# Libre Office
read -p "Do you want to install Libre Office?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Adding the Libre Office PPA repository."
  sudo add-apt-repository ppa:libreoffice/ppa

  echo -e "Installing the Libre Office."
  sudo apt update
  sudo apt install libreoffice

  echo -e "${S}Libre Office has been installed successfully.${R}\n"
fi

# Docker
read -p "Do you want to install Docker?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing Docker community edition."
  sudo apt update
  sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  sudo apt update
  sudo apt install docker-ce docker-ce-cli containerd.io

  echo -e "Creating Docker user group."
  sudo groupadd docker

  echo -e "Adding current user to the Docker user group."
  sudo usermod -aG docker $USER

  compose_version="1.24.1"
  read -p "Which version of the Docker Compose do you want to install:($compose_version) " version

  if [[ $version != "" ]]; then
    compose_version=$version
  fi

  sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  echo -e "${S}Docker has been installed successfully.${R}\n"
fi

# Editors
editors=$workspace/editors

# Atom
read -p "Do you want to install Atom?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing the latest version of Atom."
  wget -q https://packagecloud.io/AtomEditor/atom/gpgkey -O- | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main"
  sudo apt update
  sudo apt install atom

  # Adding atom desktop entry in favorites applications
  favorites=$favorites", 'atom.desktop'"

  echo -e "${S}Atom has been installed successfully.${R}\n"
fi

# Visual Studio
read -p "Do you want to install Visual Studio?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Downloading the latest version of Visual Studio."
  wget -q --show-progress -P $temp -O $temp/visual-studio.deb https://go.microsoft.com/fwlink/?LinkID=760868

  echo -e "Installing Visual Studio using deb packaging."
  sudo dpkg -i $temp/visual-studio.deb
  rm -rf $temp/visual-studio.deb

  # Adding vs desktop entry in favorites applications
  favorites=$favorites", 'code.desktop'"

  echo -e "${S}Visual Studio has been installed successfully.${R}\n"
fi

# IntelliJ
read -p "Do you want to install IntelliJ Community?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  ideaic=$editors/idea-ic
  mkdir -p $ideaic

  read -p "Enter the url to the IntelliJ tar.gz file: " url
  echo -e "Downloading the IntelliJ tar.gz file."
  ideaic_archive=$temp/ideaic.tar.gz
  wget -q --show-progress -P $temp -O $ideaic_archive $url

  echo -e "Extracting the IntelliJ files to ${V}$ideaic${R}."
  tar zxf $ideaic_archive -C $ideaic --strip-components 1
  rm -rf $ideaic_archive

  sudo ln -sfn $ideaic/bin/idea.sh /usr/local/bin/idea

  echo -e "Creating IntelliJ's application dock entry."

  desktop_file="/usr/share/applications/idea.desktop"
  sudo touch $desktop_file
  sudo echo "[Desktop Entry]" | sudo tee -a $desktop_file
  sudo echo "Type=Application" | sudo tee -a $desktop_file
  sudo echo "Name=IntelliJ Cummunity" | sudo tee -a $desktop_file
  sudo echo "Icon=$ideaic/bin/idea.png" | sudo tee -a $desktop_file
  sudo echo "Exec=$ideaic/bin/idea.sh" | sudo tee -a $desktop_file
  sudo echo "Comment=IntelliJ Community" | sudo tee -a $desktop_file
  sudo echo "Categories=Development;Code;" | sudo tee -a $desktop_file

  # Adding intelliJ desktop entry in favorites applications
  favorites=$favorites", 'idea.desktop'"

  echo -e "${S}IntelliJ has been installed successfully in $ideaic.${R}\n"
fi

