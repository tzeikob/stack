#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the desktop compositor.
install_compositor () {
  echo 'Installing the desktop compositor...'

  sudo pacman -S --noconfirm picom || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/picom"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/picom/picom.conf "${config_home}" || exit 1

  if is_setting 'vm' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    echo 'Virtual box machine detected'

    sed -i 's/\(vsync =\).*/\1 false;/' "${config_home}/picom.conf" || exit 1

    echo 'Vsync option has been disabled'
  fi

  echo 'Desktop compositor has been installed'
}

# Installs the window manager.
install_window_manager () {
  echo 'Installing the window manager...'

  sudo pacman -S --noconfirm bspwm || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/bspwm"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/bspwm/bspwmrc "${config_home}" &&
    chmod 755 "${config_home}/bspwmrc" || exit 1
  
  cp /opt/stack/configs/bspwm/rules "${config_home}" &&
    chmod 755 "${config_home}/rules" || exit 1

  cp /opt/stack/configs/bspwm/resize "${config_home}" &&
    chmod 755 "${config_home}/resize" || exit 1

  cp /opt/stack/configs/bspwm/swap "${config_home}" &&
    chmod 755 "${config_home}/swap" || exit 1

  cp /opt/stack/configs/bspwm/scratchpad "${config_home}" &&
    chmod 755 "${config_home}/scratchpad" || exit 1

  echo 'Window manager has been installed'
}

