#!/bin/bash

set -o pipefail

source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/validators.sh

# Invalidates user's cached credentials and enforcing
# new password authentication.
# Returns:
#  0 if succeeded otherwise 1.
authenticate_user () {
  # Skip authentication for the root user
  if equals "$(id -u)" 0; then
    return 0
  fi

  log 'Permission needed for this operation.'

  # Invalidate user's cached credentials
  sudo -K

  # Mimic authentication with a dry run
  sudo /usr/bin/true &> /dev/null

  if has_failed; then
    log 'Sorry incorrect password!'
    return 2
  fi

  return 0
}
