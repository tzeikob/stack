#!/bin/bash

source src/commons/process.sh
source src/commons/auth.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/printers/helpers.sh

# Shows a short status of cups service and printers.
# Outputs:
#  A list of cups and printer data.
show_status () {
  local space=10

  systemctl status --lines 0 --no-pager cups.service |
    awk -v SPC=${space} '{
      if ($0 ~ / *Active/) {
        l = "Service"
        v = $2" "$3
      } else l = ""

      if (!v || v ~ /^[[:blank:]]*$/) v = "N/A"

      frm = "%-"SPC"s%s\n"
      if (l) frm, l":", v
    }' || return 1

  echo "\"$(cups-config --version)\"" | jq -cer --arg SPC ${space} 'lbln("Cups")'
  echo "\"$(cups-config --api-version)\"" | jq -cer --arg SPC ${space} 'lbln("API")'
  echo "\"$(cups-config --datadir)\"" | jq -cer --arg SPC ${space} 'lbln("Dir")'

  find_jobs | jq -cer --arg SPC ${space} 'length | lbln("Jobs")' || return 1

  local destinations=''
  destinations="$(find_destinations | jq -cer './/[] | .[] | .name')" || return 1

  if is_not_empty "${destinations}"; then
    local query=''
    query+='\(.name      | lbln("Printer"))'
    query+='\(.is_shared | olbln("Shared"))'
    query+='\(.model     | olbln("Model"))'
    query+='\(.uri       | lbl("URI"))'

    local destination=''
    while read -r destination; do
      echo
      find_destination "${destination}" | jq -cer --arg SPC ${space} "\"${query}\"" || return 1
    done <<< "${destinations}"
  fi
}

# Shows the list of all printers.
# Outputs:
#  A list of printers.
list_printers () {
  local destinations=''
  destinations="$(find_destinations)" || return 1

  local len=0
  len="$(echo "${destinations}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No printers have found.'
    return 0
  fi

  local query=''
  query+='\(.name | lbln("Name"))'
  query+='\(.uri  | lbl("URI"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${destinations}" | jq -cer --arg SPC 7 "${query}" || return 1
}

# Shows the data of the printer with the given
# print destination name.
# Arguments:
#  name: the name of a print destination
# Outputs:
#  A long list of printer data.
show_printer () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Printer name is not given.' && return 2

    pick_printer || return $?
    is_empty "${REPLY}" && log 'Printer name is not selected.' && return 2
    name="${REPLY}"
  fi

  if destination_not_exists "${name}"; then
    log "Cannot find printer ${name}."
    return 2
  fi

  local query=''
  query+='\(.name           | lbln("Name"))'
  query+='\(.protocol       | lbln("Protocol"))'
  query+='\(.model          | olbln("Model"))'
  query+='\(.description    | olbln("Desc"))'
  query+='\(.location       | olbln("Location"))'
  query+='\(.state          | olbln("State"))'
  query+='\(.accepting_jobs | olbln("Accepts"))'
  query+='\(.shared         | olbln(("Shared"))'
  query+='\(.is_temp        | olbln("Temporary"))'
  query+='\(.ColorModel     | olbln("Color Model"))'
  query+='\(.color          | olbln("Color"))'
  query+='\(.Quality        | olbln("Quality"))'
  query+='\(.TonerSaveMode  | olbln("Toner"))'
  query+='\(.PageSize       | olbln("Page"))'
  query+='\(.MediaType      | olbln("Paper"))'
  query+='\(.uri            | lbl("URI"))'

  find_destination "${name}" | jq -cer --arg SPC 14 "\"${query}\"" || return 1
}

# Adds the printer with the given uri, name
# and driver.
# Arguments:
#  uri:    the uri of a print destination
#  name:   the name of the printer
#  driver: the driver of the printer
add_printer () {
  local uri="${1}"
  local name="${2}"
  local driver="${3}"

  if is_not_given "${uri}"; then
    on_script_mode &&
      log 'Printer uri is not given.' && return 2

    pick_uri || return $?
    is_empty "${REPLY}" && log 'Printer uri is required.' && return 2
    uri="${REPLY}"
  fi

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the printer name.' && return 2

    ask 'Enter the printer name:' || return $?
    is_empty "${REPLY}" && log 'Printer name is requried.' && return 2
    name="${REPLY}"
  fi

  if destination_exists "${name}"; then
    log "Printer ${name} already exists."
    return 2
  fi

  if is_not_given "${driver}"; then
    on_script_mode &&
      log 'Print driver is not given.' && return 2

    pick_driver || return $?
    is_empty "${REPLY}" && log 'Print driver is required.' && return 2
    driver="${REPLY}"
  fi

  if is_driver_not_available "${driver}"; then
    log "Driver ${driver} is not available."
    return 2
  fi

  lpadmin -p "${name}" -E -o printer-is-shared=false  -v "${uri}" -m "${driver}" &> /dev/null

  if has_failed; then
    log "Failed to add printer ${uri}."
    return 2
  fi

  log "Printer ${uri} added."
}

# Removes the printer destination with the
# given name.
# Arguments:
#  name: the name of a print destination
remove_printer () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing printer name.' && return 2

    pick_printer || return $?
    is_empty "${REPLY}" && log 'Printer name is required.' && return 2
    name="${REPLY}"
  fi

  if destination_not_exists "${name}"; then
    log "Cannot find printer ${name}."
    return 2
  fi

  lpadmin -x "${name}" &> /dev/null

  if has_failed; then
    log "Failed to remove printer ${name}."
    return 2
  fi

  log "Printer ${name} has been removed."
}

# Shares the printer with the given name
# to the local network.
# Arguments:
#  name: the name of a print destination
share_printer () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing printer name.' && return 2

    pick_printer || return $?
    is_empty "${REPLY}" && log 'Printer name is required.' && return 2
    name="${REPLY}"
  fi

  if destination_not_exists "${name}"; then
    log "Cannot find printer ${name}."
    return 2
  fi

  lpadmin -p "${name}" -o printer-is-shared=true &> /dev/null

  if has_failed; then
    log "Failed to share printer ${name}."
    return 2
  fi

  log "Printer ${name} has been shared."
}

# Unshares the printer with the given name
# of the local network.
# Arguments:
#  name: the name of a print destination
unshare_printer () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing printer name.' && return 2

    pick_printer || return $?
    is_empty "${REPLY}" && log 'Printer name is required.' && return 2
    name="${REPLY}"
  fi

  if destination_not_exists "${name}"; then
    log "Cannot find printer ${name}."
    return 2
  fi

  lpadmin -p "${name}" -o printer-is-shared=false &> /dev/null

  if has_failed; then
    log "Failed to unshare printer ${name}."
    return 2
  fi

  log "Printer ${name} has been unshared."
}

# Sets an option of the printer with the given name.
# Arguments:
#  name:  the name of a print destination
#  key:   quality, page, paper, toner or onerror
#  value: the value of the option
set_option () {
  local name="${1}"
  local key="${2}"
  local value="${3}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the printer name.' && return 2

    pick_printer || return $?
    is_empty "${REPLY}" && log 'Printer name is required.' && return 2
    name="${REPLY}"
  fi

  if destination_not_exists "${name}"; then
    log "Cannot find printer ${name}."
    return 2
  fi

  if is_not_given "${key}"; then
    on_script_mode &&
      log 'Missing print option key.' && return 2

    pick_print_option || return $?
    is_empty "${REPLY}" && log 'Print option key is required.' && return 2
    key="${REPLY}"
  fi

  if is_not_print_option "${key}"; then
    log 'Invalid print option key.'
    return 2
  fi

  if is_not_given "${value}"; then
    on_script_mode &&
      log 'Missing the print option value.' && return 2

    case "${key}" in
      Quality) pick_print_quality;;
      PageSize) pick_page_size;;
      MediaType) pick_media_type;;
      TonerSaveMode) pick_toner_mode;;
      printer-error-policy) pick_error_policy;;
      *)
        log 'Unknown or invalid print option key.'
        return 2;;
    esac || return $?
    is_empty "${REPLY}" && log 'Print option value is required.' && return 2
    value="${REPLY}"
  fi
   
  case "${key}" in
    Quality) is_valid_quality "${value}";;
    PageSize) is_valid_page_size "${value}";;
    MediaType) is_valid_media_type "${value}";;
    TonerSaveMode) is_valid_toner_mode "${value}";;
    printer-error-policy) is_valid_error_policy "${value}";;
    *)
      log 'Unknown or invalid print option key.'
      return 2;;
  esac

  if has_failed; then
    log 'Invalid print option value.'
    return 2
  fi

  lpadmin -p "${name}" -o "${key}"="${value}"

  if has_failed; then
    log 'Failed to set printer option.'
    return 2
  fi

  log "Option ${key} of printer ${name} set to ${value}."
}

# Sets the printer with the given name as default
# print destination.
# Arguments:
#  name: the name of a print destination
set_default () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the printer name.' && return 2

    pick_printer || return $?
    is_empty "${REPLY}" && log 'Printer name is required.' && return 2
    name="${REPLY}"
  fi

  if destination_not_exists "${name}"; then
    log "Cannot find printer ${name}."
    return 2
  fi

  lpoptions -d "${name}" &> /dev/null

  if has_failed; then
    log 'Failed to set default print destination.'
    return 2
  fi

  log "Printer ${name} set as default destination."
}

# Shows the list of all queued print jobs.
# Outputs:
#  A list of print jobs.
list_jobs () {
  local jobs=''
  jobs="$(find_jobs)" || return 1

  local len=0
  len="$(echo "${jobs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No active print jobs have found.'
    return 0
  fi

  local query=''
  query+='\(.id   | lbln("ID"))'
  query+='\(.rank | lbln("Rank"))'
  query+='\(.file | lbln("File"))'
  query+='\(.size | lbl("Size"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${jobs}" | jq -cer --arg SPC 7 "${query}" || return 1
}

# Cancels the queued job with the given id.
# Arguments:
#  id: the id of a print job
cancel_job () {
  local id="${1}"

  if is_not_given "${id}"; then
    on_script_mode &&
      log 'Missing the print job id.' && return 2

    pick_job || return $?
    is_empty "${REPLY}" && log 'Print job id is required.' && return 2
    id="${REPLY}"
  fi

  if job_not_exists "${id}"; then
    log "Cannot find print job ${id}."
    return 2
  fi

  cancel -x "${id}"

  if has_failed; then
    log "Failed to cancel print job ${id}."
    return 2
  fi

  log "Print job ${id} has been canceled."
}

# Restarts the cup service.
restart () {
  authenticate_user || return $?

  log 'Restarting the cups service...'

  sudo systemctl restart cups.service

  if has_failed; then
    log 'Failed to restart cups service.'
    return 2
  fi

  log 'Cups service has been restarted.'
}
