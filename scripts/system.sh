#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Sets host related settings.
set_host () {
  log 'Setting up the host...'

  local host_name=''
  host_name="$(get_setting 'host_name')" || fail

  echo "${host_name}" > /etc/hostname ||
    fail 'Failed to set the host name'

  log "Host name has been set to ${host_name}"

  printf '%s\n' \
    '127.0.0.1    localhost' \
    '::1          localhost' \
    "127.0.1.1    ${host_name}" > /etc/hosts ||
    fail 'Failed to add host name to hosts'

  log 'Host name has been added to the hosts'
  log 'Host has been set successfully'
}

# Sets up the root and sudoer users of the system.
set_users () {
  log 'Setting up the system users...'

  local groups='wheel,audio,video,optical,storage'

  if is_setting 'vm' 'yes'; then
    groupadd 'libvirt' 2>&1
    groups="${groups},libvirt"
  fi

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  useradd -m -G "${groups}" -s /bin/bash "${user_name}" 2>&1 ||
    fail 'Failed to create the sudoer user'

  log "Sudoer user ${user_name} has been created"

  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    fail 'Failed to create the user config folder'

  log 'User config folder created under ~/.config'

  local rule='%wheel ALL=(ALL:ALL) ALL'

  sed -i "s/^# \(${rule}\)/\1/" /etc/sudoers ||
    fail 'Failed to grant sudo permissions to wheel group'

  if ! grep -q "^${rule}" /etc/sudoers; then
    fail 'Failed to grant sudo permissions to wheel group'
  fi

  log 'Sudo permissions have been granted to sudoer user'

  local user_password=''
  user_password="$(get_setting 'user_password')" || fail

  echo "${user_name}:${user_password}" | chpasswd 2>&1 ||
    fail "Failed to set password to user ${user_name}"

  log "Password has been given to user ${user_name}"

  local root_password=''
  root_password="$(get_setting 'root_password')" || fail

  echo "root:${root_password}" | chpasswd 2>&1 ||
    fail 'Failed to set password to root user'

  log 'Password has been given to the root user'

  cp /etc/skel/.bash_profile /root ||
    fail 'Failed to create root .bash_profile file'

  cp /etc/skel/.bashrc /root ||
    fail 'Failed to create root .bashrc file'

  log 'System users have been set up'
}

# Sets the pacman package database mirrors.
set_mirrors () {
  log 'Setting up the package databases mirrors...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || fail

  reflector --country "${mirrors}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1 ||
    fail 'Unable to fetch package databases mirrors'

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sed -i "s/# --country.*/--country ${mirrors}/" "${conf_file}" &&
    sed -i 's/^--latest.*/--latest 40/' "${conf_file}" &&
    echo '--age 48' >> "${conf_file}" ||
    fail 'Failed to save mirrors settings to reflector'

  log "Package databases mirrors set to ${mirrors}"
}

# Configures pacman package manager.
configure_pacman () {
  log 'Configuring the pacman manager...'

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ||
    fail 'Failed to set parallel download'

  log 'Parallel download has been enabled'

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
    fail 'Failed to add the GPG keyserver'

  log "GPG keyserver has been set to ${keyserver}"

  cp /opt/stack/configs/pacman/orphans.hook /usr/share/libalpm/hooks ||
    fail 'Failed to add the orphans packages hook'

  log 'Orphan packages post hook has been created'
  log 'Pacman manager has been configured'
}

# Synchronizes the package databases to the master.
sync_package_databases () {
  log 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log WARN 'Package databases seem to be locked'

    rm -f "${lock_file}" ||
      fail "Failed to remove the lock file ${lock_file}"

    log "Lock file ${lock_file} has been removed"
  fi

  pacman -Syy 2>&1 ||
    fail 'Failed to synchronize package databases'

  log 'Package databases synchronized to the master'
}

