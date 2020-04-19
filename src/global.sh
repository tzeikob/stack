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

# Reset foreground color
reset_color="\e[39m"

# Dim style
dim="\e[2m"

# Reset dim style
reset_dim="\e[22m"

# Set dim text style
d () {
  echo "$dim$1$reset_dim"
}

# Log a normal message
log () {
  echo -e "$white$1$reset_color"
}

# Log an info message
info () {
  echo -e "$green$1$reset_color"
}

# Log a warn message
warn () {
  echo -e "$orange$1$reset_color"
}
