#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/process.sh
source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/json.sh
source /opt/stack/commons/validators.sh

SETTINGS='/opt/stack/installer/settings.json'

# Sets host related settings.
set_host () {
  log INFO 'Setting up the host...'

  local host_name=''
  host_name="$(get_property "${SETTINGS}" '.host_name')" ||
    abort ERROR 'Unable to read host_name setting.'

  echo "${host_name}" > /etc/hostname ||
    abort ERROR 'Failed to set the host name.'

  log INFO "Host name has been set to ${host_name}."

  printf '%s\n' \
    '127.0.0.1    localhost' \
    '::1          localhost' \
    "127.0.1.1    ${host_name}" > /etc/hosts ||
    abort ERROR 'Failed to add host name to hosts.'

  log INFO 'Host name has been added to the hosts.'
  log INFO 'Host has been set successfully.'
}

# Sets up the root and sudoer users of the system.
set_users () {
  log INFO 'Setting up the system users...'

  local groups='wheel,audio,video,optical,storage'

  if is_property "${SETTINGS}" '.vm' 'yes'; then
    groupadd 'libvirt' 2>&1
    groups="${groups},libvirt"
  fi

  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  useradd -m -G "${groups}" -s /bin/bash "${user_name}" 2>&1 ||
    abort ERROR 'Failed to create the sudoer user.'

  log INFO "Sudoer user ${user_name} has been created."

  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to create the user config folder.'

  log INFO 'User config folder created under ~/.config.'

  local rule='%wheel ALL=(ALL:ALL) ALL'

  sed -i "s/^# \(${rule}\)/\1/" /etc/sudoers ||
    abort ERROR 'Failed to grant sudo permissions to wheel group.'

  if ! grep -q "^${rule}" /etc/sudoers; then
    abort ERROR 'Failed to grant sudo permissions to wheel group.'
  fi

  log INFO 'Sudo permissions have been granted to sudoer user.'

  local user_password=''
  user_password="$(get_property "${SETTINGS}" '.user_password')" ||
    abort ERROR 'Unable to read user_password setting.'

  echo "${user_name}:${user_password}" | chpasswd 2>&1 ||
    abort ERROR "Failed to set password to user ${user_name}."

  log INFO "Password has been given to user ${user_name}."

  local root_password=''
  root_password="$(get_property "${SETTINGS}" '.root_password')" ||
    abort ERROR 'Unable to read root_password setting.'

  echo "root:${root_password}" | chpasswd 2>&1 ||
    abort ERROR 'Failed to set password to root user.'

  log INFO 'Password has been given to the root user.'

  cp /etc/skel/.bash_profile /root ||
    abort ERROR 'Failed to create root .bash_profile file.'

  cp /etc/skel/.bashrc /root ||
    abort ERROR 'Failed to create root .bashrc file.'

  log INFO 'System users have been set up.'
}

# Sets the pacman package database mirrors.
set_mirrors () {
  log INFO 'Setting up the package databases mirrors...'

  local mirrors=''
  mirrors="$(get_property "${SETTINGS}" '.mirrors' | jq -cer 'join(",")')" ||
    abort ERROR 'Unable to read mirrors setting.'

  reflector --country "${mirrors}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1 ||
    abort ERROR 'Unable to fetch package databases mirrors.'

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sed -i "s/# --country.*/--country ${mirrors}/" "${conf_file}" &&
    sed -i 's/^--latest.*/--latest 40/' "${conf_file}" &&
    echo '--age 48' >> "${conf_file}" ||
    abort ERROR 'Failed to save mirrors settings to reflector.'

  log INFO "Package databases mirrors set to ${mirrors}."
}

