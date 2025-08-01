#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/audio/commands.sh

LOGS='/var/log/stack/tools/audio.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then 
    printf 'Usage: audio [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-6s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-30s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-30s %s\n' \
    'show status' 'Show a report of the system audio.' \
    '' '' \
    'list cards' 'List all cards of the system.' \
    'show card <name>' 'Show the data of a card.' \
    '' '' \
    'list outputs' 'List all outputs.' \
    'list inputs' 'List all inputs.' \
    'list playbacks <app>' 'List all active playbacks or those with the' \
    '' 'given application name.' \
    '' '' \
    'set profile <card> <name>' 'Set the active profile of a card.' \
    'set output <name>' 'Set the active output port.' \
    'set input <name>' 'Set the active input port.' \
    '' '' \
    'turn output|input <volume>' 'Turn the volume of active output/input to,' \
    '' 'up, down, mute, unmute or a percentage value.' \
    'mute outputs|inputs' 'Mute all outputs or inputs.' \
    'unmute outputs|inputs' 'Unmute all outputs or inputs.' \
    '' '' \
    'restart' 'Restart the audio services.'
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
    'show card') show_card "${3}";;
    'restart') restart;;
    'list cards') list_cards;;
    'list outputs') list_ports output;;
    'list inputs') list_ports input;;
    'list playbacks') list_playbacks "${3}";;
    'set profile') set_profile "${3}" "${4}";;
    'set output') set_default output "${3}";;
    'set input') set_default input "${3}";;
    'turn output') turn_default output "${3}";;
    'turn input') turn_default input "${3}";;
    'mute outputs') set_mute output 1;;
    'mute inputs') set_mute input 1;;
    'unmute outputs') set_mute output 0;;
    'unmute inputs') set_mute input 0;;
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
      prompt audio

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
