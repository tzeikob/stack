#!/bin/bash
# A shell script to install a development stack environment
# Last Updated: Ubuntu 18.04.03 LTS

# Style markers various helper vars
R="\033[0m" # Reset styles
V="\e[93m" # Highlight values in yellow
S="\e[92m" # Highlight logs in green
yes="^([Yy][Ee][Ss]|[Yy]|"")$"

# List of favorite applications to be added in the dock
favorites="'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'firefox.desktop'"

# Welcome screen
echo -e "Welcome to the workspace stack installation process."

echo -e "Date: ${V}$(date)${R}"
echo -e "System: ${V}$(lsb_release -si) $(lsb_release -sr)${R}"
echo -e "Host: ${V}$HOSTNAME${R}"
echo -e "Username: ${V}$USER${R}\n"

# Temporary folder
temp="./.tmp"

read -p "Where do you want to save installation temporary files?($temp) " path

if [[ $path != "" ]]; then
 temp=$path
fi

if [[ -d $temp ]]; then
 echo -e "Temporary folder ${V}$temp${R} already exists."
else
 echo -e "Creating temporary folder ${V}$temp${R}."
 mkdir -p $temp
fi

echo -e "${S}Temporary folder has been set to $temp successfully.${R}\n"

# Default home folders
read -p "Do you want to refactor the default home folders?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Rename default home folders to lower case."
  mv /home/$USER/Desktop /home/$USER/desktop
  mv /home/$USER/Downloads /home/$USER/downloads
  mv /home/$USER/Templates /home/$USER/templates
  mv /home/$USER/Public /home/$USER/public
  mv /home/$USER/Documents /home/$USER/documents
  mv /home/$USER/Music /home/$USER/music
  mv /home/$USER/Pictures /home/$USER/pictures
  mv /home/$USER/Videos /home/$USER/videos

  echo -e "Backup the user dirs file."
  userdirs="/home/$USER/.config/user-dirs.dirs"
  cp $userdirs $userdirs.bak

  echo -e "Truncate and update the contents of the user dirs file."
  > $userdirs
  echo "XDG_DESKTOP_DIR=\"$HOME/desktop\"" >> $userdirs
  echo "XDG_DOWNLOAD_DIR=\"$HOME/downloads\"" >> $userdirs
  echo "XDG_TEMPLATES_DIR=\"$HOME/templates\"" >> $userdirs
  echo "XDG_PUBLICSHARE_DIR=\"$HOME/public\"" >> $userdirs
  echo "XDG_DOCUMENTS_DIR=\"$HOME/documents\"" >> $userdirs
  echo "XDG_MUSIC_DIR=\"$HOME/music\"" >> $userdirs
  echo "XDG_PICTURES_DIR=\"$HOME/pictures\"" >> $userdirs
  echo "XDG_VIDEOS_DIR=\"$HOME/videos\"" >> $userdirs

  echo -e "Update nautilus bookmarks file."
  bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

  # Backup and truncate the bookmarks file
  cp $bookmarks_file $bookmarks_file.bak
  > $bookmarks_file

  echo "file:///home/"$USER"/downloads Downloads" | tee -a $bookmarks_file
  echo "file:///home/"$USER"/documents Documents" | tee -a $bookmarks_file
  echo "file:///home/"$USER"/music Music" | tee -a $bookmarks_file
  echo "file:///home/"$USER"/pictures Pictures" | tee -a $bookmarks_file
  echo "file:///home/"$USER"/videos Videos" | tee -a $bookmarks_file

  echo -e "${S}Default home folders have been refactored successfully.${R}\n"
fi

# Workspace folder
workspace="/home/$USER/workspace"

read -p "Enter the path to the workspace folder:($workspace) " path

if [[ $path != "" ]]; then
 workspace=$path
fi

if [[ -d $workspace ]]; then
 echo -e "Path ${V}$workspace${R} already exists."
else
 echo -e "Creating path ${V}$workspace${R}."
 mkdir -p $workspace
fi

echo -e "${S}Workspace home path has been set to $workspace successfully.${R}\n"

# Set Local RTC Time
read -p "Do you want to use local time?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Setting system to use local time instead of UTC."
  timedatectl set-local-rtc 1 --adjust-system-clock

  gsettings set org.gnome.desktop.interface clock-show-date true

  echo -e "${S}System has been set to use local time successfully.${R}\n"
fi

# Disabling lock screen
read -p "Do you want to disable screen lock?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Disabling screen lock."
  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

  echo -e "${S}Screen lock has been disabled successfully.${R}\n"
fi