# Configures pacman package manager.
configure_pacman () {
  log INFO 'Configuring the pacman manager...'

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ||
    abort ERROR 'Failed to set parallel download.'

  log INFO 'Parallel download has been enabled.'

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
    abort ERROR 'Failed to add the GPG keyserver.'

  log INFO "GPG keyserver has been set to ${keyserver}."

  local hooks_home='/etc/pacman.d/hooks'

  mkdir -p "${hooks_home}" &&
    cp /opt/stack/installer/configs/pacman/orphans.hook "${hooks_home}/01-orphans.hook" ||
    abort ERROR 'Failed to add the orphan packages hook.'

  log INFO 'Orphan packages post hook has been created.'
  log INFO 'Pacman manager has been configured.'
}

# Synchronizes the package databases to the master.
sync_package_databases () {
  log INFO 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log WARN 'Package databases seem to be locked.'

    rm -f "${lock_file}" ||
      abort ERROR "Failed to remove the lock file ${lock_file}."

    log INFO "Lock file ${lock_file} has been removed."
  fi

  pacman -Syy 2>&1 ||
    abort ERROR 'Failed to synchronize package databases.'

  log INFO 'Package databases synchronized to the master.'
}

# Installs the base packages of the system.
install_base_packages () {
  log INFO 'Installing the base packages...'

  local extra_pckgs=''
  if is_property "${SETTINGS}" '.uefi_mode' 'yes'; then
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
    abort ERROR 'Failed to install base packages.'

  log INFO 'Replacing iptables with nft tables...'

  printf '%s\n' y y | pacman -S --needed nftables iptables-nft 2>&1 ||
    abort ERROR 'Failed to install the nft tables.'

  log INFO 'Iptables have been replaced by nft tables.'
  log INFO 'Base packages have been installed.'
}

# Installs the Xorg display server packages.
install_display_server () {
  log INFO 'Installing the display server...'

  pacman -S --needed --noconfirm xorg xorg-xinit xorg-xrandr xorg-xdpyinfo 2>&1 ||
    abort ERROR 'Failed to install xorg packages.'

  log INFO 'Xorg packages have been installed.'

  cp /opt/stack/installer/configs/xorg/xorg.conf /etc/X11 ||
    abort ERROR 'Failed to copy the xorg config file.'

  log INFO 'Xorg confg have been saved under /etc/X11/xorg.conf.'

  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  cp /opt/stack/installer/configs/xorg/xinitrc "/home/${user_name}/.xinitrc" &&
    chown ${user_name}:${user_name} "/home/${user_name}/.xinitrc" ||
    abort ERROR 'Failed to set the .xinitrc file.'

  log INFO "Xinitrc has been saved to /home/${user_name}/.xinitrc."

  local bash_profile_file="/home/${user_name}/.bash_profile"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${bash_profile_file}" ||
    abort ERROR 'Failed to add startx hook to .bash_profile.'

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' \
    /usr/lib/systemd/system/getty@.service ||
    abort ERROR 'Failed to set getty to start X11 session after login.'

  log INFO 'Getty has been set to start X11 session after login.'
  log INFO 'Display server has been installed.'
}

# Installs hardware and system drivers.
install_drivers () {
  log INFO 'Installing system drivers...'

  local cpu_pckgs=''

  if is_property "${SETTINGS}" '.cpu_vendor' 'amd'; then
    cpu_pckgs='amd-ucode'
  elif is_property "${SETTINGS}" '.cpu_vendor' 'intel'; then
    cpu_pckgs='intel-ucode'
  fi

  local gpu_pckgs=''

  if is_property "${SETTINGS}" '.gpu_vendor' 'nvidia'; then
    local kernel=''
    kernel="$(get_property "${SETTINGS}" '.kernel')" ||
      abort ERROR 'Unable to read kernel setting.'

    if equals "${kernel}" 'stable'; then
      gpu_pckgs='nvidia'
    elif equals "${kernel}" 'lts'; then
      gpu_pckgs='nvidia-lts'
    fi

    gpu_pckgs+=' nvidia-utils nvidia-settings'
  elif is_property "${SETTINGS}" '.gpu_vendor' 'amd'; then
    gpu_pckgs='xf86-video-amdgpu'
  elif is_property "${SETTINGS}" '.gpu_vendor' 'intel'; then
    gpu_pckgs='libva-intel-driver libvdpau-va-gl vulkan-intel libva-utils'
  else
    gpu_pckgs='xf86-video-qxl'
  fi

  local other_pckgs=''

  if is_property "${SETTINGS}" '.synaptics' 'yes'; then
    other_pckgs='xf86-input-synaptics'
  fi

  local vm_pckgs=''

  if is_property "${SETTINGS}" '.vm' 'yes' && is_property "${SETTINGS}" '.vm_vendor' 'oracle'; then
    vm_pckgs='virtualbox-guest-utils'
  fi

  pacman -S --needed --noconfirm \
    acpi acpi_call acpid tlp xcalib \
    networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant \
    nmap dhclient smbclient libnma \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack \
    ${cpu_pckgs} ${gpu_pckgs} ${other_pckgs} ${vm_pckgs} 2>&1 ||
    abort ERROR 'Failed to install system drivers.'

  log INFO 'System drivers have been installed.'
}

