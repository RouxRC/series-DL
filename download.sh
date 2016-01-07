#!/bin/bash

cd $(dirname $0)
source config.inc
ROOT_URL="https://kat.cr/usearch/"

mkdir -p .tmp
touch episodes.done

function lowerize {
  echo "$1" | sed -r 's/^(.*)$/\L\1/'
}

function uniqname {
  lowerize "$1" | sed 's/[^a-z0-9]//g'
}

function start_client {
  if ! ps x | grep "$TORRENT_CLIENT" | grep -v " grep " > /dev/null; then
    "$TORRENT_CLIENT" >> logAzu.txt 2>&1 &
    sleep 3
  fi
}

function start_torrent {
  echo "- Starting torrent $TORRENT_ID for: $TORRENT_NAME"
  start_client
  cd .tmp
  TORRENT_FILE=$(date +%y%m%d-%H%M)".${TORRENT_NAME}.${TORRENT_ID}.torrent"
  wget --quiet --header='Accept: text/html' --header='User-Agent: test' "$TORRENT_URL" -O "${TORRENT_FILE}.gz"
  gunzip "${TORRENT_FILE}.gz"
  if [ "$?" -ne 0 ] || ! test -e "$TORRENT_FILE"; then
    echo " WARNING: torrent download failed at $TORRENT_URL"
    rm -f "${TORRENT_FILE}.gz"
  else
    "$TORRENT_CLIENT" "$TORRENT_FILE" >> logAzu.txt 2>&1 &
    lowerize "$TORRENT_EP" >> ../episodes.done
  fi
  cd ..
}

echo
echo $(date)
echo "----------------------"
echo "$SOURCES" | while read SOURCE; do
  QUERY=$(echo "$SOURCE" | sed -r "s| *([0-9]+)?$|%20${RES}p/\1|" | sed -r 's|(/[0-9]+)$|\1/|')
  URL="${ROOT_URL}${QUERY}?field=time_add&sorder=desc"
  echo "QUERY $URL"
  curl -sL "$URL" | zcat                          |
   grep 'class="cellMainLink"\|\.torrent?title'   |
   tr '\n' ' '                                    |
   sed 's|//torcache|\nhttp://torcache|g'         |
   sed 's|?title=.*class="cellMainLink">|#|'      |
   sed 's|</a>.*$||'                              |
   sed 's|<\/\?[^>]*>||g'                         |
   while read line; do
    TORRENT_URL=$(echo "$line" | sed 's/#.*$//')
    TORRENT_ID=$(echo "$TORRENT_URL" | sed -r 's|^.*/([0-9A-F]+)\.torrent|\1|')
    TORRENT_NAME=$(echo "$line" | sed 's/^.*#//')
    TORRENT_EP=$(echo "$TORRENT_NAME" | sed -r "s/ ${RES}p .*$//")
    SEARCHABLE=$(uniqname "$TORRENT_NAME")
    LOWERED=$(lowerize "$TORRENT_EP")
    if grep "$LOWERED" episodes.done > /dev/null; then
      continue
    elif $DL_ALL_FIRST_EPS && echo "$TORRENT_EP" | grep -i " S01E01" > /dev/null; then
      start_torrent
      continue
    fi
    echo "$SHOWS" | while read SHOW; do
      MATCH=$(uniqname "$SHOW")
      if echo "$SEARCHABLE" | grep "^$MATCH.*s[0-9]\+e[0-9]\+" > /dev/null; then
        start_torrent
        break
      fi
    done
  done
done