# Disabling automatic upgrades
read -p "Do you want to disable automatic upgrades?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  upgrades_conf=/etc/apt/apt.conf.d/20auto-upgrades

  echo -e "Disabling automatic upgrades in ${V}$upgrades_conf${R}."
  sudo sed -i 's/APT::Periodic::Update-Package-Lists "1"/APT::Periodic::Update-Package-Lists "0"/' $upgrades_conf
  sudo sed -i 's/APT::Periodic::Download-Upgradeable-Packages "1"/APT::Periodic::Download-Upgradeable-Packages "0"/' $upgrades_conf
  sudo sed -i 's/APT::Periodic::AutocleanInterval "1"/APT::Periodic::AutocleanInterval "0"/' $upgrades_conf
  sudo sed -i 's/APT::Periodic::Unattended-Upgrade "1"/APT::Periodic::Unattended-Upgrade "0"/' $upgrades_conf
  cat $upgrades_conf

  echo -e "${S}Automatic upgrades have been disabled successfully.${R}\n"
fi

# System upgrade
read -p "Do you want to upgrade your base system?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Upgrading the base system with the latest updates."
  sudo apt update
  sudo apt upgrade

  echo -e "Removing any not used packages."
  sudo apt autoremove

  echo -e "${S}System upgrade has been finished successfully.${R}\n"
fi

# Dependencies
packages=(tree curl unzip htop gconf-service gconf-service-backend gconf2
          gconf2-common libappindicator1 libgconf-2-4 libindicator7
          libpython-stdlib python python-minimal python2.7 python2.7-minimal libatomic1)

echo -e "Required dependencies:\n${V}"${packages[@]}${R}
read -p "Do you want to install those dependencies?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing software dependencies."
  sudo apt install ${packages[@]}

  echo -e "${S}Dependencies have been installed successfully.${R}\n"
fi

# Dropbox
dropbox=/home/$USER/dropbox

read -p "Do you want to install Dropbox?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Adding official Dropbox repository."
  dropbox_list=/etc/apt/sources.list.d/dropbox.list
  sudo touch $dropbox_list
  sudo echo "deb [arch=i386,amd64] http://linux.dropbox.com/ubuntu $(lsb_release -cs) main" | sudo tee -a $dropbox_list
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1C61A2656FB57B7E4DE0F4C1FC918B335044912E

  echo -e "Installing the latest version of Dropbox."
  sudo apt update
  sudo apt install python3-gpg dropbox

  echo -e "Starting the dropbox daemon..."
  dropbox start -i &>/dev/null

  # Prevent process to jump to the next step before dropbox has been synced
  while true; do
    output=$(dropbox status | sed -n 1p)
    echo -ne "$output                                   \r"

    if [[ $output == "Up to date" ]]; then
      echo -e "Dropbox files have been synced to ${V}$dropbox${R}."
      break
    fi
  done

  # Adding dropbox desktop entry in favorites applications
  favorites=$favorites", 'dropbox.desktop'"

  echo -e "${S}Dropbox has been installed successfully.${R}\n"
fi

# Chrome
read -p "Do you want to install Chrome?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Downloading the latest version of Chrome."
  wget -q --show-progress -P $temp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

  echo -e "Installing Chrome using deb packaging."
  sudo dpkg -i $temp/google-chrome-stable_current_amd64.deb
  rm -rf $temp/google-chrome-stable_current_amd64.deb

  # Adding chrome desktop entry in favorites applications
  favorites=$favorites", 'google-chrome.desktop'"

  echo -e "${S}Chrome has been installed successfully.${R}\n"
fi

# Skype
read -p "Do you want to install Skype?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Downloading the latest version of Skype."
  wget -q --show-progress -P $temp https://repo.skype.com/latest/skypeforlinux-64.deb

  echo -e "Installing Skype using deb packaging."
  sudo dpkg -i $temp/skypeforlinux-64.deb
  rm -rf $temp/skypeforlinux-64.deb

  # Adding skype desktop entry in favorites applications
  favorites=$favorites", 'skypeforlinux.desktop'"

  echo -e "${S}Skype has been installed successfully.${R}\n"
fi

