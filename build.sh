#!/bin/bash

# Adds the given packages to the list of packages.
# Arguments:
#  names: the list of package names
add_packages () {
  local names=(${@})

  local pkgs_file=.dist/archlive/packages.x86_64

  local name=''
  for name in "${names[@]}"; do
    if grep -Eq "${name}" "${pkgs_file}"; then
      echo -e "Package ${name} skipped"
      continue
    fi

    echo "${name}" >> "${pkgs_file}"
  done
}

# Initializes build and distribution files.
init () {
  echo -e 'Cleaning up existing build files...'

  # Remove any pre-existing distribution files
  rm -rf .dist
  rm -rf /tmp/stack

  # Create distribution directories
  mkdir -p .dist
  mkdir -p .dist/work
  mkdir -p .dist/out
  mkdir -p /tmp/stack

  echo -e 'Build and distribution files removed'
}

# Copies the archiso custom releng profile.
copy_profile () {
  echo -e 'Copying the custom archiso profile'

  cp -r /usr/share/archiso/configs/releng .dist/archlive

  echo -e 'The releng archiso profile has been copied'
}

# Adds the base and system packages into the list of packages.
add_base_packages () {
  echo -e 'Adding base packages...'

  add_packages reflector rsync sudo \
    base-devel pacman-contrib pkgstats grub mtools dosfstools ntfs-3g exfatprogs gdisk fuseiso veracrypt \
    python-pip parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion \
    man-db man-pages texinfo cups cups-pdf cups-filters usbutils bluez bluez-utils unzip terminus-font \
    vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh hsetroot \
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils ipset xsel \
    neofetch age imagemagick gpick fuse2 rclone smartmontools glib2 jq jc sequoia-sq xf86-input-wacom \
    cairo bc xdotool \
    python-tqdm libqalculate firefox

  echo -e 'Base packages have been added'
}

# Adds the display server packages and sets up
# the configuration files.
add_display_server_packages () {
  echo -e 'Adding the display server packages...'

  add_packages xorg xorg-xinit xorg-xrandr xorg-xdpyinfo

  echo -e 'Xorg packages added'

  local root_home=.dist/archlive/airootfs/root

  cp configs/xorg/xinitrc "${root_home}/.xinitrc"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${root_home}/.zsh_profile"

  echo -e 'Xorg configuration files and hooks have been set'
}

# Adds the drivers packages into the list of packages.
add_drivers_packages () {
  echo -e 'Adding driver packages...'

  add_packages xf86-video-qxl xf86-input-synaptics \
    acpi acpi_call acpid tlp xcalib \
    networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant \
    nmap dhclient smbclient libnma \
    alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack

  echo -e 'Drivers packages have been added'
}

# Builds and adds the AUR packages into the packages list
# via an local custom repo.
add_aur_packages () {
  echo -e 'Building AUR package files...'

  local previous_dir=${PWD}

  local repo_home=.dist/archlive/local/repo

  mkdir -p "${repo_home}"

  local names=(
    yay smenu
  )

  local name=''
  for name in "${names[@]}"; do
    git clone "https://aur.archlinux.org/${name}.git" "/tmp/stack/aur/${name}"
  
    cd "/tmp/stack/aur/${name}"
    makepkg
    cd ${previous_dir}

    cp /tmp/stack/aur/"${name}"/"${name}"-*-x86_64.pkg.tar.zst "${repo_home}"
    repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/"${name}"-*-x86_64.pkg.tar.zst

    add_packages "${name}"
  done

  echo -e 'The AUR package files have been built'

  local pacman_conf=.dist/archlive/pacman.conf

  echo -e '\n[custom]' >> "${pacman_conf}"
  echo -e 'SigLevel = Optional TrustAll' >> "${pacman_conf}"
  echo -e "Server = file://$(realpath "${repo_home}")" >> "${pacman_conf}"

  echo -e 'Custom local repo added to pacman'
  
  echo -e 'AUR packages have been added'
}

