#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Sets host related settings.
set_host () {
  log '\nSetting up host name...'

  local host_name=''
  host_name="$(get_setting 'host_name')" || fail

  echo "${host_name}" > /etc/hostname || fail

  log "Host name has been set to ${host_name}"

  printf '%s\n' \
    '127.0.0.1    localhost' \
    '::1          localhost' \
    "127.0.1.1    ${host_name}" > /etc/hosts || fail

  log 'Host name added to the hosts file'

  log 'Host name has been set successfully'
}

# Sets up the root and sudoer users of the system.
set_users () {
  log '\nSetting up system users...'

  local groups='wheel,audio,video,optical,storage'

  if is_setting 'vm' 'yes'; then
    groupadd 'libvirt'
    groups="${groups},libvirt"
  fi

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  OUTPUT="$(
    useradd -m -G "${groups}" -s /bin/bash "${user_name}" 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}" &&
    chown -R ${user_name}:${user_name} "${config_home}" || fail

  local rule='%wheel ALL=(ALL:ALL) ALL'
  sed -i "s/^# \(${rule}\)/\1/" /etc/sudoers || fail

  if ! grep -q "^${rule}" /etc/sudoers; then
    fail 'Failed to grant sudo permissions to wheel user group'
  fi

  log "Sudoer user ${user_name} has been created"

  local user_password=''
  user_password="$(get_setting 'user_password')" || fail

  echo "${user_name}:${user_password}" | chpasswd || fail

  log "Password has been given to user ${user_name}"

  local root_password=''
  root_password="$(get_setting 'root_password')" || fail

  echo "root:${root_password}" | chpasswd || fail

  log 'Password has been given to the root user'

  cp /etc/skel/.bash_profile /root || fail
  cp /etc/skel/.bashrc /root || fail

  log 'System users have been set up'
}

# Sets the pacman package database mirrors.
set_mirrors () {
  log '\nSetting up pacman package database mirrors...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || fail

  OUTPUT="$(
    reflector --country "${mirrors}" --age 48 --sort age --latest 40 \
      --save /etc/pacman.d/mirrorlist 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sed -i "s/# --country.*/--country ${mirrors}/" "${conf_file}" &&
    sed -i 's/^--latest.*/--latest 40/' "${conf_file}" &&
    echo '--age 48' >> "${conf_file}" || fail

  log "Pacman database mirrors set to ${mirrors}"
}

# Configures pacman package manager.
configure_pacman () {
  log '\nConfiguring the pacman package manager...'

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || fail

  log 'Parallel downloading has been enabled'

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf || fail

  log "GPG keyserver has been set to ${keyserver}"

  cp /opt/stack/configs/pacman/orphans.hook /usr/share/libalpm/hooks || fail

  log 'Orphan packages post hook has been created'
  log 'Pacman has been configured'
}

# Synchronizes the package databases to the master.
sync_package_databases () {
  log '\nStarting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log 'Package databases seem to be locked'

    rm -f "${lock_file}" || fail

    log "Lock file ${lock_file} has been removed"
  fi

  OUTPUT="$(
    pacman -Syy 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Packages database has been synchronized with master'
}

# Installs the base packages of the system.
install_base_packages () {
  log '\nInstalling the base packages...'

  local extra_pckgs=''
  if is_setting 'uefi_mode' 'yes'; then
    extra_pckgs='efibootmgr'
  fi

  OUTPUT="$(
    pacman -S --noconfirm \
      base-devel pacman-contrib pkgstats grub mtools dosfstools ntfs-3g exfatprogs gdisk fuseiso veracrypt \
      python-pip parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
      man-db man-pages texinfo cups cups-pdf cups-filters usbutils bluez bluez-utils unzip terminus-font \
      vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh hsetroot \
      bzip2 unrar dialog inetutils dnsutils openssh nfs-utils openbsd-netcat ipset xsel \
      neofetch age imagemagick gpick fuse2 rclone smartmontools glib2 jq jc sequoia-sq xf86-input-wacom \
      cairo bc xdotool ${extra_pckgs} 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log '\nReplacing iptables with nft tables...'

  OUTPUT="$(
    printf '%s\n' y y | pacman -S nftables iptables-nft 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Base packages have been installed'
}

