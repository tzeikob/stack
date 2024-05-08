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