# DBeaver
read -p "Do you want to install DBeaver?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  dbeaver=$editors/dbeaver
  mkdir -p $dbeaver

  echo -e "Downloading the latest version of the DBeaver tar.gz file."
  wget -q --show-progress -P $temp wget https://dbeaver.io/files/dbeaver-ce-latest-linux.gtk.x86_64.tar.gz

  echo -e "Extracting the DBeaver files to ${V}$dbeaver${R}."
  tar zxf $temp/dbeaver-ce* -C $dbeaver --strip-components 1
  rm -rf $temp/dbeaver-ce*

  sudo ln -sfn $dbeaver/dbeaver /usr/local/bin/dbeaver

  echo -e "Creating DBeaver's application dock entry."

  desktop_file="/usr/share/applications/dbeaver.desktop"
  sudo touch $desktop_file
  sudo echo "[Desktop Entry]" | sudo tee -a $desktop_file
  sudo echo "Type=Application" | sudo tee -a $desktop_file
  sudo echo "Name=DBeaver Community" | sudo tee -a $desktop_file
  sudo echo "Icon=$dbeaver/dbeaver.png" | sudo tee -a $desktop_file
  sudo echo "Exec=$dbeaver/dbeaver" | sudo tee -a $desktop_file
  sudo echo "Comment=DBeaver Community" | sudo tee -a $desktop_file
  sudo echo "Categories=Development;Databases;" | sudo tee -a $desktop_file

  # Adding dbeaver desktop entry in favorites applications
  favorites=$favorites", 'dbeaver.desktop'"

  echo -e "${S}DBeaver has been installed successfully in the $dbeaver.${R}\n"
fi

# Postman
read -p "Do you want to install Postman?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  postman=$editors/postman
  mkdir -p $postman

  echo -e "Downloading the latest version of Postman."
  wget -q --show-progress -P $temp -O $temp/postman.tar.gz https://dl.pstmn.io/download/latest/linux64

  echo -e "Extracting Postman files to ${V}$postman${R}."
  tar zxf $temp/postman.tar.gz -C $postman --strip-components 1
  rm -rf $temp/postman.tar.gz

  sudo ln -sfn $postman/Postman /usr/local/bin/postman

  echo -e "Creating Postman's application dock entry."

  desktop_file="/usr/share/applications/postman.desktop"
  sudo touch $desktop_file
  sudo echo "[Desktop Entry]" | sudo tee -a $desktop_file
  sudo echo "Type=Application" | sudo tee -a $desktop_file
  sudo echo "Name=Postman" | sudo tee -a $desktop_file
  sudo echo "Icon=$postman/app/resources/app/assets/icon.png" | sudo tee -a $desktop_file
  sudo echo "Exec=$postman/Postman" | sudo tee -a $desktop_file
  sudo echo "Comment=Postman" | sudo tee -a $desktop_file
  sudo echo "Categories=Development;Code;" | sudo tee -a $desktop_file

  # Adding postman desktop entry in favorites applications
  favorites=$favorites", 'postman.desktop'"

  echo -e "${S}Postman has been installed successfully in $postman.${R}\n"
fi

# Mongo Compass
read -p "Do you want to install MongoDB Compass?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  compass_version="1.19.12"
  read -p "Which version of the MongoDB Compass do you want to install:($compass_version) " version

  if [[ $version != "" ]]; then
    compass_version=$version
  fi

  echo -e "Downloading MongoDB Compass community version $compass_version."
  wget -q --show-progress -P $temp -O $temp/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass-community_"$compass_version"_amd64.deb"

  echo -e "Installing mongoDB compass using deb packaging."
  sudo dpkg -i $temp/compass.deb
  rm $temp/compass.deb

  # Adding mongo compass desktop entry in favorites applications
  favorites=$favorites", 'mongodb-compass-community.desktop'"

  echo -e "${S}MongoDB Compass has been installed successfully.${R}\n"
fi

