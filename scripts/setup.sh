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

echo "Enabling NTP synchronization..."

timedatectl set-ntp true && timedatectl status
hwclock --systohc

echo "System clock synchronized with the hardware clock"

echo $HOSTNAME >> /etc/hostname
echo "" >> /etc/hosts
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $HOSTNAME" >> /etc/hosts

echo -e "Hostname has been set to $HOSTNAME"

echo "Moving to the next process..."
sleep 5
