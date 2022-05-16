#!/usr/bin/env bash

VERSION="0.1.0"
BRANCH=${1:-"master"}"

BLANK="^(""|[ *])$"
YES="^([Yy][Ee][Ss]|[Yy])$"

echo -e "Stack v$VERSION - $BRANCH"
echo -e "Starting base installation process"

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo -e "This script supports only UEFI systems"
  echo -e "Process exiting with code: 1"
  exit 1
fi

echo -e "\nPartitioning and formatting the installation disk..."
echo -e "The following disks found in your system:"

lsblk

read -p "Enter the device path of the disk to apply the installation: " device

while [ ! -b "$device" ]; do
  echo -e "Invalid device path: '$device'"
  read -p "Please enter a valid device path: " device
done

read -p "Do you want to create swap partition? [y/N] " swap
read -p "IMPORTANT, all data in '$device' will be lost, shall we proceed? [y/N] " answer

if [[ ! $answer =~ $YES ]]; then
  echo -e "Canceling the installation process..."
  echo -e "Process exiting with code: 0"
  exit 0
fi

echo -e "\nErasing existing partitions in '$device'..."

(
  echo o
  echo y
  echo w
  echo y
) | gdisk $device

echo -e "\nCreating installation partitions in '$device'..."

(
  echo n     # create new partition
  echo       # default to the next partition id
  echo       # default the first sector
  echo +500M # set size to 500MB
  echo ef00  # set partition type to EFI
  [[ $swap =~ $YES ]] && echo n     # create new partition
  [[ $swap =~ $YES ]] && echo       # default to the next partition id
  [[ $swap =~ $YES ]] && echo       # default the first sector
  [[ $swap =~ $YES ]] && echo +2G   # set size to 2GB
  [[ $swap =~ $YES ]] && echo 8200  # set partition type to Swap
  echo n     # create new partition
  echo       # default to the next partition id
  echo       # default the first sector
  echo       # set size to the remaining disk size
  echo 8300  # set partition type to Linux File System
  echo w     # write changes
  echo y     # confirm writing chages
) | gdisk $device

echo -e "\nPrinting a short report of the '$device'..."

fdisk $device -l

dev_efi=${device}1
dev_swap=${device}2
dev_root=${device}3

if [[ ! $swap =~ $YES ]]; then
  dev_root=${device}2
fi

echo -e "\nFormating the '$dev_efi' EFI partition as FAT32..."

mkfs.fat -F 32 $dev_efi

if [[ $swap =~ $YES ]]; then
  echo -e "\nFormating the '$dev_swap' swap partition..."
  mkswap $dev_swap
  swapon $dev_swap
fi

echo -e "\nFormating the '$dev_root' root partition as EXT4..."

mkfs.ext4 $dev_root

echo -e "Disk partitioning has been completed successfully"

echo -e "\nMounting the EFI and root partitions..."

mount $dev_root /mnt

mkdir -p /mnt/boot
mount $dev_efi /mnt/boot

echo -e "Partitions have been mounted under '/mnt':"

lsblk $device

echo -e "\nStarting the installation of the base packages..."
echo -e "Updating the system clock..."

timedatectl set-ntp true
timedatectl status

echo -e "System clock has been updated"

echo -e "Refreshing the mirror list..."

pacman -Syy

echo -e "The mirror list is now up to date"
echo -e "Installing base linux packages..."

pacstrap /mnt base linux linux-headers linux-lts linux-lts-headers linux-firmware archlinux-keyring

echo -e "Base packages have been installed successfully"

echo -e "\nCreating the file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

echo -e "The file system table has been created in '/mnt/etc/fstab'"

echo -e "Moving to the installation disk..."

arch-chroot /mnt \
  bash -c "$(curl -sLo- https://raw.githubusercontent.com/tzeikob/stack/$BRANCH/configure.sh)" &&
  echo -e "Unmounting the partitions..." &&
  umount -R /mnt &&
  echo -e "Rebooting the system in 10 secs (ctrl-c to cancel)..." &&
  sleep 10 &&
  reboot