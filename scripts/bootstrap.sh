#!/usr/bin/env bash

update_clock () {
  echo "Updating the system clock..."

  timedatectl set-ntp true
  timedatectl status

  echo "System clock has been updated"
}

set_mirrors () {
  echo "Setting up pacman and mirrors list..."

  local OLD_IFS=$IFS && IFS=","
  MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

  reflector --country "$MIRRORS" --age 8 --sort age --save /etc/pacman.d/mirrorlist

  echo "Mirror list set to $MIRRORS"
}

sync_packages () {
  echo "Starting synchronizing packages..."

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

  echo "Pacman parallel downloading has been enabled"

  pacman -Syy

  echo "Packages have been synchronized with master"
}

update_keyring () {
  echo "Updating keyring package..."

  pacman --noconfirm -Sy archlinux-keyring

  echo "Keyring has been updated successfully"
}

install_kernels () {
  echo "Installing the linux kernels..."

  local KERNEL_PKGS=""

  if [[ "${KERNELS[@]}" =~ stable ]]; then
    KERNEL_PKGS="linux linux-headers"
  fi

  if [[ "${KERNELS[@]}" =~ lts ]]; then
    KERNEL_PKGS="$KERNEL_PKGS linux-lts linux-lts-headers"
  fi

  pacstrap /mnt base $KERNEL_PKGS linux-firmware archlinux-keyring reflector rsync sudo

  echo -e "Kernels have been installed"
}

grant () {
  case "$1" in
    "nopasswd")
      sed -i 's/^# \(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /mnt/etc/sudoers;;
  esac

  echo "Sudoing permision $1 has been granted"
}

copy_files () {
  echo "Start copying installation files..."

  cp -R "$HOME" /mnt/root

  echo "Installation files have been copied to /root"
}

echo -e "\nStarting the bootstrap process..."

source $OPTIONS

update_clock &&
  set_mirrors &&
  sync_packages &&
  update_keyring &&
  install_kernels &&
  grant "nopasswd" &&
  copy_files

echo -e "\nBootstrap process has been completed successfully"
echo "Moving to the next process..."
sleep 5
