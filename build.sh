#!/bin/bash

set -Eeo pipefail

DIST_DIR=.dist
WORK_DIR="${DIST_DIR}/work"
AUR_DIR="${DIST_DIR}/aur"
PROFILE_DIR="${DIST_DIR}/profile"
ROOT_FS="${PROFILE_DIR}/airootfs"

# Prints the given log message prefixed with the given log level.
# No arguments means nothing to log on to the console.
# Arguments:
#  level:   optionally one of INFO, WARN, ERROR
#  message: an optional message to show
# Outputs:
#  Prints the message in [<level>] <message> form.
log () {
  local level message

  if [[ $# -ge 2 ]]; then
    level="${1}"
    message="${2}"
  elif [[ $# -eq 1 ]]; then
    message="${1}"
  else
    return 0
  fi

  if [[ -n "${level}" ]] || [[ "${level}" != '' ]]; then
    printf '%-5s %b\n' "${level}" "${message}"
  else
    printf '%b\n' "${message}"
  fi
}

# Aborts the current process logging the given error message.
# Arguments:
#  level:   optionally one of INFO, WARN, ERROR
#  message: an error message to print
# Outputs:
#  An error messsage.
abort () {
  local level="${1}"
  local message="${2}"

  log "${level}" "${message}"
  log "${level}" 'Build process has exited.'

  exit 1
}

# Checks if the dep with the given name is installed or not.
# Arguments:
#  name: the name of a dependency
# Returns:
#  0 if dep is installed otherwise 1.
dep_exists () {
  local name="${1}"

  if pacman -Qi "${name}" > /dev/null 2>&1; then
    return 0
  fi

  return 1
}

# An inversed alias of dep_exists.
dep_not_exists () {
  dep_exists "${1}" && return 1 || return 0
}

# Adds the package with the given name into the list of packages
# Arguments:
#  name: the name of a package
add_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if [[ ! -f "${pkgs_file}" ]]; then
    abort ERROR "Unable to locate file ${pkgs_file}."
  fi

  if ! grep -Eq "^${name}$" "${pkgs_file}"; then
    echo "${name}" >> "${pkgs_file}"
  else
    log WARN "Package ${name} already added."
  fi
}

# Removes the package with the given name from the list of packages
# Arguments:
#  name: the name of a package
remove_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if [[ ! -f "${pkgs_file}" ]]; then
    abort ERROR "Unable to locate file ${pkgs_file}."
  fi

  if ! grep -Eq "^${name}$" "${pkgs_file}"; then
    abort ERROR "Unable to remove the package ${name}."
  fi

  sed -Ei "/^${name}$/d" "${pkgs_file}" ||
    abort ERROR "Unable to remove the package ${name}."

  log INFO "Package ${name} has removed."
}

# Initializes build and distribution files.
init () {
  if [[ -d "${DIST_DIR}" ]]; then
    rm -rf "${DIST_DIR}" || abort ERROR 'Unable to remove the .dist folder.'

    log WARN 'Existing .dist folder has been removed.'
  fi

  mkdir -p "${DIST_DIR}" || abort ERROR 'Unable to create the .dist folder.'

  log INFO 'A clean .dist folder has been created.'
}

# Checks if any build dependency is missing and abort immediately.
check_depds () {
  local deps=(archiso)

  local dep=''
  for dep in "${deps[@]}"; do
    if dep_not_exists "${dep}"; then
      abort ERROR "Missing ${dep} package dependency."
    fi
  done
}

# Copies the archiso custom profile.
copy_profile () {
  log INFO 'Copying the custom archiso profile...'

  local releng_path="/usr/share/archiso/configs/releng"

  if [[ ! -d "${releng_path}" ]]; then
    abort ERROR 'Unable to locate releng archiso profile.'
  fi

  cp -r "${releng_path}" "${PROFILE_DIR}" ||
    abort ERROR 'Unable to copy the releng archiso profile.'

  log INFO "The releng profile copied to ${PROFILE_DIR}."
}

# Sets the distribution names and os release meta files.
rename_distro () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  printf '%s\n' \
    'NAME="Stack Linux"' \
    'PRETTY_NAME="Stack Linux"' \
    'ID=stack' \
    'ID_LIKE=arch' \
    'IMAGE_ID=stack' \
    "IMAGE_VERSION=$(date +%Y.%m.%d)" \
    'BUILD_ID=rolling' \
    'ANSI_COLOR="38;2;23;147;209"' \
    'HOME_URL="https://github.com/tzeikob/stack.git/"' \
    'DOCUMENTATION_URL="https://github.com/tzeikob/stack.git/"' \
    'SUPPORT_URL="https://github.com/tzeikob/stack.git/"' \
    'BUG_REPORT_URL="https://github.com/tzeikob/stack/issues"' \
    'PRIVACY_POLICY_URL="https://github.com/tzeikob/stack/blob/master/LICENSE"' \
    'LOGO=stack-logo' > "${ROOT_FS}/etc/stack-release" ||
    abort ERROR 'Failed to create the release metadata file.'

  log INFO 'Release metadata file created to /etc/stack-release.'

  mkdir -p "${ROOT_FS}/etc/pacman.d/scripts" ||
    abort ERROR 'Failed to create pacman scripts folder.'

  local fix_release="${ROOT_FS}/etc/pacman.d/scripts/fix-release"

  printf '%s\n' \
    '#!/bin/bash' \
    '' \
    'rm -f /etc/arch-release' \
    'cat /etc/stack-release > /usr/lib/os-release' \
    '[[ -f /etc/lsb-release ]] &&' \
    '  echo "DISTRIB_ID=\"Stack\"" > /etc/lsb-release &&' \
    '  echo "DISTRIB_RELEASE=\"rolling\"" >>  /etc/lsb-release &&' \
    '  echo "DISTRIB_DESCRIPTION=\"Stack Linux\"" >> /etc/lsb-release' >> "${fix_release}" ||
    abort ERROR 'Failed to create the fix-release script file.'
  
  local fix_release_hook="${ROOT_FS}/etc/pacman.d/hooks/90-fix-release.hook"

  printf '%s\n' \
    '[Trigger]' \
    'Type = Package' \
    'Operation = Install' \
    'Operation = Upgrade' \
    'Target = lsb-release' \
    '' \
    '[Action]' \
    'Description = Fix os release data and meta files' \
    'When = PostTransaction' \
    'Exec = /bin/bash /etc/pacman.d/scripts/fix-release' >> "${fix_release_hook}" ||
    abort ERROR 'Failed to create the fix-release hook file.'
  
  log INFO 'Fix release hook has been created.'

  echo -e 'stackiso' > "${ROOT_FS}/etc/hostname"

  log INFO 'Host name set to stackiso.'

  if [[ ! -d "${PROFILE_DIR}" ]]; then
    abort ERROR 'Unable to locate the releng profile folder.'
  fi

  local profile_def="${PROFILE_DIR}/profiledef.sh"

  sed -i 's|^\(iso_name=\).*|\1\"stacklinux\"|' "${profile_def}" &&
    sed -i 's|^\(iso_label="\)ARCH_\(.*\)|\1STACK_\2|' "${profile_def}" &&
    sed -i 's|^\(iso_publisher=\).*|\1\"Stack Linux <https://github.com/tzeikob/stack.git>\"|' "${profile_def}" &&
    sed -i 's|^\(iso_application=\).*|\1\"Stack Linux Live Media\"|' "${profile_def}" &&
    sed -i 's|^\(install_dir=\).*|\1\"stack\"|' "${profile_def}" ||
    abort ERROR 'Failed to update release info in the profile definition file.'

  log INFO 'Release info updated in profile definition file.'
}

# Sets up the bios and uefi boot loaders.
setup_boot_loaders () {
  if [[ ! -d "${PROFILE_DIR}" ]]; then
    abort ERROR 'Unable to locate the releng profile folder.'
  fi

  rm -rf "${PROFILE_DIR}/efiboot" || abort ERROR 'Failed to remove EFI boot loader.'

  log INFO 'EFI boot loader has been removed.'

  rm -f "${PROFILE_DIR}/syslinux/archiso_pxe.cfg" \
    "${PROFILE_DIR}/syslinux/archiso_pxe-linux.cfg" ||
    abort ERROR 'Failed to remove PXE syslinux config files.'

  local syslinux_cfg="${PROFILE_DIR}/syslinux/syslinux.cfg"
  
  sed -i 's/APPEND -pxe- pxe -sys- sys -iso- sys/APPEND -sys- sys -iso- sys/' "${syslinux_cfg}" &&
    sed -i '/LABEL pxe/,+3d' "${syslinux_cfg}" ||
    abort ERROR 'Failed to remove PXE bios modes from syslinux.'

  log INFO 'PXE bios modes have been removed from syslinux.'

  sed -i 's/Arch/Stack/' "${PROFILE_DIR}/syslinux/archiso_sys-linux.cfg" &&
    sed -i '/# Accessibility boot option/,$d' "${PROFILE_DIR}/syslinux/archiso_sys-linux.cfg" &&
    sed -i '/TEXT HELP/,/ENDTEXT/d' "${PROFILE_DIR}/syslinux/archiso_sys-linux.cfg" &&
    sed -i '/LABEL existing/,+9d' "${PROFILE_DIR}/syslinux/archiso_tail.cfg" &&
    sed -i '/TEXT HELP/,/ENDTEXT/d' "${PROFILE_DIR}/syslinux/archiso_tail.cfg" ||
    abort ERROR 'Failed to fix texts and titles in syslinux menu.'
  
  rm -rf "${PROFILE_DIR}/syslinux/splash.png" ||
    abort ERROR 'Failed to remove the splash screen file.'

  printf '%s\n' \
    'SERIAL 0 115200' \
    'UI vesamenu.c32' \
    'MENU TITLE Stack Linux Live Media' \
    'MENU BACKGROUND #ff000000' \
    'MENU WIDTH 78' \
    'MENU MARGIN 4' \
    'MENU ROWS 6' \
    'MENU VSHIFT 6' \
    'MENU TABMSGROW 14' \
    'MENU CMDLINEROW 14' \
    'MENU HELPMSGROW 16' \
    'MENU HELPMSGENDROW 29' \
    'MENU COLOR border       0     #ffffffff #00000000 none' \
    'MENU COLOR title        37;40 #ffffffff #00000000 none' \
    'MENU COLOR sel          37;40 #ff000000 #ffffffff none' \
    'MENU COLOR unsel        37;40 #ffffffff #00000000 none' \
    'MENU COLOR help         37;40 #ffffffff #00000000 none' \
    'MENU COLOR timeout_msg  37;40 #ffffffff #00000000 none' \
    'MENU COLOR timeout      37;40 #ffffffff #00000000 none' \
    'MENU COLOR msg07        37;40 #ffffffff #00000000 none' \
    'MENU COLOR tabmsg       37;40 #ffffffff #00000000 none' \
    'MENU CLEAR' \
    'MENU IMMEDIATE' > "${PROFILE_DIR}/syslinux/archiso_head.cfg" ||
    abort ERROR 'Failed to fix styles and colors in syslinux menus.'

  log INFO 'Syslinux boot loader menus have been modified.'

  local grub_cfg="${PROFILE_DIR}/grub/grub.cfg"

  sed -i "/--id 'archlinux-accessibility'/,+5d" "${grub_cfg}" &&
    sed -i 's/archlinux/stacklinux/' "${grub_cfg}" &&
    sed -i 's/Arch Linux/Stack Linux/' "${grub_cfg}" ||
    abort ERROR 'Failed to fix text and titles in grub menus.'
  
  local loopback_cfg="${PROFILE_DIR}/grub/loopback.cfg"

  sed -i "/--id 'archlinux-accessibility'/,+5d" "${loopback_cfg}" &&
    sed -i 's/archlinux/stacklinux/' "${loopback_cfg}" &&
    sed -i 's/Arch Linux/Stack Linux/' "${loopback_cfg}" ||
    abort ERROR 'Failed to fix text and titles in loopback grub menus.'

  log INFO 'Grub boot loader menus have been modified.'

  sed -i '/if serial --unit=0 --speed=115200; then/,+3d' "${grub_cfg}" ||
    abort ERROR 'Failed to disable the serial console in grub.'

  log INFO 'Grub boot loader serial console disabled.'
}

# Adds the pakacge dependencies into the list of packages.
add_packages () {
  log INFO 'Adding system and desktop packages...'

  local pkgs=()

  # Add the base and system packages
  pkgs+=(
    reflector rsync sudo
    base-devel pacman-contrib pkgstats grub mtools dosfstools ntfs-3g exfatprogs gdisk fuseiso veracrypt
    python-pip parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion
    man-db man-pages texinfo cups cups-pdf cups-filters usbutils bluez bluez-utils unzip terminus-font
    vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh hsetroot
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils ipset xsel
    neofetch age imagemagick gpick fuse2 rclone smartmontools glib2 jq jc sequoia-sq xf86-input-wacom
    cairo bc xdotool python-tqdm libqalculate nftables iptables-nft virtualbox-guest-utils
  )
  
  # Add the display server and graphics packages
  pkgs+=(
    xorg xorg-xinit xorg-xrandr xorg-xdpyinfo xf86-video-qxl
  )

  # Add various hardware and driver packages
  pkgs+=(
    acpi acpi_call acpid tlp xcalib
    networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant
    nmap dhclient smbclient libnma alsa-utils xf86-input-synaptics
  )

  # Add the desktop prerequisite packages
  pkgs+=(
    picom bspwm sxhkd polybar rofi dunst
    trash-cli cool-retro-term helix firefox torbrowser-launcher
    irssi ttf-font-awesome noto-fonts-emoji
  )

  local pkg=''
  for pkg in "${pkgs[@]}"; do
    add_package "${pkg}"
  done

  # Remove conflicting no x server virtualbox utils
  remove_package virtualbox-guest-utils-nox

  log INFO 'All packages added into the package list.'
}

# Builds and adds the AUR packages into the packages list
# via a local custom repo.
add_aur_packages () {
  log INFO 'Building the AUR package files...'

  local previous_dir=${PWD}

  if [[ ! -d "${PROFILE_DIR}" ]]; then
    abort ERROR 'Unable to locate the releng profile folder.'
  fi

  local repo_home="${PROFILE_DIR}/local/repo"

  mkdir -p "${repo_home}" || abort ERROR 'Failed to create the local repo folder.'

  local names=(
    yay smenu xkblayout-state-git
  )

  local name=''
  for name in "${names[@]}"; do
    # Build the next AUR package
    git clone "https://aur.archlinux.org/${name}.git" "${AUR_DIR}/${name}" ||
      abort ERROR "Failed to clone the AUR ${name} package repo."
  
    cd "${AUR_DIR}/${name}"
    makepkg || abort ERROR "Failed to build the AUR ${name} package."
    cd ${previous_dir}

    # Create the custom local repo database
    cp ${AUR_DIR}/${name}/${name}-*-x86_64.pkg.tar.zst "${repo_home}" &&
      repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/${name}-*-x86_64.pkg.tar.zst ||
      abort ERROR "Failed to add the ${name} package into the custom repository."

    add_package "${name}" || abort ERROR "Failed to add the ${name} AUR package into the package list."
  done

  rm -rf "${AUR_DIR}" || abort ERROR 'Failed to remove the AUR temporary folder.'

  log INFO 'The AUR package files have been built.'

  local pacman_conf="${PROFILE_DIR}/pacman.conf"

  if [[ ! -f "${pacman_conf}" ]]; then
    abort ERROR "Unable to locate file ${pacman_conf}."
  fi

  printf '%s\n' \
    '' \
    '[custom]' \
    'SigLevel = Optional TrustAll' \
    "Server = file://$(realpath "${repo_home}")" >> "${pacman_conf}" ||
    abort ERROR 'Failed to define the custom local repo.'

  log INFO 'The custom local repo added to pacman.'
  log INFO 'All AUR packages added into the package list.'
}

# Patch various packages.
patch_packages () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  # Override tqdm executable in /usr/bin to swallow error output
  mkdir -p "${ROOT_FS}/usr/local/bin" ||
    abort ERROR 'Failed to create the /usr/local/bin folder.'

  printf '%s\n' \
    '#!/usr/bin/python' \
    '# -*- coding: utf-8 -*-' \
    'import re' \
    'import sys' \
    'from tqdm.cli import main' \
    'if __name__ == "__main__":' \
    '    try:' \
    '        sys.argv[0] = re.sub(r"(-script\.pyw|\.exe)?$", "", sys.argv[0])' \
    '        sys.exit(main())' \
    '    except KeyboardInterrupt:' \
    '        sys.exit(1)' > "${ROOT_FS}/usr/local/bin/tqdm" ||
    abort ERROR 'Failed to patch the tqdm package.'
  
  log INFO 'Package tqdm has been patched.'
}

