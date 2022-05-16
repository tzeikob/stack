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

echo -e "\nSetting up the system locales..."

echo "LANG=en_US.UTF-8" >> /etc/locale.conf

echo "" >> /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo -e "Locales have been genereated successfully"

echo -e "\nSetting up hostname and hosts..."
read -p "Enter the host name of your system: [arch] " hostname

if [[ $hostname =~ $BLANK ]]; then
  hostname="arch"
fi

echo $hostname >> /etc/hostname

echo "" >> /etc/hosts
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $hostname" >> /etc/hosts

echo -e "Hostname and hosts have been set"