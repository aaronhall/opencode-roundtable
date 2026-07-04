# Roundtable

## What this repo is

A prompt-only multi-persona orchestration system for opencode. No application code, no build, no tests — just markdown agent configurations.

**Do not** look for package.json scripts, test commands, or linters. There are none.

## Architecture

Read `docs/Roundtable.md` for full design

## Workflow

1. Edit persona source files in `.opencode/roundtable/personas/`
2. Run `/roundtable-init` — runs `.opencode/roundtable/scripts/roundtable-sync.sh` to regenerate `.opencode/agents/roundtable/*.md`
3. Select `@Meeting` to start a session (agent at `.opencode/agents/Meeting.md`)
4. The facilitator routes to experts via `task()` with curated context

All agents default to model `opencode/deepseek-v4-flash-free`.

## Key constraints

- `/roundtable-init` runs `.opencode/roundtable/scripts/roundtable-sync.sh` (a bash script, not a prompt command)
- Editing agent files in `.opencode/agents/roundtable/` directly is overwritten on next sync — edit persona sources in `.opencode/roundtable/personas/`
- Generated persona agents are named `<role>.md` (e.g. `architect.md`, `engineer.md`). Use `@roundtable/architect` etc. when mentioning them.
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