# Installs the base packages of the system.
install_base_packages () {
  log 'Installing the base packages...'

  local extra_pckgs=''
  if is_setting 'uefi_mode' 'yes'; then
    extra_pckgs='efibootmgr'
  fi

  pacman -S --needed --noconfirm \
    base-devel pacman-contrib pkgstats grub mtools dosfstools ntfs-3g exfatprogs gdisk fuseiso veracrypt \
    python-pip parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
    man-db man-pages texinfo cups cups-pdf cups-filters usbutils bluez bluez-utils unzip terminus-font \
    vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh hsetroot \
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils openbsd-netcat ipset xsel \
    neofetch age imagemagick gpick fuse2 rclone smartmontools glib2 jq jc sequoia-sq xf86-input-wacom \
    cairo bc xdotool ${extra_pckgs} 2>&1 ||
    fail 'Failed to install base packages'

  log 'Replacing iptables with nft tables...'

  printf '%s\n' y y | pacman -S --needed nftables iptables-nft 2>&1 ||
    fail 'Failed to install the nft tables'

  log 'Iptables have been replaced by nft tables'
  log 'Base packages have been installed'
}

# Installs the Xorg display server packages.
install_display_server () {
  log 'Installing the display server...'

  pacman -S --needed --noconfirm xorg xorg-xinit xorg-xrandr xorg-xdpyinfo 2>&1 ||
    fail 'Failed to install xorg packages'

  log 'Xorg packages have been installed'

  cp /opt/stack/configs/xorg/xorg.conf /etc/X11 ||
    fail 'Failed to copy the xorg config file'

  log 'Xorg confg have been saved under /etc/X11/xorg.conf'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  cp /opt/stack/configs/xorg/xinitrc "/home/${user_name}/.xinitrc" &&
    chown ${user_name}:${user_name} "/home/${user_name}/.xinitrc" ||
    fail 'Failed to set the .xinitrc file'

  log "Xinitrc has been saved to /home/${user_name}/.xinitrc"

  local bash_profile_file="/home/${user_name}/.bash_profile"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${bash_profile_file}" ||
    fail 'Failed to add startx hook to .bash_profile'

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' \
    /usr/lib/systemd/system/getty@.service ||
    fail 'Failed to set getty to start X11 session after login'

  log 'Getty has been set to start X11 session after login'
  log 'Display server has been installed'
}

# Installs hardware and system drivers.
install_drivers () {
  log 'Installing system drivers...'

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

  pacman -S --needed --noconfirm \
    acpi acpi_call acpid tlp xcalib \
    networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant \
    nmap dhclient smbclient libnma \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack \
    ${cpu_pckgs} ${gpu_pckgs} ${other_pckgs} ${vm_pckgs} 2>&1 ||
    fail 'Failed to install system drivers'

  log 'System drivers have been installed'
}

# Installs the user repository package manager.
install_aur_package_manager () {
  log 'Installing the AUR package manager...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local yay_home="/home/${user_name}/yay"

  git clone https://aur.archlinux.org/yay.git "${yay_home}" 2>&1 &&
    chown -R ${user_name}:${user_name} "${yay_home}" &&
    cd "${yay_home}" &&
    sudo -u "${user_name}" makepkg -si --noconfirm 2>&1 &&
    cd ~ &&
    rm -rf "${yay_home}" ||
    fail 'Failed to install the AUR package manager'

  log 'AUR package manager has been installed'
}

# Sets the system locale along with the locale environment variables.
set_locales () {
  local locales=''
  locales="$(get_setting 'locales')" || fail

  log 'Generating system locales...'

  echo "${locales}" | jq -cer '.[]' >> /etc/locale.gen || fail

  locale-gen 2>&1 ||
    fail 'Failed to generate system locales'

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
    "LC_ALL=" | tee /etc/locale.conf > /dev/null ||
    fail 'Failed to set locale env variables'

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

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    fail 'Failed to save locales into the langs setting file'
  
  log 'Locales has been save into the langs settings'
  log "Locale has been set to ${locale}"
}

# Sets keyboard related settings.
set_keyboard () {
  log 'Applying keyboard settings...'

  local keyboard_map=''
  keyboard_map="$(get_setting 'keyboard_map')" || fail

  echo "KEYMAP=${keyboard_map}" > /etc/vconsole.conf ||
    fail 'Failed to add keymap to vconsole'

  log "Virtual console keymap set to ${keyboard_map}"

  loadkeys "${keyboard_map}" 2>&1 ||
    fail 'Failed to load keyboard map keys'

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
   'EndSection' | tee /etc/X11/xorg.conf.d/00-keyboard.conf > /dev/null ||
     fail 'Failed to add keyboard setting into the xorg config file'

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

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    fail 'Failed to save keymap to langs settings file'
  
  log 'Keymap saved to langs settings file'
  log 'Keyboard settings have been applied'
}

