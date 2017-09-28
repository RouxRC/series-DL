#!/bin/bash

cd $(dirname $0)
source config.inc

mkdir -p .tmp
touch episodes.done

CATCHUP=$1
NORES=$2

function safecurl {
  url=$1
  retries=$2
  if [ -z "$retries" ]; then
    retries=10
  fi
  curl -sL --connect-timeout 5 "$url" > /tmp/safecurl-dl-series.tmp
  if grep '<html' /tmp/safecurl-dl-series.tmp; then
    cat /tmp/safecurl-dl-series.tmp
  elif ! zcat /tmp/safecurl-dl-series.tmp 2> /dev/null && [ "$retries" -gt 0 ]; then
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
  if [ "$CLIENT" = "aria2c" ]; then return; fi
  if ! ps x | grep "$CLIENT" | grep -v " grep " > /dev/null; then
    "$CLIENT" >> logTor.txt 2>&1 &
    sleep 3
  fi
}

function start_torrent {
  echo "- Starting torrent for: $TORRENT_NAME"
  start_client
  cd .tmp
  TORRENT_FILE=$(date +%y%m%d-%H%M)".${TORRENT_NAME}.torrent"
  TORRENT_URL=$(echo $TORRENT_URL | sed 's/\[/%5B/g' | sed 's/\]/%5D/g')
  $PROXY_SERVER curl -sL "$TORRENT_URL" > "$TORRENT_FILE"
  if [ "$?" -ne 0 ] || ! test -s "$TORRENT_FILE"; then
    echo " WARNING: torrent download failed at $TORRENT_URL"
    rm -f "$TORRENT_FILE"
  else
    "$TORRENT_CLIENT" "$TORRENT_FILE" >> logAzu.txt 2>&1 &
    echo "$LOWERED" >> ../episodes.done
  fi
  cd ..
}

function start_magnet {
  echo "- Starting magnet for: $TORRENT_NAME"
  start_client
  cd $DOWNLOAD_DIR
  "$TORRENT_CLIENT" "$TORRENT_URL" >> logAzu.txt 2>&1 &
  cd - > /dev/null
  echo "$LOWERED" >> episodes.done
  sleep $SLEEPDELAY
}

function download_if_required {
  #echo $TORRENT_NAME $TORRENT_URL
  DLTYPE=$1
  RESSRC="[0-9]+0"
  if [ -z "$NORES" ]; then
    RESSRC=$RES
  fi
  TORRENT_EP=$(echo "$TORRENT_NAME"                   |
   sed -r "s/ ${RESSRC}p( |]|\.).*$//i"               |
   sed -r 's/\(?[0-9]{4}\)? (S[0-9]+E[0-9]+)/\1/i'    |
   sed -r 's/(E[0-9]+) [a-z]+ [a-z]+.*$/\1/i'         |
   sed -r 's/( - [0-9]+) .*$/\1/')
  SEARCHABLE=$(echo "$TORRENT_NAME" | sed 's/^\[[^]]*\] *//')
  SEARCHABLE=$(uniqname "$SEARCHABLE")
  LOWERED=$(echo "$TORRENT_EP" | sed 's/\s*\[[^]]*\(\]\s*\|$\)//g')
  LOWERED=$(lowerize "$LOWERED")
  if grep "^$LOWERED$" episodes.done > /dev/null; then
    continue
  elif $DL_ALL_FIRST_EPS && echo "$TORRENT_EP" | grep -i " S01E01" > /dev/null; then
    start_"$DLTYPE"
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
      start_"$DLTYPE"
      break
    fi
  done
}

