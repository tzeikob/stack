#!/usr/bin/env bash

source $OPTIONS

echo -e "\nStarting the setup process..."

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
loadkeys $KEYMAP

echo "Keyboard's keymap has been set to $KEYMAP"

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

echo "Local timezone has been set to $TIMEZONE"

echo "LANG=$LOCALE" >> /etc/locale.conf
sed -i "s/#\(${LOCALE}.*\)/\1/" /etc/locale.gen
locale-gen

echo "Locale has been set to $LOCALE"

echo "Moving to the next process..."
sleep 5
