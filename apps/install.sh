#!/usr/bin/env bash

set -Eeo pipefail

install_terminal () {
  echo "Installing the alacritty terminal..."

  sudo pacman -S --noconfirm alacritty || exit 1

  echo "export TERMINAL=alacritty" >> ~/.bashrc

  mkdir -p ~/.config/alacritty
  cp ~/stack/apps/alacritty/alacritty.yml ~/.config/alacritty

  sed -i '/PS1.*/d' ~/.bashrc
  printf '%s\n' \
    'branch () {' \
    '  git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/  [\\1]/"' \
    '}' \
    'PS1="\W\[\e[0;35m\]\$(branch)\[\e[m\]  "' >> ~/.bashrc

  sudo cp /etc/skel/.bash_profile /root
  sudo cp /etc/skel/.bashrc /root

  sudo sed -i '/PS1.*/d' /root/.bashrc
  echo "PS1='\[\e[1;31m\]\u\[\e[m\] \W  '" | sudo tee -a /root/.bashrc > /dev/null

  echo "Terminal prompt hooks have been set"
  echo "The terminal has been installed"
}

install_music_player () {
  echo "Installing the music player..."

  sudo pacman -S --noconfirm moc || exit 1

  echo "Installing codecs and various dependecies..."

  sudo pacman -S --noconfirm --asdeps --needed \
    faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack || exit 1

  local CONFIG_HOME=~/.moc
  mkdir -p "$CONFIG_HOME" "$CONFIG_HOME/themes"

  cp ~/stack/apps/moc/config "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/config"

  cp ~/stack/apps/moc/dark "$CONFIG_HOME/themes"
  chmod 644 "$CONFIG_HOME/themes/dark"

  sudo cp ~/stack/apps/moc/desktop /usr/share/applications/moc.desktop

  echo -e "Music player has been installed"
}

install_document_viewers () {
  echo "Installing various document viewers..."

  sudo pacman -S --noconfirm xournalpp poppler foliate || exit 1

  yay -S --noconfirm --useask --removemake --nodiffmenu evince-no-gnome > /dev/null || exit 1

  echo "Document viewers have been installed"
}

install_other_apps () {
  echo "Installing other apps..."

  sudo pacman -S --noconfirm firefox sxiv mpv || exit 1

  echo "Other apps have been installed"
}

setup_mimes () {
  echo "Setting up application mime types..."

  cp ~/stack/apps/mimes/app.list ~/.config/mimeapps.list
  chmod 644 ~/.config/mimeapps.list

  echo "Application mime types have been set"
}

echo -e "\nStarting the apps installation process..."

if [[ "$(id -u)" == "0" ]]; then
  echo -e "\nError: process must be run as non root user"
  echo "Process exiting with code 1..."
  exit 1
fi

source ~/stack/.options

install_terminal &&
  install_music_player &&
  install_document_viewers &&
  install_other_apps &&
  setup_mimes

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
