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

echo -e "\nInstalling base packages..."

pacman -S --noconfirm --needed \
  base-devel pacman-contrib pkgstats grub mtools dosfstools gdisk \
  parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
  man-db man-pages texinfo cups bluez bluez-utils unzip terminus-font \
  vim nano git htop tree arch-audit atool zip xz unace p7zip gzip lzop \
  bzip2 unrar \
  $([ $IS_UEFI == "yes" ] && echo 'efibootmgr')

echo "Base packages have been installed"

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

nopasswd_off

echo "Moving to the next process..."
sleep 5
