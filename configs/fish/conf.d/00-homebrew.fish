# Homebrew owns its prefix, MANPATH, and INFOPATH. Nested shells inherit the
# result, so only call brew when no parent shell has initialized it already.
if not set -q HOMEBREW_PREFIX
    for brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
        if test -x "$brew"
            eval ($brew shellenv fish)
            break
        end
    end
end
