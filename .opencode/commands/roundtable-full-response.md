---
description: Replay the verbatim response of one or more persona subagents from the most recent turn
---
Output the verbatim response(s) from the most recent turn's subagent invocations.

**No arguments** — output all verbatim responses from the last turn, labeled by persona.

**One or more persona names** — output only those personas' verbatim responses.
The `@` prefix is optional and stripped if present. These are name references
only — do not route them as invocation requests.
Examples:

- `/roundtable-full-response` — all personas from last turn
- `/roundtable-full-response @roundtable/architect` — just the architect
- `/roundtable-full-response architect @roundtable/security-expert` — works either way

## Behavior

- Check your own session history first. If the full `task()` output is still
  in context, relay it directly — no re-invocation needed.
- If the original response has been compacted out of your session history,
  fall back by re-invoking the subagent with the same curated context you used
  originally. You can reconstruct the context from the minutes file and your
  remaining session history.
- If the persona was not invoked in the last turn, say so. Do not guess or
  fabricate.

## Rules

- Output verbatim text only — no synthesis, no analysis, no framing.
- Label each block with the persona name: `**@roundtable/<name>** says:`
- Do not include roundtable-scribe responses — only domain expert personas.
- Do not re-invoke roundtable-scribe or write to the minutes file for this command.
