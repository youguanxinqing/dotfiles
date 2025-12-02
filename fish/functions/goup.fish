function goup
  if set -q __goup_done
    command goup $argv
  else
    source ~/.goup/env
    set -g __goup_done 1
    command goup $argv
  end
end
