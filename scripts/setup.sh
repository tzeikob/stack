#!/usr/bin/env bash

enable_nopasswd () {
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

  echo "No password mode has temporarily been enabled"
}

disable_nopasswd () {
  sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

  echo "No password mode has been disabled"
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
  sed -i "s/#\(${LOCALE}.*\)/\1/" /etc/locale.gen
  locale-gen

  local PARTS=($LOCALE)
  echo "LANG=${PARTS[0]}" >> /etc/locale.conf

  echo "Locale has been set to $LOCALE"
}

sync_clock () {
  echo "Synchronize hardware clock..."

  hwclock --systohc

  echo "Hardware clock has been synchronized"
}

set_hostname () {
  echo $HOSTNAME >> /etc/hostname

  printf '%s\n' \
    '127.0.0.1    localhost' \
    '::1          localhost' \
    "127.0.1.1    $HOSTNAME" > /etc/hosts

  echo "Hostname has been set to $HOSTNAME"
}

create_sudoer () {
  useradd -m -G wheel,audio,video,optical,storage $USERNAME
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  echo "Sudoer user $USERNAME has been created"
}

set_passwds () {
  echo "root:$ROOT_PASSWORD" | chpasswd

  echo "User root has been given a password"

  echo "$USERNAME:$USER_PASSWORD" | chpasswd

  echo "User $USERNAME has been given a password"
}

set_mirrors () {
  echo -e "\nSetting up pacman and mirrors list..."

  local OLD_IFS=$IFS && IFS=","
  MIRRORS="${MIRRORS[*]}" && IFS=$OLD_IFS

  reflector --country "$MIRRORS" --age 8 --sort age --save /etc/pacman.d/mirrorlist
  sed -i "s/# --country.*/--country ${MIRRORS}/" /etc/xdg/reflector/reflector.conf

  echo "Mirror list set to $MIRRORS"
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
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils openbsd-netcat ipset \
    $([ "$IS_UEFI" = "yes" ] && echo 'efibootmgr')

  yes | pacman -S --needed nftables iptables-nft

  echo "Base packages have been installed"
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
  if [ "$IS_VM" = "yes" ]; then
    if [ "$IS_VM_VBOX" = "yes" ]; then
      VM_PKGS="$VM_PKGS virtualbox-guest-utils"
    fi
  fi

  pacman -S --noconfirm --needed \
    acpi acpid acpi_call \
    networkmanager wireless_tools netctl wpa_supplicant \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack pavucontrol \
    xorg xorg-xinit xorg-xrandr arandr \
    $CPU_PKGS $GPU_PKGS $VM_PKGS

  echo "Drivers have been installed"
}

install_yay () {
  echo -e "\nInstalling the yay package manager..."

  cd /home/$USERNAME
  git clone https://aur.archlinux.org/yay.git

  chown -R $USERNAME:$USERNAME yay && cd yay
  sudo -u $USERNAME makepkg -si --noconfirm --needed --noprogressbar

  cd /root && rm -rf /home/$USERNAME/yay

  echo "Yay package manager has been installed"
}

set_layouts () {
  echo -e "\nSetting the keyboard layouts..."

  local OLD_IFS=$IFS && IFS=","
  LAYOUTS="${LAYOUTS[*]}" && IFS=$OLD_IFS

  printf '%s\n' \
    'Section "InputClass"' \
    '  Identifier "system-keyboard"' \
    '  MatchIsKeyboard "on"' \
    '  Option "XkbLayout" "'${LAYOUTS}'"' \
    '  Option "XkbModel" "pc105"' \
    '  Option "XkbOptions" "grp:alt_shift_toggle"' \
    'EndSection' > /etc/X11/xorg.conf.d/00-keyboard.conf

  echo "Keyboard layouts have been set to $LAYOUTS"
}

