#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
cd "$ROOT"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Privacy check must run inside a Git worktree." >&2
  exit 1
}

FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(git ls-files -z --cached --others --exclude-standard)

failed=0
check() {
  local label="$1" pattern="$2" file match line rest safe_rest
  for file in "${FILES[@]}"; do
    [[ "$file" == scripts/check-private.sh || ! -f "$file" ]] && continue
    grep -Iq . "$file" || continue
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      line="${match%%:*}"
      rest="${match#*:}"
      [[ "$label" == "personal home path" && "$rest" == *'/home/linuxbrew/.linuxbrew'* ]] && continue
      if [[ "$label" == "personal home path" && "$rest" == *modules/*/home/* ]]; then
        safe_rest="$(printf '%s\n' "$rest" | sed -E 's#modules/[A-Za-z0-9._-]+/home/#modules/<name>/HOME/#g')"
        printf '%s\n' "$safe_rest" | grep -Eq "$pattern" || continue
      fi
      [[ "$label" == "email address" && ("$rest" == *'git@github.com'* || "$rest" == *'git@bitbucket.com'*) ]] && continue
      printf '%s:%s: possible %s\n' "$file" "$line" "$label" >&2
      failed=1
    done < <(grep -nE "$pattern" "$file" || true)
  done
}

check "secret" 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|BEGIN PGP PRIVATE KEY BLOCK|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{16,}|xox[baprs]-[A-Za-z0-9-]{20,}'
check "personal home path" '/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/'
check "email address" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# A full dotted quad in a private range, nothing shorter. The first two octets
# alone (`10.`, `192.168.`) also match version strings: `v0.10.0` in the Herdr
# plugin list was reported as a private address. Four octets, and no adjacent
# digit or dot on either side, so `1.10.0.0` is a version and `10.0.0.5` is a
# host. Public neighbours such as 172.32.0.1 stay clean.
check "private network address" '(^|[^0-9.])(10(\.[0-9]{1,3}){3}|(172\.(1[6-9]|2[0-9]|3[01])|192\.168)(\.[0-9]{1,3}){2})([^0-9]|$)'

((failed == 0)) || exit 1
echo "No obvious private data found in public files."
