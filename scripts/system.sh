#!/usr/bin/env bash

set -Eeo pipefail

set_host () {
  echo -e "\nSetting up system host..."

  echo "$HOSTNAME" > /etc/hostname

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

  local USERGROUPS="wheel,audio,video,optical,storage"

  if [ "$VIRTUAL" = "yes" ]; then
    groupadd "libvirt"
    USERGROUPS="$USERGROUPS,libvirt"
  fi

  useradd -m -G "$USERGROUPS" -s /bin/bash "$USERNAME" || exit 1

  local CONFIG_HOME="/home/$USERNAME/.config"
  mkdir -p "$CONFIG_HOME"
  chown -R "$USERNAME":"$USERNAME" "$CONFIG_HOME"

  local RULE="%wheel ALL=(ALL:ALL) ALL"
  sed -i "s/^# \($RULE\)/\1/" /etc/sudoers

  if ! cat /etc/sudoers | grep -q "^$RULE"; then
    echo "Error: failed to grant wheel permissions to user $USERNAME"
    exit 1
  fi

  echo "Sudoer user $USERNAME has been created"

  echo "$USERNAME:$USER_PASSWORD" | chpasswd || exit 1

  echo "Password has been given to user $USERNAME"

  echo "root:$ROOT_PASSWORD" | chpasswd || exit 1

  echo "Password has been given to the root user"
  echo "System users have been setup"
}

set_keymap () {
  echo -e "\nSetting keyboard keymap..."

  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

  echo "Virtual console keymap set to $KEYMAP"

  loadkeys "$KEYMAP" || exit 1

  echo "Keyboard's keymap has been set to $KEYMAP"
}

set_locale () {
  sed -i "s/#\(${LOCALE}.*\)/\1/" /etc/locale.gen
  locale-gen || exit 1

  local PARTS=($LOCALE)

  printf '%s\n' \
    "LANG=${PARTS[0]}" \
    "LANGUAGE=${PARTS[0]}:en:C" \
    "LC_CTYPE=${PARTS[0]}" \
    "LC_NUMERIC=${PARTS[0]}" \
    "LC_TIME=${PARTS[0]}" \
    "LC_COLLATE=${PARTS[0]}" \
    "LC_MONETARY=${PARTS[0]}" \
    "LC_MESSAGES=${PARTS[0]}" \
    "LC_PAPER=${PARTS[0]}" \
    "LC_NAME=${PARTS[0]}" \
    "LC_ADDRESS=${PARTS[0]}" \
    "LC_TELEPHONE=${PARTS[0]}" \
    "LC_MEASUREMENT=${PARTS[0]}" \
    "LC_IDENTIFICATION=${PARTS[0]}" >> /etc/locale.conf

  echo "Locale has been set to $LOCALE"
}

set_timezone () {
  echo -e "\nSetting the system's timezone..."

  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime || exit 1

  sed -i 's/^#NTP=/NTP=time.google.com/' /etc/systemd/timesyncd.conf

  echo "NTP server has been set to google time"

  hwclock --systohc --utc || exit 1

  echo "Hardware clock has been synchronized to system clock"

  echo "Timezone has been set to $TIMEZONE"
}

set_mirrors () {
  echo -e "\nSetting up pacman and mirrors list..."

  local OLD_IFS=$IFS && IFS=","
  MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

  reflector --country "$MIRRORS" --age 48 --sort age --latest 20 \
    --save /etc/pacman.d/mirrorlist || exit 1

  sed -i "s/# --country.*/--country ${MIRRORS}/" /etc/xdg/reflector/reflector.conf
  sed -i "s/--latest.*/--latest 20/" /etc/xdg/reflector/reflector.conf
  echo "--age 48" >> /etc/xdg/reflector/reflector.conf

  echo "Mirror list set to $MIRRORS"
}

boost_builds () {
  echo "Boosting system's build performance..."

  local CORES=$(grep -c ^processor /proc/cpuinfo)

  if [[ "$CORES" =~ [1-9]+ ]]; then
    echo "Detected a CPU with a total of $CORES logical cores"

    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${CORES}\"/g" /etc/makepkg.conf

    echo "Make flags have been set to $CORES CPU cores"

    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=$CORES -)/g" /etc/makepkg.conf
    sed -i "s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=$CORES -)/g" /etc/makepkg.conf

    echo "Compression threads has been set"
    echo "Boosting has been completed"
  else
    echo "Unable to resolve CPU cores, boosting is skipped"
  fi
}

config_pacman () {
  echo -e "\nConfiguring the pacman package manager..."

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

  echo "Parallel downloading has been enabled"

  echo "keyserver hkp://keyserver.ubuntu.com" >> /etc/pacman.d/gnupg/gpg.conf

  echo "GPG keyserver has been set to hkp://keyserver.ubuntu.com"

  cp /root/stack/resources/pacman/orphans.hook /usr/share/libalpm/hooks

  echo "Orphan packages post hook has been created"
  echo "Pacman has been configured"
}

