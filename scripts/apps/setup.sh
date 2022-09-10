#!/usr/bin/env bash

setup_terminal () {
  echo "Installing the alacritty terminal..."

  sudo pacman -S --noconfirm alacritty

  local CONFIG_HOME=~/.config/alacritty
  local CONFIG_FILE="$CONFIG_HOME/alacritty.yml"
  local PROMPT_FILE="$CONFIG_HOME/prompt.sh"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/scripts/apps/alacritty/alacritty.yml "$CONFIG_FILE"
  cp ~/stack/scripts/apps/alacritty/prompt.sh "$PROMPT_FILE"

  local BASHRC_FILE=~/.bashrc

  sed -i '/PS1.*/d' "$BASHRC_FILE"
  echo -e "\nsource /home/$USER/.config/alacritty/prompt.sh" >> "$BASHRC_FILE"

  sudo cp /etc/skel/.bash_profile /root
  sudo cp /etc/skel/.bashrc /root

  sudo sed -i '/PS1.*/d' /root/.bashrc
  echo "PS1='\[\e[1;31m\]\u\[\e[m\] \W  '" | sudo tee -a /root/.bashrc > /dev/null

  echo "Terminal prompt hooks have been set"
  echo "The terminal has been installed"
}

setup_music_player () {
  echo "Installing the music player..."

  sudo pacman -S --noconfirm moc

  echo "Installing codecs and various dependecies..."

  sudo pacman -S --noconfirm --asdeps --needed faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack

  local CONFIG_HOME=~/.moc

  mkdir -p "$CONFIG_HOME" "$CONFIG_HOME/themes"

  cp ~/stack/scripts/apps/moc/config "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME/config"

  cp ~/stack/scripts/apps/moc/theme "$CONFIG_HOME/themes"
  chmod 644 "$CONFIG_HOME/themes/theme"

  sudo cp ~/stack/scripts/apps/moc/desktop /usr/share/applications/moc.desktop

  echo -e "Music player has been installed"
}

setup_document_viewers () {
  echo "Installing various document viewers..."

  sudo pacman -S --noconfirm xournalpp poppler foliate

  yay -S --useask --removemake --nodiffmenu evince-no-gnome > /dev/null

  echo "Document viewers have been installed"
}

echo -e "\nStarting the apps installation process..."

source ~/stack/.options

setup_terminal &&
  setup_music_player &&
  setup_document_viewers

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
