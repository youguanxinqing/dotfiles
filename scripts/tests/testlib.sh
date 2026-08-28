#!/usr/bin/env bash

set -euo pipefail

ROOT="${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}"

new_test_root() {
  TEST_ROOT="$(mktemp -d)"
  TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
  trap 'rm -rf "$TEST_ROOT"' EXIT
}

# bash 3.2 的 set -e 不管 [[ ]] / (( )) 失败 —— 只有 4.x 才管，而 test-install.sh 在
# macOS 上跑的 `bash` 就是 3.2。裸写一行 `[[ ... ]]` 当断言等于什么都没断言，所以
# 一律配 `|| die "..."`（`[ ... ]` / test / false 这些简单命令不受影响）。
die() {
  echo "$1" >&2
  exit 1
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
