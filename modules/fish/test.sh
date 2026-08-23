#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

# Generic Linux uses its system package manager and keeps the optional chsh
# behavior.
GENERIC_ROOT="$TEST_ROOT/generic"
GENERIC_HOME="$GENERIC_ROOT/home"
GENERIC_BIN="$GENERIC_ROOT/bin"
GENERIC_OS_RELEASE="$GENERIC_ROOT/os-release"
GENERIC_LOG="$GENERIC_ROOT/packages.log"
mkdir -p "$GENERIC_HOME" "$GENERIC_BIN"
printf 'ID=ubuntu\n' > "$GENERIC_OS_RELEASE"
printf '#!/usr/bin/env bash\necho Linux\n' > "$GENERIC_BIN/uname"
printf '#!/usr/bin/env bash\nexit 0\n' > "$GENERIC_BIN/fish"
printf '#!/usr/bin/env bash\nprintf '\''demo:x:1000:1000::/tmp:/bin/bash\\n'\''\n' > "$GENERIC_BIN/getent"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" >> "$FISH_TEST_LOG"' > "$GENERIC_BIN/apt-get"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'exec "$@"' > "$GENERIC_BIN/sudo"
chmod +x "$GENERIC_BIN/uname" "$GENERIC_BIN/fish" "$GENERIC_BIN/getent" \
  "$GENERIC_BIN/apt-get" "$GENERIC_BIN/sudo"
: > "$GENERIC_LOG"

output="$(PATH="$GENERIC_BIN:/usr/bin:/bin" HOME="$GENERIC_HOME" USER=demo SHELL=/bin/bash \
  DOTFILES_OS_RELEASE="$GENERIC_OS_RELEASE" DOTFILES_OMARCHY_ROOT="$GENERIC_ROOT/no-omarchy" \
  "$ROOT/modules/fish/post-install.sh")"
assert_contains "$output" "Run 'chsh -s $GENERIC_BIN/fish'"

PATH="$GENERIC_BIN:/usr/bin:/bin" HOME="$GENERIC_HOME" \
  DOTFILES_OS_RELEASE="$GENERIC_OS_RELEASE" DOTFILES_OMARCHY_ROOT="$GENERIC_ROOT/no-omarchy" \
  FISH_TEST_LOG="$GENERIC_LOG" "$ROOT/modules/fish/install.sh" install
grep -Fqx 'update' "$GENERIC_LOG"
grep -Fqx 'install -y fish' "$GENERIC_LOG"
grep -Fqx 'apt' "$GENERIC_HOME/.local/state/dotfiles/fish-installer"

UNOWNED_HOME="$GENERIC_ROOT/unowned-home"
mkdir -p "$UNOWNED_HOME"
package_log_size="$(wc -l < "$GENERIC_LOG" | tr -d ' ')"
output="$(PATH="$GENERIC_BIN:/usr/bin:/bin" HOME="$UNOWNED_HOME" USER=demo SHELL=/bin/bash \
  DOTFILES_OS_RELEASE="$GENERIC_OS_RELEASE" DOTFILES_OMARCHY_ROOT="$GENERIC_ROOT/no-omarchy" \
  FISH_TEST_LOG="$GENERIC_LOG" "$ROOT/modules/fish/install.sh" clean)"
assert_contains "$output" "this dotfiles installer did not record installing it"
[[ "$(wc -l < "$GENERIC_LOG" | tr -d ' ')" == "$package_log_size" ]]

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''demo:x:1000:1000::/tmp:%s\n'\'' "$(dirname -- "$0")/fish"' > "$GENERIC_BIN/getent"
chmod +x "$GENERIC_BIN/getent"
output="$(PATH="$GENERIC_BIN:/usr/bin:/bin" HOME="$GENERIC_HOME" USER=demo SHELL=/bin/bash \
  DOTFILES_OS_RELEASE="$GENERIC_OS_RELEASE" DOTFILES_OMARCHY_ROOT="$GENERIC_ROOT/no-omarchy" \
  "$ROOT/modules/fish/post-install.sh")"
assert_contains "$output" "Fish is already the login shell: $GENERIC_BIN/fish"

