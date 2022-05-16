#!/usr/bin/env bash

BLANK="^(""|[ *])$"
YES="^([Yy][Ee][Ss]|[Yy])$"

echo -e "\nSetting up the local timezone..."
read -p "Enter your timezone in slash form (e.g. Europe/Athens): " timezone

while [ ! -f "/usr/share/zoneinfo/$timezone" ]; do
  echo -e "Invalid timezone: '$timezone'"
  read -p "Please enter a valid timezone: " timezone
done

ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

echo -e "System clock synchronized to the hardware clock"
echo -e "Local timezone has been set successfully"