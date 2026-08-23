#!/usr/bin/env bash

set -euo pipefail

ROOT="${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}"

new_test_root() {
  TEST_ROOT="$(mktemp -d)"
  TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
  trap 'rm -rf "$TEST_ROOT"' EXIT
}

assert_link() {
  local target="$1" source="$2"
  [[ -L "$target" && "$(readlink "$target")" == "$source" ]] || {
    echo "Expected link $target -> $source" >&2
    exit 1
  }
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || {
    echo "Expected output to contain: $needle" >&2
    exit 1
  }
}
