function cd
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
