#!/bin/bash

. src/workflowHandler.sh
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
  while [ "${str:0:${#match}}" == "$match" ]; do
    str="${str:${#match}:${#str}}"
  done
  while [ "${str:$((${#str}-${#match}))}" == "$match" ]; do
    str="${str:0:$((${#str} - ${#match}))}"
  done
  echo "$str"
}

# Get wifi state as boolean
# $1 = Wi-Fi interface name
# $! = Boolean
getWifiState() {
  if [ "$(networksetup -getairportpower "$1" | grep On)" != "" ]; then
    echo 1
  else
    echo 0
  fi
}

# Get ethernet state as boolean
# $1 = Ethernet interface name
# $! = Boolean
getEthernetState() {
  if [ "$1" != "" ]; then
    echo 1
  else
    echo 0
  fi
}

# Get wifi port name
# $1 = networksetup -listallhardwareports
# $! = String
getWifiName() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$WIFI_REGEX")
  echo "$DETAILS" | grep -Eo "AirPort|Wi-Fi"
}

# Get ethernet port name
# $1 = networksetup -listallhardwareports
# $! = String
getEthernetName() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$DETAILS" | awk '/Hardware / {print substr($0, index($0, $3))}'
}

# Get wifi interface name
# $1 = networksetup -listallhardwareports
# $! = String
getWifiInterface() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$WIFI_REGEX")
  echo "$DETAILS" | grep -m 1 -o -e en[0-9]
}

# Get ethernet interface name
# $1 = networksetup -listallhardwareports
# $! = String
getEthernetInterface() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$DETAILS" | grep -m 1 -o -e en[0-9]
}

# Get wifi mac address
# $1 = networksetup -listallhardwareports
# $! = String
getWifiMac() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$WIFI_REGEX")
  echo "$DETAILS" | awk '/Ethernet Address: / {print substr($0, index($0, $3))}'
}

# Get ethernet mac address
# $1 = networksetup -listallhardwareports
# $! = String
getEthernetMac() {
  local LIST=${1-$(networksetup -listallhardwareports)}
  local DETAILS=$(echo "$LIST" | grep -A 2 -E "$ETHERNET_REGEX")
  echo "$DETAILS" | awk '/Ethernet Address: / {print substr($0, index($0, $3))}'
}

# Find name of primary connected network interface
# $! = String
getPrimaryInterfaceName() {
  local INTERFACE=$(getEthernetInterface)
  if [ "$(getEthernetState "$INTERFACE")" != 0 ]; then
    echo "$(getEthernetName)"
  else
    echo "$(getWifiName)"
  fi
}

