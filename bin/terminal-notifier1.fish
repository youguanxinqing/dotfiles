#!/usr/bin/env fish

if contains -- -h $argv; or contains -- --help $argv
    echo "Usage: terminal-notifier1 -title ... -message ..."
    echo ""
    echo "  -title <text>     notification title"
    echo "  -message <text>   notification body (tmux window/pane info is prepended automatically)"
    echo "  -h                show this help"
    return 0
end

# Build tmux context prefix: [session:window.pane]
set -l CONTEXT ""
if set -q TMUX
    set CONTEXT (tmux display-message -p '[#S:#W] ')
end

# 保留旧的 terminal-notifier 参数接口，但把实际后端交给跨平台适配器。
set -l title ""
set -l message ""
set -l i 1
while test $i -le (count $argv)
    if test "$argv[$i]" = -title; or test "$argv[$i]" = --title
        set i (math $i + 1)
        if test $i -gt (count $argv)
            echo "terminal-notifier1: title requires a value" >&2
            exit 2
        end
        set title "$argv[$i]"
    else if test "$argv[$i]" = -message; or test "$argv[$i]" = --message
        set i (math $i + 1)
        if test $i -gt (count $argv)
            echo "terminal-notifier1: message requires a value" >&2
            exit 2
        end
        set message "$argv[$i]"
    else
        echo "terminal-notifier1: unknown argument: $argv[$i]" >&2
        exit 2
    end
    set i (math $i + 1)
end

set -l here (dirname (status filename))
"$here/g-notify" --title "$title" --message "$CONTEXT$message"
