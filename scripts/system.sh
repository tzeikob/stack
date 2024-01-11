#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Sets host related settings.
set_host () {
  echo -e '\nSetting up host name...'

  local host_name=''
  host_name="$(get_setting 'host_name')" || exit 1

  echo "${host_name}" > /etc/hostname || exit 1

  echo "Host name has been set to ${host_name}"

  printf '%s\n' \
    '127.0.0.1    localhost' \
    '::1          localhost' \
    "127.0.1.1    ${host_name}" > /etc/hosts || exit 1

  echo 'Host name added to the hosts file'

  echo 'Host name has been set successfully'
}

# Sets up the root and sudoer users of the system.
set_users () {
  echo -e '\nSetting up system users...'

  local groups='wheel,audio,video,optical,storage'

  if is_setting 'vm' 'yes'; then
    groupadd 'libvirt'
    groups="${groups},libvirt"
  fi

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  useradd -m -G "${groups}" -s /bin/bash "${user_name}" || exit 1

  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}" &&
    chown -R ${user_name}:${user_name} "${config_home}" || exit 1

  local rule='%wheel ALL=(ALL:ALL) ALL'
  sed -i "s/^# \(${rule}\)/\1/" /etc/sudoers || exit 1

  if ! grep -q "^${rule}" /etc/sudoers; then
    echo 'Failed to grant sudo permissions to wheel user group'
    exit 1
  fi

  echo "Sudoer user ${user_name} has been created"

  local user_password=''
  user_password="$(get_setting 'user_password')" || exit 1

  echo "${user_name}:${user_password}" | chpasswd || exit 1

  echo "Password has been given to user ${user_name}"

  local root_password=''
  root_password="$(get_setting 'root_password')" || exit 1

  echo "root:${root_password}" | chpasswd || exit 1

  echo 'Password has been given to the root user'

  cp /etc/skel/.bash_profile /root || exit 1
  cp /etc/skel/.bashrc /root || exit 1

  echo 'System users have been set up'
}

# Sets the pacman package database mirrors.
set_mirrors () {
  echo -e '\nSetting up pacman package database mirrors...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || exit 1

  reflector --country "${mirrors}" --age 48 --sort age --latest 40 \
    --save /etc/pacman.d/mirrorlist

  if has_failed; then
    echo "Reflector failed to retrieve ${mirrors} mirrors"
    echo 'Falling back to default mirrors for now'
  fi

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sed -i "s/# --country.*/--country ${mirrors}/" "${conf_file}" &&
    sed -i 's/^--latest.*/--latest 40/' "${conf_file}" &&
    echo '--age 48' >> "${conf_file}" || exit 1

  echo "Pacman mirrors set to ${mirrors}"
}

# Configures pacman package manager.
configure_pacman () {
  echo -e '\nConfiguring the pacman package manager...'

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || exit 1

  echo 'Parallel downloading has been enabled'

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf || exit 1

  echo "GPG keyserver has been set to ${keyserver}"

  cp /opt/stack/configs/pacman/orphans.hook /usr/share/libalpm/hooks || exit 1

  echo 'Orphan packages post hook has been created'
  echo 'Pacman has been configured'
}

# Synchronizes the package databases to the master.
sync_package_databases () {
  echo -e '\nStarting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    echo 'Package databases seem to be locked'

    rm -f "${lock_file}" || exit 1

    echo "Lock file ${lock_file} has been removed"
  fi

  pacman -Syy || exit 1

  echo 'Packages database has been synchronized with master'
}

# Installs the base packages of the system.
install_base_packages () {
  echo -e '\nInstalling the base packages...'

  pacman -S --noconfirm \
    base-devel pacman-contrib pkgstats grub mtools dosfstools ntfs-3g exfatprogs gdisk fuseiso veracrypt \
    python-pip parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
    man-db man-pages texinfo cups cups-pdf cups-filters usbutils bluez bluez-utils unzip terminus-font \
    vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh hsetroot \
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils openbsd-netcat ipset xsel \
    neofetch age imagemagick gpick fuse2 rclone smartmontools glib2 jq jc sequoia-sq xf86-input-wacom \
    cairo bc xdotool || exit 1

  if is_setting 'uefi_mode' 'yes'; then
    pacman -S --noconfirm efibootmgr || exit 1
  fi

  echo -e '\nReplacing iptables with nft tables...'

  printf '%s\n' y y | pacman -S nftables iptables-nft || exit 1

  echo 'Base packages have been installed'
}

