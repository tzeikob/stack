#!/usr/bin/env bash

install_terminal () {
  echo "Installing the alacritty terminal..."

  sudo pacman -S --noconfirm alacritty

  local CONFIG_HOME=~/.config/alacritty

  mkdir -p "$CONFIG_HOME"
  cp ~/stack/apps/alacritty/alacritty.yml "$CONFIG_HOME"
  cp ~/stack/apps/alacritty/prompt.sh "$CONFIG_HOME"

  local BASHRC_FILE=~/.bashrc
  sed -i '/PS1.*/d' "$BASHRC_FILE"
  echo -e "\nsource /home/$USER/.config/alacritty/prompt.sh" >> "$BASHRC_FILE"

  sudo cp /etc/skel/.bash_profile /root
  sudo cp /etc/skel/.bashrc /root

  BASHRC_FILE=/root/.bashrc
  sudo sed -i '/PS1.*/d' "$BASHRC_FILE"
  echo "PS1='\[\e[1;31m\]\u\[\e[m\] \W  '" | sudo tee -a "$BASHRC_FILE" > /dev/null

  echo "Terminal prompt hooks have been set"
  echo "The terminal has been installed"
}

install_music_player () {
  echo "Installing the music player..."

  sudo pacman -S --noconfirm moc

  echo "Installing codecs and various dependecies..."

  sudo pacman -S --noconfirm --asdeps --needed faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack

  local CONFIG_HOME=~/.moc

  mkdir -p "$CONFIG_HOME" "$CONFIG_HOME/themes"

  cp ~/stack/apps/moc/config "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/config"

  cp ~/stack/apps/moc/theme "$CONFIG_HOME/themes"
  chmod 644 "$CONFIG_HOME/themes/theme"

  sudo cp ~/stack/apps/moc/desktop /usr/share/applications/moc.desktop

  echo -e "Music player has been installed"
}

install_document_viewers () {
  echo "Installing various document viewers..."

  sudo pacman -S --noconfirm xournalpp poppler foliate

  yay -S --noconfirm --useask --removemake --nodiffmenu evince-no-gnome > /dev/null

  echo "Document viewers have been installed"
}

install_other_apps () {
  echo "Installing other apps..."

  sudo pacman -S --noconfirm firefox sxiv mpv

  echo "Other apps have been installed"
}

setup_mimes () {
  echo "Setting up application mime types..."

  printf '%s\n' \
    '[Default Applications]' \
    'inode/directory=nnn.desktop' \
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
    'video/avi=mpv.desktop' \
    'application/pdf=org.gnome.Evince.desktop' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' \
    'application/x-xojpp=com.github.xournalapp.xournalapp.desktop' \
    'application/x-xopp=com.github.xournalapp.xournalapp.desktop' \
    'application/x-xopt=com.github.xournalapp.xournalapp.desktop' \
    > ~/.config/mimeapps.list

  chmod 644 ~/.config/mimeapps.list

  echo "Application mime types have been set"
}

echo -e "\nStarting the apps installation process..."

source ~/stack/.options

install_terminal &&
  install_music_player &&
  install_document_viewers &&
  install_other_apps &&
  setup_mimes

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