# Copies the files of the installer.
copy_installer () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local installer_home="${ROOT_FS}/opt/stack"

  mkdir -p "${installer_home}" || abort ERROR 'Failed to create the /opt/stack folder.'

  cp -r configs "${installer_home}" &&
    cp -r resources "${installer_home}" &&
    cp -r rules "${installer_home}" &&
    cp -r scripts "${installer_home}" &&
    cp -r services "${installer_home}" &&
    cp -r tools "${installer_home}" &&
    cp install.sh "${installer_home}" ||
    abort ERROR 'Failed to copy the installer files.'

  # Create a global alias to launch the installer
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}" || abort ERROR 'Failed to create the /usr/local/bin folder.'

  ln -sf /opt/stack/install.sh "${bin_home}/install_os" ||
    abort ERROR 'Failed to create the symlink to the installer launcher.'

  info INFO 'Installer files have been copied.'
}

# Copies the files of the settings tools.
copy_settings_tools () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local tools_home="${ROOT_FS}/opt/tools"

  mkdir -p "${tools_home}" || abort ERROR 'Failed to create the /opt/tools folder.'

  # Copy settings tools needed to the live media only
  cp -r tools/displays "${tools_home}" &&
    cp -r tools/desktop "${tools_home}" &&
    cp -r tools/clock "${tools_home}" &&
    cp -r tools/networks "${tools_home}" &&
    cp -r tools/disks "${tools_home}" &&
    cp -r tools/bluetooth "${tools_home}" &&
    cp -r tools/langs "${tools_home}" &&
    cp -r tools/notifications "${tools_home}" &&
    cp -r tools/power "${tools_home}" &&
    cp -r tools/printers "${tools_home}" &&
    cp -r tools/trash "${tools_home}" &&
    cp tools/utils "${tools_home}" ||
    abort ERROR 'Failed to copy the settings tools files.'

  # Remove LC_CTYPE on smenu calls as live media doesn't need it
  sed -i 's/\(.*\)LC_CTYPE=.* \(smenu .*\)/\1\2/' "${tools_home}/utils" ||
    abort ERROR 'Failed to remove the LC_TYPE from the smenu calls.'

  # Disable init scratchpad command for the live media
  local desktop_main="${tools_home}/desktop/main"

  sed -i "/.*scratchpad.*/d" "${desktop_main}" ||
    abort ERROR 'Failed to remove the scratchpad lines from the desktop main.'

  # Create global aliases for each setting tool main entry
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}" || abort ERROR 'Failed to create the /usr/local/bin folder.'

  ln -sf /opt/tools/displays/main "${bin_home}/displays" &&
    ln -sf /opt/tools/desktop/main "${bin_home}/desktop" &&
    ln -sf /opt/tools/clock/main "${bin_home}/clock" &&
    ln -sf /opt/tools/networks/main "${bin_home}/networks" &&
    ln -sf /opt/tools/disks/main "${bin_home}/disks" &&
    ln -sf /opt/tools/bluetooth/main "${bin_home}/bluetooth" &&
    ln -sf /opt/tools/langs/main "${bin_home}/langs" &&
    ln -sf /opt/tools/notifications/main "${bin_home}/notifications" &&
    ln -sf /opt/tools/power/main "${bin_home}/power" &&
    ln -sf /opt/tools/printers/main "${bin_home}/printers" &&
    ln -sf /opt/tools/trash/main "${bin_home}/trash" ||
    abort ERROR 'Failed to create symlinks for each settings tool main.'

  log INFO 'Settings tools have been copied.'
}