# Installs the Xorg display server packages.
install_display_server () {
  log 'Installing the display server...'

  OUTPUT="$(
    pacman -S --noconfirm xorg xorg-xinit xorg-xrandr xorg-xdpyinfo 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  cp /opt/stack/configs/xorg/xorg.conf /etc/X11 || fail

  log 'Xorg configurations have been saved under /etc/X11'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  cp /opt/stack/configs/xorg/xinitrc "/home/${user_name}/.xinitrc" &&
    chown ${user_name}:${user_name} "/home/${user_name}/.xinitrc" || fail

  log "Xinitrc has been saved to /home/${user_name}/.xinitrc"

  local bash_profile_file="/home/${user_name}/.bash_profile"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${bash_profile_file}" || fail

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' \
    /usr/lib/systemd/system/getty@.service || fail

  log 'Xorg session has been set to start after login'
  log 'Display server has been installed'
}

# Installs hardware and system drivers.
install_drivers () {
  log '\nInstalling system drivers...'

  local cpu_pckgs=''

  if is_setting 'cpu_vendor' 'amd'; then
    cpu_pckgs='amd-ucode'
  elif is_setting 'cpu_vendor' 'intel'; then
    cpu_pckgs='intel-ucode'
  fi

  local gpu_pckgs=''

  if is_setting 'gpu_vendor' 'nvidia'; then
    local kernels=''
    kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || fail

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

  OUTPUT="$(
    pacman -S --noconfirm \
      acpi acpi_call acpid tlp xcalib \
      networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant \
      nmap dhclient smbclient libnma \
      alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack \
      ${cpu_pckgs} ${gpu_pckgs} ${other_pckgs} ${vm_pckgs} 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'System drivers have been installed'
}

# Installs the user repository package manager.
install_aur_package_manager () {
  log '\nInstalling the user repository package manager...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  OUTPUT="$(
    cd "/home/${user_name}" &&
      git clone https://aur.archlinux.org/yay.git 2>&1 &&
      chown -R ${user_name}:${user_name} yay &&
      cd yay &&
      sudo -u "${user_name}" makepkg -si --noconfirm 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  cd ~
  rm -rf "/home/${user_name}/yay" || fail

  log 'User repository package manager has been installed'
}

# Sets the system locale along with the locale environment variables.
set_locales () {
  local locales=''
  locales="$(get_setting 'locales')" || fail

  log 'Generating system locales...'

  echo "${locales}" | jq -cer '.[]' >> /etc/locale.gen || fail

  OUTPUT="$(
    locale-gen 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'System locales have been generated'

  # Set as system locale the locale selected first
  local locale=''
  locale="$(echo "${locales}" | jq -cer '.[0]' | cut -d ' ' -f 1)" || fail

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
    "LC_ALL=" | tee /etc/locale.conf > /dev/null || fail

  # Unset previous set variables
  unset LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE \
        LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS \
        LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL || fail
  
  # Save locale settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings=''
  settings="$(echo "${locales}" | jq -e '{locale: .[0], locales: .}')" || fail

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" || fail
  fi

  echo "${settings}" > "${settings_file}" || fail

  chown -R ${user_name}:${user_name} "${config_home}" || fail

  log "Locale has been set to ${locale}"
}

