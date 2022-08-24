#!/usr/bin/env bash

source $OPTIONS

clear

echo "Starting the bootstrap process..."

echo "Updating the system clock..."

timedatectl set-ntp true
timedatectl status

echo "System clock has been updated"

echo -e "\nUpdating the mirror list to ${MIRRORS[@]}..."

OLD_IFS=$IFS && IFS=","
MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

reflector --country "$MIRRORS" --age 8 --sort age --save /etc/pacman.d/mirrorlist

echo "The mirror list has been updated"

echo -e "\nUpdating the archlinux keyring..."

pacman --noconfirm -Sy archlinux-keyring

echo "Keyring has been updated successfully"

echo -e "\nInstalling the kernel and base packages..."

if [[ "${KERNELS[@]}" =~ "stable" ]]; then
  KERNEL_PKGS="linux linux-headers"
fi

if [[ "${KERNELS[@]}" =~ "lts" ]]; then
  KERNEL_PKGS="$KERNEL_PKGS linux-lts linux-lts-headers"
fi

pacstrap /mnt base $KERNEL_PKGS linux-firmware archlinux-keyring reflector rsync sudo

echo -e "Base packages have been installed successfully"

echo -e "\nCreating the file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

echo -e "The file system table has been created in /mnt/etc/fstab"

echo -e "\nBootstrap process has been completed successfully"
echo "Moving to the system to complete the setup..."
sleep 5
