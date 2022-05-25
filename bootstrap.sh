#!/usr/bin/env bash

shopt -s nocasematch

branch=$1

echo -e "Stack v0.0.1"
echo -e "Starting the bootstrap process...\n"

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo -e "This script supports only UEFI systems"
  echo -e "Process exiting with code: 1"
  exit 1
fi

echo -e "Setting keyboard layout..."

read -p "Enter the key map of your keyboard: [us] " keymap
keymap=${keymap:-"us"}

keymap_path=$(find /usr/share/kbd/keymaps/ -type f -name "$keymap.map.gz")

while [ -z "$keymap_path" ]; do
  echo -e "Invalid key map: '$keymap'"
  read -p "Please enter a valid keymap: [us] " keymap
  keymap=${keymap:-"us"}

  keymap_path=$(find /usr/share/kbd/keymaps/ -type f -name "$keymap.map.gz")
done

loadkeys $keymap

echo -e "Keyboard layout set to '$keymap'"

echo -e "\nPartitioning the installation disk..."
echo -e "The following disks found in your system:"

lsblk

read -p "Enter the device path of the disk to apply the installation on: " device

while [ ! -b "$device" ]; do
  echo -e "Invalid device path: '$device'"
  read -p "Please enter a valid device path: " device
done

echo -e "Installation disk set to '$device'"

read -p "Enter the size of the swap partition in GB (0 to skip): [0] " swapsize
swapsize=${swapsize:-0}

while [[ ! $swapsize =~ ^[0-9]+$ ]]; do
  echo -e "Invalid swap size: '$swapsize'"
  read -p "Please enter a valid size (0 to skip): [0] " swapsize
  swapsize=${swapsize:-0}
done

if [[ $swapsize -gt 0 ]]; then
  echo -e "Swap size set to '$swapsize' GB"
else
  echo -e 'Swap has been skipped'
fi

echo -e "IMPORTANT, all data in '$device' will be lost"
read -p "Shall we proceed and partition the disk? [y/N] " answer

if [[ ! $answer =~ ^(yes|y)$ ]]; then
  echo -e "Canceling the installation process..."
  echo -e "Process exiting with code: 0"
  exit 0
fi

echo -e "Erasing any existing GPT and MBR data tables..."

sgdisk -Z "$device"

echo -e "Creating a clean GPT table free of partitions..."

sgdisk -og "$device"

echo -e "Creating the boot EFI partition..."

sgdisk -n 1:0:+500M -c 1:"EFI System Partition" -t 1:ef00 "$device"
dev_efi=${device}1

if [[ $swapsize -gt 0 ]]; then
  echo -e "Creating the swap partition..."

  sgdisk -n 2:0:+${swapsize}G -c 2:"Swap Partition" -t 2:8200 "$device"
  dev_swap=${device}2

  echo -e "Creating the root partition..."

  sgdisk -n 3:0:0 -c 3:"Root Partition" -t 3:8300 "$device"
  dev_root=${device}3
else
  echo -e "Creating the root partition..."

  sgdisk -n 2:0:0 -c 2:"Root Partition" -t 2:8300 "$device"
  dev_root=${device}2
fi

echo -e "Partitioning on '$device' has been completed:\n"

sgdisk -p "$device"

echo -e "\nFormatting partitions in '$device'..."
echo -e "Formating the '$dev_efi' boot EFI partition as FAT32..."

mkfs.fat -F 32 $dev_efi

if [[ $swapsize -gt 0 ]]; then
  echo -e "Formating the '$dev_swap' swap partition..."

  mkswap $dev_swap
  swapon $dev_swap
fi

echo -e "Formating the '$dev_root' root partition as EXT4..."

mkfs.ext4 -q $dev_root

echo -e "Formating has been completed successfully"

echo -e "\nMounting the boot and root partitions..."

mount $dev_root /mnt

mkdir -p /mnt/boot
mount $dev_efi /mnt/boot

echo -e "Partitions have been mounted under '/mnt':\n"

lsblk $device

echo -e "\nUpdating the system clock..."

timedatectl set-ntp true
timedatectl status

echo -e "System clock has been updated"

echo -e "\nUpdating the mirror list..."

resolved_country=$(curl -sLo- https://ipapi.co/country_name?format=json)
read -p "What is your current location? [$resolved_country] " country
country=${country:-$resolved_country}

echo -e "Refreshing the mirror list from servers in $country..."

reflector --country $country --age 8 --sort age --save /etc/pacman.d/mirrorlist

while [ ! $? -eq 0 ]; do
  echo -e "Reflector failed for '$country'"
  read -p "Please enter another country: [$resolved_country] " country
  country=${country:-$resolved_country}

  reflector --country $country --age 8 --sort age --save /etc/pacman.d/mirrorlist
done

pacman -Syy

echo -e "The mirror list is now up to date"

echo -e "\nInstalling base linux packages..."

pacstrap /mnt base linux linux-headers linux-lts linux-lts-headers linux-firmware \
  archlinux-keyring reflector rsync

echo -e "Base packages have been installed successfully"

echo -e "\nCreating the file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

echo -e "The file system table has been created in '/mnt/etc/fstab'"

echo -e "\nBootstrap process has been completed successfully"
echo -e "Script will move to the installation disk in 10 secs (ctrl-c to skip)..."

sleep 10

arch-chroot /mnt \
  bash -c "$(curl -sLo- https://raw.githubusercontent.com/tzeikob/stack/${branch:-master}/stack.sh)" &&
  echo -e "Unmounting disk partitions under '/mnt'..." &&
  umount -R /mnt &&
  echo -e "Rebooting the system in 10 secs (ctrl-c to skip)..." &&
  sleep 10 &&
  reboot