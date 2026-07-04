# Roundtable

## What this repo is

A prompt-only multi-persona orchestration system for opencode. No application code, no build, no tests — just markdown agent configurations.

**Do not** look for package.json scripts, test commands, or linters. There are none.

## Architecture

Read `docs/Roundtable.md` for full design

## Workflow

1. Edit persona source files in `.opencode/roundtable/personas/`
2. Run `/roundtable-sync` — the agent reads the sync command file (`commands/roundtable-sync.md`) and regenerates `.opencode/agents/persona-*.md`
3. Select `@Meeting` to start a session
4. The facilitator routes to experts via `task()` with curated context

All agents default to model `opencode/deepseek-v4-flash-free`.

## Key constraints

- `/roundtable-sync` is a **prompt command** — the agent must read the `.md` file and execute the instructions by hand using read/glob/write tools, not a shell script
- Editing agent files in `.opencode/agents/` directly is overwritten on next sync — edit persona sources in `.opencode/roundtable/personas/`
- Generated persona agents are named `persona-<role>.md` (e.g. `persona-architect.md`, `persona-engineer.md`). Use `@persona-architect` etc. when mentioning them.
- Minutes files are gitignored at `.opencode/roundtable/minutes/` — don't expect them in the working tree


## General response practices

You have access to `websearch` and `webfetch` tools. **Use them by default for any
factual question** — especially about current events, dates, software versions,
APIs, pricing, documentation, technologies, or anything that may have changed
since the model's training cutoff (which you cannot reliably determine).

Rules:
1. When asked a factual question, do NOT answer from memory alone.
2. Search the web first, then synthesize the answer from search results.
3. If search results are inconclusive, say so — do not guess.
4. The only exception is common knowledge that is genuinely timeless
   (e.g., "what is the capital of France?").
