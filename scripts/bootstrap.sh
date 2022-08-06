#!/usr/bin/env bash

shopt -s nocasematch

source .options

echo -e "\nStarting the bootstrap process..."

echo "Updating the system clock..."

timedatectl set-ntp true
timedatectl status

echo "System clock has been updated"

echo "Updating the mirror list from $COUNTRY..."

reflector --country $COUNTRY --age 8 --sort age --save /etc/pacman.d/mirrorlist

pacman --noconfirm -Sy archlinux-keyring

echo "The mirror list is now up to date"
echo "Bootstrap process has been completed successfully"
