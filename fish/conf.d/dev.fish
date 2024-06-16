source ~/.config/fish/functions/platform.fish

set -gx EDITOR nvim

# Go: install goup (https://github.com/owenthereal/goup)
source ~/.go/env
set -gx PATH $PATH $HOME/go/bin/

# Rust: install rust, cagro,... (https://www.rust-lang.org/tools/install)
set -gx PATH $PATH $HOME/.cargo/bin/
set -gx RUSTUP_DIST_SERVER https://rsproxy.cn
set -gx RUSTUP_UPDATE_ROOT https://rsproxy.cn/rustup

# Js: fnm (https://github.com/Schniz/fnm)
set PATH $PATH "$HOME/.local/share/fnm" 
fnm env | source

# Py
# so slow!!!
function load_py_env
  set -Ux PYENV_ROOT $HOME/.pyenv
  fish_add_path $PYENV_ROOT/bin
  pyenv init - | source
end

# wsl2 gui
if test (is_wsl2)
  set -gx DISPLAY $(awk '/nameserver/ {print $2}' /etc/resolv.conf):0.0
  set -gx LIBGL_ALWAYS_INDIRECT 1
end
