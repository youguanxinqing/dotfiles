---
description: "Send a structured inbox message to another AI agent (Claude or Codex). Use for: send to codex, send to claude, ask codex/claude to review, hand off work, forward conclusions."
---

# /inbox:send

Put the current stage conclusions into a structured inbox message and deliver it to the other agent.

## Identity

- If you are running in Claude Code, you are `claude`, default recipient is `codex`
- If you are running in Codex, you are `codex`, default recipient is `claude`

## Message Type Mapping

| User says | type |
|---|---|
| "review", "check", "look at" | `review_request` |
| "question", "ask", "please answer" | `question` |
| "hand off", "continue", "take over", "next step" | `handoff` |

If unclear, default to `review_request`.

## How to Distill Context

Do NOT dump the entire conversation. Extract only:

- **goal**: The current objective in one sentence
- **files**: List of relevant file paths
- **focus**: What the recipient should pay attention to (list)
- **notes**: Constraints, warnings, or supplementary info

For `question` type, also include:
- **questions**: The specific questions to answer

For `handoff` type, also include:
- **decision**: What has been decided so far
- **notes**: What remains to be done

## Execution — Claude Code (use native tools, no Bash)

0. **Resolve project root**: Run `git rev-parse --show-toplevel` via Bash to get the absolute path of the repo root. Use this as `{root}` in all subsequent paths. This is necessary because `.ai-inbox` lives at the repo root, but CWD may be a subdirectory.

1. Generate a topic in kebab-case (short, descriptive, e.g. `login-review`)

2. Generate a UTC timestamp in compact format: `YYYYMMDDTHHMMSSZ`

3. Construct the message JSON:
   ```json
   {
     "schema_version": "v1",
     "id": "{timestamp}-{self}-to-{other}-{topic}",
     "from": "{self}",
     "to": "{other}",
     "topic": "{topic}",
     "type": "{type}",
     "summary": "{one-line summary}",
     "context": {
       "goal": "...",
       "files": [],
       "focus": [],
       "notes": "..."
     },
     "reply_requested": true,
     "created_at": "{ISO 8601 UTC, e.g. 2026-04-22T09:15:30Z}"
   }
   ```

4. Write the message file using the **Write** tool to:
   ```
   {root}/.ai-inbox/{other}/inbox/{timestamp}-{topic}-{self}-to-{other}.json
   ```

5. Report: file path, topic, summary. Remind user to run `/inbox read` in the other agent.

## Execution — Codex (use Python script)

Set `INBOX_PY` to whichever path exists:
- `~/.claude/skills/inbox/scripts/inbox.py`
- `~/.codex/skills/inbox/scripts/inbox.py`

1. If `.ai-inbox/` does not exist, initialize:
   ```bash
   python3 "$INBOX_PY" init --root "$(pwd)"
   ```

2. Write context JSON to a temp file, then send:
   ```bash
   cat > /tmp/inbox-ctx.json << 'CTXEOF'
   {"goal": "...", "files": [...], "focus": [...], "notes": "..."}
   CTXEOF

   python3 "$INBOX_PY" send \
     --agent codex \
     --to claude \
     --topic <TOPIC> \
     --type <TYPE> \
     --summary "<one-line summary>" \
     --context-file /tmp/inbox-ctx.json \
     --reply-requested \
     --root "$(pwd)"
   ```

3. Report: file path, topic, summary. Remind user to run `/inbox read` in the other agent.
