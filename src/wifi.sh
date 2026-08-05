#!/bin/bash

. src/wifiCommon.sh
. src/workflowHandler.sh

RESCAN_MARK="${alfred_workflow_cache:-/tmp}/wifi_rescan"

# Handle action
if [ "$1" != "" ]; then
  if [ "$1" == "On" ] || [ "$1" == "Off" ]; then
  	networksetup -setairportpower "$INTERFACE" "$1"
  elif [ "$1" == "LOCATION" ]; then
    openLocationSettings
  elif [ "$1" == "RESCAN" ]; then
    # Drop a marker so the reopened list skips the cache and scans live,
    # then reopen net wifi. The live scan there also refreshes the cache.
    mkdir -p "$(dirname "$RESCAN_MARK")" 2>/dev/null
    touch "$RESCAN_MARK" 2>/dev/null
    osascript -e 'tell application "Alfred 5" to search "net wifi "' >/dev/null 2>&1
  else
    echo "$1" | tr -d '\n'
  fi
  exit
fi

# Guard against a Mac without Wi-Fi hardware
if [ -z "$INTERFACE" ]; then
  addResult "" "" "No Wi-Fi interface found" "This Mac has no Wi-Fi hardware" "$ICON_WIFI_ERROR" "no"
  getJSONResults
  return
fi

# Get interface mac address
MAC=$(getWifiMac)

# Handle Wi-Fi off state
if [ "$(getWifiState "$INTERFACE")" == 0 ]; then
  addResult "" "On" "Turn $NAME on" "$INTERFACE ($MAC)" "$ICON_WIFI_ERROR"
  getJSONResults
  return
fi

# Read the current network name via CoreWLAN, since ipconfig and system_profiler
# redact it. The instant OS cache is enough almost always. Only when the current
# network is not cached do a live scan (a few seconds), showing "Checking" while
# it runs. The live scan also refreshes the cache for next time.
# The scanner prefers a saved network when identifying the connected one.
WIFI_SAVED=$(networksetup -listpreferredwirelessnetworks "$INTERFACE" 2>/dev/null)
export WIFI_SAVED

# A rescan request (⌘⏎) drops a marker so this pass skips the cache and forces
# a live scan through the "Checking" rerun below.
FORCED=""
if [ -f "$RESCAN_MARK" ]; then
  rm -f "$RESCAN_MARK"
  FORCED=1
  NETWORKS="[]"
else
  NETWORKS=$(scanNetworks "$INTERFACE" cached)
fi
SSID=$(getActiveScanSSID "$NETWORKS")

if [ -z "$SSID" ] && [ -z "$wifi_checking" ]; then
  MSG="Checking Wi-Fi…"
  [ -n "$FORCED" ] && MSG="Rescanning Wi-Fi…"
  addResult "" "" "$MSG" "Reading the current network name" "$ICON_WIFI" "no"
  setRerun 0.1
  addVariable wifi_checking 1
  getJSONResults
  return
fi

if [ -n "$wifi_checking" ]; then
  NETWORKS=$(scanNetworks "$INTERFACE")
  SSID=$(getActiveScanSSID "$NETWORKS")
fi
AUTH=$(jq -r 'map(select(.section == "current"))[0].security // ""' <<< "$NETWORKS")

# Get network configuration
NETINFO=$(networksetup -getinfo "$NAME")
NETCONFIG=$(getConnectionConfig "$NETINFO")

# Output IPv4
IPv4=$(getIPv4 "$NETINFO")
if [ "$IPv4" != "" ]; then
  addResult "" "$IPv4" "$IPv4" "IPv4 address ($NETCONFIG)" "$ICON_WIFI"
fi

# Output IPv6
IPv6=$(getIPv6 "$NETINFO")
if [ "$IPv6" != "" ]; then
  addResult "" "$IPv6" "$IPv6" "IPv6 address ($NETCONFIG)" "$ICON_WIFI"
fi

# Output the Wi-Fi network name (read from the scan above). Hold ⌘ to force a
# fresh scan, in case the cached name is stale.
if [ "$SSID" != "" ] && [ "$SSID" != "<redacted>" ]; then
  addResult "" "$SSID" "$SSID" "$NAME access point ($AUTH)" "$ICON_WIFI" "" "" \
    "↻ Rescan Wi-Fi networks" "RESCAN"
else
  # macOS hides the name unless the app reading Wi-Fi has Location access
  addResult "" "LOCATION" "Wi-Fi name hidden by macOS" "Press ⏎ to open Location Services, then enable it for Alfred" "$ICON_WIFI_ERROR" "" "" \
    "↻ Rescan Wi-Fi networks" "RESCAN"
fi

# Output global IP
GLOBALIP=$(getGlobalIP)
if [ "$GLOBALIP" != "" ]; then
  addResult "" "$GLOBALIP" "$GLOBALIP" "Global IP" "$ICON_WIFI"
fi

# Output VPN
VPN=$(getVPN "$(scutil --nc list)")
if [ "$VPN" != "" ]; then
  addResult "" "$VPN" "$VPN" "VPN connection" "$ICON_WIFI"
fi

# Output DNS list
DNSSTRING=$(getDNS "$(networksetup -getdnsservers "$NAME")")
if [ "$DNSSTRING" != "" ]; then
  addResult "" "$DNSSTRING" "$DNSSTRING" "DNS list" "$ICON_WIFI"
fi

addResult "" "Off" "Turn $NAME Off" "$INTERFACE ($MAC)" "$ICON_WIFI"

getJSONResults
