---
description: "Reply to the most recently read inbox message from another AI agent. Use for: reply to inbox, send reply, respond to codex/claude, send back review results or answers."
---

# /inbox:reply

Generate a structured reply to the most recently read inbox message and send it back to the original sender.

## Identity

- If you are running in Claude Code, you are `claude`, reply goes to `codex`
- If you are running in Codex, you are `codex`, reply goes to `claude`

## Determining Reply Parameters

Look at the most recently processed message (the one you read via `/inbox read`) to determine:

- **topic**: MUST be the same as the original message's topic
- **type**: Infer from the original message type:

| Original type | Reply type |
|---|---|
| `review_request` | `review_result` |
| `question` | `answer` |
| `handoff` | `handoff` |
| other | infer from context |

## How to Distill Reply Context

For `review_result`, include:
- **decision**: `"approved"`, `"changes_requested"`, or `"needs_discussion"`
- **findings**: List of specific observations
- **risk**: Any identified risks (list)
- **notes**: Actionable next steps or suggestions

For `answer`, include:
- **answers**: List of answers corresponding to the questions
- **notes**: Additional context or caveats

For `handoff`, include:
- **goal**: Updated goal or next phase description
- **decision**: What was decided
- **files**: Files touched or relevant
- **notes**: What the next agent should know

## Execution — Claude Code (use native tools, no Bash)

0. **Resolve project root**: Run `git rev-parse --show-toplevel` via Bash to get the absolute path of the repo root. Use this as `{root}` in all subsequent paths. This is necessary because `.ai-inbox` lives at the repo root, but CWD may be a subdirectory. Glob only matches dotdirs (`.ai-inbox`) when the `path` parameter is an absolute path.

1. If you don't have context about a recently read message, find the latest processed message:
   ```
   Glob(pattern=".ai-inbox/claude/processed/*.json", path="{root}")
   ```
   Then **Read** the last file (sorted) to recover the original topic and type.

2. Generate a UTC timestamp in compact format: `YYYYMMDDTHHMMSSZ`

3. Construct the reply message JSON:
   ```json
   {
     "schema_version": "v1",
     "id": "{timestamp}-claude-to-codex-{topic}",
     "from": "claude",
     "to": "codex",
     "topic": "{original_topic}",
     "type": "{reply_type}",
     "summary": "{one-line summary}",
     "context": {
       "decision": "...",
       "findings": [],
       "risk": [],
       "notes": "..."
     },
     "reply_requested": false,
     "created_at": "{ISO 8601 UTC}"
   }
   ```

4. Write the reply using the **Write** tool to:
   ```
   {root}/.ai-inbox/codex/inbox/{timestamp}-{topic}-claude-to-codex.json
   ```

5. Report: file path, topic, summary. Remind user to run `/inbox read` in Codex.

## Execution — Codex (use Python script)

Set `INBOX_PY` to whichever path exists:
- `~/.claude/skills/inbox/scripts/inbox.py`
- `~/.codex/skills/inbox/scripts/inbox.py`

1. If you don't have context about a recently read message, read the latest processed message:
   ```bash
   python3 "$INBOX_PY" read --agent codex --processed --keep --root "$(pwd)"
   ```
   Use that JSON to recover the original topic and type.

2. Write reply context JSON to a temp file, then send:
   ```bash
   cat > /tmp/inbox-reply-ctx.json << 'CTXEOF'
   {"decision": "...", "findings": [...], "risk": [...], "notes": "..."}
   CTXEOF

   python3 "$INBOX_PY" send \
     --agent codex \
     --to claude \
     --topic <ORIGINAL_TOPIC> \
     --type <REPLY_TYPE> \
     --summary "<one-line summary>" \
     --context-file /tmp/inbox-reply-ctx.json \
     --root "$(pwd)"
   ```

3. Report: file path, topic, summary. Remind user to run `/inbox read` in Claude Code.
