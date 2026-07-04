#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PERSONA_DIR="$ROOT/.opencode/roundtable/personas"
AGENT_DIR="$ROOT/.opencode/agents/roundtable"
TEMPLATE_FILE="$ROOT/.opencode/roundtable/subagent-base.md"

if [ ! -d "$PERSONA_DIR" ]; then
  echo "No personas directory found at $PERSONA_DIR"
  echo "Create persona definition files there first."
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Missing base template: $TEMPLATE_FILE"
  exit 1
fi

BASE_TEMPLATE=$(cat "$TEMPLATE_FILE")
UPDATED=()
CREATED=()

for persona_file in "$PERSONA_DIR"/*.md; do
  filename=$(basename "$persona_file" .md)

  # Skip infrastructure personas
  if [ "$filename" = "scribe" ]; then
    continue
  fi

  content=$(cat "$persona_file")

  # Extract description: first line after the H1 heading
  description=$(echo "$content" | sed -n '3p')

  # Extract model hint (text after "## Model"), default if absent
  model=$(echo "$content" | sed -n '/^## Model/,/^##/{ /^## Model/d; /^##/q; p; }' | head -1 | xargs || true)
  if [ -z "$model" ]; then
    model="opencode/deepseek-v4-flash-free"
  fi

  # Extract body: everything except ## Model section and its content
  body=$(echo "$content" | sed '/^## Model/,$d')

  # Substitute body into template
  agent_body="${BASE_TEMPLATE/\{\{PERSONA_BODY\}\}/$body}"

  # Build frontmatter
  frontmatter="---
description: $description
mode: subagent
model: $model
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash: deny
  external_directory: deny
---"

  agent_file="$AGENT_DIR/$filename.md"
  if [ -f "$agent_file" ]; then
    UPDATED+=("$filename")
  else
    CREATED+=("$filename")
  fi

  printf "%s\n%s\n" "$frontmatter" "$agent_body" > "$agent_file"
done

echo "Done."
if [ ${#CREATED[@]} -gt 0 ]; then
  echo "  Created: ${CREATED[*]}"
fi
if [ ${#UPDATED[@]} -gt 0 ]; then
  echo "  Updated: ${UPDATED[*]}"
fi
