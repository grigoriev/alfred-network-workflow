#!/bin/bash
. src/helpers.sh
export PATH="tests/mocks/bin:$PATH"
echo "BWI>>>$(build_wifi_items '[{"section":"current","ssid":"X","channel":36,"security":"None","rssi":-45}]')<<<"
echo "WSTATE>>>$(get_wifi_state en0)<<<"
