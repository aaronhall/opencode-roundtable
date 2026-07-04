# Multi-Agent Roundtable: Persistent Persona Orchestration

> Session notes from 2026-07-03 conversation. Explores how to build
> a system where multiple AI agents with distinct personas collaborate
> persistently on a shared project — retaining their own context across
> interactions, with a human as the ultimate decision-maker.

---

## The Core Idea

OpenCode's `task` tool accepts a `task_id` parameter that **resumes the
same subagent session** — same context, history, and conversation. This
turns subagents from disposable one-shot invocations into persistent
personas that maintain their own context windows for the duration of a
"meeting."

```
Orchestrator (primary agent)
  │
  ├─ task(agent=@architect)  → task_id: abc  → resumes same session
  ├─ task(agent=@developer)  → task_id: def  → resumes same session
  ├─ task(agent=@reviewer)   → task_id: ghi  → resumes same session
  └─ task(agent=@qa)         → task_id: jkl  → persists same session

Shared document on disk: fallback that survives compaction / restart
```

Each persona:
- Runs as a **continued subagent session** — not a fresh start
- Has its own **model, permissions, temperature**
- Accumulates its own **conversation history** over multiple rounds
- Gets **direct messages** from the orchestrator referencing other
  personas' outputs

The orchestrator:
- Spools each persona up once, captures its `task_id`
- Routes messages between them: *"Architect said X about the data model.
  Developer, please respond."*
- Flags contradictions for the human to resolve
- Writes a shared artifact (`.workbench/session.md`) as the persistent
  record that survives session restarts

## Why It Works Better Than Role-Playing

| Single agent switching roles | Multi-persona (roundtable) |
|---|---|
| Context bleeds between roles — knows what it just said as "stakeholder" | Each persona sees only its own history |
| Never truly disagrees with itself across persona boundaries | Architect can reject a stakeholder requirement cold |
| Reviewer is lenient on code it helped write minutes ago | Reviewer has fresh eyes — catches real bugs |
| One model, one permission set | Per-persona model/permission tuning (cheap model for QA, expensive for architect) |

## Concrete Example: Portal Onboarding

1. **Architect** reviews the portal's HTML patterns, designs extractor
   methods, writes to the shared doc
2. **Developer** reads the doc, implements based on that design
3. **Reviewer** reads the diff independently, catches that pagination
   isn't handled — flags it
4. **Orchestrator** routes the finding back to Developer with context
5. **QA** generates test fixtures covering the pagination edge case
6. Orchestrator presents the full package to the human for sign-off

The reviewer catching the pagination gap is unlikely in a single-agent
flow because the agent "knows" it didn't implement it and rationalizes.

## Key Risk: Stale Context on Restart

Subagent sessions survive as long as the primary session is alive. If
the primary compacts or restarts, `task_id`s are lost. Mitigation: the
shared document on disk. On restart, the orchestrator re-spawns each
persona with *"Read the shared document to catch up."*

## Not Novel — But Not Canonical

The pattern is well-documented across opencode tooling and community:

- **OpenCode docs** — `task_id` resume is described in the Task tool docs
- **PR #7756** — subagent-to-subagent delegation with persistent sessions,
  budgets, depth limits (NamedIdentity's Agentic Collaboration Framework)
- **PR #18588** — dynamic subagent task support with inline context
  persistence
- **Reddit r/opencodeCLI** — community discussing "Blueprint / Execute
  Scheme" of continuing subagent sessions
- **`shared-brain`** — file-based shared context directory for any agent
- **`WORKFLOW_STATE.md`** — planner → debater → implementor → reviewer
  → tester → linter pipeline
- **Slack-based patterns** (slackhive, openclaw channel bots) — persona
  agents in shared channels with Boss delegating to specialists
- **Issue #6584** — feature request for agent-level subagent resume
- **Issue #387 (oh-my-opencode-slim)** — using `task_id` for multi-agent
  delegations with explicit persona routing

What's **missing** is a polished, documented recipe — an orchestrator
prompt template + persona agent markdown files + shared document format
that wires the whole thing together end-to-end.

## Open Questions

- How does the orchestrator handle a persona's session going idle for
  a long time? Auto-compaction?
- Should the shared document be markdown or something more structured
  (YAML frontmatter per section)?
- Is there a way to surface the roundtable state in opencode's TUI
  (subagent tree already exists via PR #7756)?
- How granular should the "flag for human" mechanism be? Every
  contradiction, or only substantive ones?

---

*See also: [[Architecture]], [[Agentic Workflow]]*
