#!/usr/bin/env bash

set -Eeo pipefail

install_compositor () {
  echo "Installing the picom compositor..."

  sudo pacman -S --noconfirm picom || exit 1

  local CONFIG_HOME=~/.config/picom
  mkdir -p "$CONFIG_HOME"

  cp ~/stack/resources/picom/picom.conf "$CONFIG_HOME"

  if [ "$VIRTUAL_VENDOR" = "oracle" ]; then
    echo "Virtual box machine detected"

    sed -i 's/vsync = true;/vsync = false;/' "$CONFIG_HOME/picom.conf"

    echo -e "Vsync has been disabled"
  fi

  echo "picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &" >> ~/.xinitrc

  echo "Configuration has been set under ~/.config/picom"
  echo "Compositor has been installed"
}

install_window_manager () {
  echo "Installing BSPWM as the window manager..."

  sudo pacman -S --noconfirm bspwm || exit 1

  local CONFIG_HOME=~/.config/bspwm
  mkdir -p "$CONFIG_HOME"

  cp ~/stack/resources/bspwm/bspwmrc "$CONFIG_HOME"
  chmod 755 "$CONFIG_HOME/bspwmrc"

  cp ~/stack/resources/bspwm/rules "$CONFIG_HOME"
  chmod 755 "$CONFIG_HOME/rules"

  cp ~/stack/resources/bspwm/resize.sh "$CONFIG_HOME"
  chmod 755 "$CONFIG_HOME/resize.sh"

  echo "exec bspwm" >> ~/.xinitrc

  echo "Window manager has been installed"
}

install_terminals () {
  echo "Installing virtual terminals..."

  echo "Installing alacritty as the terminal..."

  sudo pacman -S --noconfirm alacritty || exit 1

  echo "export TERMINAL=alacritty" >> ~/.bashrc

  mkdir -p ~/.config/alacritty
  cp ~/stack/resources/alacritty/alacritty.yml ~/.config/alacritty

  sed -i '/PS1.*/d' ~/.bashrc
  printf '%s\n' \
    'branch () {' \
    '  git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/  [\\1]/"' \
    '}' \
    'PS1="\W\[\e[0;35m\]\$(branch)\[\e[m\]  "' \
    'PS2=" "' >> ~/.bashrc

  sudo cp /etc/skel/.bash_profile /root
  sudo cp /etc/skel/.bashrc /root

  sudo sed -i '/PS1.*/d' /root/.bashrc
  echo "PS1='\[\e[1;31m\]\u\[\e[m\] \W  '" | sudo tee -a /root/.bashrc > /dev/null
  echo "PS2=' '" | sudo tee -a /root/.bashrc > /dev/null

  echo "Terminal prompt hooks have been set"

  echo "Installing the cool retro terminal..."

  sudo pacman -S --noconfirm cool-retro-term || exit 1

  echo "Virtual terminals have been installed"
}

install_file_manager () {
  echo "Installing the file manager..."

  sudo pacman -S --noconfirm nnn fzf || exit 1

  echo 'alias N="sudo -E nnn -dH"' >> ~/.bashrc
  echo 'export EDITOR=nano' >> ~/.bashrc

  local CONFIG_HOME=~/.config/nnn
  mkdir -p "$CONFIG_HOME"

  cp ~/stack/resources/nnn/env "$CONFIG_HOME"
  echo 'source "$HOME/.config/nnn/env"' >> ~/.bashrc

  echo "Installing extra nnn plugins..."

  local GETPLUGS_URL="https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs"

  curl "$GETPLUGS_URL" -sSLo "$CONFIG_HOME/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1
  HOME=~/ sh "$CONFIG_HOME/getplugs" > /dev/null || exit 1

  sed -ri 's/(.*)# mocp$/\1\$TERMINAL -e mocp \&/' "$CONFIG_HOME/plugins/mocq"

  echo "Extra plugins have been installed"

  cp ~/stack/resources/nnn/remove "$CONFIG_HOME/plugins"
  chmod 755 "$CONFIG_HOME/plugins/remove"

  echo "Plugin remove has been installed"

  cp ~/stack/resources/nnn/trash "$CONFIG_HOME/plugins"
  chmod 755 "$CONFIG_HOME/plugins/trash"

  echo "Plugin trash has been installed"

  cp ~/stack/resources/nnn/mount "$CONFIG_HOME/plugins"
  chmod 755 "$CONFIG_HOME/plugins/mount"

  echo "Plugin mount has been installed"

  mkdir -p ~/downloads ~/documents ~/images ~/audios ~/videos ~/virtuals ~/sources ~/data ~/mount
  cp ~/stack/resources/nnn/user.dirs ~/.config/user-dirs.dirs

  echo "User home directories have been created"

  printf '%s\n' \
    '[Default Applications]' \
    'inode/directory=nnn.desktop' > ~/.config/mimeapps.list

  chmod 644 ~/.config/mimeapps.list

  echo "Application mime types file has been created"
  echo "File manager has been installed"
}

