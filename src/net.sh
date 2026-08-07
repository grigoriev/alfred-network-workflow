#!/bin/bash

. src/workflow_handler.sh
. src/media.sh

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

subcommands="wifi eth wifilist vpn dns update"

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
    *) ;;
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
  # Update is always offered last, regardless of the filter.
  add_result "" "" "Update" "Check for and install workflow updates" "icon.png" "no" "update "
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
    http://*|https://*) . src/update.sh "$query" ;;
    *) ;;
  esac
  exit
fi

# List mode
if [[ -z "$cmd" ]]; then
  catalog ""
elif is_subcommand "$cmd"; then
  if [[ "$cmd" == "update" ]]; then
    # The shared updater builds its own arg (a download URL), so no prefix
    . src/update.sh "$rest"
  else
    ARG_PREFIX="$cmd "
    case "$cmd" in
      wifi)     . src/wifi.sh "$rest" ;;
      eth)      . src/ethernet.sh "$rest" ;;
      wifilist) . src/ap.sh "$rest" ;;
      vpn)      . src/vpn.sh "$rest" ;;
      dns)      . src/dns.sh "$rest" ;;
      *) ;;
    esac
  fi
else
  catalog "$cmd"
fi