# Installs the Xorg display server packages.
install_display_server () {
  echo 'Installing the display server...'

  pacman -S --noconfirm xorg xorg-xinit xorg-xrandr xorg-xdpyinfo || exit 1

  cp /opt/stack/configs/xorg/xorg.conf /etc/X11 || exit 1

  echo 'Xorg configurations have been saved under /etc/X11'

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  cp /opt/stack/configs/xorg/xinitrc "/home/${user_name}/.xinitrc" &&
    chown ${user_name}:${user_name} "/home/${user_name}/.xinitrc" || exit 1

  echo "Xinitrc has been saved to /home/${user_name}/.xinitrc"

  local bash_profile_file="/home/${user_name}/.bash_profile"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${bash_profile_file}" || exit 1

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' \
    /usr/lib/systemd/system/getty@.service || exit 1

  echo 'Xorg session has been set to start after login'
  echo 'Display server has been installed'
}

# Installs hardware and system drivers.
install_drivers () {
  echo -e '\nInstalling system drivers...'

  local cpu_pckgs=''

  if is_setting 'cpu_vendor' 'amd'; then
    cpu_pckgs='amd-ucode'
  elif is_setting 'cpu_vendor' 'intel'; then
    cpu_pckgs='intel-ucode'
  fi

  local gpu_pckgs=''

  if is_setting 'gpu_vendor' 'nvidia'; then
    local kernels=''
    kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || exit 1

    if match "${kernels}" 'stable'; then
      gpu_pckgs='nvidia'
    fi

    if match "${kernels}" 'lts'; then
      gpu_pckgs+=' nvidia-lts'
    fi

    gpu_pckgs+=' nvidia-utils nvidia-settings'
  elif is_setting 'gpu_vendor' 'amd'; then
    gpu_pckgs='xf86-video-amdgpu'
  elif is_setting 'gpu_vendor' 'intel'; then
    gpu_pckgs='libva-intel-driver libvdpau-va-gl vulkan-intel libva-utils'
  else
    gpu_pckgs='xf86-video-qxl'
  fi

  local other_pckgs=''

  if is_setting 'synaptics' 'yes'; then
    other_pckgs='xf86-input-synaptics'
  fi

  local vm_pckgs=''

  if is_setting 'vm' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    vm_pckgs='virtualbox-guest-utils'
  fi

  pacman -S --noconfirm \
    acpi acpi_call acpid tlp xcalib \
    networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant \
    nmap dhclient smbclient libnma \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack \
    ${cpu_pckgs} ${gpu_pckgs} ${other_pckgs} ${vm_pckgs} || exit 1

  echo 'System drivers have been installed'
}

# Installs the user repository package manager.
install_aur_package_manager () {
  echo -e '\nInstalling the user repository package manager...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  cd "/home/${user_name}"
  git clone https://aur.archlinux.org/yay.git || exit 1
  chown -R ${user_name}:${user_name} yay || exit 1

  cd yay
  sudo -u "${user_name}" makepkg -si --noconfirm || exit 1

  cd ~
  rm -rf "/home/${user_name}/yay" || exit 1

  echo 'User repository package manager has been installed'
}