install_trash () {
  echo "Installing the trash via the trash-cli..."

  sudo pacman -S --noconfirm trash-cli || exit 1

  sudo cp ~/stack/resources/trash-cli/alias.sh /usr/local/bin/trash
  sudo chmod 755 /usr/local/bin/trash

  echo "Added a proxy binary to orchestrate trash-cli commands"

  echo 'alias rr=rm' >> ~/.bashrc
  echo 'alias tt=trash' >> ~/.bashrc

  echo "Set aliases for rm and trash"
  echo "Trash has been installed"
}

install_bars () {
  echo "Setting up the status bar via polybar..."

  sudo pacman -S --noconfirm polybar || exit 1

  local CONFIG_HOME=~/.config/polybar
  mkdir -p "$CONFIG_HOME"

  cp ~/stack/resources/polybar/config.ini "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/config.ini"

  cp ~/stack/resources/polybar/launch.sh "$CONFIG_HOME"
  chmod 755 "$CONFIG_HOME/launch.sh"

  echo "Polybar launcher script has been installed"
  echo "Status bars have been installed"
}

install_notifier () {
  echo "Installing notifications server..."

  sudo pacman -S --noconfirm dunst || exit 1

  mkdir -p ~/.config/dunst
  cp ~/stack/resources/dunst/dunstrc ~/.config/dunst
  cp ~/stack/resources/dunst/alert.sh ~/.config/dunst

  sudo cp ~/stack/resources/dunst/drip.ogg /usr/share/sounds/dunst

  echo "Notifications server has been installed"
}

install_launchers () {
  echo "Setting up the launchers via rofi..."

  sudo pacman -S --noconfirm rofi rofi-emoji rofi-calc xsel || exit 1

  local CONFIG_HOME=~/.config/rofi
  mkdir -p "$CONFIG_HOME"

  cp ~/stack/resources/rofi/config.rasi "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/config.rasi"

  sudo cp ~/stack/resources/rofi/power /usr/local/bin
  sudo chmod 755 /usr/local/bin/power

  echo "Power launcher has been installed"
  echo "Launchers has been installed"
}

install_login_screen () {
  echo "Setting up the getty login screen..."

  sudo pacman -S --noconfirm figlet || exit 1
  yay -S --noconfirm --removemake figlet-fonts figlet-fonts-extra || exit 1

  sudo mv /etc/issue /etc/issue.bak
  sudo cp ~/stack/resources/getty/issue.sh /etc

  echo "Welcome screen theme has been set"

  sudo cp ~/stack/resources/getty/login-issue.service /etc/systemd/system
  sudo systemctl enable login-issue || exit 1

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/getty@.service
  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/serial-getty@.service

  echo "Login issue service has been enabled"
  echo "Login screen has been set"
}

install_monitors () {
  echo "Installing monitoring tools..."

  sudo pacman -S --noconfirm htop glances || exit 1

  mkdir -p ~/.local/share/applications
  cp ~/stack/resources/glances/desktop ~/.local/share/applications/glances.desktop

  echo "Monitoring tools have been installed"
}

