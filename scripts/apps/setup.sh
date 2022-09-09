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

echo -e "\nStarting the apps installation process..."

source ~/stack/.options

setup_terminal

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
