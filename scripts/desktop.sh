#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the desktop compositor.
install_compositor () {
  echo -e 'Installing the desktop compositor...'

  sudo pacman -S --noconfirm picom || fail 'Failed to install picom'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/picom"

  mkdir -p "${config_home}" || fail

  cp /opt/stack/configs/picom/picom.conf "${config_home}" ||
    fail 'Failed to copy compositor config file'

  if is_setting 'vm' 'yes' && is_setting 'vm_vendor' 'oracle'; then
    echo -e 'Virtual box machine detected'

    sed -i 's/\(vsync =\).*/\1 false;/' "${config_home}/picom.conf" ||
      fail 'Failed to disable vsync mode'

    echo -e 'Vsync mode has been disabled'
  fi

  echo -e 'Desktop compositor picom has been installed'
}

# Installs the window manager.
install_window_manager () {
  echo -e 'Installing the window manager...'

  sudo pacman -S --noconfirm bspwm || fail 'Failed to install bspwm'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/bspwm"

  mkdir -p "${config_home}" || fail

  cp /opt/stack/configs/bspwm/bspwmrc "${config_home}" &&
    chmod 755 "${config_home}/bspwmrc" &&
    cp /opt/stack/configs/bspwm/rules "${config_home}" &&
    chmod 755 "${config_home}/rules" &&
    cp /opt/stack/configs/bspwm/resize "${config_home}" &&
    chmod 755 "${config_home}/resize" &&
    cp /opt/stack/configs/bspwm/swap "${config_home}" &&
    chmod 755 "${config_home}/swap" &&
    cp /opt/stack/configs/bspwm/scratchpad "${config_home}" &&
    chmod 755 "${config_home}/scratchpad" || fail 'Failed to copy the bspwm config files'

  echo -e 'Window manager bspwm has been installed'
}