install_break_timer () {
  echo "Installing the break timer tool..."

  yay -S --noconfirm --removemake breaktimer-bin || exit 1

  cp ~/stack/resources/break/config.json ~/.config/BreakTimer/config.json

  echo "Break timer tool has been installed"
}

install_screen_locker () {
  echo "Installing the screen locker..."

  cd ~/
  curl https://dl.suckless.org/tools/slock-1.4.tar.gz -sSLo ./slock-1.4.tar.gz \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1
  tar -xzvf ./slock-1.4.tar.gz || exit 1

  cd ~/slock-1.4
  curl https://tools.suckless.org/slock/patches/control-clear/slock-git-20161012-control-clear.diff -sSLo ./control-clear.diff \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1
  patch -p1 < ./control-clear.diff || exit 1

  echo "Control clear patch has been added"

  sed -ri 's/(.*)nogroup(.*)/\1nobody\2/' ./config.def.h
  sed -ri 's/.*INIT.*/  [INIT] = "#1a1b26",/' ./config.def.h
  sed -ri 's/.*INPUT.*/  [INPUT] = "#383c4a",/' ./config.def.h
  sed -ri 's/.*FAILED.*/  [FAILED] = "#ff2369"/' ./config.def.h
  sed -ri 's/(.*)controlkeyclear.*/\1controlkeyclear = 1;/' ./config.def.h

  echo "Lock screen color theme has been applied"

  sudo make install || exit 1

  cd / && rm -rf ~/slock-1.4 ~/slock-1.4.tar.gz

  echo -e "Screen locker has been installed"
}

install_screencasters () {
  echo "Installing screen casting tools..."

  sudo pacman -S --noconfirm scrot || exit 1

  yay -S --noconfirm --removemake --mflags --nocheck slop screencast || exit 1

  echo "Screen casting tools have been installed"
}

install_calculator () {
  echo "Installing calculator..."

  yay -S --noconfirm --removemake libqalculate kalker || exit 1

  mkdir -p ~/.local/share/applications
  cp ~/stack/resources/kalker/desktop ~/.local/share/applications/kalker.desktop
  cp ~/stack/resources/qalculate/desktop ~/.local/share/applications/qalculate.desktop

  echo "Calculator has been installed"
}

install_media_apps () {
  echo "Installing media applications..."

  sudo pacman -S --noconfirm moc mpv sxiv || exit 1

  echo "Installing codecs and various dependecies..."

  sudo pacman -S --noconfirm --asdeps --needed \
    faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack || exit 1

  local CONFIG_HOME=~/.moc
  mkdir -p "$CONFIG_HOME" "$CONFIG_HOME/themes"

  cp ~/stack/resources/moc/config "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/config"

  cp ~/stack/resources/moc/dark "$CONFIG_HOME/themes"
  chmod 644 "$CONFIG_HOME/themes/dark"

  mkdir -p ~/.local/share/applications
  cp ~/stack/resources/moc/desktop ~/.local/share/applications/moc.desktop

  printf '%s\n' \
    'image/jpeg=sxiv.desktop' \
    'image/jpg=sxiv.desktop' \
    'image/png=sxiv.desktop' \
    'image/tiff=sxiv.desktop' \
    'audio/mpeg=moc.desktop' \
    'audio/mp3=moc.desktop' \
    'audio/flac=moc.desktop' \
    'audio/midi=moc.desktop' \
    'video/mp4=mpv.desktop' \
    'video/mkv=mpv.desktop' \
    'video/mov=mpv.desktop' \
    'video/mpeg=mpv.desktop' \
    'video/avi=mpv.desktop' >> ~/.config/mimeapps.list
  
  echo "Mime types have been added"
  echo -e "Media applications have been installed"
}

