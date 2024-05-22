#!/bin/bash

set -Eeo pipefail

# Removes leading and trailing white spaces
# from the given string or input.
# Arguments:
#  input: a string or input of a pipeline
# Outputs:
#  The given input trimmed of trailing spaces.
trim () {
  local input=''

  if [[ -p /dev/stdin ]]; then
    input="$(cat -)"
  else
    input="$@"
  fi

  echo "${input}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Returns the md5 hash of the given string value
# truncated to the first given number of characters.
# Arguments:
#  value:  a string value
#  length: the number of character to keep
# Outputs:
#  A truncated md5 hash value.
get_hash () {
  local value="${1}"
  local length="${2:-32}"

  echo "${value}" | md5sum | cut "-c1-${length}"
}
