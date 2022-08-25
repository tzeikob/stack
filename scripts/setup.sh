#!/usr/bin/env bash

source $OPTIONS

nopasswd_on () {
  
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

echo -e "\nSetting up pacman and mirrors list..."

OLD_IFS=$IFS && IFS=","
MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

reflector --country "$MIRRORS" --age 8 --sort age --save /etc/pacman.d/mirrorlist
sed -i "s/# --country.*/--country ${MIRRORS}/" /etc/xdg/reflector/reflector.conf

echo "Mirror list set to ${MIRRORS[@]}"

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

echo "Pacman parallel downloading has been enabled"

echo -e "\nStarting synchronizing packages..."

pacman -Syy

echo "Packages have been synchronized with master"

nopasswd_off

echo "Moving to the next process..."
sleep 5
