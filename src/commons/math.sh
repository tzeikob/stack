#!/bin/bash

set -Eeo pipefail

# Calculates the given arithmetic expression.
# Arguments:
#  expression: any arithmetic expression
# Outputs:
#  The result of the arithmetic expression.
calc () {
  local expression="${1}"

  local result=0
  result="$(qalc -t "${expression}")" || return 1

  # Make sure scientific formats like 3e-9 convert to regular form
  result="$(echo "${result}" | awk '{print $0 + 0}')" || return 1

  echo "${result}"
}

# Checks if the given logical expression is true where expression
# could be any expression like 0 < 5 < 10 or any boolean literals.
# Arguments:
#  expression: any logical expression or boolean value
# Returns:
#  0 if expression is true otherwise 1.
is_true () {
  local expression="${1}"

  local result='false'
  result="$(qalc -t "${expression}")" || return 1

  if [[ "${result}" == 'true' ]] || [[ ${result} -eq 1 ]]; then
    return 0
  fi

  return 1
}

# An inverse version of is_true.
is_not_true () {
  is_true "${1}" && return 1 || return 0
}

# A alias version of is_not_true.
is_false () {
  is_not_true "${1}" && return 0 || return 1
}

# An inverse version of is_false.
is_not_false () {
  is_false "${1}" && return 1 || return 0
}