# Sets keyboard related settings.
set_keyboard () {
  log '\nApplying keyboard settings...'

  local keyboard_map=''
  keyboard_map="$(get_setting 'keyboard_map')" || fail

  echo "KEYMAP=${keyboard_map}" > /etc/vconsole.conf || fail

  log "Virtual console keymap set to ${keyboard_map}"

  OUTPUT="$(
    loadkeys "${keyboard_map}" 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Keyboard map keys has been loaded'

  local keyboard_model=''
  keyboard_model="$(get_setting 'keyboard_model')" || fail

  local keyboard_layouts=''
  keyboard_layouts="$(get_setting 'keyboard_layouts')" || fail

  local keyboard_options=''
  keyboard_options="$(get_setting 'keyboard_options')" || fail

  printf '%s\n' \
   'Section "InputClass"' \
   '  Identifier "system-keyboard"' \
   '  MatchIsKeyboard "on"' \
   "  Option \"XkbLayout\" \"$(echo ${keyboard_layouts} | jq -cr 'join(",")')\"" \
   "  Option \"XkbModel\" \"${keyboard_model}\"" \
   "  Option \"XkbOptions\" \"${keyboard_options}\"" \
   'EndSection' | tee /etc/X11/xorg.conf.d/00-keyboard.conf > /dev/null || fail

  log 'Xorg keyboard settings have been added'

  # Save keyboard settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local query=''
  query+="keymap: \"${keyboard_map}\","
  query+="model: \"${keyboard_model}\","
  query+="options: \"${keyboard_options}\","
  query+='layouts: [.[]|{code: ., variant: "default"}]'
  query="{${query}}"

  local settings=''
  settings="$(echo "${keyboard_layouts}" | jq -e "${query}")" || fail

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" || fail
  fi

  echo "${settings}" > "${settings_file}" || fail
  
  chown -R ${user_name}:${user_name} "${config_home}" || fail

  log 'Keyboard settings have been applied'
}

# Sets the system timezone.
set_timezone () {
  log '\nSetting the system timezone...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || fail

  ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime || fail

  local ntp_server='time.google.com'

  sed -i "s/^#NTP=/NTP=${ntp_server}/" /etc/systemd/timesyncd.conf || fail

  log "NTP server has been set to ${ntp_server}"

  OUTPUT="$(
    hwclock --systohc --utc 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Hardware clock has been synchronized to system clock'

  log "Timezone has been set to ${timezone}\n"
}

# Boost system's make and build performance.
boost_builds () {
  log 'Boosting system build performance...'

  OUTPUT="$(
    grep -c '^processor' /proc/cpuinfo 2>&1
  )" || fail

  local cores="${OUTPUT}"

  if is_not_integer "${cores}" '[1,]'; then
    log 'Unable to resolve CPU cores, boosting is skipped'
    return 0
  fi

  log "Detected a CPU with a total of ${cores} logical cores"

  local conf_file='/etc/makepkg.conf'

  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${cores}\"/g" "${conf_file}" || fail

  log "Make flags have been set to ${cores} CPU cores"

  sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=${cores} -)/g" "${conf_file}" || fail
  sed -i "s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=${cores} -)/g" "${conf_file}" || fail

  log 'Compression threads has been set'
  log 'Boosting has been completed'
}

# Applies varius system power settings.
configure_power () {
  log '\nConfiguring power settings...'
  
  local logind_conf='/etc/systemd/logind.conf.d/00-main.conf'
  
  mkdir -p /etc/systemd/logind.conf.d &&
    cp /etc/systemd/logind.conf "${logind_conf}" || fail

  echo 'HandleHibernateKey=ignore' >> "${logind_conf}" &&
    echo 'HandleHibernateKeyLongPress=ignore' >> "${logind_conf}" &&
    echo 'HibernateKeyIgnoreInhibited=no' >> "${logind_conf}" &&
    echo 'HandlePowerKey=suspend' >> "${logind_conf}" &&
    echo 'HandleRebootKey=reboot' >> "${logind_conf}" &&
    echo 'HandleSuspendKey=suspend' >> "${logind_conf}" &&
    echo 'HandleLidSwitch=suspend' >> "${logind_conf}" &&
    echo 'HandleLidSwitchDocked=ignore' >> "${logind_conf}" || fail

  local sleep_conf='/etc/systemd/sleep.conf.d/00-main.conf'

  mkdir -p /etc/systemd/sleep.conf.d &&
    cp /etc/systemd/sleep.conf "${sleep_conf}" || fail

  echo 'AllowSuspend=yes' >> "${sleep_conf}" &&
    echo 'AllowHibernation=no' >> "${sleep_conf}" &&
    echo 'AllowSuspendThenHibernate=no' >> "${sleep_conf}" &&
    echo 'AllowHybridSleep=no' >> "${sleep_conf}" || fail

  local tlp_conf='/etc/tlp.d/00-main.conf'

  echo 'SOUND_POWER_SAVE_ON_AC=0' >> "${tlp_conf}" &&
    echo 'SOUND_POWER_SAVE_ON_BAT=0' >> "${tlp_conf}" || fail

  rm -f /etc/tlp.d/00-template.conf || fail

  # Save screensaver settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings='{"screensaver": {"interval": 15}}'

  local settings_file="${config_home}/power.json"

  echo "${settings}" > "${settings_file}" || fail

  chown -R ${user_name}:${user_name} "${config_home}" || fail

  log 'Power configurations have been set'
}

