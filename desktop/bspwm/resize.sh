#!/usr/bin/env bash

SIDE=$1
DELTA=${2:-"10"}

case $SIDE in
  "right")
    ORIENTATION="horizontal"
    DELTA=$((1 * DELTA));;
  "left")
    ORIENTATION="horizontal"
    DELTA=$((-1 * DELTA));;
  "up")
    ORIENTATION="vertical"
    DELTA=$((-1 * DELTA));;
  "down")
    ORIENTATION="vertical"
    DELTA=$((1 * DELTA));;
esac

X=0; Y=0;

if [ "$ORIENTATION" = "horizontal" ]; then
  X=$DELTA
  DIRECTION="right"
  OPPOSITE="left"
elif [ "$ORIENTATION" = "vertical" ]; then
  Y=$DELTA
  DIRECTION="top"
  OPPOSITE="bottom"
fi

bspc node -z "$DIRECTION" "$X" "$Y" || bspc node -z "$OPPOSITE" "$X" "$Y"
