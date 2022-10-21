#!/usr/bin/env bash

source ~/.config/stack/utils.sh

FIRST_ARG=$1

if [ "$FIRST_ARG" = "-y" ]; then
  REPLY="yes"
else
  askme "The screen will be locked, proceed?" "yes" "no"
fi

if [ "$REPLY" = "yes" ]; then
  slock
fi