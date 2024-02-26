#!/bin/bash

DIST_DIR=.dist
WORK_DIR="${DIST_DIR}/work"
AUR_DIR="${DIST_DIR}/aur"
PROFILE_DIR="${DIST_DIR}/profile"
ROOT_FS="${PROFILE_DIR}/airootfs"

# Initializes build and distribution files.
init () {
  echo -e 'Starting the clean up process...'

  rm -rf "${DIST_DIR}"
  mkdir "${DIST_DIR}"

  echo -e 'Clean up has been completed'
}

# Copies the archiso custom profile.
copy_profile () {
  echo -e 'Copying the custom archiso profile...'

  cp -r /usr/share/archiso/configs/releng "${PROFILE_DIR}"

  echo -e "The releng profile copied to ${PROFILE_DIR}"
}

# Adds the package with the given name into the list of packages
# Arguments:
#  name: the name of a package
add_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if grep -Eq "${name}" "${pkgs_file}"; then
    echo -e "Skipping ${name}"
    return 0
  fi

  echo "${name}" >> "${pkgs_file}"
}

# Adds the pakacge dependencies into the list of packages.
add_packages () {
  echo -e 'Adding system and desktop packages...'

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
    cairo bc xdotool python-tqdm libqalculate
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

  echo -e 'All packages added into the package list'
}

# Builds and adds the AUR packages into the packages list
# via a local custom repo.
add_aur_packages () {
  echo -e 'Building the AUR package files...'

  local previous_dir=${PWD}

  local repo_home="${PROFILE_DIR}/local/repo"

  mkdir -p "${repo_home}"

  local names=(
    yay smenu xkblayout-state-git
  )

  local name=''
  for name in "${names[@]}"; do
    # Build the next AUR package
    git clone "https://aur.archlinux.org/${name}.git" "${AUR_DIR}/${name}"
  
    cd "${AUR_DIR}/${name}"
    makepkg
    cd ${previous_dir}

    # Create the custom local repo database
    cp ${AUR_DIR}/${name}/${name}-*-x86_64.pkg.tar.zst "${repo_home}"
    repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/${name}-*-x86_64.pkg.tar.zst

    add_package "${name}"
  done

  rm -rf "${AUR_DIR}"

  echo -e 'The AUR package files have been built'

  local pacman_conf="${PROFILE_DIR}/pacman.conf"

  echo -e '\n[custom]' >> "${pacman_conf}"
  echo -e 'SigLevel = Optional TrustAll' >> "${pacman_conf}"
  echo -e "Server = file://$(realpath "${repo_home}")" >> "${pacman_conf}"

  echo -e 'The custom local repo added to pacman'
  
  echo -e 'All AUR packages added into the package list'
}

# Copies the files of the installer.
copy_installer () {
  echo -e 'Copying the installer files...'

  local installer_home="${ROOT_FS}/opt/stack"

  mkdir -p "${installer_home}"

  cp -r configs "${installer_home}"
  cp -r resources "${installer_home}"
  cp -r rules "${installer_home}"
  cp -r scripts "${installer_home}"
  cp -r services "${installer_home}"
  cp -r tools "${installer_home}"
  cp install.sh "${installer_home}"

  # Create a global alias to launch the installer
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}"

  ln -sf /opt/stack/install.sh "${bin_home}/install_os"

  echo -e 'Installer files have been copied'
}

# Copies the files of the settings manager tools.
copy_settings_manager () {
  echo -e 'Copying the setting manager tools...'

  local tools_home="${ROOT_FS}/opt/tools"

  mkdir -p "${tools_home}"

  # Copy settings tools needed to the live media only
  cp -r tools/displays "${tools_home}"
  cp -r tools/desktop "${tools_home}"
  cp -r tools/clock "${tools_home}"
  cp -r tools/networks "${tools_home}"
  cp -r tools/disks "${tools_home}"
  cp -r tools/bluetooth "${tools_home}"
  cp -r tools/langs "${tools_home}"
  cp -r tools/notifications "${tools_home}"
  cp -r tools/power "${tools_home}"
  cp -r tools/printers "${tools_home}"
  cp -r tools/trash "${tools_home}"
  cp tools/utils "${tools_home}"

  # Remove LC_CTYPE on smenu calls as live media doesn't need it
  sed -i 's/\(.*\)LC_CTYPE=.* \(smenu .*\)/\1\2/' "${tools_home}/utils"

  # Disable init scratchpad command for the live media
  local desktop_main="${tools_home}/desktop/main"

  sed -i "/'init scratchpad' 'Initialize the sticky scratchpad terminal.'/d" "${desktop_main}"
  sed -i "/'init scratchpad') init_scratchpad;;/d" "${desktop_main}"

  # Create global aliases for each setting tool main entry
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}"

  ln -sf /opt/tools/displays/main "${bin_home}/displays"
  ln -sf /opt/tools/desktop/main "${bin_home}/desktop"
  ln -sf /opt/tools/clock/main "${bin_home}/clock"
  ln -sf /opt/tools/networks/main "${bin_home}/networks"
  ln -sf /opt/tools/disks/main "${bin_home}/disks"
  ln -sf /opt/tools/bluetooth/main "${bin_home}/bluetooth"
  ln -sf /opt/tools/langs/main "${bin_home}/langs"
  ln -sf /opt/tools/notifications/main "${bin_home}/notifications"
  ln -sf /opt/tools/power/main "${bin_home}/power"
  ln -sf /opt/tools/printers/main "${bin_home}/printers"
  ln -sf /opt/tools/trash/main "${bin_home}/trash"

  echo -e 'Settings manager tools have been copied'
}

