#!/usr/bin/env python3
"""AI Inbox - Local message exchange between Claude Code and Codex.

A file-based inbox system that enables structured JSON message passing
between AI agents through a shared directory structure.

Usage:
    inbox.py init   --root PATH
    inbox.py send   --agent A --to B --topic T --type T --summary S ... --root PATH
    inbox.py list   --agent A [--processed] --root PATH
    inbox.py read   --agent A [--processed] [--keep] --root PATH
"""

import argparse
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = "v1"
ALLOWED_TYPES = {"review_request", "review_result", "question", "answer", "handoff"}
AGENTS = {"claude", "codex"}
INBOX_DIR = ".ai-inbox"


def make_timestamp():
    """UTC timestamp in compact ISO format: YYYYMMDDTHHMMSSZ."""
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def inbox_root(root):
    """Return the .ai-inbox path under the given root."""
    return Path(root) / INBOX_DIR


def agent_inbox(root, agent):
    """Return the inbox directory for an agent."""
    return inbox_root(root) / agent / "inbox"


def agent_processed(root, agent):
    """Return the processed directory for an agent."""
    return inbox_root(root) / agent / "processed"


def message_dir(root, agent, processed=False):
    """Return either the inbox or processed directory for an agent."""
    if processed:
        return agent_processed(root, agent)
    return agent_inbox(root, agent)


def make_message(
    from_agent, to_agent, topic, msg_type, summary, context, reply_requested
):
    """Build a schema-v1 message dict."""
    ts = make_timestamp()
    msg_id = f"{ts}-{from_agent}-to-{to_agent}-{topic}"
    return {
        "schema_version": SCHEMA_VERSION,
        "id": msg_id,
        "from": from_agent,
        "to": to_agent,
        "topic": topic,
        "type": msg_type,
        "summary": summary,
        "context": context,
        "reply_requested": reply_requested,
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def make_filename(timestamp, topic, from_agent, to_agent):
    """Build the message filename: {timestamp}-{topic}-{from}-to-{to}.json."""
    return f"{timestamp}-{topic}-{from_agent}-to-{to_agent}.json"


def atomic_write_json(filepath, data):
    """Write JSON atomically via tempfile + rename."""
    dir_path = os.path.dirname(filepath)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.rename(tmp_path, filepath)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def load_context(args):
    """Load context JSON from --context-file or return empty dict."""
    if not args.context_file:
        return {}
    path = args.context_file
    try:
        if path == "-":
            raw = sys.stdin.read()
        else:
            with open(path, "r", encoding="utf-8") as f:
                raw = f.read()
        if not raw.strip():
            return {}
        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in context: {e}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: context file not found: {path}", file=sys.stderr)
        sys.exit(1)


def validate_agent(agent):
    """Validate agent name."""
    if agent not in AGENTS:
        print(
            f"Error: agent must be one of {sorted(AGENTS)}, got '{agent}'",
            file=sys.stderr,
        )
        sys.exit(1)


def validate_type(msg_type):
    """Validate message type."""
    if msg_type not in ALLOWED_TYPES:
        print(
            f"Error: type must be one of {sorted(ALLOWED_TYPES)}, got '{msg_type}'",
            file=sys.stderr,
        )
        sys.exit(1)


# ─── Subcommands ──────────────────────────────────────────────


def cmd_init(args):
    """Create .ai-inbox directory structure."""
    root = args.root
    created = []
    for agent in sorted(AGENTS):
        for sub in ("inbox", "processed"):
            d = inbox_root(root) / agent / sub
            d.mkdir(parents=True, exist_ok=True)
            created.append(str(d))
    result = {"status": "ok", "created": created}
    print(json.dumps(result, indent=2))


def cmd_send(args):
    """Compose and write a message to target's inbox."""
    validate_agent(args.agent)
    validate_agent(args.to)
    validate_type(args.type)

    if args.agent == args.to:
        print("Error: cannot send message to yourself", file=sys.stderr)
        sys.exit(1)

    context = load_context(args)
    msg = make_message(
        from_agent=args.agent,
        to_agent=args.to,
        topic=args.topic,
        msg_type=args.type,
        summary=args.summary,
        context=context,
        reply_requested=args.reply_requested,
    )

    target_dir = agent_inbox(args.root, args.to)
    target_dir.mkdir(parents=True, exist_ok=True)
    # Also ensure processed dir exists
    agent_processed(args.root, args.to).mkdir(parents=True, exist_ok=True)

    ts = (
        msg["created_at"]
        .replace("-", "")
        .replace(":", "")
        .replace("T", "T")
        .split("+")[0]
    )
    # Use the compact timestamp from the id
    ts_compact = msg["id"].split("-")[0]
    filename = make_filename(ts_compact, args.topic, args.agent, args.to)
    filepath = target_dir / filename

    atomic_write_json(str(filepath), msg)

    result = {
        "status": "ok",
        "path": str(filepath),
        "id": msg["id"],
        "topic": msg["topic"],
        "type": msg["type"],
        "summary": msg["summary"],
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))


