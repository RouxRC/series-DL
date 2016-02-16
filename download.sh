#!/bin/bash

cd $(dirname $0)
source config.inc
ROOT_URL="https://kat.cr/usearch/"

mkdir -p .tmp
touch episodes.done

function safecurl {
  url=$1
  retries=$2
  if [ -z "$retries" ]; then
    retries=10
  fi
  curl -sL --connect-timeout 5 "$url" > /tmp/safecurl-dl-series.tmp
  if ! zcat /tmp/safecurl-dl-series.tmp 2> /dev/null && [ "$retries" -gt 0 ]; then
    safecurl "$url" $(( $retries - 1 ))
  fi
}

function lowerize {
  echo "$1" | sed -r 's/^(.*)$/\L\1/'
}

function uniqname {
  lowerize "$1" | sed 's/[^a-z0-9]//g'
}

function start_client {
  CLIENT=$(echo "$TORRENT_CLIENT" | sed 's/ .*$//')
  if ! ps x | grep "$CLIENT" | grep -v " grep " > /dev/null; then
    "$CLIENT" >> logTor.txt 2>&1 &
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
    echo "$LOWERED" >> ../episodes.done
  fi
  cd ..
}

echo
echo $(date)
echo "----------------------"
echo "$SOURCES" | while read SOURCE; do
  SOURCE=$(echo "$SOURCE" | sed 's/\s\+/ /g' | sed -r 's/(^ | $)//')
  PAGES=1
  if echo "$SOURCE" | grep " [0-9]\+\s*" > /dev/null; then
    PAGES=$(echo "$SOURCE" | sed -r 's/^.* ([0-9]+) ?$/\1/')
  fi
  QUERY=$(echo "$SOURCE"        |
   sed -r "s| +[0-9]+?$||"      |
   sed 's/ /%20/g')"%20${RES}p"
  for PAGE in $(seq $PAGES); do
    URL="${ROOT_URL}$QUERY/$PAGE/?field=time_add&sorder=desc"
    echo "QUERY $URL"
    safecurl "$URL"                                 |
     grep 'class="cellMainLink"\|\.torrent?title'   |
     tr '\n' ' '                                    |
     sed 's|//torcache|\nhttp://torcache|g'         |
     sed 's|?title=.*class="cellMainLink">|#|'      |
     sed 's|</a>.*$||'                              |
     sed 's|<\/\?[^>]*>||g'                         |
     grep -v "Download torrent file"                |
     while read line; do
      TORRENT_URL=$(echo "$line" | sed 's/#.*$//')
      TORRENT_ID=$(echo "$TORRENT_URL" | sed -r 's|^.*/([0-9A-F]+)\.torrent|\1|')
      TORRENT_NAME=$(echo "$line" | sed 's/^.*#//')
      TORRENT_EP=$(echo "$TORRENT_NAME"                   |
       sed -r "s/ ${RES}p( |]|\.).*$//i"                  |
       sed -r 's/\(?[0-9]{4}\)? (S[0-9]+E[0-9]+)/\1/i'    |
       sed -r 's/(E[0-9]+) [a-z]+ [a-z]+.*$/\1/i'         |
       sed -r 's/( - [0-9]+) .*$/\1/')
      SEARCHABLE=$(echo "$TORRENT_NAME" | sed 's/^\[[^]]*\] *//')
      SEARCHABLE=$(uniqname "$SEARCHABLE")
      LOWERED=$(echo "$TORRENT_EP" | sed 's/^\[[^]]*\] *//')
      LOWERED=$(lowerize "$LOWERED")
      if grep "^$LOWERED$" episodes.done > /dev/null; then
        continue
      elif $DL_ALL_FIRST_EPS && echo "$TORRENT_EP" | grep -i " S01E01" > /dev/null; then
        start_torrent
        continue
      fi
      echo "$SHOWS" | while read SHOW; do
        EPSEARCH=".*s[0-9]\+e[0-9]\+"
        if echo "$SHOW" | grep "#NOSEASON" > /dev/null; then
          SHOW=$(echo "$SHOW" | sed 's/\s*#NOSEASON\s*$//')
          EPSEARCH="[0-9][0-9]\+"
        fi
        MATCH=$(uniqname "$SHOW")
        if echo "$SEARCHABLE" | grep "^${MATCH}${EPSEARCH}" > /dev/null; then
          start_torrent
          break
        fi
      done
    done
  done
done