# Installs the desktop status bars.
install_status_bars () {
  echo -e 'Installing the desktop status bars...'

  sudo pacman -S --noconfirm polybar || fail 'Failed to install polybar'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/polybar"

  mkdir -p "${config_home}" || fail

  cp /opt/stack/configs/polybar/config.ini "${config_home}" &&
    chmod 644 "${config_home}/config.ini" &&
    cp /opt/stack/configs/polybar/modules.ini "${config_home}" &&
    chmod 644 "${config_home}/modules.ini" &&
    cp /opt/stack/configs/polybar/theme.ini "${config_home}" &&
    chmod 644 "${config_home}/theme.ini" &&
    cp -r /opt/stack/configs/polybar/scripts "${config_home}" &&
    chmod +x "${config_home}"/scripts/* || fail 'Failed to copy polybar config files'

  echo -e 'Status bars have been installed'
}

# Installs the utility tools for managing system settings.
install_settings_manager () {
  echo -e 'Installing settings manager tools...'

  yay -S --noconfirm --removemake smenu || fail 'Failed to install smenu'

  local tools_home='/opt/tools'

  sudo mkdir -p "${tools_home}" &&
    sudo cp -r /opt/stack/tools/* "${tools_home}" || fail 'Failed to install setting manager tools'

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
    sudo ln -sf "${tools_home}/system/main" "${bin_home}/system" ||
    fail 'Failed to create symlinks to /usr/local/bin'

  echo -e 'Settings manager tools have been installed'
}

# Installs the desktop launchers.
install_launchers () {
  echo -e 'Installing the desktop launchers...'

  sudo pacman -S --noconfirm rofi || fail 'Failed to install rofi'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/rofi"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/rofi/config.rasi "${config_home}" &&
    chmod 644 "${config_home}/config.rasi" &&
    cp /opt/stack/configs/rofi/launch "${config_home}" &&
    chmod +x "${config_home}/launch" || fail 'Failed to copy rofi config files'

  echo -e 'Desktop launchers have been installed'
}

# Installs the keyboard key bindinds and shortcuts.
install_keyboard_bindings () {
  echo -e 'Setting up the keyboard key bindings...'

  sudo pacman -S --noconfirm sxhkd || fail 'Failed to install sxhkd'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/sxhkd"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/sxhkd/sxhkdrc "${config_home}" &&
    chmod 644 "${config_home}/sxhkdrc" || fail 'Failed to copy sxhkdrc configs files'

  echo -e 'Keyboard key bindings have been set'
}

# Installs the login screen.
install_login_screen () {
  echo -e 'Installing the login screen...'

  sudo pacman -S --noconfirm figlet &&
    yay -S --noconfirm --removemake figlet-fonts figlet-fonts-extra ||
    fail 'Failed to install figlet packages'
  
  echo -e 'Figlet packages have been installed'

  sudo mv /etc/issue /etc/issue.bak || fail 'Failed to backup the issue file'

  echo -e 'The issue file has been backed up to /etc/issue.bak'

  local host_name=''
  host_name="$(get_setting 'host_name')" || fail

  figlet -f pagga " ${host_name} " | sudo tee /etc/issue > /dev/null ||
    fail 'Failed to create the new issue file'
  
  echo -e 'The new issue file has been created'

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/getty@.service || fail 'Failed to set no hostname mode to getty service'

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/serial-getty@.service || fail 'Failed to set no hostname mode to serial getty service'

  echo -e 'Login screen has been installed'
}

# Installs the screen locker.
install_screen_locker () {
  echo -e 'Installing the screen locker...'

  sudo pacman -S --noconfirm xautolock python-cairo python-pam &&
    yay -S --noconfirm --removemake python-screeninfo ||
    fail 'Failed to install the locker dependencies'

  echo -e 'Locker dependencies have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local xsecurelock_home="/home/${user_name}/xsecurelock"

  git clone https://github.com/tzeikob/xsecurelock.git "${xsecurelock_home}" &&
    cd "${xsecurelock_home}" &&
    sh autogen.sh &&
    ./configure --with-pam-service-name=system-auth &&
    make &&
    sudo make install &&
    cd ~ &&
    rm -rf "${xsecurelock_home}" || fail 'Failed to install xsecurelock'
  
  echo -e 'Xsecurelock has been installed'

  sudo cp /opt/stack/configs/xsecurelock/hook /usr/lib/systemd/system-sleep/locker ||
    fail 'Failed to copy the sleep hook'
  
  echo -e 'Sleep hook has been copied'

  local user_id=''
  user_id="$(id -u "${user_name}")" || fail 'Failed to get the user id'

  local service_file="/etc/systemd/system/lock@.service"

  sudo cp /opt/stack/configs/xsecurelock/service "${service_file}" &&
    sudo sed -i "s/#USER_ID/${user_id}/g" "${service_file}" &&
    sudo systemctl enable lock@${user_name}.service ||
    fail 'Failed to enable locker service'

  echo -e 'Locker service has been enabled'

  echo -e 'Screen locker has been installed'
}

# Installs the notifications server.
install_notification_server () {
  echo -e 'Installing notifications server...'

  sudo pacman -S --noconfirm dunst || fail 'Failed to install dunst'

  echo -e 'Dunst has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/dunst"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/dunst/dunstrc "${config_home}" &&
    cp /opt/stack/configs/dunst/hook "${config_home}" ||
    fail 'Failed to copy notifications server config files'

  echo -e 'Notifications server has been installed'
}

# Installs the file manager.
install_file_manager () {
  echo -e 'Installing the file manager...'

  sudo pacman -S --noconfirm nnn fzf || fail 'Failed to install nnn'

  echo -e 'Nnn has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/nnn"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/nnn/env "${config_home}" || fail 'Failed to copy the env file'
  
  echo -e 'Env file has been copied'

  echo -e 'Installing file manager plugins...'

  # Todo: get current working directory error
  local pluggins_url='https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs'

  curl "${pluggins_url}" -sSLo "${config_home}/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 &&
    cd "/home/${user_name}" &&
    HOME="/home/${user_name}" sh "${config_home}/getplugs" ||
    fail 'Failed to install extra plugins'

  echo -e 'Extra plugins have been installed'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nsource "${HOME}/.config/nnn/env"' >> "${bashrc_file}" &&
    echo 'alias N="sudo -E nnn -dH"' >> "${bashrc_file}" ||
    fail 'Failed to add hooks in .bashrc file'

  echo -e 'File manager hooks added in .bashrc file'

  mkdir -p "/home/${user_name}"/{downloads,documents,data,sources,mounts} &&
    mkdir -p "/home/${user_name}"/{images,audios,videos} &&
    cp /opt/stack/configs/nnn/user.dirs "/home/${user_name}/.config/user-dirs.dirs" ||
    fail 'Failed to create home directories'
  
  echo -e 'Home directories have been created'

  printf '%s\n' \
    '[Default Applications]' \
    'inode/directory=nnn.desktop' > "/home/${user_name}/.config/mimeapps.list" &&
    chmod 644 "/home/${user_name}/.config/mimeapps.list" ||
    fail 'Failed to create the applications mime type file'

  echo -e 'Application mime types file has been created'

  echo -e 'File manager has been installed'
}

# Installs the trash manager.
install_trash_manager () {
  echo -e 'Installing the trash manager...'

  sudo pacman -S --noconfirm trash-cli || fail 'Failed to install trash-cli'

  echo -e 'Trash-cli has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e "\nalias sudo='sudo '" >> "${bashrc_file}" &&
    echo "alias tt='trash-put -i'" >> "${bashrc_file}" &&
    echo "alias rm='rm -i'" >> "${bashrc_file}" || fail 'Failed to add aliases to .bashrc file'
  
  echo -e 'Aliases have been added to .bashrc file'

  bashrc_file='/root/.bashrc'
  
  echo -e "\nalias sudo='sudo '" | sudo tee -a "${bashrc_file}" > /dev/null &&
    echo "alias tt='trash-put -i'" | sudo tee -a "${bashrc_file}" > /dev/null &&
    echo "alias rm='rm -i'" | sudo tee -a "${bashrc_file}" > /dev/null ||
    fail 'Failed to add aliases to root .bashrc file'
  
  echo -e 'Aliases have been added to root .bashrc file'

  echo -e 'Trash manager has been installed'
}

# Installs the virtual terminals.
install_terminals () {
  echo -e 'Installing virtual terminals...'

  sudo pacman -S --noconfirm alacritty cool-retro-term ||
    fail 'Failed to install terminal packages'

  echo -e 'Alacritty and cool-retro-term have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/alacritty"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/alacritty/alacritty.toml "${config_home}" ||
    fail 'Failed to copy the alacritty config file'
  
  echo -e 'Alacritty config file has been copied'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport TERMINAL=alacritty' >> "${bashrc_file}" &&
    sed -i '/PS1.*/d' "${bashrc_file}" &&
    cat /opt/stack/configs/alacritty/user.prompt >> "${bashrc_file}" ||
    fail 'Failed to add hooks in the .bashrc file'
  
  echo -e 'Hooks have been added in the .bashrc file'

  sudo sed -i '/PS1.*/d' /root/.bashrc &&
    cat /opt/stack/configs/alacritty/root.prompt | sudo tee -a /root/.bashrc > /dev/null ||
    fail 'Failed to add hooks in the root .bashrc file'

  echo -e 'Hooks have been added in the root .bashrc file'

  echo -e 'Virtual terminals have been installed'
}