# Sets to skip login prompt and auto login the root user.
setup_auto_login () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort 'Unable to locate the airootfs folder.'
  fi

  local auto_login="${ROOT_FS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"

  local exec_start="ExecStart=-/sbin/agetty -o '-p -f -- \\\\\\\u' --noissue --noclear --skip-login --autologin root - \$TERM"

  sed -i "s;^ExecStart=-/sbin/agetty.*;${exec_start};" "${auto_login}" ||
    abort ERROR 'Failed to set skip on login prompt.'

  log INFO 'Login prompt set to skip and autologin.'

  # Remove the default welcome message
  rm -rf "${ROOT_FS}/etc/motd" || abort ERROR 'Failed to remove the /etc/motd file.'

  # Create the welcome message to be shown after login
  local welcome=''
  welcome+='░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░\n'
  welcome+='░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░\n'
  welcome+='░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░\n\n'
  welcome+='Welcome to live media of \u001b[36mStack Linux\u001b[0m, more information\n'
  welcome+='can be found on https://github.com/tzeikob/stack.git.\n\n'
  welcome+='Connect to a wireless network using the networks tool via\n'
  welcome+='the command \u001b[36mnetworks add wifi <device> <ssid> <secret>\u001b[0m.\n'
  welcome+='Ethernet, WALN and WWAN networks should work automatically.\n\n'
  welcome+='To install a new system run \u001b[36minstall_os\u001b[0m to launch\n'
  welcome+='the installation process of the Stack Linux.\n'

  echo -e "${welcome}" > "${ROOT_FS}/etc/welcome"

  log INFO 'Welcome message has been set to /etc/welcome.'
}

