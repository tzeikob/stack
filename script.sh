#!/bin/bash
# A shell script to install and setup your development stack

# Global variables and functions
VERSION="1.0.0"
YES="^([Yy][Ee][Ss]|[Yy]|"")$"
TEMP="/tmp/stack-$(date +%s)"
LOG_FILE="$TEMP/stdout.log"
GIT_USER_NAME=""
GIT_USER_EMAIL=""

# Third-party dependencies
NVM_VERSION="0.38.0"
DOCKER_COMPOSE_VERSION="1.29.2"
MONGODB_COMPASS_VERSION="1.28.1"

# Log a normal info message, log message
log () {
  echo -e "\e[97m$1\e[0m"
}

# Log a success info message, success message
success () {
  echo -e "\e[92m$1\e[0m"
}

# Log an error and exit the process, abort message
abort () {
  echo -e "\033[0;31m$1\e[0m" >&2
  echo -e "Process exited with code: 1" >&2
  exit 1
}

# Check if tasks list contains a given task, tasksContains taskName
tasksContains () {
  local result=false

  for task in "${tasks[@]}"; do
    if [[ $1 == $task ]]; then
      result=true
      break
    fi
  done

  echo $result
}

# Ask if a task should be added to tasks list or not, ask question taskName
ask () {
  read -p "$1(Y/n) " answer
  if [[ $answer =~ $YES ]]; then
    tasks+=($2)
  fi
}

# Task to create temp folder
createTempFolder () {
  log "Creating a folder for temorary files"

  mkdir -p $TEMP

  log "Temp folder has been created successfully ($TEMP)"
}

# Task to upgrade the system via apt
upgradeSystem () {
  log "Upgrading the base system with the latest updates"

  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y upgrade >> $LOG_FILE

  log "Removing not used unnecessary packages"

  sudo apt-get -y autoremove >> $LOG_FILE

  local packages=(tree curl unzip htop gconf-service gconf-service-backend gconf2
            gconf2-common libappindicator1 libgconf-2-4 libindicator7
            libpython2-stdlib python python2.7 python2.7-minimal libatomic1
            gimp vlc)

  log "Installing the following third-party software dependencies: \n${packages[*]}"

  sudo apt-get -y install ${packages[@]} >> $LOG_FILE

  success "System has been updated successfully"
}

# Task to install extra system languages, Greek
installExtraLanguages () {
  log "Installing extra languages"
  log "Installing the greek language packages"

  sudo apt-get -y install `check-language-support -l el` >> $LOG_FILE

  log "Adding greek layout into the keyboard input sources"

  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'gr')]"

  log "Setting regional formats back to US"

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

  success "System languages have been updated successfully"
}

# Task to set local RTC time
setLocalRTCTime () {
  log "Configuring system to use local RTC time instead of UTC"

  timedatectl set-local-rtc 1 --adjust-system-clock
  gsettings set org.gnome.desktop.interface clock-show-date true

  success "System has been set to use local RTC time successfully"
}

# Task to enable system's firewall via UFW
enableFirewall () {
  log "Installing GUFW to manage firewall rules via user interface"

  sudo add-apt-repository -y -n universe >> $LOG_FILE
  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install gufw >> $LOG_FILE

  log "Enabling the system's firewall via the UFW service"

  sudo ufw enable
  sudo ufw status verbose

  log "Any incoming traffic has been set to deny and outgoing to allow"
  success "Firewall has been enabled successfully"
}

# Task to increase inotify watches limit to monitor more files
increaseInotifyLimit () {
  log "Setting the inotify watches limit to a higher value"

  local watches_limit=524288
  echo fs.inotify.max_user_watches=$watches_limit | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

  success "The inotify watches limit has been set to $watches_limit"
}

# Task to disable screen lock
disableScreenLock () {
  log "Disabling screen lock operation"

  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

  success "Screen lock has been disabled successfully"
}