# Slack
read -p "Do you want to install Slack?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  read -p "Enter the url to the Slack binary file: " url
  echo -e "Downloading the latest version of Slack."
  wget -q --show-progress -P $temp -O $temp/slack-desktop-amd64.deb $url

  echo -e "Installing Slack using deb packaging."
  sudo dpkg -i $temp/slack-desktop-amd64.deb
  rm -rf $temp/slack-desktop-amd64.deb

  # Ask user to start slack at system start up
  read -p "Do you want to start Slack at start up?(Y/n) " answer

  if [[ $answer =~ $yes ]]; then
    echo -e "Adding Slack desktop entry to autostart."

    mkdir -p ~/.config/autostart
    desktop_file="/home/$USER/.config/autostart/slack.desktop"
    touch $desktop_file
    echo "[Desktop Entry]" | tee -a $desktop_file
    echo "Type=Application" | tee -a $desktop_file
    echo "Name=Slack" | tee -a $desktop_file
    echo "Comment=Slack Desktop" | tee -a $desktop_file
    echo "Exec=/usr/bin/slack -u" | tee -a $desktop_file
    echo "X-GNOME-Autostart-enabled=true" | tee -a $desktop_file
    echo "StartupNotify=false" | tee -a $desktop_file
    echo "Terminal=false" | tee -a $desktop_file
    # echo "Hidden=false" | tee -a $desktop_file
    # echo "NoDisplay=false" | tee -a $desktop_file
  fi

  # Adding slack desktop entry in favorites applications
  favorites=$favorites", 'slack.desktop'"

  echo -e "${S}Slack has been installed successfully.${R}\n"
fi

# Virtual Box
read -p "Do you want to install Virtual Box?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing Virtual Box version 6.0."
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"

  sudo apt update
  sudo apt install virtualbox-6.0

  # Adding virtual box desktop entry in favorites applications
  favorites=$favorites", 'virtualbox.desktop'"

  echo -e "${S}Virtual box has been installed successfully.${R}\n"
fi

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

# Git
read -p "Do you want to install Git?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  ppa="git-core/ppa"

  if ! grep -q "^deb .*$ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
   echo -e "Adding the Git ppa repository."
   sudo add-apt-repository ppa:$ppa
   sudo apt update
  fi

  echo -e "Installing the latest version of Git."
  sudo apt install git

  read -p "Enter a global username to be associated in each commit:($USER) " username
  if [[ $username == "" ]]; then
   username = $USER
  fi

  git config --global user.name "$username"
  echo -e "Global username has been set to ${V}$(git config --global user.name)${R}."

  read -p "Enter a global email to be associated in each commit:($USER@$HOSTNAME) " email
  if [[ $email == "" ]]; then
   email = $USER@$HOSTNAME
  fi

  git config --global user.email "$email"
  echo -e "Global email has been set to ${V}$(git config --global user.email)${R}."

  echo -e "${S}Git has been installed successfully.${R}\n"
fi

# NodeJS
node=$workspace/node
nvm=$node/nvm

read -p "Do you want to install NodeJS through NVM?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  mkdir -p $nvm

  read -p "Enter the url to the latest version of NVM: " url
  echo -e "Downloading the NVM installation script file."
  wget -q --show-progress -P $temp -O $temp/nvm-install.sh $url

  echo -e "Installing latest version of NVM in ${V}$nvm${R}."
  export NVM_DIR=$nvm
  bash $temp/nvm-install.sh
  rm -rf $temp/nvm-install.sh

  source ~/.bashrc
  source $nvm/nvm.sh

  nvm install --lts
  nvm install node
  nvm use --lts

  echo -e "Currently installed NodeJS versions:"
  nvm ls

  echo -e "${S}NodeJS have been installed successfully in $nvm/versions/node.${R}\n"
fi

# Java
java=$workspace/java

read -p "Do you want to install JDKs?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  mkdir -p $java

  while true; do
    read -p "Enter the url to the JDK binary tar.gz file: " url
    echo -e "Downloading the JDK binary file."
    jdk_file=$temp/jdk.tar.gz
    wget -q --show-progress -P $temp -O $jdk_file --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" $url

    echo -e "Extracting JDK binary files to ${V}$java${R}."
    tar zxf $jdk_file -C $java
    rm -rf $jdk_file

    echo -e "${S}JDK has been installed successfully to $java.${R}\n"

    echo -e "Currently installed JDKs are:"
    tree -d --noreport -n -L 1 $java

    read -p "Do you want to install another JDK?(Y/n) " answer
    if ! [[ $answer =~ ^([Yy][Ee][Ss]|[Yy]|"")$ ]]; then
      break
    fi
  done
fi

# Alternatives
jdks=$(ls -A $java | grep ^jdk)