# Robo 3T
read -p "Do you want to install Robo3t?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  robo3t=$editors/robo3t
  mkdir -p $robo3t

  read -p "Enter the url to the latest Robo3t tar.gz file: " url
  echo -e "Downloading Robo3t tar.gz file."
  wget -q --show-progress -P $temp -O $temp/robo3t.tar.gz $url

  echo -e "Extracting Robo3t files to ${V}$robo3t${R}."
  tar zxf $temp/robo3t.tar.gz -C $robo3t --strip-components 1
  rm $temp/robo3t.tar.gz

  icon_url="https://blog.robomongo.org/content/images/2016/01/enjoy.png"
  wget -q --show-progress -P $robo3t -O $robo3t/icon.png $icon_url

  sudo ln -sfn $robo3t/bin/robo3t /usr/local/bin/robo3t

  echo -e "Creating Robo3t's application dock entry."

  desktop_file="/usr/share/applications/robo3t.desktop"
  sudo touch $desktop_file
  sudo echo "[Desktop Entry]" | sudo tee -a $desktop_file
  sudo echo "Type=Application" | sudo tee -a $desktop_file
  sudo echo "Name=Robo 3T" | sudo tee -a $desktop_file
  sudo echo "Icon=$robo3t/icon.png" | sudo tee -a $desktop_file
  sudo echo "Exec=$robo3t/bin/robo3t" | sudo tee -a $desktop_file
  sudo echo "Comment=Robo 3T" | sudo tee -a $desktop_file
  sudo echo "Categories=Databases;Editor;" | sudo tee -a $desktop_file

  # Adding robo3t desktop entry in favorites applications
  favorites=$favorites", 'robo3t.desktop'"

  echo -e "${S}Robo3T has been installed successfully in $robo3t.${R}\n"
fi

# qBittorrent
read -p "Do you want to install qBittorent?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing the latest version of qBittorent."
  sudo add-apt-repository ppa:qbittorrent-team/qbittorrent-stable
  sudo apt update
  sudo apt install qbittorrent

  # Adding qBittorent desktop entry in favorites applications
  favorites=$favorites", 'org.qbittorrent.qBittorrent.desktop'"

  echo -e "${S}qBittorent has been installed successfully.${R}\n"
fi

# Sources
sources=$workspace/sources

if [[ ! -d $sources ]]; then
  echo -e "Creating sources folder ${V}$sources${R}."
  mkdir -p $sources
  mkdir -p $sources/me
  mkdir -p $sources/temp

  echo -e "Adding sources to bookmarks file ${V}$bookmarks_file${R}."
  echo "file://$workspace/sources Sources" | tee -a $bookmarks_file

  echo -e "${S}Sources folder has been created successfully.${R}\n"
fi

# SSH
read -p "Do you want to restore backup SSH files?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  ssh_home=/home/$USER/.ssh

  echo -e "Copying backup SSH files to ${V}$ssh_home${R}."
  mkdir -p $ssh_home
  cp $dropbox/Stack/Secret/ssh/* $ssh_home
  sudo chmod 600 $ssh_home/*

  echo -e "The following SSH files have been restored:"
  tree --noreport -n -L 1 $ssh_home

  echo -e "${S}SSH files have been restored successfully in $ssh_home.${R}\n"
fi

# AWS
read -p "Do you want to restore backup AWS files?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  aws_home=/home/$USER/.aws

  echo -e "Copying backup AWS files to ${V}$aws_home${R}."
  mkdir -p $aws_home
  cp $dropbox/Stack/Secret/aws/* $aws_home
  sudo chmod 600 $aws_home/*

  echo -e "The following AWS files have been restored:"
  tree --noreport -n -L 1 $aws_home

  echo -e "${S}SSH files have been restored successfully in $aws_home.${R}\n"
fi

# Dock
read -p "Do you want to add favorite applications in Dock?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Found the following favorite applications:"
  gsettings get org.gnome.shell favorite-apps

  echo -e "Updating the list of favorite applications."
  gsettings set org.gnome.shell favorite-apps "[$favorites]"

  echo -e "The new favorite applications are: "
  gsettings get org.gnome.shell favorite-apps

  echo -e "Setting dock panel to bottom."
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 26

  echo -e "Hiding the trash icon from the desktop."
  gsettings set org.gnome.nautilus.desktop trash-icon-visible false

  echo -e "${S}Dock panel has been updated successfully.${R}\n"
fi

# Terminal
read -p "Do you want to restore terminal profiles?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  terminal_conf=$dropbox/Stack/Terminal/profiles.dconf

  echo -e "Restoring terminal profiles from ${V}$terminal_conf${R}."
  dconf load /org/gnome/terminal/legacy/profiles:/ < $terminal_conf

  echo -e "${S}Terminal profiles have been restored successfully.${R}\n"
fi

# Report
echo -e "Workspace stack has been installed under ${V}$workspace${R}:"
tree -d --noreport -L 2 $workspace

echo -e "\n${S}Installation completed successfully.${R}"

read -p "Do you want to reboot?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  sudo reboot
fi
