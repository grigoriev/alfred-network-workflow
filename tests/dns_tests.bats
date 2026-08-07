#!/usr/bin/env bats

. src/helpers.sh
load variables

@test "get_dns: get current DNS list" {
  run get_dns "$DNS"
  [ "$output" = "8.8.8.8 / 8.8.4.4 / 192.168.1.1" ]
}

@test "get_dns: empty when no servers are set" {
  run get_dns "There aren't any DNS Servers set on Wi-Fi."
  [ "$output" == "" ]
}

@test "parse_dns_line: parse a single dns config line" {
  run parse_dns_line "Google DNS:8.8.8.8,8.8.4.4"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "$status" -eq 0 ]
  [ "${ARRAY[0]}" == "Google DNS" ]
  [ "${ARRAY[1]}" == "8.8.8.8 / 8.8.4.4" ]
  [ "${ARRAY[2]}" == "$ICON_DNS" ]
}

@test "parse_dns_line: parse simple config" {
  run parse_dns_line "OpenerDNS:42.120.21.30"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "OpenerDNS" ]
  [ "${ARRAY[1]}" == "42.120.21.30" ]
}

@test "parse_dns_line: parse with spaces" {
  run parse_dns_line "  Random DNS  :  1.2.3.4 , 6.7.8.9"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "Random DNS" ]
  [ "${ARRAY[1]}" == "1.2.3.4 / 6.7.8.9" ]
}

@test "parse_dns_line: ignore comments" {
  run parse_dns_line "# comment"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "" ]
}

@test "parse_dns_line: ignore comments with separator" {
  run parse_dns_line "# comment: this is a comment"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "" ]
}

@test "parse_dns_line: ignore empty lines" {
  run parse_dns_line "  "
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "" ]
}

@test "parse_dns_line: set used state" {
  run parse_dns_line "Google DNS:8.8.8.8,8.8.4.4" "8.8.8.8 / 8.8.4.4"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "Google DNS (used)" ]
  [ "${ARRAY[1]}" == "8.8.8.8 / 8.8.4.4" ]
  [ "${ARRAY[2]}" == "$ICON_DNS_USED" ]
}

@test "parse_dns_line: handle invalid line" {
  run parse_dns_line "Invalid 1.2.3.4"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "" ]
}

@test "parse_dns_line: handle missing ip" {
  run parse_dns_line "Invalid:"
  IFS='~' read -r -a ARRAY <<< "$output"
  [ "${ARRAY[0]}" == "" ]
}
