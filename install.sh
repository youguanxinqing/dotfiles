#!/usr/bin/env bash

set -eo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
MODE=all
ACTION=install
DRY_RUN=0
CONFIGS=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [--deps-only | --links-only] [--dry-run] [module ...]
       ./install.sh clean [--dry-run] <module>
       ./install.sh list

With no options, install dependencies and links for every default module that
matches this platform. Modules are discovered from modules/*/module.ini; adding
a module never requires editing this installer.
EOF
}

case "${1:-}" in
  clean) ACTION=clean; shift ;;
  list) ACTION=list; shift ;;
esac

while (($#)); do
  case "$1" in
    --deps-only) MODE=deps ;;
    --links-only) MODE=links ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) CONFIGS+=("$1") ;;
  esac
  shift
done

# shellcheck source=scripts/module-engine.sh
source "$ROOT/scripts/module-engine.sh"

discover_modules

if [[ "$ACTION" == list ]]; then
  ((${#CONFIGS[@]} == 0)) || { usage >&2; exit 2; }
  list_modules
  exit 0
fi

if [[ "$ACTION" == clean ]]; then
  [[ "$MODE" == all && ${#CONFIGS[@]} -eq 1 ]] || { usage >&2; exit 2; }
  select_modules "${CONFIGS[0]}"
  clean_selected_module "${CONFIGS[0]}"
  exit 0
fi

select_modules "${CONFIGS[@]}"

if [[ "$MODE" != links ]]; then
  install_selected_dependencies
fi

if [[ "$MODE" != deps ]]; then
  link_selected_modules
  run_selected_hooks post-links.sh
fi

if [[ "$MODE" != links ]]; then
  run_selected_hooks post-install.sh
fi