# Installs the desktop status bars.
install_status_bars () {
  echo 'Installing the desktop status bars...'

  sudo pacman -S --noconfirm polybar || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/polybar"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/polybar/config.ini "${config_home}" &&
    chmod 644 "${config_home}/config.ini" || exit 1
  
  cp /opt/stack/configs/polybar/modules.ini "${config_home}" &&
    chmod 644 "${config_home}/modules.ini" || exit 1
  
  cp /opt/stack/configs/polybar/theme.ini "${config_home}" &&
    chmod 644 "${config_home}/theme.ini" || exit 1

  cp -r /opt/stack/configs/polybar/scripts "${config_home}" &&
    chmod +x "${config_home}"/scripts/* || exit 1

  echo 'Status bars have been installed'
}

# Installs the utility tools for managing system settings.
install_settings_manager () {
  echo -e '\nInstalling settings manager tools...'

  yay -S --noconfirm --removemake smenu || exit 1

  local tools_home='/opt/tools'

  sudo mkdir -p "${tools_home}" || exit 1
  
  sudo cp -r /opt/stack/tools/* "${tools_home}" || exit 1

  local bin_home='/usr/local/bin'

  # Create symlinks to expose executables
  sudo ln -sf "${tools_home}/displays/main" "${bin_home}/displays" &&
    sudo ln -sf "${tools_home}/desktop/main" "${bin_home}/desktop" &&
    sudo ln -sf "${tools_home}/audio/main" "${bin_home}/audio" &&
    sudo ln -sf "${tools_home}/clock/main" "${bin_home}/clock" &&
    sudo ln -sf "${tools_home}/cloud/main" "${bin_home}/cloud" &&
    sudo ln -sf "${tools_home}/networks/main" "${bin_home}/networks" &&
    sudo ln -sf "${tools_home}/disks/main" "${bin_home}/disks" &&
    sudo ln -sf "${tools_home}/bluetooth/main" "${bin_home}/bluetooth" &&
    sudo ln -sf "${tools_home}/langs/main" "${bin_home}/langs" &&
    sudo ln -sf "${tools_home}/notifications/main" "${bin_home}/notifications" &&
    sudo ln -sf "${tools_home}/power/main" "${bin_home}/power" &&
    sudo ln -sf "${tools_home}/printers/main" "${bin_home}/printers" &&
    sudo ln -sf "${tools_home}/security/main" "${bin_home}/security" &&
    sudo ln -sf "${tools_home}/trash/main" "${bin_home}/trash" &&
    sudo ln -sf "${tools_home}/system/main" "${bin_home}/system" || exit 1

  echo 'Settings manager tools have been installed'
}

# Installs the desktop launchers.
install_launchers () {
  echo 'Installing the desktop launchers...'

  sudo pacman -S --noconfirm rofi || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/rofi"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/rofi/config.rasi "${config_home}" &&
    chmod 644 "${config_home}/config.rasi" || exit 1

  cp /opt/stack/configs/rofi/launch "${config_home}" &&
    chmod +x "${config_home}/launch" || exit 1

  echo 'Desktop launchers have been installed'
}

# Installs the keyboard key bindinds and shortcuts.
install_keyboard_bindings () {
  echo 'Installing the keyboard key bindings...'

  sudo pacman -S --noconfirm sxhkd || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/sxhkd"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/sxhkd/sxhkdrc "${config_home}" &&
    chmod 644 "${config_home}/sxhkdrc" || exit 1

  echo 'Keyboard key bindings have been set'
}

# Installs the login screen.
install_login_screen () {
  echo 'Installing the login screen...'

  sudo pacman -S --noconfirm figlet || exit 1
  yay -S --noconfirm --removemake figlet-fonts figlet-fonts-extra || exit 1

  sudo mv /etc/issue /etc/issue.bak || exit 1

  local host_name=''
  host_name="$(get_setting 'host_name')" || exit 1

  local logo=''
  logo="$(figlet -f pagga " ${host_name} ")" || exit 1

  echo -e "${logo}\n" | sudo tee /etc/issue > /dev/null || exit 1

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/getty@.service || exit 1
  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/serial-getty@.service || exit 1

  echo 'Login screen has been installed'
}

# Installs the screen locker.
install_screen_locker () {
  echo 'Installing the screen locker...'

  sudo pacman -S --noconfirm xautolock python-cairo python-pam || exit 1
  yay -S --noconfirm --removemake python-screeninfo || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  cd "/home/${user_name}"
  git clone https://github.com/tzeikob/xsecurelock.git || exit 1
  cd xsecurelock
  sh autogen.sh || exit 1
  ./configure --with-pam-service-name=system-auth || exit 1
  make || exit 1
  sudo make install || exit 1

  cd "/home/${user_name}"
  rm -rf "/home/${user_name}/xsecurelock" || exit 1

  sudo cp /opt/stack/configs/xsecurelock/hook /usr/lib/systemd/system-sleep/locker || exit 1

  local user_id="$(id -u "${user_name}")"

  sudo cp /opt/stack/configs/xsecurelock/service /etc/systemd/system/lock@.service || exit 1
  sudo sed -i "s/#USER_ID/${user_id}/g" /etc/systemd/system/lock@.service || exit 1

  sudo systemctl enable lock@${user_name}.service || exit 1

  echo 'Screen locker has been installed'
}

# Installs the notifications server.
install_notification_server () {
  echo 'Installing notifications server...'

  sudo pacman -S --noconfirm dunst || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/dunst"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/dunst/dunstrc "${config_home}" || exit 1
  cp /opt/stack/configs/dunst/hook "${config_home}" || exit 1

  echo 'Notifications server has been installed'
}

# Installs the file manager.
install_file_manager () {
  echo 'Installing the file manager...'

  sudo pacman -S --noconfirm nnn fzf || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/nnn"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/nnn/env "${config_home}" || exit 1

  echo 'Installing file manager plugins...'

  # Todo: get current working directory error
  local pluggins_url='https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs'

  curl "${pluggins_url}" -sSLo "${config_home}/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  cd "/home/${user_name}"
  HOME="/home/${user_name}" sh "${config_home}/getplugs" > /dev/null || exit 1

  echo 'Extra plugins have been installed'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nsource "${HOME}/.config/nnn/env"' >> "${bashrc_file}" &&
    echo 'alias N="sudo -E nnn -dH"' >> "${bashrc_file}" || exit 1

  echo 'File manager hooks added in the bashrc file'

  mkdir -p "/home/${user_name}"/{downloads,documents,data,sources,mounts} || exit 1
  mkdir -p "/home/${user_name}"/{images,audios,videos} || exit 1

  cp /opt/stack/configs/nnn/user.dirs "/home/${user_name}/.config/user-dirs.dirs" || exit 1

  echo 'User home directories have been created'

  printf '%s\n' \
    '[Default Applications]' \
    'inode/directory=nnn.desktop' > "/home/${user_name}/.config/mimeapps.list" || exit 1
  
  chmod 644 "/home/${user_name}/.config/mimeapps.list" || exit 1

  echo 'Application mime types file has been created'

  echo 'File manager has been installed'
}

# Installs the trash manager.
install_trash_manager () {
  echo 'Installing the trash manager...'

  sudo pacman -S --noconfirm trash-cli || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e "\nalias sudo='sudo '" >> "${bashrc_file}" &&
    echo "alias tt='trash-put -i'" >> "${bashrc_file}" &&
    echo "alias rm='rm -i'" >> "${bashrc_file}" || exit 1

  bashrc_file='/root/.bashrc'
  
  echo -e "\nalias sudo='sudo '" | sudo tee -a "${bashrc_file}" > /dev/null &&
    echo "alias tt='trash-put -i'" | sudo tee -a "${bashrc_file}" > /dev/null &&
    echo "alias rm='rm -i'" | sudo tee -a "${bashrc_file}" > /dev/null || exit 1

  echo 'Trash manager has been installed'
}

# Installs the virtual terminals.
install_terminals () {
  echo 'Installing virtual terminals...'

  sudo pacman -S --noconfirm alacritty cool-retro-term || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/alacritty"

  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/alacritty/alacritty.toml "${config_home}" || exit 1

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport TERMINAL=alacritty' >> "${bashrc_file}" &&
    sed -i '/PS1.*/d' "${bashrc_file}" &&
    cat /opt/stack/configs/alacritty/user.prompt >> "${bashrc_file}" || exit 1

  sudo sed -i '/PS1.*/d' /root/.bashrc || exit 1
  cat /opt/stack/configs/alacritty/root.prompt | sudo tee -a /root/.bashrc > /dev/null || exit 1

  echo 'Terminal prompt hooks have been set'

  echo 'Virtual terminals have been installed'
}

