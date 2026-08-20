#!/usr/bin/env bash

set -euo pipefail

case "${1:-}" in
  check)
    command -v goup >/dev/null 2>&1 && [[ -f "$HOME/.goup/env" ]] && command -v go >/dev/null 2>&1
    ;;
  install)
    command -v cargo >/dev/null 2>&1 || {
      echo "cargo is required to install goup.rs." >&2
      exit 1
    }
    command -v goup >/dev/null 2>&1 || cargo install goup-rs
    [[ -f "$HOME/.goup/env" ]] || goup init
    command -v go >/dev/null 2>&1 || goup install stable
    ;;
  clean)
    command -v cargo >/dev/null 2>&1 || exit 0
    cargo install --list | grep -Fq '^goup-rs v' || exit 0
    cargo uninstall goup-rs
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