# Sets the system timezone.
set_timezone () {
  log 'Setting the system timezone...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || fail

  ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime ||
    fail 'Failed to set the timezone'

  log "Timezone has been set to ${timezone}"

  local ntp_server='time.google.com'

  sed -i "s/^#NTP=/NTP=${ntp_server}/" /etc/systemd/timesyncd.conf ||
    fail 'Failed to set the NTP server'

  log "NTP server has been set to ${ntp_server}"

  hwclock --systohc --utc 2>&1 ||
    fail 'Failed to sync hardware to system clock'

  log 'Hardware clock has been synchronized to system clock'
}

# Boost system performance on various tasks.
boost_performance () {
  log 'Boosting system performance...'

  local cores=''
  cores="$(
    grep -c '^processor' /proc/cpuinfo 2>&1
  )" || fail 'Failed to read cpu data'

  if is_not_integer "${cores}" '[1,]'; then
    fail 'Unable to resolve CPU cores'
  fi

  log "Detected a CPU with a total of ${cores} logical cores"

  local conf_file='/etc/makepkg.conf'

  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${cores}\"/g" "${conf_file}" ||
    fail 'Failed to set the make flags setting'

  log "Make flags have been set to ${cores} CPU cores"

  sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=${cores} -)/g" "${conf_file}" ||
    fail 'Failed to set the compressXZ threads'
  
  sed -i "s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=${cores} -)/g" "${conf_file}" ||
    fail 'Failed to set the compressZST threads'

  log 'Compression threads have been set'

  log 'Increasing the limit of inotify watches...'

  local limit=524288
  echo "fs.inotify.max_user_watches=${limit}" >> /etc/sysctl.conf ||
    fail 'Failed to set the max limit of inotify watches'

  sysctl --system 2>&1 ||
    fail 'Failed to update the max limit to inotify watches'

  log "Inotify watches limit has been set to ${limit}"

  log 'Boosting has been completed'
}

# Applies varius system power settings.
configure_power () {
  log 'Configuring power settings...'
  
  local logind_conf='/etc/systemd/logind.conf.d/00-main.conf'
  
  mkdir -p /etc/systemd/logind.conf.d &&
    cp /etc/systemd/logind.conf "${logind_conf}" ||
    fail 'Failed to create the logind config file'

  echo 'HandleHibernateKey=ignore' >> "${logind_conf}" ||
    fail 'Failed set hibernate key to ignore'

  log 'Hiberante key set to ignore'

  echo 'HandleHibernateKeyLongPress=ignore' >> "${logind_conf}" ||
    fail 'Failed to set hibernate key long press to ignore'

  log 'Hiberante key long press set to ignore'

  echo 'HibernateKeyIgnoreInhibited=no' >> "${logind_conf}" ||
    fail 'Failed to set hibernate key to ignore inhibited'

  log 'Hibernate key set to ignore inhibited'

  echo 'HandlePowerKey=suspend' >> "${logind_conf}" ||
    fail 'Failed to set power key to suspend'

  log 'Power key set to suspend'

  echo 'HandleRebootKey=reboot' >> "${logind_conf}" ||
    fail 'Failed to set reboot key to reboot'
  
  log 'Reboot key set to reboot'

  echo 'HandleSuspendKey=suspend' >> "${logind_conf}" ||
    fail 'Failed to set suspend key to suspend'
  
  log 'Suspend key set to suspend'

  echo 'HandleLidSwitch=suspend' >> "${logind_conf}" ||
    fail 'Failed to set lid switch to suspend'
  
  log 'Lid switch set to suspend'

  echo 'HandleLidSwitchDocked=ignore' >> "${logind_conf}" ||
    fail 'Failed to set lid switch docked to ignore'
  
  log 'Lid switch docked set to ignore'

  local sleep_conf='/etc/systemd/sleep.conf.d/00-main.conf'

  mkdir -p /etc/systemd/sleep.conf.d &&
    cp /etc/systemd/sleep.conf "${sleep_conf}" ||
    fail 'Failed to create the sleep config file'

  echo 'AllowSuspend=yes' >> "${sleep_conf}" ||
    fail 'Failed to set allow suspend to yes'
  
  log 'Allow suspend set to yes'

  echo 'AllowHibernation=no' >> "${sleep_conf}" ||
    fail 'Failed to set allow hibernation to no'
  
  log 'Allow hibernation set to no'

  echo 'AllowSuspendThenHibernate=no' >> "${sleep_conf}" ||
    fail 'Failed to set allow suspend then hibernate to no'

  log 'Allow suspend then to hibernate set to no'

  echo 'AllowHybridSleep=no' >> "${sleep_conf}" ||
    fail 'Failed to set allow hybrid sleep to no'

  log 'Allow hybrid sleep set to no'

  local tlp_conf='/etc/tlp.d/00-main.conf'

  echo 'SOUND_POWER_SAVE_ON_AC=0' >> "${tlp_conf}" &&
    echo 'SOUND_POWER_SAVE_ON_BAT=0' >> "${tlp_conf}" ||
    fail 'Failed to set no sound on power save mode'

  rm -f /etc/tlp.d/00-template.conf || fail

  # Save screensaver settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings='{"screensaver": {"interval": 15}}'

  local settings_file="${config_home}/power.json"

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    fail 'Failed to save screen saver interval to power settings file'
  
  log 'Screen saver interval saved to power settings file'
  log 'Power configurations have been set'
}

