#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
retired="$HOME/.tmux/bin"
if [[ -L "$retired" && "$(readlink "$retired")" == "$ROOT/configs/tmux/bin" ]]; then
  rm "$retired"
  echo "Removed retired link: $retired"
fi
