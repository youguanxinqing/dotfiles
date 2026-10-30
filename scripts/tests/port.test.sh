#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

BIN="$ROOT/bin/port"

command -v lsof >/dev/null && command -v python3 >/dev/null || {
  echo "port.test.sh: skipped (needs lsof and python3)"
  exit 0
}

# 真起一个 listener：port 0 让内核挑空闲端口，不会撞上本机正在跑的服务。
(cd "$TEST_ROOT" && exec python3 -c '
import socket, time
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen()
print(s.getsockname()[1], flush=True)
time.sleep(60)
' >"$TEST_ROOT/portno") &
server=$!
disown "$server"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$TEST_ROOT"' EXIT

for ((i = 0; i < 50; i++)); do
  [[ -s "$TEST_ROOT/portno" ]] && break
  sleep 0.1
done
p=$(cat "$TEST_ROOT/portno")
[[ -n $p ]] || die "Test listener never reported its port."

out=$("$BIN" search "$p")
assert_contains "$out" "pid   $server"
assert_contains "$out" "cwd   $TEST_ROOT"
assert_contains "$out" "addr  127.0.0.1:$p"

"$BIN" search 0 >/dev/null 2>&1 && die "Port 0 was accepted."
"$BIN" search 65536 >/dev/null 2>&1 && die "Port 65536 was accepted."

out=$("$BIN" kill "$p")
assert_contains "$out" "TCP $p is free"
kill -0 "$server" 2>/dev/null && die "Listener survived port kill."

"$BIN" search "$p" >/dev/null 2>&1 && die "search still found a listener after kill."
exit 0
