#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

new_path() {
  local name=$1 platform=$2
  ADAPTER_BIN="$TEST_ROOT/$name"
  mkdir -p "$ADAPTER_BIN"
  ln -s "$TEST_BASH_BIN" "$ADAPTER_BIN/bash"
  ln -s "$(command -v cat)" "$ADAPTER_BIN/cat"
  printf '#!/usr/bin/env bash\nprintf '\''%%s\\n'\'' '\''%s'\''\n' "$platform" > "$ADAPTER_BIN/uname"
  chmod +x "$ADAPTER_BIN/uname"
}

capture_stdin() {
  local command_path=$1
  printf '#!/usr/bin/env bash\ncat > "$ADAPTER_TEST_LOG"\n' > "$command_path"
  chmod +x "$command_path"
}

# macOS uses pbcopy.
new_path mac-copy Darwin
capture_stdin "$ADAPTER_BIN/pbcopy"
printf 'mac clipboard' | PATH="$ADAPTER_BIN" ADAPTER_TEST_LOG="$TEST_ROOT/mac-copy.log" \
  "$ROOT/bin/g-copy"
[[ $(<"$TEST_ROOT/mac-copy.log") == 'mac clipboard' ]]

# Linux selects the backend that belongs to the active display session.
new_path wayland-copy Linux
capture_stdin "$ADAPTER_BIN/wl-copy"
printf 'wayland clipboard' | PATH="$ADAPTER_BIN" WAYLAND_DISPLAY=wayland-1 \
  ADAPTER_TEST_LOG="$TEST_ROOT/wayland-copy.log" "$ROOT/bin/g-copy"
[[ $(<"$TEST_ROOT/wayland-copy.log") == 'wayland clipboard' ]]

new_path xclip-copy Linux
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" > "$ADAPTER_ARGS_LOG"' \
  'cat > "$ADAPTER_TEST_LOG"' > "$ADAPTER_BIN/xclip"
chmod +x "$ADAPTER_BIN/xclip"
printf 'xclip clipboard' | PATH="$ADAPTER_BIN" DISPLAY=:1 \
  ADAPTER_ARGS_LOG="$TEST_ROOT/xclip-args.log" ADAPTER_TEST_LOG="$TEST_ROOT/xclip-copy.log" \
  "$ROOT/bin/g-copy"
grep -Fqx -- '-selection clipboard' "$TEST_ROOT/xclip-args.log"
[[ $(<"$TEST_ROOT/xclip-copy.log") == 'xclip clipboard' ]]

new_path xsel-copy Linux
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" > "$ADAPTER_ARGS_LOG"' \
  'cat > "$ADAPTER_TEST_LOG"' > "$ADAPTER_BIN/xsel"
chmod +x "$ADAPTER_BIN/xsel"
printf 'xsel clipboard' | PATH="$ADAPTER_BIN" DISPLAY=:1 \
  ADAPTER_ARGS_LOG="$TEST_ROOT/xsel-args.log" ADAPTER_TEST_LOG="$TEST_ROOT/xsel-copy.log" \
  "$ROOT/bin/g-copy"
grep -Fqx -- '--clipboard --input' "$TEST_ROOT/xsel-args.log"
[[ $(<"$TEST_ROOT/xsel-copy.log") == 'xsel clipboard' ]]

new_path no-copy Linux
if printf 'nowhere' | PATH="$ADAPTER_BIN" "$ROOT/bin/g-copy" \
  >"$TEST_ROOT/no-copy.out" 2>"$TEST_ROOT/no-copy.err"; then
  echo "Clipboard adapter succeeded without a backend." >&2
  exit 1
fi
grep -Fq 'no usable clipboard backend' "$TEST_ROOT/no-copy.err"

# Hammerspoon gets data through environment variables, never generated Lua.
new_path hammerspoon-notify Darwin
printf '#!/usr/bin/env bash\nexit 0\n' > "$ADAPTER_BIN/pgrep"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$DOTFILES_NOTIFY_TITLE" "$DOTFILES_NOTIFY_MESSAGE" "$DOTFILES_NOTIFY_AGENT" > "$ADAPTER_TEST_LOG"' \
  'printf '\''%s\n'\'' "$*" > "$ADAPTER_ARGS_LOG"' \
  'printf '\''ok\n'\''' > "$ADAPTER_BIN/hs"
