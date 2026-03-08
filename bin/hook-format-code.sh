#!/usr/bin/env bash
# Claude Code hook: auto-format Go and Python files after Claude writes/edits them.
#
# Usage (as a hook):
#   Reads JSON from stdin (provided by Claude Code), extracts tool_input.file_path,
#   then formats the file in place based on its extension.
#
#   Hook config example (settings.json):
#     {
#       "hooks": {
#         "PostToolUse": [{
#           "matcher": "Write|Edit",
#           "hooks": [{ "type": "command", "command": "hook-format-code.sh" }]
#         }]
#       }
#     }
#
# Supported languages:
#   .go  — gofmt
#   .py  — black (quiet) + isort (quiet)
#         Uses pyenv to resolve the virtualenv: sets PYENV_DIR to the file's directory
#         so pyenv reads the nearest .python-version file and locates the correct
#         black/isort. Falls back to system-installed tools if pyenv is unavailable.
#
# Manual usage (for testing):
#   echo '{"tool_input":{"file_path":"path/to/file.py"}}' | hook-format-code.sh

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  awk 'NR>1 && /^#/{ sub(/^# ?/,""); print; next } NR>1 && NF>0 && !/^#/{exit}' "$0"
  exit 0
fi

file_path=$(jq -r '.tool_input.file_path // empty')
[[ -z "$file_path" ]] && exit 0
[[ ! -f "$file_path" ]] && exit 0

case "$file_path" in
  *.go)
    gofmt -w "$file_path"
    ;;
  *.py)
    file_dir=$(cd "$(dirname "$file_path")" && pwd)

    if command -v pyenv &>/dev/null; then
      # PYENV_DIR tells pyenv where to start resolving .python-version,
      # so it picks the correct virtualenv for this project.
      black_cmd=$(PYENV_DIR="$file_dir" pyenv which black 2>/dev/null || true)
      isort_cmd=$(PYENV_DIR="$file_dir" pyenv which isort 2>/dev/null || true)
    fi

    # Fallback to system tools if pyenv didn't find them
    [[ -x "$black_cmd" ]] || black_cmd=$(command -v black 2>/dev/null || true)
    [[ -x "$isort_cmd" ]] || isort_cmd=$(command -v isort 2>/dev/null || true)

    [[ -x "$black_cmd" ]] && "$black_cmd" --quiet "$file_path"
    [[ -x "$isort_cmd" ]] && "$isort_cmd" --quiet "$file_path"
    ;;
esac
