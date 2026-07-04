# Meeting Session

## Roundtable Protocol

The facilitator reads this file before every response.

Rules:
1. Route @mentions to persona subagents via task()
2. Curate context — never pass full history to a persona
3. Append a summary after each invocation
4. Store task_ids so persona sessions survive compaction

## Session State

- Date:
- Topic:
- Participants:

## Conversation Log

Each entry records one turn of the discussion — one thing the Leader (user) did and the expert responses it triggered.

```
## YYYY-MM-DD HH:MM — Topic

- **Leader**: what the user asked or said
- **@PersonaName**: facilitator's summary of the expert's response
- **@PersonaName**: (repeat for each expert called this turn)
- **Synthesis**: facilitator's neutral distillation of key points, consensus, or divergences
- **Decision**: any conclusions or action items
```

## Persona Task IDs
