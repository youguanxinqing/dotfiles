function cd
  # Initialize direnv on first run
  if not set -q __direnv_done
    # direnv: https://github.com/direnv/direnv
    direnv hook fish | source
    set -g __direnv_done 1
  end

  # Handle cd -
  if test "$argv[1]" = "-"
    if set -q OLDPWD
      set -l target $OLDPWD
      set -gx OLDPWD $PWD
      builtin cd $target
    end
  else
    # Save current directory before changing
    set -gx OLDPWD $PWD
    builtin cd $argv
  end
end
