---
description: Initialize or update persona subagents from roundtable persona definitions
---
Run `.opencode/roundtable/scripts/roundtable-persona-sync.sh` to generate or update persona agent files from
the definitions in `.opencode/roundtable/personas/`.

- Reads each persona file (except `roundtable-scribe.md`, which is handled separately)
- Substitutes the persona body into `.opencode/roundtable/subagent-base.md`
- Writes the result to `.opencode/agents/roundtable/<name>.md`

After the script completes, report: "Personas updated. Restart opencode for changes to take effect."
