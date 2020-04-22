#!/bin/bash
# Script to expose global variables and functions

# Regular expression for yes answers
yes="^([Yy][Ee][Ss]|[Yy]|"")$"

# Yellow foreground color
yellow="\e[93m"

# Orange foreground color
orange="\e[33m"

# White foreground color
white="\e[97m"

# Green foreground color
green="\e[92m"

# Blue foreground color
blue="\e[94m"

# Red foreground color
red="\e[38;5;124m"

# Invert fore/background colors
invert="\e[7m"

# Dim text style
dim="\e[2m"

# Bold text style
bold="\e[1m"

# Reset text style and colors
reset="\e[0m"

# Set dim text style
d () {
  echo $dim$1$reset
}

# Set bold text style
b () {
  echo $bold$1$reset
}

# Log a normal message
log () {
  echo -e $white$1$reset
}

# Log an info message
info () {
  echo -e $green$1$reset
}

# Log a warn message
warn () {
  echo -e $orange$1$reset
}

highlight () {
  echo -e $invert$1$reset
}
