#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"

# Syntax coverage is discovered from Git-visible files: every *.sh, plus any
# file whose first line is a bash shebang — most of bin/ has no extension. A
# new module or adapter automatically joins both the current Bash and macOS
# Bash 3.2 checks.
bash_shebang() {
  local first
  # Bounded read: git-visible files include fonts, and a binary may have no
  # newline for read to stop at.
  first="$(head -c 64 "$1" 2>/dev/null)" || return 1
  first="${first%%$'\n'*}"
  case "$first" in
    '#!'*bash*) return 0 ;;
  esac
  return 1
}

checked=0
while IFS= read -r script; do
  [[ -n "$script" && -f "$ROOT/$script" ]] || continue
  case "$script" in
    *.sh) ;;
    *) bash_shebang "$ROOT/$script" || continue ;;
  esac
  bash -n "$ROOT/$script"
  if [[ -x /bin/bash ]]; then
    /bin/bash -n "$ROOT/$script"
  fi
  checked=$((checked + 1))
done < <(git -C "$ROOT" ls-files --cached --others --exclude-standard | sort)
# Discovery matching nothing means discovery broke, not that the repo is clean.
[[ $checked -gt 0 ]] || { echo "No shell scripts discovered." >&2; exit 1; }
echo "Syntax-checked $checked shell scripts (bash + /bin/bash 3.2)."

export DOTFILES_TEST_ROOT="$ROOT"
found=0
for test in "$ROOT"/scripts/tests/*.test.sh "$ROOT"/modules/*/test.sh; do
  [[ -f "$test" ]] || continue
  found=1
  bash "$test"
done
((found)) || { echo "No tests discovered." >&2; exit 1; }

echo "Install checks passed."
