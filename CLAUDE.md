# CLAUDE.md

Alfred workflow that shows and changes network settings: Wi-Fi, Ethernet, VPN and DNS.
A maintained fork of `mrodalgaard/alfred-network-workflow`, updated for modern macOS.
Keyword: `net`. Artifact: `Network.alfredworkflow`.

## Layout

- `src/net.sh` - the single entry point and router. It takes `mode` (`list` or `run`) and `query`.
- `net <command>` dispatches to `src/wifi.sh`, `ethernet.sh`, `ap.sh` (wifilist), `vpn.sh` or `dns.sh`. `ARG_PREFIX` routes selections back through `net`.
- `src/wifi_common.sh`, `src/ethernet_common.sh`, `src/helpers.sh` - shared helpers.
- `src/wifi-scan.js` - JXA CoreWLAN scanner, run with `osascript -l JavaScript`. It reads real SSIDs without a Location prompt.
- `src/parse-wifi.awk`, `src/wifi-rows.jq`, `src/build-wifi-items.jq`, `src/wifi-hint.jq` - extracted awk and jq programs.
- `src/default-dns.conf` - the default DNS presets.
- `src/workflow_handler.sh` - shared JSON feedback helpers, identical in all sibling workflows.
- `src/media.sh` - icon paths. Icons live in `media/`, not `icons/`. The UUID-named PNGs at the root are Alfred object icons.
- `src/update.sh`, `src/autoupdate.sh` - fetched at build time from `alfred-workflow-updater`. Gitignored, never committed.
- `info.plist` - Alfred objects and the workflow `version`.
- `tests/*.bats`, `tests/variables.bash` (shared fixtures), `tests/perf_tests.bats`.
- `tests/mocks/bin/` - fakes for `networksetup`, `scutil`, `ipconfig`, `system_profiler`, `security`, `dig`, `dscacheutil`, `osascript`, `open`.

## Commands

```sh
make lint       # ShellCheck wifi, ethernet, ap, dns, vpn and net scripts in Docker
make test       # fetch the updater, run verify-js, then bats tests (macOS)
make verify-js  # run wifi-scan.js and check it prints valid JSON (macOS)
make coverage   # bats under kcov in Docker, writes sonar-coverage.xml
make build      # fetch and verify the updater, zip Network.alfredworkflow
make clean      # remove the artifact, fetched updater and coverage
```

1. Install tools with `brew install bats-core jq`.
2. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead of Docker.
3. `make test` needs network access, because it fetches the updater bundle first.
4. `LIVE_DNS_TEST=1 make test` enables the one live OpenDNS test. It is skipped by default.
5. `WIFI_SCAN_TEST` feeds `wifi-scan.js` fixed data in `tests/wifi_scan_tests.bats`.

## Constraints and conventions

- Scripts run under stock macOS `/bin/bash` 3.2.
- No bash 4+ features: no `mapfile`, `readarray`, `declare -A`, `${var,,}` or `${var^^}`.
- Check a construct with `/bin/bash -c '...'`. zsh and Homebrew bash 5 hide 3.2 gaps.
- No perl. Use `awk`, `sed`, `jq` or bash.
- Wi-Fi data comes from `wifi-scan.js`. `system_profiler SPAirPortDataType` is the fallback only. The `airport` CLI is gone since macOS 14.4.
- No compiled helper, no code signing, no Location prompt.
- Build Script Filter JSON with `add_result` and `get_json_results`, never by hand.
- The Script Filter must feel instant. Spawn `jq` once per run, not once per network.
- Put multi-line jq or awk programs in `src/*.jq` or `src/*.awk` and call them with `-f`.
- Settings and updates live behind the `net >` menu. `globals_menu` in `net.sh` calls the shared `autoupdate_menu`.
- Update logic lives only in `alfred-workflow-updater`. Never reimplement it here.
- SonarCloud shell rules: `[[ ]]` not `[ ]`, positional params into named lowercase `local`s, snake_case functions, explicit `return` at function end, a `*)` default in every `case`, HTTPS for `curl`.
- The subcommand scripts come from the fork and use top-level code and uppercase globals such as `INTERFACE`. Hold new and changed code to the rules above.
- `make coverage` ends with `|| true` and skips `wifi_scan_tests.bats`. kcov mangles some jq-heavy tests on Linux. Coverage sits near 90%. Accept it.

## Review focus

Flag these in a pull request:

- Any bash 4+ feature, or any perl call.
- A new or changed function without a bats test. A bug fix without a test that fails before the fix.
- Unquoted variable expansions, especially SSIDs, interface names, VPN names and DNS servers.
- `jq`, `awk` or a subshell spawned inside a per-network loop.
- A multi-line jq or awk program embedded in `$(...)` instead of a `src/*.jq` or `src/*.awk` file.
- Hand-built JSON strings instead of `add_result` and `json_encode`.
- A test that changes real network state or runs a real system command instead of a mock.
- A change to `wifi-scan.js` without a `WIFI_SCAN_TEST` case, or output that is no longer valid JSON.
- A new subcommand that `net.sh` does not route in both `list` and `run` mode, or that the catalog does not list.
- A new `src/*.sh` script that the `SCRIPTS` list in the Makefile does not lint.
- A violation of the Sonar shell rules listed above, in new or changed code.
- A "fix" for the kcov limits that breaks bash 3.2 compatibility.
- Update or autoupdate logic added here, or a committed `src/update.sh` or `src/autoupdate.sh`.
- A change to `.github/workflows/ci.yml`, `release.yml` or `bump-version.yml` in this repo only. These are byte-identical across all 8 Alfred repos.
- A user-facing change without an entry under `## [Unreleased]` in `CHANGELOG.md`.
- A behavior change without a README update.

Commit, branch and pull request rules are in `CONTRIBUTING.md`.

## CI and release

- `ci.yml`: ShellCheck, actionlint and zizmor on Ubuntu, bats on `macos-latest`, the build, and a SonarCloud scan with kcov coverage.
- The version lives in `info.plist`. `make print-version` and `make set-version VERSION=x.y.z` read and write it.
- A maintainer runs **Bump Version & Release**. It cuts the `CHANGELOG.md` section and tags `v*`.
- `release.yml` builds with `CHECK_PROVENANCE=1`, attests the artifact, and publishes an immutable release.
