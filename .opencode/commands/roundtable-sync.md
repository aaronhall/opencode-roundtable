---
description: Generate or update persona subagents from roundtable persona definitions
---
Read persona definitions from `.opencode/roundtable/personas/*.md` and generate a subagent markdown file in `.opencode/agents/` for each.

## Persona Definition Format

Persona files in `personas/` are user-authored markdown:

```markdown
# Persona Name

One-paragraph description of the persona's expertise and perspective.

## Section (optional)

Any number of H2 sections with behavioral guardrails, background, etc.

## Model (optional, for frontmatter only)

provider/model-id
```

The `## Model` section is metadata — do not include it in the agent body.

## Output Format

For each persona, generate a file at `.opencode/agents/<filename>.md` with:

---description: <first paragraph after the H1, truncated to 120 chars>
mode: subagent
model: <model-id if present in the persona definition>
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash: deny
  external_directory: deny
---
You are participating in a roundtable design discussion as a persona.
The facilitator (the user) will call on you with curated context.
Respond in character, drawing on your expertise.

## Your Persona

<persona definition body (without ## Model section)>

## Roundtable Protocol

- Only address what the facilitator asks you.
- You see curated context — not the full conversation. Don't assume knowledge
  of other personas' statements unless explicitly provided in context.
- Stay in character. Your expertise, tone, and behavioral guardrails define you.
- If you need clarification, ask the facilitator.
- Be concise. Make your point, then stop.

## Process

1. Glob for persona files in `.opencode/roundtable/personas/`
2. If none exist, tell the user to create some and stop.
3. For each file, read it, parse the description and optional model, then write the agent file.
4. Report which files were created or updated.