if [ "$jdks" ]; then
  read -p "Do you want to add JDKs in alternatives?(Y/n) " answer

  if [[ $answer =~ $yes ]]; then
    for d in $jdks ; do
      read -p "Do you want to add $(basename $d) in alternatives?(Y/n) " answer

      if [[ $answer =~ $yes ]]; then
        echo -e "Already JDKs found installed in alternatives:"
        update-alternatives --display java

        read -p "Enter the priority for this alternative entry: " priority

        sudo update-alternatives --install /usr/bin/java java $java/$d/bin/java $priority
        sudo update-alternatives --install /usr/bin/javac javac $java/$d/bin/javac $priority

        echo -e "${S}JDK $(basename $d) has been added in alternatives.${R}\n"
     fi
   done
 fi
fi

# Maven
maven=$workspace/maven

read -p "Do you want to install Maven?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  mkdir -p $maven

  read -p "Enter the url to the Maven binary tar.gz file: " url
  echo -e "Downloading the Maven binary file."
  wget -q --show-progress -P $temp $url

  echo -e "Extracting the Maven files to ${V}$maven${R}."
  tar zxf $temp/apache-maven* -C $maven
  rm -rf $temp/apache-maven*

  echo -e "${S}Maven has been installed successfully in $maven.${R}\n"

  for d in $maven/* ; do
    read -p "Do you want to add Maven to alternatives?(Y/n) " answer

    if [[ $answer =~ $yes ]]; then
      echo -e "Already MVNs found installed in alternatives:"
      update-alternatives --display mvn

      read -p "Enter the priority for this alternative entry: " priority

      sudo update-alternatives --install /usr/bin/mvn mvn $d/bin/mvn $priority

      echo -e "${S}Maven $(basename $d) has been added in alternatives.${R}\n"
    fi
  done
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

# Gimp
read -p "Do you want to install Gimp?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing the Gimp software."
  sudo apt install gimp

  echo -e "${S}Gimp has been installed successfully.${R}\n"
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

# VLC
read -p "Do you want to install VLC?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing the VLC."
  sudo apt install vlc

  echo -e "${S}VLC has been installed successfully.${R}\n"
fi

# Sources
sources=$workspace/sources

if [[ ! -d $sources ]]; then
  echo -e "Creating sources folder ${V}$sources${R}."
  mkdir -p $sources
  mkdir -p $sources/me
  mkdir -p $sources/temp

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

# Bookmarks
read -p "Do you want to create workspace bookmarks?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

  echo -e "Adding workspace and sources to bookmarks file ${V}$bookmarks_file${R}."
  echo "file://$workspace Workspace" | tee -a $bookmarks_file
  echo "file://$workspace/sources Sources" | tee -a $bookmarks_file
  echo "file://$dropbox Dropbox" | tee -a $bookmarks_file

  echo -e "${S}Workspace bookmarks have been added successfully.${R}\n"
fi

# Terminal
read -p "Do you want to restore terminal profiles?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  terminal_conf=$dropbox/Stack/Terminal/profiles.dconf

  echo -e "Restoring terminal profiles from ${V}$terminal_conf${R}."
  dconf load /org/gnome/terminal/legacy/profiles:/ < $terminal_conf

  echo -e "${S}Terminal profiles have been restored successfully.${R}\n"
fi

# Languages
read -p "Do you want to install the greek language?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  echo -e "Installing the greek language packages."
  sudo apt install `check-language-support -l el`

  echo -e "Add greek layout into the keyboard inpuit sources."
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'gr')]"

  echo -e "Setting regional formats back to US:"
  sudo update-locale LANG=en_US.UTF-8
  sudo update-locale LANGUAGE=
  sudo update-locale LC_CTYPE="en_US.UTF-8"
  sudo update-locale LC_NUMERIC=en_US.UTF-8
  sudo update-locale LC_TIME=en_US.UTF-8
  sudo update-locale LC_COLLATE="en_US.UTF-8"
  sudo update-locale LC_MONETARY=en_US.UTF-8
  sudo update-locale LC_MESSAGES="en_US.UTF-8"
  sudo update-locale LC_PAPER=en_US.UTF-8
  sudo update-locale LC_NAME=en_US.UTF-8
  sudo update-locale LC_ADDRESS=en_US.UTF-8
  sudo update-locale LC_TELEPHONE=en_US.UTF-8
  sudo update-locale LC_MEASUREMENT=en_US.UTF-8
  sudo update-locale LC_IDENTIFICATION=en_US.UTF-8
  sudo update-locale LC_ALL=
  locale

  echo -e "${S}Greek language has been installed successfully.${R}\n"
fi

# Report
echo -e "Workspace stack has been installed under ${V}$workspace${R}:"
tree -d --noreport -L 2 $workspace

echo -e "\n${S}Installation completed successfully.${R}"

read -p "Do you want to reboot?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  sudo reboot
fi
