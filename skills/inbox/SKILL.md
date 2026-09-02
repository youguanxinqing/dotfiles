---
name: inbox
description: >-
  Local inbox system for AI agent collaboration between Claude Code and Codex
  via structured JSON messages. Use when: send to codex, send to claude, check
  inbox, read inbox, reply to inbox, hand off work, ask codex/claude to review.
argument-hint: "<send|read|reply>"
allowed-tools: Read, Write, Glob, Bash
---

# /inbox

Route based on the first argument:

1. Determine subcommand: `send`, `read`, or `reply`.
   - Explicit argument (e.g. `/inbox send`) — use it directly.
   - No argument but intent is clear from context (e.g. "发给 codex" → send, "看看有没有消息" → read, "回复刚才的" → reply) — infer it.
   - Cannot determine — use AskUserQuestion to present a single-select list:
     - **Read inbox** — check for new messages from the other agent
     - **Send message** — send current conclusions to the other agent
     - **Reply** — reply to the most recently read message
2. Read the corresponding instruction file: `~/.claude/skills/inbox/<subcommand>.md`
3. Follow those instructions exactly.