function search_episodes_eztv_magnet {
  ROOT_URL="https://eztv.ag/"
  URL="${ROOT_URL}$QUERY"
  echo "QUERY $URL"
  safecurl "$URL"                           |
   grep "$RESSTR"'.*class="magnet"'         |
   sed 's|^.*<a href="||'                   |
   sed 's|".*title="|#|'                    |
   sed 's| \[eztv\] ([0-9.]\+ [MG]B) Magnet Link.*$||'  |
   while read line; do
    TORRENT_URL=$(echo "$line" | sed 's/#.*$//')
    TORRENT_NAME=$(echo "$line" | sed 's/^.*#//')
    download_if_required "magnet"
  done
}
function search_episodes_eztv {
  ROOT_URL="https://eztv.ag/"
  URL="${ROOT_URL}$QUERY"
  echo "QUERY $URL"
  safecurl "$URL"                       |
   grep "$RESSTR"'.*class="download_1"' |
   sed 's|^.*<a href="||'               |
   sed 's|".*title="|#|'                |
   sed 's| Torrent: .*$||'              |
   while read line; do
    TORRENT_URL=$(echo "$line" | sed 's/#.*$//')
    TORRENT_NAME=$(echo "$line" | sed 's/^.*#//')
    download_if_required "torrent"
  done
}

function search_episodes_piratebay {
  #ROOT_URL="https://thepiratebay.org/search/"
  ROOT_URL="https://piratenproxy.nl/thepiratebay.org/search/"
  for PAGE in $(seq 0 $(($PAGES - 1))); do
    URL="${ROOT_URL}$QUERY/$PAGE/3//"
    echo "QUERY $URL"
    safecurl "$URL"                             |
     grep 'href="\(magnet:\|/torrent/\)'        |
     tr '\n' ' '                                |
     sed 's|="/torrent/[^>]*>|\n|g'             |
     sed 's|</a>.*<a href="magnet:|#magnet:|'   |
     sed 's|" title.*$||'                       |
     grep -v '"detName"'                        |
     while read line; do
      TORRENT_URL=$(echo "$line" | sed 's/^.*#//')
      TORRENT_NAME=$(echo "$line" | sed 's/#.*$//' | sed 's/\./ /g')
      download_if_required "magnet"
    done
  done
}

function set_resstr {
  P20=
  if [ ! -z "$1" ]; then
    P20=$1
  fi
  RESSTR=
  if [ -z "$NORES" ]; then
    RESSTR="$P20$RES"p
  fi
}

function get_recent_piratebay {
  SLEEPDELAY=100
  echo "$SOURCES" | while read SOURCE; do
    SOURCE=$(echo "$SOURCE" | sed 's/\s\+/ /g' | sed -r 's/(^ | $)//g')
    PAGES=1
    if echo "$SOURCE" | grep " [0-9]\+\s*" > /dev/null; then
      PAGES=$(echo "$SOURCE" | sed -r 's/^.* ([0-9]+) ?$/\1/')
    fi
    QUERY=$(echo "$SOURCE"        |
     sed -r 's| +[0-9]+?$||'      |
     sed 's/ /%20/g')"%20${RES}p"
    search_episodes_piratebay
  done
}

function get_recent_eztv {
  SLEEPDELAY=300
  PAGES=10
  set_resstr
  for PAGE in $(seq 0 $(($PAGES - 1))); do
    QUERY="page_$PAGE"
    search_episodes_eztv_magnet
  done
}

function catchup_show_piratebay {
  SLEEPDELAY=180
  PAGES=10
  set_resstr "%20"
  ROOTQUERY=$QUERY
  QUERY="$QUERY$RESSTR"
  search_episodes_piratebay
  QUERY=$ROOTQUERY
}

function catchup_show_eztv {
  SLEEPDELAY=180
  set_resstr
  ROOTQUERY=$QUERY
  QUERY="search/$QUERY"
  search_episodes_eztv_magnet
  QUERY=$ROOTQUERY
}

echo
echo $(date)
echo "----------------------"
if [ -z "$CATCHUP" ]; then
  get_recent_eztv
  get_recent_piratebay
else
  SHOWS=$CATCHUP
  QUERY=$(echo "$CATCHUP"       |
   sed 's/\s*#NOSEASON\s*$//'   |
   sed 's/\s\+/ /g'             |
   sed -r 's/(^ | $)//g'        |
   sed 's/ /%20/g')
  catchup_show_eztv
  catchup_show_piratebay
fi
