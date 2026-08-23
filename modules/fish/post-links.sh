#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
DRY_RUN=0

# Reuse the module engine's ownership checks and state file so these optional
# external-SDK links are as safe to clean as repository-owned links.
# shellcheck source=scripts/module-engine.sh
source "$ROOT/scripts/module-engine.sh"

for command_name in flutter dart; do
  source_path="$HOME/tools/flutter/bin/$command_name"
  [[ -x "$source_path" ]] || continue
  link_one fish "$source_path" "$HOME/.local/bin/$command_name"
done
