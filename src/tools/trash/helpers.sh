#!/bin/bash

set -o pipefail

# Returns the list of all trashed files.
# Outputs:
#  A json array of trashed files.
find_files () {
  local files=''

  files="$(trash-list | awk '{
    schema="\"date\": \"%s\","
    schema=schema"\"time\": \"%s\","
    schema=schema"\"epoch_date\": %s,"
    schema=schema"\"epoch\": %s,"
    schema=schema"\"path\": \"%s\""
    schema="{"schema"},"

    path=""
    for (i = 3; i <= NF; i++) {
      path=path$i
      if (i < NF) path=path" "
    }

    cmd="date -d" $1 " +%s"; cmd | getline epoch_date; close(cmd);
    cmd="date -d" $1"T"$2 " +%s"; cmd | getline epoch; close(cmd);

    printf schema, $1, $2, epoch_date, epoch, path
  }')" || return 1

  # Remove the extra comma after the last element
  files="${files:+${files::-1}}"

  echo "[${files}]"
}

# Returns the list of all trashed files eligible
# for restoring.
# Outputs:
#  A json array of trashed files.
find_restorable_files () {
  local files=''

  files="$(trash-restore / <<< "" | awk '/^ *[0-9]+ /{
    schema="\"key\": \"%s\","
    schema=schema"\"value\": \"%s\""
    schema="{"schema"},"

    path=""
    for (i = 4; i <= NF; i++) {
      path=path$i
      if (i < NF) path=path" "
    }

    printf schema, $1, path
  }')" || return 1

  # Remove the extra comma after the last element
  files="${files:+${files::-1}}"
  
  echo "[${files}]"
}

