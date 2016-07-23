#!/bin/bash

cd $(dirname $0)
source config.inc
ROOT_URL="https://thepiratebay.org/search/"

mkdir -p .tmp
touch episodes.done

CATCHUP=$1
NORES=$2
SLEEPDELAY=30

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
  if ! ps x | grep "$CLIENT" | grep -v " grep " > /dev/null; then
    "$CLIENT" >> logTor.txt 2>&1 &
    sleep 3
  fi
}

function start_magnet {
  echo "- Starting magnet for: $TORRENT_NAME"
  start_client
  "$TORRENT_CLIENT" "$MAGNET_URL" >> logAzu.txt 2>&1 &
  echo "$LOWERED" >> episodes.done
  sleep $SLEEPDELAY
}

function search_episodes {
  RESSTR="[0-9]+0"
  if [ -z "$NORES" ]; then
    RESSTR=$RES
  fi
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
      MAGNET_URL=$(echo "$line" | sed 's/^.*#//')
      TORRENT_NAME=$(echo "$line" | sed 's/#.*$//' | sed 's/\./ /g')
      TORRENT_EP=$(echo "$TORRENT_NAME"                   |
       sed -r "s/ ${RESSTR}p( |]|\.).*$//i"               |
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
        start_magnet
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
          start_magnet
          break
        fi
      done
    done
  done
}

echo
echo $(date)
echo "----------------------"
if [ -z "$CATCHUP" ]; then
  echo "$SOURCES" | while read SOURCE; do
    SOURCE=$(echo "$SOURCE" | sed 's/\s\+/ /g' | sed -r 's/(^ | $)//g')
    PAGES=1
    if echo "$SOURCE" | grep " [0-9]\+\s*" > /dev/null; then
      PAGES=$(echo "$SOURCE" | sed -r 's/^.* ([0-9]+) ?$/\1/')
    fi
    QUERY=$(echo "$SOURCE"        |
     sed -r 's| +[0-9]+?$||'      |
     sed 's/ /%20/g')"%20${RES}p"
    search_episodes
  done
else
  RESSTR=
  if [ -z "$NORES" ]; then
    RESSTR="%20${RES}p"
  fi
  SHOWS=$CATCHUP
  QUERY=$(echo "$CATCHUP"       |
   sed 's/\s*#NOSEASON\s*$//'   |
   sed 's/\s\+/ /g'             |
   sed -r 's/(^ | $)//g'        |
   sed 's/ /%20/g')"$RESSTR"
  PAGES=10
  SLEEPDELAY=90
  search_episodes
fi
