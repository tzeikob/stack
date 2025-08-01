#!/bin/bash

source src/commons/process.sh
source src/commons/auth.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/security/helpers.sh
source src/tools/notifications/helpers.sh

# Shows the current status of the system's security.
# Outputs:
#  A verbose list of text data.
show_status () {
  local space=18

  local query=''
  query+='\(.password     | lbln("Password"))'
  query+='\(.last_changed | lbl("Changed"))'

  find_password_status | jq -cer --arg SPC ${space} "\"${query}\"" || return 1

  local query=''
  query+='\(.failed_attempts                | lbln("Failed Attempts"))'
  query+='\(.unblock_time  | unit(" secs")  | lbln("Unblock Time"))'
  query+='\(.fail_interval | unit(" secs")  | lbl("Fail Interval"))'

  find_faillock_status | jq -cer --arg SPC ${space} "\"${query}\"" || return 1

  local query='unit(" mins") | lbl("Screen Locker")'

  find_locker_status | jq -cer --arg SPC ${space} "${query}" || return 1
}

# Sets the screen locker given the interval
# time in mins, where 0 means deactivate the
# locker.
# Arguments:
#  interval: the interval time in mins [0,60]
set_screen_locker () {
  local interval="${1}"

  if is_not_given "${interval}"; then
    log 'Missing interval time.'
    return 2
  elif is_not_integer "${interval}"; then
    log 'Invalid interval time.'
    return 2
  elif is_not_integer "${interval}" '[0,60]'; then
    log 'Interval time out of range [0,60].'
    return 2
  fi

  # Kill possibly running locker instances
  kill_screen_locker || return 1

  if is_true "${interval} > 0"; then
    xautolock -locker "security -qs lock screen" \
      -nowlocker "security -qs lock screen" -time "${interval}" \
      -corners 0-00 -detectsleep 1> /dev/null &
    
    sleep 1

    if is_process_down '^xautolock'; then
      log 'Failed to set the screen locker.'
      return 2
    fi
  
    log "Screen locker set to ${interval} mins."
  else
    log "Screen locker has been disabled."
  fi
  
  save_screen_locker_to_settings "${interval}" ||
    log 'Failed to save screen locker into settings.'
}

# Initiates the screen locker from
# the settings stored in settings file.
init_screen_locker () {
  local interval=8

  if file_exists "${SECURITY_SETTINGS}"; then
    interval="$(jq '.screen_locker.interval//8' "${SECURITY_SETTINGS}")"
  fi

  # Kill possibly running locker instances
  kill_screen_locker || return 1

  if is_true "${interval} > 0"; then
    xautolock -locker "security -qs lock screen" \
      -nowlocker "security -qs lock screen" -time "${interval}" \
      -corners 0-00 -detectsleep 1> /dev/null &
    
    sleep 1

    if is_process_down '^xautolock'; then
      log 'Failed to initialize the screen locker.'
      return 2
    fi
    
    log "Screen locker initialized to ${interval} mins."
  else
    log "Screen locker has been disabled."
  fi
}

# Locks the screen making sure notifications stream is muted
# before lock and resets it back to it's previous state
# after user unlocks the screen.
lock_screen () {
  if is_screen_locked; then
    log 'Screen locker is already running.'
    return 2
  fi

  local is_paused=''
  is_paused="$(get_notifications_state | jq -cr '.is_paused')"

  if is_false "${is_paused}"; then
    notifications -qs mute all
  fi

  env XSECURELOCK_FONT='PixelMix' \
    XSECURELOCK_SAVER='saver_clock' \
    XSECURELOCK_NO_COMPOSITE=1 \
    XSECURELOCK_BLANK_TIMEOUT=-1 \
    xsecurelock 1> /dev/null

  if has_failed; then
    log 'Failed to lock the screen.'
    return 2
  fi

  # Reset notifications stream to previous state
  if is_false "${is_paused}"; then
    notifications -qs unmute all
  fi
}

# Changes the password of the current user.
set_user_password () {
  authenticate_user || return $?

  ask_secret 'Enter new password (at least 4 chars):' || return $?
  is_empty "${REPLY}" && log 'New password cannot be blank.' && return 2
  
  while not_match "${REPLY}" '^[a-zA-Z0-9`~!@#\$%^&*()=+{};:",.<>/\?_-]{4,}$'; do
    ask_secret 'Please enter a valid password:' || return $?
    is_empty "${REPLY}" && log 'New password cannot be blank.' && return 2
  done

  local new_password="${REPLY}"
  
  ask_secret 'Retype new password:' || return $?
  
  if not_equals "${REPLY}" "${new_password}"; then
    log 'New password does not match!'
    return 2
  fi

  echo -e "${new_password}\n${new_password}" |
    sudo passwd --quiet "${USER}" 1> /dev/null

  if has_failed; then
    log 'Failed to set user password.'
    return 2
  fi

  log 'User password has been set.'
}

# Logs the user out, terminating the current xorg session.
logout_user () {
  bspc quit

  if has_failed; then
    log 'Failed to logout the user.'
    return 2
  fi
}

# Sets the max number of failed attempts before
# the user's password gets blocked.
# Arguments:
#  attempts: the max number of failed password attempts
set_faillock_attempts () {
  authenticate_user || return $?

  local attempts="${1}"

  if is_not_given "${attempts}"; then
    log 'Missing attempts number.'
    return 2
  elif is_not_integer "${attempts}" '[0,]'; then
    log 'Invalid attempts number.'
    return 2
  elif is_true "${attempts} < 1"; then
    log 'Attempts number should be greater than 0.'
    return 2
  fi

  sudo sed -ri "s;deny =.*;deny = ${attempts};" /etc/security/faillock.conf

  if has_failed; then
    log 'Failed to set max failed attempts.'
    return 2
  fi

  log "Failed attempts set to ${attempts}."
}

# Sets the time a blocked password should be unblocked.
# Arguments:
#  time: the time in secs to unblock the password
set_faillock_unblock () {
  authenticate_user || return $?

  local time="${1}"
  
  if is_not_given "${time}"; then
    log 'Missing unblock time.'
    return 2
  elif is_not_integer "${time}" '[0,]'; then
    log 'Invalid unblock time.'
    return 2
  elif is_true "${time} < 1"; then
    log 'Unblock time should be greater than 0.'
    return 2
  fi

  sudo sed -ri "s;unlock_time =.*;unlock_time = ${time};" /etc/security/faillock.conf

  if has_failed; then
    log 'Failed to set unblock time.'
    return 2
  fi

  log "Unblock time set to ${time} secs."
}

# Sets the interval in which a failed password attempt
# should be counted as consecutive attempt to trigger
# a password block.
# Arguments:
#  time: the time in secs between consecutive fails
set_faillock_interval () {
  authenticate_user || return $?

  local time="${1}"

  if is_not_given "${time}"; then
    log 'Missing interval time.'
    return 2
  elif is_not_integer "${time}" '[0,]'; then
    log 'Invalid interval time.'
    return 2
  elif is_true "${time} < 1"; then
    log 'Interval time should be greater than 0.'
    return 2
  fi

  sudo sed -ri "s;fail_interval =.*;fail_interval = ${time};" /etc/security/faillock.conf

  if has_failed; then
    log 'Failed to set fail interval.'
    return 2
  fi

  log "Fail interval set to ${time} secs."
}
