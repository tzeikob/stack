#!/bin/bash
# A shell script to install a development environment

# Style markers
R="\033[0m" # Reset styles
V="\e[93m" # Highlight values in yellow
S="\e[92m" # Highlight logs in green

# Welcome screen
echo -e "Welcome to the workspace installation process."

echo -e "Date: ${V}$(date)${R}"
echo -e "System: ${V}$(lsb_release -si) $(lsb_release -sr)${R}"
echo -e "Host: ${V}$HOSTNAME${R}"
echo -e "Username: ${V}$USER${R}\n"

# Temporary folder
temp=".tmp"
read -p "Where do you want to save temporary files?($temp)" path

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

# Workspace folder
workspace="/home/$USER/Workspace"
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

# System upgrade
read -p "Do you want to upgrade your base system?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Updating the repositories package list."
  sudo apt update
  sudo apt upgrade
  echo -e "${S}System upgrade finished successfully.${R}\n"
esac

# Utility software
read -p "Do you want to install third-party utilities?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Installing various software utilities."
  sudo apt install tree curl
  echo -e "${S}Software utilities have been installed successfully.${R}\n"
esac

# Chrome
read -p "Do you want to install chrome?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Downloading the latest version of chrome."
  wget -q --show-progress -P $temp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

  echo -e "Installing chrome using deb packaging."
  sudo dpkg -i $temp/google-chrome-stable_current_amd64.deb
  rm -rf $temp/google-chrome-stable_current_amd64.deb

  echo -e "${S}Chrome has been installed successfully.${R}\n"
esac

# Skype
read -p "Do you want to install skype?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Downloading the latest version of skype."
  wget -q --show-progress -P $temp https://repo.skype.com/latest/skypeforlinux-64.deb

  echo -e "Installing skype using deb packaging."
  sudo dpkg -i $temp/skypeforlinux-64.deb
  rm -rf $temp/skypeforlinux-64.deb

  echo -e "${S}Skype has been installed successfully.${R}\n"
esac

# Slack
read -p "Do you want to install slack?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  read -p "Enter the url to the slack binary file: " url
  echo -e "Downloading the latest version of slack."
  wget -q --show-progress -P $temp -O $temp/slack-desktop-amd64.deb $url

  echo -e "Installing slack using deb packaging."
  sudo dpkg -i $temp/slack-desktop-amd64.deb
  rm -rf $temp/slack-desktop-amd64.deb

  # Ask user to start slack at system start up
  read -p "Do you want to start slack at start up?(Y/n)" answer

  case $answer in
   ( [Yy][Ee][Ss] | [Yy] | "" )
    echo -e "Adding slack desktop entry to autostart."

    mkdir -p ~/.config/autostart
    desktopfile="/home/$USER/.config/autostart/slack.desktop"
    touch $desktopfile
    sudo echo "[Desktop Entry]" | sudo tee -a $desktopfile
    sudo echo "Type=Application" | sudo tee -a $desktopfile
    sudo echo "Name=Slack" | sudo tee -a $desktopfile
    sudo echo "Comment=Slack Desktop" | sudo tee -a $desktopfile
    sudo echo "Exec=/usr/bin/slack -u" | sudo tee -a $desktopfile
    sudo echo "X-GNOME-Autostart-enabled=true" | sudo tee -a $desktopfile
    sudo echo "StartupNotify=false" | sudo tee -a $desktopfile
    sudo echo "Terminal=false" | sudo tee -a $desktopfile
    # sudo echo "Hidden=false" | sudo tee -a $desktopfile
    # sudo echo "NoDisplay=false" | sudo tee -a $desktopfile
  esac

  echo -e "${S}Slack has been installed successfully.${R}\n"
esac

# Virtual Box
read -p "Do you want to install virtual box?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Installing virtual box ${V}version 6.0${R}."
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
  sudo apt update
  sudo apt install virtualbox-6.0

  echo -e "${S}Virtual box has been installed successfully.${R}\n"
esac

