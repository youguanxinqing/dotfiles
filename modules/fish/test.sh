#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_BIN="$TEST_ROOT/bin"
mkdir -p "$TEST_BIN"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_BIN/fish"
printf '#!/usr/bin/env bash\nprintf '\''demo:x:1000:1000::/tmp:/bin/bash\\n'\''\n' > "$TEST_BIN/getent"
chmod +x "$TEST_BIN/fish" "$TEST_BIN/getent"

output="$(PATH="$TEST_BIN:/usr/bin:/bin" USER=demo SHELL=/bin/bash \
  "$ROOT/modules/fish/post-install.sh")"
assert_contains "$output" "Run 'chsh -s $TEST_BIN/fish'"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''demo:x:1000:1000::/tmp:%s\n'\'' "$(dirname -- "$0")/fish"' > "$TEST_BIN/getent"
chmod +x "$TEST_BIN/getent"
output="$(PATH="$TEST_BIN:/usr/bin:/bin" USER=demo SHELL=/bin/bash \
  "$ROOT/modules/fish/post-install.sh")"
assert_contains "$output" "Fish is already the login shell: $TEST_BIN/fish"
