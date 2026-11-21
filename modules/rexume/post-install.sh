#!/usr/bin/env bash

set -euo pipefail

# rexume install 写各运行时的 hook 和后台 job，重复跑只保留一份、不动别的 hook。
# 它写进 job 的是 rexume 和 rex 在 PATH 上的路径（不解析软链），brew upgrade 后仍有效。
# Codex 的 hook 要在 Codex 里 /hooks 手动信任一次，脚本做不了。
command -v rexume >/dev/null 2>&1 || { echo "rexume is not installed; skipping its hooks." >&2; exit 0; }
command -v rex >/dev/null 2>&1 || { echo "rex is not on PATH; skipping rexume install." >&2; exit 0; }
rexume install >/dev/null
echo "rexume: hooks and daemon installed (in Codex, trust 'rexume report codex' under /hooks)."