# Git
read -p "Do you want to install git?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  ppa="git-core/ppa"

  if ! grep -q "^deb .*$ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
   echo -e "Adding the git ppa repository."
   sudo add-apt-repository ppa:$ppa
   sudo apt update
  fi

  echo -e "Installing the latest version of git."
  sudo apt install git

  read -p "Enter a global username to be associated in each git commit:($USER)" username
  if [[ $username == "" ]]; then
   username = $USER
  fi

  git config --global user.name "$username"
  echo -e "Global username has been set to ${V}$(git config --global user.name)${R}."

  read -p "Enter a global email to be associated in each git commit:($USER@$HOSTNAME)" email
  if [[ $email == "" ]]; then
   email = $USER@$HOSTNAME
  fi

  git config --global user.email "$email"
  echo -e "Global email has been set to ${V}$(git config --global user.email)${R}."

  echo -e "${S}Git has been installed successfully.${R}\n"
esac

# NodeJS
node=$workspace/node
nvm=$node/nvm
read -p "Do you want to install NodeJS via nvm?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  mkdir -p $nvm

  read -p "Enter the url to the latest version of nvm: " url
  echo -e "Installing latest version of nvm in ${V}$nvm${R}."
  wget -q --show-progress -P $temp -O $temp/nvm-install.sh $url

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

  echo -e "${S}NodeJS LTS and current versions have been installed successfully in $nvm/versions/node.${R}"
esac

# JAVA
java=$workspace/java

# JDKs
read -p "Do you want to install a JDK?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  mkdir -p $java

  read -p "Enter the url to the JDK binary tar.gz file: " url
  echo -e "Downloading the JDK binary file."
  wget -q --show-progress -P $temp --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" $url

  echo -e "Extracting JDK binary files to ${V}$java${R}."
  tar zxf $temp/jdk* -C $java
  rm -rf $temp/jdk*

  echo -e "${S}JDK has been installed succefully to $java.${R}\n"

  # Install more JDKs
  while :
  do
    echo -e "Currently installed JDKs are:"
    tree -d --noreport -n -L 1 $java

    read -p "Do you want to install another JDK?(Y/n)" answer
    case $answer in
     ( [Yy][Ee][Ss] | [Yy] | "" )
      read -p "Enter the url to the JDK binary tar.gz file: " url
      echo -e "Downloading the JDK binary file."
      wget -q --show-progress -P $temp --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" $url

      echo -e "Extracting JDK binary files to ${V}$java${R}."
      tar zxf $temp/jdk* -C $java
      rm -rf $temp/jdk*

      echo -e "${S}JDK has been installed succefully to $java.${R}\n"
      ;;
     *)
      break
    esac
  done
esac

# Alternatives
jdks=$(ls -A $java | grep ^jdk)

if [ "$jdks" ]; then
  read -p "Found JDKs, do you want to add them in alternatives?(Y/n)" answer

  case $answer in
   ( [Yy][Ee][Ss] | [Yy] | "" )
    for d in $jdks ; do
     read -p "Do you want to add $(basename $d) in alternatives?(Y/n)" answer

     case $answer in
      ( [Yy][Ee][Ss] | [Yy] | "" )
       read -p "Enter the priority for this alternative entry: " priority

       sudo update-alternatives --install /usr/bin/java java $d/bin/java $priority
       sudo update-alternatives --install /usr/bin/javac javac $d/bin/javac $priority

       echo -e "${S}JDK $(basename $d) has been added in alternatives.${R}\n"
     esac
    done
  esac
fi

