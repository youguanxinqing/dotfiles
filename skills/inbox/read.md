---
description: "Read the latest unprocessed inbox message from another AI agent. Use for: check inbox, read inbox, any messages, what did codex/claude say."
---

# /inbox:read

Read and process the latest unprocessed message from your inbox.

## Identity

- If you are running in Claude Code, you are `claude`
- If you are running in Codex, you are `codex`

## Execution — Claude Code (use native tools, no Bash)

0. **Resolve project root**: Run `git rev-parse --show-toplevel` via Bash to get the absolute path of the repo root. Use this as `{root}` in all subsequent paths. This is necessary because `.ai-inbox` lives at the repo root, but CWD may be a subdirectory. Glob only matches dotdirs (`.ai-inbox`) when the `path` parameter is an absolute path.

1. **Find inbox messages** using Glob with explicit `path`:
   ```
   Glob(pattern=".ai-inbox/claude/inbox/*.json", path="{root}")
   ```

2. **Find already-read messages** using Glob with explicit `path`:
   ```
   Glob(pattern=".ai-inbox/claude/processed/*.json", path="{root}")
   ```

3. **Filter**: Remove any inbox file whose **filename** also exists in processed/. The remaining files are unread.

4. If no unread messages remain, tell the user: "Inbox is empty, no unprocessed messages."

5. If unread messages exist, **read the latest one** (last in sorted order) using the **Read** tool.

6. **Mark as read**: Parse the JSON content, then use the **Write** tool to write the same content to:
   ```
   {root}/.ai-inbox/claude/processed/{same_filename}
   ```

7. Present the summary (see format below).

8. If there were multiple unread messages, inform the user how many remain.

## Execution — Codex (use Python script)

Set `INBOX_PY` to whichever path exists:
- `~/.claude/skills/inbox/scripts/inbox.py`
- `~/.codex/skills/inbox/scripts/inbox.py`

1. List pending messages:
   ```bash
   python3 "$INBOX_PY" list --agent codex --root "$(pwd)"
   ```

2. If empty, tell the user: "Inbox is empty, no unprocessed messages."

3. Read the latest:
   ```bash
   python3 "$INBOX_PY" read --agent codex --root "$(pwd)"
   ```

4. Present the summary (see format below).

## Summary Format

```
From:           <from>
Topic:          <topic>
Type:           <type>
Summary:        <summary>
Goal:           <context.goal>
Related files:  <context.files>
Focus:          <context.focus>
Notes:          <context.notes>
Reply needed:   <reply_requested>
```

Include any additional context fields (decision, findings, risk, questions, answers).

## Special Handling by Type

### review_request
- Proceed to review the referenced files
- Do NOT modify any code unless the message explicitly allows it
- After review, suggest the user run `/inbox reply` to send findings back

### question
- Analyze the questions in context
- Prepare answers based on the current codebase state
- Suggest the user run `/inbox reply` to respond

### handoff
- Understand what was done and what remains
- Prepare to continue the work described in the message

### review_result / answer
- Present the findings/answers to the user
- No reply is typically needed (check `reply_requested`)

## Error Handling

- If `.ai-inbox/` does not exist, tell the user: "No inbox found. The other agent needs to send a message first, or run `/inbox send` to initialize."
- If a message file has invalid JSON, report the filename and error, skip to the next message.