# Applies various system security settings.
configure_security () {
  log 'Hardening system security...'

  sed -i '/# Defaults maxseq = 1000/a Defaults badpass_message="Sorry incorrect password!"' /etc/sudoers ||
    fail 'Failed to set badpass message'
  
  log 'Default bad pass message has been set'

  sed -i '/# Defaults maxseq = 1000/a Defaults passwd_timeout=0' /etc/sudoers ||
    fail 'Failed to set password timeout interval'
  
  log 'Password timeout interval set to 0'

  sed -i '/# Defaults maxseq = 1000/a Defaults passwd_tries=2' /etc/sudoers ||
    fail 'Failed to set password failed tries'
  
  log 'Password failed tries set to 2'

  sed -i '/# Defaults maxseq = 1000/a Defaults passprompt="Enter current password: "' /etc/sudoers ||
    fail 'Failed to set password prompt'
  
  log 'Password prompt has been set'

  sed -ri 's;# dir =.*;dir = /var/lib/faillock;' /etc/security/faillock.conf ||
    fail 'Failed to set faillock file path'
  
  log 'Faillock file path has been set to /var/lib/faillock'

  sed -ri 's;# deny =.*;deny = 3;' /etc/security/faillock.conf ||
    fail 'Failed to set deny'
  
  log 'Deny has been set to 3'

  sed -ri 's;# fail_interval =.*;fail_interval = 180;' /etc/security/faillock.conf ||
    fail 'Failed to set fail interval time'
  
  log 'Fail interval time set to 180 secs'

  sed -ri 's;# unlock_time =.*;unlock_time = 120;' /etc/security/faillock.conf ||
    fail 'Failed to set unlock time'
  
  log 'Unlock time set to 120 secs'

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config ||
    fail 'Failed to set permit root login to no'

  log 'SSH login permission disabled for the root user'
  log 'Setting up a simple stateful firewall...'

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
    nft add rule inet my_table my_input counter reject with icmpx port-unreachable 2>&1 ||
    fail 'Failed to add NFT table rules'

  mv /etc/nftables.conf /etc/nftables.conf.bak &&
    nft -s list ruleset > /etc/nftables.conf 2>&1 ||
    fail 'Failed to flush NFT tables rules'

  log 'Firewall ruleset has been flushed to /etc/nftables.conf'

  # Save screen locker settings to the user config
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings='{"screen_locker": {"interval": 12}}'

  local settings_file="${config_home}/security.json"

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    fail 'Failed to save screen locker interval to security settings'
  
  log 'Screen locker interval saved to the security settings'
  log 'Security configuration has been completed'
}

# Installs and configures the boot loader.
install_boot_loader () {
  log 'Setting up the boot loader...'

  if is_setting 'uefi_mode' 'yes'; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1 ||
      fail 'Failed to install grub boot loader on x86_64-efi'
    
    log 'Grub boot loader has been installed on x86_64-efi'
  else
    local disk=''
    disk="$(get_setting 'disk')" || fail

    grub-install --target=i386-pc "${disk}" 2>&1 ||
      fail 'Failed to install grub boot on i386-pc'
    
    log 'Grub boot loader has been installed on i386-pc'
  fi

  log 'Configuring the boot loader...'

  sed -ri 's/(GRUB_CMDLINE_LINUX_DEFAULT=".*)"/\1 consoleblank=300"/' /etc/default/grub &&
    sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub &&
    sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub &&
    sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub ||
    fail 'Failed to set boot loader properties'

  grub-mkconfig -o /boot/grub/grub.cfg 2>&1 ||
    fail 'Failed to create the boot loader config file'

  log 'Boot loader config file created successfully'

  if is_setting 'uefi_mode' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    mkdir -p /boot/EFI/BOOT &&
      cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI || fail
  fi

  log 'Boot loader has been set up successfully'
}

