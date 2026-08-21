set -gx EDITOR nvim
set -gx XDG_CONFIG_HOME "$HOME/.config"

# Rust: install rust, cagro,... (https://www.rust-lang.org/tools/install)
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

# Homebrew uses one Brewfile on macOS and Linux, but a different prefix.
for brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
  if test -x $brew
    eval ($brew shellenv fish)
    break
  end
end


set cdptah
# 只 set -g 不 -gx: fish 自己的 cd 认非导出的 CDPATH，而一旦导出，bash 的 cd 就会
# 把目标目录打到 stdout，`ROOT="$(cd "$(dirname "$0")/.." && pwd)"` 这类到处都是的写法
# 会拿到两行的路径。herdr-reviewr 的 install.sh 就是这么挂掉的。
# 先 erase 是因为从父进程继承来的 CDPATH 自带 export 标记，set -g 不会把它摘掉。
set -e CDPATH
set -g CDPATH .
if test (get_my_platform) = "darwin"
  set -g CDPATH $CDPATH ~/projects
else
  if test (is_wsl2) = "true"
      set -g CDPATH $CDPATH ~/projects/
  else
    if test (get_my_platform) = "windows"
      set -g CDPATH $CDPATH /mnt/d/code
    else if test (get_my_platform) = "linux"
      set -g CDPATH $CDPATH ~/Public
    else if test (get_my_platform) = "darwin"
      set -g CDPATH $CDPATH ~/projects
    end
  end
end

if type -q fnm
  fnm env | source
end

if test -f ~/.goup/env
  source ~/.goup/env
  set -e GOROOT
end