# Sets up the display server configuration and hooks.
setup_display_server () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local xinitrc_file="${ROOT_FS}/root/.xinitrc"

  cp configs/xorg/xinitrc "${xinitrc_file}" ||
    abort ERROR 'Failed to copy the .xinitrc file.'

  # Keep functionality relatated to live media only
  sed -i '/system -qs check updates &/d' "${xinitrc_file}" &&
    sed -i '/displays -qs restore layout/d' "${xinitrc_file}" &&
    sed -i '/displays -qs restore colors &/d' "${xinitrc_file}" &&
    sed -i '/security -qs init locker &/d' "${xinitrc_file}" &&
    sed -i '/cloud -qs mount remotes &/d' "${xinitrc_file}" ||
    abort ERROR 'Failed to remove unsupported calls from the .xinitrc file.'

  log INFO 'The .xinitrc file copied to /root/.xinitrc.'

  mkdir -p "${ROOT_FS}/etc/X11" &&
    cp configs/xorg/xorg.conf "${ROOT_FS}/etc/X11" ||
    abort ERROR 'Failed to copy the xorg.conf file.'

  log INFO 'The xorg.conf file copied to /etc/X11/xorg.conf.'

  local zlogin_file="${ROOT_FS}/root/.zlogin"

  if [[ ! -f "${zlogin_file}" ]]; then
    abort ERROR "Unable to locate file ${zlogin_file}."
  fi

  printf '%s\n' \
    '' \
    "echo -e 'Starting desktop environment...'" \
    'startx' >> "${zlogin_file}" || abort ERROR 'Failed to add startx hook to .zlogin file.'

  log INFO 'Xorg server set to be started after login.'
}

