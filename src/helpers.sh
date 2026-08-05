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

# Parse `system_profiler SPAirPortDataType` scan output into tuples
# $1 = system_profiler SPAirPortDataType text
# $2 = Wi-Fi interface name (e.g. en0)
# $! = One line per network: SECTION~SSID~CHANNEL~SECURITY~RSSI
#      SECTION is "current" for the active network, "other" for the rest.
#      airport was removed in macOS 14.4, so system_profiler is the source.
parseScanResults() {
  echo "$1" | awk -v iface="$2" '
    function flush() {
      if (ssid != "") { print section "~" ssid "~" channel "~" security "~" rssi }
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
  '
}

# Get the active network SSID from scan output
# $1 = system_profiler SPAirPortDataType text
# $2 = Wi-Fi interface name (e.g. en0)
# $! = String
getActiveScanSSID() {
  parseScanResults "$1" "$2" | awk -F'~' '$1 == "current" { print $2; exit }'
}

# Build access point details from a scan tuple
# $1 = SECTION~SSID~CHANNEL~SECURITY~RSSI (from parseScanResults)
# $2 = SSID of the active access point (optional)
# $3 = List of favorite access points (optional)
# $! = Separated string: PRIORITY~SSID~BSSID~RSSI~CHANNEL~SECURITY~AP_ICON
#      BSSID is empty; system_profiler does not expose it.
getScanDetails() {
  IFS='~' read -r -a F <<< "$1"
  local SECTION="${F[0]}" SSID="${F[1]}" CHANNEL="${F[2]}" SECURITY="${F[3]}" RSSI="${F[4]}"

  if [ "$SSID" == "" ]; then
    return
  fi

  local FAVORITED=$(listContains "$3" "$SSID")
  local PRIORITY=$PRIORITY_LOW
  local AP_ICON

  # A redacted SSID cannot be matched by name, so only the current network
  # section identifies the active one; otherwise all redacted rows would match.
  if [ "$SECTION" == "current" ] || { [ "$SSID" != "<redacted>" ] && [ "$2" != "" ] && [ "$SSID" == "$2" ]; }; then
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

  echo "$PRIORITY"~"$SSID"~""~"$RSSI"~"$CHANNEL"~"$SECURITY"~"$AP_ICON"
}

# Open the macOS Location Services settings pane
openLocationSettings() {
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
}
