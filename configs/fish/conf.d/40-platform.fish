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
