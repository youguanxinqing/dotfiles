function fnm
  if set -q __fnm_done
    command fnm $argv
  else
    command fnm env | source
    set -g __fnm_done 1
    command fnm $argv
  end
end
