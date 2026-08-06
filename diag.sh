#!/bin/bash
. src/helpers.sh
export PATH="tests/mocks/bin:$PATH"
build_wifi_items '[{"section":"current","ssid":"HomeNet","channel":36,"security":"WPA2 Personal","rssi":-45}]'