# Installs the text editor.
install_text_editor () {
  echo 'Installing the text editor...'

  sudo pacman -S --noconfirm helix || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport EDITOR=helix' >> "${bashrc_file}" || exit 1

  echo -e 'Text editor has been installed\n'
}

# Installs the web browsers.
install_web_browsers () {
  echo 'Installing the web browsers...'

  sudo pacman -S --noconfirm firefox torbrowser-launcher || exit 1

  yay -S --noconfirm --removemake google-chrome brave-bin || exit 1

  echo -e 'Web browser have been installed\n'
}

# Installing monitoring tools.
install_monitoring_tools () {
  echo 'Installing monitoring tools...'

  sudo pacman -S --noconfirm htop glances || exit 1

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || exit 1

  local desktop_file="${desktop_home}/glances.desktop"

  printf '%s\n' \
   '[Desktop Entry]' \
   'Type=Application' \
   'Name=Glances' \
   'comment=Console Monitor' \
   'Exec=glances' \
   'Terminal=true' \
   'Icon=glances' \
   'Catogories=Monitor;Resources;System;Console' \
   'Keywords=Monitor;Resources;System' | sudo tee "${desktop_file}" > /dev/null || exit 1

  echo 'Monitoring tools have been installed'
}

# Installs the print screen and recording casters.
install_screen_casters () {
  echo 'Installing screen casting tools...'

  sudo pacman -S --noconfirm scrot || exit 1

  yay -S --noconfirm --removemake --mflags --nocheck slop screencast || exit 1

  echo 'Screen casting tools have been installed'
}

# Installs the calculator.
install_calculator () {
  echo 'Installing the calculator...'

  yay -S --noconfirm --removemake libqalculate || exit 1

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || exit 1

  local desktop_file="${desktop_home}/qalculate.desktop"

  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=qalculate' \
    'comment=Console Calculator' \
    'Exec=qalc' \
    'Terminal=true' \
    'Icon=qalculate' \
    'Catogories=Math;Calculator;Console' \
    'Keywords=Calc;Math' | sudo tee "${desktop_file}" > /dev/null || exit 1

  echo 'Calculators has been installed'
}