# Sets the system locale along with the locale environment variables.
set_locales () {
  local locales=''
  locales="$(get_setting 'locales')" || exit 1

  echo 'Generating system locales...'

  echo "${locales}" | jq -cer '.[]' >> /etc/locale.gen || exit 1

  locale-gen || exit 1

  echo 'System locales have been generated'

  # Set as system locale the locale selected first
  local locale=''
  locale="$(echo "${locales}" | jq -cer '.[0]' | cut -d ' ' -f 1)" || exit 1

  printf '%s\n' \
    "LANG=${locale}" \
    "LANGUAGE=${locale}:en:C" \
    "LC_CTYPE=${locale}" \
    "LC_NUMERIC=${locale}" \
    "LC_TIME=${locale}" \
    "LC_COLLATE=${locale}" \
    "LC_MONETARY=${locale}" \
    "LC_MESSAGES=${locale}" \
    "LC_PAPER=${locale}" \
    "LC_NAME=${locale}" \
    "LC_ADDRESS=${locale}" \
    "LC_TELEPHONE=${locale}" \
    "LC_MEASUREMENT=${locale}" \
    "LC_IDENTIFICATION=${locale}" \
    "LC_ALL=" | tee /etc/locale.conf > /dev/null || exit 1

  # Unset previous set variables
  unset LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE \
        LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS \
        LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL || exit 1
  
  # Save locale settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || exit 1

  local settings=''
  settings="$(echo "${locales}" | jq -e '{locale: .[0], locales: .}')" || exit 1

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" || exit 1
  fi

  echo "${settings}" > "${settings_file}" || exit 1

  chown -R ${user_name}:${user_name} "${config_home}" || exit 1

  echo "Locale has been set to ${locale}"
}

# Sets keyboard related settings.
set_keyboard () {
  echo -e '\nApplying keyboard settings...'

  local keyboard_map=''
  keyboard_map="$(get_setting 'keyboard_map')" || exit 1

  echo "KEYMAP=${keyboard_map}" > /etc/vconsole.conf || exit 1

  echo "Virtual console keymap set to ${keyboard_map}"

  loadkeys "${keyboard_map}" || exit 1

  echo 'Keyboard map keys has been loaded'

  local keyboard_model=''
  keyboard_model="$(get_setting 'keyboard_model')" || exit 1

  local keyboard_layouts=''
  keyboard_layouts="$(get_setting 'keyboard_layouts')" || exit 1

  local keyboard_options=''
  keyboard_options="$(get_setting 'keyboard_options')" || exit 1

  printf '%s\n' \
   'Section "InputClass"' \
   '  Identifier "system-keyboard"' \
   '  MatchIsKeyboard "on"' \
   "  Option \"XkbLayout\" \"$(echo ${keyboard_layouts} | jq -cr 'join(",")')\"" \
   "  Option \"XkbModel\" \"${keyboard_model}\"" \
   "  Option \"XkbOptions\" \"${keyboard_options}\"" \
   'EndSection' | tee /etc/X11/xorg.conf.d/00-keyboard.conf > /dev/null || exit 1

  echo 'Xorg keyboard settings have been added'

  # Save keyboard settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || exit 1

  local query=''
  query+="keymap: \"${keyboard_map}\","
  query+="model: \"${keyboard_model}\","
  query+="options: \"${keyboard_options}\","
  query+='layouts: [.[]|{code: ., variant: "default"}]'
  query="{${query}}"

  local settings=''
  settings="$(echo "${keyboard_layouts}" | jq -e "${query}")" || exit 1

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" || exit 1
  fi

  echo "${settings}" > "${settings_file}" || exit 1
  
  chown -R ${user_name}:${user_name} "${config_home}" || exit 1

  echo 'Keyboard settings have been applied'
}

# Sets the system timezone.
set_timezone () {
  echo -e '\nSetting the system timezone...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || exit 1

  ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime || exit 1

  local ntp_server='time.google.com'

  sed -i "s/^#NTP=/NTP=${ntp_server}/" /etc/systemd/timesyncd.conf || exit 1

  echo "NTP server has been set to ${ntp_server}"

  hwclock --systohc --utc || exit 1

  echo 'Hardware clock has been synchronized to system clock'

  echo -e "Timezone has been set to ${timezone}\n"
}