def cmd_list(args):
    """List messages in agent's inbox or processed directory."""
    validate_agent(args.agent)
    target_dir = message_dir(args.root, args.agent, processed=args.processed)

    if not target_dir.exists():
        print(json.dumps([]))
        return

    messages = []
    for f in sorted(target_dir.glob("*.json")):
        try:
            with open(f, "r", encoding="utf-8") as fh:
                data = json.load(fh)
            messages.append(
                {
                    "path": str(f),
                    "id": data.get("id", ""),
                    "from": data.get("from", ""),
                    "topic": data.get("topic", ""),
                    "type": data.get("type", ""),
                    "summary": data.get("summary", ""),
                    "created_at": data.get("created_at", ""),
                }
            )
        except (json.JSONDecodeError, OSError) as e:
            print(f"Warning: skipping malformed file {f}: {e}", file=sys.stderr)

    print(json.dumps(messages, indent=2, ensure_ascii=False))


def cmd_read(args):
    """Read latest message from inbox or processed, optionally move to processed."""
    validate_agent(args.agent)
    target_dir = message_dir(args.root, args.agent, processed=args.processed)
    source_name = "processed" if args.processed else "inbox"

    if not target_dir.exists():
        print(
            json.dumps(
                {
                    "status": "empty",
                    "message": f"{source_name.capitalize()} directory does not exist",
                }
            )
        )
        return

    files = sorted(target_dir.glob("*.json"))
    if not files:
        print(
            json.dumps(
                {
                    "status": "empty",
                    "message": (
                        "No processed messages"
                        if args.processed
                        else "No unprocessed messages"
                    ),
                }
            )
        )
        return

    # Read the latest (last in sorted order = most recent timestamp)
    target_file = files[-1]
    try:
        with open(target_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: malformed JSON in {target_file}: {e}", file=sys.stderr)
        sys.exit(1)

    if not args.keep and not args.processed:
        processed_dir = agent_processed(args.root, args.agent)
        processed_dir.mkdir(parents=True, exist_ok=True)
        dest = processed_dir / target_file.name
        target_file.rename(dest)
        data["_meta"] = {"read_from": str(target_file), "moved_to": str(dest)}
    else:
        data["_meta"] = {"read_from": str(target_file), "moved_to": None}

    print(json.dumps(data, indent=2, ensure_ascii=False))


# ─── CLI ──────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="AI Inbox - Local message exchange between Claude Code and Codex"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # init
    p_init = subparsers.add_parser("init", help="Create .ai-inbox directory structure")
    p_init.add_argument("--root", required=True, help="Project root directory")
    p_init.set_defaults(func=cmd_init)

    # send
    p_send = subparsers.add_parser("send", help="Send a message to another agent")
    p_send.add_argument("--agent", required=True, help="Sender identity (claude|codex)")
    p_send.add_argument("--to", required=True, help="Recipient identity (claude|codex)")
    p_send.add_argument("--topic", required=True, help="Message topic (kebab-case)")
    p_send.add_argument("--type", required=True, help="Message type")
    p_send.add_argument("--summary", required=True, help="One-line summary")
    p_send.add_argument(
        "--context-file", default=None, help="Path to context JSON file, or - for stdin"
    )
    p_send.add_argument(
        "--reply-requested", action="store_true", help="Request a reply"
    )
    p_send.add_argument("--root", required=True, help="Project root directory")
    p_send.set_defaults(func=cmd_send)

    # list
    p_list = subparsers.add_parser("list", help="List inbox or processed messages")
    p_list.add_argument("--agent", required=True, help="Agent identity (claude|codex)")
    p_list.add_argument(
        "--processed", action="store_true", help="List messages from processed/"
    )
    p_list.add_argument("--root", required=True, help="Project root directory")
    p_list.set_defaults(func=cmd_list)

    # read
    p_read = subparsers.add_parser("read", help="Read latest inbox or processed message")
    p_read.add_argument("--agent", required=True, help="Agent identity (claude|codex)")
    p_read.add_argument(
        "--processed", action="store_true", help="Read from processed/ instead of inbox/"
    )
    p_read.add_argument("--keep", action="store_true", help="Do not move to processed")
    p_read.add_argument("--root", required=True, help="Project root directory")
    p_read.set_defaults(func=cmd_read)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
