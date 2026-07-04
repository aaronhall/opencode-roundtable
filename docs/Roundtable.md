# Roundtable

Prompt-driven multi-persona orchestration for opencode.

---

## Problem

opencode conversations are flat — one agent, one context window. When you need multiple perspectives on a design, a security review, or a trade-off analysis, you either:

1. **Single-session role-play** — context bleeds between roles, the "architect" knows what the "security expert" is about to say, and honest disagreement is impossible.
2. **Manual sessions** — each restart loses thread, no shared memory across them.
3. **Pipeline stages** (plan → implement → review → QA) — rigid and sequential, don't support ad-hoc back-and-forth.

None support a **human-led meeting** where the facilitator dynamically calls on domain experts with curated, isolated context — the same way you'd run a real design review.

---

## Solution

Roundtable is a prompt-only pattern using opencode's existing primitives:

| Primitive | Role in Roundtable |
|---|---|
| **Agent markdown files** (.opencode/agents/*.md) | Orchestrator and persona subagents |
| **`task()` with `task_id`** | Resumable persona sessions across turns |
| **`task(prompt=...)`** | Curated context isolation |
| **Permission system** | File/directory/model scoping per persona |
| **File read/write** | `roundtable-minutes.md` as shared conversational memory |

**Zero dependencies, zero compiled code, zero plugins.** The entire system is markdown files + the `/roundtable-sync` prompt command that reads persona definitions and writes agent files.

---

## User Experience

### Init

1. Create persona definition files in `.opencode/roundtable/personas/`.
2. Run `/roundtable-sync` to generate the corresponding subagent files.
3. Start a session with `@meeting`.

### Daily Use

1. Open opencode in the project directory.
2. Select `@meeting` as the active agent.
3. The facilitator reads the persona definitions to know each expert's domain, then discusses with you:

   ```
   @meeting We need to design the auth flow for the API. @architect, what's
   your take on JWT vs session-based?
   ```

4. The facilitator reads `roundtable-minutes.md`, invokes the expert with curated context, relays the response verbatim, and provides synthesis.
5. The user asks a follow-up or the facilitator routes an open-ended question to the right expert:

   ```
   @security-expert, @architect proposed JWT with refresh tokens.
   Any concerns?
   ```

6. The facilitator invokes `@security-expert` — architect's proposal is in the prompt, but the security expert doesn't see the architect's full history.
7. After each turn, the facilitator appends a structured entry to `roundtable-minutes.md`.
8. Next session, `roundtable-minutes.md` is on disk — the meeting resumes where it left off, even after compaction.

### Flow

```
User (via @meeting)
  │  "What do you think about JWT for our API?"
  ▼
Orchestrator
  │  Reads roundtable-minutes.md, reads persona definitions
  │  Decides which expert to call (or asks user to specify)
  │  Curates context, invokes task(agent=..., prompt=..., task_id=...)
  ▼
Expert subagent
  │  Responds with domain analysis (sees only curated context)
  ▼
Orchestrator
  │  Relays response verbatim to user
  │  Provides contextual synthesis
  │  Appends summary to roundtable-minutes.md
```

The user drives. The orchestrator routes. Experts speak only when called via `task()`.

---

## Implementation

### File Structure

```
.opencode/
  agents/
    meeting.agent.md              # Orchestrator (primary agent)
    architect.md                  # Persona subagent (auto-generated)
    security-expert.md            # Persona subagent (auto-generated)
    ux-designer.md                # Persona subagent (auto-generated)
    ...
  commands/
    roundtable-sync.md            # Prompt command: read personas, write agents
  roundtable/
    roundtable-minutes.md         # Shared conversational memory
    subagent-base.md              # Base template all persona agents share
    personas/
      architect.md                # Persona definition (user-authorable)
      security-expert.md          # Persona definition (user-authorable)
      ux-designer.md              # Persona definition (user-authorable)
      ...
```

### Agent: Orchestrator (`meeting.agent.md`)

A primary agent (`mode: primary`). Responsibilities:

- Read persona definitions at meeting start to learn each expert's domain.
- Read `roundtable-minutes.md` before each response.
- Route user questions to the right expert(s) — by explicit `@mention` or by judging which domain fits.
- Curate context per invocation (see Context Curation below).
- Announce each expert call, relay response verbatim, synthesize after all respond.
- Append structured entries to `roundtable-minutes.md` after every turn.
- **Never** answer domain questions directly, **never** chain experts without user input, **never** pass raw full history to an expert.

Protocol rules are in both the system prompt and `roundtable-minutes.md` for recency-anchored drift resistance.

### Agent: Persona Subagents (auto-generated by `/roundtable-sync`)

Each persona's agent file is assembled from:

1. **Frontmatter** — description, mode: subagent, optional model hint, permissions (read-only by default).
2. **Base template** — loaded from `.opencode/roundtable/subagent-base.md`. Frames the persona as a domain expert, not a roleplayer. Includes the roundtable protocol rules.
3. **Persona definition** — substituted into the `{{PERSONA_BODY}}` placeholder. User-authored content: expertise, perspective, tone, guardrails.

The assembly is done by the `/roundtable-sync` pure-prompt command (reads the base template, reads each persona file, substitutes, writes agent files — no shell script).

Example persona definition:

```markdown
# Architect

You evaluate technical designs for scalability, maintainability, and
feasibility. You prefer simple solutions and push back on over-engineering.

## Behavioral Guardrails

- If the requirements are ambiguous, ask for clarification rather than
  assuming.
- Flag technical debt explicitly.
- When disagreeing, propose an alternative.

## Model

claude-sonnet-4-20250514
```

### Session File (`roundtable-minutes.md`)

The shared memory that survives compaction, restart, and model switches.

```markdown
# Roundtable Protocol

[Rules the orchestrator reads every turn — duplicated from system prompt]

# Session State

- Date: 2026-07-03
- Topic: API auth design
- Participants: @architect, @security-expert

# Conversation Log

## 2026-07-03 14:00 — Auth approach

- **Leader**: Asked about JWT vs session-based auth
- **@architect**: Recommended JWT with refresh tokens, HttpOnly cookies
- **@security-expert**: Agreed, flagged refresh token rotation storage
- **Synthesis**: Both prefer JWT; key concern is token storage
- **Decision**: Proceed with JWT, investigate refresh token storage options

# Persona Task IDs

- architect: task_abc123
- security-expert: task_def456
```

The user is always **Leader** in minutes. `task_id`s are stored here so the orchestrator can resume expert sessions after compaction.

### Context Curation

When the facilitator calls an expert, `task(prompt=...)` includes:

1. The direct question
2. Relevant prior statements from that expert (from `roundtable-minutes.md`)
3. The topic at hand
4. Any other expert's statements that are directly relevant to the question

It does NOT include:
- The full conversation history
- Other experts' unrelated statements
- Facilitator routing decisions or reasoning
- The facilitator's own analysis

This is the key isolation mechanism. Each expert's context window stays clean. Subagents are one-shot — they receive a prompt and return a response; no back-and-forth.

### `/roundtable-sync` Command

`roundtable-sync.md` is a pure-prompt command (no shell script). Process:

1. Glob for persona files in `.opencode/roundtable/personas/`.
2. If none exist, tell the user to create some and stop.
3. Read base template from `.opencode/roundtable/subagent-base.md`.
4. For each persona file, read it, parse the description and optional model hint, substitute the body into the template, prepend frontmatter, write the agent file.
5. Report which files were created or updated.

### Permissions Model

Personas ship with role-appropriate defaults in their generated frontmatter:

```yaml
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash: deny
  external_directory: deny
```

Users override per-persona in `opencode.json` or by editing the agent file directly.

### Drift Resistance

| Drift source | Mitigation |
|---|---|
| System prompt burial | Protocol rules duplicated in roundtable-minutes.md — read every turn |
| Compaction loss | All state in roundtable-minutes.md (file, not conversation history) |
| Learning bad patterns | Orchestrator history is just routing — no behavioral examples to mimic |
| Forgetting task_ids | Stored in roundtable-minutes.md file, survive compaction |
| Over-eager routing | Hard Boundaries: never chain without user input |

---

## Status

- **Orchestrator prompt**: written and refined
- **Base subagent template**: written, stored in `subagent-base.md`
- **`/roundtable-sync` command**: written as pure prompt
- **`roundtable-minutes.md` format**: drafted
- **Example personas**: 4 written (architect, security-expert, ux-designer, qa-engineer)
- **Permissions model**: defined per persona
- **Drift resistance**: implemented via duplicate protocol rules + file-based state
- **Status**: prototype ready for testing

---

## Future: Autonomous Mode

The same infrastructure (roundtable-minutes.md, curated context, persona isolation) can support an autonomous coding mode with a `@director` orchestrator that decomposes tasks, delegates to coding personas, and synthesizes results — without the user driving each turn. Only the orchestrator system prompt and persona permissions change.