# Sets up the display server configuration and hooks.
setup_display_server () {
  local xinitrc_file="${ROOT_FS}/root/.xinitrc"

  cp configs/xorg/xinitrc "${xinitrc_file}"

  # Keep functionality relatated to live media only
  sed -i '/system -qs/d' "${xinitrc_file}"
  sed -i '/displays -qs/d' "${xinitrc_file}"
  sed -i '/security -qs/d' "${xinitrc_file}"
  sed -i '/power -qs/d' "${xinitrc_file}"
  sed -i '/cloud -qs/d' "${xinitrc_file}"

  echo -e 'The .xinitrc file copied to /root/.xinitrc'

  mkdir -p "${ROOT_FS}/etc/X11"
  cp configs/xorg/xorg.conf "${ROOT_FS}/etc/X11"

  echo -e 'The xorg.conf file copied to /etc/X11/xorg.conf'
}

# Sets up the keyboard settings.
setup_keyboard () {
  echo -e 'Applying keyboard settings...'

  echo 'KEYMAP=us' > "${ROOT_FS}/etc/vconsole.conf"

  echo -e 'Keyboard map keys has been set to us'

  mkdir -p "${ROOT_FS}/etc/X11/xorg.conf.d"

  printf '%s\n' \
   'Section "InputClass"' \
   '  Identifier "system-keyboard"' \
   '  MatchIsKeyboard "on"' \
   '  Option "XkbLayout" "us"' \
   '  Option "XkbModel" "pc105"' \
   '  Option "XkbOptions" "grp:alt_shift_toggle"' \
   'EndSection' > "${ROOT_FS}/etc/X11/xorg.conf.d/00-keyboard.conf"

  echo -e 'Xorg keyboard settings have been set'

  # Save keyboard settings to the user langs json file
  local config_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${config_home}"

  printf '%s\n' \
    '{' \
    '  "keymap": "us",' \
    '  "model": "pc105",' \
    '  "options": "grp:alt_shift_toggle",' \
    '  "layouts": [{"code": "us", "variant": "default"}]' \
    '}' > "${config_home}/langs.json"
  
  echo -e 'Keyboard settings have been applied'
}

# Sets up the sheel environment files.
setup_shell_environment () {
  local zshrc_file="${ROOT_FS}/root/.zshrc"

  # Set the defauilt terminal and text editor
  echo -e 'export TERMINAL=cool-retro-term' >> "${zshrc_file}"
  echo -e 'export EDITOR=helix' >> "${zshrc_file}"

  # Set up trash-cli aliases
  echo -e "\nalias sudo='sudo '" >> "${zshrc_file}"
  echo "alias tt='trash-put -i'" >> "${zshrc_file}"
  echo "alias rm='rm -i'" >> "${zshrc_file}"

  echo -e 'Shell environment configs saved in /root/.zshrc'
}

