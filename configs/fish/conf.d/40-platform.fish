set -l kernel_name (uname -s)
set -l is_wsl false
set -l is_wsl2 false

if test "$kernel_name" = Linux
    set -l kernel_release (uname -r)
    if string match -qi '*microsoft*' -- "$kernel_release"
        set is_wsl true
    end
    if string match -qi '*wsl2*' -- "$kernel_release"
        set is_wsl2 true
    end
end

# A Rex pane on any host but the home Mac is viewed from the home Mac. codex and
# pi copy only into this host's clipboard unless they think the terminal is
# remote; then they also send OSC 52, which Rex carries to the viewer. (Claude
# Code always sends it.) pi has a knob for this; codex reads only SSH_TTY,
# SSH_CONNECTION, TMUX and HERDR_ENV, and SSH_TTY is the one that is true here.
# The home Mac is left out: tools such as gcloud stop opening a browser when
# they see SSH_TTY.
if test "$TERM_PROGRAM" = rex; and not string match -q 'GuandeMacBook-Pro*' -- $hostname
    set -gx PI_CLIPBOARD_OSC52 1
    if not set -q SSH_TTY; and set -l pane_tty (tty)
        set -gx SSH_TTY $pane_tty
    end
end

if test "$is_wsl2" = true
    set -l nameserver (awk '/nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)
    if test -n "$nameserver"
        set -gx DISPLAY "$nameserver:0.0"
    end
    set -gx LIBGL_ALWAYS_INDIRECT 1
end

# Fish uses an unexported CDPATH. Exporting it makes Bash command substitutions
# such as ROOT="$(cd ... && pwd)" receive an extra line from cd.
set -e CDPATH
set -g CDPATH .
switch "$kernel_name"
    case Darwin
        set -g CDPATH $CDPATH "$HOME/projects"
    case Linux
        if test "$is_wsl2" = true
            set -g CDPATH $CDPATH "$HOME/projects"
        else if test "$is_wsl" = true
            set -g CDPATH $CDPATH /mnt/d/code
        else
            set -g CDPATH $CDPATH "$HOME/Public"
        end
end
