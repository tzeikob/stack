#!/bin/bash
# A bash script to setup a development stack environment

# Set current relative path
dir="$dir/stack"

# Create temporary files folder
temp="/tmp/scriptbox/stack"

log "Creating temporary files folder."

mkdir -p $temp

info "Temporary files folder $temp has been created.\n"

# Rename default home folders
if [[ $yesToAll = false ]]; then
  read -p "Do you want to rename the default home folders?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/home-folders.sh
fi

# Upgrade the system
if [[ $yesToAll = false ]]; then
  read -p "Do you want to upgrade your system?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/upgrade.sh
fi

# Install system languages
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install more languages [Greek]?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/languages.sh
fi

# Set local RTC time
if [[ $yesToAll = false ]]; then
  read -p "Do you want to use local RTC time?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/loca-time.sh
fi

# Disable screen lock
if [[ $yesToAll = false ]]; then
  read -p "Do you want to disable screen lock?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/screen-lock.sh
fi

# Install and sync dropbox
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install and sync dropbox?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/dropbox.sh
fi

# Install chrome
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install chrome?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/chrome.sh
fi

# Install skype
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install skype?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/skype.sh
fi

# Install slack
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install slack?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/slack.sh
fi

# Install virtualbox
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install virtual box?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/virtual-box.sh
fi

# Install git
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install git?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/git.sh
fi

# Install node
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install node?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/node.sh
fi

# Install java
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install java [openjdk-8, openjdk-13, maven]?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  source $dir/java.sh
fi
