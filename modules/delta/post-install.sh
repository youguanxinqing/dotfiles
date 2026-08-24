#!/usr/bin/env bash

set -euo pipefail

command -v git >/dev/null 2>&1 || {
  echo "git is required to configure delta." >&2
  exit 1
}

git config --global --get core.pager >/dev/null 2>&1 || git config --global core.pager delta
git config --global --get interactive.diffFilter >/dev/null 2>&1 || git config --global interactive.diffFilter "delta --color-only"
git config --global --get delta.navigate >/dev/null 2>&1 || git config --global delta.navigate true
git config --global --get merge.conflictStyle >/dev/null 2>&1 || git config --global merge.conflictStyle zdiff3