# Task to rename the default home folders
renameHomeFolders () {
  log "Renaming user's home folders in /home/$USER"

  mv /home/$USER/Desktop /home/$USER/desktop
  mv /home/$USER/Downloads /home/$USER/downloads
  mv /home/$USER/Templates /home/$USER/templates
  mv /home/$USER/Public /home/$USER/public
  mv /home/$USER/Documents /home/$USER/documents
  mv /home/$USER/Music /home/$USER/music
  mv /home/$USER/Pictures /home/$USER/pictures
  mv /home/$USER/Videos /home/$USER/videos

  # Task to update the user dirs file
  local userdirs_file="/home/$USER/.config/user-dirs.dirs"

  log "Backing up the user dirs file to $userdirs_file.bak"

  cp $userdirs_file $userdirs_file.bak

  log "Updating the user dirs file $userdirs_file"

  > $userdirs_file
  echo "XDG_DESKTOP_DIR=\"$HOME/desktop\"" >> $userdirs_file
  echo "XDG_DOWNLOAD_DIR=\"$HOME/downloads\"" >> $userdirs_file
  echo "XDG_TEMPLATES_DIR=\"$HOME/templates\"" >> $userdirs_file
  echo "XDG_PUBLICSHARE_DIR=\"$HOME/public\"" >> $userdirs_file
  echo "XDG_DOCUMENTS_DIR=\"$HOME/documents\"" >> $userdirs_file
  echo "XDG_MUSIC_DIR=\"$HOME/music\"" >> $userdirs_file
  echo "XDG_PICTURES_DIR=\"$HOME/pictures\"" >> $userdirs_file
  echo "XDG_VIDEOS_DIR=\"$HOME/videos\"" >> $userdirs_file

  log "User dirs file has been updated successfully"

  # Update the bookmarks file
  local bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

  log "Backing up the bookmarks file to $bookmarks_file.bak"

  cp $bookmarks_file $bookmarks_file.bak

  log "Updating the bookmarks file $bookmarks_file"

  > $bookmarks_file
  echo "file:///home/"$USER"/downloads Downloads" >> $bookmarks_file
  echo "file:///home/"$USER"/documents Documents" >> $bookmarks_file
  echo "file:///home/"$USER"/music Music" >> $bookmarks_file
  echo "file:///home/"$USER"/pictures Pictures" >> $bookmarks_file
  echo "file:///home/"$USER"/videos Videos" >> $bookmarks_file

  success "Home folders and bookmarks renamed successfully"
}

# Task to configure desktop look and feel
configureDesktop () {
  log "Configuring desktop look and feel"

  log "Hiding desktop home and trash icons"

  gsettings set org.gnome.shell.extensions.desktop-icons show-home false
  gsettings set org.gnome.shell.extensions.desktop-icons show-trash false

  success "Desktop has been updated successfully"
}

# Task to configure dock's look and feel
configureDock () {
  log "Configuring dock look and feel"

  log "Setting dock's position to bottom and icon size to 22"

  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 22

  success "Dock has been updated successfully"
}

# Task to install Chrome
installChrome () {
  log "Installing the latest version of Chrome"

  wget -q --show-progress -P $TEMP https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get -y install $TEMP/google-chrome-stable_current_amd64.deb >> $LOG_FILE

  success "Chrome has been installed successfully"
}

# Task to install Slack
installSlack () {
  log "Installing the latest version of Slack"

  sudo snap install slack --classic

  success "Slack has been installed successfully"
}

# Task to install Microsoft Teams
installMSTeams () {
  log "Installing the latest version of Microsoft Teams"

  sudo snap install teams

  success "Microsoft Teams has been installed successfully"
}

# Task to install Skype
installSkype () {
  log "Installing the latest version of Skype"

  sudo snap install skype

  success "Skype has been installed successfully"
}

# Task to install Virtual Box
installVirtualBox () {
  log "Installing the latest version of Virtual Box"

  sudo add-apt-repository -y -n multiverse >> $LOG_FILE
  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install virtualbox >> $LOG_FILE

  success "Virtual Box has been installed successfully"
}

# Task to install git
installGit () {
  log "Installing the latest version of Git"

  ppa="git-core/ppa"

  if ! grep -q "^deb .*$ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
   sudo add-apt-repository -y -n ppa:$ppa >> $LOG_FILE
   sudo apt-get -y update >> $LOG_FILE
  fi

  sudo apt-get -y install git >> $LOG_FILE

  if [[ -n $GIT_USER_NAME ]]; then
    git config --global user.name "$GIT_USER_NAME"
    log "Git global username has been set to $(git config --global user.name)"
  fi

  if [[ -n $GIT_USER_EMAIL ]]; then
    git config --global user.email "$GIT_USER_EMAIL"
    log "Git global email has been set to $(git config --global user.email)"
  fi

  success "Git has been installed successfully"
}

