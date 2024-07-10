#!/usr/bin/env bash

set -x

sudo cp -r ./fonts/lxgw-wenkai  /usr/local/share/fonts/
fc-cache -f -v 
