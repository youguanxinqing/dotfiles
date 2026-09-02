
# alias for coding agents
# opus 是别名，跟最新的 Opus 走，不写死 claude-opus-5；
# [1m] 后缀要的是 1M context 那个变体，光写 opus 拿到的是默认 200K。
alias claude='claude --permission-mode auto --model "opus[1m]" --effort max'
# codex 不需要 alias：可移植偏好由 dotfiles profile 提供，目录信任也要
# 在启动前计算；两件事都收口在 functions/codex.fish。

# alias for git
abbr -a gits "git status"
abbr -a gitd "git diff"
abbr -a gitc "git commit -m \"\""


# desktop clipboard
if type -q g-copy
  abbr -a copy "g-copy"
end


# alias for proxy
set -l FISH_PROXY_FILE ~/.config/fish/conf.d/variables/proxy.fish
if test -e $FISH_PROXY_FILE
  source $FISH_PROXY_FILE
  alias proxy-git="git config --global http.proxy $PROXY_SOCK_DSN; \
    git config --global https.proxy $PROXY_SOCK_DSN"
  alias unproxy-git="git config --global --unset http.proxy; \
    git config --global --unset https.proxy"
  alias proxy-http="set -gx ALL_PROXY $PROXY_HTTP_DSN; \
    set -gx  http_proxy $PROXY_HTTP_DSN; \
    set -gx  HTTP_PROXY $PROXY_HTTP_DSN; \
    set -gx  https_proxy $PROXY_HTTP_DSN; \
    set -gx  HTTPS_PROXY $PROXY_HTTP_DSN"
  alias proxy-sock="set -gx ALL_PROXY $PROXY_SOCK_DSN; \
    set -gx  http_proxy $PROXY_SOCK_DSN; \
    set -gx  HTTP_PROXY $PROXY_SOCK_DSN; \
    set -gx  https_proxy $PROXY_SOCK_DSN; \
    set -gx  HTTPS_PROXY $PROXY_SOCK_DSN"
end

# 懒猫微服 daemon 的代理口。61090 是 hclient-cli 文档里的默认 -proxy-listen-addr，
# 每台机器都一样，所以它进仓库，而不是进 gitignore 掉的 proxy.fish —— 那个文件留给
# 真的因机器而异的地址。同一个端口 HTTP CONNECT 和 SOCKS5 都讲，取 http 就够了。
set -gx PROXY_LAZYCAT_DSN "http://127.0.0.1:61090"
alias proxy-lazycat="set -gx ALL_PROXY $PROXY_LAZYCAT_DSN; \
  set -gx  http_proxy $PROXY_LAZYCAT_DSN; \
  set -gx  HTTP_PROXY $PROXY_LAZYCAT_DSN; \
  set -gx  https_proxy $PROXY_LAZYCAT_DSN; \
  set -gx  HTTPS_PROXY $PROXY_LAZYCAT_DSN"

# unproxy 不读任何 DSN，所以不该跟着 proxy.fish 一起消失：没有那个私有文件的机器
# 现在也能用 proxy-lazycat，得留个关得掉的开关。
alias unproxy="set -e ALL_PROXY; \
  set -e  http_proxy; \
  set -e  HTTP_PROXY; \
  set -e  https_proxy; \
  set -e  HTTPS_PROXY"

# `..` 不用配，fish 的 implicit cd 认 `.` / `..` / 带 `/` 的路径（裸目录名不认）。
# `...` 只能靠 abbr，而 abbr 只在交互式下展开——脚本里写 `...` 会是 Unknown command。
abbr -a ... "cd ../.."

# Match Omarchy's eza interface while keeping the command line as `ls`:
# Fish aliases resolve only when the command executes; abbreviations expand while typing.
if type -q eza
  alias ls "eza -lh --group-directories-first --icons=auto"
  alias lsa "ls -a"
  alias lt "eza --tree --level=2 --long --icons --git"
  alias lta "lt -a"
end

abbr -a z "zellij"
abbr -a za "zellij attach"
abbr -a zls "zellij ls"

# quick edit fish root
abbr -a edit-fish-config "cd ~/.config/fish && nvim"
# quick edit the single fish file for lb
abbr -a edit-local-fish-config "nvim ~/.config/fish/local.d/local.fish"
# quick edit nvim root
abbr -a edit-nvim-config "cd ~/.config/nvim && nvim"
# quick edit ssh config
abbr -a edit-ssh-config "nvim ~/.ssh/config"
