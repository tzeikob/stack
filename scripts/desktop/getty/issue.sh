#!/usr/bin/env bash

LOGO=$(figlet -f pagga " $HOSTNAME ")
TODAY=$(date)

echo -e "$LOGO\n" > /etc/issue
echo -e "$TODAY\n" >> /etc/issue