# Extract connection configuration
# $1 = networksetup -getinfo
# $! = String
getConnectionConfig() {
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

  if [ "$IPv6" == "none" ]; then
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
getSummaryValue() {
  echo "$1" | sed -n "s/^  $2 : //p" | head -n 1
}

# Resolve global IP
# $1 = Dig resolver address (optional)
# $! = String
getGlobalIP() {
  local RESOLVER=${1:-"myip.opendns.com @resolver1.opendns.com"}

  local IP=$(dig -4 +time=2 +tries=1 +short $RESOLVER)
  if [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "$IP"
  fi
}

# Get connected VPN
# $1 = scutil --nc list
# $! = String
getVPN() {
  echo "$1" | awk '/\/*.(Connected)/ {print $7}' | tr -d '"'
}

# Get VPN info
# $1 = `scutil --nc list` lines
# $! = Separated string of VPN info
getVPNInfo() {
  if [[ "$1" =~ \*[[:space:]]\(([a-zA-Z ]*)\)[[:space:]].*\"(.*)\".*\[(.*)\] ]]
  then
    STATE=${BASH_REMATCH[1]}
    NAME=${BASH_REMATCH[2]}
    TYPE=${BASH_REMATCH[3]}
  fi

  if [ "$STATE" == "Connected" ]; then
    AP_ICON=$ICON_VPN_CONNECTED
  else
    AP_ICON=$ICON_VPN
  fi

  echo "$STATE"~"$NAME"~"$TYPE"~"$AP_ICON"
}

# Get DNS info
# $1 = `networksetup -getdnsservers <servicename>`
# $! = String
getDNS() {
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
parseDNSLine() {
  IFS=':' read -r -a ARRAY <<< "$1"
  if [[ "${ARRAY[0]}" =~ ^# ]] || [ "${ARRAY[0]}" == "" ] || [ "${ARRAY[1]}" == "" ]; then
    return
  fi

  local ID=$(trim "${ARRAY[0]}")
  local DNS=$(echo "${ARRAY[1]}" | sed 's/ //g' | sed 's/,/ \/ /g')
  local ICON=$ICON_DNS

  if [ "$DNS" == "$2" ]; then
    ICON=$ICON_DNS_USED
    ID="$ID (used)"
  fi

  echo "$ID"~"$DNS"~"$ICON"
}

# Get saved access point
# $1 = networksetup -listpreferredwirelessnetworks
# $! = Separated string of saved access points
getSavedAPs() {
  while read -r line; do
    OUTPUT=$OUTPUT~$line
  done <<< "$1"
  echo "${OUTPUT:1}"
}

# Check if list contains an element
# $1 = List of elements
# $2 = Element to check
# $! = Boolean
listContains() {
  while read -r ITEM; do
    if [ "$ITEM" == "$2" ]; then
      echo 1
    fi
  done <<< "$1"
}

# Get WiFi strength
# $1 = Wifi RSSI
# $! = Wifi strength level 1-4
getWifiStrength() {
  if [ "$1" -lt -80 ]; then
    echo 1
  elif [ "$1" -lt -70 ]; then
    echo 2
  elif [ "$1" -lt -60 ]; then
    echo 3
  else
    echo 4
  fi
}

# Get WiFi strength for a scan result
# $1 = Wifi RSSI (may be empty; system_profiler omits it for many networks)
# $! = Wifi strength level 1-4 (defaults to 4 when signal is unknown)
getScanStrength() {
  if [ "$1" == "" ]; then
    echo 4
  else
    getWifiStrength "$1"
  fi
}

# Parse `system_profiler SPAirPortDataType` output into a JSON array of
# networks: [{ section, ssid, channel, security, rssi }]. section is "current"
# for the active network, "other" for the rest. Used as the redacted fallback
# when the CoreWLAN scanner returns nothing.
# $1 = system_profiler SPAirPortDataType text
# $2 = Wi-Fi interface name (e.g. en0)
parseScanResults() {
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
getActiveScanSSID() {
  jq -r 'map(select(.section == "current"))[0].ssid // empty' <<< "$1"
}

# Scan Wi-Fi networks. Reads real SSIDs with CoreWLAN through osascript, whose
# Apple-signed context is allowed to on macOS 14+ (no prompt or signing needed).
# Falls back to system_profiler (redacted names) if that returns nothing.
# A live scan also refreshes the OS scan cache that "cached" mode reads.
# $1 = Wi-Fi interface name
# $2 = mode: "cached" for the instant OS cache, empty for a live scan
# $! = JSON array of { section, ssid, channel, security, rssi }
scanNetworks() {
  local SRC="src/wifi-scan.js"
  local MODE="$2"

  if [ -f "$SRC" ]; then
    local OUT
    OUT=$(osascript -l JavaScript "$SRC" "$MODE" 2>/dev/null)
    if [ -n "$OUT" ] && [ "$OUT" != "[]" ]; then
      echo "$OUT"
      return
    fi
  fi

  # An empty cache is expected. Return nothing so the caller can show a
  # placeholder and rerun with a live scan, instead of falling back to
  # system_profiler and its redacted names.
  if [ "$MODE" == "cached" ]; then
    echo "[]"
    return
  fi

  parseScanResults "$(system_profiler SPAirPortDataType 2>/dev/null)" "$1"
}

# Annotate a scan network with its priority and icon.
# $1 = network JSON { section, ssid, channel, security, rssi }
# $2 = List of favorite access points (optional)
# $! = JSON { priority, ssid, channel, security, rssi, icon }
getScanDetails() {
  local SECTION SSID CHANNEL SECURITY RSSI
  { read -r SECTION; read -r SSID; read -r CHANNEL; read -r SECURITY; read -r RSSI; } \
    < <(jq -r '.section, .ssid, .channel, .security, .rssi' <<< "$1")

  if [ "$SSID" == "" ]; then
    return
  fi

  local FAVORITED PRIORITY AP_ICON
  FAVORITED=$(listContains "$2" "$SSID")
  PRIORITY=$PRIORITY_LOW

  # Only the scan's "current" section marks the connected network. Matching by
  # SSID would flag every access point that shares the name (e.g. a hotel).
  if [ "$SECTION" == "current" ]; then
    AP_ICON=$ICON_WIFI_ACTIVE_
    PRIORITY=$PRIORITY_HIGH
  elif [ "$FAVORITED" != "" ]; then
    AP_ICON=$ICON_WIFI_STAR_
    PRIORITY=$PRIORITY_MEDIUM
  elif [ "$SECURITY" == "None" ] || [ "$SECURITY" == "" ]; then
    AP_ICON=$ICON_WIFI_
  else
    AP_ICON=$ICON_WIFI_LOCK_
  fi

  AP_ICON=$AP_ICON$(getScanStrength "$RSSI")$ICON_END

  jq -nc \
    --argjson priority "$PRIORITY" \
    --arg ssid "$SSID" \
    --argjson channel "${CHANNEL:-0}" \
    --arg security "$SECURITY" \
    --argjson rssi "${RSSI:-0}" \
    --arg icon "$AP_ICON" \
    '{priority:$priority, ssid:$ssid, channel:$channel, security:$security, rssi:$rssi, icon:$icon}'
}

# Open the macOS Location Services settings pane
openLocationSettings() {
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
}
