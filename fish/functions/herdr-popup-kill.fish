# 关掉卡住的 herdr popup。
# popup 是 session-modal，吞掉全部输入包括 esc 和 prefix，正常出口是浮层里按 ctrl+b q
# （direct-attach 客户端硬编码的 detach 键）。里面的程序连 ctrl+b 都吃掉时，就从别的
# 终端窗口跑这个 —— 走 socket API，不需要键盘能到达那个 session。
#
#   herdr-popup-kill              关掉默认 session 的 popup
#   herdr-popup-kill <session>    关掉指定命名 session 的 popup
function herdr-popup-kill --description "close a stuck herdr popup via the socket API"
    set -l sock
    if set -q argv[1]
        set sock (herdr --session $argv[1] status server 2>/dev/null | string replace -r '^socket: ' '')
    else
        set sock (herdr status server 2>/dev/null | string replace -r '^socket: ' '')
    end
    set sock (string match -r '^/.*\.sock$' -- $sock)

    if test -z "$sock"
        echo "herdr server not running (no socket)" >&2
        return 1
    end

    printf '{"id":"herdr-popup-kill","method":"popup.close","params":{}}\n' | nc -U $sock
end
