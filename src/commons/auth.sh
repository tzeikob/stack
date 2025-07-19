#!/bin/bash

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

# Invalidates user's cached credentials and enforcing
# new password authentication.
# Returns:
#  0 if succeeded otherwise 1.
authenticate_user () {
  # Skip authentication for the root user
  if equals "$(id -u)" 0; then
    return 0
  fi

  # Invalidate user's cached credentials
  sudo -K

  local prompt='Permission needed for this operation.'
  prompt+='\nEnter current password:'

  ask_secret "${prompt}" || return $?
  is_empty "${REPLY}" && log 'Password is required.' && return 2

  local password="${REPLY}"

  # Mimic authentication with a dry run
  echo "${password}" | sudo -S /usr/bin/true 2> /dev/null

  if has_failed; then
    log 'Sorry incorrect password!'
    return 2
  fi
}
