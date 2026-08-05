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

# Build a network JSON object for getScanDetails
netjson() { # section ssid channel security rssi
  jq -nc --arg s "$1" --arg ssid "$2" --argjson ch "$3" --arg sec "$4" --argjson rssi "$5" \
    '{section:$s, ssid:$ssid, channel:$ch, security:$sec, rssi:$rssi}'
}

@test "getScanDetails: current network is marked active" {
  run getScanDetails "$(netjson current HomeNet 36 "WPA2 Personal" -45)"
  echo "$output" | jq -e ".priority == $PRIORITY_HIGH and .ssid == \"HomeNet\" and .channel == 36 and .icon == \"$ICON_WIFI_ACTIVE\"" >/dev/null
}

@test "getScanDetails: open network uses a plain icon" {
  run getScanDetails "$(netjson other CoffeeShop 40 None -50)"
  echo "$output" | jq -e ".ssid == \"CoffeeShop\" and .icon == \"$ICON_WIFI_4\"" >/dev/null
}

@test "getScanDetails: secured network uses a lock icon" {
  run getScanDetails "$(netjson other "Neighbor 5G" 132 "WPA2 Personal" -72)"
  echo "$output" | jq -e ".priority == $PRIORITY_LOW and .icon == \"$ICON_WIFI_LOCK_2\"" >/dev/null
}

@test "getScanDetails: only the current section is active" {
  run getScanDetails "$(netjson other HomeNet 6 None -50)"
  echo "$output" | jq -e ".priority == $PRIORITY_LOW" >/dev/null
}

@test "getScanDetails: favorited network is marked with a star" {
  AP_LIST="Neighbor 5G
  Random other AP"

  run getScanDetails "$(netjson other "Neighbor 5G" 132 "WPA2 Personal" -72)" "$AP_LIST"
  echo "$output" | jq -e ".priority == $PRIORITY_MEDIUM and .icon == \"$ICON_WIFI_STAR_2\"" >/dev/null
}

@test "getScanDetails: filter empty SSIDs" {
  run getScanDetails "$(netjson other "" 40 None -50)"
  [ "$output" == "" ]
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
