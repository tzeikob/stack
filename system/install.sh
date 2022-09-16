#!/usr/bin/env bash

set_host () {
  echo -e "\nSetting up system host..."

  echo "$HOSTNAME" >> /etc/hostname

  echo "Hostname has been set to $HOSTNAME"

  printf '%s\n' \
    '127.0.0.1    localhost' \
    '::1          localhost' \
    "127.0.1.1    $HOSTNAME" > /etc/hosts

  echo "Hostname has been added to hosts"

  echo "Host has been set successfully"
}

set_users () {
  echo -e "\nSetting up system users..."

  useradd -m -G wheel,audio,video,optical,storage "$USERNAME"
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  echo "Sudoer user $USERNAME has been created"

  echo "$USERNAME:$USER_PASSWORD" | chpasswd

  echo "Password has been given to user $USERNAME"

  echo "root:$ROOT_PASSWORD" | chpasswd

  echo "Password has been given to the root user"
  echo "System users have been setup"
}

set_keymap () {
  echo -e "\nSetting keyboard keymap..."

  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

  echo "Virtual console keymap set to $KEYMAP"

  loadkeys "$KEYMAP"

  echo "Keyboard's keymap has been set to $KEYMAP"
}

set_locale () {
  sed -i "s/#\(${LOCALE}.*\)/\1/" /etc/locale.gen
  locale-gen

  local PARTS=($LOCALE)
  echo "LANG=${PARTS[0]}" >> /etc/locale.conf

  echo "Locale has been set to $LOCALE"
}

set_timezone () {
  echo -e "\nSetting the system's timezone..."

  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

  sed -i 's/^#NTP=/NTP=time.google.com/' /etc/systemd/timesyncd.conf

  echo "NTP server has been set to google time"

  hwclock --systohc

  echo "System clock has been synchronized to hardware clock"

  echo "Timezone has been set to $TIMEZONE"
}

set_mirrors () {
  echo -e "\nSetting up pacman and mirrors list..."

  local OLD_IFS=$IFS && IFS=","
  MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

  reflector --country "$MIRRORS" --age 8 --sort age --save /etc/pacman.d/mirrorlist
  sed -i "s/# --country.*/--country ${MIRRORS}/" /etc/xdg/reflector/reflector.conf

  echo "Mirror list set to $MIRRORS"
}

config_pacman () {
  echo -e "\nConfiguring the pacman package manager..."

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

  echo "Parallel downloading has been enabled"

  cp /root/stack/system/pacman/orphans.hook /usr/share/libalpm/hooks

  echo "Orphan packages post hook has been created"
  echo "Pacman has been configured"
}

sync_packages () {
  echo -e "\nStarting synchronizing packages..."

  pacman -Syy

  echo "Packages have been synchronized with master"
}

install_packages () {
  echo -e "\nInstalling the base packages..."

  pacman -S --noconfirm \
    base-devel pacman-contrib pkgstats grub mtools dosfstools gdisk \
    parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
    man-db man-pages texinfo cups bluez bluez-utils unzip terminus-font \
    vim nano git htop tree arch-audit atool zip xz unace p7zip gzip lzop \
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils openbsd-netcat ipset \
    $([ "$IS_UEFI" = "yes" ] && echo 'efibootmgr')

  yes | pacman -S nftables iptables-nft

  echo "Base packages have been installed"
}

install_display_server () {
  echo "Installing the xorg display server..."

  pacman -S --noconfirm xorg xorg-xinit xorg-xrandr arandr

  cp /root/stack/system/xorg/xorg.conf /etc/X11

  echo "Configuration has been saved to /etc/X11/xorg.conf"
  echo "Xorg server has been installed"
}

install_drivers () {
  echo -e "\nInstalling hardware drivers..."

  local CPU_PKGS=""
  if [ "$CPU" = "amd" ]; then
    CPU_PKGS="amd-ucode"
  elif [ "$CPU" = "intel" ]; then
    CPU_PKGS="intel-ucode"
  fi

  local GPU_PKGS=""
  if [ "$GPU" = "nvidia" ]; then
    [[ "${KERNELS[@]}" =~ stable ]] && GPU_PKGS="nvidia"
    [[ "${KERNELS[@]}" =~ lts ]] && GPU_PKGS="$GPU_PKGS nvidia-lts"

    GPU_PKGS="$GPU_PKGS nvidia-utils nvidia-settings"
  elif [ "$GPU" = "amd" ]; then
    GPU_PKGS="xf86-video-amdgpu"
  elif [ "$GPU" = "intel" ]; then
    GPU_PKGS="xf86-video-intel"
  else
    GPU_PKGS="xf86-video-qxl"
  fi

  local VM_PKGS=""
  if [ "$IS_VIRTUAL" = "yes" ]; then
    if [ "$IS_VIRTUAL_BOX" = "yes" ]; then
      VM_PKGS="$VM_PKGS virtualbox-guest-utils"
    fi
  fi

  pacman -S --noconfirm \
    acpi acpid acpi_call \
    networkmanager wireless_tools netctl wpa_supplicant \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack pavucontrol \
    $CPU_PKGS $GPU_PKGS $VM_PKGS

  echo "Drivers have been installed"
}

