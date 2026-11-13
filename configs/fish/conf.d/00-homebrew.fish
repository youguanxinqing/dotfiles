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
# A parent that exported HOMEBREW_PREFIX can still hand over a PATH without
# Homebrew (launchd-started servers do). Add what is missing, but never move
# entries a caller put first on purpose.
if test -n "$HOMEBREW_PREFIX"
    fish_add_path --global --path $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin
end
