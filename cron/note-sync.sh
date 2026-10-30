#!/usr/bin/env bash
set -euo pipefail

repo=${1:?Usage: note-sync.sh REPOSITORY}
cd -- "$repo"
top=$(git rev-parse --show-toplevel)
[[ "$PWD" -ef "$top" ]] || { echo 'Expected the repository root' >&2; exit 1; }

# A timer and a manual run must never operate on the index at the same time.
exec 9>"$(git rev-parse --git-path note-sync.lock)"
flock -n 9 || exit 0

for marker in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD REVERT_HEAD; do
  if [[ -e "$(git rev-parse --git-path "$marker")" ]]; then
    echo "Unfinished Git operation ($marker); resolve it before syncing." >&2
    exit 1
  fi
done

branch=$(git symbolic-ref --quiet --short HEAD)
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')
remote=$(git config --get "branch.$branch.remote")
target=$(git config --get "branch.$branch.merge")
[[ "$remote" != . ]] || { echo 'Expected a remote upstream' >&2; exit 1; }
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=20'

printf '%s Syncing %s (%s -> %s)\n' "$(date -Is)" "$repo" "$branch" "$upstream"
git add --all
if ! git diff --cached --quiet; then
  git commit -m "auto-commit $(date '+%Y-%m-%d %H:%M:%S %z')"
fi
git -c fetch.recurseSubmodules=false pull --rebase "$remote" "$target"
git push "$remote" "HEAD:$target"