# Applies various system security settings.
configure_security () {
  log '\nHardening system security...'

  sed -i '/# Defaults maxseq = 1000/a Defaults badpass_message="Sorry incorrect password!"' /etc/sudoers &&
    sed -i '/# Defaults maxseq = 1000/a Defaults passwd_timeout=0' /etc/sudoers &&
    sed -i '/# Defaults maxseq = 1000/a Defaults passwd_tries=2' /etc/sudoers &&
    sed -i '/# Defaults maxseq = 1000/a Defaults passprompt="Enter current password: "' /etc/sudoers || fail

  log 'Sudo configuration has been done'

  sed -ri 's;# dir =.*;dir = /var/lib/faillock;' /etc/security/faillock.conf &&
    sed -ri 's;# deny =.*;deny = 3;' /etc/security/faillock.conf &&
    sed -ri 's;# fail_interval =.*;fail_interval = 180;' /etc/security/faillock.conf &&
    sed -ri 's;# unlock_time =.*;unlock_time = 120;' /etc/security/faillock.conf || fail

  log 'Faillocks set to be persistent after system reboot'

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config || fail

  log 'SSH login permission disabled for the root user'

  log 'Setting up a simple stateful firewall...'

  OUTPUT="$(
    nft flush ruleset 2>&1 &&
      nft add table inet my_table 2>&1 &&
      nft add chain inet my_table my_input '{ type filter hook input priority 0 ; policy drop ; }' 2>&1 &&
      nft add chain inet my_table my_forward '{ type filter hook forward priority 0 ; policy drop ; }' 2>&1 &&
      nft add chain inet my_table my_output '{ type filter hook output priority 0 ; policy accept ; }' 2>&1 &&
      nft add chain inet my_table my_tcp_chain 2>&1 &&
      nft add chain inet my_table my_udp_chain 2>&1 &&
      nft add rule inet my_table my_input ct state related,established accept 2>&1 &&
      nft add rule inet my_table my_input iif lo accept 2>&1 &&
      nft add rule inet my_table my_input ct state invalid drop 2>&1 &&
      nft add rule inet my_table my_input meta l4proto ipv6-icmp accept 2>&1 &&
      nft add rule inet my_table my_input meta l4proto icmp accept 2>&1 &&
      nft add rule inet my_table my_input ip protocol igmp accept 2>&1 &&
      nft add rule inet my_table my_input meta l4proto udp ct state new jump my_udp_chain 2>&1 &&
      nft add rule inet my_table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump my_tcp_chain' 2>&1 &&
      nft add rule inet my_table my_input meta l4proto udp reject 2>&1 &&
      nft add rule inet my_table my_input meta l4proto tcp reject with tcp reset 2>&1 &&
      nft add rule inet my_table my_input counter reject with icmpx port-unreachable 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  mv /etc/nftables.conf /etc/nftables.conf.bak &&
    nft -s list ruleset > /etc/nftables.conf || fail

  log 'Firewall ruleset has been saved to /etc/nftables.conf'

  # Save screen locker settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings='{"screen_locker": {"interval": 12}}'

  local settings_file="${config_home}/security.json"

  echo "${settings}" > "${settings_file}" || fail

  chown -R ${user_name}:${user_name} "${config_home}" || fail

  log 'Security configuration has been completed'
}