# Copies the files of the installer.
copy_installer () {
  echo -e 'Copying the installer files...'

  local installer_home=.dist/archlive/airootfs/opt/stack

  mkdir -p "${installer_home}"

  cp -r ./configs "${installer_home}"
  cp -r ./resources "${installer_home}"
  cp -r ./rules "${installer_home}"
  cp -r ./scripts "${installer_home}"
  cp -r ./services "${installer_home}"
  cp -r ./tools "${installer_home}"
  cp ./install.sh "${installer_home}"

  echo -e 'Installer files have been copied'
}

# Copies and setups aliases for the settings manager tools.
copy_settings_manager () {
  local tools_home=.dist/archlive/airootfs/opt/tools

  mkdir -p "${tools_home}"

  cp -r tools/* "${tools_home}"

  local bin_home=.dist/archlive/airootfs/usr/local/bin

  mkdir -p "${bin_home}"

  ln -sf /opt/stack/tools/displays/main "${bin_home}/displays"
  ln -sf /opt/stack/tools/desktop/main "${bin_home}/desktop"
  ln -sf /opt/stack/tools/audio/main "${bin_home}/audio"
  ln -sf /opt/stack/tools/clock/main "${bin_home}/clock"
  ln -sf /opt/stack/tools/cloud/main "${bin_home}/cloud"
  ln -sf /opt/stack/tools/networks/main "${bin_home}/networks"
  ln -sf /opt/stack/tools/disks/main "${bin_home}/disks"
  ln -sf /opt/stack/tools/bluetooth/main "${bin_home}/bluetooth"
  ln -sf /opt/stack/tools/langs/main "${bin_home}/langs"
  ln -sf /opt/stack/tools/notifications/main "${bin_home}/notifications"
  ln -sf /opt/stack/tools/power/main "${bin_home}/power"
  ln -sf /opt/stack/tools/printers/main "${bin_home}/printers"
  ln -sf /opt/stack/tools/security/main "${bin_home}/security"
  ln -sf /opt/stack/tools/trash/main "${bin_home}/trash"
  ln -sf /opt/stack/tools/system/main "${bin_home}/system"
}

# Adds the desktop pre-requisite packages and sets up
# the corresponding configurations.
setup_desktop () {
  echo -e 'Setting up the desktop...'

  add_packages picom bspwm sxhkd polybar rofi dunst \
    trash-cli cool-retro-term helix

  echo -e 'Desktop pre-requisite packages added'

  local config_home=.dist/archlive/airootfs/root/.config

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
  cp configs/bspwm/scratchpad "${bspwm_home}"
  cp configs/bspwm/swap "${bspwm_home}"

  echo -e 'Bspwm configuration has been set'

  # Copy polybar configuration files
  local polybar_home="${config_home}/polybar"

  mkdir -p "${polybar_home}"

  cp configs/polybar/config.ini "${polybar_home}"
  cp configs/polybar/modules.ini "${polybar_home}"
  cp configs/polybar/theme.ini "${polybar_home}"

  sed -i "s/\(modules-right = \)cpu.*/\1 date time user/" "${polybar_home}/config.ini"
  sed -i "s/\(modules-right = \)notifications.*/\1 power audio keyboard/" "${polybar_home}/config.ini"
  sed -i "s/\(modules-left = \)wlan.*/\1 wlan eth flash-drives/" "${polybar_home}/config.ini"

  mkdir -p "${polybar_home}/scripts"

  cp -r configs/polybar/scripts/flash-drives "${polybar_home}/scripts"
  cp -r configs/polybar/scripts/time "${polybar_home}/scripts"
  cp -r configs/polybar/scripts/power "${polybar_home}/scripts"

  echo -e 'Polybar configuration has been set'

  # Copy sxhkd configuration files
  local sxhkd_home="${config_home}/sxhkd"

  mkdir -p "${sxhkd_home}"

  cp configs/sxhkd/sxhkdrc "${sxhkd_home}"

  echo -e 'Sxhkd configuration has been set'

  # Copy rofi configuration files
  local rofi_home="${config_home}/rofi"

  mkdir -p "${rofi_home}"

  cp configs/rofi/config.rasi "${rofi_home}"
  cp configs/rofi/launch "${rofi_home}"

  echo -e 'Rofi configuration has been set'

  # Copy dunst configuration files
  local dunst_home="${config_home}/dunst"

  mkdir -p "${dunst_home}"

  cp configs/dunst/dunstrc "${dunst_home}"
  cp configs/dunst/hook "${dunst_home}"

  # Set up trash-cli aliases
  local zshrc_file=.dist/archlive/airootfs/root/.zshrc

  echo -e "\nalias sudo='sudo '" >> "${zshrc_file}"
  echo "alias tt='trash-put -i'" >> "${zshrc_file}"
  echo "alias rm='rm -i'" >> "${zshrc_file}"

  # Set the defauilt text editor to helix
  echo -e '\nexport EDITOR=helix' >> "${zshrc_file}"
}

