#!/usr/bin/env bats

. src/helpers.sh
load variables

@test "get_saved_aps: get saved access points" {
  run get_saved_aps "$SAVED_APS"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "$status" -eq 0 ]
  [ "${ARRAY[0]}" == "Test-Network" ]
  [ "${ARRAY[1]}" == "Test-Network2" ]
  [ "${ARRAY[2]}" == "Martins iPhone" ]
}

@test "parse_scan_results: parse into a json array" {
  run parse_scan_results "$SCAN" "en0"

  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 3' >/dev/null
  echo "$output" | jq -e '.[0] | .section=="current" and .ssid=="HomeNet" and .channel==36 and .security=="WPA2 Personal" and .rssi==-45' >/dev/null
  echo "$output" | jq -e '.[1] | .section=="other" and .ssid=="CoffeeShop" and .security=="None"' >/dev/null
}

@test "parse_scan_results: ignore other interfaces" {
  run parse_scan_results "$SCAN" "en0"

  [ "$(echo "$output" | grep -c awdl)" == 0 ]
  [ "$(echo "$output" | grep -c Infrastructure)" == 0 ]
}

@test "get_active_scan_ssid: read the current network name" {
  run get_active_scan_ssid "$(parse_scan_results "$SCAN" en0)"

  [ "$status" -eq 0 ]
  [ "$output" == "HomeNet" ]
}

@test "get_scan_strength: level from RSSI" {
  run get_scan_strength "-45"
  [ "$output" == 4 ]

  run get_scan_strength "-65"
  [ "$output" == 3 ]

  run get_scan_strength "-75"
  [ "$output" == 2 ]

  run get_scan_strength "-85"
  [ "$output" == 1 ]
}

@test "get_scan_strength: unknown signal defaults to full" {
  run get_scan_strength ""
  [ "$output" == 4 ]
}

# Build a JSON networks array from one network for build_wifi_items
net1() { # section ssid channel security rssi
  jq -nc --arg s "$1" --arg ssid "$2" --argjson ch "$3" --arg sec "$4" --argjson rssi "$5" \
    '[{section:$s, ssid:$ssid, channel:$ch, security:$sec, rssi:$rssi}]'
}

@test "build_wifi_items: current network gets the active icon and sorts first" {
  NETS=$(jq -sc 'add' <<< "$(net1 current HomeNet 36 "WPA2 Personal" -45; net1 other CoffeeShop 40 None -50)")
  run build_wifi_items "$NETS"
  echo "$output" | jq -e '.[0].title == "HomeNet" and .[0].icon.path == "media/wifi-active-4.png"' >/dev/null
  echo "$output" | jq -e '.[0].subtitle == "RSSI -45 dBm, channel 36, WPA2 Personal"' >/dev/null
}

@test "build_wifi_items: open network uses a plain icon and is actionable" {
  run build_wifi_items "$(net1 other CoffeeShop 40 None -50)"
  echo "$output" | jq -e '.[0].title == "CoffeeShop" and .[0].icon.path == "media/wifi-4.png" and .[0].valid == true' >/dev/null
}

@test "build_wifi_items: secured network uses a lock icon" {
  run build_wifi_items "$(net1 other "Neighbor 5G" 132 "WPA2 Personal" -72)"
  echo "$output" | jq -e '.[0].icon.path == "media/wifi-lock-2.png"' >/dev/null
}

@test "build_wifi_items: only the current section is active" {
  run build_wifi_items "$(net1 other HomeNet 6 None -50)"
  echo "$output" | jq -e '.[0].icon.path == "media/wifi-4.png"' >/dev/null
}

@test "build_wifi_items: saved network is marked with a star" {
  SAVED="Neighbor 5G
  Random other AP"
  run build_wifi_items "$(net1 other "Neighbor 5G" 132 "WPA2 Personal" -72)" "$SAVED"
  echo "$output" | jq -e '.[0].icon.path == "media/wifi-star-2.png"' >/dev/null
}

@test "build_wifi_items: empty SSIDs are skipped" {
  run build_wifi_items "$(net1 other "" 40 None -50)"
  [ "$output" == "[]" ]
}

@test "build_wifi_items: redacted network is a non-actionable hidden row" {
  run build_wifi_items "$(net1 current "<redacted>" 36 "WPA2 Personal" -45)"
  echo "$output" | jq -e '.[0].title == "Hidden network" and .[0].valid == false and .[0].arg == ""' >/dev/null
}

@test "build_wifi_items: item arg uses ARG_PREFIX" {
  ARG_PREFIX="wifilist "
  run build_wifi_items "$(net1 other CoffeeShop 40 None -50)"
  echo "$output" | jq -e '.[0].arg == "wifilist CoffeeShop"' >/dev/null
}

@test "list_contains: contains element" {
  run list_contains "$AP_LIST" "bar baz"
  [ "$status" -eq 0 ]
  [ "$output" == 1 ]
}

@test "list_contains: does not contain element" {
  run list_contains "$AP_LIST" "not"
  [ "$output" == "" ]
}

@test "list_contains: list is empty" {
  run list_contains "" "foo"
  [ "$output" == "" ]
}

@test "list_contains: element is empty" {
  run list_contains "$AP_LIST"
  [ "$output" == "" ]
}