# Installs the media viewer.
install_media_viewer () {
  echo 'Installing the media viewer...'

  sudo pacman -S --noconfirm sxiv || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'image/jpeg=sxiv.desktop' \
    'image/jpg=sxiv.desktop' \
    'image/png=sxiv.desktop' \
    'image/tiff=sxiv.desktop' >> "${config_home}/mimeapps.list" || exit 1
  
  echo 'Media viewer has been installed'
}

# Installs the music player.
install_music_player () {
  echo 'Installing the music player...'
  
  sudo pacman -S --noconfirm mpd ncmpcpp || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config"

  local mpd_home="/${config_home}/mpd"

  mkdir -p "${mpd_home}"/{playlists,database} || exit 1

  cp /opt/stack/configs/mpd/conf "${mpd_home}/mpd.conf" || exit 1

  local ncmpcpp_home="/${config_home}/ncmpcpp"

  mkdir -p "${ncmpcpp_home}" || exit 1

  cp /opt/stack/configs/ncmpcpp/config "${ncmpcpp_home}/config" || exit 1

  sudo systemctl --user enable mpd.service || exit 1

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || exit 1

  local desktop_file="${desktop_home}/ncmpcpp.desktop"

  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=Ncmpcpp' \
    'comment=Console music player' \
    'Exec=ncmpcpp' \
    'Terminal=true' \
    'Icon=ncmpcpp' \
    'MimeType=audio/mpeg' \
    'Catogories=Music;Player;ConsoleOnly' \
    'Keywords=Music;Player;Audio' | sudo tee "${desktop_file}" > /dev/null || exit 1
  
  printf '%s\n' \
    'audio/mpeg=ncmpcpp.desktop' \
    'audio/mp3=ncmpcpp.desktop' \
    'audio/flac=ncmpcpp.desktop' \
    'audio/midi=ncmpcpp.desktop' >> "${config_home}/mimeapps.list" || exit 1
  
  echo 'Music player has been installed'
}

# Installs the video media player.
install_video_player () {
  echo 'Installing video media player...'

  sudo pacman -S --noconfirm mpv || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'video/mp4=mpv.desktop' \
    'video/mkv=mpv.desktop' \
    'video/mov=mpv.desktop' \
    'video/mpeg=mpv.desktop' \
    'video/avi=mpv.desktop' >> "${config_home}/mimeapps.list" || exit 1
  
  echo 'Video media player has been installed'
}

# Installs the audio and video media codecs.
install_media_codecs () {
  echo 'Installing audio and video media codecs...'

  sudo pacman -S --noconfirm \
    faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack || exit 1

  echo 'Media codecs have been installed'
}

# Installs the office tools.
install_office_tools () {
  echo 'Installing the office tools...'

  sudo pacman -S --noconfirm libreoffice-fresh || exit 1

  echo -e 'Office tools have been installed\n'
}

# Installs the pdf and epub readers.
install_readers () {
  echo 'Installing pdf and epub readers...'

  sudo pacman -S --noconfirm foliate || exit 1
  yay -S --noconfirm --useask --removemake --diffmenu=false evince-no-gnome poppler || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' \
    'application/pdf=org.gnome.Evince.desktop' >> "${config_home}/mimeapps.list" || exit 1

  echo -e 'Pdf and epub readers have been installed\n'
}

# Installs the torrent client.
install_torrent_client () {
  echo 'Installing the torrent client...'

  sudo pacman -S --noconfirm transmission-cli || exit 1

  echo -e 'Torrent client has been installed\n'
}