# Boost system's make and build performance.
boost_builds () {
  echo 'Boosting system build performance...'

  local cores=0
  cores=$(grep -c '^processor' /proc/cpuinfo) || exit 1

  if is_not_integer "${cores}" '[1,]'; then
    echo 'Unable to resolve CPU cores, boosting is skipped'
    return 0
  fi

  echo "Detected a CPU with a total of ${cores} logical cores"

  local conf_file='/etc/makepkg.conf'

  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${cores}\"/g" "${conf_file}" || exit 1

  echo "Make flags have been set to ${cores} CPU cores"

  sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=${cores} -)/g" "${conf_file}" &&
    sed -i "s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=${cores} -)/g" "${conf_file}" || exit 1

  echo 'Compression threads has been set'
  echo 'Boosting has been completed'
}

# Applies varius system power settings.
configure_power () {
  echo -e '\nConfiguring power settings...'
  
  local logind_conf='/etc/systemd/logind.conf.d/00-main.conf'
  
  mkdir -p /etc/systemd/logind.conf.d &&
    cp /etc/systemd/logind.conf "${logind_conf}" || exit 1

  echo 'HandleHibernateKey=ignore' >> "${logind_conf}" &&
    echo 'HandleHibernateKeyLongPress=ignore' >> "${logind_conf}" &&
    echo 'HibernateKeyIgnoreInhibited=no' >> "${logind_conf}" &&
    echo 'HandlePowerKey=suspend' >> "${logind_conf}" &&
    echo 'HandleRebootKey=reboot' >> "${logind_conf}" &&
    echo 'HandleSuspendKey=suspend' >> "${logind_conf}" &&
    echo 'HandleLidSwitch=suspend' >> "${logind_conf}" &&
    echo 'HandleLidSwitchDocked=ignore' >> "${logind_conf}" || exit 1

  local sleep_conf='/etc/systemd/sleep.conf.d/00-main.conf'

  mkdir -p /etc/systemd/sleep.conf.d &&
    cp /etc/systemd/sleep.conf "${sleep_conf}" || exit 1

  echo 'AllowSuspend=yes' >> "${sleep_conf}" &&
    echo 'AllowHibernation=no' >> "${sleep_conf}" &&
    echo 'AllowSuspendThenHibernate=no' >> "${sleep_conf}" &&
    echo 'AllowHybridSleep=no' >> "${sleep_conf}" || exit 1

  local tlp_conf='/etc/tlp.d/00-main.conf'

  echo 'SOUND_POWER_SAVE_ON_AC=0' >> "${tlp_conf}" &&
    echo 'SOUND_POWER_SAVE_ON_BAT=0' >> "${tlp_conf}" || exit 1

  rm -f /etc/tlp.d/00-template.conf || exit 1

  # Save screensaver settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || exit 1

  local settings='{"screensaver": {"interval": 15}}'

  local settings_file="${config_home}/power.json"

  echo "${settings}" > "${settings_file}" || exit 1

  chown -R ${user_name}:${user_name} "${config_home}" || exit 1

  echo 'Power configurations have been set'
}

# Applies various system security settings.
configure_security () {
  echo -e '\nHardening system security...'

  sed -i '/# Defaults maxseq = 1000/a Defaults badpass_message="Sorry incorrect password!"' /etc/sudoers &&
    sed -i '/# Defaults maxseq = 1000/a Defaults passwd_timeout=0' /etc/sudoers &&
    sed -i '/# Defaults maxseq = 1000/a Defaults passwd_tries=2' /etc/sudoers &&
    sed -i '/# Defaults maxseq = 1000/a Defaults passprompt="Enter current password: "' /etc/sudoers || exit 1

  echo 'Sudo configuration has been done'

  sed -ri 's;# dir =.*;dir = /var/lib/faillock;' /etc/security/faillock.conf &&
    sed -ri 's;# deny =.*;deny = 3;' /etc/security/faillock.conf &&
    sed -ri 's;# fail_interval =.*;fail_interval = 180;' /etc/security/faillock.conf &&
    sed -ri 's;# unlock_time =.*;unlock_time = 120;' /etc/security/faillock.conf || exit 1

  echo 'Faillocks set to be persistent after system reboot'

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config || exit 1

  echo 'SSH login permission disabled for the root user'

  echo 'Setting up a simple stateful firewall...'

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

  mv /etc/nftables.conf /etc/nftables.conf.bak &&
    nft -s list ruleset > /etc/nftables.conf || exit 1

  echo 'Firewall ruleset has been saved to /etc/nftables.conf'

  # Save screen locker settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || exit 1

  local settings='{"screen_locker": {"interval": 12}}'

  local settings_file="${config_home}/security.json"

  echo "${settings}" > "${settings_file}" || exit 1

  chown -R ${user_name}:${user_name} "${config_home}" || exit 1

  echo 'Security configuration has been completed'
}

