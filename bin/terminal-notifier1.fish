#!/usr/bin/env fish

if contains -- -h $argv
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

# 逐个重建参数，对 -message 值注入 tmux 上下文，用双引号确保含空格的文本不拆分
set -l new_args
set -l i 1
while test $i -le (count $argv)
    if test "$argv[$i]" = -message
        set i (math $i + 1)
        set -a new_args -message "\"$CONTEXT$argv[$i]\""
    else if string match -q -- '-*' "$argv[$i]"
        set -a new_args "$argv[$i]"
    else
        set -a new_args "\"$argv[$i]\""
    end
    set i (math $i + 1)
end

terminal-notifier $new_args