# Omarchy installs its integration package, keeps Bash as the login shell, and
# manages only a bounded handoff block in the user's existing .bashrc.
OMARCHY_TEST_ROOT="$TEST_ROOT/omarchy"
OMARCHY_TEST_HOME="$OMARCHY_TEST_ROOT/home"
OMARCHY_TEST_BIN="$OMARCHY_TEST_ROOT/bin"
OMARCHY_OS_RELEASE="$OMARCHY_TEST_ROOT/os-release"
OMARCHY_LOG="$OMARCHY_TEST_ROOT/omarchy.log"
CHSH_LOG="$OMARCHY_TEST_ROOT/chsh.log"
BASHRC="$OMARCHY_TEST_HOME/.bashrc"
ORIGINAL_BASHRC="$OMARCHY_TEST_ROOT/original.bashrc"
BACKUP_DIR="$OMARCHY_TEST_ROOT/backups"
mkdir -p "$OMARCHY_TEST_HOME" "$OMARCHY_TEST_BIN"
printf 'ID=omarchy\nID_LIKE=arch\n' > "$OMARCHY_OS_RELEASE"
printf '#!/usr/bin/env bash\necho Linux\n' > "$OMARCHY_TEST_BIN/uname"
printf '#!/usr/bin/env bash\nexit 0\n' > "$OMARCHY_TEST_BIN/fish"
printf '#!/usr/bin/env bash\nexit 0\n' > "$OMARCHY_TEST_BIN/omarchy-setup-fish"
printf '#!/usr/bin/env bash\nprintf '\''demo:x:1000:1000::/tmp:/usr/bin/bash\\n'\''\n' > "$OMARCHY_TEST_BIN/getent"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" >> "$OMARCHY_TEST_LOG"' > "$OMARCHY_TEST_BIN/omarchy"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" >> "$FISH_CHSH_LOG"' > "$OMARCHY_TEST_BIN/chsh"
chmod +x "$OMARCHY_TEST_BIN/uname" "$OMARCHY_TEST_BIN/fish" \
  "$OMARCHY_TEST_BIN/omarchy-setup-fish" "$OMARCHY_TEST_BIN/getent" \
  "$OMARCHY_TEST_BIN/omarchy" "$OMARCHY_TEST_BIN/chsh"

# Older/custom Omarchy installations can still be recognized when os-release
# is generic Arch, as long as both the command and installation root exist.
OMARCHY_COMPAT_OS_RELEASE="$OMARCHY_TEST_ROOT/compat-os-release"
OMARCHY_COMPAT_ROOT="$OMARCHY_TEST_ROOT/compat-root"
printf 'ID=arch\n' > "$OMARCHY_COMPAT_OS_RELEASE"
mkdir -p "$OMARCHY_COMPAT_ROOT"
PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" DOTFILES_OS_RELEASE="$OMARCHY_COMPAT_OS_RELEASE" \
  DOTFILES_OMARCHY_ROOT="$OMARCHY_COMPAT_ROOT" \
  bash -c 'source "$1"; fish_is_omarchy' _ "$ROOT/modules/fish/platform.sh"

printf '# original bashrc\nexport KEEP_ME=1\n' > "$BASHRC"
cp "$BASHRC" "$ORIGINAL_BASHRC"
: > "$OMARCHY_LOG"
: > "$CHSH_LOG"

PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$OMARCHY_TEST_HOME" \
  DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" "$ROOT/modules/fish/install.sh" check
PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$OMARCHY_TEST_HOME" \
  DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" OMARCHY_TEST_LOG="$OMARCHY_LOG" \
  "$ROOT/modules/fish/install.sh" install
grep -Fqx 'pkg add omarchy-fish' "$OMARCHY_LOG"

output="$(PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$OMARCHY_TEST_HOME" \
  USER=demo SHELL=/usr/bin/bash DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" \
  DOTFILES_BASHRC="$BASHRC" DOTFILES_BACKUP_DIR="$BACKUP_DIR" \
  OMARCHY_TEST_LOG="$OMARCHY_LOG" FISH_CHSH_LOG="$CHSH_LOG" \
  "$ROOT/modules/fish/post-install.sh")"
assert_contains "$output" "Omarchy detected: Bash remains the login shell"
[[ "$(head -n 1 "$BASHRC")" == '# >>> dotfiles omarchy fish >>>' ]]
grep -Fqx '# original bashrc' "$BASHRC"
grep -Fqx 'export KEEP_ME=1' "$BASHRC"
grep -Fq 'exec fish --login' "$BASHRC"
[[ ! -s "$CHSH_LOG" ]]

first_checksum="$(cksum "$BASHRC")"
first_backup_count="$(find "$BACKUP_DIR" -type f -name 'bashrc.*' | wc -l | tr -d ' ')"
output="$(PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$OMARCHY_TEST_HOME" \
  USER=demo SHELL=/usr/bin/bash DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" \
  DOTFILES_BASHRC="$BASHRC" DOTFILES_BACKUP_DIR="$BACKUP_DIR" \
  "$ROOT/modules/fish/post-install.sh")"
