#!/usr/bin/env bats

. src/helpers.sh
load variables

setup() {
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
}

@test "json_encode: escape quote and backslash" {
  run json_encode 'a"b\c'
  [ "$output" == 'a\"b\\c' ]
}

@test "json_encode: plain text is unchanged" {
  run json_encode "Test-Network"
  [ "$output" == "Test-Network" ]
}

@test "add_result and get_json_results: build feedback json" {
  add_result "uid1" "arg1" "Title" "Subtitle" "icon.png" "yes" "auto"
  run get_json_results

  [ "$status" -eq 0 ]
  [[ "$output" =~ '"items":[' ]]
  [[ "$output" =~ '"title":"Title"' ]]
  [[ "$output" =~ '"subtitle":"Subtitle"' ]]
  [[ "$output" =~ '"arg":"arg1"' ]]
  [[ "$output" =~ '"uid":"uid1"' ]]
  [[ "$output" =~ '"icon":{"path":"icon.png"}' ]]
  [[ "$output" =~ '"autocomplete":"auto"' ]]
}

@test "add_result: escapes special characters in fields" {
  add_result "" 'a"b' 'back\slash' "" "" "" ""
  run get_json_results
  [[ "$output" =~ '"arg":"a\"b"' ]]
  [[ "$output" =~ '"title":"back\\slash"' ]]
}

@test "add_result: ARG_PREFIX prefixes a non-empty arg" {
  ARG_PREFIX="wifi "
  add_result "" "Off" "Turn Off" "" "i.png"
  run get_json_results
  [[ "$output" =~ '"arg":"wifi Off"' ]]
}

@test "add_result: ARG_PREFIX leaves an empty arg empty" {
  ARG_PREFIX="wifi "
  add_result "" "" "Info" "row" "i.png" "no"
  run get_json_results
  [[ "$output" =~ '"arg":""' ]]
}

@test "add_result: omits uid when empty and marks invalid" {
  add_result "" "" "Info" "row" "i.png" "no" ""
  run get_json_results
  [[ ! "$output" =~ '"uid"' ]]
  [[ "$output" =~ '"valid":false' ]]
}

@test "add_result: adds a cmd modifier when given" {
  add_result "" "Net" "Net" "sub" "i.png" "" "" "Rescan" "RESCAN"
  run get_json_results
  echo "$output" | jq -e '.items[0].mods.cmd | .valid == true and .arg == "RESCAN" and .subtitle == "Rescan"' >/dev/null
}

@test "add_result: routes the cmd modifier arg through ARG_PREFIX" {
  ARG_PREFIX="wifi "
  add_result "" "Net" "Net" "sub" "i.png" "" "" "Rescan" "RESCAN"
  run get_json_results
  echo "$output" | jq -e '.items[0].mods.cmd.arg == "wifi RESCAN"' >/dev/null
}

@test "add_result: no mods key without a modifier arg" {
  add_result "" "Net" "Net" "sub" "i.png"
  run get_json_results
  [[ ! "$output" =~ '"mods"' ]]
}

@test "get_json_results: empty result set is valid json" {
  run get_json_results
  [ "$output" == '{"items":[]}' ]
}

@test "get_json_results: emit rerun and variables" {
  set_rerun 0.1
  add_variable "ap_scanning" "1"
  add_result "" "" "Scanning" "" "i.png" "no" ""
  run get_json_results
  [[ "$output" =~ '"rerun":0.1' ]]
  [[ "$output" =~ '"variables":{"ap_scanning":"1"}' ]]
  [[ "$output" =~ '"items":[' ]]
}

@test "set_pref and get_pref: store and read a value" {
  set_pref "server" "8.8.8.8" 1
  run get_pref "server" 1
  [ "$output" == "8.8.8.8" ]
}

@test "set_pref: overwrite an existing key" {
  set_pref "server" "8.8.8.8" 1
  set_pref "server" "1.1.1.1" 1
  run get_pref "server" 1
  [ "$output" == "1.1.1.1" ]
}

@test "set_pref and get_pref: custom filename" {
  set_pref "token" "abc" 1 "custom"
  run get_pref "token" 1 "custom"
  [ "$output" == "abc" ]
}

@test "get_pref: missing dir returns empty" {
  run get_pref "server" 1
  [ "$output" == "" ]
}

@test "get_pref: key is not matched as a substring" {
  set_pref "dns" "1.1.1.1" 1
  set_pref "dns2" "9.9.9.9" 1
  run get_pref "dns" 1
  [ "$output" == "1.1.1.1" ]
}

@test "set_pref: overwrite does not remove a similar key" {
  set_pref "dns" "1.1.1.1" 1
  set_pref "dns2" "9.9.9.9" 1
  set_pref "dns" "8.8.8.8" 1
  run get_pref "dns2" 1
  [ "$output" == "9.9.9.9" ]
}

@test "get_wifi_strength: level from RSSI" {
  run get_wifi_strength "-45"
  [ "$output" == 4 ]

  run get_wifi_strength "-65"
  [ "$output" == 3 ]

  run get_wifi_strength "-75"
  [ "$output" == 2 ]

  run get_wifi_strength "-85"
  [ "$output" == 1 ]
}
