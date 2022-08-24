#!/usr/bin/env bash

echo -e "Starting the bootstrap process...\n"

echo -e "\nUpdating the system clock..."

timedatectl set-ntp true
sleep 60
timedatectl status

echo -e "System clock has been updated"

echo -e "\nUpdating the mirror list..."

read -p "What is your current location? [Greece] " country
country=${country:-"Greece"}

echo -e "Refreshing the mirror list from servers in $country..."

reflector --country $country --age 8 --sort age --save /etc/pacman.d/mirrorlist

while [ ! $? -eq 0 ]; do
  echo -e "Reflector failed for '$country'"
  read -p "Please enter another country: [Greece] " country
  country=${country:-"Greece"}

  reflector --country $country --age 8 --sort age --save /etc/pacman.d/mirrorlist
done

pacman --noconfirm -Sy archlinux-keyring

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
echo -e "Moving to the new system in 15 secs (ctrl-c to skip)..."

sleep 15

arch-chroot /mnt \
  bash -c "$(curl -sLo- https://raw.githubusercontent.com/tzeikob/stack/$branch/stack.sh)" -s "$device" "$branch" "$kernels" "$country" 2>&1 | tee /mnt/var/log/stack.log &&
  echo -e "Unmounting all partitions under '/mnt'..." &&
  umount -R /mnt || echo -e "Ignoring any busy mounted points..." &&
  echo -e "Rebooting the system in 15 secs (ctrl-c to skip)..." &&
  sleep 15 &&
  reboot