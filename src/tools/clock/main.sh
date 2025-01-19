#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/clock/commands.sh

LOGS='/var/log/stack/tools/clock.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: clock [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-6s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-34s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-34s %s\n' \
    'show status' 'Show the system date time status.' \
    '' '' \
    'set timezone <name>' 'Set system timezone in region/city form.' \
    'set time <time>' 'Set system local time in hh:mm:ss form.' \
    'set date <date>' 'Set system date in yyyy-mm-dd form.' \
    '' '' \
    'format time <mode> <precision>' 'Set the status bar clock 12h/24h mode' \
    '' 'and precision to mins, secs or nanos.' \
    'format date <pattern>' 'Set the status bar date format.' \
    '' '' \
    'set ntp on|off' 'Enable or disable the NTP sync service.' \
    'set rtc local|utc' 'Set hardware clock to local or UTC time.' \
    '' '' \
    'sync rtc' 'Sync hardware clock to system clock.'
}

# Routes to the corresponding operation by matching
# the given command and object along with the list
# of arguments.
# Arguments:
#   command: the command to execute
#   object:  the object the command should operate on
#   args:    a list of arguments
execute () {
  local command="${1}"
  local object="${2}"
  
  case "${command}${object:+ ${object}}" in
    'show status') show_status;;
    'set ntp') set_ntp "${3}";;
    'set timezone') set_timezone "${3}";;
    'set time') set_time "${3}";;
    'set date') set_date "${3}";;
    'format time') format_time "${3}" "${4}";;
    'format date') format_date "${3}";;
    'set rtc') set_rtc "${3}";;
    'sync rtc') sync_rtc;;
    *)
      log 'Ooops, invalid or unknown command!'
      return 2;;
  esac
}

run () {
  local opt=''

  while getopts ':hqs' opt; do
    case "${opt}" in
     'h')
        ON_QUIET_MODE='true'
        show_help once
        return 0;;
     'q') ON_QUIET_MODE='true';;
     's') ON_SCRIPT_MODE='true';;
     *)
      log "Ooops, invalid or unknown option -${OPTARG}!"
      beep 2
      return $?;;
    esac
  done

  # Collect command arguments
  shift $(calc "${OPTIND} - 1")
  local args_len=$#

  if is_true "${args_len} = 0" && on_script_mode; then
    log 'Option -s cannot be used in loop mode.'
    beep 2
    return $?
  fi

  local mode='once'
  if is_true "${args_len} = 0"; then
    mode='loop'
    clear
  fi

  while true; do
    if equals "${mode}" 'loop'; then
      prompt clock

      local command=''
      command="$(echo "${REPLY}" | awk '{print (NF == 1) ? $1 : $0}')"

      case "${command}" in
        'help') clear && show_help && continue;;
        'clear') clear && continue;;
        'quit') break;;
        '') continue;;
      esac
      
      eval "execute ${REPLY[@]}"
    else
      execute "$@"
    fi

    # Save exit status code of the last executed operation
    local exit_code=$?
  
    if is_true "${exit_code} = 1"; then
      log 'Ooops, an unknwon error occurred!'
    fi

    on_loud_mode && beep "${exit_code}"

    if equals "${mode}" 'once'; then
      return ${exit_code}
    fi
  done

  clear
}

run "$@" 2>> "${LOGS}"