# Sets up the corresponding configurations for
# each desktop module.
setup_desktop () {
  echo -e 'Setting up the desktop configurations...'

  local config_home="${ROOT_FS}/root/.config"

  # Copy the picom configuration files
  local picom_home="${config_home}/picom"

  mkdir -p "${picom_home}"
  
  cp configs/picom/picom.conf "${picom_home}"

  echo -e 'Picom configuration has been set'

  # Copy windows manager configuration files
  local bspwm_home="${config_home}/bspwm"

  mkdir -p "${bspwm_home}"

  cp configs/bspwm/bspwmrc "${bspwm_home}"
  cp configs/bspwm/resize "${bspwm_home}"
  cp configs/bspwm/rules "${bspwm_home}"
  cp configs/bspwm/swap "${bspwm_home}"

  # Remove init scratchpad initializer from the bspwmrc
  sed -i '/desktop -qs init scratchpad &/d' "${bspwm_home}/bspwmrc"
  sed -i '/bspc rule -a scratch sticky=off state=floating hidden=on/d' "${bspwm_home}/bspwmrc"

  echo -e 'Bspwm configuration has been set'

  # Copy polybar configuration files
  local polybar_home="${config_home}/polybar"

  mkdir -p "${polybar_home}"

  cp configs/polybar/config.ini "${polybar_home}"
  cp configs/polybar/modules.ini "${polybar_home}"
  cp configs/polybar/theme.ini "${polybar_home}"

  local config_ini="${polybar_home}/config.ini"

  # Remove modules not needed by the live media
  sed -i "s/\(modules-right = \)cpu.*/\1 alsa-audio date time/" "${config_ini}"
  sed -i "s/\(modules-right = \)notifications.*/\1 flash-drives keyboard/" "${config_ini}"
  sed -i "s/\(modules-left = \)wlan.*/\1 wlan eth/" "${config_ini}"

  mkdir -p "${polybar_home}/scripts"

  # Keep only scripts needed by the live media
  cp -r configs/polybar/scripts/flash-drives "${polybar_home}/scripts"
  cp -r configs/polybar/scripts/time "${polybar_home}/scripts"

  echo -e 'Polybar configuration has been set'

  # Copy sxhkd configuration files
  local sxhkd_home="${config_home}/sxhkd"

  mkdir -p "${sxhkd_home}"

  cp configs/sxhkd/sxhkdrc "${sxhkd_home}"

  local sxhkdrc_file="${sxhkd_home}/sxhkdrc"

  # Remove key bindings not needed by the live media
  sed -i '/# Lock the screen./,+3d' "${sxhkdrc_file}"
  sed -i '/# Take a screen shot./,+3d' "${sxhkdrc_file}"
  sed -i '/# Start recording your screen./,+3d' "${sxhkdrc_file}"
  sed -i '/# Show and hide the scratchpad termimal./,+3d' "${sxhkdrc_file}"

  echo -e 'Sxhkd configuration has been set'

  # Copy rofi configuration files
  local rofi_home="${config_home}/rofi"

  mkdir -p "${rofi_home}"

  cp configs/rofi/config.rasi "${rofi_home}"
  cp configs/rofi/launch "${rofi_home}"

  local launch_file="${rofi_home}/launch"

  sed -i "/options+='Lock\\\n'/d" "${launch_file}"
  sed -i "/options+='Blank\\\n'/d" "${launch_file}"
  sed -i "/options+='Logout'/d" "${launch_file}"
  sed -i "s/\(  local exact_lines='listview {lines:\) 6\(;}'\)/\1 3\2/" "${launch_file}"
  sed -i "/'Lock') security -qs lock screen;;/d" "${launch_file}"
  sed -i "/'Blank') power -qs blank;;/d" "${launch_file}"
  sed -i "/'Logout') security -qs logout user;;/d" "${launch_file}"

  echo -e 'Rofi configuration has been set'

  # Copy dunst configuration files
  local dunst_home="${config_home}/dunst"

  mkdir -p "${dunst_home}"

  cp configs/dunst/dunstrc "${dunst_home}"
  cp configs/dunst/hook "${dunst_home}"

  echo -e 'Dunst configuration has been set'
}