# Sets up the keyboard settings.
setup_keyboard () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  echo 'KEYMAP=us' > "${ROOT_FS}/etc/vconsole.conf" ||
    abort ERROR 'Failed to set keyboard map to us.'

  log INFO 'Keyboard map keys has been set to us.'

  mkdir -p "${ROOT_FS}/etc/X11/xorg.conf.d" ||
    abort ERROR 'Failed to create the /etx/X11/xorg.conf.d folder.'

  printf '%s\n' \
   'Section "InputClass"' \
   '  Identifier "system-keyboard"' \
   '  MatchIsKeyboard "on"' \
   '  Option "XkbLayout" "us"' \
   '  Option "XkbModel" "pc105"' \
   '  Option "XkbOptions" "grp:alt_shift_toggle"' \
   'EndSection' > "${ROOT_FS}/etc/X11/xorg.conf.d/00-keyboard.conf" ||
   abort ERROR 'Failed to set xorg keyboard settings.'

  log INFO 'Xorg keyboard settings have been set.'

  # Save keyboard settings to the user langs json file
  local config_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${config_home}" || abort ERROR 'Failed to create the /root/.config/stack folder.'

  printf '%s\n' \
    '{' \
    '  "keymap": "us",' \
    '  "model": "pc105",' \
    '  "options": "grp:alt_shift_toggle",' \
    '  "layouts": [{"code": "us", "variant": "default"}]' \
    '}' > "${config_home}/langs.json" ||
    abort ERROR 'Failed to create the langs settings file.'
  
  log INFO 'Keyboard langs settings have been set.'
}

# Sets up various system power settings.
setup_power () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  rm -rf "${ROOT_FS}/etc/systemd/logind.conf.d" &&
    mkdir -p "${ROOT_FS}/etc/systemd/logind.conf.d" ||
    abort ERROR 'Failed to create the /etc/systemd/logind.conf.d folder.'
  
  local logind_conf="${ROOT_FS}/etc/systemd/logind.conf.d/00-main.conf"

  printf '%s\n' \
    '[Login]' \
    'HandleHibernateKey=ignore' \
    'HandleHibernateKeyLongPress=ignore' \
    'HibernateKeyIgnoreInhibited=no' \
    'HandlePowerKey=suspend' \
    'HandleRebootKey=reboot' \
    'HandleSuspendKey=suspend' \
    'HandleLidSwitch=suspend' \
    'HandleLidSwitchDocked=ignore' > "${logind_conf}" ||
    abort ERROR 'Failed to set the logind action handlers.'

  log INFO 'Logind action handlers have been set.'

  rm -rf "${ROOT_FS}/etc/systemd/sleep.conf.d" &&
    mkdir -p "${ROOT_FS}/etc/systemd/sleep.conf.d" ||
    abort ERROR 'Failed to create the /etc/systemd/sleep.conf.d folder.'
  
  local sleep_conf="${ROOT_FS}/etc/systemd/sleep.conf.d/00-main.conf"

  printf '%s\n' \
    '[Sleep]' \
    'AllowSuspend=yes' \
    'AllowHibernation=no' \
    'AllowSuspendThenHibernate=no' \
    'AllowHybridSleep=no' > "${sleep_conf}" ||
    abort ERROR 'Failed to set the sleep action handlers.'

  log INFO 'Sleep action handlers have been set.'

  mkdir -p "${ROOT_FS}/etc/tlp.d" || abort ERROR 'Failed to create the /etc/tlp.d folder.'

  local tlp_conf="${ROOT_FS}/etc/tlp.d/00-main.conf"

  printf '%s' \
    'SOUND_POWER_SAVE_ON_AC=0' \
    'SOUND_POWER_SAVE_ON_BAT=0' > "${tlp_conf}" ||
    abort ERROR 'Failed to set the battery action handlers.'

  log INFO 'Battery action handlers have been set.'

  local config_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${config_home}" || abort ERROR 'Failed to create the /root/.config/stack folder.'

  printf '%s\n' \
  '{' \
  '  "screensaver": {"interval": 15}' \
  '}' > "${config_home}/power.json" ||
  abort ERROR 'Failed to create the power settings file.'

  log INFO 'Screensaver interval setting has been set.'
}

# Sets up the sheel environment files.
setup_shell_environment () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local zshrc_file="${ROOT_FS}/root/.zshrc"

  # Set the defauilt terminal and text editor
  echo -e 'export TERMINAL=cool-retro-term' >> "${zshrc_file}"

  log INFO 'Default terminal set to cool-retro-term.'

  echo -e 'export EDITOR=helix' >> "${zshrc_file}"

  log INFO 'Default editor set to helix.'

  # Set up trash-cli aliases
  echo -e "\nalias sudo='sudo '" >> "${zshrc_file}"
  echo "alias tt='trash-put -i'" >> "${zshrc_file}"
  echo "alias rm='rm -i'" >> "${zshrc_file}"

  log INFO 'Command aliases added to /root/.zshrc.'

  printf '%s\n' \
    '' \
    'if [[ "${SHOW_WELCOME_MSG}" == "true" ]]; then' \
    '  cat /etc/welcome' \
    'fi' >> "${zshrc_file}" || abort ERROR 'Failed to add the welcome message hook call.'

  log INFO 'Welcome message set to be shown after login.'
}

