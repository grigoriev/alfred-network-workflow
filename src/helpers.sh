#!/bin/bash

. src/workflow_handler.sh
. src/media.sh

ETHERNET_REGEX="LAN$|Lan$|Ethernet$|AX[0-9A-Z]+$"
WIFI_REGEX="Airport$|Wi-Fi$"

PRIORITY_HIGH="1"
PRIORITY_MEDIUM="2"
PRIORITY_LOW="5"

# Trim string
# $1 = Input string
# $! = Trimmed string
trim() {
  local str="$1"
  local match=" "
  while [[ "${str:0:${#match}}" == "$match" ]]; do
    str="${str:${#match}:${#str}}"
  done
  while [[ "${str:$((${#str}-${#match}))}" == "$match" ]]; do
    str="${str:0:$((${#str} - ${#match}))}"
  done
  echo "$str"
  return 0
}

# Get wifi state as boolean
# $1 = Wi-Fi interface name
get_wifi_state() {
  local interface="$1"
  if [[ "$(networksetup -getairportpower "$interface" | grep On)" != "" ]]; then
    echo 1
  else
    echo 0
  fi
  return 0
}

# Get ethernet state as boolean
# $1 = Ethernet interface name
get_ethernet_state() {
  local interface="$1"
  if [[ "$interface" != "" ]]; then
    echo 1
  else
    echo 0
  fi
  return 0
}

# Get wifi port name
# $1 = networksetup -listallhardwareports
get_wifi_name() {
  local list="${1-$(networksetup -listallhardwareports)}"
  local details
  details=$(echo "$list" | grep -A 2 -E "$WIFI_REGEX")
  echo "$details" | grep -Eo "AirPort|Wi-Fi"
  return 0
}

