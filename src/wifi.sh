#!/bin/bash

. src/wifi_common.sh
. src/workflow_handler.sh

RESCAN_MARK="${alfred_workflow_cache:-/tmp}/wifi_rescan"

# Handle action
if [[ "$1" != "" ]]; then
  if [[ "$1" == "On" ]] || [[ "$1" == "Off" ]]; then
  	networksetup -setairportpower "$INTERFACE" "$1"
  elif [[ "$1" == "LOCATION" ]]; then
    open_location_settings
  elif [[ "$1" == "RESCAN" ]]; then
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
if [[ -z "$INTERFACE" ]]; then
  add_result "" "" "No Wi-Fi interface found" "This Mac has no Wi-Fi hardware" "$ICON_WIFI_ERROR" "no"
  get_json_results
  return
fi

# Get interface mac address
MAC=$(get_wifi_mac)

# Handle Wi-Fi off state
if [[ "$(get_wifi_state "$INTERFACE")" == 0 ]]; then
  add_result "" "On" "Turn $NAME on" "$INTERFACE ($MAC)" "$ICON_WIFI_ERROR"
  get_json_results
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
if [[ -f "$RESCAN_MARK" ]]; then
  rm -f "$RESCAN_MARK"
  FORCED=1
  NETWORKS="[]"
else
  NETWORKS=$(scan_networks "$INTERFACE" cached)
fi
SSID=$(get_active_scan_ssid "$NETWORKS")

if [[ -z "$SSID" ]] && [[ -z "$wifi_checking" ]]; then
  MSG="Checking Wi-Fi…"
  [[ -n "$FORCED" ]] && MSG="Rescanning Wi-Fi…"
  add_result "" "" "$MSG" "Reading the current network name" "$ICON_WIFI" "no"
  set_rerun 0.1
  add_variable wifi_checking 1
  get_json_results
  return
fi

if [[ -n "$wifi_checking" ]]; then
  NETWORKS=$(scan_networks "$INTERFACE")
  SSID=$(get_active_scan_ssid "$NETWORKS")
fi
AUTH=$(jq -r 'map(select(.section == "current"))[0].security // ""' <<< "$NETWORKS")

# Get network configuration
NETINFO=$(networksetup -getinfo "$NAME")
NETCONFIG=$(get_connection_config "$NETINFO")

# Output IPv4
IPv4=$(get_ipv4 "$NETINFO")
if [[ "$IPv4" != "" ]]; then
  add_result "" "$IPv4" "$IPv4" "IPv4 address ($NETCONFIG)" "$ICON_WIFI"
fi

# Output IPv6
IPv6=$(get_ipv6 "$NETINFO")
if [[ "$IPv6" != "" ]]; then
  add_result "" "$IPv6" "$IPv6" "IPv6 address ($NETCONFIG)" "$ICON_WIFI"
fi

# Output the Wi-Fi network name (read from the scan above). Hold ⌘ to force a
# fresh scan, in case the cached name is stale.
if [[ "$SSID" != "" ]] && [[ "$SSID" != "<redacted>" ]]; then
  add_result "" "$SSID" "$SSID" "$NAME access point ($AUTH)" "$ICON_WIFI" "" "" \
    "↻ Rescan Wi-Fi networks" "RESCAN"
else
  # macOS hides the name unless the app reading Wi-Fi has Location access
  add_result "" "LOCATION" "Wi-Fi name hidden by macOS" "Press ⏎ to open Location Services, then enable it for Alfred" "$ICON_WIFI_ERROR" "" "" \
    "↻ Rescan Wi-Fi networks" "RESCAN"
fi

# Output global IP
GLOBALIP=$(get_global_ip)
if [[ "$GLOBALIP" != "" ]]; then
  add_result "" "$GLOBALIP" "$GLOBALIP" "Global IP" "$ICON_WIFI"
fi

# Output VPN
VPN=$(get_vpn "$(scutil --nc list)")
if [[ "$VPN" != "" ]]; then
  add_result "" "$VPN" "$VPN" "VPN connection" "$ICON_WIFI"
fi

# Output DNS list
DNSSTRING=$(get_dns "$(networksetup -getdnsservers "$NAME")")
if [[ "$DNSSTRING" != "" ]]; then
  add_result "" "$DNSSTRING" "$DNSSTRING" "DNS list" "$ICON_WIFI"
fi

add_result "" "Off" "Turn $NAME Off" "$INTERFACE ($MAC)" "$ICON_WIFI"

get_json_results