# Installs the desktop and ui theme.
install_theme () {
  echo 'Installing the desktop theme...'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  sudo curl "${theme_url}" -sSLo /usr/share/themes/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  sudo unzip -q /usr/share/themes/Dracula.zip -d /usr/share/themes &&
    sudo mv /usr/share/themes/gtk-master /usr/share/themes/Dracula &&
    sudo rm -f /usr/share/themes/Dracula.zip || exit 1

  echo 'Theme has been installed'

  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  sudo curl "${icons_url}" -sSLo /usr/share/icons/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  sudo unzip -q /usr/share/icons/Dracula.zip -d /usr/share/icons &&
    sudo rm -f /usr/share/icons/Dracula.zip || exit 1

  echo 'Theme icons have been installed'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  sudo wget "${cursors_url}" -qO /usr/share/icons/breeze-snow.tgz \
    --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 || exit 1

  sudo tar -xzf /usr/share/icons/breeze-snow.tgz -C /usr/share/icons &&
    sudo sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' /usr/share/icons/default/index.theme &&
    sudo rm -f /usr/share/icons/breeze-snow.tgz || exit 1

  echo 'Cursors have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local config_home="/home/${user_name}/.config/gtk-3.0"
  
  mkdir -p "${config_home}" || exit 1

  cp /opt/stack/configs/gtk/settings.ini "${config_home}" || exit 1

  local wallpapers_home="/home/${user_name}/.local/share/wallpapers"

  mkdir -p "${wallpapers_home}" || exit 1

  cp /opt/stack/resources/wallpapers/* "${wallpapers_home}" || exit 1

  config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || exit 1

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${config_home}/desktop.json" || exit 1

  echo 'Default wallpaper has been set'

  echo 'Desktop theme has been setup'
}

# Installs extras system fonts.
install_fonts () {
  echo -e '\nInstalling extra fonts...'

  local fonts_home='/usr/share/fonts/extra-fonts'

  sudo mkdir -p "${fonts_home}" || exit 1

  local fonts=(
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
    "PixelMix https://dl.dafont.com/dl/?f=pixelmix"
  )

  local font=''

  for font in "${fonts[@]}"; do
    local name=''
    name="$(echo "${font}" | cut -d ' ' -f 1)" || exit 1

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" || exit 1

    sudo curl "${url}" -sSLo "${fonts_home}/${name}.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1
    
    sudo unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" || exit 1
    sudo chmod -R 755 "${fonts_home}/${name}" || exit 1

    sudo rm -f "${fonts_home}/${name}.zip" || exit 1

    echo "Font ${name} has been installed"
  done

  fc-cache -f || exit 1

  echo "Fonts have been installed under ${fonts_home}"

  echo -e '\nInstalling some extra font glyphs...'

  sudo pacman -S --noconfirm \
    ttf-font-awesome noto-fonts-emoji || exit 1

  echo 'Extra font glyphs have been installed'
}

# Installs various system sound resources.
install_sounds () {
  echo 'Installing extra system sounds...'

  local sounds_home='/usr/share/sounds/stack'
  
  sudo mkdir -p "${sounds_home}" &&
    sudo cp /opt/stack/resources/sounds/normal.wav "${sounds_home}" &&
    sudo cp /opt/stack/resources/sounds/critical.wav "${sounds_home}" || exit 1

  echo 'System sounds have been installed'
}

# Installs various extra packages.
install_extra_packages () {
  echo -e '\nInstalling some extra packages...'

  yay -S --noconfirm --removemake \
    digimend-kernel-drivers-dkms-git xkblayout-state-git || exit 1
  
  echo 'Extra packages have been installed'
}

echo -e '\nStarting the desktop installation process...'

if equals "$(id -u)" 0; then
  echo -e '\nProcess must be run as non root user'
  exit 1
fi

install_compositor &&
  install_window_manager &&
  install_status_bars &&
  install_settings_manager &&
  install_launchers &&
  install_keyboard_bindings &&
  install_login_screen &&
  install_screen_locker &&
  install_notification_server &&
  install_file_manager &&
  install_trash_manager &&
  install_terminals &&
  install_text_editor &&
  install_web_browsers &&
  install_monitoring_tools &&
  install_screen_casters &&
  install_calculator &&
  install_media_viewer &&
  install_music_player &&
  install_video_player &&
  install_media_codecs &&
  install_office_tools &&
  install_readers &&
  install_torrent_client &&
  install_theme &&
  install_fonts &&
  install_sounds &&
  install_extra_packages

echo -e '\nDesktop installation has been completed'
echo 'Moving to the stack installation process...'
sleep 5

