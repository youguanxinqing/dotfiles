
# alias for git
abbr -a gits "git status"
abbr -a gitd "git diff"
abbr -a gitc "git commit -m \"\""


# nvim copy
if type -q xclip
  abbr -a copy "xclip -selection c"
end


# alias for proxy
set -l FISH_PROXY_FILE ~/.config/fish/conf.d/variables/proxy.fish
if test -e $FISH_PROXY_FILE
  source ~/.config/fish/conf.d/variables/proxy.fish
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
  alias unproxy="set -e ALL_PROXY; \
    set -e  http_proxy; \
    set -e  HTTP_PROXY; \
    set -e  https_proxy; \
    set -e  HTTPS_PROXY"
end

abbr -a z "zellij"
abbr -a za "zellij attach"
abbr -a zls "zellij ls"

# quick edit fish root
abbr -a edit-fish "cd ~/.config/fish && nvim"
# quick edit the single fish file for lb
abbr -a edit-lb-fish "nvim ~/.config/fish/conf.d/lb.fish"
# quick edit nvim root
abbr -a edit-nvim "cd ~/.config/nvim && nvim"
