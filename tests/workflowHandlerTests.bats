#!/usr/bin/env bats

. src/helpers.sh
load variables

setup() {
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
}

@test "jsonEncode: escape quote and backslash" {
  run jsonEncode 'a"b\c'
  [ "$output" == 'a\"b\\c' ]
}

@test "jsonEncode: plain text is unchanged" {
  run jsonEncode "Test-Network"
  [ "$output" == "Test-Network" ]
}

@test "addResult and getJSONResults: build feedback json" {
  addResult "uid1" "arg1" "Title" "Subtitle" "icon.png" "yes" "auto"
  run getJSONResults

  [ "$status" -eq 0 ]
  [[ "$output" =~ '"items":[' ]]
  [[ "$output" =~ '"title":"Title"' ]]
  [[ "$output" =~ '"subtitle":"Subtitle"' ]]
  [[ "$output" =~ '"arg":"arg1"' ]]
  [[ "$output" =~ '"uid":"uid1"' ]]
  [[ "$output" =~ '"icon":{"path":"icon.png"}' ]]
  [[ "$output" =~ '"autocomplete":"auto"' ]]
}

@test "addResult: escapes special characters in fields" {
  addResult "" 'a"b' 'back\slash' "" "" "" ""
  run getJSONResults
  [[ "$output" =~ '"arg":"a\"b"' ]]
  [[ "$output" =~ '"title":"back\\slash"' ]]
}

@test "addResult: ARG_PREFIX prefixes a non-empty arg" {
  ARG_PREFIX="wifi "
  addResult "" "Off" "Turn Off" "" "i.png"
  run getJSONResults
  [[ "$output" =~ '"arg":"wifi Off"' ]]
}

@test "addResult: ARG_PREFIX leaves an empty arg empty" {
  ARG_PREFIX="wifi "
  addResult "" "" "Info" "row" "i.png" "no"
  run getJSONResults
  [[ "$output" =~ '"arg":""' ]]
}

@test "addResult: omits uid when empty and marks invalid" {
  addResult "" "" "Info" "row" "i.png" "no" ""
  run getJSONResults
  [[ ! "$output" =~ '"uid"' ]]
  [[ "$output" =~ '"valid":false' ]]
}

@test "getJSONResults: empty result set is valid json" {
  run getJSONResults
  [ "$output" == '{"items":[]}' ]
}

@test "getJSONResults: emit rerun and variables" {
  setRerun 0.1
  addVariable "ap_scanning" "1"
  addResult "" "" "Scanning" "" "i.png" "no" ""
  run getJSONResults
  [[ "$output" =~ '"rerun":0.1' ]]
  [[ "$output" =~ '"variables":{"ap_scanning":"1"}' ]]
  [[ "$output" =~ '"items":[' ]]
}

@test "setPref and getPref: store and read a value" {
  setPref "server" "8.8.8.8" 1
  run getPref "server" 1
  [ "$output" == "8.8.8.8" ]
}

@test "setPref: overwrite an existing key" {
  setPref "server" "8.8.8.8" 1
  setPref "server" "1.1.1.1" 1
  run getPref "server" 1
  [ "$output" == "1.1.1.1" ]
}

@test "setPref and getPref: custom filename" {
  setPref "token" "abc" 1 "custom"
  run getPref "token" 1 "custom"
  [ "$output" == "abc" ]
}

@test "getPref: missing dir returns empty" {
  run getPref "server" 1
  [ "$output" == "" ]
}

@test "getPref: key is not matched as a substring" {
  setPref "dns" "1.1.1.1" 1
  setPref "dns2" "9.9.9.9" 1
  run getPref "dns" 1
  [ "$output" == "1.1.1.1" ]
}

@test "setPref: overwrite does not remove a similar key" {
  setPref "dns" "1.1.1.1" 1
  setPref "dns2" "9.9.9.9" 1
  setPref "dns" "8.8.8.8" 1
  run getPref "dns2" 1
  [ "$output" == "9.9.9.9" ]
}

@test "getWifiStrength: level from RSSI" {
  run getWifiStrength "-45"
  [ "$output" == 4 ]

  run getWifiStrength "-65"
  [ "$output" == 3 ]

  run getWifiStrength "-75"
  [ "$output" == 2 ]

  run getWifiStrength "-85"
  [ "$output" == 1 ]
}
