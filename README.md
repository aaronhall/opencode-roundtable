# Roundtable

**Prompt-driven multi-persona orchestration for opencode.** Adversarial guidance without context bloat.

---

## Problem

opencode conversations are flat — one agent, one context window. When you need
multiple perspectives on a design, a security review, or a trade-off analysis,
you either:

1. **Single-session role-play** — context bleeds between roles, the "architect"
   knows what the "security expert" is about to say, and honest disagreement is
   impossible.
2. **Manual sessions** — each restart loses thread, no shared memory across
   them.
3. **Pipeline stages** (plan → implement → review → QA) — rigid and sequential,
   don't support ad-hoc back-and-forth.

None support a **human-led meeting** where the facilitator dynamically calls on
domain experts with curated, isolated context — the same way you'd run a real
design review.

---

## Solution

Roundtable is a prompt-only pattern using opencode's existing primitives:

| Primitive                                                   | Role in Roundtable                                        |
| ----------------------------------------------------------- | --------------------------------------------------------- |
| **Agent markdown files** (.opencode/agents/roundtable/*.md) | Orchestrator and persona subagents                        |
| **`task()` with `task_id`**                                 | Resumable persona sessions across turns                   |
| **`task(prompt=...)`**                                      | Curated context isolation                                 |
| **Permission system**                                       | File/directory/model scoping per persona                  |
| **File read/write**                                         | Per-session minutes files as shared conversational memory |

**Zero dependencies, zero compiled code, zero plugins.** The entire system is
markdown files + the `/roundtable-init` command that generates persona agent
files from definitions.

---

## User Experience

### Init

1. Create persona definition files in `.opencode/roundtable/personas/`.
2. Run `/roundtable-init` to generate the corresponding subagent files.
3. Start a session with `@Meeting`.

### Daily Use

1. Open opencode in the project directory.
2. Select `@Meeting` as the active agent.
3. The facilitator reads the persona definitions to know each expert's domain,
   then discusses with you:

   ```
   @Meeting We need to design the auth flow for the API. @roundtable/architect, what's
   your take on JWT vs session-based?
   ```

4. The facilitator reads the current minutes file, invokes the expert(s) in
   parallel with curated context, outputs the curated prompt for visibility,
   relays each response verbatim, then provides synthesis.
5. The user asks a follow-up or the facilitator routes an open-ended question to
   the right expert:

   ```
   @roundtable/security-expert, @roundtable/architect proposed JWT with refresh tokens.
   Any concerns?
   ```

6. The facilitator invokes `@roundtable/security-expert` — architect's proposal
   is in the prompt, but the security expert doesn't see the architect's full
   history.
7. After each turn, the facilitator delegates minute-writing to the
   `roundtable/roundtable-scribe` subagent, which handles the file write
   invisibly.
8. Next session, the minutes directory is on disk — latest or previous sessions
   can be resumed.

### Flow

```
User (via @Meeting)
  │  "What do you think about JWT for our API?"
  ▼
Orchestrator
  │  Reads current minutes file, reads persona definitions
  │  Decides which experts to call (or asks user to specify)
  │  Curates context, outputs prompt, invokes experts in parallel
  ▼
Expert subagent(s)
  │  Each responds with domain analysis (sees only curated context)
  ▼
Orchestrator
  │  Relays all responses verbatim to user
  │  Provides contextual synthesis
  │  Delegates minute-writing to roundtable/roundtable-scribe (file write, invisible to user)
```

The user drives. The orchestrator routes. Experts speak only when called via
`task()`.

---

## Implementation

### File Structure

```
.opencode/
  agents/
    Meeting.md                    # Orchestrator (primary agent)
    roundtable/
      architect.md                # Persona subagent (auto-generated)
      engineer.md                 # Persona subagent (auto-generated)
      product-designer.md         # Persona subagent (auto-generated)
      product-manager.md          # Persona subagent (auto-generated)
      qa-engineer.md              # Persona subagent (auto-generated)
      security-expert.md          # Persona subagent (auto-generated)
      ux-designer.md              # Persona subagent (auto-generated)
      roundtable-scribe.md           # Minute-writing subagent (hidden from UI)
    ...
  commands/
    roundtable-init.md            # Read by agent, delegates to .opencode/roundtable/scripts/roundtable-persona-sync.sh
    roundtable-full-response.md   # Utility: replay verbatim responses from last turn
  roundtable/
    scripts/
      roundtable-persona-sync.sh            # Bash script: deterministic persona generation
    minutes/                      # Per-session minutes files (gitignored)
      2026-07-04-auth-flow-review.md
      ...
    subagent-base.md              # Base template all persona agents share
    personas/
      architect.md                # Persona definition (user-authorable)
      engineer.md                 # Persona definition (user-authorable)
      product-designer.md         # Persona definition (user-authorable)
      product-manager.md          # Persona definition (user-authorable)
      qa-engineer.md              # Persona definition (user-authorable)
      roundtable-scribe.md           # Scribe definition (internal)
      security-expert.md          # Persona definition (user-authorable)
      ux-designer.md              # Persona definition (user-authorable)
      ...
```

### Agent: Orchestrator (`agents/Meeting.md`)

A primary agent (`mode: primary`). Responsibilities:

- Read persona definitions at meeting start to learn each expert's domain.
- Determine the current minutes file (glob for latest, create new, or ask user).
- Read the current minutes file before each response.
- Route user questions to the right expert(s) — by explicit `@mention` or by
  judging which domain fits.
- Curate context per invocation (see Context Curation below).
- Output the curated prompt for visibility before each subagent invocation.
- Announce expert calls, relay responses verbatim, synthesize after all respond.
- Delegate minute-writing to the `roundtable/roundtable-scribe` subagent
  (hidden, handles file writes invisibly).
- Invoke multiple independent experts in parallel.
- **Never** answer domain questions directly, **never** chain experts without
  user input, **never** pass raw full history to an expert.

### Agent: Persona Subagents (auto-generated by `/roundtable-init`)

Each persona's agent file is assembled from:

1. **Frontmatter** — description, mode: subagent, optional model hint,
   permissions (read-only by default).
2. **Base template** — loaded from `.opencode/roundtable/subagent-base.md`.
   Frames the persona as a domain expert, not a roleplayer. Includes the
   roundtable protocol rules.
3. **Persona definition** — substituted into the `{{PERSONA_BODY}}` placeholder.
   User-authored content: expertise, perspective, tone, guardrails.

The assembly is done by the `/roundtable-init` command, which runs

Example persona definition:

```markdown
# Architect

You evaluate technical designs for scalability, maintainability, and
feasibility. You prefer simple solutions and push back on over-engineering.

## Behavioral Guardrails

- If the requirements are ambiguous, ask for clarification rather than assuming.
- Flag technical debt explicitly.
- When disagreeing, propose an alternative.

## Model

opencode/deepseek-v4-flash-free
```

### Session Files (`minutes/`)

Minutes are stored per-session files in `.opencode/roundtable/minutes/` with
names like `YYYY-MM-DD-[slug].md`. The slug is a 2-4 word topic summary,
lowercase with hyphens. Examples:

- `2026-07-04-auth-flow-review.md`
- `2026-07-04-ux-revision.md` (same day, different meeting)

Filenames are generated by the orchestrator at session creation:

1. Run `date +%Y-%m-%d` via bash to get today's date.
2. Derive a 2-4 word slug from the user's first message.
3. Combine: `{date}-{slug}.md` — e.g., `2026-07-04-auth-flow-review.md`.

Entry headers use the date portion of the filename with sequential turn numbers:

```markdown
# Meeting Session

## Session State

- Topic: API auth design
- Participants: @roundtable/architect, @roundtable/security-expert

## Conversation Log

## 2026-07-04 Turn 1 — Auth approach

- **Leader**: Asked about JWT vs session-based auth
- **@roundtable/architect**: Recommended JWT with refresh tokens, HttpOnly
  cookies
- **@roundtable/security-expert**: Agreed, flagged refresh token rotation
  storage
- **Synthesis**: Both prefer JWT; key concern is token storage
- **Decision**: Proceed with JWT, investigate refresh token rotation storage

# Persona Task IDs

- architect: task_abc123
- security-expert: task_def456
```

The user is always **Leader** in minutes. `task_id`s are stored here so the
orchestrator can resume expert sessions after compaction.

The file write is delegated to the `roundtable/roundtable-scribe` subagent
(`hidden: true`) — the user never sees file diffs in the UI.

### Context Curation

When the facilitator calls an expert, `task(prompt=...)` includes:

1. The direct question
2. Relevant prior statements from that expert (from the current minutes file)
3. The topic at hand
4. Any other expert's statements that are directly relevant to the question

It does NOT include:

- The full conversation history
- Other experts' unrelated statements
- Facilitator routing decisions or reasoning
- The facilitator's own analysis

This is the key isolation mechanism. Each expert's context window stays clean.
Subagents are one-shot — they receive a prompt and return a response; no
back-and-forth.

### `/roundtable-init` Command

`roundtable-init.md` is a command file that tells the agent to run
`.opencode/roundtable/scripts/roundtable-persona-sync.sh` — a standalone bash
script that does the deterministic work of reading persona definitions,
substituting the template, and writing agent files. Process:

1. The script reads each persona file in `.opencode/roundtable/personas/`.
2. For each (except `roundtable-scribe.md`, handled separately), it reads the
   file, extracts the description and optional model hint, strips the `## Model`
   section, substitutes the body into `subagent-base.md`, prepends frontmatter,
   and writes the agent file to `.opencode/agents/roundtable/<name>.md`.
3. Reports which files were created or updated.

Additional utility commands may live in this directory. See each `.md` file for
usage. Current utilities:

- `/roundtable-full-response` — replay verbatim subagent responses from the most
  recent turn. Accepts one or more persona names or none (all).

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

Users override per-persona in `opencode.json` or by editing the agent file
directly.

### Drift Resistance

| Drift source          | Mitigation                                                                        |
| --------------------- | --------------------------------------------------------------------------------- |
| System prompt burial  | Hard Boundaries in system prompt are always present (not in conversation history) |
| Compaction loss       | All state in minutes files (files, not conversation history)                      |
| Learning bad patterns | Orchestrator history is just routing — no behavioral examples to mimic            |
| Forgetting task_ids   | Stored in minutes file, survive compaction                                        |
| Over-eager routing    | Hard Boundaries: never chain without user input                                   |

---

## Status

- **Orchestrator prompt**: written and refined
- **Base subagent template**: written, stored in `subagent-base.md`, frames
  persona as domain expert (not roleplayer)
- **`/roundtable-init` command**: delegates to
  `.opencode/roundtable/scripts/roundtable-persona-sync.sh` (bash script,
  deterministic)
- **`/roundtable-full-response` utility**: replays verbatim responses by name
  from session history with compaction fallback
- **Minutes file format**: drafted, per-session timestamped files in `minutes/`
- **Example personas**: 7 written (architect, security-expert, ux-designer,
  qa-engineer, engineer, product-manager, product-designer)
- **Roundtable-scribe subagent**: created (`hidden: true`) — handles
  minute-writing invisibly to avoid file diff noise in UI
- **Parallel invocation**: experts are invoked concurrently when questions are
  independent
- **Permissions model**: defined per persona (read-only by default,
  roundtable-scribe has edit for file writes)
- **Default model**: `opencode/deepseek-v4-flash-free` across all agents
- **Status**: prototype ready for testing

---

## Future: Autonomous Mode

The same infrastructure (roundtable-minutes.md, curated context, persona
isolation) can support an autonomous coding mode with a `@director` orchestrator
that decomposes tasks, delegates to coding personas, and synthesizes results —
without the user driving each turn. Only the orchestrator system prompt and
persona permissions change.
