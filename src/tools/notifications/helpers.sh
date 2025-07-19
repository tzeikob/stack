#!/bin/bash

source src/commons/validators.sh

# Returns the list of all archived notifications 
# sorted by the given field in the given order.
# Arguments:
#  sort_by:  id or app
#  order:    asc or desc, default is asc
# Outputs:
#  A json array of notification objects.
find_all () {
  local sort_by="${1}"
  local order="${2}"

  local query='.data[0]'

  if match "${sort_by}" '^(id|app)$'; then
    query+="| sort_by(.${sort_by})"

    if equals "${order}" 'desc'; then
      query+='| reverse'
    fi
  fi

  dunstctl history | jq -cr "${query}" || return 1
}

# Checks if the notifications stream service
# is up and running.
# Returns:
#  0 if notification service is up otherwise 1.
is_notifications_up () {
  local query=''
  query='[.[] | select(.command | test("/usr/bin/dunst|dunst.*"))] | length > 0'

  ps aux | grep -v 'jq' | jc --ps | jq -cer "${query}" &> /dev/null
}

# Checks if the given value is a valid sort field.
# Arguments:
#  field: a sort field name
# Returns:
#  0 if field is valid otherwise 1.
is_valid_sort_field () {
  local field="${1}"

  match "${field}" '^(id|app)$'
}

# An inverse version of is_valid_sort_field.
is_not_valid_sort_field () {
  ! is_valid_sort_field "${1}"
}

# Returns the notifications state.
# Outputs:
#  A json object of the notifiactions state.
get_notifications_state () {
  local state=''

  state+="$(dunstctl is-paused |
    awk '{print "\"is_paused\":"$0","}')" || return 1

  state+="$(dunstctl count | awk '{
    split($0, a, ":")

    if (a[1] ~ "Waiting") {
      print "\"pending\":"a[2]","
    } else if (a[1] ~ "Currently displayed") {
      print "\"displayed\":"a[2]","
    } else if (a[1] ~ "History") {
      print "\"archived\":"a[2]","
    }
  }')" || return 1

  # Remove extra comma after the last field
  state="${state:+${state::-1}}"

  echo "{${state}}"
}