# Copies and sets up the theme of the live media.
setup_theme () {
  echo -e 'Setting up the Dracula theme...'

  local themes_home=.dist/archlive/airootfs/usr/share/themes

  mkdir -p "${themes_home}"

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip"
  unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}"
  mv "${themes_home}/gtk-master" "${themes_home}/Dracula"
  rm -f "${themes_home}/Dracula.zip"

  echo -e 'Dracula theme has been installed'

  echo -e 'Setting up the Dracula icons...'

  local icons_home=.dist/archlive/airootfs/usr/share/icons

  mkdir -p "${icons_home}"
  
  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip"
  unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}"
  rm -f "${icons_home}/Dracula.zip"

  echo -e 'Dracula icons have been installed'

  echo -e 'Setting up the Breeze cursors...'

  local cursors_home=.dist/archlive/airootfs/usr/share/icons

  mkdir -p "${cursors_home}"

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  wget "${cursors_url}" -qO "${cursors_home}/breeze-snow.tgz"
  tar -xzf "${cursors_home}/breeze-snow.tgz" -C "${cursors_home}"
  rm -f "${cursors_home}/breeze-snow.tgz"

  mkdir -p "${cursors_home}/default"
  echo '[Icon Theme]' >> "${cursors_home}/default/index.theme"
  echo 'Inherits=Breeze-Snow' >> "${cursors_home}/default/index.theme"

  echo -e 'Breeze cursors have been installed'

  local gtk_home=.dist/archlive/airootfs/root/.config/gtk-3.0
  
  mkdir -p "${gtk_home}"
  cp configs/gtk/settings.ini "${gtk_home}"

  echo -e 'Gtk settings file has been set'

  echo -e 'Setting the desktop wallpaper...'

  local wallpapers_home=.dist/archlive/airootfs/root/.local/share/wallpapers

  mkdir -p "${wallpapers_home}"
  cp resources/wallpapers/* "${wallpapers_home}"

  local settings_home=.dist/archlive/airootfs/root/.config/stack

  mkdir -p "${settings_home}"

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${settings_home}/desktop.json"

  echo -e 'Desktop wallpaper has been set'
}

# Sets up sopme extra system fonts.
setup_fonts () {
  echo -e 'Setting up extra system fonts...'

  local fonts_home=.dist/archlive/airootfs/usr/share/fonts/extra-fonts

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

    echo -e "Font ${name} has been installed"
  done

  echo -e 'Adding some extra glyph fonts...'

  add_packages ttf-font-awesome noto-fonts-emoji

  echo -e 'Fonts have been setup'
}

# Sets up various system sound resources.
setup_sounds () {
  echo -e 'Setting up extra system sounds...'

  local sounds_home=.dist/archlive/airootfs/usr/share/sounds/stack
  
  mkdir -p "${sounds_home}"
  cp resources/sounds/normal.wav "${sounds_home}"
  cp resources/sounds/critical.wav "${sounds_home}"

  echo -e 'System sounds have been set'
}

set_file_permissions () {
  echo -e 'Defining the file permissions...'

  local permissions_file=.dist/archlive/profiledef.sh

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

make_archiso () {
  echo -e 'Building the archiso file...'

  sudo mkarchiso -v -w .dist/work -o .dist/out .dist/archlive
}

echo -e 'Build process will start in 5 secs...'
sleep 5

init &&
  copy_profile &&
  add_base_packages &&
  add_display_server_packages &&
  add_drivers_packages &&
  add_aur_packages &&
  copy_installer &&
  copy_settings_manager &&
  setup_desktop &&
  setup_theme &&
  setup_fonts &&
  setup_sounds &&
  set_file_permissions &&
  make_archiso &&
  echo -e 'Build process completed successfully' ||
  echo -e 'Build process has failed'
