# Roundtable

Prompt-driven multi-persona orchestration for opencode.

---

## Problem

OpenCode conversations are flat — one agent, one context window. When you need multiple perspectives on a design, a security review, or a trade-off analysis, you either:

1. **Hand-roll role-play** in a single session — but context bleeds between roles, the "architect" knows what the "security expert" is about to say, and honest disagreement is impossible.
2. **Switch between manual sessions** — but each restart loses thread, and there's no shared memory across them.
3. **Decompose into pipeline stages** (plan → implement → review → QA) — but pipelines are rigid, sequential, and don't support ad-hoc back-and-forth between roles.

None of these support a **human-led meeting** where the facilitator dynamically calls on personas with curated, isolated context — the same way you'd run a real design review with different specialists at the table.

---

## Solution

Roundtable is a prompt-only pattern that wires opencode's existing primitives into a reusable meeting format:

| Primitive | Role in Roundtable |
|---|---|
| **Agent markdown files** (.opencode/agents/*.md) | Define the orchestrator and each persona subagent |
| **`task()` tool with `task_id`** | Resumable persona sessions that persist across turns |
| **`task(prompt=...)`** | Curated context isolation — each persona sees only what it needs |
| **Permission system** | File/directory/model scoping per persona |
| **File read/write** | `roundtable-minutes.md` as the shared conversational memory |

**Zero dependencies. Zero compiled code. Zero plugins.** The entire system is markdown files + a bootstrap shell script.

---

## User Experience

### Init

```
cd my-project
curl -fsSL https://roundtable.example/install | bash
```

Prompts for persona names, generates agent files. Done in ~5 seconds.

### Daily Use

1. Open opencode in the project directory.
2. Tab-select the `@meeting` orchestrator.
3. Start the session:

   ```
   @meeting We need to design the auth flow for the API. @architect, what's
   your take on JWT vs session-based?
   ```

4. The orchestrator reads `roundtable-minutes.md`, invokes `@architect` with curated
   context, and returns the response.
5. The user asks a follow-up or calls on another persona:

   ```
   @security-expert, @architect proposed JWT with refresh tokens. 
   Any concerns?
   ```

6. The orchestrator invokes `@security-expert` — the architect's proposal is
   in the prompt, but the security expert doesn't see the architect's full
   conversation history.
7. The user can loop in more personas, ask for synthesis, or call for a decision.
8. The orchestrator appends a structured summary to `roundtable-minutes.md` after each
   round.
9. On return the next day, `roundtable-minutes.md` is on disk — the meeting resumes
   where it left off, even after compaction or restart.

### Flow

```
User (@meeting)
  │  "@architect, what do you think about JWT?"
  ▼
Orchestrator
  │  Reads roundtable-minutes.md
  │  Curates context: topic + architect's prior statements
  │  Invokes task(agent=architect, prompt=..., task_id=...)
  ▼
Architect subagent
  │  Responds with analysis (in-character, only sees curated context)
  ▼
Orchestrator
  │  Presents response to user
  │  Appends to roundtable-minutes.md
```

The user drives. The orchestrator routes. Personas speak only when called.

---

## Implementation

### File Structure

```
.opencode/
  agents/
    meeting.agent.md        # Orchestrator (primary agent)
    architect.md            # Persona subagent (auto-generated)
    security-expert.md      # Persona subagent (auto-generated)
    ux-designer.md          # Persona subagent (auto-generated)
    ...
  roundtable/
    roundtable-minutes.md              # Shared conversational memory
    personas/
      architect.md          # Persona definition (user-authorable)
      security-expert.md    # Persona definition (user-authorable)
      ux-designer.md        # Persona definition (user-authorable)
      ...
```

### Agent: Orchestrator (`meeting.agent.md`)

A primary agent with a deliberately small system prompt. Responsibilities:

- Read `roundtable-minutes.md` before each response.
- When user `@mentions` a persona, curate context and invoke via `task()`.
- Never invoke unprompted, never chain personas.
- Append structured entries to `roundtable-minutes.md` after each round.

The protocol rules live in `roundtable-minutes.md`, not the system prompt, creating a recency anchor that resists drift across compaction.

### Agent: Persona Subagents (auto-generated)

Each persona is a markdown agent file. The system prompt is assembled from:

1. **The roundtable protocol wrapper** — explains the persona's role in a meeting context: "You are participating in a design discussion. The facilitator is the user. Respond in character. Only address what you're asked."
2. **The persona definition** — loaded from `.opencode/roundtable/personas/<name>.md`. This is user-authored and contains the persona's expertise, perspective, tone, and behavioral guardrails.
3. **Optional model hint** — the persona definition can suggest a specific model (e.g., a cheap model for QA, an expensive one for architecture).

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

[Rules the orchestrator reads every turn]

# Session State

- Date: 2026-07-03
- Topic: API auth design
- Participants: @architect, @security-expert

# Conversation Log

## 2026-07-03 14:00 — Auth approach

- **Facilitator**: Asked about JWT vs session-based auth
- **@architect**: Recommended JWT with refresh tokens, HttpOnly cookies
- **@security-expert**: Agreed, flagged refresh token rotation storage

## 2026-07-03 14:12 — Token storage

- **Facilitator**: Asked where to store refresh tokens
- **@security-expert**: Recommended dedicated secrets service, not DB

# Persona Task IDs

- architect: task_abc123
- security-expert: task_def456
```

`task_id`s are stored here so the orchestrator can resume persona sessions after compaction.

### Context Curation

When the user says `@architect, what about X?`, the orchestrator's `task(prompt=...)` includes:

1. The direct question
2. Relevant prior statements from that persona (from `roundtable-minutes.md`)
3. The topic at hand
4. Any other persona's statements that are directly relevant

It does NOT include:
- The full conversation history
- Other personas' unrelated statements
- Orchestrator routing decisions

This is the key isolation mechanism. Each persona's context window stays clean.

### Bootstrap

`roundtable-init.sh` is a ~30-line shell script:

1. Creates `.opencode/agents/` and `.opencode/roundtable/personas/` if missing
2. Copies the orchestrator agent file
3. For each persona definition in `personas/`, generates a subagent markdown file with:
   - YAML frontmatter (description, mode, model, permissions)
   - A system prompt that wraps the persona definition with roundtable protocol instructions
4. Initializes `roundtable-minutes.md` from template
5. Optionally creates example persona definitions if the directory is empty

### Permissions Model

Personas ship with role-appropriate defaults. The YAML frontmatter in each generated agent file declares them:

```yaml
---
# Planning persona — read-only by default
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash: deny
  external_directory: deny
---
```

Users override per-persona or globally in `opencode.json`:

```json
{
  "agent": {
    "architect": {
      "permission": { "edit": "allow", "bash": "allow" }
    }
  }
}
```

File/directory scoping is supported natively:

```yaml
permission:
  edit:
    "docs/**": allow
    "src/**": deny
```

### Drift Resistance

| Drift source | Mitigation |
|---|---|
| System prompt burial | Protocol rules in roundtable-minutes.md — read every turn |
| Compaction loss | All state in roundtable-minutes.md (file, not conversation history) |
| Learning bad patterns | Orchestrator history is just routing — no behavioral examples to mimic |
| Forgetting task_ids | Stored in roundtable-minutes.md, survive compaction |
| Over-eager routing | Tight rules: never invoke unprompted, never chain |

---

## Status

- **Problem/UX/Implementation**: Designed (this document)
- **Orchestrator prompt**: Drafted
- **Persona protocol wrapper**: Not yet written
- **roundtable-minutes.md format**: Drafted
- **Bootstrap script**: Not yet written
- **Example personas**: Not yet written
- **Prototype**: Not yet started

---

## Future: Autonomous Mode

The same infrastructure (roundtable-minutes.md, curated context, persona isolation) can support an autonomous coding mode with a `@director` orchestrator that decomposes tasks, delegates to coding personas, and synthesizes results — without the user driving each turn. The abstraction boundary is clean: only the orchestrator system prompt and persona permissions change.
