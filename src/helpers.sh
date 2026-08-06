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
trim () {
  str="$1"
  match=" "
  while [[ "${str:0:${#match}}" == "$match" ]]; do
    str="${str:${#match}:${#str}}"
  done
  while [[ "${str:$((${#str}-${#match}))}" == "$match" ]]; do
    str="${str:0:$((${#str} - ${#match}))}"
  done
  echo "$str"
}

# Get wifi state as boolean
# $1 = Wi-Fi interface name
# $! = Boolean
get_wifi_state() {
  if [[ "$(networksetup -getairportpower "$1" | grep On)" != "" ]]; then
    echo 1
  else
    echo 0
  fi
}

# Get ethernet state as boolean
# $1 = Ethernet interface name
# $! = Boolean
get_ethernet_state() {
  if [[ "$1" != "" ]]; then
    echo 1
  else
    echo 0
  fi
}

# Get wifi port name
# $1 = networksetup -listallhardwareports
# $! = String
get_wifi_name() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$WIFI_REGEX")
  echo "$DETAILS" | grep -Eo "AirPort|Wi-Fi"
}

# Get ethernet port name
# $1 = networksetup -listallhardwareports
# $! = String
get_ethernet_name() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$DETAILS" | awk '/Hardware / {print substr($0, index($0, $3))}'
}

# Get wifi interface name
# $1 = networksetup -listallhardwareports
# $! = String
get_wifi_interface() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$WIFI_REGEX")
  echo "$DETAILS" | grep -m 1 -o -e en[0-9]
}

# Get ethernet interface name
# $1 = networksetup -listallhardwareports
# $! = String
get_ethernet_interface() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$DETAILS" | grep -m 1 -o -e en[0-9]
}

# Get wifi mac address
# $1 = networksetup -listallhardwareports
# $! = String
get_wifi_mac() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$WIFI_REGEX")
  echo "$DETAILS" | awk '/Ethernet Address: / {print substr($0, index($0, $3))}'
}

# Get ethernet mac address
# $1 = networksetup -listallhardwareports
# $! = String
get_ethernet_mac() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$DETAILS" | awk '/Ethernet Address: / {print substr($0, index($0, $3))}'
}

# Find name of primary connected network interface
# $! = String
get_primary_interface_name() {
  local INTERFACE=$(get_ethernet_interface)
  if [[ "$(get_ethernet_state "$INTERFACE")" != 0 ]]; then
    echo "$(get_ethernet_name)"
  else
    echo "$(get_wifi_name)"
  fi
}

# Extract connection configuration
# $1 = networksetup -getinfo
# $! = String
get_connection_config() {
  echo "$1" | grep 'Configuration$'
}

# Extract IP4
# $1 = networksetup -getinfo
# $! = String
getIPv4() {
  echo "$1" | grep '^IP\saddress' \
    | awk '/ address/ {print substr($0, index($0, $3))}'
}

# Extract IP6
# $1 = networksetup -getinfo
# $! = String
getIPv6() {
  local IPv6=$(echo "$1" \
    | grep '^IPv6 IP address' \
    | awk '/ address/ {print substr($0, index($0, $4))}')

  if [[ "$IPv6" == "none" ]]; then
    echo ""
  else
    echo "$IPv6"
  fi
}

# Extract a value from ipconfig getsummary output
# $1 = `ipconfig getsummary <interface>` text
# $2 = key (e.g. SSID, BSSID, Security)
# $! = String
# airport was removed in macOS 14.4, so ipconfig getsummary is the source.
get_summary_value() {
  echo "$1" | sed -n "s/^  $2 : //p" | head -n 1
}