# Installs the text editor.
install_text_editor () {
  echo -e 'Installing the text editor...'

  sudo pacman -S --noconfirm helix || fail 'Failed to install helix'

  echo -e 'Helix has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport EDITOR=helix' >> "${bashrc_file}" ||
    fail 'Failed to set helix as default editor'

  echo -e 'Helix set as default editor'

  echo -e 'Text editor has been installed'
}

# Installs the web browsers.
install_web_browsers () {
  echo -e 'Installing the web browsers...'

  sudo pacman -S --noconfirm firefox torbrowser-launcher &&
    yay -S --noconfirm --removemake google-chrome brave-bin || fail 'Failed to install web browsers'

  echo -e 'Web browsers have been installed'
}

# Installing monitoring tools.
install_monitoring_tools () {
  echo -e 'Installing monitoring tools...'

  sudo pacman -S --noconfirm htop glances || fail 'Failed to install monitoring tools'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

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
   'Keywords=Monitor;Resources;System' | sudo tee "${desktop_file}" > /dev/null ||
   fail 'Failed to create the desktop file'

  echo -e 'Monitoring tools have been installed'
}

# Installs the print screen and recording casters.
install_screen_casters () {
  echo -e 'Installing screen casting tools...'

  sudo pacman -S --noconfirm scrot &&
    yay -S --noconfirm --removemake --mflags --nocheck slop screencast ||
    fail 'Failed to install screen casting tools'

  echo -e 'Screen casting tools have been installed'
}

