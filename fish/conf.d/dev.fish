source ~/.config/fish/functions/platform.fish

set -gx EDITOR nvim

# Go: install goup (https://github.com/thinkgos/goup-rs)
source ~/.goup/env
set -gx PATH $PATH $HOME/go/bin/

# Rust: install rust, cagro,... (https://www.rust-lang.org/tools/install)
set -gx PATH $PATH $HOME/.cargo/bin/
set -gx RUSTUP_DIST_SERVER https://rsproxy.cn
set -gx RUSTUP_UPDATE_ROOT https://rsproxy.cn/rustup
set -l RUST_ENV_FILE "$HOME/.cargo/env.fish"
if test -e $RUST_ENV_FILE
  source $RUST_ENV_FILE
end

# Py
# so slow!!!
function load_py_env
  set -Ux PYENV_ROOT $HOME/.pyenv
  fish_add_path $PYENV_ROOT/bin
  pyenv init - | source
end

# fzf
set PATH $PATH "$HOME/.fzf/bin/"

# eask
set PATH $PATH "$HOME/.local/bin"

# wsl2 gui
if test (is_wsl2) = "true"
  set -gx DISPLAY $(awk '/nameserver/ {print $2}' /etc/resolv.conf):0.0
  set -gx LIBGL_ALWAYS_INDIRECT 1
end

set -l FLUTTER_ROOT "$HOME/tools/flutter/"
set -l FLUTTER_BIN "$HOME/tools/flutter/bin"
if test -e $FLUTTER_BIN
  set -gx PUB_HOSTED_URL "https://pub.flutter-io.cn"
  set -gx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"
  set PATH $PATH $FLUTTER_BIN
end

# load binary path for macos
if test (get_my_platform) = "darwin"
  if test (command_exists /opt/homebrew/bin/brew) = "true"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else if test (command_exists /usr/local/bin/brew) = "true"
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "brew not found"
  end
end

# direnv: https://github.com/direnv/direnv
if test (command_exists direnv) = "true"
  direnv hook fish | source
end
