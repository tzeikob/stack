#!/usr/bin/env bash

SIDE=$1
DELTA=${2:-"30"}

case $SIDE in
  "right")
    DIM="WIDTH";
    DELTA=$((1 * DELTA));;
  "left")
    DIM="WIDTH";
    DELTA=$((-1 * DELTA));;
  "up")
    DIM="HEIGHT";
    DELTA=$((-1 * DELTA));;
  "down")
    DIM="HEIGHT"
    DELTA=$((1 * DELTA));;
esac

X=0; Y=0;

if [ "$DIM" = "WIDTH" ]; then
  x=$DELTA
  DIRECTION="right"
  FALL="left"
elif ["$DIM" = "HEIGHT" ]; then
  y=$DELTA
  DIRECTION="top"
  FALL="bottom"
fi

bspc node -z "$DIRECTION" "$X" "$Y" || bspc node -z "$FALL" "$X" "$Y";
