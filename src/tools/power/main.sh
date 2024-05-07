#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/tools/power/commands.sh

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: power [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-10s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-36s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-36s %s\n' \
    'show status' 'Show the power status of the system.' \
    '' '' \
    'set action <handler> <action>' 'Set the action of a power handler like' \
    '' 'power, reboot, suspend, lid or docked to' \
    '' 'poweroff, reboot, suspend or ignore.' \
    'reset actions' 'Reset to default action for all power handlers.' \
    '' '' \
    'init screensaver' 'Initialize the screen saver.' \
    'set screensaver <mins>' 'Set the interval of the screen saver,' \
    '' 'where 0 means deactivate the screensaver.' \
    '' '' \
    'set tlp on|off' 'Enable or disable power saving mode.' \
    'set charging <start> <stop>' 'Set battery charging start and stop percent thresholds.' \
    '' '' \
    'shutdown' 'Shut the system down.' \
    'reboot' 'Reboot the system.' \
    'suspend' 'Set system in suspend mode.' \
    'blank' 'Blank the screen.'
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
    'set action') set_action "${3}" "${4}";;
    'set screensaver') set_screensaver "${3}";;
    'set tlp') set_tlp "${3}";;
    'set charging') set_charging "${3}" "${4}";;
    'reset actions') reset_actions;;
    'init screensaver') init_screensaver;;
    'shutdown') shutdown_system;;
    'reboot') reboot_system;;
    'suspend') suspend_system;;
    'blank') blank_screen;;
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
        set_quiet_mode 'on'
        show_help once
        return 0;;
     'q') set_quiet_mode 'on';;
     's') set_script_mode 'on';;
     *)
      log "Ooops, invalid or unknown option -${OPTARG}!"
      beep 2
      return $?;;
    esac
  done

  # Collect command arguments
  shift $((OPTIND-1))
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
      prompt power

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

run "$@"

