function cd
  # Handle cd -
  if test "$argv[1]" = "-"
    if set -q OLDPWD
      set -l target $OLDPWD
      set -gx OLDPWD $PWD
      builtin cd -- $target
    end
  else
    # fish 的 implicit cd（直接敲 `..`）是以 `cd -- <dir>` 调进来的，
    # 不剥掉这个 `--` 就会传成两个，builtin cd 报 "expected 1 arguments"
    if test "$argv[1]" = "--"
      set -e argv[1]
    end
    # Save current directory before changing
    set -gx OLDPWD $PWD
    builtin cd -- $argv
  end
end
