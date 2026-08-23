#!/usr/bin/env bash

set -euo pipefail

export CARGO_INSTALL_ROOT="${CARGO_INSTALL_ROOT:-$HOME/.local}"
GOUP_BIN="$CARGO_INSTALL_ROOT/bin/goup"

case "${1:-}" in
  check)
    [[ -x "$GOUP_BIN" ]] && [[ -f "$HOME/.goup/env" ]] && command -v go >/dev/null 2>&1
    ;;
  install)
    command -v cargo >/dev/null 2>&1 || {
      echo "cargo is required to install goup.rs." >&2
      exit 1
    }
    [[ -x "$GOUP_BIN" ]] || cargo install goup-rs
    [[ -f "$HOME/.goup/env" ]] || "$GOUP_BIN" init
    command -v go >/dev/null 2>&1 || "$GOUP_BIN" install stable
    ;;
  clean)
    command -v cargo >/dev/null 2>&1 || exit 0
    cargo install --list | grep -q '^goup-rs v' || exit 0
    cargo uninstall goup-rs
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
