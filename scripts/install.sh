#!/usr/bin/env bash

set -x

NAVIGATION_FILE=navigation.txt

FLAG=$1
echo $FLAG
if [ $FLAG = "" ]; then
  echo "Invalid FLAG and aborted!"
  exit
fi

cd ~/dotfiles/
# TODO: how to drop newline charater
SOURCE_DIR=$(ls | xargs -n1 | grep -w $FLAG)
TARGET_DIR=$(cat $NAVIGATION_FILE | awk -v SOURCE_DIR=$SOURCE_DIR '{c[$1]=$3; print c[SOURCE_DIR]}')
TARGET_FATHER_DIR=$(echo "${TARGET_DIR//$SOURCE_DIR/}" | tr '\n' ' ')

echo "ln -s `pwd`/$SOURCE_DIR $TARGET_FATHER_DIR" | bash
