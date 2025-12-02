function cd
  if set -q __direnv_done
    builtin cd $argv
  else
    # direnv: https://github.com/direnv/direnv
    direnv hook fish | source
    set -g __direnv_done 1
    builtin cd $argv
  end
end
