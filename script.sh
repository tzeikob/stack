#!/bin/bash
# A shell script to install and setup your development stack

# Global variables and functions
VERSION="1.0.0"
YES="^([Yy][Ee][Ss]|[Yy]|"")$"
TEMP="/tmp/stack.$(date +%s)"
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

# Log a progress message, progress message
progress () {
  echo -ne "\e[97m$1\e[0m\\r"
}

# Log an error and exit the process, abort message
abort () {
  echo -e "\n\033[0;31m$1\e[0m" >&2
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
  mkdir -p $TEMP

  log "Temporary folder has been created successfully ($TEMP)"
  log "You might want to know that logs have been routed to $LOG_FILE\n"
}

# Task to configure desktop look and feel
configureDesktop () {
  log "Configuring desktop's look and feel"

  log "Hiding home icon from desktop"
  gsettings set org.gnome.shell.extensions.desktop-icons show-home false

  log "Hiding trash icon from desktop"
  gsettings set org.gnome.shell.extensions.desktop-icons show-trash false

  success "Desktop has been updated successfully\n"
}

# Task to configure dock's look and feel
configureDock () {
  log "Configuring dock's look and feel"

  log "Positioning dock to the bottom"
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM

  log "Setting dock's size down to 22 pixels"
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 22

  success "Dock has been updated successfully\n"
}

# Task to rename the default home folders
renameHomeFolders () {
  log "Renaming home folders in /home/$USER"

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

  success "Home folders and bookmarks renamed successfully\n"
}

# Task to disable screen lock
disableScreenLock () {
  log "Disabling the auto screen lock operation"

  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

  log "Idle delay has been set to 0"
  log "Power idle dim has been disabled"

  success "Screen lock has been disabled successfully\n"
}

# Task to update the system via apt
updateSystem () {
  log "Updating the system with the latest updates"

  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y upgrade >> $LOG_FILE

  log "Latest updates have been installed successfully"

  sudo apt-get -y autoremove >> $LOG_FILE

  log "Unnecessary packages have been removed"

  local packages=(tree curl unzip htop gconf-service gconf-service-backend gconf2
            gconf2-common libappindicator1 libgconf-2-4 libindicator7
            libpython2-stdlib python python2.7 python2.7-minimal libatomic1
            gimp vlc)

  log "Installing the following third-party dependencies:\n${packages[*]}"

  sudo apt-get -y install ${packages[@]} >> $LOG_FILE

  success "System has been updated successfully\n"
}

# Task to set local RTC time
setLocalRTCTime () {
  log "Configuring system to use local RTC time"

  timedatectl set-local-rtc 1 --adjust-system-clock

  log "Now the system is using the local RTC Time instead of UTC"

  gsettings set org.gnome.desktop.interface clock-show-date true

  log "Clock has been set to show the date as well"

  success "System has been set to use local RTC time successfully\n"
}

# Task to increase inotify watches limit to monitor more files
increaseInotifyLimit () {
  log "Setting the inotify watches limit to a higher value"

  local watches_limit=524288
  echo fs.inotify.max_user_watches=$watches_limit | sudo tee -a /etc/sysctl.conf >/dev/null && sudo sysctl -p

  success "The inotify watches limit has been set to $watches_limit\n"
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
  success "Firewall has been enabled successfully\n"
}

# Task to install extra system languages, Greek
installGreekLanguage () {
  log "Installing language packages for Greek"

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

  success "System languages have been updated successfully\n"
}

# Task to install Virtual Box
installVirtualBox () {
  log "Installing the latest version of Virtual Box"

  sudo add-apt-repository -y -n multiverse >> $LOG_FILE
  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install virtualbox >> $LOG_FILE

  success "Virtual Box has been installed successfully\n"
}

# Task to install Docker and Compose
installDocker () {
  log "Installing the latest version of Docker"

  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release >> $LOG_FILE

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >> $LOG_FILE
  
  echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get -y update >> $LOG_FILE
  sudo apt-get -y install docker-ce docker-ce-cli containerd.io >> $LOG_FILE

  log "Creating the docker user group"

  sudo groupadd docker

  log "Adding current user $USER to the docker user group"

  sudo usermod -aG docker $USER

  log "Installing the Docker Compose version $DOCKER_COMPOSE_VERSION"

  sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  success "Docker has been installed successfully\n"
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
    log "Git global user name has been set to $(git config --global user.name)"
  fi

  if [[ -n $GIT_USER_EMAIL ]]; then
    git config --global user.email "$GIT_USER_EMAIL"
    log "Git global user email has been set to $(git config --global user.email)"
  fi

  success "Git has been installed successfully\n"
}

