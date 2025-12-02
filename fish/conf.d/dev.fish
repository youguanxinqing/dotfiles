set -gx EDITOR nvim

# Go: install goup (https://github.com/thinkgos/goup-rs)
set -gx PATH $PATH $HOME/go/bin/
# fzf
set PATH $PATH "$HOME/.fzf/bin/"
# eask
set PATH $PATH "$HOME/.local/bin"
# fnm
set PATH "~/.local/share/fnm" $PATH

# Rust: install rust, cagro,... (https://www.rust-lang.org/tools/install)
set -gx PATH $PATH $HOME/.cargo/bin/
set -gx RUSTUP_DIST_SERVER https://rsproxy.cn
set -gx RUSTUP_UPDATE_ROOT https://rsproxy.cn/rustup

# Flutter
set -l FLUTTER_ROOT "$HOME/tools/flutter/"
set -l FLUTTER_BIN "$HOME/tools/flutter/bin"
if test -e $FLUTTER_BIN
  set -gx PUB_HOSTED_URL "https://pub.flutter-io.cn"
  set -gx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"
  set PATH $PATH $FLUTTER_BIN
end

# wsl2 gui
if test (is_wsl2) = "true"
  set -gx DISPLAY $(awk '/nameserver/ {print $2}' /etc/resolv.conf):0.0
  set -gx LIBGL_ALWAYS_INDIRECT 1
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


set cdptah
set -gx CDPATH .
if test (get_my_platform) = "darwin"
  set -gx CDPATH $CDPATH ~/projects
else
  if test (is_wsl2) = "true"
      set -gx CDPATH $CDPATH ~/projects/
  else
    if test (get_my_platform) = "windows"
      set -gx CDPATH $CDPATH /mnt/d/code
    else if test (get_my_platform) = "linux"
      set -gx CDPATH $CDPATH ~/Public
    else if test (get_my_platform) = "darwin"
      set -gx CDPATH $CDPATH ~/projects
    end
  end
end
