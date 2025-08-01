#!/bin/bash

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/tools/notifications/helpers.sh

# Starts the notifications service.
start () {
  if is_notifications_up; then
    log 'Notifications service is already runnning.'
    return 2
  fi

  log 'Starting notifications service...'

  dunst 1> /dev/null &

  local pid=$!

  ps -p "${pid}" 1> /dev/null
  
  if has_failed; then
    log 'Failed to start notifications service.'
    return 2
  fi

  log 'Notifications service started.'
}

# Restarts the notifications service.
restart () {
  log 'Restarting notifications service...'

  killall dunst || return 1
  sleep 1

  dunst 1> /dev/null &

  local pid=$!

  ps -p "${pid}" 1> /dev/null
  
  if has_failed; then
    log 'Failed to restart notifications service.'
    return 2
  fi

  log 'Notifications service restarted.'
}

# Shows the current status of the notification stream.
# Outputs:
#  A verbose list of text data.
show_status () {
  local space=10

  local is_service_up='false'

  if is_notifications_up; then
    is_service_up='true'
  fi

  local query='. | up_down | lbl("Service")'

  echo "${is_service_up}" | jq -cer --arg SPC ${space} "${query}" || return 1

  local query=''
  query+='\(.is_paused | yes_no | lbln("Mute") | ln)'
  query+='\(.pending            | lbln("Pending"))'
  query+='\(.displayed          | lbln("Showing"))'
  query+='\(.archived           | lbl("Sent"))'

  get_notifications_state | jq -cer --arg SPC ${space} "\"${query}\"" || return 1
}

# Shows the list of archived notifications sorted by the
# optionally given field and order.
# Arguments:
#  sort_by: id or app, default is id
# Outputs:
#  A long list of notificaions data.
list_all () {
  local sort_by="${1:-id}"

  if is_not_valid_sort_field "${sort_by}"; then
    log 'Invalid sorting field.'
    return 2
  fi

  local notifications=''
  notifications="$(find_all "${sort_by}" asc)" || return 1

  local len=0
  len="$(echo "${notifications}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No notifications have found.'
    return 0
  fi

  local sent_time=''
  sent_time+='.timestamp.data | ($u|tonumber) - (. / 1000000 | round) |'
  sent_time+='($e|tonumber) - . | localtime | strftime("%H:%M:%S")'

  local query=''
  query+='\(.id.data      | lbln("ID"))'
  query+='\(.appname.data | lbln("App"))'
  query+='\(.summary.data | olbln("Summary"))'
  query+='\(.body.data    | olbln("Body"))'
  query+="\(${sent_time}  | lbl(\"Sent\"))"

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  # Read the current uptime secs of the system
  local uptime=''
  uptime="$(cut -d '.' -f 1 /proc/uptime)" || return 1

  # Read the current secs from epoch time
  local epoch=''
  epoch="$(date +%s)" || return 1

  local space=10

  echo "${notifications}" |
    jq -cer --arg SPC ${space} --arg u ${uptime} --arg e ${epoch} "${query}" || return 1
}

# Pauses the notification stream.
mute_all () {
  dunstctl set-paused true 1> /dev/null

  if has_failed; then
    log 'Failed to mute notifications.'
    return 2
  fi

  log 'Notifications have been muted.'
}

# Restores the notification stream.
unmute_all () {
  dunstctl set-paused false 1> /dev/null

  if has_failed; then
    log 'Failed to unmute notifications.'
    return 2
  fi

  log 'Notifications have been unmuted.'
}

# Removes all the archived notifications.
clean_all () {
  dunstctl history-clear 1> /dev/null

  if has_failed; then
    log 'Failed to remove all notifications.'
    return 2
  fi

  log 'All notifications have been removed.'
}
