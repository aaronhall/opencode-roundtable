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

For each persona, generate a file at `.opencode/agents/persona-<filename>.md`.
The file is composed of frontmatter followed by the subagent base template with
the persona body substituted in:

1. Read the base template from `.opencode/roundtable/subagent-base.md`
2. Replace `{{PERSONA_BODY}}` with the persona definition body (excluding `## Model`)
3. Prepend frontmatter:
   ```yaml
   description: <first paragraph after the H1, truncated to 120 chars>
   mode: subagent
    model: <model-id if present, otherwise opencode/deepseek-v4-flash-free>
   permission:
     read: allow
     glob: allow
     grep: allow
     edit: deny
     bash: deny
     external_directory: deny
   ```

## Process

1. Glob for persona files in `.opencode/roundtable/personas/`
2. If none exist, tell the user to create some and stop.
3. Read the base template from `.opencode/roundtable/subagent-base.md`
4. For each persona file, read it, parse the description and optional model,
   substitute the body into the template, then write the agent file.
5. Report which files were created or updated.
