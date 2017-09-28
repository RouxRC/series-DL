#!/bin/bash

cd $(dirname $0)
source config.inc
if [ ! -z "$3" ]; then
  touch "$3".done
  mv "$3"* "$ACHIEVED_DIR"/
fi