# Increases the max limit of inotify watchers.
increase_watchers () {
  log '\nIncreasing the limit of inotify watchers...'

  local limit=524288
  echo "fs.inotify.max_user_watches=${limit}" >> /etc/sysctl.conf || fail

  OUTPUT="$(
    sysctl --system 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log "Inotify watchers limit has been set to ${limit}"
}

# Installs and configures the bootloader.
install_boot_loader () {
  log '\nSetting up the boot loader...'

  if is_setting 'uefi_mode' 'yes'; then
    OUTPUT="$(
      grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1
    )" || fail
  else
    local disk=''
    disk="$(get_setting 'disk')" || fail

    OUTPUT="$(
      grub-install --target=i386-pc "${disk}" 2>&1
    )" || fail
  fi

  log -t file "${OUTPUT}"

  log 'Boot loader has been installed'

  log 'Configuring the boot loader...'

  sed -ri 's/(GRUB_CMDLINE_LINUX_DEFAULT=".*)"/\1 consoleblank=300"/' /etc/default/grub &&
    sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub &&
    sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub &&
    sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub || fail

  OUTPUT="$(
    grub-mkconfig -o /boot/grub/grub.cfg 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Boot loader has been configured'

  if is_setting 'uefi_mode' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    mkdir -p /boot/EFI/BOOT &&
      cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI || fail
  fi

  log 'Boot loader has been set up'
}

# Enables system services.
enable_services () {
  log '\nEnabling system services...'

  OUTPUT="$(
    systemctl enable systemd-timesyncd.service 2>&1 &&
      systemctl enable NetworkManager.service 2>&1 &&
      systemctl enable bluetooth.service 2>&1 &&
      systemctl enable acpid.service 2>&1 &&
      systemctl enable cups.service 2>&1 &&
      systemctl enable sshd.service 2>&1 &&
      systemctl enable nftables.service 2>&1 &&
      systemctl enable reflector.timer 2>&1 &&
      systemctl enable paccache.timer 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  if is_setting 'trim_disk' 'yes'; then
    OUTPUT="$(
      systemctl enable fstrim.timer 2>&1
    )" || fail

    log -t file "${OUTPUT}"
  fi

  if is_setting 'vm' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    OUTPUT="$(
      systemctl enable vboxservice.service 2>&1
    )" || fail

    log -t file "${OUTPUT}"
  fi
  
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail
  
  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}/systemd/user" &&
    cp /opt/stack/services/init-pointer.service "${config_home}/systemd/user" &&
    cp /opt/stack/services/init-tablets.service "${config_home}/systemd/user" &&
    cp /opt/stack/services/fix-layout.service "${config_home}/systemd/user" || fail

  chown -R ${user_name}:${user_name} "${config_home}/systemd" || fail
  
  sed -i "s/#USER/${user_name}/g" "${config_home}/systemd/user/fix-layout.service" || fail

  log 'System services have been enabled'
}

# Adds system rules for udev.
add_rules () {
  log '\nAdding system udev rules...'

  local rules_home='/etc/udev/rules.d'

  cp /opt/stack/rules/90-init-pointer.rules "${rules_home}" &&
    cp /opt/stack/rules/91-init-tablets.rules "${rules_home}" &&
    cp /opt/stack/rules/92-fix-layout.rules "${rules_home}" || fail

  log 'System udev rules have been added'
}

log '\nStarting the system installation process...'

if not_equals "$(id -u)" 0; then
  fail 'Script system.sh must be run as root user'
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

sleep 3
