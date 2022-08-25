#!/usr/bin/env bash

source $OPTIONS

nopasswd_on () {
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
  echo "No password mode has been enabled"
}

nopasswd_off () {
  sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
  echo "No password mode has been disabled"
}

echo -e "\nStarting the setup process..."

nopasswd_on

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

useradd -m -G wheel,audio,video,optical,storage $USERNAME
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "Sudoer user $USERNAME has been created"

echo "root:$ROOT_PASSWORD" | chpasswd

echo "User root has been given a password"

echo "$USERNAME:$USER_PASSWORD" | chpasswd

echo "User $USERNAME have been given a password"

nopasswd_off

echo "Moving to the next process..."
sleep 5
