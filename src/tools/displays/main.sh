#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/displays/commands.sh

LOGS='/var/log/stack/tools/displays.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: displays [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-6s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
   
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-47s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-47s %s\n' \
    'show status' 'Show a report of the Xorg server and active outputs.' \
    '' '' \
    'list outputs <status>' 'List all outputs or those with status,' \
    '' 'connected, disconnected, active, inactive, primary.' \
    'show output <name>' 'Show the data of an output.' \
    '' '' \
    'set mode <name> <resolution> <rate>' 'Set the mode of an output.' \
    'set primary <name>' 'Set an output as primary.' \
    'set on|off <name>' 'Activate or de-activate an output.' \
    'rotate output <name> <mode>' 'Rotate an output to normal, right, left or inverted.' \
    'reflect output <name> <mode>' 'Reflect an output to normal, x, y or xy.' \
    'mirror output <name> <resolution> <targets>' 'Mirror an output to other outputs.' \
    '' '' \
    'set layout <mode> <outputs>' 'Set the layout of active outputs to row-2, col-2, row-3,' \
    '' 'col-3, gamma-3, gamma-rev-3, lambda-3 or lambda-rev-3,' \
    '' 'grid-4, taph-4, taph-rev-4, taph-right-4, taph-left-4.' \
    'save layout' 'Save the current layout of active outputs.' \
    'list layouts' 'List all layouts.' \
    'delete layout <index>' 'Delete a layout.' \
    'restore layout' 'Restore the layout matching the current mapping.' \
    'fix layout' 'Fix the positioning of the current layout.' \
    '' '' \
    'set color <output> <profile>' 'Set the color of a display connected to an output.' \
    'reset color <output>' 'Reset the color of a display connected to an output.' \
    'list colors' 'List all saved color settings per display.' \
    'restore colors' 'Restore color settings of any active displays.'
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
    'show output') show_output "${3}";;
    'list outputs') list_outputs "${3}";;
    'list colors') list_colors;;
    'list layouts') list_layouts;;
    'set layout') set_layout "${3}" "${@:4}";;
    'set mode') set_mode "${3}" "${4}" "${5}";;
    'set primary') set_primary "${3}";;
    'set on') set_on "${3}";;
    'set off') set_off "${3}";;
    'set color') set_color "${3}" "${4}";;
    'reset color') reset_color "${3}";;
    'save layout') save_layout;;
    'delete layout') delete_layout "${3}";;
    'restore layout') restore_layout;;
    'restore colors') restore_colors;;
    'rotate output') rotate_output "${3}" "${4}";;
    'reflect output') reflect_output "${3}" "${4}";;
    'mirror output') mirror_output "${3}" "${4}" "${@:5}";;
    'fix layout') fix_layout;;
    *)
      log 'Ooops, invalid or unknown command!'
      return 2;;
  esac
}

run () {
  local OPTIND='' opt=''

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
  shift $((OPTIND - 1))
  
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
      prompt displays

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