# Installs the system tools for managing system settings.
install_system_tools () {
  log INFO 'Installing the system tools...'

  local tools_home='/opt/stack/tools'

  sudo mkdir -p "${tools_home}" &&
    sudo cp -r /opt/stack/installer/tools/* "${tools_home}" ||
    abort ERROR 'Failed to install system tools.'

  local bin_home='/usr/local/bin'

  # Create symlinks to expose executables
  sudo ln -sf "${tools_home}/displays/main.sh" "${bin_home}/displays" &&
    sudo ln -sf "${tools_home}/desktop/main.sh" "${bin_home}/desktop" &&
    sudo ln -sf "${tools_home}/audio/main.sh" "${bin_home}/audio" &&
    sudo ln -sf "${tools_home}/clock/main.sh" "${bin_home}/clock" &&
    sudo ln -sf "${tools_home}/cloud/main.sh" "${bin_home}/cloud" &&
    sudo ln -sf "${tools_home}/networks/main.sh" "${bin_home}/networks" &&
    sudo ln -sf "${tools_home}/disks/main.sh" "${bin_home}/disks" &&
    sudo ln -sf "${tools_home}/bluetooth/main.sh" "${bin_home}/bluetooth" &&
    sudo ln -sf "${tools_home}/langs/main.sh" "${bin_home}/langs" &&
    sudo ln -sf "${tools_home}/notifications/main.sh" "${bin_home}/notifications" &&
    sudo ln -sf "${tools_home}/power/main.sh" "${bin_home}/power" &&
    sudo ln -sf "${tools_home}/printers/main.sh" "${bin_home}/printers" &&
    sudo ln -sf "${tools_home}/security/main.sh" "${bin_home}/security" &&
    sudo ln -sf "${tools_home}/trash/main.sh" "${bin_home}/trash" &&
    sudo ln -sf "${tools_home}/system/main.sh" "${bin_home}/system" ||
    abort ERROR 'Failed to create symlinks to /usr/local/bin.'

  log INFO 'System tools have been installed.'
}

# Installs the user repository package manager.
install_aur_package_manager () {
  log INFO 'Installing the AUR package manager...'

  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  local yay_home="/home/${user_name}/yay"

  git clone https://aur.archlinux.org/yay.git "${yay_home}" 2>&1 &&
    chown -R ${user_name}:${user_name} "${yay_home}" &&
    cd "${yay_home}" &&
    sudo -u "${user_name}" makepkg -si --noconfirm 2>&1 &&
    cd ~ &&
    rm -rf "${yay_home}" ||
    abort ERROR 'Failed to install the AUR package manager.'

  log INFO 'AUR package manager has been installed.'
}

# Sets the system locale along with the locale environment variables.
set_locales () {
  local locales=''
  locales="$(get_property "${SETTINGS}" '.locales')" ||
    abort ERROR 'Unable to read locales setting.'

  log INFO 'Generating system locales...'

  echo "${locales}" | jq -cer '.[]' >> /etc/locale.gen ||
    abort ERROR 'Failed to flush locales to locales.gen.'

  locale-gen 2>&1 ||
    abort ERROR 'Failed to generate system locales.'

  log INFO 'System locales have been generated.'

  # Set as system locale the locale selected first
  local locale=''
  locale="$(echo "${locales}" | jq -cer '.[0]' | cut -d ' ' -f 1)" ||
    abort ERROR 'Failed to read the default locale.'

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
    abort ERROR 'Failed to set locale env variables.'

  # Unset previous set variables
  unset LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE \
        LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS \
        LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL ||
        abort ERROR 'Failed to unset locale variables.'
  
  # Save locale settings to the user config
  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || abort ERROR "Failed to create folder ${config_home}."

  local settings=''
  settings="$(echo "${locales}" | jq -e '{locale: .[0], locales: .}')" ||
    abort ERROR 'Failed to parse locale settings to JSON object.'

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" ||
      abort ERROR 'Failed to merge locales to langs settings.'
  fi

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to save locales into the langs setting file.'
  
  log INFO 'Locales has been save into the langs settings.'
  log INFO "Locale has been set to ${locale}."
}

# Sets keyboard related settings.
set_keyboard () {
  log INFO 'Applying keyboard settings...'

  local keyboard_map=''
  keyboard_map="$(get_property "${SETTINGS}" '.keyboard_map')" ||
    abort ERROR 'Unable to read keyboard_map setting.'

  echo "KEYMAP=${keyboard_map}" > /etc/vconsole.conf ||
    abort ERROR 'Failed to add keymap to vconsole.'

  log INFO "Virtual console keymap set to ${keyboard_map}."

  loadkeys "${keyboard_map}" 2>&1 ||
    abort ERROR 'Failed to load keyboard map keys.'

  log INFO 'Keyboard map keys has been loaded.'

  local keyboard_model=''
  keyboard_model="$(get_property "${SETTINGS}" '.keyboard_model')" ||
    abort ERROR 'Unable to read keyboard_model setting.'

  local keyboard_layout=''
  keyboard_layout="$(get_property "${SETTINGS}" '.keyboard_layout')" ||
    abort ERROR 'Unable to read keyboard_layout setting.'
  
  local layout_variant=''
  layout_variant="$(get_property "${SETTINGS}" '.layout_variant')" ||
    abort ERROR 'Unable to read layout_variant setting.'

  local keyboard_options=''
  keyboard_options="$(get_property "${SETTINGS}" '.keyboard_options')" ||
    abort ERROR 'Unable to read keyboard_options setting.'
  
  local keyboard_conf="/etc/X11/xorg.conf.d/00-keyboard.conf"

  echo -e 'Section "InputClass"' > "${keyboard_conf}"
  echo -e '  Identifier "system-keyboard"' >> "${keyboard_conf}"
  echo -e '  MatchIsKeyboard "on"' >> "${keyboard_conf}"
  echo -e "  Option \"XkbLayout\" \"${keyboard_layout}\"" >> "${keyboard_conf}"
  not_equals "${layout_variant}" 'default' &&
    echo -e "  Option \"XkbVariant\" \"${layout_variant}\"" >> "${keyboard_conf}"
  echo -e "  Option \"XkbModel\" \"${keyboard_model}\"" >> "${keyboard_conf}"
  echo -e "  Option \"XkbOptions\" \"${keyboard_options}\"" >> "${keyboard_conf}"
  echo -e 'EndSection' >> "${keyboard_conf}"

  log INFO 'Xorg keyboard settings have been added.'

  # Save keyboard settings to the user config
  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || abort ERROR "Failed to create folder ${config_home}."

  local settings=''
  settings+="\"keymap\": \"${keyboard_map}\","
  settings+="\"model\": \"${keyboard_model}\","
  settings+="\"options\": \"${keyboard_options}\","
  settings+="\"layouts\": [{\"code\": \"${keyboard_layout}\", \"variant\": \"${layout_variant}\"}]"
  settings="{${settings}}"

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" ||
      abort ERROR 'Failed to merge keyboard to langs setttings.'
  fi

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to save keyboard to langs settings file.'
  
  log INFO 'Keyboard saved to langs settings file.'
  log INFO 'Keyboard settings have been applied.'
}

# Sets the system timezone.
set_timezone () {
  log INFO 'Setting the system timezone...'

  local timezone=''
  timezone="$(get_property "${SETTINGS}" '.timezone')" ||
    abort ERROR 'Unable to read timezone setting.'

  ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime ||
    abort ERROR 'Failed to set the timezone.'

  log INFO "Timezone has been set to ${timezone}."

  local ntp_server='time.google.com'

  sed -i "s/^#NTP=/NTP=${ntp_server}/" /etc/systemd/timesyncd.conf ||
    abort ERROR 'Failed to set the NTP server.'

  log INFO "NTP server has been set to ${ntp_server}."

  hwclock --systohc --utc 2>&1 ||
    abort ERROR 'Failed to sync hardware to system clock.'

  log INFO 'Hardware clock has been synchronized to system clock.'
}

# Boost system performance on various tasks.
boost_performance () {
  log INFO 'Boosting system performance...'

  local cores=''
  cores="$(
    grep -c '^processor' /proc/cpuinfo 2>&1
  )" || abort ERROR 'Failed to read cpu data.'

  if is_not_integer "${cores}" '[1,]'; then
    abort ERROR 'Unable to resolve CPU cores.'
  fi

  log INFO "Detected a CPU with a total of ${cores} logical cores."

  local conf_file='/etc/makepkg.conf'

  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${cores}\"/g" "${conf_file}" ||
    abort ERROR 'Failed to set the make flags setting.'

  log INFO "Make flags have been set to ${cores} CPU cores."

  sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=${cores} -)/g" "${conf_file}" ||
    abort ERROR 'Failed to set the compressXZ threads.'
  
  sed -i "s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=${cores} -)/g" "${conf_file}" ||
    abort ERROR 'Failed to set the compressZST threads.'

  log INFO 'Compression threads have been set.'

  log INFO 'Increasing the limit of inotify watches...'

  local limit=524288
  echo "fs.inotify.max_user_watches=${limit}" >> /etc/sysctl.conf ||
    abort ERROR 'Failed to set the max limit of inotify watches.'

  sysctl --system 2>&1 ||
    abort ERROR 'Failed to update the max limit to inotify watches.'

  log INFO "Inotify watches limit has been set to ${limit}."

  log INFO 'Boosting has been completed.'
}

# Applies varius system power settings.
configure_power () {
  log INFO 'Configuring power settings...'
  
  local logind_conf='/etc/systemd/logind.conf.d/00-main.conf'
  
  mkdir -p /etc/systemd/logind.conf.d &&
    cp /etc/systemd/logind.conf "${logind_conf}" ||
    abort ERROR 'Failed to create the logind config file.'

  echo 'HandleHibernateKey=ignore' >> "${logind_conf}" ||
    abort ERROR 'Failed set hibernate key to ignore.'

  log INFO 'Hiberante key set to ignore.'

  echo 'HandleHibernateKeyLongPress=ignore' >> "${logind_conf}" ||
    abort ERROR 'Failed to set hibernate key long press to ignore.'

  log INFO 'Hiberante key long press set to ignore.'

  echo 'HibernateKeyIgnoreInhibited=no' >> "${logind_conf}" ||
    abort ERROR 'Failed to set hibernate key to ignore inhibited.'

  log INFO 'Hibernate key set to ignore inhibited.'

  echo 'HandlePowerKey=suspend' >> "${logind_conf}" ||
    abort ERROR 'Failed to set power key to suspend.'

  log INFO 'Power key set to suspend.'

  echo 'HandleRebootKey=reboot' >> "${logind_conf}" ||
    abort ERROR 'Failed to set reboot key to reboot.'
  
  log INFO 'Reboot key set to reboot.'

  echo 'HandleSuspendKey=suspend' >> "${logind_conf}" ||
    abort ERROR 'Failed to set suspend key to suspend.'
  
  log INFO 'Suspend key set to suspend.'

  echo 'HandleLidSwitch=suspend' >> "${logind_conf}" ||
    abort ERROR 'Failed to set lid switch to suspend.'
  
  log INFO 'Lid switch set to suspend.'

  echo 'HandleLidSwitchDocked=ignore' >> "${logind_conf}" ||
    abort ERROR 'Failed to set lid switch docked to ignore.'
  
  log INFO 'Lid switch docked set to ignore.'

  local sleep_conf='/etc/systemd/sleep.conf.d/00-main.conf'

  mkdir -p /etc/systemd/sleep.conf.d &&
    cp /etc/systemd/sleep.conf "${sleep_conf}" ||
    abort ERROR 'Failed to create the sleep config file.'

  echo 'AllowSuspend=yes' >> "${sleep_conf}" ||
    abort ERROR 'Failed to set allow suspend to yes.'
  
  log INFO 'Allow suspend set to yes.'

  echo 'AllowHibernation=no' >> "${sleep_conf}" ||
    abort ERROR 'Failed to set allow hibernation to no.'
  
  log INFO 'Allow hibernation set to no.'

  echo 'AllowSuspendThenHibernate=no' >> "${sleep_conf}" ||
    abort ERROR 'Failed to set allow suspend then hibernate to no.'

  log INFO 'Allow suspend then to hibernate set to no.'

  echo 'AllowHybridSleep=no' >> "${sleep_conf}" ||
    abort ERROR 'Failed to set allow hybrid sleep to no.'

  log INFO 'Allow hybrid sleep set to no.'

  local tlp_conf='/etc/tlp.d/00-main.conf'

  echo 'SOUND_POWER_SAVE_ON_AC=0' >> "${tlp_conf}" &&
    echo 'SOUND_POWER_SAVE_ON_BAT=0' >> "${tlp_conf}" ||
    abort ERROR 'Failed to set no sound on power save mode.'

  rm -f /etc/tlp.d/00-template.conf || abort ERROR 'Unable to remove the template TLP file.'

  # Save screensaver settings to the user config
  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || abort ERROR "Failed to create folder ${config_home}."

  local settings='{"screensaver": {"interval": 15}}'

  local settings_file="${config_home}/power.json"

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to save screen saver interval to power settings file.'
  
  log INFO 'Screen saver interval saved to power settings file.'
  log INFO 'Power configurations have been set.'
}

# Applies various system security settings.
configure_security () {
  log INFO 'Hardening system security...'

  sed -i '/# Defaults maxseq = 1000/a Defaults badpass_message="Sorry incorrect password!"' /etc/sudoers ||
    abort ERROR 'Failed to set badpass message.'
  
  log INFO 'Default bad pass message has been set.'

  sed -i '/# Defaults maxseq = 1000/a Defaults passwd_timeout=0' /etc/sudoers ||
    abort ERROR 'Failed to set password timeout interval.'
  
  log INFO 'Password timeout interval set to 0.'

  sed -i '/# Defaults maxseq = 1000/a Defaults passwd_tries=2' /etc/sudoers ||
    abort ERROR 'Failed to set password failed tries.'
  
  log INFO 'Password failed tries set to 2.'

  sed -i '/# Defaults maxseq = 1000/a Defaults passprompt="Enter current password: "' /etc/sudoers ||
    abort ERROR 'Failed to set password prompt.'
  
  log INFO 'Password prompt has been set.'

  sed -ri 's;# dir =.*;dir = /var/lib/faillock;' /etc/security/faillock.conf ||
    abort ERROR 'Failed to set faillock file path.'
  
  log INFO 'Faillock file path has been set to /var/lib/faillock.'

  sed -ri 's;# deny =.*;deny = 3;' /etc/security/faillock.conf ||
    abort ERROR 'Failed to set deny.'
  
  log INFO 'Deny has been set to 3.'

  sed -ri 's;# fail_interval =.*;fail_interval = 180;' /etc/security/faillock.conf ||
    abort ERROR 'Failed to set fail interval time.'
  
  log INFO 'Fail interval time set to 180 secs.'

  sed -ri 's;# unlock_time =.*;unlock_time = 120;' /etc/security/faillock.conf ||
    abort ERROR 'Failed to set unlock time.'
  
  log INFO 'Unlock time set to 120 secs.'

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config ||
    abort ERROR 'Failed to set permit root login to no.'

  log INFO 'SSH login permission disabled for the root user.'
  log INFO 'Setting up a simple stateful firewall...'

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
    abort ERROR 'Failed to add NFT table rules.'

  mv /etc/nftables.conf /etc/nftables.conf.bak &&
    nft -s list ruleset > /etc/nftables.conf 2>&1 ||
    abort ERROR 'Failed to flush NFT tables rules.'

  log INFO 'Firewall ruleset has been flushed to /etc/nftables.conf.'

  # Save screen locker settings to the user config
  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || abort ERROR "Failed to create folder ${config_home}."

  local settings='{"screen_locker": {"interval": 12}}'

  local settings_file="${config_home}/security.json"

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to save screen locker interval to security settings.'
  
  log INFO 'Screen locker interval saved to the security settings.'
  log INFO 'Security configuration has been completed.'
}

# Installs and configures the boot loader.
setup_boot_loader () {
  log INFO 'Setting up the boot loader...'

  if is_property "${SETTINGS}" '.uefi_mode' 'yes'; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1 ||
      abort ERROR 'Failed to install grub boot loader on x86_64-efi.'
    
    log INFO 'Grub boot loader has been installed on x86_64-efi.'
  else
    local disk=''
    disk="$(get_property "${SETTINGS}" '.disk')" ||
      abort ERROR 'Unable to read disk setting.'

    grub-install --target=i386-pc "${disk}" 2>&1 ||
      abort ERROR 'Failed to install grub boot on i386-pc.'
    
    log INFO 'Grub boot loader has been installed on i386-pc.'
  fi

  log INFO 'Configuring the boot loader...'

  sed -ri 's/(GRUB_CMDLINE_LINUX_DEFAULT=".*)"/\1 consoleblank=300"/' /etc/default/grub &&
    sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub &&
    sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub &&
    sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub ||
    abort ERROR 'Failed to set boot loader properties.'

  grub-mkconfig -o /boot/grub/grub.cfg 2>&1 ||
    abort ERROR 'Failed to create the boot loader config file.'

  log INFO 'Boot loader config file created successfully.'

  if is_property "${SETTINGS}" '.uefi_mode' 'yes' && is_property "${SETTINGS}" '.vm_vendor' 'oracle'; then
    mkdir -p /boot/EFI/BOOT &&
      cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI ||
      abort ERROR 'Failed to copy the grubx64 efi file to BOOTX64.'
  fi

  log INFO 'Boot loader has been set up successfully.'
}

# Enables system services.
enable_services () {
  log INFO 'Enabling system services...'

  systemctl enable systemd-timesyncd.service 2>&1 ||
    abort ERROR 'Failed to enable timesyncd service.'

  log INFO 'Service timesyncd has been enabled.'

  systemctl enable NetworkManager.service 2>&1 ||
    abort ERROR 'Failed to enable network manager service.'

  log INFO 'Service network manager has been enabled.'

  systemctl enable bluetooth.service 2>&1 ||
    abort ERROR 'Failed to enable bluetooth service.'

  log INFO 'Service bluetooth has been enabled.'

  systemctl enable acpid.service 2>&1 ||
    abort ERROR 'Failed to enable acpid service.'

  log INFO 'Service acpid has been enabled.'

  systemctl enable cups.service 2>&1 ||
    abort ERROR 'Failed to enable cups service.'

  log INFO 'Service cups has been enabled.'

  systemctl enable sshd.service 2>&1 ||
    abort ERROR 'Failed to enable sshd service.'
  
  log INFO 'Service sshd has been enabled.'

  systemctl enable nftables.service 2>&1 ||
    abort ERROR 'Failed to enable nftables service.'
  
  log INFO 'Service nftables has been enabled.'

  systemctl enable reflector.timer 2>&1 ||
    abort ERROR 'Failed to enable reflector.timer service.'

  log INFO 'Service reflector.timer has been enabled.'

  systemctl enable paccache.timer 2>&1 ||
    abort ERROR 'Failed to enable paccache.timer service.'

  log INFO 'Service paccache.timer has been enabled.'

  if is_property "${SETTINGS}" '.trim_disk' 'yes'; then
    systemctl enable fstrim.timer 2>&1 ||
      abort ERROR 'Failed to enable fstrim.timer service.'
    
    log INFO 'Service fstrim.timer has been enabled.'
  fi

  if is_property "${SETTINGS}" '.vm' 'yes' && is_property "${SETTINGS}" '.vm_vendor' 'oracle'; then
    systemctl enable vboxservice.service 2>&1 ||
      abort ERROR 'Failed to enable virtual box service.'

    log INFO 'Service virtual box has been enabled.'
  fi
  
  local user_name=''
  user_name="$(get_property "${SETTINGS}" '.user_name')" ||
    abort ERROR 'Unable to read user_name setting.'
  
  local config_home="/home/${user_name}/.config"

  mkdir -p "${config_home}/systemd/user" ||
    abort ERROR 'Failed to create the user systemd folder.'

  cp /opt/stack/installer/services/init-pointer.service "${config_home}/systemd/user" ||
    abort ERROR 'Failed to set the init-pointer service.'

  log INFO 'Service init-pointer has been set.'

  cp /opt/stack/installer/services/init-tablets.service "${config_home}/systemd/user" ||
    abort ERROR 'Failed to set the init-tablets service.'

  log INFO 'Service init-tablets has been set.'

  cp /opt/stack/installer/services/fix-layout.service "${config_home}/systemd/user" ||
    abort ERROR 'Failed to set the fix-layout service.'
  
  log INFO 'Service fix-layout has been set.'

  chown -R ${user_name}:${user_name} "${config_home}/systemd" ||
    abort ERROR 'Failed to change user ownership to user systemd services.'
  
  sed -i "s/#USER/${user_name}/g" "${config_home}/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the user name in the fix-layout service file.'

  log INFO 'System services have been enabled.'
}

# Adds system rules for udev.
add_rules () {
  log INFO 'Adding system udev rules...'

  local rules_home='/etc/udev/rules.d'

  cp /opt/stack/installer/services/init-pointer.rules "${rules_home}/90-init-pointer.rules" ||
    abort ERROR 'Failed to add the init-pointer rules.'

  log INFO 'Rules init-pointer have been added.'

  cp /opt/stack/installer/services/init-tablets.rules "${rules_home}/91-init-tablets.rules" ||
    abort ERROR 'Failed to add the init-tablets rules.'

  log INFO 'Rules init-tablets have been added.'

  cp /opt/stack/installer/services/fix-layout.rules "${rules_home}/92-fix-layout.rules" ||
    abort ERROR 'Failed to add the fix-layout rules.'
  
  log INFO 'Rules fix-layout have been set.'
  log INFO 'System udev rules have been added.'
}

log INFO 'Script system.sh started.'
log INFO 'Installing the system...'

if not_equals "$(id -u)" 0; then
  abort ERROR 'Script system.sh must be run as root user.'
fi

set_host &&
  set_users &&
  set_mirrors &&
  configure_pacman &&
  sync_package_databases &&
  install_base_packages &&
  install_display_server &&
  install_drivers &&
  install_system_tools &&
  install_aur_package_manager &&
  set_locales &&
  set_keyboard &&
  set_timezone &&
  boost_performance &&
  configure_power &&
  configure_security &&
  setup_boot_loader &&
  enable_services &&
  add_rules

log INFO 'Script system.sh has finished.'

resolve system 2060 && sleep 2