# Enables system services.
enable_services () {
  log 'Enabling system services...'

  systemctl enable systemd-timesyncd.service 2>&1 ||
    fail 'Failed to enable timesyncd service'

  log 'Service timesyncd has been enabled'

  systemctl enable NetworkManager.service 2>&1 ||
    fail 'Failed to enable network manager service'

  log 'Service network manager has been enabled'

  systemctl enable bluetooth.service 2>&1 ||
    fail 'Failed to enable bluetooth service'

  log 'Service bluetooth has been enabled'

  systemctl enable acpid.service 2>&1 ||
    fail 'Failed to enable acpid service'

  log 'Service acpid has been enabled'

  systemctl enable cups.service 2>&1 ||
    fail 'Failed to enable cups service'

  log 'Service cups has been enabled'

  systemctl enable sshd.service 2>&1 ||
    fail 'Failed to enable sshd service'
  
  log 'Service sshd has been enabled'

  systemctl enable nftables.service 2>&1 ||
    fail 'Failed to enable nftables service'
  
  log 'Service nftables has been enabled'

  systemctl enable reflector.timer 2>&1 ||
    fail 'Failed to enable reflector.timer service'

  log 'Service reflector.timer has been enabled'

  systemctl enable paccache.timer 2>&1 ||
    fail 'Failed to enable paccache.timer service'

  log 'Service paccache.timer has been enabled'

  if is_setting 'trim_disk' 'yes'; then
    systemctl enable fstrim.timer 2>&1 ||
      fail 'Failed to enable fstrim.timer service'
    
    log 'Service fstrim.timer has been enabled'
  fi

  if is_setting 'vm' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    systemctl enable vboxservice.service 2>&1 ||
      fail 'Failed to enable virtual box service'

    log 'Service virtual box has been enabled'
  fi
  
  local user_name=''
  user_name="$(get_setting 'user_name')" || fail
  
  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}/systemd/user" ||
    fail 'Failed to create the user systemd folder'

  cp /opt/stack/services/init-pointer.service "${config_home}/systemd/user" ||
    fail 'Failed to set the init-pointer service'

  log 'Service init-pointer has been set'

  cp /opt/stack/services/init-tablets.service "${config_home}/systemd/user" ||
    fail 'Failed to set the init-tablets service'

  log 'Service init-tablets has been set'

  cp /opt/stack/services/fix-layout.service "${config_home}/systemd/user" ||
    fail 'Failed to set the fix-layout service'
  
  log 'Service fix-layout has been set'

  chown -R ${user_name}:${user_name} "${config_home}/systemd" ||
    fail 'Failed to change user ownership to user systemd services'
  
  sed -i "s/#USER/${user_name}/g" "${config_home}/systemd/user/fix-layout.service" ||
    fail 'Failed to set the user name in the fix-layout service file'

  log 'System services have been enabled'
}

# Adds system rules for udev.
add_rules () {
  log 'Adding system udev rules...'

  local rules_home='/etc/udev/rules.d'

  cp /opt/stack/rules/90-init-pointer.rules "${rules_home}" ||
    fail 'Failed to add the init-pointer rules'

  log 'Rules init-pointer have been added'

  cp /opt/stack/rules/91-init-tablets.rules "${rules_home}" ||
    fail 'Failed to add the init-tablets rules'

  log 'Rules init-tablets have been added'

  cp /opt/stack/rules/92-fix-layout.rules "${rules_home}" ||
    fail 'Failed to add the fix-layout rules'
    
  log 'Rules fix-layout have been set'
  log 'System udev rules have been added'
}

log 'Installing the system...'

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
  boost_performance &&
  configure_power &&
  configure_security &&
  install_boot_loader &&
  enable_services &&
  add_rules

sleep 3
