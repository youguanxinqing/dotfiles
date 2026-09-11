#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

BIN="$ROOT/bin/herdr-scratch-resync"

STATE="$TEST_ROOT/state"
mkdir -p "$STATE" "$TEST_ROOT/bin"

# stale: pane 还在但 terminal_id 是重启前那个 —— 就是 popup 闪退的那条。
# fresh: 已经对上，不该被动。
# gone:  pane 整个没了 —— handle 清掉让 toggle 重建。
# noop:  从来没开过，handle 是 null。
write_registry() {
  cat >"$STATE/registry.json" <<'EOF'
{
  "version": 2,
  "scratchpads": {
    "workspace:w1:scratch": {
      "status": "available",
      "handle": { "kind": "herdr_popup", "pane_id": "wA:p2", "terminal_id": "term_old" }
    },
    "workspace:w2:scratch": {
      "status": "available",
      "handle": { "kind": "herdr_popup", "pane_id": "wB:p2", "terminal_id": "term_fresh" }
    },
    "workspace:w3:scratch": {
      "status": "available",
      "handle": { "kind": "herdr_popup", "pane_id": "wC:p2", "terminal_id": "term_dead" }
    },
    "workspace:w4:scratch": { "status": "closed", "handle": null }
  }
}
EOF
}

fake_herdr() {
  printf '%s\n' '#!/usr/bin/env bash' "printf '%s' '$1'" >"$TEST_ROOT/bin/herdr"
  chmod +x "$TEST_ROOT/bin/herdr"
}

run_resync() {
  PATH="$TEST_ROOT/bin:$TEST_SYSTEM_PATH" HERDR_BIN_PATH="$TEST_ROOT/bin/herdr" \
    HERDR_PLUGIN_STATE_DIR="$STATE" "$BIN"
}

field() {
  jq -r ".scratchpads[\"$1\"].$2" "$STATE/registry.json"
}

write_registry
fake_herdr '{"id":"cli:pane:list","result":{"panes":[{"pane_id":"wA:p2","terminal_id":"term_new"},{"pane_id":"wB:p2","terminal_id":"term_fresh"}]}}'
out=$(run_resync)
assert_contains "$out" "resynced registry handles"
[[ "$(field 'workspace:w1:scratch' 'handle.terminal_id')" == term_new ]] ||
  die "Stale terminal_id was not rewritten to the live one."
[[ "$(field 'workspace:w2:scratch' 'handle.terminal_id')" == term_fresh ]] ||
  die "An already-live handle was rewritten."
[[ "$(field 'workspace:w3:scratch' 'handle')" == null ]] ||
  die "A handle whose pane is gone was kept."
[[ "$(field 'workspace:w3:scratch' 'status')" == closed ]] ||
  die "A scratchpad whose pane is gone was left available."
[[ "$(field 'workspace:w4:scratch' 'handle')" == null ]] ||
  die "A never-opened scratchpad was touched."

# 第二次跑什么都不该改：这个脚本每按一次 prefix+p 都跑。
before=$(cat "$STATE/registry.json")
out=$(run_resync)
[[ -z "$out" ]] || die "A no-op resync still reported a change."
[[ "$(cat "$STATE/registry.json")" == "$before" ]] || die "A no-op resync rewrote the registry."

# backing server 没起：herdr 退 0 但只返回 error，registry 必须原样不动。
write_registry
before=$(cat "$STATE/registry.json")
fake_herdr '{"id":"cli:pane:list","error":{"code":"server_not_running","message":"no herdr server is running"}}'
run_resync >/dev/null
[[ "$(cat "$STATE/registry.json")" == "$before" ]] ||
  die "A not-running backing server wiped the registry handles."