# Task to configure cmd prompt to show current git branch
enableGitPrompt () {
  log "Configuring prompt to show the current branch name for git folders (~/.bashrc)"

  echo '' | tee -a ~/.bashrc
  echo '# Show git branch name' | tee -a ~/.bashrc
  echo 'parse_git_branch() {' | tee -a ~/.bashrc
  echo ' git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/:\\1/"' | tee -a ~/.bashrc
  echo '}' | tee -a ~/.bashrc
  echo "PS1='\${debian_chroot:+(\$debian_chroot)}\[\\033[01;32m\]\u@\h\[\\033[00m\]:\[\\033[01;34m\]\w\[\\033[01;31m\]\$(parse_git_branch)\[\\033[00m\]\$ '" | tee -a ~/.bashrc

  log "Command prompt has been updated successfully"
}

# Task to install Node via NVM
installNode () {
  log "Installing the NVM version $NVM_VERSION"

  wget -q --show-progress -P $TEMP -O $TEMP/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh

  bash $TEMP/nvm-install.sh >> $LOG_FILE
  source /home/$USER/.bashrc >> $LOG_FILE
  source /home/$USER/.nvm/nvm.sh >> $LOG_FILE

  log "NVM has been installed under /home/$USER/.nvm"

  log "Installing Node LTS and latest stable versions"

  nvm install --no-progress --lts >> $LOG_FILE
  nvm install --no-progress node >> $LOG_FILE
  nvm use --lts >> $LOG_FILE

  log "Node versions can be found under /home/$USER/.nvm/versions/node"
  log "Node $(nvm current) is currently in use"

  success "Node has been installed successfully"
}

# Task to install Java, Open JDK and Maven
installJava () {
  log "Installing the OpenJDK version 11"

  sudo apt-get -y install openjdk-11-jdk openjdk-11-doc openjdk-11-source >> $LOG_FILE

  log "OpenJDK has been installed successfully"

  log "JDK currently in use is:"

  java -version

  sudo update-alternatives --display java >> $LOG_FILE

  log "Installing the latest version of Maven"

  sudo apt-get -y install maven >> $LOG_FILE

  mvn -version >> $LOG_FILE

  success "Java has been installed successfully"
}

# Task to install Docker and Compose
installDocker () {
  log "Installing the latest version of Docker"

  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common >> $LOG_FILE

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -  >> $LOG_FILE
  sudo add-apt-repository -y -n "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> $LOG_FILE

  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install docker-ce docker-ce-cli containerd.io >> $LOG_FILE

  log "Creating the docker user group"

  sudo groupadd docker

  log "Adding current user $USER to the docker user group"

  sudo usermod -aG docker $USER

  log "Installing the docker compose v$DOCKER_COMPOSE_VERSION"

  sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  success "Docker has been installed successfully"
}

# Task to install Atom
installAtom () {
  log "Installing the latest version of Atom"

  sudo snap install atom --classic

  success "Atom has been installed successfully"
}

# Task to install Visual Studio Code
installVSCode () {
  log "Installing the latest version of Visual Studio Code"

  sudo snap install code --classic

  local extensions=(
    dbaeumer.vscode-eslint
    yzhang.markdown-all-in-one
  )

  log "Installing the following VS Code plugins and extensions:\n${extensions[*]}"

  for ext in ${extensions[@]}; do
    code --install-extension "$ext"
  done

  success "Visual Studio Code has been installed successfully"
}

# Task to install IntelliJ Idea
installIntelliJIdea () {
  log "Installing the latest version of IntelliJ Idea"

  sudo snap install intellij-idea-community --classic

  success "IntelliJ Idea has been installed successfully"
}

# Task to install MongoDB Compass
installMongoDBCompass () {
  log "Installing the MongoDB Compass version $MONGODB_COMPASS_VERSION"

  wget -q --show-progress -P $TEMP -O $TEMP/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass_${MONGODB_COMPASS_VERSION}_amd64.deb"

  sudo apt-get -y install $TEMP/compass.deb >> $LOG_FILE

  success "MongoDB compass has been installed successfully"
}

# Task to install DBeaver
installDBeaver () {
  log "Installing the latest version of DBeaver"

  sudo snap install dbeaver-ce

  success "DBeaver has been installed successfully"
}

# Task to install Postman
installPostman () {
  log "Installing the latest version of Postman"

  sudo snap install postman

  success "Postman has been isntalled successfully"
}