# Sets up the corresponding configurations for
# each desktop module.
setup_desktop () {
  log INFO 'Setting up the desktop configurations...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local config_home="${ROOT_FS}/root/.config"

  # Copy the picom configuration files
  local picom_home="${config_home}/picom"

  mkdir -p "${picom_home}" &&
    cp configs/picom/picom.conf "${picom_home}" ||
    abort ERROR 'Failed to copy the picom config file.'

  log INFO 'Picom configuration has been set.'

  # Copy windows manager configuration files
  local bspwm_home="${config_home}/bspwm"

  mkdir -p "${bspwm_home}" &&
    cp configs/bspwm/bspwmrc "${bspwm_home}" &&
    cp configs/bspwm/resize "${bspwm_home}" &&
    cp configs/bspwm/rules "${bspwm_home}" &&
    cp configs/bspwm/swap "${bspwm_home}" ||
    abort ERROR 'Failed to copy the bspwm files.'

  # Remove init scratchpad initializer from the bspwmrc
  sed -i '/desktop -qs init scratchpad &/d' "${bspwm_home}/bspwmrc" &&
    sed -i '/bspc rule -a scratch sticky=off state=floating hidden=on/d' "${bspwm_home}/bspwmrc" ||
    abort ERROR 'Failed to remove the scratchpad lines from the .bspwmrc file.'

  # Add a hook to open the welcome terminal once at login
  printf '%s\n' \
    '[ "$@" -eq 0 ] && {' \
    '  SHOW_WELCOME_MSG=true cool-retro-term &' \
    '}' >> "${bspwm_home}/bspwmrc" ||
    abort ERROR 'Failed to add the welcome message hook to the .bspwmrc file.'

  log INFO 'Bspwm configuration has been set.'

  # Copy polybar configuration files
  local polybar_home="${config_home}/polybar"

  mkdir -p "${polybar_home}" &&
    cp configs/polybar/config.ini "${polybar_home}" &&
    cp configs/polybar/modules.ini "${polybar_home}" &&
    cp configs/polybar/theme.ini "${polybar_home}" ||
    abort ERROR 'Failed to copy the polybar files.'

  local config_ini="${polybar_home}/config.ini"

  # Remove modules not needed by the live media
  sed -i "s/\(modules-right = \)cpu.*/\1 alsa-audio date time/" "${config_ini}" &&
    sed -i "s/\(modules-right = \)notifications.*/\1 flash-drives keyboard/" "${config_ini}" &&
    sed -i "s/\(modules-left = \)wlan.*/\1 wlan eth/" "${config_ini}" ||
    abort ERROR 'Failed to remove not supported polybar bars.'

  # Keep only scripts needed by the live media
  mkdir -p "${polybar_home}/scripts" &&
    cp -r configs/polybar/scripts/flash-drives "${polybar_home}/scripts" &&
    cp -r configs/polybar/scripts/time "${polybar_home}/scripts" ||
    abort ERROR 'Failed to copy the polybar scripts.'

  log INFO 'Polybar configuration has been set.'

  # Copy sxhkd configuration files
  local sxhkd_home="${config_home}/sxhkd"

  mkdir -p "${sxhkd_home}" &&
    cp configs/sxhkd/sxhkdrc "${sxhkd_home}" ||
    abort ERROR 'Failed to copy the sxhkd config file.'

  local sxhkdrc_file="${sxhkd_home}/sxhkdrc"

  # Remove key bindings not needed by the live media
  sed -i '/# Lock the screen./,+3d' "${sxhkdrc_file}" &&
    sed -i '/# Take a screen shot./,+3d' "${sxhkdrc_file}" &&
    sed -i '/# Start recording your screen./,+3d' "${sxhkdrc_file}" &&
    sed -i '/# Show and hide the scratchpad termimal./,+3d' "${sxhkdrc_file}" ||
    abort ERROR 'Failed to remove not supported key bindings.'

  log INFO 'Sxhkd configuration has been set.'

  # Copy rofi configuration files
  local rofi_home="${config_home}/rofi"

  mkdir -p "${rofi_home}" &&
    cp configs/rofi/config.rasi "${rofi_home}" &&
    cp configs/rofi/launch "${rofi_home}" ||
    abort ERROR 'Failed to copy the rofi files.'

  local launch_file="${rofi_home}/launch"

  sed -i "/options+='Lock\\\n'/d" "${launch_file}" &&
    sed -i "/options+='Blank\\\n'/d" "${launch_file}" &&
    sed -i "/options+='Logout'/d" "${launch_file}" &&
    sed -i "s/\(  local exact_lines='listview {lines:\) 6\(;}'\)/\1 3\2/" "${launch_file}" &&
    sed -i "/'Lock') security -qs lock screen;;/d" "${launch_file}" &&
    sed -i "/'Blank') power -qs blank;;/d" "${launch_file}" &&
    sed -i "/'Logout') security -qs logout user;;/d" "${launch_file}" ||
    abort ERROR 'Failed to remove not supported cmds from rofi launch menu.'

  log INFO 'Rofi configuration has been set.'

  # Copy dunst configuration files
  local dunst_home="${config_home}/dunst"

  mkdir -p "${dunst_home}" &&
    cp configs/dunst/dunstrc "${dunst_home}" &&
    cp configs/dunst/hook "${dunst_home}" ||
    abort ERROR 'Failed to copy the dunst files.'

  log INFO 'Dunst configuration has been set.'
}

