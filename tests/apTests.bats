#!/usr/bin/env bats

. src/helpers.sh
load variables

@test "getSavedAPs: get saved access points" {
  run getSavedAPs "$SAVED_APS"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "$status" -eq 0 ]
  [ "${ARRAY[0]}" == "Test-Network" ]
  [ "${ARRAY[1]}" == "Test-Network2" ]
  [ "${ARRAY[2]}" == "Martins iPhone" ]
}

@test "parseScanResults: parse into a json array" {
  run parseScanResults "$SCAN" "en0"

  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 3' >/dev/null
  echo "$output" | jq -e '.[0] | .section=="current" and .ssid=="HomeNet" and .channel==36 and .security=="WPA2 Personal" and .rssi==-45' >/dev/null
  echo "$output" | jq -e '.[1] | .section=="other" and .ssid=="CoffeeShop" and .security=="None"' >/dev/null
}

@test "parseScanResults: ignore other interfaces" {
  run parseScanResults "$SCAN" "en0"

  [ "$(echo "$output" | grep -c awdl)" == 0 ]
  [ "$(echo "$output" | grep -c Infrastructure)" == 0 ]
}

@test "getActiveScanSSID: read the current network name" {
  run getActiveScanSSID "$(parseScanResults "$SCAN" en0)"

  [ "$status" -eq 0 ]
  [ "$output" == "HomeNet" ]
}

@test "getScanStrength: level from RSSI" {
  run getScanStrength "-45"
  [ "$output" == 4 ]

  run getScanStrength "-65"
  [ "$output" == 3 ]

  run getScanStrength "-75"
  [ "$output" == 2 ]

  run getScanStrength "-85"
  [ "$output" == 1 ]
}

@test "getScanStrength: unknown signal defaults to full" {
  run getScanStrength ""
  [ "$output" == 4 ]
}

# Build a JSON networks array from one network for buildWifiItems
net1() { # section ssid channel security rssi
  jq -nc --arg s "$1" --arg ssid "$2" --argjson ch "$3" --arg sec "$4" --argjson rssi "$5" \
    '[{section:$s, ssid:$ssid, channel:$ch, security:$sec, rssi:$rssi}]'
}

@test "buildWifiItems: current network gets the active icon and sorts first" {
  NETS=$(jq -sc 'add' <<< "$(net1 current HomeNet 36 "WPA2 Personal" -45; net1 other CoffeeShop 40 None -50)")
  run buildWifiItems "$NETS"
  echo "$output" | jq -e '.[0].title == "HomeNet" and .[0].icon.path == "media/wifi-active-4.png"' >/dev/null
  echo "$output" | jq -e '.[0].subtitle == "RSSI -45 dBm, channel 36, WPA2 Personal"' >/dev/null
}

@test "buildWifiItems: open network uses a plain icon and is actionable" {
  run buildWifiItems "$(net1 other CoffeeShop 40 None -50)"
  echo "$output" | jq -e '.[0].title == "CoffeeShop" and .[0].icon.path == "media/wifi-4.png" and .[0].valid == true' >/dev/null
}

@test "buildWifiItems: secured network uses a lock icon" {
  run buildWifiItems "$(net1 other "Neighbor 5G" 132 "WPA2 Personal" -72)"
  echo "$output" | jq -e '.[0].icon.path == "media/wifi-lock-2.png"' >/dev/null
}

@test "buildWifiItems: only the current section is active" {
  run buildWifiItems "$(net1 other HomeNet 6 None -50)"
  echo "$output" | jq -e '.[0].icon.path == "media/wifi-4.png"' >/dev/null
}

@test "buildWifiItems: saved network is marked with a star" {
  SAVED="Neighbor 5G
  Random other AP"
  run buildWifiItems "$(net1 other "Neighbor 5G" 132 "WPA2 Personal" -72)" "$SAVED"
  echo "$output" | jq -e '.[0].icon.path == "media/wifi-star-2.png"' >/dev/null
}

@test "buildWifiItems: empty SSIDs are skipped" {
  run buildWifiItems "$(net1 other "" 40 None -50)"
  [ "$output" == "[]" ]
}

@test "buildWifiItems: redacted network is a non-actionable hidden row" {
  run buildWifiItems "$(net1 current "<redacted>" 36 "WPA2 Personal" -45)"
  echo "$output" | jq -e '.[0].title == "Hidden network" and .[0].valid == false and .[0].arg == ""' >/dev/null
}

@test "buildWifiItems: item arg uses ARG_PREFIX" {
  ARG_PREFIX="wifilist "
  run buildWifiItems "$(net1 other CoffeeShop 40 None -50)"
  echo "$output" | jq -e '.[0].arg == "wifilist CoffeeShop"' >/dev/null
}

@test "listContains: contains element" {
  run listContains "$AP_LIST" "bar baz"
  [ "$status" -eq 0 ]
  [ "$output" == 1 ]
}

@test "listContains: does not contain element" {
  run listContains "$AP_LIST" "not"
  [ "$output" == "" ]
}

@test "listContains: list is empty" {
  run listContains "" "foo"
  [ "$output" == "" ]
}

@test "listContains: element is empty" {
  run listContains "$AP_LIST"
  [ "$output" == "" ]
}
