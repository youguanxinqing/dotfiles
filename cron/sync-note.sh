#!/bin/sh

# crontab -else
# */30 * * * * sh /path-to/dotfiles/cron/sync-note.sh >> /path-to/dotfiles/cron/sync-note.log 2>&1

function timestamp() {
  date +"at %H:%M:%S on %d/%m/%Y"
}

function sync_repo() {
  local path=$1
        cd $path; pwd

        git pull
        git add --all
        git commit -am "auto-commit $(timestamp)"
        git push origin master
}

function splitter() {
        echo "----------------"
}


paths=(
  "path-to-note-01" "path-to-note-02" "path-to-note-03"
)

for path in ${paths[@]}; do
  echo "$(timestamp)"
        sync_repo "${path}"
  splitter
done