# Task to configure cmd prompt to show current git branch
enableGitPrompt () {
  log "Setting cmd prompt to show current branch in git folders (~/.bashrc)"

  echo '' >> ~/.bashrc
  echo '# Show git branch name' >> ~/.bashrc
  echo 'parse_git_branch() {' >> ~/.bashrc
  echo ' git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/:\\1/"' >> ~/.bashrc
  echo '}' >> ~/.bashrc
  echo "PS1='\${debian_chroot:+(\$debian_chroot)}\[\\033[01;32m\]\u@\h\[\\033[00m\]:\[\\033[01;34m\]\w\[\\033[01;31m\]\$(parse_git_branch)\[\\033[00m\]\$ '" >> ~/.bashrc

  log "Cmd prompt will now shown as user@host:~/path/to/folder[:branch]"

  success "Command prompt has been updated successfully\n"
}

# Task to install Node via NVM
installNode () {
  log "Installing Node via the NVM version $NVM_VERSION"

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

  success "Node has been installed successfully\n"
}

# Task to install Java, Open JDK and Maven
installJava () {
  log "Installing Java via the OpenJDK version 11"

  sudo apt-get -y install openjdk-11-jdk openjdk-11-doc openjdk-11-source >> $LOG_FILE

  log "OpenJDK has been installed successfully"

  log "JDK currently in use is:"

  java -version

  sudo update-alternatives --display java >> $LOG_FILE

  log "Installing the latest version of Maven"

  sudo apt-get -y install maven >> $LOG_FILE

  mvn -version

  success "Java has been installed successfully\n"
}

# Task to install Atom
installAtom () {
  log "Installing the latest version of Atom"

  sudo snap install atom --classic

  success "Atom has been installed successfully\n"
}

# Task to install Visual Studio Code
installVSCode () {
  log "Installing the latest version of Visual Studio Code"

  sudo snap install code --classic

  local extensions=(
    dbaeumer.vscode-eslint
    yzhang.markdown-all-in-one
  )

  log "Installing the following plugins and extensions:\n${extensions[*]}"

  for ext in ${extensions[@]}; do
    code --install-extension "$ext"
  done

  success "Visual Studio Code has been installed successfully\n"
}

# Task to install IntelliJ Idea
installIntelliJIdea () {
  log "Installing the latest version of IntelliJ Idea"

  sudo snap install intellij-idea-community --classic

  success "IntelliJ Idea has been installed successfully\n"
}

# Task to install MongoDB Compass
installMongoDBCompass () {
  log "Installing the MongoDB Compass version $MONGODB_COMPASS_VERSION"

  wget -q --show-progress -P $TEMP -O $TEMP/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass_${MONGODB_COMPASS_VERSION}_amd64.deb"

  sudo apt-get -y install $TEMP/compass.deb >> $LOG_FILE

  success "MongoDB compass has been installed successfully\n"
}

# Task to install DBeaver
installDBeaver () {
  log "Installing the latest version of DBeaver"

  sudo snap install dbeaver-ce

  success "DBeaver has been installed successfully\n"
}

# Task to install Postman
installPostman () {
  log "Installing the latest version of Postman"

  sudo snap install postman

  success "Postman has been isntalled successfully\n"
}

# Task to install Chrome
installChrome () {
  log "Installing the latest version of Chrome"

  log "Downloading the binary file..."

  wget -q --show-progress -P $TEMP https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb >> $LOG_FILE
  sudo apt-get -y install $TEMP/google-chrome-stable_current_amd64.deb >> $LOG_FILE

  success "Chrome has been installed successfully\n"
}

# Task to install Slack
installSlack () {
  log "Installing the latest version of Slack"

  sudo snap install slack --classic

  success "Slack has been installed successfully\n"
}

# Task to install Microsoft Teams
installMSTeams () {
  log "Installing the latest version of Microsoft Teams"

  sudo snap install teams

  success "Microsoft Teams has been installed successfully\n"
}

# Task to install Skype
installSkype () {
  log "Installing the latest version of Skype"

  sudo snap install skype

  success "Skype has been installed successfully\n"
}

# Task to install Libre Office
installLibreOffice () {
  log "Installing the latest version of Libre Office"

  sudo snap install libreoffice

  success "Libre Office has been installed successfully\n"
}

# Task to clean up temporary files
cleanTempFolder () {
  log "Cleaning up installation files ($TEMP)"

  rm -rf $TEMP
}

