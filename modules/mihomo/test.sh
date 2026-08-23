#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_HOME="$TEST_ROOT/home"
TEST_BIN_DIR="$TEST_ROOT/bin"
TEST_CONFIG="$TEST_HOME/.config/mihomo"
TEST_UNIT="$TEST_HOME/.config/systemd/user/mihomo.service"
FIXTURE="$TEST_ROOT/mihomo.gz"
CAP_STATE="$TEST_ROOT/capabilities"
SYSTEMCTL_LOG="$TEST_ROOT/systemctl.log"
mkdir -p "$TEST_HOME/.local/bin" "$TEST_CONFIG" "$(dirname "$TEST_UNIT")" "$TEST_BIN_DIR"

printf '#!/usr/bin/env bash\necho "Mihomo Meta v1.19.30 linux amd64 with go1.test"\n' > "$TEST_ROOT/mihomo"
chmod +x "$TEST_ROOT/mihomo"
gzip -c "$TEST_ROOT/mihomo" > "$FIXTURE"
FIXTURE_SHA="$(sha256sum "$FIXTURE" | awk '{print $1}')"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s cap_net_admin,cap_net_raw=ep\n" "$2" > "$MIHOMO_TEST_CAP_STATE"' > "$TEST_BIN_DIR/setcap"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'cat "$MIHOMO_TEST_CAP_STATE"' > "$TEST_BIN_DIR/getcap"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >> "$MIHOMO_TEST_SYSTEMCTL_LOG"' > "$TEST_BIN_DIR/systemctl"
chmod +x "$TEST_BIN_DIR/setcap" "$TEST_BIN_DIR/getcap" "$TEST_BIN_DIR/systemctl"

printf 'legacy unit\n' > "$TEST_UNIT"
printf 'mixed-port: 7890\n' > "$TEST_CONFIG/config.yaml"
: > "$SYSTEMCTL_LOG"

run_installer() {
  HOME="$TEST_HOME" \
    MIHOMO_BIN="$TEST_HOME/.local/bin/mihomo" \
    MIHOMO_CONFIG_DIR="$TEST_CONFIG" \
    MIHOMO_UNIT_TARGET="$TEST_UNIT" \
    MIHOMO_ARCH=x86_64 \
    MIHOMO_DOWNLOAD_URL="file://$FIXTURE" \
    MIHOMO_SHA256="$FIXTURE_SHA" \
    MIHOMO_SETCAP="$TEST_BIN_DIR/setcap" \
    MIHOMO_GETCAP="$TEST_BIN_DIR/getcap" \
    MIHOMO_ROOT_RUNNER=/usr/bin/env \
    MIHOMO_SYSTEMCTL="$TEST_BIN_DIR/systemctl" \
    MIHOMO_TEST_CAP_STATE="$CAP_STATE" \
    MIHOMO_TEST_SYSTEMCTL_LOG="$SYSTEMCTL_LOG" \
    "$ROOT/modules/mihomo/install.sh" "$1"
}

run_installer install >/dev/null
run_installer check
[[ -x "$TEST_HOME/.local/bin/mihomo" ]]
assert_link "$TEST_UNIT" "$ROOT/modules/mihomo/mihomo.service"
[[ "$(find "$(dirname "$TEST_UNIT")" -maxdepth 1 -name 'mihomo.service.backup.*' | wc -l)" -eq 1 ]]
grep -Fq 'cap_net_admin,cap_net_raw=ep' "$CAP_STATE"
grep -Fqx -- '--user daemon-reload' "$SYSTEMCTL_LOG"
grep -Fqx -- '--user enable mihomo.service' "$SYSTEMCTL_LOG"
grep -Fqx -- '--user restart mihomo.service' "$SYSTEMCTL_LOG"

# Re-running does not download again or create another service backup.
run_installer install >/dev/null
[[ "$(find "$(dirname "$TEST_UNIT")" -maxdepth 1 -name 'mihomo.service.backup.*' | wc -l)" -eq 1 ]]