chmod +x "$ADAPTER_BIN/pgrep" "$ADAPTER_BIN/hs"
# base64 and tr live outside the stub directory; the adapter encodes with them.
PATH="$ADAPTER_BIN:$TEST_SYSTEM_PATH" ADAPTER_TEST_LOG="$TEST_ROOT/hs-env.log" \
  ADAPTER_ARGS_LOG="$TEST_ROOT/hs-args.log" \
  "$ROOT/bin/g-notify" --title 'Title "quoted" ]]' --message 'body with spaces' --agent codex
for value in 'Title "quoted" ]]' 'body with spaces' codex; do
  grep -Fq "$(printf '%s' "$value" | base64 | tr -d '\n')" "$TEST_ROOT/hs-args.log"
done
if grep -Fq 'Title "quoted" ]]' "$TEST_ROOT/hs-args.log"; then
  echo "Notification text was interpolated into Lua source." >&2
  exit 1
fi

# The native fallbacks preserve each argument, including whitespace.
new_path terminal-notify Darwin
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$ADAPTER_TEST_LOG"' > "$ADAPTER_BIN/terminal-notifier"
chmod +x "$ADAPTER_BIN/terminal-notifier"
PATH="$ADAPTER_BIN" ADAPTER_TEST_LOG="$TEST_ROOT/terminal-args.log" \
  "$ROOT/bin/g-notify" --title 'Task done' --message 'repo with spaces' --agent claude
[[ $(sed -n '1p' "$TEST_ROOT/terminal-args.log") == -title ]]
[[ $(sed -n '2p' "$TEST_ROOT/terminal-args.log") == '✅ claude' ]]
[[ $(sed -n '3p' "$TEST_ROOT/terminal-args.log") == -message ]]
[[ $(sed -n '4p' "$TEST_ROOT/terminal-args.log") == 'Task done · repo with spaces' ]]

new_path linux-notify Linux
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$ADAPTER_TEST_LOG"' > "$ADAPTER_BIN/notify-send"
chmod +x "$ADAPTER_BIN/notify-send"
PATH="$ADAPTER_BIN" ADAPTER_TEST_LOG="$TEST_ROOT/linux-args.log" \
  "$ROOT/bin/g-notify" --title 'Linux title' --message 'Linux body'
[[ $(sed -n '1p' "$TEST_ROOT/linux-args.log") == -a ]]
[[ $(sed -n '2p' "$TEST_ROOT/linux-args.log") == dotfiles ]]
[[ $(sed -n '3p' "$TEST_ROOT/linux-args.log") == 'Linux title' ]]
[[ $(sed -n '4p' "$TEST_ROOT/linux-args.log") == 'Linux body' ]]

new_path no-notify Linux
if PATH="$ADAPTER_BIN" "$ROOT/bin/g-notify" --title title --message body \
  >"$TEST_ROOT/no-notify.out" 2>"$TEST_ROOT/no-notify.err"; then
  echo "Notification adapter succeeded without a backend." >&2
  exit 1
fi
grep -Fq 'no usable notification backend' "$TEST_ROOT/no-notify.err"

# Call sites describe intent and leave platform selection to the adapters.
[[ -x "$ROOT/bin/g-copy" && -x "$ROOT/bin/g-notify" ]]
grep -Fq 'set -s copy-command "$HOME/.local/bin/g-copy"' "$ROOT/configs/tmux/tmux.conf"
grep -Fq '| $HOME/.local/bin/g-copy' "$ROOT/configs/tmux/tmux.conf"
if grep -Fq pbcopy "$ROOT/configs/tmux/tmux.conf"; then
  echo "tmux still calls the macOS clipboard directly." >&2
  exit 1
fi
if grep -Eq 'terminal-notifier|notify-send|notificationToast|(^|[^[:alnum:]_])hs[[:space:]]+-' \
  "$ROOT/bin/agent-done-toast" "$ROOT/bin/herdr-agent-attention"; then
  echo "A notification caller still selects its own desktop backend." >&2
  exit 1
fi