# Task to install Libre Office
installLiberOffice () {
  log "Installing the latest version of Libre Office"

  sudo add-apt-repository -y -n ppa:libreoffice/ppa >> $LOG_FILE
  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install libreoffice >> $LOG_FILE

  success "Libre Office has been installed successfully"
}

# Task to clean up temporary files
cleanTempFolder () {
  log "Cleaning up temporary files"

  rm -rf $TEMP

  log "Temporary files have been removed ($TEMP)"
}

# Task to print a good bye message
sayGoodBye () {
  success "\nStack script has completed successfully"
  log "Have a nice coding time, see ya!"
}

# Task to reboot the system
rebootSystem () {
  log "Restarting the system..."
  
  for secs in 10 9 8 7 6 5 4 3 2 1; do
    echo -ne "Reboot will start in $secs secs (press Ctrl-C to cancel reboot)\\r"
    sleep 1
  done

  reboot
}

log "Stack v$VERSION"
log "Running on $(lsb_release -si) $(lsb_release -sr) $(lsb_release -sc)"
log "Logged as $USER@$HOSTNAME with kernel $(uname -r)\n"

# Initiate task execution list with the mandatory tasks
tasks=(createTempFolder)

# Read option y to enable yes to all tasks, default is false
yesToAll=false
while getopts :y opt; do
  case $opt in
    y)
     yesToAll=true
     log "Option -y (yes to all tasks) has been enabled";;
    *) abort "Error: Ooops argument $OPTARG is not supported";;
  esac
done

if [[ $yesToAll = false ]]; then
  log "System configuration:"
  ask "Do you want to upgrade your system?" upgradeSystem
  ask "Do you want to install extra languages (Greek)?" installExtraLanguages
  ask "Do you want to use local RTC time?" setLocalRTCTime
  ask "Do you want to enable the firewall via UFW?" enableFirewall
  ask "Do you want to increase the inotify watches limit?" increaseInotifyLimit
  ask "Do you want to disable screen lock?" disableScreenLock
  ask "Do you want to rename home folders to lowecase?" renameHomeFolders

  log "\nLook and feel:"
  ask "Do you want to hide desktop icons?" configureDesktop
  ask "Do you want to reposition dock to bottom?" configureDock

  log "\nThird-party software:"
  ask "Do you want to install Chrome?" installChrome
  ask "Do you want to install Slack?" installSlack
  ask "Do you want to install Microsoft Teams?" installMSTeams
  ask "Do you want to install Skype?" installSkype
  ask "Do you want to install Virtual Box?" installVirtualBox
  ask "Do you want to install Git?" installGit

  if [[ $(tasksContains installGit) == true ]]; then
    read -p "What's your git user name?(enter to skip) " GIT_USER_NAME
    read -p "What's your git user email?(enter to skip) " GIT_USER_EMAIL

    ask "Should cmd prompt show the current branch for git folders?" enableGitPrompt
  fi

  ask "Do you want to install Node?" installNode
  ask "Do you want to install Java with Maven?" installJava
  ask "Do you want to install Docker and Compose?" installDocker
  ask "Do you want to install Atom?" installAtom
  ask "Do you want to install Visual Studio Code?" installVSCode
  ask "Do you want to install IntelliJ Idea?" installIntelliJIdea
  ask "Do you want to install MongoDB Compass?" installMongoDBCompass
  ask "Do you want to install DBeaver?" installDBeaver
  ask "Do you want to install Postman?" installPostman
  ask "Do you want to install Libre Office?" installLiberOffice

  log "\nPost actions:"
  ask "Do you want to clean temp files?" cleanTempFolder

  tasks+=(sayGoodBye)

  ask "Do you want to reboot after stack script is done?" rebootSystem
else
  tasks+=(
    upgradeSystem
    installExtraLanguages
    setLocalRTCTime
    enableFirewall
    increaseInotifyLimit
    disableScreenLock
    renameHomeFolders
    configureDesktop
    configureDock
    installChrome
    installSlack
    installMSTeams
    installSkype
    installVirtualBox
    installGit
    enableGitPrompt
    installNode
    installJava
    installDocker
    installAtom
    installVSCode
    installIntelliJIdea
    installMongoDBCompass
    installDBeaver
    installPostman
    installLiberOffice
    cleanTempFolder
    sayGoodBye
    rebootSystem
  )
fi

# Start executing each task in order
log "\nStarting the execution of tasks"

for task in "${tasks[@]}"; do "${task}"; done