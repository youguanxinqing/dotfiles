#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"

# Syntax coverage is discovered from Git-visible shell files. A new module or
# adapter automatically joins both the current Bash and macOS Bash 3.2 checks.
while IFS= read -r script; do
  [[ -n "$script" && -f "$ROOT/$script" ]] || continue
  bash -n "$ROOT/$script"
  if [[ -x /bin/bash ]]; then
    /bin/bash -n "$ROOT/$script"
  fi
done < <(git -C "$ROOT" ls-files --cached --others --exclude-standard -- '*.sh' | sort)

export DOTFILES_TEST_ROOT="$ROOT"
found=0
for test in "$ROOT"/scripts/tests/*.test.sh "$ROOT"/modules/*/test.sh; do
  [[ -f "$test" ]] || continue
  found=1
  bash "$test"
done
((found)) || { echo "No tests discovered." >&2; exit 1; }

echo "Install checks passed."