# Resolve global IP
# $1 = Dig resolver address (optional)
# $! = String
get_global_ip() {
  local RESOLVER=${1:-"myip.opendns.com @resolver1.opendns.com"}

  local IP=$(dig -4 +time=2 +tries=1 +short $RESOLVER)
  if [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "$IP"
  fi
}

# Get connected VPN
# $1 = scutil --nc list
# $! = String
get_vpn() {
  echo "$1" | awk '/\/*.(Connected)/ {print $7}' | tr -d '"'
}

# Get VPN info
# $1 = `scutil --nc list` lines
# $! = Separated string of VPN info
get_vpn_info() {
  if [[ "$1" =~ \*[[:space:]]\(([a-zA-Z ]*)\)[[:space:]].*\"(.*)\".*\[(.*)\] ]]
  then
    STATE=${BASH_REMATCH[1]}
    NAME=${BASH_REMATCH[2]}
    TYPE=${BASH_REMATCH[3]}
  fi

  if [[ "$STATE" == "Connected" ]]; then
    AP_ICON=$ICON_VPN_CONNECTED
  else
    AP_ICON=$ICON_VPN
  fi

  echo "$STATE"~"$NAME"~"$TYPE"~"$AP_ICON"
}

# Get DNS info
# $1 = `networksetup -getdnsservers <servicename>`
# $! = String
get_dns() {
  if [[ "$1" != *"any DNS"* ]]; then
    echo $1 | sed 's/ / \/ /g'
  else
    echo ""
  fi
}

# Parse DNS info
# $1 = line of dns config file
# $2 = active dns list
# $! = Separated string of dns config elements
parse_dns_line() {
  IFS=':' read -r -a ARRAY <<< "$1"
  if [[ "${ARRAY[0]}" =~ ^# ]] || [[ "${ARRAY[0]}" == "" ]] || [[ "${ARRAY[1]}" == "" ]]; then
    return
  fi

  local ID=$(trim "${ARRAY[0]}")
  local DNS=$(echo "${ARRAY[1]}" | sed 's/ //g' | sed 's/,/ \/ /g')
  local ICON=$ICON_DNS

  if [[ "$DNS" == "$2" ]]; then
    ICON=$ICON_DNS_USED
    ID="$ID (used)"
  fi

  echo "$ID"~"$DNS"~"$ICON"
}

# Get saved access point
# $1 = networksetup -listpreferredwirelessnetworks
# $! = Separated string of saved access points
get_saved_aps() {
  while read -r line; do
    OUTPUT=$OUTPUT~$line
  done <<< "$1"
  echo "${OUTPUT:1}"
}

# Check if list contains an element
# $1 = List of elements
# $2 = Element to check
# $! = Boolean
list_contains() {
  while read -r ITEM; do
    if [[ "$ITEM" == "$2" ]]; then
      echo 1
    fi
  done <<< "$1"
}

# Get WiFi strength
# $1 = Wifi RSSI
# $! = Wifi strength level 1-4
get_wifi_strength() {
  if [[ "$1" -lt -80 ]]; then
    echo 1
  elif [[ "$1" -lt -70 ]]; then
    echo 2
  elif [[ "$1" -lt -60 ]]; then
    echo 3
  else
    echo 4
  fi
}

# Get WiFi strength for a scan result
# $1 = Wifi RSSI (may be empty; system_profiler omits it for many networks)
# $! = Wifi strength level 1-4 (defaults to 4 when signal is unknown)
get_scan_strength() {
  if [[ "$1" == "" ]]; then
    echo 4
  else
    get_wifi_strength "$1"
  fi
}

# Parse `system_profiler SPAirPortDataType` output into a JSON array of
# networks: [{ section, ssid, channel, security, rssi }]. section is "current"
# for the active network, "other" for the rest. Used as the redacted fallback
# when the CoreWLAN scanner returns nothing.
# $1 = system_profiler SPAirPortDataType text
# $2 = Wi-Fi interface name (e.g. en0)
parse_scan_results() {
  echo "$1" | awk -v iface="$2" '
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
}

# Get the active network SSID from a scan JSON array
# $1 = networks JSON
# $! = String
get_active_scan_ssid() {
  jq -r 'map(select(.section == "current"))[0].ssid // empty' <<< "$1"
}

# Scan Wi-Fi networks. Reads real SSIDs with CoreWLAN through osascript, whose
# Apple-signed context is allowed to on macOS 14+ (no prompt or signing needed).
# Falls back to system_profiler (redacted names) if that returns nothing.
# A live scan also refreshes the OS scan cache that "cached" mode reads.
# $1 = Wi-Fi interface name
# $2 = mode: "cached" for the instant OS cache, empty for a live scan
# $! = JSON array of { section, ssid, channel, security, rssi }
scan_networks() {
  local SRC="src/wifi-scan.js"
  local MODE="$2"

  if [[ -f "$SRC" ]]; then
    local OUT
    OUT=$(osascript -l JavaScript "$SRC" "$MODE" 2>/dev/null)
    if [[ -n "$OUT" ]] && [[ "$OUT" != "[]" ]]; then
      echo "$OUT"
      return
    fi
  fi

  # An empty cache is expected. Return nothing so the caller can show a
  # placeholder and rerun with a live scan, instead of falling back to
  # system_profiler and its redacted names.
  if [[ "$MODE" == "cached" ]]; then
    echo "[]"
    return
  fi

  parse_scan_results "$(system_profiler SPAirPortDataType 2>/dev/null)" "$1"
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
# $! = JSON array of Alfred items, sorted by priority
build_wifi_items() {
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
           icon: {path: .icon}} ]' <<< "$1"
}

# Open the macOS Location Services settings pane
open_location_settings() {
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
}