# Installs the calculator.
install_calculator () {
  echo -e 'Installing the calculator...'

  yay -S --noconfirm --removemake libqalculate || fail 'Failed to install qalculate'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

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
    'Keywords=Calc;Math' | sudo tee "${desktop_file}" > /dev/null ||
    fail 'Failed to create desktop file'

  echo -e 'Calculator has been installed'
}

# Installs the media viewer.
install_media_viewer () {
  echo -e 'Installing the media viewer...'

  sudo pacman -S --noconfirm sxiv || fail 'Failed to install sxiv'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'image/jpeg=sxiv.desktop' \
    'image/jpg=sxiv.desktop' \
    'image/png=sxiv.desktop' \
    'image/tiff=sxiv.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add image mime types'
  
  echo -e 'Image mime types have been added'
  
  echo -e 'Media viewer has been installed'
}

# Installs the music player.
install_music_player () {
  echo -e 'Installing the music player...'
  
  sudo pacman -S --noconfirm mpd ncmpcpp || fail 'Failed to install the music player'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  local mpd_home="/${config_home}/mpd"

  mkdir -p "${mpd_home}"/{playlists,database} ||
    fail 'Failed to create mpd config directories'

  cp /opt/stack/configs/mpd/conf "${mpd_home}/mpd.conf" ||
    fail 'Failed to copy the mpd config file'

  local ncmpcpp_home="/${config_home}/ncmpcpp"

  mkdir -p "${ncmpcpp_home}" &&
    cp /opt/stack/configs/ncmpcpp/config "${ncmpcpp_home}/config" ||
    fail 'Failed to copy ncmpcpp config file'

  sudo systemctl --user enable mpd.service || fail 'Failed to enable mpd service'

  echo -e 'Mpd service has been enabled'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

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
    'Keywords=Music;Player;Audio' | sudo tee "${desktop_file}" > /dev/null ||
    fail 'Failed to create the desktop file'
  
  printf '%s\n' \
    'audio/mpeg=ncmpcpp.desktop' \
    'audio/mp3=ncmpcpp.desktop' \
    'audio/flac=ncmpcpp.desktop' \
    'audio/midi=ncmpcpp.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add audio mime types'
  
  echo -e 'Audio mime types have been added'
  
  echo -e 'Music player has been installed'
}

# Installs the video media player.
install_video_player () {
  echo -e 'Installing video media player...'

  sudo pacman -S --noconfirm mpv || fail 'Failed to install mpv'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'video/mp4=mpv.desktop' \
    'video/mkv=mpv.desktop' \
    'video/mov=mpv.desktop' \
    'video/mpeg=mpv.desktop' \
    'video/avi=mpv.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add video mime types'
  
  echo -e 'Video mime types have been added'
  
  echo -e 'Video media player has been installed'
}

# Installs the audio and video media codecs.
install_media_codecs () {
  echo -e 'Installing audio and video media codecs...'

  sudo pacman -S --noconfirm \
    faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack ||
    fail 'Failed to install audio and video codecs'

  echo -e 'Media codecs have been installed'
}

# Installs the office tools.
install_office_tools () {
  echo -e 'Installing the office tools...'

  sudo pacman -S --noconfirm libreoffice-fresh ||
    fail 'Failed to install office tools'

  echo -e 'Office tools have been installed'
}

# Installs the pdf and epub readers.
install_readers () {
  echo -e 'Installing pdf and epub readers...'

  sudo pacman -S --noconfirm foliate &&
    yay -S --noconfirm --useask --removemake --diffmenu=false evince-no-gnome poppler ||
    fail 'Failed to install pdf and epub readers'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' \
    'application/pdf=org.gnome.Evince.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add pdf and epub mime types'
  
  echo -e 'Pdf and epub mime types have been added'

  echo -e 'Pdf and epub readers have been installed'
}

