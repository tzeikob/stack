#!/usr/bin/env bash


echo -e "Starting the stack installation process..."

read -p "Do you want to install a desktop environment? [Y/n] " answer
answer=${answer:-"yes"}

if [[ $answer =~ ^(yes|y)$ ]]; then
  echo -e "Installing the BSPWM window manager..."

  pacman -S firefox sxiv mpv

  echo -e "Setting up the desktop environment configuration..."

  curl $config_url/mime -sSo /home/$username/.config/mimeapps.list \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/mimeapps.list

  chown -R $username:$username /home/$username/.config

  echo "udiskie --notify-command \"ln -s /run/media/$USER $HOME/media/local\" &" >> /home/$username/.xinitrc

  chown -R $username:$username /home/$username/.xinitrc

  echo -e "Installing the file manager..."

  pacman -S nnn fzf

  mkdir -p /home/$username/.config/nnn
  curl $config_url/nnn -sSo /home/$username/.config/nnn/.env_vars \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chown -R $username:$username /home/$username/.config/nnn/
  echo -e '\nsource $HOME/.config/nnn/.env_vars' >> /home/$username/.bashrc

  sed -i 's/Exec=nnn/Exec=alacritty -e nnn/' /usr/share/applications/nnn.desktop

  echo -e "File manager set to get open via terminal in xdg-open calls"

  echo -e "Installing extra nnn plugins..."

  curl https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs -sSLo ./nnn-getplugs \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  HOME=/home/$username sh ./nnn-getplugs > /dev/null
  rm -f ./nnn-getplugs

  cp /home/$username/.config/nnn/plugins/mocq /home/$username/.config/nnn/plugins/mocq.bak
  sed -ri 's/(.*)# mocp$/\1alacritty -e mocp \&/' /home/$username/.config/nnn/plugins/mocq

  curl $bin_url/remove-plugin -sSo /home/$username/.config/nnn/plugins/remove \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/nnn/plugins/remove

  curl $bin_url/trash-plugin -sSo /home/$username/.config/nnn/plugins/trash \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/nnn/plugins/trash

  curl $bin_url/mount-plugin -sSo /home/$username/.config/nnn/plugins/mount \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/nnn/plugins/mount

  chown -R $username:$username /home/$username/.config/nnn/plugins

  echo -e "Creating user home directories..."

  mkdir -p /home/$username/downloads \
    /home/$username/documents \
    /home/$username/images \
    /home/$username/audios \
    /home/$username/videos \
    /home/$username/virtuals \
    /home/$username/sources \
    /home/$username/data \
    /home/$username/media

  chown -R $username:$username /home/$username/downloads \
    /home/$username/documents \
    /home/$username/images \
    /home/$username/audios \
    /home/$username/videos \
    /home/$username/virtuals \
    /home/$username/sources \
    /home/$username/data \
    /home/$username/media

  echo -e "Main user home forders have been created"
  echo -e "File manager has been installed"

  echo -e "Installing the music player..."

  sudo pacman -S moc

  echo -e "Installing codecs and various dependecies..."

  sudo pacman -S --asdeps --needed faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack

  mkdir -p /home/$username/.moc/
  curl $config_url/moc.config -sSo /home/$username/.moc/config \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.moc/config

  mkdir -p /home/$username/.moc/themes
  curl $config_url/moc.theme -sSo /home/$username/.moc/themes/dark \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.moc/themes/dark

  chown -R $username:$username /home/$username/.moc/

  cat << EOF > /usr/share/applications/moc.desktop
[Desktop Entry]
Type=Application
Name=moc
comment=Console music player
Exec=alacritty -e mocp
Terminal=true
Icon=moc
MimeType=audio/mpeg
Catogories=Music;Player;ConsoleOnly
Keywords=Music;Player;Audio
EOF

  echo -e "Music player has been installed"

  echo -e "Installing various document viewers..."

  pacman -S xournalpp poppler foliate

  sudo -u $username yay -S --useask --removemake --nodiffmenu evince-no-gnome > /dev/null

  echo -e "Document viewers have been installed"

  echo -e "Installing the trash..."

  pacman -S trash-cli

  curl $bin_url/trash -sSo /usr/local/bin/trash \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /usr/local/bin/trash

  echo -e '\nalias rr="rm"' >> /home/$username/.bashrc
  echo -e 'alias tt="trash"\n' >> /home/$username/.bashrc

  echo -e "Trash has been installed successfully"

  echo -e "Desktop environment configuration is done"
else
  echo -e "Desktop environment has been skipped"
fi

echo -e "\nThe stack script has been completed"
echo -e "Exiting the script and prepare for reboot..."