# <img src="https://raw.githubusercontent.com/grigoriev/alfred-network-workflow/main/icon.png" alt="network" width="32"> Alfred Network Workflow

![CI](https://github.com/grigoriev/alfred-network-workflow/actions/workflows/ci.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/grigoriev/alfred-network-workflow)](https://github.com/grigoriev/alfred-network-workflow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Alfred workflow that shows and changes your network settings: Wi-Fi, Ethernet, VPN and DNS.

This is a maintained fork of [mrodalgaard/alfred-network-workflow](https://github.com/mrodalgaard/alfred-network-workflow), updated for modern macOS.

## Install

1. Open the [latest release](https://github.com/grigoriev/alfred-network-workflow/releases/latest).
2. Under **Assets**, download `Network.alfredworkflow`.
3. Double click the file to add it to Alfred.

Alfred [Powerpack](https://www.alfredapp.com/powerpack/) is required.

## Usage

Everything lives under one keyword. Type `net` to see the command catalog, then keep typing (`net v`) or press <kbd>Tab</kbd> to drill into a command.

| Command        | Action                                          |
| -------------- | ----------------------------------------------- |
| `net`          | List all commands.                              |
| `net wifi`     | Show Wi-Fi info, toggle Wi-Fi on or off.        |
| `net eth`      | Show Ethernet info when connected.              |
| `net wifilist` | Scan for Wi-Fi networks and connect.            |
| `net vpn`      | List configured VPNs and connect.               |
| `net dns`      | List and change DNS for the primary connection. |
| `net update`   | Check for and install workflow updates.         |

<p align="center">
<img src="https://raw.githubusercontent.com/grigoriev/alfred-network-workflow/main/screenshots/wifi-preview.png" alt="wifi" width="600">
<img src="https://raw.githubusercontent.com/grigoriev/alfred-network-workflow/main/screenshots/wifilist-preview.png" alt="wifilist" width="600">
</p>

## macOS 14 and later

Apple removed the `airport` cli in macOS 14.4, which broke Wi-Fi scanning. This fork works around it.

macOS 14+ hides Wi-Fi network names (SSID and BSSID) from most processes for privacy. The known workarounds (a compiled CoreWLAN helper, or `system_profiler`) return redacted names unless the app has Location access, and getting that requires a signed, notarized app.

**The workaround this fork uses:** read Wi-Fi with CoreWLAN through `osascript`. `osascript` is an Apple-signed system binary whose context is allowed to read SSIDs, so a small JXA script ([`src/wifi-scan.js`](src/wifi-scan.js)) run with `osascript -l JavaScript` returns real network names, channel, security and signal as JSON, with **no Location prompt, no code signing and no compiled binary**. The scripts parse that JSON with `jq`. `net wifilist` lists the networks and `net wifi` shows the current one's name; both fall back to `system_profiler SPAirPortDataType` (redacted names) only if the scanner returns nothing.

`jq` ships with macOS since Sequoia, so this needs a recent macOS (tested on macOS 26).

## Limitations

- Most actions work as a standard user. Actions that change network settings can fail without admin rights.
- Access point changes need your keychain password. This is a [known limitation](https://github.com/mrodalgaard/alfred-network-workflow/issues/11#issuecomment-559252188).
- A Wi-Fi scan takes a few seconds. `wifilist` shows a "Scanning" placeholder while it runs.

## How it works

`net` is the single entry point. `net.sh` is a router: with no argument it lists the command catalog, and `net <command>` dispatches to `src/<command>.sh`, prefixing item args so selections route back through `net`. The scripts talk to macOS network utilities (`networksetup`, `scutil`, `osascript`, `ipconfig`) and return Alfred JSON feedback. `info.plist` wires the single `net` Script Filter to a Run Script and Copy to Clipboard.

## Development

A `Makefile` drives the same steps locally and in CI:

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # fetch the updater and build Network.alfredworkflow
make clean     # remove the build artifact and fetched files
```

Install the tools with `brew install bats-core shellcheck jq`. System commands are replaced by mocks under `tests/mocks/bin`, so the action scripts run deterministically without touching real network state. The Wi-Fi scanner ([`src/wifi-scan.js`](src/wifi-scan.js)) is unit tested via a `WIFI_SCAN_TEST` hook that feeds it fixed data instead of scanning.

The self-update logic is shared, not vendored. `make build` fetches
[`update.sh`](https://github.com/grigoriev/alfred-workflow-updater) at build time and bundles it, so it is never stored in this repository.

## Releases

Pushing a `v*` tag builds `Network.alfredworkflow` and publishes a GitHub Release with the asset attached. The tag also sets the workflow version.

## Credits

A fork of the original workflow by [Martin Rodalgaard](https://github.com/mrodalgaard/alfred-network-workflow). Contributions, bug reports and feature requests are welcome.

Licensed under the MIT License. See [LICENSE](LICENSE).
