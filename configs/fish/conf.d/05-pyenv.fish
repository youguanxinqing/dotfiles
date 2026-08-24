# pyenv publishes one shim per executable found in ANY installed version, and a
# shim aborts instead of falling through when the selected version does not have
# that command. Shims therefore have to sit ahead of Homebrew's python, yet they
# must not hide a Homebrew CLI that happens to share its name with a project
# dependency: ruff, uv and black all exist both as formulae and inside project
# virtualenvs.
#
# Loading pyenv before 10-paths.fish, and going through $PATH rather than
# fish_user_paths, produces the intended three-tier order:
#
#   ~/.local/bin  >  pyenv shims  >  Homebrew
#
# Version selection keeps working because nothing in ~/.local/bin is named after
# a Python entry point. To pin one of the shadowed CLIs to its Homebrew build,
# link it into ~/.local/bin; that makes the choice explicit instead of leaving it
# to PATH ordering. fish_user_paths is avoided on purpose: Fish hoists that list
# in front of the whole of $PATH, which is what made shims win unconditionally.

set -l pyenv_command "$HOME/.local/bin/pyenv"
if not test -x "$pyenv_command"
    set pyenv_command (command -v pyenv)
end
test -n "$pyenv_command"; and test -x "$pyenv_command"; or exit 0

set -gx PYENV_ROOT "$HOME/.pyenv"
set -gx PYENV_SHELL fish
set -g _PYENV_BIN "$pyenv_command"

fish_add_path --global --move --path "$PYENV_ROOT/shims"

# sh-* subcommands mutate the calling shell, so they are sourced instead of run.
function pyenv
    set -l command ""
    if set -q argv[1]
        set command $argv[1]
    end

    switch "$command"
        case rehash shell activate deactivate
            source ($_PYENV_BIN "sh-$command" $argv[2..-1] | psub)
        case '*'
            $_PYENV_BIN $argv
    end
end