# Sets up the theme of the desktop environment.
setup_theme () {
  echo -e 'Setting up the Dracula theme...'

  local themes_home="${ROOT_FS}/usr/share/themes"

  mkdir -p "${themes_home}"

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip"
  unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}"
  mv "${themes_home}/gtk-master" "${themes_home}/Dracula"
  rm -f "${themes_home}/Dracula.zip"

  echo -e 'Dracula theme has been installed'

  echo -e 'Setting up the Dracula icons...'

  local icons_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${icons_home}"
  
  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip"
  unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}"
  rm -f "${icons_home}/Dracula.zip"

  echo -e 'Dracula icons have been installed'

  echo -e 'Setting up the Breeze cursors...'

  local cursors_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${cursors_home}"

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  wget "${cursors_url}" -qO "${cursors_home}/breeze-snow.tgz"
  tar -xzf "${cursors_home}/breeze-snow.tgz" -C "${cursors_home}"
  rm -f "${cursors_home}/breeze-snow.tgz"

  mkdir -p "${cursors_home}/default"
  echo '[Icon Theme]' >> "${cursors_home}/default/index.theme"
  echo 'Inherits=Breeze-Snow' >> "${cursors_home}/default/index.theme"

  echo -e 'Breeze cursors have been installed'

  local gtk_home="${ROOT_FS}/root/.config/gtk-3.0"
  
  mkdir -p "${gtk_home}"
  cp configs/gtk/settings.ini "${gtk_home}"

  echo -e 'Gtk settings file has been set'

  echo -e 'Setting the desktop wallpaper...'

  local wallpapers_home="${ROOT_FS}/root/.local/share/wallpapers"

  mkdir -p "${wallpapers_home}"
  cp resources/wallpapers/* "${wallpapers_home}"

  local settings_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${settings_home}"

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${settings_home}/desktop.json"

  echo -e 'Desktop wallpaper has been set'
}

# Sets up some extra system fonts.
setup_fonts () {
  echo -e 'Setting up extra system fonts...'

  local fonts_home="${ROOT_FS}/usr/share/fonts/extra-fonts"

  mkdir -p "${fonts_home}"

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
    name="$(echo "${font}" | cut -d ' ' -f 1)"

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)"

    curl "${url}" -sSLo "${fonts_home}/${name}.zip"
    unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}"
    chmod -R 755 "${fonts_home}/${name}"
    rm -f "${fonts_home}/${name}.zip"

    echo -e "Font ${name} installed"
  done

  echo -e 'Fonts have been setup'
}

# Sets up various system sound resources.
setup_sounds () {
  echo -e 'Setting up extra system sounds...'

  local sounds_home="${ROOT_FS}/usr/share/sounds/stack"
  
  mkdir -p "${sounds_home}"
  cp resources/sounds/normal.wav "${sounds_home}"
  cp resources/sounds/critical.wav "${sounds_home}"

  echo -e 'System sounds have been set'
}

# Enables various system services.
enable_services () {
  echo -e 'Enabling system services...'

  local systemd_home="${ROOT_FS}/etc/systemd/system"

  mkdir -p "${systemd_home}"

  ln -s /usr/lib/systemd/system/NetworkManager-dispatcher.service \
    "${systemd_home}/dbus-org.freedesktop.nm-dispatcher.service"

  local multi_user="${systemd_home}/multi-user.target.wants"

  mkdir -p "${multi_user}"

  ln -s /usr/lib/systemd/system/NetworkManager.service "${multi_user}"

  local network_online="${systemd_home}/network-online.target.wants"

  mkdir -p "${network_online}"

  ln -s /usr/lib/systemd/system/NetworkManager-wait-online.service "${network_online}"

  echo -e 'Network manager services enabled'
}

# Adds input and output devices rules.
add_device_rules () {
  echo -e 'Adding system udev rules...'

  local rules_home="${ROOT_FS}/etc/udev/rules.d"

  mkdir -p "${rules_home}"

  cp rules/90-init-pointer.rules "${rules_home}"
  cp rules/91-init-tablets.rules "${rules_home}"
  cp rules/92-fix-layout.rules "${rules_home}"
    
  echo -e 'Device rules have been set'
}

# Defines the root files permissions.
set_file_permissions () {
  echo -e 'Defining the file permissions...'

  local permissions_file="${PROFILE_DIR}/profiledef.sh"

  sed -i '/file_permissions=(/a ["/opt/stack/configs/bspwm/"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/configs/dunst/hook"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/configs/nnn/env"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/configs/polybar/scripts/"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/configs/rofi/launch"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/configs/xsecurelock/hook"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/tools/"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/scripts/"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/install.sh"]="0:0:755"' "${permissions_file}"

  sed -i '/file_permissions=(/a ["/root/.config/bspwm/"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/root/.config/polybar/scripts/"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/root/.config/rofi/launch"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/root/.config/dunst/hook"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/tools/"]="0:0:755"' "${permissions_file}"

  echo -e 'File permissions have been defined'
}

# Creates the iso file of the live media.
make_iso_file () {
  echo -e 'Building the archiso file...'

  sudo mkarchiso -v -r -w "${WORK_DIR}" -o "${DIST_DIR}" "${PROFILE_DIR}"

  echo -e "Archiso file has been exported at ${DIST_DIR}"
}

echo -e 'Build process will start in 5 secs...'
sleep 5

init &&
  copy_profile &&
  add_packages &&
  add_aur_packages &&
  copy_installer &&
  copy_settings_manager &&
  setup_display_server &&
  setup_keyboard &&
  setup_shell_environment &&
  setup_desktop &&
  setup_theme &&
  setup_fonts &&
  setup_sounds &&
  enable_services &&
  add_device_rules &&
  set_file_permissions &&
  make_iso_file &&
  echo -e 'Build process completed successfully' ||
  echo -e 'Build process has failed'
