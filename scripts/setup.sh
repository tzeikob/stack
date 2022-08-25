#!/usr/bin/env bash

enable_nopasswd () {
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

  echo "No password mode has temporarily been enabled"
}

set_keymap () {
  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
  loadkeys $KEYMAP

  echo "Keyboard's keymap has been set to $KEYMAP"
}

set_timezone () {
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

  echo "Local timezone has been set to $TIMEZONE"
}

set_locale () {
  echo "LANG=$LOCALE" >> /etc/locale.conf
  sed -i "s/#\(${LOCALE}.*\)/\1/" /etc/locale.gen
  locale-gen

  echo "Locale has been set to $LOCALE"
}

sync_clock () {
  echo "Enabling NTP synchronization..."

  timedatectl set-ntp true
  timedatectl status
  hwclock --systohc

  echo "System clock synchronized with the hardware clock"
}

set_hostname () {
  echo $HOSTNAME >> /etc/hostname
  echo "" >> /etc/hosts
  echo "127.0.0.1    localhost" >> /etc/hosts
  echo "::1          localhost" >> /etc/hosts
  echo "127.0.1.1    $HOSTNAME" >> /etc/hosts

  echo "Hostname has been set to $HOSTNAME"
}

create_sudoer () {
  useradd -m -G wheel,audio,video,optical,storage $USERNAME
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  echo "Sudoer user $USERNAME has been created"
}

apply_passwds () {
  echo "root:$ROOT_PASSWORD" | chpasswd

  echo "User root has been given a password"

  echo "$USERNAME:$USER_PASSWORD" | chpasswd

  echo "User $USERNAME have been given a password"
}

set_mirrors () {
  echo -e "\nSetting up pacman and mirrors list..."

  local OLD_IFS=$IFS && IFS=","
  MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

  reflector --country "$MIRRORS" --age 8 --sort age --save /etc/pacman.d/mirrorlist
  sed -i "s/# --country.*/--country ${MIRRORS}/" /etc/xdg/reflector/reflector.conf

  echo "Mirror list set to ${MIRRORS[@]}"
}

boost_download () {
  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

  echo "Pacman parallel downloading has been enabled"
}

sync_packages () {
  echo -e "\nStarting synchronizing packages..."

  pacman -Syy

  echo "Packages have been synchronized with master"
}

install_packages () {
  echo -e "\nInstalling base packages..."

  pacman -S --noconfirm --needed \
    base-devel pacman-contrib pkgstats grub mtools dosfstools gdisk \
    parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
    man-db man-pages texinfo cups bluez bluez-utils unzip terminus-font \
    vim nano git htop tree arch-audit atool zip xz unace p7zip gzip lzop \
    bzip2 unrar \
    $([ $IS_UEFI == "yes" ] && echo 'efibootmgr')

  echo "Base packages have been installed"
}

install_drivers () {
  echo -e "\nInstalling hardware drivers..."

  [ $CPU == "amd" ] && CPU_PKGS="amd-ucode" || CPU_PKGS="intel-ucode"

  if [[ $GPU == "nvidia" ]]; then
    [[ "${KERNELS[@]}" =~ "stable" ]] && GPU_PKG="nvidia"
    [[ "${KERNELS[@]}" =~ "lts" ]] && GPU_PKG="$GPU_PKG nvidia-lts"

    GPU_PKG="$GPU_PKG nvidia-utils nvidia-settings"
  elif [[ $GPU == "amd" ]]; then
    GPU_PKG="xf86-video-amdgpu"
  elif [[ $GPU == "intel" ]]; then
    GPU_PKG="xf86-video-intel"
  elif [[ $GPU == "vm" ]]; then
    GPU_PKG="xf86-video-qxl"
  fi

  [[ $IS_VM == "yes" ]] && VM_PKGS="virtualbox-guest-utils"

  pacman -S --noconfirm --needed \
    acpi acpid acpi_call \
    networkmanager dialog wireless_tools netctl inetutils dnsutils \
    wpa_supplicant openssh nfs-utils openbsd-netcat nftables iptables-nft ipset \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack pavucontrol \
    xorg xorg-xinit xorg-xrandr arandr \
    $CPU_PKGS $GPU_PKGS $VM_PKGS

  echo "Drivers have been installed"
}

echo -e "\nStarting the setup process..."

source $OPTIONS

enable_nopasswd &&
  set_keymap &&
  set_timezone &&
  set_locale &&
  sync_clock &&
  set_hostname &&
  create_sudoer &&
  apply_passwds &&
  set_mirrors &&
  boost_download &&
  sync_packages &&
  install_packages &&
  install_drivers

echo -e "\nSetting up the system has been completed"
echo "Moving to the next process..."
sleep 5
