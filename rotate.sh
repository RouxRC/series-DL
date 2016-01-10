#!/bin/bash

cd $(dirname $0)
source config.inc

mkdir -p "$ACHIEVED_DIR" "$READY_DIR"

# Cleanup torrent files
find "$ACHIEVED_DIR" -regex ".*/[0-9]+-[0-9]+\..*\.[A-F0-9]+\.torrent" -exec rm -f {} \;


# Move finished video files and cleanup remnant directories
find "$ACHIEVED_DIR" -regex ".*[sS][0-9]+[eE][0-9]+.*\.\(mkv\|mp4\|avi\)" | sort | while read VIDEOFILE; do
  mv "$VIDEOFILE" "$READY_DIR/"
  VIDEOPATH=$(echo "$VIDEOFILE" | sed -r 's|^(.*)/[^/]+$|\1|')
  if [ "$VIDEOPATH" != "$ACHIEVED_DIR" ]; then
    # Remove sample videos
    find "$VIDEOPATH" -regex ".*[.\-][sS][aA][mM][pP][lL][eE]\.\(mkv\|mp4\|avi\)" -exec rm -f {} \;
    # Remove extra files
    find "$VIDEOPATH" -regex ".*\.\(txt\|srt\|nfo\|png\|jpg\)" -exec rm -f {} \;
    rm -df "$VIDEOPATH" 2> /dev/null
  fi
done

# Start downloading subs after rotation if extra argument
if ! [ -z "$1" ]; then
  ./getSubs.py >> logSub.txt 2>&1
fi
