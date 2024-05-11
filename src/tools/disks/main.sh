#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/input.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/disks/commands.sh

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: disks [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-10s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-58s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-58s %s\n' \
    'show status' 'Show a report of the file system.' \
    '' '' \
    'show disk <path>' 'Show a disk block device.' \
    'show partition <path>' 'Show a partition block device.' \
    'show rom <path>' 'Show an optical drive block device.' \
    '' '' \
    'list disks' 'List all disk block devices.' \
    'list partitions <disk>' 'List the partitions of a disk block device.' \
    'list roms' 'List all optical block devices.' \
    'list folders <host> <user> <group> <password>' 'List the shared folders of a host.' \
    'list mounts' 'List all mounting points.' \
    '' '' \
    'mount partition <path>' 'Mount a partition block device.' \
    'unmount partition <path>' 'Unmount a partition block device.' \
    'mount encrypted <path> <key>' 'Mount an encrypted partition block device.' \
    'unmount encrypted <path>' 'Unmount an encrypted partition block device.' \
    'mount rom <path>' 'Mount an optical block device.' \
    'unmount rom <path>' 'Unmount an optical block device.' \
    'mount image <path>' 'Mount an iso, img image file system.' \
    'unmount image <path>' 'Unmount an image file system.' \
    'mount folder <host> <name> <user> <group> <password>' 'Mount a shared storage folder.' \
    'unmount folder <uri>' 'Unmount a shared storage folder.' \
    '' '' \
    'format disk <path> <label> <fs-type>' 'Format a disk block device.' \
    'eject disk <path>' 'Eject a disk block device.' \
    'scan disk <path>' 'Scan a disk block device for SMART data.' \
    '' '' \
    'create encrypted <path> <fs-type> <key>' 'Create an encrypted drive.' \
    'create bootable <path> <iso-file>' 'Create a bootable installation drive.'
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
    'list disks') list_disks;;
    'list partitions') list_partitions "${3}";;
    'list roms') list_roms;;
    'list folders') list_shared_folders "${3}" "${4}" "${5}" "${6}";;
    'list mounts') list_mounts;;
    'show status') show_status;;
    'show disk') show_disk "${3}";;
    'show partition') show_partition "${3}";;
    'show rom') show_rom "${3}";;
    'mount partition') mount_partition "${3}";;
    'mount encrypted') mount_encrypted "${3}" "${4}";;
    'mount rom') mount_rom "${3}";;
    'mount image') mount_image "${3}";;
    'mount folder') mount_shared_folder "${3}" "${4}" "${5}" "${6}" "${7}";;
    'unmount partition') unmount_partition "${3}";;
    'unmount encrypted') unmount_encrypted "${3}";;
    'unmount rom') unmount_rom "${3}";;
    'unmount image') unmount_image "${3}";;
    'unmount folder') unmount_shared_folder "${3}";;
    'format disk') format_disk "${3}" "${4}" "${5}";;
    'eject disk') eject_disk "${3}";;
    'scan disk') scan_disk "${3}";;
    'create encrypted') create_encrypted "${3}" "${4}" "${5}";;
    'create bootable') create_bootable "${3}" "${4}";;
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
     's') ON_SCRIPT_MODE='true';;
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
      prompt disks

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