sync_packages () {
  echo -e "\nStarting synchronizing packages..."

  if [[ -f /var/lib/pacman/db.lck ]]; then
    echo "Pacman database seems to be blocked"

    rm -f /var/lib/pacman/db.lck

    echo "Lock file has been removed"
  fi

  pacman -Syy || exit 1

  echo "Packages have been synchronized with master"
}

install_packages () {
  echo -e "\nInstalling the base packages..."

  pacman -S --noconfirm \
    base-devel pacman-contrib pkgstats grub mtools dosfstools gdisk \
    parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
    man-db man-pages texinfo cups bluez bluez-utils unzip terminus-font \
    vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh \
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils openbsd-netcat ipset \
    neofetch age polkit-gnome imagemagick gpick fuse2 rclone smartmontools \
    $([ "$UEFI" = "yes" ] && echo 'efibootmgr') || exit 1

  echo -e "\nReplacing iptables with nft tables..."

  printf '%s\n' y y |
    pacman -S nftables iptables-nft || exit 1

  echo "Base packages have been installed"
}

install_aur () {
  echo -e "\nInstalling the yay as AUR package manager..."

  cd "/home/$USERNAME"
  git clone https://aur.archlinux.org/yay.git || exit 1
  chown -R "$USERNAME":"$USERNAME" yay

  cd yay
  sudo -u "$USERNAME" makepkg -si --noconfirm || exit 1

  cd /root && rm -rf "/home/$USERNAME/yay"

  echo "Yay package manager has been installed"
}

install_display_server () {
  echo "Installing the xorg display server..."

  pacman -S --noconfirm xorg xorg-xinit xorg-xrandr arandr || exit 1

  cp /root/stack/resources/xorg/xorg.conf /etc/X11
  cp /root/stack/resources/xorg/keyboard.conf /etc/X11/xorg.conf.d/00-keyboard.conf

  echo "Server configurations have been saved under /etc/X11"

  local OLD_IFS=$IFS && IFS=","
  LAYOUTS="${LAYOUTS[*]}" && IFS=$OLD_IFS

  sed -i "/XkbLayout/ s/us/us,${LAYOUTS}/" /etc/X11/xorg.conf.d/00-keyboard.conf

  echo "Keyboard layouts have been set to $LAYOUTS"

  cp /root/stack/resources/xorg/xinitrc "/home/$USERNAME/.xinitrc"
  chown "$USERNAME":"$USERNAME" "/home/$USERNAME/.xinitrc"

  echo "Xinitrc has been saved to /home/$USERNAME/.xinitrc"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "/home/$USERNAME/.bash_profile"

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' /usr/lib/systemd/system/getty@.service

  echo "Xorg session has been set to start after login"
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
    GPU_PKGS="libva-intel-driver libvdpau-va-gl vulkan-intel libva-intel-driver libva-utils"
  else
    GPU_PKGS="xf86-video-qxl"
  fi

  local OTHER_PKGS=""
  if [ "$SYNAPTICS" = "yes" ]; then
    OTHER_PKGS="$OTHER_PKGS xf86-input-synaptics"
  fi

  local VM_PKGS=""
  if [ "$VIRTUAL" = "yes" ]; then
    if [ "$VIRTUAL_VENDOR" = "oracle" ]; then
      VM_PKGS="$VM_PKGS virtualbox-guest-utils"
    fi
  fi

  pacman -S --noconfirm \
    acpi acpid acpi_call \
    networkmanager wireless_tools netctl wpa_supplicant nmap dhclient smbclient \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack pavucontrol \
    $CPU_PKGS $GPU_PKGS $OTHER_PKGS $VM_PKGS || exit 1

  echo "Drivers have been installed"
}

install_utilities () {
  echo -e "\nInstalling stack utility binaries..."

  local STACK_HOME="/opt/stack"
  mkdir -p "$STACK_HOME"

  cp ~/stack/resources/stack/utils "$STACK_HOME"
  cp ~/stack/resources/stack/clock "$STACK_HOME"
  cp ~/stack/resources/stack/trash "$STACK_HOME"
  cp ~/stack/resources/stack/networks "$STACK_HOME"
  cp ~/stack/resources/stack/disks "$STACK_HOME"
  cp ~/stack/resources/stack/langs "$STACK_HOME"
  cp ~/stack/resources/stack/drive "$STACK_HOME"
  cp ~/stack/resources/stack/dropbox "$STACK_HOME"

  ln -sf "$STACK_HOME/clock" /usr/local/bin/clock
  ln -sf "$STACK_HOME/trash" /usr/local/bin/trash
  ln -sf "$STACK_HOME/networks" /usr/local/bin/networks
  ln -sf "$STACK_HOME/disks" /usr/local/bin/disks
  ln -sf "$STACK_HOME/langs" /usr/local/bin/langs
  ln -sf "$STACK_HOME/drive" /usr/local/bin/drive
  ln -sf "$STACK_HOME/dropbox" /usr/local/bin/dropbox

  echo "Stack utilities have been installed"
}