# Installs the torrent client.
install_torrent_client () {
  echo -e 'Installing the torrent client...'

  sudo pacman -S --noconfirm transmission-cli || fail 'Failed to install transmission-cli'

  echo -e 'Torrent client has been installed'
}

# Installs the desktop and ui theme.
install_theme () {
  echo -e 'Installing the desktop theme...'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  sudo curl "${theme_url}" -sSLo /usr/share/themes/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 &&
    sudo unzip -q /usr/share/themes/Dracula.zip -d /usr/share/themes &&
    sudo mv /usr/share/themes/gtk-master /usr/share/themes/Dracula &&
    sudo rm -f /usr/share/themes/Dracula.zip ||
    fail 'Failed to install theme files'

  echo -e 'Theme files have been installed'

  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  sudo curl "${icons_url}" -sSLo /usr/share/icons/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 &&
    sudo unzip -q /usr/share/icons/Dracula.zip -d /usr/share/icons &&
    sudo rm -f /usr/share/icons/Dracula.zip ||
    fail 'Failed to install icon files'

  echo -e 'Icon files have been installed'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  sudo wget "${cursors_url}" -qO /usr/share/icons/breeze-snow.tgz \
    --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 &&
    sudo tar -xzf /usr/share/icons/breeze-snow.tgz -C /usr/share/icons &&
    sudo sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' /usr/share/icons/default/index.theme &&
    sudo rm -f /usr/share/icons/breeze-snow.tgz ||
    fail 'Failed to install cursors'

  echo -e 'Cursors have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/gtk-3.0"
  
  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/gtk/settings.ini "${config_home}" ||
    fail 'Failed to copy gtk settings file'

  echo -e 'Gtk settings file has been copied'

  local wallpapers_home="/home/${user_name}/.local/share/wallpapers"

  mkdir -p "${wallpapers_home}" &&
    cp /opt/stack/resources/wallpapers/* "${wallpapers_home}" ||
    fail 'Failed to copy wallpapers'
  
  echo -e 'Wallpapers have been copied'

  config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${config_home}/desktop.json" ||
   fail 'Failed to add wallpaper into the desktop settings file'

  echo -e 'Wallpaper has been set into the desktop settings file'

  echo -e 'Desktop theme has been setup'
}

# Installs extras system fonts.
install_fonts () {
  echo -e 'Installing extra fonts...'

  local fonts_home='/usr/share/fonts/extra-fonts'

  sudo mkdir -p "${fonts_home}" || fail 'Failed to create fonts home directory'

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
    name="$(echo "${font}" | cut -d ' ' -f 1)" || fail

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" || fail

    sudo curl "${url}" -sSLo "${fonts_home}/${name}.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 &&
      sudo unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" &&
      sudo chmod -R 755 "${fonts_home}/${name}" &&
      sudo rm -f "${fonts_home}/${name}.zip" ||
      fail "Failed to install font ${name}"

    echo -e "Font ${name} has been installed"
  done

  echo -e 'Update the fonts cache...'

  fc-cache -f || fail 'Failed to update the fonts cache'

  echo -e 'Fonts cache has been updated'

  echo -e 'Installing some extra glyphs...'

  sudo pacman -S --noconfirm \
    ttf-font-awesome noto-fonts-emoji || fail 'Failed to install extra glyphs'

  echo -e 'Extra glyphs have been installed'
}

# Installs various system sound resources.
install_sounds () {
  echo -e 'Installing extra system sounds...'

  local sounds_home='/usr/share/sounds/stack'
  
  sudo mkdir -p "${sounds_home}" &&
    sudo cp /opt/stack/resources/sounds/normal.wav "${sounds_home}" &&
    sudo cp /opt/stack/resources/sounds/critical.wav "${sounds_home}" ||
    fail 'Failed to copy system sound files'

  echo -e 'System sounds have been installed'
}

# Installs various extra packages.
install_extra_packages () {
  echo -e 'Installing some extra packages...'

  yay -S --noconfirm --removemake \
    digimend-kernel-drivers-dkms-git xkblayout-state-git ||
    fail 'Failed to install extra packages'
  
  echo -e 'Extra packages have been installed'
}

echo -e 'Installing the desktop...'

if equals "$(id -u)" 0; then
  fail 'Script desktop.sh must be run as non root user'
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

sleep 3