# Maven
maven=$workspace/maven
read -p "Do you want to install maven?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  mkdir -p $maven

  read -p "Enter the url to the maven binary tar.gz file: " url
  echo -e "Downloading the maven binary file."
  wget -q --show-progress -P $temp $url

  echo -e "Extracting the maven files to ${V}$maven${R}."
  tar zxf $temp/apache-maven* -C $maven
  rm -rf $temp/apache-maven*

  echo -e "${S}Maven has been installed successfully in $maven.${R}\n"

  for d in $maven/* ; do
    read -p "Found Maven $(basename $d), do you want to add it to alternatives?(Y/n)" answer

    case $answer in
     ( [Yy][Ee][Ss] | [Yy] | "" )
      read -p "Enter the priority for this alternative entry: " priority

      sudo update-alternatives --install /usr/bin/mvn mvn $d/bin/mvn $priority

      echo -e "${S}Maven $(basename $d) has been added in alternatives.${R}\n"
    esac
  done
esac

# Docker
read -p "Do you want to install docker?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Installing docker community edition."
  sudo apt update
  sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  sudo apt update
  sudo apt install docker-ce docker-ce-cli containerd.io

  echo -e "Creating docker user group."
  sudo groupadd docker

  echo -e "Adding current user to docker user group."
  sudo usermod -aG docker $USER

  compose_version="1.24.1"
  read -p "Which version of the docker compose do you want to install:($compose_version) " version

  if [[ $version != "" ]]; then
    compose_version=$version
  fi

  sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  echo -e "${S}Docker has been installed successfully.${R}\n"
esac

# Editors
editors=$workspace/editors

# Atom
read -p "Do you want to install atom?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Installing the latest version of atom."
  wget -q https://packagecloud.io/AtomEditor/atom/gpgkey -O- | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main"
  sudo apt update
  sudo apt install atom

  echo -e "${S}Atom has been installed successfully.${R}\n"
esac

# IdeaIC
read -p "Do you want to install ideaIC?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  ideaic=$editors/idea-ic
  mkdir -p $ideaic

  read -p "Enter the url to the ideaIC tar.gz file: " url
  echo -e "Downloading the ideaIC tar.gz file."
  wget -q --show-progress -P $temp $url

  echo -e "Extracting the ideaIC files to ${V}$ideaic${R}."
  tar zxf $temp/ideaIC* -C $ideaic --strip-components 1
  rm -rf $temp/ideaIC*

  echo -e "${S}IdeaIC has been installed successfully in $ideaic.${R}\n"
esac

# DBeaver
read -p "Do you want to install dbeaver?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  dbeaver=$editors/dbeaver
  mkdir -p $dbeaver

  echo -e "Downloading the latest version of the dbeaver tar.gz file."
  wget -q --show-progress -P $temp wget https://dbeaver.io/files/dbeaver-ce-latest-linux.gtk.x86_64.tar.gz

  echo -e "Extracting the dbeaver files to ${V}$dbeaver${R}."
  tar zxf $temp/dbeaver-ce* -C $dbeaver --strip-components 1
  rm -rf $temp/dbeaver-ce*

  sudo ln -sfn $dbeaver/dbeaver /usr/local/bin/dbeaver

  echo -e "Creating dbeaver's application dock entry."

  desktopfile="/usr/share/applications/dbeaver.desktop"
  sudo touch $desktopfile
  sudo echo "[Desktop Entry]" | sudo tee -a $desktopfile
  sudo echo "Type=Application" | sudo tee -a $desktopfile
  sudo echo "Name=DBeaver Community" | sudo tee -a $desktopfile
  sudo echo "Icon=$dbeaver/dbeaver.png" | sudo tee -a $desktopfile
  sudo echo "Exec=$dbeaver/dbeaver" | sudo tee -a $desktopfile
  sudo echo "Comment=DBeaver Community" | sudo tee -a $desktopfile
  sudo echo "Categories=Development;Databases;" | sudo tee -a $desktopfile

  echo -e "${S}DBeaver has been installed successfully in the $dbeaver.${R}\n"
esac

# Postman
read -p "Do you want to install postman?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  postman=$editors/postman
  mkdir -p $postman

  echo -e "Downloading the latest version of postman."
  wget -q --show-progress -P $temp -O $temp/postman.tar.gz https://dl.pstmn.io/download/latest/linux64

  echo -e "Extracting postman files to ${V}$postman${R}."
  tar zxf $temp/postman.tar.gz -C $postman --strip-components 1
  rm -rf $temp/postman.tar.gz

  sudo ln -sfn $postman/Postman /usr/local/bin/postman

  echo -e "Creating postman's application dock entry."

  desktopfile="/usr/share/applications/postman.desktop"
  sudo touch $desktopfile
  sudo echo "[Desktop Entry]" | sudo tee -a $desktopfile
  sudo echo "Type=Application" | sudo tee -a $desktopfile
  sudo echo "Name=Postman" | sudo tee -a $desktopfile
  sudo echo "Icon=$postman/app/resources/app/assets/icon.png" | sudo tee -a $desktopfile
  sudo echo "Exec=$postman/Postman" | sudo tee -a $desktopfile
  sudo echo "Comment=Postman" | sudo tee -a $desktopfile
  sudo echo "Categories=Development;Code;" | sudo tee -a $desktopfile

  echo -e "${S}Postman has been installed successfully in $postman.${R}\n"
esac

# Mongo Compass
read -p "Do you want to install mongodb compass?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  compass_version="1.19.12"
  read -p "Which version of the mongodb compass do you want to install:($compass_version) " version

  if [[ $version != "" ]]; then
    compass_version=$version
  fi

  echo -e "Downloading mongodb compass community version $compass_version."
  wget -q --show-progress -P $temp -O $temp/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass-community_"$compass_version"_amd64.deb"

  echo -e "Installing mongodb compass using deb packaging."
  sudo dpkg -i $temp/compass.deb
  rm $temp/compass.deb

  echo -e "${S}MongoDB Compass has been installed successfully.${R}\n"
esac

# Robo 3T
read -p "Do you want to install robo 3t?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  robo3t=$editors/robo3t
  mkdir -p $robo3t

  read -p "Enter the url to the latest robo 3t tar.gz file: " url
  echo -e "Downloading robo 3t tar.gz file."
  wget -q --show-progress -P $temp -O $temp/robo3t.tar.gz $url

  echo -e "Extracting robo 3t files to ${V}$robo3t${R}."
  tar zxf $temp/robo3t.tar.gz -C $robo3t --strip-components 1
  rm $temp/robo3t.tar.gz

  wget -q --show-progress -P $robo3t -O $robo3t/icon.png https://images.g2crowd.com/uploads/product/image/large_detail/large_detail_f49ab27210b28cdaf3e3bd3f7d2d629f/robo3t.png

  sudo ln -sfn $robo3t/bin/robo3t /usr/local/bin/robo3t

  echo -e "Creating robo 3t's application dock entry."

  desktopfile="/usr/share/applications/robo3t.desktop"
  sudo touch $desktopfile
  sudo echo "[Desktop Entry]" | sudo tee -a $desktopfile
  sudo echo "Type=Application" | sudo tee -a $desktopfile
  sudo echo "Name=Robo 3T" | sudo tee -a $desktopfile
  sudo echo "Icon=$robo3t/icon.png" | sudo tee -a $desktopfile
  sudo echo "Exec=$robo3t/bin/robo3t" | sudo tee -a $desktopfile
  sudo echo "Comment=Robo 3T" | sudo tee -a $desktopfile
  sudo echo "Categories=Databases;Editor;" | sudo tee -a $desktopfile

  echo -e "${S}Robo 3T has been installed successfully in $robo3t.${R}\n"
esac

# Sources
sources=$workspace/sources

if [[ -d $sources ]]; then
 echo -e "Sources folder ${V}$sources${R} already exists."
else
 echo -e "Creating sources folder ${V}$sources${R}."
 mkdir -p $sources
fi

echo -e "${S}Sources folder has been set successfully to $sources.${R}\n"

# Bookmarks
read -p "Do you want to create workspace bookmarks?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  bookmarksfile="/home/$USER/.config/gtk-3.0/bookmarks"

  echo -e "Adding workspace and sources to bookmarks file ${V}$bookmarksfile${R}."
  echo "file://$workspace Workspace" | tee -a $bookmarksfile
  echo "file://$workspace/sources Sources" | tee -a $bookmarksfile

  echo -e "${S}Workspace bookmarks have been added successfully.${R}\n"
esac

# Terminal
read -p "Do you want to load terminal profiles?(Y/n)" answer

case $answer in
 ( [Yy][Ee][Ss] | [Yy] | "" )
  echo -e "Downloading terminal profiles backup file."
  conffile=$temp/terminal.dconf
  wget -q --show-progress -P $temp -O $conffile https://www.dropbox.com/s/qslstp28n1g6wtk/terminal.dconf?dl=0

  echo -e "Installing terminal profiles from ${V}$conffile${R}."
  dconf load /org/gnome/terminal/legacy/profiles:/ < $conffile
  rm -rf $conffile

  echo -e "${S}Terminal profiles have been loaded successfully.${R}\n"
esac

echo -e "Workspace stack has been installed under ${V}$workspace${R}:"
tree -d --noreport -L 2 $workspace

echo -e "\n${S}Installation completed successfully.${R}"
