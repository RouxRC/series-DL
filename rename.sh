#!/bin/bash

cd $(dirname $0)
source config.inc

cd "$READY_DIR"

rename -v 's/\[[^\]*]tv\]//' *\[*tv\].*
ls *English*Addic7ed* 2> /dev/null | while read file; do
  regex="\s\+-\s\+S\?0*\([0-9]\+\)x\([0-9]\+\)\s\+-\s\+"
  clean=`echo $file | sed 's/.English.*$//'`
  show=`echo $clean | sed 's/'"$regex"'.*$//i'`
  season=`echo $clean | sed 's/^.*'"$regex"'.*$/\1/i'`
  episode=`echo $clean | sed 's/^.*'"$regex"'.*$/\2/i'`
  end=`echo $clean | sed 's/^.*'"$regex"'//i'`
  title=`echo $end | sed 's/\.\(\([0-9]\{3,4\}p\|[ph]dtv\|xvid\|x264\)[\.\-]\?\)\+.*$//i' | sed 's/\.[A-Z]\{3\}.*$//'`
  team=`echo $end | sed 's/^'"$title"'\.\?//' | sed 's/\([0-9]\{3,4\}p\|[ph]dtv\|xvid\|x264\)[\.\-\_]\?//ig' | sed 's/\(proper\|WEBRip\)[-\.]\+//ig'`
  name=`echo "$show - $season$episode - $title"`
  show=$(echo $show | sed 's/\s*([0-9]\{4\})\s*//' | sed 's/-/?/g')
  echo "$file => $name  | $title / $team"
  convdone=false
  ct=0
  while ! $convdone && [ "$ct" -lt 4 ]; do
    ct=$(($ct+1))
    #echo "${show}*${season}?${episode}*${team}.*" | sed 's/[()]/?/g' | sed 's/\([a-z]\)/[\L\1\U\1]/ig' | sed 's/\([^1-9]\)0\([0-9][0-9]\)/\1\2/'
    ls `echo "${show}*${season}?${episode}*${team}.*" | sed 's/[()]/?/g' | sed 's/\([a-z]\)/[\L\1\U\1]/ig' | sed 's/\([^1-9]\)0\([0-9][0-9]\)/\1/' | sed 's/\s\+/*/g'` 2> /dev/null | grep "\(avi\|mp4\|mkv\|ogm\)" | while read vidfile; do
      extension=`echo $vidfile | sed 's/^.*\.\([^\.]\+\)$/\1/'`
      mv "$vidfile" "$name.$extension"
      mv "$file" "$name.srt"
      convdone=true
      break
    done
    if echo $team | grep -i "excellence" > /dev/null; then
      team=`echo $team | sed 's/excellence/remarkable/i'`
      continue
    elif echo $team | grep -i "remarkable" > /dev/null; then
      team=`echo $team | sed 's/remarkable/excellence/i'`
      continue
    elif echo $team | grep -i "lol" > /dev/null; then
      team=`echo $team | sed 's/lol/dimension/i'`
      continue
    elif echo $team | grep -i "dimension" > /dev/null; then
      team=`echo $team | sed 's/dimension/lol/i'`
      continue
    elif echo $team | grep -i "evolve" > /dev/null; then
      team=`echo $team | sed 's/evolve/2hd/i'`
      continue
    elif echo $team | grep -i "2hd" > /dev/null; then
      team=`echo $team | sed 's/2hd/evolve/i'`
      continue
    elif echo $team | grep -i "tric" > /dev/null; then
      team=`echo $team | sed 's/tric/hoc/i'`
      continue
    fi
    break
  done
done

