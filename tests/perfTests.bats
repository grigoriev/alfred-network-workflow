#!/usr/bin/env bats

# Performance guard for the Wi-Fi list. In dense areas (a hotel) a scan can
# return dozens of access points, so this times the wifilist render over a large
# mocked scan and fails on an order-of-magnitude regression. The measured time
# is printed so a slowdown is visible in the test output.
#
# Times with jq's `now` (already a dependency); BSD `date` has no %N.

BUDGET_MS=2000
NETWORKS=100

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export MOCK_SCAN_SIZE="$NETWORKS"
  export ap_scanning=1   # skip the "Scanning" placeholder, render directly
}

now_ms() { jq -n 'now * 1000 | floor'; }

@test "perf: wifilist render over many networks stays fast" {
  local start end ms
  start=$(now_ms)
  run bash -c '. src/net.sh list "wifilist"'
  end=$(now_ms)
  ms=$((end - start))
  [ "$status" -eq 0 ]
  echo "# wifilist render ($NETWORKS networks): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}