install_theme () {
  echo "Installing theme, icons and cursors..."

  local THEME_URL="https://github.com/dracula/gtk/archive/master.zip"

  sudo curl "$THEME_URL" -sSLo /usr/share/themes/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  sudo unzip -q /usr/share/themes/Dracula.zip -d /usr/share/themes || exit 1
  sudo mv /usr/share/themes/gtk-master /usr/share/themes/Dracula
  sudo rm -f /usr/share/themes/Dracula.zip

  echo "Theme has been installed"

  local ICONS_URL="https://github.com/dracula/gtk/files/5214870/Dracula.zip"

  sudo curl "$ICONS_URL" -sSLo /usr/share/icons/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  sudo unzip -q /usr/share/icons/Dracula.zip -d /usr/share/icons || exit 1
  sudo rm -f /usr/share/icons/Dracula.zip

  echo "Theme icons have been installed"

  local CURSORS_URL="https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1"

  sudo wget "$CURSORS_URL" -qO /usr/share/icons/breeze-snow.tgz \
    --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 || exit 1

  sudo tar -xzf /usr/share/icons/breeze-snow.tgz -C /usr/share/icons || exit 1
  sudo sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' /usr/share/icons/default/index.theme
  sudo rm -f /usr/share/icons/breeze-snow.tgz

  echo "Cursors have been installed"

  local GTK_HOME=~/.config/gtk-3.0
  mkdir -p "$GTK_HOME"

  cp ~/stack/resources/gtk/settings.ini "$GTK_HOME"

  mkdir -p ~/images/wallpapers
  cp ~/stack/resources/feh/wallpaper.jpeg ~/images/wallpapers/wallpaper.jpeg

  echo "Default wallpaper has been saved to ~/images/wallpapers"
  echo "Theme has been setup"
}

install_fonts () {
  echo -e "\nInstalling extra fonts..."

  local FONTS_HOME="/usr/share/fonts/extra-fonts"
  sudo mkdir -p "$FONTS_HOME"

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
    local NAME=$(echo "$FONT" | cut -d " " -f 1)
    local URL=$(echo "$FONT" | cut -d " " -f 2)

    sudo curl "$URL" -sSLo "$FONTS_HOME/$NAME.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1
    sudo unzip -q "$FONTS_HOME/$NAME.zip" -d "$FONTS_HOME/$NAME" || exit 1

    sudo find "$FONTS_HOME/$NAME/" -depth -mindepth 1 -iname "*windows*" -exec rm -r {} +
    sudo find "$FONTS_HOME/$NAME/" -depth -mindepth 1 -iname "*macosx*" -exec rm -r {} +
    sudo find "$FONTS_HOME/$NAME/" -depth -type f -not -iname "*ttf*" -delete
    sudo find "$FONTS_HOME/$NAME/" -empty -type d -delete
    sudo rm -f "$FONTS_HOME/$NAME.zip"

    echo "Font $NAME has been installed"
  done

  fc-cache -f

  echo "Fonts have been installed under $FONTS_HOME"

  echo -e "\nInstalling some extra font glyphs..."

  sudo pacman -S --noconfirm \
    ttf-font-awesome noto-fonts-emoji || exit 1

  echo "Extra font glyphs have been installed"
}

setup_bindings () {
  echo "Setting up key bindings via sxhkd..."

  sudo pacman -S --noconfirm sxhkd || exit 1

  local CONFIG_HOME=~/.config/sxhkd
  mkdir -p "$CONFIG_HOME"

  cp ~/stack/resources/sxhkd/sxhkdrc "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/sxhkdrc"

  echo "Key bindings have been set"
}

echo -e "\nStarting the desktop installation process..."

if [[ "$(id -u)" == "0" ]]; then
  echo -e "\nError: process must be run as non root user"
  echo "Process exiting with code 1..."
  exit 1
fi

source ~/stack/.options

install_compositor &&
  install_window_manager &&
  install_terminals &&
  install_file_manager &&
  install_trash &&
  install_bars &&
  install_notifier &&
  install_launchers &&
  install_login_screen &&
  install_monitors &&
  install_break_timer &&
  install_screen_locker &&
  install_screencasters &&
  install_calculator &&
  install_media_apps &&
  install_theme &&
  install_fonts &&
  setup_bindings

echo -e "\nSetting up the desktop has been completed"
echo "Moving to the next process..."
sleep 5
