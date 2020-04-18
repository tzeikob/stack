#!/bin/bash
# Root bash script to route execution to scripts

# Read command line options
yesToAll=false

while getopts y OPT; do
  case "$OPT" in
    y) yesToAll=true
  esac
done

# Set script file's relative path
dir=$(dirname "$0")

# Load global goodies
source $dir"/global.sh"

# Initiate local variables
now=$(date)
distro=$(lsb_release -si)
version=$(lsb_release -sr)

# Print welcome screen
log "Scriptbox v1.0.0\n"
log "Date: $(d "$now")"
log "System: $(d "$distro $version")"
log "Host: $(d $HOSTNAME)"
log "User: $(d $USER)\n"

# Load the available script paths
scripts=()

for d in $dir/*/; do
  scripts+=(${d})
done

# List the scripts avaialble for execution
for i in ${!scripts[@]}; do
  name=$(basename ${scripts[$i]})
  name=$(tr '[:lower:]' '[:upper:]' <<< ${name:0:1})${name:1}

  log "$((i+1)). $name"
done

# Ask user to pick a script for execution
read -p "Enter the number of the script you want to execute? " index

if [[ $index =~ ^[0-9]+$ ]]; then
  if (( $index >= 1 && $index <= ${#scripts[@]} )); then
    script=${scripts[$(($index-1))]}
    script=${script}index.sh

    if [[ -f $script ]]; then
      log "\nExecuting the $script script file."
      source ${script}
      info "Script $script has been completed successfully.\n"
    else
      warn "Sorry, cannot find the $script script file."
    fi
  else
    warn "Sorry, that's a wrong answer."
  fi
else
  warn "Sorry, that's a wrong answer."
fi

log "Have a nice day, Bye!"