# Increases the max limit of inotify watchers.
increase_watchers () {
  echo -e '\nIncreasing the limit of inotify watchers...'

  local limit=524288
  echo "fs.inotify.max_user_watches=${limit}" >> /etc/sysctl.conf || exit 1

  sysctl --system || exit 1

  echo "Inotify watchers limit has been set to ${limit}"
}

# Installs and configures the bootloader.
install_boot_loader () {
  echo -e '\nInstalling the boot loader...'

  if is_setting 'uefi_mode' 'yes'; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
  else
    local disk=''
    disk="$(get_setting 'disk')" || exit 1

    grub-install --target=i386-pc "${disk}" || exit 1
  fi

  sed -ri 's/(GRUB_CMDLINE_LINUX_DEFAULT=".*)"/\1 consoleblank=300"/' /etc/default/grub &&
    sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub &&
    sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub &&
    sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub || exit 1

  grub-mkconfig -o /boot/grub/grub.cfg || exit 1

  if is_setting 'uefi_mode' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    mkdir -p /boot/EFI/BOOT &&
      cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI || exit 1
  fi

  echo 'Boot loader has been installed'
}

# Enables system services.
enable_services () {
  echo -e '\nEnabling system services...'

  systemctl enable systemd-timesyncd.service &&
    systemctl enable NetworkManager.service &&
    systemctl enable bluetooth.service &&
    systemctl enable acpid.service &&
    systemctl enable cups.service &&
    systemctl enable sshd.service &&
    systemctl enable nftables.service &&
    systemctl enable reflector.timer &&
    systemctl enable paccache.timer || exit 1

  if is_setting 'trim_disk' 'yes'; then
    systemctl enable fstrim.timer || exit 1
  fi

  if is_setting 'vm' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    systemctl enable vboxservice.service || exit 1
  fi
  
  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1
  
  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}/systemd/user" &&
    cp /opt/stack/services/init-pointer.service "${config_home}/systemd/user" &&
    cp /opt/stack/services/init-tablets.service "${config_home}/systemd/user" &&
    cp /opt/stack/services/fix-layout.service "${config_home}/systemd/user" || exit 1

  chown -R ${user_name}:${user_name} "${config_home}/systemd" || exit 1
  
  sed -i "s/#USER/${user_name}/g" "${config_home}/systemd/user/fix-layout.service" || exit 1

  echo 'System services have been enabled'
}

# Adds system rules for udev.
add_rules () {
  echo -e '\nAdding system udev rules...'

  local rules_home='/etc/udev/rules.d'

  cp /opt/stack/rules/90-init-pointer.rules "${rules_home}" &&
    cp /opt/stack/rules/91-init-tablets.rules "${rules_home}" &&
    cp /opt/stack/rules/92-fix-layout.rules "${rules_home}" || exit 1

  echo 'System udev rules have been added'
}

echo -e '\nStarting the system installation process...'

if not_equals "$(id -u)" 0; then
  echo -e '\nProcess must be run as root user'
  exit 1
fi

set_host &&
  set_users &&
  set_mirrors &&
  configure_pacman &&
  sync_package_databases &&
  install_base_packages &&
  install_display_server &&
  install_drivers &&
  install_aur_package_manager &&
  set_locales &&
  set_keyboard &&
  set_timezone &&
  boost_builds &&
  configure_power &&
  configure_security &&
  increase_watchers &&
  install_boot_loader &&
  enable_services &&
  add_rules

echo -e '\nSystem installation has been completed'
echo 'Moving to the desktop installation process...'
sleep 5

