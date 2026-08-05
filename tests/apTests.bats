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

@test "parseScanResults: parse current and other networks" {
  run parseScanResults "$SCAN" "en0"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" == "current~HomeNet~36~WPA2 Personal~-45" ]
  [ "${lines[1]}" == "other~CoffeeShop~40~None~" ]
  [ "${lines[2]}" == "other~Neighbor 5G~132~WPA2 Personal~-72" ]
  [ "${#lines[@]}" == 3 ]
}

@test "parseScanResults: ignore other interfaces" {
  run parseScanResults "$SCAN" "en0"

  [ "$(echo "$output" | grep -c awdl)" == 0 ]
  [ "$(echo "$output" | grep -c Infrastructure)" == 0 ]
}

@test "getActiveScanSSID: read the current network name" {
  run getActiveScanSSID "$SCAN" "en0"

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

@test "getScanDetails: active network is marked with an icon" {
  run getScanDetails "current~HomeNet~36~WPA2 Personal~-45" "HomeNet"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[0]}" == $PRIORITY_HIGH ]
  [ "${ARRAY[1]}" == "HomeNet" ]
  [ "${ARRAY[3]}" == "-45" ]
  [ "${ARRAY[4]}" == "36" ]
  [ "${ARRAY[5]}" == "WPA2 Personal" ]
  [ "${ARRAY[6]}" == $ICON_WIFI_ACTIVE ]
}

@test "getScanDetails: open network uses a plain icon" {
  run getScanDetails "other~CoffeeShop~40~None~"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[1]}" == "CoffeeShop" ]
  [ "${ARRAY[6]}" == $ICON_WIFI_4 ]
}

@test "getScanDetails: secured network uses a lock icon" {
  run getScanDetails "other~Neighbor 5G~132~WPA2 Personal~-72"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[0]}" == $PRIORITY_LOW ]
  [ "${ARRAY[1]}" == "Neighbor 5G" ]
  [ "${ARRAY[6]}" == $ICON_WIFI_LOCK_2 ]
}

@test "getScanDetails: redacted current network is active" {
  run getScanDetails "current~<redacted>~6~None~" "<redacted>"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[0]}" == $PRIORITY_HIGH ]
  [ "${ARRAY[6]}" == $ICON_WIFI_ACTIVE ]
}

@test "getScanDetails: redacted other network is not marked active" {
  run getScanDetails "other~<redacted>~40~WPA2 Personal~" "<redacted>"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[0]}" == $PRIORITY_LOW ]
  [ "${ARRAY[6]}" == $ICON_WIFI_LOCK_4 ]
}

@test "getScanDetails: favorited network is marked with an icon" {
  AP_LIST="Neighbor 5G
  Random other AP"

  run getScanDetails "other~Neighbor 5G~132~WPA2 Personal~-72" "" "$AP_LIST"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[0]}" == $PRIORITY_MEDIUM ]
  [ "${ARRAY[6]}" == $ICON_WIFI_STAR_2 ]
}

@test "getScanDetails: no BSSID from system_profiler" {
  run getScanDetails "other~CoffeeShop~40~None~"
  IFS='~' read -r -a ARRAY <<< "$output"

  [ "${ARRAY[2]}" == "" ]
}

@test "getScanDetails: filter empty SSIDs" {
  run getScanDetails "other~~40~None~"
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
