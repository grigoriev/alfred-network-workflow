# <img src="https://raw.githubusercontent.com/grigoriev/alfred-network-workflow/master/icon.png" alt="network" width="32"> Alfred Network Workflow ![CI](https://github.com/grigoriev/alfred-network-workflow/actions/workflows/ci.yml/badge.svg)

Alfred workflow that shows and changes your network settings: Wi-Fi, Ethernet, VPN and DNS.

This is a maintained fork of [mrodalgaard/alfred-network-workflow](https://github.com/mrodalgaard/alfred-network-workflow), updated for modern macOS.

## Install

1. Open the [latest release](https://github.com/grigoriev/alfred-network-workflow/releases/latest).
2. Under **Assets**, download `Network.alfredworkflow`.
3. Double click the file to add it to Alfred.

Alfred [Powerpack](https://www.alfredapp.com/powerpack/) is required.

## Usage

| Keyword    | Action                                          |
| ---------- | ----------------------------------------------- |
| `wifi`     | Show Wi-Fi info, toggle Wi-Fi on or off.        |
| `eth`      | Show Ethernet info when connected.              |
| `wifilist` | Scan for Wi-Fi networks and connect.            |
| `vpn`      | List configured VPNs and connect.               |
| `dns`      | List and change DNS for the primary connection. |

<p align="center">
<img src="https://raw.githubusercontent.com/grigoriev/alfred-network-workflow/master/screenshots/wifi-preview.png" alt="wifi" width="600">
<img src="https://raw.githubusercontent.com/grigoriev/alfred-network-workflow/master/screenshots/wifilist-preview.png" alt="wifilist" width="600">
</p>

## macOS 14 and later

Apple removed the `airport` cli in macOS 14.4. This fork replaces it:

- `wifilist` scans with `system_profiler SPAirPortDataType`.
- `wifi` reads the current connection with `ipconfig getsummary`.

macOS hides network names (SSID and BSSID) until the workflow has Location access. To see names, open **System Settings > Privacy & Security > Location Services** and enable location for Alfred.

## Limitations

- Most actions work as a standard user. Actions that change network settings can fail without admin rights.
- Access point changes need your keychain password. This is a [known limitation](https://github.com/mrodalgaard/alfred-network-workflow/issues/11#issuecomment-559252188).
- A Wi-Fi scan takes a few seconds. `wifilist` shows a "Scanning" placeholder while it runs.

## How it works

The logic lives in `src/` as Bash scripts. `info.plist` is the Alfred workflow definition: it maps each keyword to its script and wires the connect actions. Every command runs `src/<name>.sh`, talks to macOS network utilities (`networksetup`, `scutil`, `system_profiler`, `ipconfig`), and returns Alfred JSON feedback.

## Development

A `Makefile` drives the same steps locally and in CI:

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # fetch the updater and build Network.alfredworkflow
make clean     # remove the build artifact and fetched files
```

Install the tools with `brew install bats-core shellcheck`. System commands are replaced by mocks under `tests/mocks/bin`, so the action scripts run deterministically without touching real network state.

The self-update logic is shared, not vendored. `make build` fetches
[`update.sh`](https://github.com/grigoriev/alfred-workflow-updater) at build time and bundles it, so it is never stored in this repository.

## Releases

Pushing a `v*` tag builds `Network.alfredworkflow` and publishes a GitHub Release with the asset attached. The tag also sets the workflow version.

## Credits

A fork of the original workflow by [Martin Rodalgaard](https://github.com/mrodalgaard/alfred-network-workflow). Contributions, bug reports and feature requests are welcome.

Licensed under the MIT License. See [LICENSE.md](LICENSE.md).
