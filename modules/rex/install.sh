#!/usr/bin/env bash

# rex-flash, the picker behind ctrl+b s. It tracks master, like the herdr-flash
# plugin it builds on; there are no tags yet. A remote Rex host needs it too:
# its floats run there.
set -euo pipefail

export CARGO_INSTALL_ROOT="${CARGO_INSTALL_ROOT:-$HOME/.local}"
BIN="$CARGO_INSTALL_ROOT/bin/rex-flash"

case "${1:-}" in
  check)
    [[ -x "$BIN" ]]
    ;;
  install)
    command -v cargo >/dev/null 2>&1 || {
      echo "cargo is required to install rex-flash." >&2
      exit 1
    }
    cargo install --locked --git https://github.com/youguanxinqing/rex-flash
    ;;
  clean)
    [[ -x "$BIN" ]] || exit 0
    cargo uninstall rex-flash
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