assert_contains "$output" "handoff is already configured"
[[ "$(cksum "$BASHRC")" == "$first_checksum" ]]
[[ "$(find "$BACKUP_DIR" -type f -name 'bashrc.*' | wc -l | tr -d ' ')" == "$first_backup_count" ]]

# On Omarchy itself, apply the handoff to the exact first-login Bash template
# in a temporary home. The packaged file remains read-only.
if [[ -r /etc/os-release ]] && grep -Eq '^ID="?omarchy"?$' /etc/os-release && \
  [[ -f /etc/skel/.bashrc ]]; then
  SKEL_TEST_HOME="$OMARCHY_TEST_ROOT/skel-home"
  SKEL_BASHRC="$SKEL_TEST_HOME/.bashrc"
  SKEL_BACKUPS="$OMARCHY_TEST_ROOT/skel-backups"
  mkdir -p "$SKEL_TEST_HOME"
  cp -p /etc/skel/.bashrc "$SKEL_BASHRC"
  PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$SKEL_TEST_HOME" \
    USER=demo SHELL=/usr/bin/bash DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" \
    DOTFILES_BASHRC="$SKEL_BASHRC" DOTFILES_BACKUP_DIR="$SKEL_BACKUPS" \
    "$ROOT/modules/fish/post-install.sh" >/dev/null
  [[ "$(head -n 1 "$SKEL_BASHRC")" == '# >>> dotfiles omarchy fish >>>' ]]
  grep -Fq 'source "$OMARCHY_PATH/default/bash/rc"' "$SKEL_BASHRC"
  [[ "$(find "$SKEL_BACKUPS" -type f -name 'bashrc.*' | wc -l | tr -d ' ')" == 1 ]]
fi

PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$OMARCHY_TEST_HOME" \
  DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" DOTFILES_BASHRC="$BASHRC" \
  DOTFILES_BACKUP_DIR="$BACKUP_DIR" OMARCHY_TEST_LOG="$OMARCHY_LOG" \
  "$ROOT/modules/fish/install.sh" clean
cmp -s "$BASHRC" "$ORIGINAL_BASHRC"
grep -Fqx 'pkg drop omarchy-fish' "$OMARCHY_LOG"

# An existing symlink is user-owned; the handoff refuses to replace it.
SYMLINK_HOME="$OMARCHY_TEST_ROOT/symlink-home"
SYMLINK_SOURCE="$OMARCHY_TEST_ROOT/symlink-source"
mkdir -p "$SYMLINK_HOME"
printf '# managed elsewhere\n' > "$SYMLINK_SOURCE"
ln -s "$SYMLINK_SOURCE" "$SYMLINK_HOME/.bashrc"
if output="$(PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$SYMLINK_HOME" \
  USER=demo SHELL=/usr/bin/bash DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" \
  DOTFILES_BASHRC="$SYMLINK_HOME/.bashrc" DOTFILES_BACKUP_DIR="$BACKUP_DIR" \
  "$ROOT/modules/fish/post-install.sh" 2>&1)"; then
  echo "Omarchy Fish handoff replaced an unmanaged symlink." >&2
  exit 1
fi
assert_contains "$output" "Refusing to replace symlinked Bash configuration"
[[ -L "$SYMLINK_HOME/.bashrc" ]]
grep -Fqx '# managed elsewhere' "$SYMLINK_SOURCE"

# A machine previously changed with chsh is reported instead of silently
# leaving an unsafe Omarchy login-shell configuration behind.
printf '#!/usr/bin/env bash\nprintf '\''demo:x:1000:1000::/tmp:%s\n'\'' "$(dirname -- "$0")/fish"\n' > "$OMARCHY_TEST_BIN/getent"
chmod +x "$OMARCHY_TEST_BIN/getent"
if output="$(PATH="$OMARCHY_TEST_BIN:/usr/bin:/bin" HOME="$OMARCHY_TEST_HOME" \
  USER=demo SHELL=/usr/bin/fish DOTFILES_OS_RELEASE="$OMARCHY_OS_RELEASE" \
  DOTFILES_BASHRC="$BASHRC" DOTFILES_BACKUP_DIR="$BACKUP_DIR" \
  "$ROOT/modules/fish/post-install.sh" 2>&1)"; then
  echo "Omarchy accepted Fish as the login shell." >&2
  exit 1
fi
assert_contains "$output" "Omarchy must keep Bash as the login shell"
cmp -s "$BASHRC" "$ORIGINAL_BASHRC"
