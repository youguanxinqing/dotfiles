#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <font-directory>"
    exit 1
fi

FONT_DIR="$1"

if [ ! -d "$FONT_DIR" ]; then
    echo "Error: '$FONT_DIR' is not a directory"
    exit 1
fi

TTF_FILES=$(find "$FONT_DIR" -name "*.ttf" -o -name "*.TTF")
if [ -z "$TTF_FILES" ]; then
    echo "No TTF files found in '$FONT_DIR'"
    exit 1
fi

case "$(uname -s)" in
    Darwin)
        DEST="/Library/Fonts"
        sudo mkdir -p "$DEST"
        find "$FONT_DIR" \( -name "*.ttf" -o -name "*.TTF" \) -exec sudo cp {} "$DEST/" \;
        echo "Installed fonts to $DEST"
        ;;
    Linux)
        DEST="/usr/local/share/fonts"
        sudo mkdir -p "$DEST"
        find "$FONT_DIR" \( -name "*.ttf" -o -name "*.TTF" \) -exec sudo cp {} "$DEST/" \;
        fc-cache -f -v
        echo "Installed fonts to $DEST"
        ;;
    *)
        echo "Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac
