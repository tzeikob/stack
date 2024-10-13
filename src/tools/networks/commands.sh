#!/bin/bash

source src/commons/process.sh
source src/commons/input.sh
source src/commons/auth.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/networks/helpers.sh

# Shows the current status of the system networking.
# Outputs:
#  A long list of networking data.
show_status () {
  local space=13

  systemctl status --lines 0 --no-pager NetworkManager.service |
    awk -v SPC=${space} '{
      if ($0 ~ / *Active/) {
        l = "Service"
        v = $2" "$3
      } else l = ""

      if (!v || v ~ /^[[:blank:]]*$/) v = "N/A"

      frm = "%-"SPC"s%s\n"
      if (l) printf frm, l":", v
    }' || return 1

  local devices=''
  devices="$(find_devices)" || return 1

  local network=''
  network+='[$d[] | select((.type == "wifi" or .type == "ethernet") and .state == "connected")]'
  network+='| if . | length == 0 then "local" else .[0] | .device end'

  local query=''
  query+="\(${network}    | lbln("Network"))"
  query+='\(.state        | lbln("State"))'
  query+='\(.connectivity | lbln("Connect"))'
  query+='\(.wifi         | lbln("WiFi"))'
  query+='\(.wifi_hw      | lbln("Antenna"))'

  find_status | jq -cer --arg SPC ${space} --argjson d "${devices}" "\"${query}\"" || return 1

  local proxy_env="${HOME}/.config/environment.d/proxy.conf"

  local proxy=''
  if file_exists "${proxy_env}"; then
    proxy="$(cat "${proxy_env}" | awk -F'=' '/export http_proxy=/ {
      split($2,a,"http://")

      if (a[2] ~ /@/) {
        split(a[2],b,"@")
        print b[2]
      } else print a[2]
    }' | tr -d '"/')" || return 1
  fi

  echo "\"${proxy}\"" | jq -cer --arg SPC ${space} 'lbln("Proxy"; "None")'

  local query=''
  query+='\(.as | split(" ") | "\(.[1]) \(.[2])") [\(.isp)] | lbln("ISP"))'
  query+='\(.query                                          | lbln("IP"))'
  query+='\(.country                                        | lbl("Location"))'

  curl -s 'http://ip-api.com/json' | jq -cer --arg SPC ${space} "\"${query}\"" 2> /dev/null

  if has_failed; then
    echo '""' | jq -cer --arg SPC ${space} 'lbl("ISP"; "Unavailable")'
  fi

  local query=''
  query+='.[] | select(.type | test("(^ethernet|wifi|vpn)$")) | .name'

  local connections=''
  connections="$(nmcli connection show --active | jc --nmcli | jq -cr "${query}")" || return 1

  if is_empty "${connections}"; then
    return 0
  fi

  local device=''
  device+='if .connection_type == "vpn" then .ip_iface else .connection_interface_name end'

  local vpn_host=''
  vpn_host='if .connection_type == "vpn" then .vpn_gateway else "" end'

  local query=''
  query+='\(.connection_id                                   | lbln("Connection"))'
  query+='\(.default                                         | lbln("Default"))'
  query+='\(."802_11_wireless_ssid"                          | olbln("SSID"))'
  query+="\(${device}                                        | lbln("Device"))"
  query+='\(.freq | unit("GHz")                              | olbln("Freq"))'
  query+='\(.rate | unit("Mb/s")                             | olbln("Rate"))'
  query+='\(.quality                                         | olbln("Quality"))'
  query+='\(.signal | unit("dBm")                            | olbln("Signal"))'
  query+='\(.vpn_type                                        | olbln("VPN"))'
  query+="\(${vpn_host}                                      | olbln("Host"))"
  query+='\(.vpn_username                                    | olbln("User"))'
  query+='\(."802_11_wireless_security_key_mgmt" | uppercase | olbln("Security"))'
  query+='\(.ip4_address_1                                   | olbln("IPv4"))'
  query+='\(.connection_type                                 | lbl("Type"))'

  local connection=''
  while read -r connection; do
    echo
    find_connection "${connection}" | jq -cer --arg SPC ${space} "\"${query}\"" || return 1
  done <<< "${connections}"
}

# Shows the data of the network device with
# the given name.
# Arguments:
#  name: the name of a device
# Outputs:
#  A long list of device data.
show_device () {
  local name="${1}"
  
  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing network device name.' && return 2
    
    pick_device || return $?
    is_empty "${REPLY}" && log 'Network device name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_network_device "${name}"; then
    log "Network device ${name} not found."
    return 2
  fi

  local query=''
  query+='\(.device               | lbln("Name"))'
  query+='\(.type                 | lbln("Type"))'
  query+='\(.hwaddr               | lbln("MAC"))'
  query+='\(.freq | unit("GHz")   | olbln("Freq"))'
  query+='\(.rate | unit("Mb/s"   | olbln("Rate"))'
  query+='\(.quality              | olbln("Quality"))'
  query+='\(.signal | unit("dBm") | olbln("Signal"))'
  query+='\(.state_text           | olbln("State"))'
  query+='\(.mtu                  | lbln("MTU"))'
  query+='\(.ip4_address_1        | olbln("IPv4"))'
  query+='\(.ip4_gateway          | olbln("Gateway"))'
  query+='\(.ip4_route_1.dst      | olbln("Route"))'
  query+='\(.ip4_dns_1            | olbln("DNS1"))'
  query+='\(.ip4_dns_2            | olbln("DNS2"))'
  query+='\(.ip6_address_1        | olbln("IPv6"))'
  query+='\(.ip6_gateway          | olbln("Gateway"))'
  query+='\(.ip6_route_1.dist     | olbln("Route"))'
  query+='\(.connection           | lbl("Connection"; "None"))'

  find_device "${name}" | jq -cer --arg SPC 13 "\"${query}\"" || return 1
}

# Shows the data of the network connection with the
# given name.
# Arguments:
#  name: the name of a connection
# Outputs:
#  A long list of connection data.
show_connection () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing connection name.' && return 2
    
    pick_connection || return $?
    is_empty "${REPLY}" && log 'Connection name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_connection "${name}"; then
    log "Connection ${name} not found."
    return 2
  fi

  local device=''
  device+='if .connection_type == "vpn" then .ip_iface else .connection_interface_name end'

  local host=''
  host+='if .connection_type == "vpn" then .vpn_gateway else "" end'

  local query=''
  query+='\(.connection_id                                   | lbln("Connection"))'
  query+='\(.default                                         | lbln("Default"))'
  query+='\(."802_11_wireless_ssid"                          | olbln("SSID"))'
  query+='\(.connection_uuid                                 | olbln("UUID"))'
  query+="\(${device}                                        | lbln("Device"; "None"))"
  query+='\(.freq | unit("GHz")                              | olbln("Freq"))'
  query+='\(.rate | unit("Mb/s")                             | olbln("Rate"))'
  query+='\(.quality                                         | olbln("Quality"))'
  query+='\(.signal | unit("dBm")                            | olbln("Signal"))'
  query+='\(.state                                           | olbln("State"))'
  query+='\(.connection_autoconnect                          | lbln("Auto"))'
  query+='\(.vpn_type                                        | olbln("VPN"))'
  query+="\(${host}                                          | olbln("Host"))"
  query+='\(.vpn_username                                    | olbln("User"))'
  query+='\(."802_11_wireless_security_key_mgmt" | uppercase | lbln("Security"))'
  query+='\(.ip4_address_1                                   | olbln("IPv4"))'
  query+='\(.ip4_gateway                                     | olbln("Gateway"))'
  query+='\(.ip4_route_1.dst                                 | olbln("Route"))'
  query+='\(.ip4_dns_1                                       | olbln("DNS1"))'
  query+='\(.ip4_dns_2                                       | olbln("DNS2"))'
  query+='\(.ip6_address_1                                   | olbln("IPv6"))'
  query+='\(.ip6_gateway                                     | olbln("Gateway"))'
  query+='\(.ip6_route_1.dst                                 | olbln("Route"))'
  query+='\(.connection_type                                 | lbl("Type))'

  find_connection "${name}" | jq -cer --arg SPC 13 "\"${query}\"" || return 1
}

# Shows the list of networking devices.
# Outputs:
#  A list of network devices.
list_devices () {
  local devices=''
  devices="$(find_devices)" || return 1

  local len=0
  len="$(echo "${devices}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No network devices have found.'
    return 0
  fi

  local query=''
  query+='\(.device     | lbln("Name"))'
  query+='\(.type       | lbln("Type"))'
  query+='\(.state      | lbln("State"; "None"))'
  query+='\(.connection | lbl("Connection"; "None"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${devices}" | jq -cer --arg SPC 13 "${query}" || return 1
}

# Shows the list of networking connections.
# Outputs:
#  A list of network connections.
list_connections () {
  local connections=''
  connections="$(find_connections)" || return 1

  local len=0
  len="$(echo "${connections}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No connections have found.'
    return 0
  fi

  local query=''
  query+='\(.name   | lbln("Name"))'
  query+='\(.type   | lbln("Type"))'
  query+='\(.device | lbl("Device"; "None"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${connections}" | jq -cer --arg SPC 9 "${query}" || return 1
}

# Detects the available wifi networks in the local area
# with signal strength at least the given limit.
# Arguments:
#  device: the name of a wifi device
#  singal: a signal limitation value
# Outputs:
#  The list of wifi networks.
list_wifis () {
  local device="${1}"
  local signal="${2:-"0"}"

  if is_not_given "${device}"; then
    on_script_mode &&
      log 'Missing wifi device name.' && return 2
    
    pick_device wifi || return $?
    is_empty "${REPLY}" && log 'Wifi device name required.' && return 2
    device="${REPLY}"
  fi

  if is_not_network_device "${device}" wifi; then
    log "Wifi device ${device} not found."
    return 2
  fi

  if is_not_integer "${signal}"; then
    log 'Invalid signal limit value.'
    return 2
  elif is_not_integer "${signal}" '[0,100]'; then
    log 'Signal limit value out of range.'
    return 2
  fi

  log 'Detecting available wifi networks...'

  local networks=''
  networks="$(find_wifis "${device}" "${signal}")"

  if has_failed; then
    log 'Unable to detect wifi networks.'
    return 2
  fi

  local len=0
  len="$(echo "${networks}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No wifi networks detected.'
    return 0
  fi

  local query=''
  query+='\(.ssid                 | lbln("Name"))'
  query+='\(.signal               | lbln("Signal"))'
  query+='\(.channel              | lbln("Channel"))'
  query+='\(.security | uppercase | lbl("Security"; "None"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${networks}" | jq -cer --arg SPC 11 "${query}" || return 1
}

# Enables the device with the given name.
# Arguments:
#  name: the name of a device
up_device () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing network device name.' && return 2
    
    pick_device || return $?
    is_empty "${REPLY}" && log 'Network device name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_network_device "${name}"; then
    log "Network device ${name} not found."
    return 2
  fi

  log "Enabling network device ${name}..."

  nmcli device connect "${name}" &> /dev/null

  if has_failed; then
    log 'Failed to enable network device.'
    return 2
  fi

  log "Network device ${name} enabled."
}

# Enables the connection with the given name.
# Arguments:
#  name: the name of a connection
up_connection () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing connection name.' && return 2
    
    pick_connection || return $?
    is_empty "${REPLY}" && log 'Connection name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_connection "${name}"; then
    log "Connection ${name} not found."
    return 2
  fi

  log "Enabling connection ${name}..."

  nmcli connection up "${name}" --ask

  if has_failed; then
    log 'Failed to enable connection.'
    return 2
  fi

  log "Connection ${name} enabled."
}

# Disables the device with the given name.
# Arguments:
#  name: the name of a device
down_device () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing network device name.' && return 2
    
    pick_device || return $?
    is_empty "${REPLY}" && log 'Network device name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_network_device "${name}"; then
    log "Network device ${name} not found."
    return 2
  fi

  log "Disabling network device ${name}..."

  nmcli device disconnect "${name}" &> /dev/null

  if has_failed; then
    log 'Failed to disable network device.'
    return 2
  fi

  log "Network device ${name} disabled."
}

# Disables the connection with the given name.
# Arguments:
#  name: the name of a connection
down_connection () {
  local name="${1}"

  if is_not_given "${name}" ]]; then
    on_script_mode &&
      log 'Missing connection name.' && return 2
    
    pick_connection || return $?
    is_empty "${REPLY}" && log 'Connection name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_connection "${name}"; then
    log "Connection ${name} not found."
    return 2
  fi

  log "Disabling connection ${name}..."

  nmcli connection down "${name}" &> /dev/null

  if has_failed; then
    log 'Failed to disable connection.'
    return 2
  fi

  log "Connection ${name} disabled."
}

# Removes the software network device with
# the given name.
# Arguments:
#  name: the name of a network device
remove_device () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing network device name.' && return 2
    
    pick_device || return $?
    is_empty "${REPLY}" && log 'Network device name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_network_device "${name}"; then
    log "Network device ${name} not found."
    return 2
  fi

  log "Removing network device ${name}..."

  nmcli device delete "${name}" &> /dev/null

  if has_failed; then
    log 'Failed to remove network device.'
    return 2
  fi

  log "Network device ${name} removed."
}

# Removes the connection with the given name.
# Arguments:
#  name: the name of a connection
remove_connection () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing connection name.' && return 2
    
    pick_connection || return $?
    is_empty "${REPLY}" && log 'Connection name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_connection "${name}"; then
    log "Connection ${name} not found."
    return 2
  fi

  log "Removing connection ${name}..."

  nmcli connection delete "${name}" &> /dev/null

  if has_failed; then
    log 'Failed to remove connection.'
    return 2
  fi

  log "Connection ${name} removed."
}

# Adds a new ethernet connection with static ip address.
# Arguments:
#  device:  the name of ethernet device
#  name:    the name of the connection
#  ip:      the static ip address
#  gateway: the gateway ip address
#  dns:     comma separated dns servers
add_ethernet () {
  local device="${1}"
  local name="${2}"
  local ip="${3}"
  local gateway="${4}"
  local dns="${5}"

  if is_not_given "${device}"; then
    on_script_mode &&
      log 'Missing ethernet device name.' && return 2
  
    pick_device ethernet || return $?
    is_empty "${REPLY}" && log 'Ethernet device name required.' && return 2
    device="${REPLY}"
  fi

  if is_not_network_device "${device}" 'ethernet'; then
    log "Ethernet device ${device} not found."
    return 2
  fi

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing connection name.' && return 2

    ask 'Enter a connection name:' || return $?
    is_empty "${REPLY}" && log 'Connection name required.' && return 2
    name="${REPLY}"
  fi

  if find_connection "${name}" &> /dev/null; then
    log "Connection ${name} already exists."
    return 2
  fi

  if is_not_given "${ip}"; then
    on_script_mode &&
      log 'Missing static ip address.' && return 2

    ask 'Enter static ip address:' || return $?
    is_empty "${REPLY}" && log 'Static ip address required.' && return 2
    ip="${REPLY}"
  fi

  if is_not_given "${gateway}"; then
    on_script_mode &&
      log 'Missing gateway address.' && return 2

    ask 'Enter gateway address:' || return $?
    is_empty "${REPLY}" && log 'Gateway address required.' && return 2
    gateway="${REPLY}"
  fi

  if is_not_given "${dns}"; then
    on_script_mode &&
      log 'Missing dns servers.' && return 2

    ask 'Enter dns servers:' || return $?
    is_empty "${REPLY}" && log 'Primary dns server required.' && return 2
    dns="${REPLY}"
  fi

  log "Creating ethernet connection ${name}..."

  nmcli connection add type ethernet \
    con-name "${name}" ifname "${device}" ipv4.method "manual" \
    ipv4.addresses "${ip}/24" ipv4.gateway "${gateway}" ipv4.dns "${dns}"

  if has_failed; then
    log 'Failed to create ethernet connection.'
    return 2
  fi

  log "Ethernet connection ${name} created."
}

# Adds a new dhcp ethernet connection.
# Arguments:
#  device: the name of ethernet device
#  name:   the name of the connection
add_dhcp () {
  local device="${1}"
  local name="${2}"

  if is_not_given "${device}"; then
    on_script_mode &&
      log 'Missing ethernet device name.' && return 2
  
    pick_device ethernet || return $?
    is_empty "${REPLY}" && log 'Ethernet device name required.' && return 2
    device="${REPLY}"
  fi

  if is_not_network_device "${device}" 'ethernet'; then
    log "Ethernet device ${device} not found."
    return 2
  fi

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing connection name.' && return 2

    ask 'Enter a connection name:' || return $?
    is_empty "${REPLY}" && log 'Connection name required.' && return 2
    name="${REPLY}"
  fi

  if find_connection "${name}" &> /dev/null; then
    log "Connection ${name} already exists."
    return 2
  fi

  log "Creating ethernet dhcp connection ${name}..."

  nmcli connection add type ethernet \
    con-name "${name}" ifname "${device}" ipv4.method auto
  
  if has_failed; then
    log 'Failed to create ethernet dhcp connection.'
    return 2
  fi

  log "Ethernet dhcp connection ${name} created."
}

# Adds a wifi connection to wireless network.
# Arguments:
#  device: the wifi device
#  ssid:   the wifi network id
#  secret: the private key of the wifi network
add_wifi () {
  local device="${1}"
  local ssid="${2}"
  local secret="${3}"

  if is_not_given "${device}"; then
    on_script_mode &&
      log 'Missing wifi device name.' && return 2

    pick_device wifi || return $?
    is_empty "${REPLY}" && log 'Wifi device name required.' && return 2
    device="${REPLY}"
  fi
  
  if is_not_network_device "${device}" 'wifi'; then
    log "Wifi device ${device} not found."
    return 2
  fi

  if is_not_given "${ssid}"; then
    on_script_mode &&
      log 'Missing network ssid.' && return 2

    pick_wifi "${device}" || return $?
    is_empty "${REPLY}" && log 'Network ssid required.' && return 2
    ssid="${REPLY}"
  fi

  if is_not_given "${secret}"; then
    on_script_mode &&
      log 'Missing private key.' && return 2

    ask_secret 'Enter private key:' || return $?
    is_empty "${REPLY}" && log 'Private key required.' && return 2
    secret="${REPLY}"
  fi

  log "Connecting to network ${ssid}..."

  local result=''
  result="$(nmcli device wifi connect "${ssid}" password "${secret}" \
    ifname "${device}" hidden yes 2> /dev/null)"
  
  if has_failed || match "${result}" '(E|e)rror'; then
    log "Failed to connect to ${ssid}."
    return 2
  fi

  log "Connection to ${ssid} established."
}

# Adds a new vpn connection from the given ovpn file.
# Arguments:
#  file_path: the ovpn file path
#  username:  the user name
#  password:  the user password
add_vpn () {
  local file_path="${1}"
  local username="${2}"
  local password="${3}"

  if is_not_given "${file_path}"; then
    on_script_mode &&
      log 'Missing ovpn file path.' && return 2
      
    ask 'Enter path to ovpn file:' || return $?
    is_empty "${REPLY}" && log 'Ovpn file path required.' && return 2
    file_path="${REPLY}"
  fi

  if file_not_exists "${file_path}"; then
    log "File ${file_path} not found."
    return 2
  elif is_not_ovpn_file "${file_path}"; then
    log 'Invalid ovpn file type.'
    return 2
  fi

  local name=''
  name=$(basename -- "${file_path}")
  name="${name%.*}"

  if find_connection "${name}" &> /dev/null; then
    log "Connection ${name} already exists."
    return 2
  fi

  if is_not_given "${username}"; then
    on_script_mode &&
      log 'Missing the username.' && return 2

    ask 'Enter the username:' || return $?
    is_empty "${REPLY}" && log 'Username required.' && return 2
    username="${REPLY}"
  fi

  if is_not_given "${password}"; then
    on_script_mode &&
      log 'Missing the password.' && return 2

    ask_secret 'Enter the password:' || return $?
    is_empty "${REPLY}" && log 'Password required.' && return 2
    password="${REPLY}"
  fi

  log "Creating VPN connection ${name}..."

  nmcli connection import type openvpn file "${file_path}"

  if has_failed; then
    log 'Failed to create VPN connection.'
    return 2
  fi

  nmcli connection modify "${name}" +vpn.data username="${username}" || return 1
  nmcli connection modify "${name}" +vpn.secrets password="${password}" || return 1

  log "VPN connection ${name} created."
}

# Adds a new proxy profile with the given name.
# Arguments:
#  name:     the name of the proxy profile
#  host:     the host of the proxy server
#  port:     the port of the proxy server
#  username: the user name
#  password: the password
#  no_proxy: the hosts to ignore proxy
add_proxy () {
  local name="${1}"
  local host="${2}"
  local port="${3}"
  local username="${4}"
  local password="${5}"
  local no_proxy="${6}"
  
  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing proxy profile name.' && return 2
    
    ask 'Enter a proxy profile name:' || return $?
    is_empty "${REPLY}" && log 'Proxy profile name required.' && return 2
    name="${REPLY}"
  fi

  if exists_proxy_profile "${name}"; then
    log "Proxy profile ${name} already exists."
    return 2
  fi

  if is_not_given "${host}"; then
    on_script_mode &&
      log 'Missing proxy host server.' && return 2
    
    ask 'Enter proxy host server:' || return $?
    is_empty "${REPLY}" && log 'Proxy host server required.' && return 2
    host="${REPLY}"
  fi

  if is_not_given "${port}"; then
    on_script_mode &&
      log 'Missing proxy server port.' && return 2
    
    ask 'Enter proxy server port:' || return $?
    is_empty "${REPLY}" && log 'Proxy server port required.' && return 2
    port="${REPLY}"
  fi

  if on_user_mode; then
    if is_not_given "${username}"; then
      ask 'Enter the username [optional]:' || return $?
      username="${REPLY}"
    fi
    
    if is_not_given "${password}"; then
      ask_secret 'Enter the password [optional]:' || return $?
      password="${REPLY}"
    fi
    
    if is_not_given "${no_proxy}"; then
      ask 'Enter no proxy hosts [optional]:' || return $?
      no_proxy="${REPLY}"
    fi
  fi

  save_proxy_to_settings "${name}" "${host}" "${port}" "${username}" "${password}" "${no_proxy}"
  
  log "Proxy profile ${name} added."
}

# Removes the proxy profile with the given name.
# Arguments:
#  name: the name of the proxy profile
remove_proxy () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing proxy profile name.' && return 2

    pick_proxy || return $?
    is_empty "${REPLY}" && log 'Proxy profile name required.' && return 2
    name="${REPLY}"
  fi

  if file_not_exists "${NETWORKS_SETTINGS}"; then
    log 'No proxy profiles found.'
    return 2
  fi

  local query=".proxies | if . then .[] | select(.name == \"${name}\") else empty end"

  local match=''
  match="$(jq "${query}" "${NETWORKS_SETTINGS}")"

  if is_empty "${match}"; then
    log "Proxy profile ${name} not found."
    return 2
  fi

  local settings=''
  settings="$(jq -e "del(.proxies[] | select(.name == \"${name}\"))" "${NETWORKS_SETTINGS}")"

  if has_failed; then
    log "Failed to delete proxy profile ${name}."
    return 2
  fi

  echo "${settings}" > "${NETWORKS_SETTINGS}"
  
  log "Proxy profile ${name} deleted."
}

# Shows the list of all proxy profiles stored in the
# settings file.
# Outputs:
#  A list of proxy profiles.
list_proxies () {
  if file_not_exists "${NETWORKS_SETTINGS}"; then
    log 'No proxy profiles have found.'
    return 0
  fi

  local proxies=''
  proxies="$(jq -cer '.proxies//[]' "${NETWORKS_SETTINGS}")" || return 1
  
  local len=0
  len="$(echo "${proxies}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No proxy profiles have found.'
    return 0
  fi

  local query=''
  query+='\(.name                      | lbln("Name"))'
  query+='\(.host                      | lbln("Host"))'
  query+='\(.port                      | lbln("Port"))'
  query+='\(.username                  | olbln("Auth"))'
  query+='\(.no_proxy//[] | join(", ") | lbl("Ignore"; "None"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${proxies}" | jq -cer --arg SPC 9 "${query}" || return 1
}

# Sets system-wise proxy server to settings with the
# given profile name.
# Arguments:
#  name: the name of a proxy profile
set_proxy () {
  authenticate_user || return $?

  local name="${1}"
  
  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing proxy profile name.' && return 2

    pick_proxy || return $?
    is_empty "${REPLY}" && log 'Proxy profile name required.' && return 2
    name="${REPLY}"
  fi

  if file_not_exists "${NETWORKS_SETTINGS}"; then
    log 'No proxy profiles have found.'
    return 2
  fi

  local query=".proxies | if . then .[] | select(.name == \"${name}\") else empty end"

  local proxy=''
  proxy="$(jq "${query}" "${NETWORKS_SETTINGS}")"

  if is_empty "${proxy}"; then
    log "Proxy profile ${name} not found."
    return 2
  fi

  local query=''
  query+='\(if is_nullish(.username) | not then "\(.username):\(.password)@" else "" end)'
  query+='\(.host):\(.port)'

  local uri=''
  uri="$(echo "${proxy}" | jq -cer "\"${query}\"")" || return 1

  local no_proxy=''
  no_proxy="$(echo "${proxy}" | jq -cer '[.no_proxy][] | join(",")')" || return 1

  log "Setting proxy server ${uri}..."

  mkdir -p "${HOME}/.config/environment.d"

  local proxy_env="${HOME}/.config/environment.d/proxy.conf"

  echo "export http_proxy=\"http://${uri}/\"" > "${proxy_env}" &&
  echo "export HTTP_PROXY=\"http://${uri}/\"" >> "${proxy_env}" &&
  echo "export https_proxy=\"https://${uri}/\"" >> "${proxy_env}" &&
  echo "export HTTPS_PROXY=\"https://${uri}/\"" >> "${proxy_env}" &&
  echo "export ftp_proxy=\"ftp://${uri}/\"" >> "${proxy_env}" &&
  echo "export FTP_PROXY=\"ftp://${uri}/\"" >> "${proxy_env}" &&
  echo "export rsync_proxy=\"rsync://${uri}/\"" >> "${proxy_env}" &&
  echo "export RSYNC_PROXY=\"rsync://${uri}/\"" >> "${proxy_env}" &&
  echo "export all_proxy=\"https://${uri}/\"" >> "${proxy_env}" &&
  echo "export ALL_PROXY=\"https://${uri}/\"" >> "${proxy_env}" &&
  echo "export no_proxy=\"${no_proxy}\"" >> "${proxy_env}" &&
  echo "export NO_PROXY=\"${no_proxy}\"" >> "${proxy_env}" ||
    log 'Failed to set environment proxy variables.'
  
  local shell_rc=''

  if file_exists "${HOME}/.bashrc"; then
    shell_rc="${HOME}/.bashrc"
  elif file_exists "${HOME}/.zshrc"; then
    shell_rc="${HOME}/.zshrc"
  fi

  if is_not_empty "${shell_rc}"; then
    sed -i "\|source \"${proxy_env}\"|d" "${shell_rc}" &&
    echo "source \"${proxy_env}\"" >> "${shell_rc}" &&
    source "${shell_rc}" ||
      log 'Failed to set environment proxy variables.'
  fi

  if which wget &> /dev/null; then
    if file_not_exists "${HOME}/.wgetrc"; then
      cp /etc/wgetrc "${HOME}/.wgetrc"
    fi

    sed -Ei "s;^#?https_proxy.*;https_proxy = https://${uri}/;" "${HOME}/.wgetrc" &&
    sed -Ei "s;^#?http_proxy.*;http_proxy = http://${uri}/;" "${HOME}/.wgetrc" &&
    sed -Ei "s;^#?ftp_proxy.*;ftp_proxy = ftp://${uri}/;" "${HOME}/.wgetrc" &&
    sed -Ei "s;^#?use_proxy.*;use_proxy = on;" "${HOME}/.wgetrc" ||
      log 'Failed to set wget proxy settings.'
  fi

  if which git &> /dev/null; then
    git config --global http.proxy "http://${uri}/" &&
    git config --global https.proxy "https://${uri}/" ||
      log 'Failed to set git proxy settings.'
  fi

  if which npm &> /dev/null; then
    npm config set proxy "http://${uri}/" &&
    npm config set https-proxy "https://${uri}/" ||
      log 'Failed to set npm proxy settings.'
  fi
  
  if which yarn &> /dev/null; then
    yarn config set proxy "http://${uri}/" &&
    yarn config set https-proxy "https://${uri}/" ||
      log 'Failed to set yarn proxy settings.'
  fi

  if which docker &> /dev/null; then
    sudo mkdir -p /etc/systemd/system/docker.service.d

    local docker_proxy='/etc/systemd/system/docker.service.d/http-proxy.conf'

    printf '%s\n%s%s%s%s' \
      '[Service]' \
      'Environment=' \
      "\"HTTP_PROXY=http://${uri}/\" " \
      "\"HTTPS_PROXY=https://${uri}/\" " \
      "\"NO_PROXY=${no_proxy}\"" | sudo tee "${docker_proxy}" > /dev/null &&
    sudo systemctl daemon-reload ||
      log 'Failed to set docker proxy settings.'
  fi

  local host=''
  host="$(echo "${proxy}" | jq -cer ".host")" || return 1

  local port=''
  port="$(echo "${proxy}" | jq -cer ".port")" || return 1

  gsettings set org.gnome.system.proxy mode manual
  gsettings set org.gnome.system.proxy.http host "${host}"
  gsettings set org.gnome.system.proxy.http port "${port}"
  gsettings set org.gnome.system.proxy.https host "${host}"
  gsettings set org.gnome.system.proxy.https port "${port}"
  gsettings set org.gnome.system.proxy.ftp host "${host}"
  gsettings set org.gnome.system.proxy.ftp port "${port}"
  gsettings set org.gnome.system.proxy.socks host "${host}"
  gsettings set org.gnome.system.proxy.socks port "${port}"

  local username=''
  username="$(echo "${proxy}" | jq -cer ".username")" || return 1

  local password=''
  password="$(echo "${proxy}" | jq -cer ".password")" || return 1

  if is_given "${username}"; then
    gsettings set org.gnome.system.proxy.http use-authentication true
    gsettings set org.gnome.system.proxy.http authentication-user "${username}"
    gsettings set org.gnome.system.proxy.http authentication-password "${password}"
  else
    gsettings set org.gnome.system.proxy.http use-authentication false
    gsettings set org.gnome.system.proxy.http authentication-user ''
    gsettings set org.gnome.system.proxy.http authentication-password ''
  fi

  local query='.no_proxy | if . | length > 0'
  query+=" then \"[\([.[] | \"'\(.)'\"] | join(\",\"))]\" else [] end"

  local no_proxy=''
  no_proxy="$(echo "${proxy}" | jq -cer "${query}")" || return 1

  gsettings set org.gnome.system.proxy ignore-hosts "${no_proxy}"
  
  log 'Proxy settings have been applied.'
}

# Reverts any proxy settings have been applied to
# the system.
unset_proxy () {
  authenticate_user || return $?

  log 'Unsetting proxy server...'

  local proxy_env="${HOME}/.config/environment.d/proxy.conf"

  rm -f "${proxy_env}"

  unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY \
    ftp_proxy FTP_PROXY rsync_proxy RSYNC_PROXY \
    all_proxy ALL_PROXY no_proxy NO_PROXY ||
    log 'Failed to unset environment proxy variables.'

  local shell_rc=''

  if file_exists "${HOME}/.bashrc"; then
    shell_rc="${HOME}/.bashrc"
  elif file_exists "${HOME}/.zshrc"; then
    shell_rc="${HOME}/.zshrc"
  fi

  if is_not_empty "${shell_rc}"; then
    sed -i "\|source \"${proxy_env}\"|d" "${shell_rc}" ||
      log 'Failed to unset environment proxy variables.'
  fi

  if which wget &> /dev/null; then
    if file_not_exists "${HOME}/.wgetrc"; then
      cp /etc/wgetrc "${HOME}/.wgetrc"
    fi

    sed -Ei "s;^https_proxy.*;#https_proxy = ;" "${HOME}/.wgetrc" &&
    sed -Ei "s;^http_proxy.*;#http_proxy = ;" "${HOME}/.wgetrc" &&
    sed -Ei "s;^ftp_proxy.*;#ftp_proxy = ;" "${HOME}/.wgetrc" &&
    sed -Ei "s;^use_proxy.*;#use_proxy = ;" "${HOME}/.wgetrc" ||
      log 'Failed to set wget proxy settings.'
  fi

  if which git &> /dev/null &&
    git config --global --get http.proxy &> /dev/null; then
    git config --global --unset http.proxy &&
    git config --global --unset https.proxy ||
      log 'Failed to unset git proxy settings.'
  fi

  if which npm &> /dev/null; then
    npm config delete proxy &&
    npm config delete https-proxy ||
      log 'Failed to set npm proxy settings.'
  fi
  
  if which yarn &> /dev/null; then
    yarn config delete proxy &&
    yarn config delete https-proxy ||
      log 'Failed to unset yarn proxy settings.'
  fi

  if which docker &> /dev/null; then
    local docker_proxy='/etc/systemd/system/docker.service.d/http-proxy.conf'

    sudo rm -f "${docker_proxy}" &&
    sudo systemctl daemon-reload ||
      log 'Failed to unset docker proxy settings.'
  fi

  gsettings set org.gnome.system.proxy mode none
  gsettings set org.gnome.system.proxy.http host ''
  gsettings set org.gnome.system.proxy.http port 0
  gsettings set org.gnome.system.proxy.https host ''
  gsettings set org.gnome.system.proxy.https port 0
  gsettings set org.gnome.system.proxy.ftp host ''
  gsettings set org.gnome.system.proxy.ftp port 0
  gsettings set org.gnome.system.proxy.socks host ''
  gsettings set org.gnome.system.proxy.socks port 0
  gsettings set org.gnome.system.proxy.http use-authentication false
  gsettings set org.gnome.system.proxy.http authentication-user ''
  gsettings set org.gnome.system.proxy.http authentication-password ''
  gsettings set org.gnome.system.proxy ignore-hosts '[]'

  log 'Proxy settings have been unset.'
}

# Sets the system networking to on or off.
# Arguments:
#  mode: on or off
power_network () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'Missing network power mode.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid network power mode.'
    return 2
  fi

  log "Powering network ${mode}..."

  nmcli networking "${mode}"

  if has_failed; then
    log "Failed to power network ${mode}."
    return 2
  fi

  log "Network power set to ${mode}."
}

# Sets the wifi to on or off.
# Arguments:
#  mode: on or off
power_wifi () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'Missing wifi power mode.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid wifi power mode.'
    return 2
  fi

  log "Powering wifi ${mode}..."

  nmcli radio wifi "${mode}"

  if has_failed; then
    log "Failed to power wifi ${mode}."
    return 2
  fi

  log "Wifi power set to ${mode}."
}