# Sets up the theme of the desktop environment.
setup_theme () {
  log INFO 'Setting up the desktop theme...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local themes_home="${ROOT_FS}/usr/share/themes"

  mkdir -p "${themes_home}" || abort ERROR 'Failed to create the themes folder.'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip" &&
    unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}" &&
    mv "${themes_home}/gtk-master" "${themes_home}/Dracula" &&
    rm -f "${themes_home}/Dracula.zip" ||
    abort ERROR 'Failed to install the desktop theme.'

  log INFO 'Desktop theme has been installed.'

  log INFO 'Setting up the desktop icons...'

  local icons_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${icons_home}" || abort ERROR 'Failed to create the icons folder.'
  
  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip" &&
    unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}" &&
    rm -f "${icons_home}/Dracula.zip" ||
    abort ERROR 'Failed to install the desktop icons.'

  log INFO 'Desktop icons have been installed.'

  log INFO 'Setting up the desktop cursors...'

  local cursors_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${cursors_home}" || abort ERROR 'Failed to create the cursors folder.'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  wget "${cursors_url}" -qO "${cursors_home}/breeze-snow.tgz" &&
    tar -xzf "${cursors_home}/breeze-snow.tgz" -C "${cursors_home}" &&
    rm -f "${cursors_home}/breeze-snow.tgz" ||
    abort ERROR 'Failed to install the desktop cursors.'

  mkdir -p "${cursors_home}/default" || abort ERROR 'Failed to create the cursors default folder.'

  echo '[Icon Theme]' >> "${cursors_home}/default/index.theme"
  echo 'Inherits=Breeze-Snow' >> "${cursors_home}/default/index.theme"

  log INFO 'Desktop cursors have been installed.'

  local gtk_home="${ROOT_FS}/root/.config/gtk-3.0"
  
  mkdir -p "${gtk_home}" &&
    cp configs/gtk/settings.ini "${gtk_home}" ||
    abort ERROR 'Failed to set the GTK settings.'

  log INFO 'Gtk settings file has been set.'

  log INFO 'Setting the desktop wallpaper...'

  local wallpapers_home="${ROOT_FS}/root/.local/share/wallpapers"

  mkdir -p "${wallpapers_home}" &&
    cp resources/wallpapers/* "${wallpapers_home}" ||
    abort ERROR 'Failed to copy the wallpapers.'

  local settings_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${settings_home}" || abort ERROR 'Failed to create the /root/.config/stack folder.'

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${settings_home}/desktop.json"

  log INFO 'Desktop wallpaper has been set.'
}

# Sets up some extra system fonts.
setup_fonts () {
  log INFO 'Setting up extra system fonts...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local fonts_home="${ROOT_FS}/usr/share/fonts/extra-fonts"

  mkdir -p "${fonts_home}" || abort ERROR 'Failed to create the fonts folder.'

  local fonts=(
    "FiraCode https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
    "JetBrainsMono https://github.com/JetBrains/JetBrainsMono/releases/download/v2.242/JetBrainsMono-2.242.zip"
    "Mononoki https://github.com/madmalik/mononoki/releases/download/1.3/mononoki.zip"
    "VictorMono https://rubjo.github.io/victor-mono/VictorMonoAll.zip"
    "PixelMix https://dl.dafont.com/dl/?f=pixelmix"
  )

  local font=''

  for font in "${fonts[@]}"; do
    local name=''
    name="$(echo "${font}" | cut -d ' ' -f 1)" || abort ERROR 'Failed to extract the font name.'

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" || abort ERROR 'Failed to extract the font url.'

    curl "${url}" -sSLo "${fonts_home}/${name}.zip" &&
      unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" &&
      chmod -R 755 "${fonts_home}/${name}" &&
      rm -f "${fonts_home}/${name}.zip" ||
      abort ERROR "Failed to install the font ${name}."

    log INFO "Font ${name} has been installed."
  done

  log INFO 'Fonts have been setup.'
}

# Sets up various system sound resources.
setup_sounds () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local sounds_home="${ROOT_FS}/usr/share/sounds/stack"
  
  mkdir -p "${sounds_home}" &&
    cp resources/sounds/normal.wav "${sounds_home}" &&
    cp resources/sounds/critical.wav "${sounds_home}" ||
    abort ERROR 'Failed to set the extra system sounds.'

  log INFO 'Extra system sounds have been set.'
}

# Enables various system services.
enable_services () {
  log INFO 'Enabling system services...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  mkdir -p "${ROOT_FS}/etc/systemd/system" || abort ERROR 'Failed to create the /etc/systemd/system folder.'

  ln -s /usr/lib/systemd/system/NetworkManager-dispatcher.service \
      "${ROOT_FS}/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service" &&
    mkdir -p "${ROOT_FS}/etc/systemd/system/multi-user.target.wants" &&
    ln -s /usr/lib/systemd/system/NetworkManager.service \
      "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/NetworkManager.service" &&
    mkdir -p "${ROOT_FS}/etc/systemd/system/network-online.target.wants" &&
    ln -s /usr/lib/systemd/system/NetworkManager-wait-online.service \
      "${ROOT_FS}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" ||
    abort ERROR 'Failed to enable the network manager services.'

  log INFO 'Network manager services enabled.'

  ln -s /usr/lib/systemd/system/bluetooth.service \
      "${ROOT_FS}/etc/systemd/system/dbus-org.bluez.service" &&
    mkdir -p "${ROOT_FS}/etc/systemd/system/bluetooth.target.wants" &&
    ln -s /usr/lib/systemd/system/bluetooth.service \
      "${ROOT_FS}/etc/systemd/system/bluetooth.target.wants/bluetooth.service" ||
    abort ERROR 'Failed to enable the bluetooth services.'

  log INFO 'Bluetooth services enabled.'

  ln -s /usr/lib/systemd/system/acpid.service \
      "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/acpid.service" ||
    abort ERROR 'Failed to enable th acpid servce.'

  log INFO 'Acpid service enabled.'

  mkdir -p "${ROOT_FS}/etc/systemd/system/printer.target.wants" &&
    ln -s /usr/lib/systemd/system/cups.service \
      "${ROOT_FS}/etc/systemd/system/printer.target.wants/cups.service" &&
    ln -s /usr/lib/systemd/system/cups.service \
      "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/cups.service" &&
    mkdir -p "${ROOT_FS}/etc/systemd/system/sockets.target.wants" &&
    ln -s /usr/lib/systemd/system/cups.socket \
      "${ROOT_FS}/etc/systemd/system/sockets.target.wants/cups.socket" &&
    ln -s /usr/lib/systemd/system/cups.path \
      "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/cups.path" ||
    abort ERROR 'Failed to enable the cups services.'

  log INFO 'Cups services enabled.'

  ln -s /usr/lib/systemd/system/nftables.service \
      "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/nftables.service" ||
    abort ERROR 'Failed to enable the nftables service.'

  log INFO 'Nftables service enabled.'

  mkdir -p "${ROOT_FS}/root/.config/systemd/user" &&
    cp services/init-pointer.service \
      "${ROOT_FS}/root/.config/systemd/user/init-pointer.service" ||
    abort ERROR 'Failed to enable the pointer init service.'

  log INFO 'Pointer init service enabled.'

  cp services/init-tablets.service \
      "${ROOT_FS}/root/.config/systemd/user/init-tablets.service" ||
    abort ERROR 'Failed to enable the tablets init service.'

  log INFO 'Tablets init service enabled.'

  cp services/fix-layout.service \
      "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" &&
    sed -i 's;^\(Environment=HOME\).*;\1=/root;' \
      "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" &&
    sed -i 's;^\(Environment=XAUTHORITY\).*;\1=/root/.Xauthority;' \
      "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to enable the fix layout service.'
  
  log INFO 'Fix layout service enabled.'
}

# Adds input and output devices rules.
add_device_rules () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local rules_home="${ROOT_FS}/etc/udev/rules.d"

  mkdir -p "${rules_home}" &&
    cp rules/90-init-pointer.rules "${rules_home}" &&
    cp rules/91-init-tablets.rules "${rules_home}" &&
    cp rules/92-fix-layout.rules "${rules_home}" ||
    abort ERROR 'Failed to set the device rules.'
  
  log INFO 'Device rules have been set.'
}

# Adds various extra sudoers rules.
add_sudoers_rules () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local proxy_rules='Defaults env_keep += "'
  proxy_rules+='http_proxy HTTP_PROXY '
  proxy_rules+='https_proxy HTTPS_PROXY '
  proxy_rules+='ftp_proxy FTP_PROXY '
  proxy_rules+='rsync_proxy RSYNC_PROXY '
  proxy_rules+='all_proxy ALL_PROXY '
  proxy_rules+='no_proxy NO_PROXY"'

  mkdir -p "${ROOT_FS}/etc/sudoers.d" || abort ERROR 'Failed to create the /etc/sudoers.d folder.'

  echo "${proxy_rules}" > "${ROOT_FS}/etc/sudoers.d/proxy_rules"

  log INFO 'Proxy rules have been added to sudoers.'
}

# Defines the root files permissions.
set_file_permissions () {
  local permissions_file="${PROFILE_DIR}/profiledef.sh"

  if [[ ! -f "${permissions_file}" ]]; then
    abort ERROR "Unable to locate file ${permissions_file}."
  fi

  local defs=(
    '0:0:750,/etc/sudoers.d/'
    '0:0:755,/etc/tlp.d/'
    '0:0:644,/etc/systemd/sleep.conf.d/'
    '0:0:644,/etc/systemd/logind.conf.d/'
    '0:0:644,/etc/welcome'
    '0:0:755,/etc/pacman.d/scripts/'
    '0:0:755,/opt/stack/configs/bspwm/'
    '0:0:755,/opt/stack/configs/dunst/hook'
    '0:0:755,/opt/stack/configs/nnn/env'
    '0:0:755,/opt/stack/configs/polybar/scripts/'
    '0:0:755,/opt/stack/configs/rofi/launch'
    '0:0:755,/opt/stack/configs/xsecurelock/hook'
    '0:0:755,/opt/stack/tools/'
    '0:0:755,/opt/stack/scripts/'
    '0:0:755,/opt/stack/install.sh'
    '0:0:755,/root/.config/bspwm/'
    '0:0:755,/root/.config/polybar/scripts/'
    '0:0:755,/root/.config/rofi/launch'
    '0:0:755,/root/.config/dunst/hook'
    '0:0:664,/root/.config/stack/'
    '0:0:755,/opt/tools/'
    '0:0:755,/usr/local/bin/tqdm'
  )

  local def=''
  for def in "${defs[@]}"; do
    local perms=''
    perms="$(echo "${def}" | cut -d ',' -f 1)" || abort ERROR 'Failed to extract the perms.'

    local path=''
    path="$(echo "${def}" | cut -d ',' -f 2)" || abort ERROR 'Failed to extract the path.'

    sed -i "/file_permissions=(/a [\"${path}\"]=\"${perms}\"" "${permissions_file}" ||
      abort ERROR "Failed to define the file permission ${perms}, ${path}."
  done

  log INFO 'File permissions have been defined.'
}

# Creates the iso file of the live media.
make_iso_file () {
  log INFO 'Building the archiso file...'

  if [[ ! -d "${PROFILE_DIR}" ]]; then
    abort ERROR 'Unable to locate the releng profile folder.'
  fi

  sudo mkarchiso -v -r -w "${WORK_DIR}" -o "${DIST_DIR}" "${PROFILE_DIR}" ||
    abort ERROR 'Failed to build the archiso file.'

  log INFO "Archiso file has been exported at ${DIST_DIR}."
  log INFO 'Build process completed successfully.'
}

log INFO 'Starting the build process...'

init &&
  check_depds &&
  copy_profile &&
  rename_distro &&
  setup_boot_loaders &&
  add_packages &&
  add_aur_packages &&
  patch_packages &&
  copy_installer &&
  copy_settings_tools &&
  setup_auto_login &&
  setup_display_server &&
  setup_keyboard &&
  setup_power &&
  setup_shell_environment &&
  setup_desktop &&
  setup_theme &&
  setup_fonts &&
  setup_sounds &&
  enable_services &&
  add_device_rules &&
  add_sudoers_rules &&
  set_file_permissions &&
  make_iso_file