# Get ethernet port name
# $1 = networksetup -listallhardwareports
get_ethernet_name() {
  local list="${1-$(networksetup -listallhardwareports)}"
  local details
  details=$(echo "$list" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$details" | awk '/Hardware / {print substr($0, index($0, $3))}'
  return 0
}

# Get wifi interface name
# $1 = networksetup -listallhardwareports
get_wifi_interface() {
  local list="${1-$(networksetup -listallhardwareports)}"
  local details
  details=$(echo "$list" | grep -A 2 -E "$WIFI_REGEX")
  echo "$details" | grep -m 1 -o -e "en[0-9]"
  return 0
}

# Get ethernet interface name
# $1 = networksetup -listallhardwareports
get_ethernet_interface() {
  local list="${1-$(networksetup -listallhardwareports)}"
  local details
  details=$(echo "$list" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$details" | grep -m 1 -o -e "en[0-9]"
  return 0
}

# Get wifi mac address
# $1 = networksetup -listallhardwareports
get_wifi_mac() {
  local list="${1-$(networksetup -listallhardwareports)}"
  local details
  details=$(echo "$list" | grep -A 2 -E "$WIFI_REGEX")
  echo "$details" | awk '/Ethernet Address: / {print substr($0, index($0, $3))}'
  return 0
}

# Get ethernet mac address
# $1 = networksetup -listallhardwareports
get_ethernet_mac() {
  local list="${1-$(networksetup -listallhardwareports)}"
  local details
  details=$(echo "$list" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$details" | awk '/Ethernet Address: / {print substr($0, index($0, $3))}'
  return 0
}

# Find name of primary connected network interface
get_primary_interface_name() {
  local interface
  interface=$(get_ethernet_interface)
  if [[ "$(get_ethernet_state "$interface")" != 0 ]]; then
    get_ethernet_name
  else
    get_wifi_name
  fi
  return 0
}

# Extract connection configuration
# $1 = networksetup -getinfo
get_connection_config() {
  local info="$1"
  echo "$info" | grep 'Configuration$'
  return 0
}

# Extract IP4
# $1 = networksetup -getinfo
get_ipv4() {
  local info="$1"
  echo "$info" | grep '^IP\saddress' \
    | awk '/ address/ {print substr($0, index($0, $3))}'
  return 0
}

# Extract IP6
# $1 = networksetup -getinfo
get_ipv6() {
  local info="$1"
  local ipv6
  ipv6=$(echo "$info" | grep '^IPv6 IP address' \
    | awk '/ address/ {print substr($0, index($0, $4))}')
  if [[ "$ipv6" == "none" ]]; then
    echo ""
  else
    echo "$ipv6"
  fi
  return 0
}

# Extract a value from ipconfig getsummary output
# $1 = `ipconfig getsummary <interface>` text
# $2 = key (e.g. SSID, BSSID, Security)
get_summary_value() {
  local text="$1" key="$2"
  echo "$text" | sed -n "s/^  $key : //p" | head -n 1
  return 0
}

# Resolve global IP
# $1 = Dig resolver address (optional)
get_global_ip() {
  local resolver="${1:-myip.opendns.com @resolver1.opendns.com}"
  local ip
  # shellcheck disable=SC2086
  ip=$(dig -4 +time=2 +tries=1 +short $resolver)
  if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "$ip"
  fi
  return 0
}

# Get connected VPN
# $1 = scutil --nc list
get_vpn() {
  local list="$1"
  echo "$list" | awk '/\/*.(Connected)/ {print $7}' | tr -d '"'
  return 0
}

# Get VPN info
# $1 = `scutil --nc list` lines
get_vpn_info() {
  local line="$1"
  local state name type ap_icon
  if [[ "$line" =~ \*[[:space:]]\(([a-zA-Z ]*)\)[[:space:]].*\"(.*)\".*\[(.*)\] ]]; then
    state=${BASH_REMATCH[1]}
    name=${BASH_REMATCH[2]}
    type=${BASH_REMATCH[3]}
  fi

  if [[ "$state" == "Connected" ]]; then
    ap_icon=$ICON_VPN_CONNECTED
  else
    ap_icon=$ICON_VPN
  fi

  echo "$state"~"$name"~"$type"~"$ap_icon"
  return 0
}

# Get DNS info
# $1 = `networksetup -getdnsservers <servicename>`
get_dns() {
  local servers="$1"
  if [[ "$servers" != *"any DNS"* ]]; then
    # Unquoted on purpose: collapse newlines and repeated spaces to single spaces.
    # shellcheck disable=SC2086
    echo $servers | sed 's/ / \/ /g'
  else
    echo ""
  fi
  return 0
}

# Parse DNS info
# $1 = line of dns config file
# $2 = active dns list
parse_dns_line() {
  local line="$1" active="$2"
  local array
  IFS=':' read -r -a array <<< "$line"
  if [[ "${array[0]}" =~ ^# ]] || [[ "${array[0]}" == "" ]] || [[ "${array[1]}" == "" ]]; then
    return 0
  fi

  local id dns icon
  id=$(trim "${array[0]}")
  dns=$(echo "${array[1]}" | sed 's/ //g' | sed 's/,/ \/ /g')
  icon=$ICON_DNS

  if [[ "$dns" == "$active" ]]; then
    icon=$ICON_DNS_USED
    id="$id (used)"
  fi

  echo "$id"~"$dns"~"$icon"
  return 0
}

# Get saved access point
# $1 = networksetup -listpreferredwirelessnetworks
get_saved_aps() {
  local input="$1"
  local output="" line
  while read -r line; do
    output=$output~$line
  done <<< "$input"
  echo "${output:1}"
  return 0
}

# Check if list contains an element
# $1 = List of elements
# $2 = Element to check
list_contains() {
  local list="$1" element="$2"
  local item
  while read -r item; do
    if [[ "$item" == "$element" ]]; then
      echo 1
    fi
  done <<< "$list"
  return 0
}

# Get WiFi strength
# $1 = Wifi RSSI
get_wifi_strength() {
  local rssi="$1"
  if [[ "$rssi" -lt -80 ]]; then
    echo 1
  elif [[ "$rssi" -lt -70 ]]; then
    echo 2
  elif [[ "$rssi" -lt -60 ]]; then
    echo 3
  else
    echo 4
  fi
  return 0
}

# Get WiFi strength for a scan result
# $1 = Wifi RSSI (may be empty; system_profiler omits it for many networks)
get_scan_strength() {
  local rssi="$1"
  if [[ "$rssi" == "" ]]; then
    echo 4
  else
    get_wifi_strength "$rssi"
  fi
  return 0
}

# Parse `system_profiler SPAirPortDataType` output into a JSON array of
# networks: [{ section, ssid, channel, security, rssi }]. section is "current"
# for the active network, "other" for the rest. Used as the redacted fallback
# when the CoreWLAN scanner returns nothing.
# $1 = system_profiler SPAirPortDataType text
# $2 = Wi-Fi interface name (e.g. en0)
parse_scan_results() {
  local text="$1" iface="$2"
  echo "$text" | awk -v iface="$iface" '
    function flush() {
      if (ssid != "") { printf "%s\t%s\t%s\t%s\t%s\n", section, ssid, channel, security, rssi }
      ssid=""; channel=""; security=""; rssi=""
    }
    # Interface header (8 spaces): scope parsing to the Wi-Fi interface
    /^        [A-Za-z0-9]+:$/ {
      flush(); cur = $1; sub(/:$/, "", cur); inIface = (cur == iface); section=""; next
    }
    !inIface { next }
    # Section headers (10 spaces)
    /^          Current Network Information:/ { flush(); section="current"; next }
    /^          Other Local Wi-Fi Networks:/ { flush(); section="other"; next }
    /^          [A-Za-z].*:$/ { flush(); section=""; next }
    section=="" { next }
    # Network fields (14 spaces)
    /^              Channel:/ { l=$0; sub(/^ *Channel: */,"",l); split(l,a," "); channel=a[1]; next }
    /^              Security:/ { l=$0; sub(/^ *Security: */,"",l); security=l; next }
    /^              Signal . Noise:/ { l=$0; sub(/^ *Signal \/ Noise: */,"",l); split(l,a," "); rssi=a[1]; next }
    /^              / { next }
    # Network name header (12 spaces, ends with a colon)
    /^            .*:$/ { flush(); s=$0; sub(/^ */,"",s); sub(/:$/,"",s); ssid=s; next }
    END { flush() }
  ' | jq -Rn '[inputs | split("\t")
    | {section:.[0], ssid:.[1], channel:(.[2]|tonumber? // 0), security:.[3], rssi:(.[4]|tonumber? // 0)}]'
  return 0
}

# Get the active network SSID from a scan JSON array
# $1 = networks JSON
get_active_scan_ssid() {
  local networks="$1"
  jq -r 'map(select(.section == "current"))[0].ssid // empty' <<< "$networks"
  return 0
}

# Scan Wi-Fi networks. Reads real SSIDs with CoreWLAN through osascript, whose
# Apple-signed context is allowed to on macOS 14+ (no prompt or signing needed).
# Falls back to system_profiler (redacted names) if that returns nothing.
# A live scan also refreshes the OS scan cache that "cached" mode reads.
# $1 = Wi-Fi interface name
# $2 = mode: "cached" for the instant OS cache, empty for a live scan
scan_networks() {
  local interface="$1" mode="$2"
  local src="src/wifi-scan.js"

  if [[ -f "$src" ]]; then
    local out
    out=$(osascript -l JavaScript "$src" "$mode" 2>/dev/null)
    if [[ -n "$out" ]] && [[ "$out" != "[]" ]]; then
      echo "$out"
      return 0
    fi
  fi

  # An empty cache is expected. Return nothing so the caller can show a
  # placeholder and rerun with a live scan, instead of falling back to
  # system_profiler and its redacted names.
  if [[ "$mode" == "cached" ]]; then
    echo "[]"
    return 0
  fi

  parse_scan_results "$(system_profiler SPAirPortDataType 2>/dev/null)" "$interface"
  return 0
}

# Build the Alfred items for a Wi-Fi scan in a single jq pass. Marks the
# connected network (active icon, top priority), starred saved networks, and
# open vs locked networks, sorts by priority, and formats each subtitle.
# Doing this in one jq call, instead of several per network, keeps a dense
# scan (a hotel) instant. Item args use ARG_PREFIX, like add_result.
# Only the scan's "current" section marks the connected network; matching by
# SSID would flag every access point that shares the name.
# $1 = networks JSON array { section, ssid, channel, security, rssi }
# $2 = saved/preferred networks (newline text, optional)
build_wifi_items() {
  local networks="$1"
  local saved
  saved=$(printf '%s' "$2" | jq -Rn '[inputs | gsub("^[ \t]+|[ \t]+$";"") | select(length > 0)]')

  jq -c \
    --argjson saved "$saved" \
    --arg prefix "$ARG_PREFIX" \
    --argjson high "$PRIORITY_HIGH" \
    --argjson medium "$PRIORITY_MEDIUM" \
    --argjson low "$PRIORITY_LOW" \
    --arg active "$ICON_WIFI_ACTIVE_" \
    --arg star "$ICON_WIFI_STAR_" \
    --arg open "$ICON_WIFI_" \
    --arg lock "$ICON_WIFI_LOCK_" \
    --arg end "$ICON_END" '
    def strength(r):
      if r == null then 4
      elif r < -80 then 1
      elif r < -70 then 2
      elif r < -60 then 3
      else 4 end;
    [ .[]
      | select(.ssid != "")
      | . as $n
      | (if $n.section == "current" then {p: $high, base: $active}
         elif ($saved | index($n.ssid)) then {p: $medium, base: $star}
         elif ($n.security == "None" or $n.security == "") then {p: $low, base: $open}
         else {p: $low, base: $lock} end) as $c
      | {p: $c.p, n: $n, icon: ($c.base + (strength($n.rssi) | tostring) + $end)} ]
    | sort_by(.p)
    | [ .[]
        | .n as $n
        | {title: (if $n.ssid == "<redacted>" then "Hidden network" else $n.ssid end),
           subtitle: (
             (if ($n.rssi != 0 and $n.rssi != null) then "RSSI " + ($n.rssi | tostring) + " dBm, " else "" end)
             + "channel " + ($n.channel | tostring)
             + (if ($n.security != "" and $n.security != null) then ", " + $n.security else "" end)),
           arg: (if $n.ssid == "<redacted>" then "" else $prefix + $n.ssid end),
           valid: ($n.ssid != "<redacted>"),
           icon: {path: .icon}} ]' <<< "$networks"
  return 0
}

# Open the macOS Location Services settings pane
open_location_settings() {
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
  return 0
}
