#!/usr/bin/env bats

. src/helpers.sh
load variables

setup() {
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
}

@test "xmlEncode: escape special characters" {
  run xmlEncode "a&b<c>d'e\"f"
  [ "$output" == "a&amp;b&lt;c&gt;d&apos;e&quot;f" ]
}

@test "xmlEncode: plain text is unchanged" {
  run xmlEncode "Test-Network"
  [ "$output" == "Test-Network" ]
}

@test "addResult and getXMLResults: build feedback xml" {
  addResult "uid1" "arg1" "Title" "Subtitle" "icon.png" "yes" "auto"
  run getXMLResults

  [ "$status" -eq 0 ]
  [[ "$output" =~ "<?xml version='1.0'?>" ]]
  [[ "$output" =~ "<title>Title</title>" ]]
  [[ "$output" =~ "<subtitle>Subtitle</subtitle>" ]]
  [[ "$output" =~ "arg='arg1'" ]]
  [[ "$output" =~ "uid='uid1'" ]]
}

@test "addResult: escapes xml in fields" {
  addResult "" "R&D" "A & B" "" "" "" ""
  run getXMLResults
  [[ "$output" =~ "arg='R&amp;D'" ]]
  [[ "$output" =~ "<title>A &amp; B</title>" ]]
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
