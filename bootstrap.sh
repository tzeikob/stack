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

echo -e "\nProceeding to the disk layout..."
echo -e "The following disks found in your system:"

lsblk

read -p "Enter the block device disk the new system will be installed on: " device

while [ ! -b "$device" ]; do
  echo -e "Invalid block device: '$device'"
  read -p "Please enter a valid block device: " device
done

echo -e "Installation disk set to block device '$device'"

echo -e "\nIMPORTANT, all data in '$device' will be lost"
read -p "Shall we proceed and partition the disk? [y/N] " answer

if [[ ! $answer =~ ^(yes|y)$ ]]; then
  echo -e "\nCanceling the installation process..."
  echo -e "Process exiting with code: 0"
  exit 0
fi

echo -e "\nCreating a clean GPT table..."

parted --script $device mklabel gpt

echo -e "GPT table has been created"

echo -e "Creating the boot EFI partition..."

parted --script $device mkpart "Boot" fat32 1MiB 501MiB
parted --script $device set 1 boot on

echo -e "EFI boot partition has been created under '${device}1'"

echo -e "Creating the root partition..."

parted --script $device mkpart "Root" ext4 501Mib 100%

echo -e "The root partition has been created under '${device}2'"

echo -e "Partitioning on '$device' has been completed:\n"

parted --script $device print

echo -e "\nFormatting partitions in '$device'..."
echo -e "Formating the '${device}1' boot EFI partition as FAT32..."

mkfs.fat -F 32 ${device}1

echo -e "Formating the '${device}2' root partition as EXT4..."

mkfs.ext4 -F -q ${device}2

echo -e "Formating has been completed successfully"

echo -e "\nMounting the boot and root partitions..."

mount ${device}2 /mnt
mount --mkdir ${device}1 /mnt/boot

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

echo -e "\nInstalling the base system..."

read -p "Which linux kernels to install: [stable/lts/ALL] " kernels
kernels=${kernels:-"all"}

while [[ ! $kernels =~ ^(stable|lts|all)$ ]]; do
  echo -e "Invalid linux kernel: '$kernels'"
  read -p "Please enter which linux kernels to install: [stable/lts/ALL] " kernels
  kernels=${kernels:-"all"}
done

if [[ $kernels =~ ^stable$ ]]; then
  linux_kernels="linux"
  linux_headers="linux-headers"
elif [[ $kernels =~ ^lts$ ]]; then
  linux_kernels="linux-lts"
  linux_headers="linux-lts-headers"
else
  linux_kernels="linux linux-lts"
  linux_headers="linux-headers linux-lts-headers"
fi

pacstrap /mnt base $linux_kernels $linux_headers linux-firmware archlinux-keyring reflector rsync sudo

echo -e "Base packages have been installed successfully"

echo -e "\nCreating the file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

echo -e "The file system table has been created in '/mnt/etc/fstab'"

echo -e "\nBootstrap process has been completed successfully"
echo -e "Moving to the new system in 10 secs (ctrl-c to skip)..."

sleep 10

arch-chroot /mnt \
  bash -c "$(curl -sLo- https://raw.githubusercontent.com/tzeikob/stack/${branch:-master}/stack.sh)" -s "$kernels" "$country" &&
  echo -e "Unmounting disk partitions under '/mnt'..." &&
  umount -R /mnt || echo -e "Ignoring any busy mounted points..." &&
  echo -e "Rebooting the system in 10 secs (ctrl-c to skip)..." &&
  sleep 10 &&
  reboot