# Task to print a good bye message
sayGoodBye () {
  local endTime=`date +%s`
  local runtime=$(((endTime-startTime)/60))

  log "Installation has been completed in $runtime mins"
  success "Have a nice coding time, see ya!\n"
}

# Task to reboot the system
rebootSystem () {
  log "Script has been switched to restart mode..."
  
  # Sleep 10 secs before reboot
  for secs in 10 9 8 7 6 5 4 3 2 1 0; do
    progress "Reboot will start in $secs secs (Ctrl-C to cancel)"
    sleep 1
  done

  reboot
}

log "Stack v$VERSION"
log "Running on $(lsb_release -si) $(lsb_release -sr) $(lsb_release -sc)"
log "Logged in as $USER@$HOSTNAME with kernel $(uname -r)"

# Read options, y to enable yes to all tasks
yesToAll=false
while getopts :y opt; do
  case $opt in
    y)
     yesToAll=true
     log "Option -y (yes to all tasks) has been enabled";;
    *) abort "Error: Ooops argument $OPTARG is not supported";;
  esac
done

log "Script initialization has been completed\n"

# Initiate task execution list with the mandatory tasks
tasks=(createTempFolder)

if [[ $yesToAll = false ]]; then
  log "Me likes a clean look and feel:"
  ask "You may want to hide desktop icons?" configureDesktop
  ask "Do you want to reposition dock to the bottom?" configureDock
  ask "Should home folders (~/Downloads, etc.) be renamed to lowercase?" renameHomeFolders
  ask "Would disabling screen lock be helpful to you?" disableScreenLock

  log "\nCaptain, the system is out of order:"
  ask "I guess you want to get the latest system updates?" updateSystem
  ask "Should system time be set to local RTC time?" setLocalRTCTime
  ask "Will higher inotify watches limit help you to monitor files?" increaseInotifyLimit
  ask "Do you want to enable firewall via UFW?" enableFirewall
  ask "Is Greek an extra language you need in your keyboard?" installGreekLanguage

  log "\nDope, shippin' with containers is:"
  ask "Do you want to install Virtual Box?" installVirtualBox
  ask "Do you want to install Docker and Compose?" installDocker

  log "\nWe all say coding is so sexy:"
  ask "Do you want to install Git?" installGit

  if [[ $(tasksContains installGit) == true ]]; then
    read -p "Awesome, what's your git user name?(enter to skip) " GIT_USER_NAME
    read -p "...and your git user email please?(enter to skip) " GIT_USER_EMAIL

    ask "Should cmd prompt show the current branch in git folders?" enableGitPrompt
  fi

  ask "Do you want to install Node?" installNode
  ask "Do you want to install Java with Maven?" installJava
  ask "Do you want to install Atom?" installAtom
  ask "Do you want to install Visual Studio Code?" installVSCode
  ask "Do you want to install IntelliJ Idea?" installIntelliJIdea

  log "\nIt's all about data:"
  ask "Do you want to install MongoDB Compass?" installMongoDBCompass
  ask "Do you want to install DBeaver?" installDBeaver
  ask "Do you want to install Postman?" installPostman

  log "\nWork in teams, get things done:"
  ask "Do you want to install Chrome?" installChrome
  ask "Do you want to install Slack?" installSlack
  ask "Do you want to install Microsoft Teams?" installMSTeams
  ask "Do you want to install Skype?" installSkype
  ask "Do you want to install Libre Office?" installLibreOffice

  log "\nWe're almost done:"
  ask "You may want to post clean temp files, right?" cleanTempFolder

  tasks+=(sayGoodBye)

  ask "Do you want to reboot after installation?" rebootSystem
else
  tasks+=(
    configureDesktop
    configureDock
    renameHomeFolders
    disableScreenLock

    updateSystem
    setLocalRTCTime
    increaseInotifyLimit
    enableFirewall
    installGreekLanguage

    installVirtualBox
    installDocker

    installGit
    enableGitPrompt
    installNode
    installJava
    installAtom
    installVSCode
    installIntelliJIdea

    installMongoDBCompass
    installDBeaver
    installPostman

    installChrome
    installSlack
    installMSTeams
    installSkype
    installLibreOffice
    cleanTempFolder
    sayGoodBye
    rebootSystem
  )
fi

# Start executing each task in order
log ""
for secs in 5 4 3 2 1 0; do
  progress "Installation is ready to launch in $secs (Ctrl-C to cancel)"
  sleep 1
done

log "\nLiftoff! We have a liftoff..."

startTime=`date +%s`

for task in "${tasks[@]}"; do "${task}"; done