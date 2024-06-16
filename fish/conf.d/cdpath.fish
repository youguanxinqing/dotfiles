source ~/.config/fish/functions/platform.fish

# set cdptah
set -gx CDPATH .
if test (is_wsl2)
    set -gx CDPATH $CDPATH ~/projects/
else
  if test (get_my_platform) = "windows"
    set -gx CDPATH $CDPATH /mnt/d/code
  else if test (get_my_platform) = "linux"
    set -gx CDPATH $CDPATH ~/Public
  end
end
