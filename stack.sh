#!/usr/bin/env bash

VERSION="0.1.0"

BLANK="^(""|[ *])$"
YES="^([Yy][Ee][Ss]|[Yy])$"

NVIDIA="^(nvidia|n)$"
AMD="^(amd|a)$"
INTEL="^(intel|i)$"
VIRTUAL="^(virtual|v)$"

CPU="($AMD|$INTEL)"
GPU="($NVIDIA|$AMD|$INTEL|$VIRTUAL)"

shopt -s nocasematch

opt=${1-}

case $opt in
  "--bootstrap" | "-b" | "")
    BOOTSTRAP=true;;
  "--no-bootstrap")
    BOOTSTRAP=false;;
  *)
    echo -e "option '$opt' is not supported"
    echo -e "Process exiting with code: 1"
    exit 1;;
esac

if [ $BOOTSTRAP == "true" ]; then
  echo -e "Stack v$VERSION"
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
    bash -c "$(curl -sLo- https://raw.githubusercontent.com/tzeikob/stack/issue-22/stack.sh)" -s --no-bootstrap &&
    echo -e "Unmounting the partitions..." &&
    umount -R /mnt &&
    echo -e "Rebooting the system in 10 secs (ctrl-c to cancel)..." &&
    sleep 10 &&
    reboot
else
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

  echo -e "\nInstalling extra base packages..."

  pacman -S base-devel grub os-prober efibootmgr mtools dosfstools wpa_supplicant openssh \
    bash-completion nfs-utils networkmanager dialog wireless_tools netctl inetutils dnsutils reflector rsync \
    cups bluez bluez-utils \
    terminus-font vim nano git

  echo -e "\nInstalling hardware drivers..."
  read -p "What proccessor is your system running? [AMD/intel] " cpu_vendor

  while [[ ! $cpu_vendor =~ $CPU && ! $cpu_vendor =~ $BLANK ]]; do
    echo -e "Invalid cpu vendor: '$cpu_vendor'"
    read -p "Please enter a valid cpu vendor: " cpu_vendor
  done

  if [[ $cpu_vendor =~ $INTEL ]]; then
    cpu_vendor="intel"
    cpu_pkg="intel-ucode"
  else
    cpu_vendor="amd"
    cpu_pkg="amd-ucode"
  fi

  echo -e "Installing $cpu_vendor cpu packages..."

  pacman -S $cpu_pkg

  read -p "What video card is your system using? [NVIDIA/amd/intel/virtual] " gpu_vendor

  while [[ ! $gpu_vendor =~ $GPU && ! $gpu_vendor =~ $BLANK ]]; do
    echo -e "Invalid gpu vendor: '$gpu_vendor'"
    read -p "Please enter a valid gpu vendor: " gpu_vendor
  done

  if [[ $gpu_vendor =~ $AMD ]]; then
    gpu_vendor="amd"
    gpu_pkg="xf86-video-ati"
    gpu_module="amdgpu"
  elif [[ $gpu_vendor =~ $INTEL ]]; then
    gpu_vendor="intel"
    gpu_pkg="xf86-video-intel"
    gpu_module="i915"
  elif [[ $gpu_vendor =~ $VIRTUAL ]]; then
    gpu_vendor="virtual"
    gpu_pkg=""
    gpu_module=""
  else
    gpu_vendor="nvidia"
    gpu_pkg="nvidia nvidia-utils nvidia-settings"
    gpu_module="nvidia"
  fi

  if [[ ! $gpu_pkg =~ $BLANK ]]; then
    echo -e "Installing $gpu_vendor gpu packages..."

    pacman -S $gpu_pkg

    sed -i "s/MODULES=(\(.*\))$/MODULES=(\1 $gpu_module)/" /etc/mkinitcpio.conf
    sed -i "s/MODULES=( \(.*\))$/MODULES=(\1)/" /etc/mkinitcpio.conf

    echo -e "Video card driver module added into the '/etc/mkinitcpio.conf/'"

    mkinitcpio -p linux
    mkinitcpio -p linux-lts

    echo -e "Initramfs has been re-genereated successfully"
  else
    echo -e "No gpu packages will be installed"
  fi

  echo -e "\nSetting up users and passwords..."
  echo -e "Adding password for the root user..."

  passwd

  echo -e "Creating a new sudoer user..."
  read -p "Enter the name of the sudoer user: [bob] " username

  if [[ $username =~ $BLANK ]]; then
    username="bob"
  fi

  useradd -m -g users -G wheel $username

  echo -e "Adding password for the user $username..."

  passwd $username

  echo -e "Adding user $username to the group of sudoers..."

  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  echo -e "User $username with sudo priviledges has been created"

  echo -e "\nInstalling the bootloader via GRUB..."

  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
  grub-mkconfig -o /boot/grub/grub.cfg

  sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub
  sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub
  sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub

  grub-mkconfig -o /boot/grub/grub.cfg

  echo -e "Bootloader has been installed"

  echo -e "\nEnabling system services..."

  systemctl enable NetworkManager
  systemctl enable bluetooth
  systemctl enable cups
  systemctl enable sshd
  systemctl enable reflector.timer
  systemctl enable fstrim.timer

  echo -e "\nScript has been completed successfully!"
  echo -e "Exiting back to archiso..."
fi