#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/desktop/commands.sh

LOGS='/var/log/stack/tools/desktop.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: desktop [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-6s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-32s %s\n' \
      'help' 'Show this help message.' \
      '' ''
  fi

  printf ' %-32s %s\n' \
    'show status' 'Show the status of the desktop environment.' \
    'show pointer <name>' 'Show a pointing device.' \
    'show tablet <name>' 'Show a tablet device.' \
    '' '' \
    'list wallpapers' 'List the available wallapers.' \
    'list pointers' 'List the available pointing devices.' \
    'list tablets' 'List the connected tablets.' \
    '' '' \
    'set wallpaper <name> <mode>' 'Set the desktop wallpaper on center,' \
    '' 'fill, scale, max or tile mode.' \
    'init wallpaper' 'Initialize the desktop wallpaper.' \
    '' '' \
    'speed pointer <factor>' 'Set the pointer speed to a factor between' \
    '' '[0, 1] where 0 means slow and 1 fast.' \
    'init pointer' 'Initialize the pointer.' \
    '' '' \
    'scale tablet <name> <factor>' 'Scale down the tablet area in range [0.1-1],' \
    '' 'where factor 1 means remove scaling.' \
    'map tablet <name> <display>' 'Map a tablet to a screen display' \
    '' 'or just use desktop to reset mapping.' \
    'init tablets' 'Initialize any connected tablets.' \
    '' '' \
    'add workspace <monitor>' 'Add a workspace to the given or current monitor.' \
    'remove workspace <index>' 'Remove a workspace with the given index.' \
    'fix workspaces' 'Fix dangling or misordered workspaces.' \
    'init workspaces' 'Initialize workspaces per active monitor.' \
    '' '' \
    'set backend xrender|glx' 'Set the compositor backend engine.' \
    'set vsync on|off' 'Enable or disable compositor vsync mode.' \
    '' '' \
    'init scratchpad' 'Initialize the sticky scratchpad terminal.' \
    'init bars' 'Initialize status bars.' \
    'init bindings' 'Initialize keyboard bindings.' \
    '' '' \
    'start' 'Start desktop user interface.' \
    'restart' 'Restart desktop user interface.'
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
    'show pointer') show_pointer "${3}";;
    'show tablet') show_tablet "${3}";;
    'set wallpaper') set_wallpaper "${3}" "${4}";;
    'speed pointer') set_pointer_speed "${3}";;
    'scale tablet') scale_tablet "${3}" "${4}";;
    'map tablet') map_tablet "${3}" "${4}";;
    'list wallpapers') list_wallpapers;;
    'list pointers') list_pointers;;
    'list tablets') list_tablets;;
    'init pointer') init_pointer;;
    'init tablets') init_tablets;;
    'init wallpaper') init_wallpaper;;
    'set backend') set_backend "${3}";;
    'set vsync') set_vsync "${3}";;
    'add workspace') add_workspace "${3}";;
    'remove workspace') remove_workspace "${3}";;
    'fix workspaces') fix_workspaces;;
    'init workspaces') init_workspaces;;
    'init scratchpad') init_scratchpad;;
    'init bars') init_bars;;
    'init bindings') init_bindings;;
    'start') start;;
    'restart') restart;;
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
      prompt desktop

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