config_security () {
  echo -e "\nHardening system's security..."

  sed -i 's;# dir = /var/run/faillock;dir = /var/lib/faillock;' /etc/security/faillock.conf

  echo "Faillocks set to be persistent after system reboot"

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

  echo "SSH login permission disabled for the root user"

  echo "Setting up a simple stateful firewall..."

  nft flush ruleset &&
    nft add table inet my_table &&
    nft add chain inet my_table my_input '{ type filter hook input priority 0 ; policy drop ; }' &&
    nft add chain inet my_table my_forward '{ type filter hook forward priority 0 ; policy drop ; }' &&
    nft add chain inet my_table my_output '{ type filter hook output priority 0 ; policy accept ; }' &&
    nft add chain inet my_table my_tcp_chain &&
    nft add chain inet my_table my_udp_chain &&
    nft add rule inet my_table my_input ct state related,established accept &&
    nft add rule inet my_table my_input iif lo accept &&
    nft add rule inet my_table my_input ct state invalid drop &&
    nft add rule inet my_table my_input meta l4proto ipv6-icmp accept &&
    nft add rule inet my_table my_input meta l4proto icmp accept &&
    nft add rule inet my_table my_input ip protocol igmp accept &&
    nft add rule inet my_table my_input meta l4proto udp ct state new jump my_udp_chain &&
    nft add rule inet my_table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump my_tcp_chain' &&
    nft add rule inet my_table my_input meta l4proto udp reject &&
    nft add rule inet my_table my_input meta l4proto tcp reject with tcp reset &&
    nft add rule inet my_table my_input counter reject with icmpx port-unreachable || exit 1

  mv /etc/nftables.conf /etc/nftables.conf.bak
  nft -s list ruleset > /etc/nftables.conf || exit 1

  echo "Firewall ruleset has been saved to /etc/nftables.conf"

  echo "Security configuration has been completed"
}

increase_watchers () {
  echo -e "\nIncreasing the limit of inotify watchers..."

  local LIMIT=524288
  echo "fs.inotify.max_user_watches=$LIMIT" >> /etc/sysctl.conf
  sysctl --system || exit 1

  echo "Inotify watchers limit has been set to $LIMIT"
}

install_bootloader () {
  echo -e "\nInstalling the bootloader via GRUB..."

  if [ "$UEFI" = "yes" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
  else
    grub-install --target=i386-pc "$DISK" || exit 1
  fi

  sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub
  sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub
  sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub

  grub-mkconfig -o /boot/grub/grub.cfg || exit 1

  if [ "$UEFI" = "yes" ] && [ "$VIRTUAL_VENDOR" = "oracle" ]; then
    mkdir -p /boot/EFI/BOOT
    cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
  fi

  echo "Bootloader has been installed"
}

enable_services () {
  echo -e "\nEnabling various system services..."

  systemctl enable systemd-timesyncd.service &&
  systemctl enable NetworkManager.service &&
  systemctl enable bluetooth.service &&
  systemctl enable acpid.service &&
  systemctl enable cups.service &&
  systemctl enable sshd.service &&
  systemctl enable nftables.service &&
  systemctl enable reflector.timer &&
  systemctl enable paccache.timer || exit 1

  if [ "$DISK_TRIM" = "yes" ]; then
    systemctl enable fstrim.timer || exit 1
  fi

  if [ "$VIRTUAL_VENDOR" = "oracle" ]; then
    systemctl enable vboxservice.service || exit 1
  fi

  echo "System services have been enabled"
}

copy_files () {
  echo "Start copying installation files..."

  cp -R /root/stack "/home/$USERNAME" || exit 1
  chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/stack"

  echo "Installation files have been moved to /home/$USERNAME"
}

echo -e "\nStarting the system setup process..."

if [[ "$(id -u)" != "0" ]]; then
  echo -e "\nError: process must be run as root user"
  echo "Process exiting with code 1..."
  exit 1
fi

source /root/stack/.options

set_host &&
  set_users &&
  set_keymap &&
  set_locale &&
  set_timezone &&
  set_mirrors &&
  boost_builds &&
  config_pacman &&
  sync_packages &&
  install_packages &&
  install_aur &&
  install_display_server &&
  install_drivers &&
  install_utilities &&
  config_security &&
  increase_watchers &&
  install_bootloader &&
  enable_services &&
  copy_files

echo -e "\nSetting up the system has been completed"
echo "Moving to the next process..."
sleep 5