install_fonts () {
  echo -e "\nInstalling extra fonts..."

  local FONTS_HOME="/usr/share/fonts/extra-fonts"
  mkdir -p $FONTS_HOME

  local FONTS=(
    "FiraCode https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
    "FantasqueSansMono https://github.com/belluzj/fantasque-sans/releases/download/v1.8.0/FantasqueSansMono-Normal.zip"
    "Hack https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.zip"
    "Hasklig https://github.com/i-tu/Hasklig/releases/download/v1.2/Hasklig-1.2.zip"
    "JetBrainsMono https://github.com/JetBrains/JetBrainsMono/releases/download/v2.242/JetBrainsMono-2.242.zip"
    "Mononoki https://github.com/madmalik/mononoki/releases/download/1.3/mononoki.zip"
    "VictorMono https://rubjo.github.io/victor-mono/VictorMonoAll.zip"
    "Cousine https://fonts.google.com/download?family=Cousine"
    "RobotoMono https://fonts.google.com/download?family=Roboto%20Mono"
    "ShareTechMono https://fonts.google.com/download?family=Share%20Tech%20Mono"
    "SpaceMono https://fonts.google.com/download?family=Space%20Mono"
  )

  for FONT in "${FONTS[@]}"; do
    local NAME=$(echo $FONT | cut -d " " -f 1)
    local URL=$(echo $FONT | cut -d " " -f 2)

    curl $URL -sSLo $FONTS_HOME/$NAME.zip \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
    unzip -q $FONTS_HOME/$NAME.zip -d $FONTS_HOME/$NAME

    find $FONTS_HOME/$NAME/ -depth -mindepth 1 -iname "*windows*" -exec rm -r {} +
    find $FONTS_HOME/$NAME/ -depth -mindepth 1 -iname "*macosx*" -exec rm -r {} +
    find $FONTS_HOME/$NAME/ -depth -type f -not -iname "*ttf*" -delete
    find $FONTS_HOME/$NAME/ -empty -type d -delete
    rm -f $FONTS_HOME/$NAME.zip

    echo "Font $NAME has been installed"
  done

  fc-cache -f

  echo "Fonts have been installed under $FONTS_HOME"

  echo -e "\nInstalling some extra font glyphs..."

  pacman -S --noconfirm --needed \
    ttf-font-awesome noto-fonts-emoji

  echo "Extra font glyphs have been installed"
}

config_pacman () {
  echo -e "\nConfiguring the pacman package manager..."

  printf '%s\n' \
    '[Trigger]' \
    'Type = Package' \
    'Operation = Install' \
    'Operation = Upgrade' \
    'Operation = Remove' \
    'Target = *' \
    '[Action]' \
    'Description = Search for any left over orphan packages' \
    'When = PostTransaction' \
    'Exec = /usr/bin/bash -c "/usr/bin/pacman -Qtd || /usr/bin/echo "No orphan packages found"' \
    > /usr/share/libalpm/hooks/orphan-packages.hook

  echo "Orphan packages post installation hook has been set"
  echo "Pacman has been configured"
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

  printf '%s\n' \
  '# Prevents overpassing screen locker by killing xorg or switching vt' \
  'Section "ServerFlags"'
  '  Option "DontVTSwitch" "True"'
  '  Option "DontZap" "True"'
  'EndSection' > /etc/X11/xorg.conf.d/01-screenlock.conf

  echo "Security configuration has been completed"
}

setup_swap () {
  echo -e "\nSetting up the swap..."

  echo "Creating the swapfile..."

  dd if=/dev/zero of=/swapfile bs=1M count=$(expr $SWAP_SIZE \* 1024) status=progress
  chmod 0600 /swapfile
  mkswap -U clear /swapfile

  echo "Enabling swap..."

  swapon /swapfile && free -m

  cp /etc/fstab /etc/fstab.bak
  echo "/swapfile none swap defaults 0 0" | tee -a /etc/fstab

  echo "Swap file has been set successfully to /swapfile"
}

install_bootloader () {
  echo -e "\nInstalling the bootloader via GRUB..."

  if [ "$IS_UEFI" = "yes" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  else
    grub-install --target=i386-pc $DISK
  fi

  sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub
  sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub
  sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub

  grub-mkconfig -o /boot/grub/grub.cfg

  if [ "$IS_UEFI" = "yes" && "$IS_VM_VBOX" = "yes" ]; then
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

  if [ "$IS_VM_VBOX" = "yes" ]; then
    systemctl enable vboxservice
  fi

  echo "System services have been enabled"
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
  set_passwds &&
  set_mirrors &&
  boost_download &&
  sync_packages &&
  install_packages &&
  install_drivers &&
  install_yay &&
  set_layouts &&
  install_fonts &&
  config_pacman &&
  config_security &&
  [ "$SWAP" = "yes" ] && setup_swap &&
  install_bootloader &&
  enable_services &&
  disable_nopasswd

echo -e "\nSetting up the system has been completed"
echo "Moving to the next process..."
sleep 5