install_yay () {
  echo -e "\nInstalling the yay package manager..."

  cd "/home/$USERNAME"
  git clone https://aur.archlinux.org/yay.git

  chown -R "$USERNAME":"$USERNAME" yay && cd yay
  sudo -u "$USERNAME" makepkg -si --noconfirm

  cd /root && rm -rf "/home/$USERNAME/yay"

  echo "Yay package manager has been installed"
}

config_security () {
  echo -e "\nHardening system's security..."

  sed -i 's;# dir = /var/run/faillock;dir = /var/lib/faillock;' /etc/security/faillock.conf

  echo "Faillocks set to be persistent after system reboot"

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

  echo "SSH login permission disabled for the root user"

  echo "Setting up a simple stateful firewall..."

  nft flush ruleset
  nft add table inet my_table
  nft add chain inet my_table my_input '{ type filter hook input priority 0 ; policy drop ; }'
  nft add chain inet my_table my_forward '{ type filter hook forward priority 0 ; policy drop ; }'
  nft add chain inet my_table my_output '{ type filter hook output priority 0 ; policy accept ; }'
  nft add chain inet my_table my_tcp_chain
  nft add chain inet my_table my_udp_chain
  nft add rule inet my_table my_input ct state related,established accept
  nft add rule inet my_table my_input iif lo accept
  nft add rule inet my_table my_input ct state invalid drop
  nft add rule inet my_table my_input meta l4proto ipv6-icmp accept
  nft add rule inet my_table my_input meta l4proto icmp accept
  nft add rule inet my_table my_input ip protocol igmp accept
  nft add rule inet my_table my_input meta l4proto udp ct state new jump my_udp_chain
  nft add rule inet my_table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump my_tcp_chain'
  nft add rule inet my_table my_input meta l4proto udp reject
  nft add rule inet my_table my_input meta l4proto tcp reject with tcp reset
  nft add rule inet my_table my_input counter reject with icmpx port-unreachable

  mv /etc/nftables.conf /etc/nftables.conf.bak
  nft -s list ruleset > /etc/nftables.conf

  echo "Firewall ruleset has been saved to /etc/nftables.conf"

  echo "Security configuration has been completed"
}

install_bootloader () {
  echo -e "\nInstalling the bootloader via GRUB..."

  if [ "$IS_UEFI" = "yes" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  else
    grub-install --target=i386-pc "$DISK"
  fi

  sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub
  sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub
  sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub

  grub-mkconfig -o /boot/grub/grub.cfg

  if [ "$IS_UEFI" = "yes" ] && [ "$IS_VIRTUAL_BOX" = "yes" ]; then
    mkdir -p /boot/EFI/BOOT
    cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
  fi

  echo "Bootloader has been installed"
}

enable_services () {
  echo -e "\nEnabling various system services..."

  systemctl enable systemd-timesyncd
  systemctl enable NetworkManager
  systemctl enable bluetooth
  systemctl enable acpid
  systemctl enable cups
  systemctl enable sshd
  systemctl enable fstrim.timer
  systemctl enable nftables
  systemctl enable reflector.timer
  systemctl enable paccache.timer

  if [ "$IS_VIRTUAL_BOX" = "yes" ]; then
    systemctl enable vboxservice
  fi

  echo "System services have been enabled"
}

copy_files () {
  echo "Start copying installation files..."

  cp -R /root/stack "/home/$USERNAME"
  chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/stack"

  echo "Installation files have been moved to /home/$USERNAME"
}

echo -e "\nStarting the system setup process..."

source /root/stack/.options

set_host &&
  set_users &&
  set_keymap &&
  set_locale &&
  set_timezone &&
  set_mirrors &&
  config_pacman &&
  sync_packages &&
  install_packages &&
  install_display_server &&
  install_drivers &&
  install_yay &&
  config_security &&
  install_bootloader &&
  enable_services &&
  copy_files

echo -e "\nSetting up the system has been completed"
echo "Moving to the next process..."
sleep 5
