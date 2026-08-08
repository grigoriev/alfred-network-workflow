#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/autoupdate.sh

# Single entry point. Every command lives under the "net" keyword:
#   net            -> catalog of commands
#   net vpn        -> the VPN command, and so on
# Called two ways from Alfred:
#   list mode (Script Filter): . src/net.sh list "{query}"
#   run mode  (Run Script):    . src/net.sh run  "{query}"

mode="$1"
query="$2"
cmd="${query%% *}"
rest="${query#"$cmd"}"
rest="${rest# }"

subcommands="wifi eth wifilist vpn dns"

is_subcommand() {
  local target="$1"
  local name
  for name in $subcommands; do
    [[ "$name" == "$target" ]] && return 0
  done
  return 1
}

# Add a catalog entry when its subcommand matches the filter prefix
# $1 subcommand  $2 filter  $3 title  $4 subtitle  $5 icon  $6 autocomplete
cat_item() {
  local name="$1" filter="$2" title="$3" subtitle="$4" icon="$5" autocomplete="$6"
  case "$name" in
    "$filter"*) add_result "" "" "$title" "$subtitle" "$icon" "no" "$autocomplete" ;;
    *) : ;;
  esac
  return 0
}

# Catalog of commands, optionally filtered by a subcommand prefix
# $1 = filter (may be empty)
catalog() {
  local filter="$1"
  cat_item wifi     "$filter" "Wi-Fi"      "Show Wi-Fi info and toggle it on or off"        "$ICON_WIFI" "wifi "
  cat_item eth      "$filter" "Ethernet"   "Show Ethernet info"                             "$ICON_ETH"  "eth "
  cat_item wifilist "$filter" "Wi-Fi List" "Scan for nearby Wi-Fi networks"                 "$ICON_WIFI" "wifilist "
  cat_item vpn      "$filter" "VPN"        "List configured VPNs and connect"               "$ICON_VPN"  "vpn "
  cat_item dns      "$filter" "DNS"        "List and change DNS for the primary connection" "$ICON_DNS"  "dns "
  get_json_results
  return 0
}

# The ">" menu, filtered by a substring: settings and the shared update items.
globals_menu() {
  local filter="$1" lc
  lc="$(printf '%s' "$filter" | tr '[:upper:]' '[:lower:]')"
  if [[ "edit dns presets" == *"$lc"* ]]; then
    add_result "" "dns EDIT" "Edit DNS presets" "Open the DNS presets file in a text editor" "$ICON_DNS" "yes"
  fi
  autoupdate_menu "$filter" "icon.png"
  get_json_results
  return 0
}

# Run the action for a selected item
if [[ "$mode" == "run" ]]; then
  case "$cmd" in
    wifi)     . src/wifi.sh "$rest" ;;
    eth)      . src/ethernet.sh "$rest" ;;
    wifilist) . src/ap.sh "$rest" ;;
    vpn)      . src/vpn.sh "$rest" ;;
    dns)      . src/dns.sh "$rest" ;;
    http://*|https://*) autoupdate_clear; . src/update.sh "$query" ;;
    autoupdate) set_autoupdate "$rest" ;;
    *) : ;;
  esac
  exit
fi

# List mode
if [[ "$cmd" == ">" ]]; then
  # ">" opens the settings and updates menu; "> update" checks for a new version
  if [[ "$rest" == update* ]]; then
    . src/update.sh ""
  else
    globals_menu "$rest"
  fi
elif [[ -z "$cmd" ]]; then
  autoupdate_refresh
  autoupdate_banner
  catalog ""
elif is_subcommand "$cmd"; then
  ARG_PREFIX="$cmd "
  case "$cmd" in
    wifi)     . src/wifi.sh "$rest" ;;
    eth)      . src/ethernet.sh "$rest" ;;
    wifilist) . src/ap.sh "$rest" ;;
    vpn)      . src/vpn.sh "$rest" ;;
    dns)      . src/dns.sh "$rest" ;;
    *) : ;;
  esac
else
  catalog "$cmd"
fi
