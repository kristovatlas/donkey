# Donkey: Harmless macOS Persistence Tool for Endpoint Protection Testing

[![GitHub license](https://img.shields.io/github/license/kristovatlas/donkey)](https://github.com/kristovatlas/donkey/blob/main/LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/kristovatlas/donkey)](https://github.com/kristovatlas/donkey/issues)

## Overview

Donkey is a simple, harmless tool designed to test endpoint detection and response (EDR) systems on macOS by establishing persistence via a LaunchAgent. It runs a Python script periodically (every 60 seconds) that appends timestamps to a local log file (`~/Documents/donkey.log`). Additional optional features can be enabled to mimic suspicious behaviors (e.g., reconnaissance, network activity, screen captures, port scanning, WiFi enumeration, LAN ARP scanning, browser history queries, keychain listing, clipboard access, harmless downloads, shell config modifications, or ransomware simulation) without causing any harm—all outputs remain local to the machine.

This tool is intended for ethical testing on controlled systems only. It does not exfiltrate data, modify system files beyond reversible changes, or perform any destructive actions. Use it to evaluate how EDR solutions detect persistence and related activities.

The LaunchAgent uses a randomized label (e.g., `com.donkey.<uuid>`) by default to mimic evasive techniques.

**Key Features:**
- Cross-compatible with older and newer macOS versions (detects Python 2/3 automatically).
- Always logs timestamps; optional behaviors added via flags.
- Easy installation and uninstallation via shell scripts.

## Prerequisites

- macOS (tested on versions 10.x through 15.x, including Sequoia).
- System Python (installed via Command Line Tools if not present—run `python3` in Terminal to trigger installation).
- Bash (default on macOS).

No additional dependencies are required. The Python script uses only standard libraries (`sys`, `subprocess`, `urllib.request`, `socket`, `ipaddress`, `sqlite3`, `os`, `os.path`, `datetime`).

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/kristovatlas/donkey.git
   cd donkey
   ```

2. Run the installer script with optional flags:
   ```
   bash installer.sh [options]
   ```

   The installer will:
   - Check if Donkey is already installed and uninstall it first if present.
   - Generate and install the Python script (`~/donkey.py`).
   - Create and load a LaunchAgent plist (`~/Library/LaunchAgents/com.donkey.<uuid>.plist`).
   - Use `launchctl bootstrap` (macOS 11+) or `load` (older) for compatibility.
   - Store the randomized label in `/tmp/donkey_label` for uninstall.

   By default (no options), it only appends timestamps to `~/Documents/donkey.log` every 60 seconds.

### Options

Specify one or more flags to enable additional harmless behaviors in the persistent script. These are passed as command-line arguments to the Python script via the plist, so the script itself remains static but conditionally executes features based on the flags.

- `--recon`: Enables system reconnaissance. Runs `whoami` and `ps -ef` to log the current user and process count to the log file. Mimics discovery tactics without any harm.
  
- `--beacon`: Enables harmless network beaconing. Sends a GET request to `https://httpbin.org/get` (a public echo service) and logs the response code. Mimics C2 communication; no data is sent.

- `--capture`: Enables local screen capture. Uses `screencapture -x` to save a silent screenshot to `~/Documents/donkey_screenshot.png` and logs the action. May prompt for TCC screen recording permission on first run; the image stays local.

- `--portscan`: Enables local network port scanning. Detects the local subnet (e.g., 192.168.1.0/24), scans common ports (22, 80, 443, 445, 3389) on the first 10 hosts, and logs any open ports found. Mimics lateral movement reconnaissance; limited scope to avoid performance issues; all results stay local.

- `--wifi`: Enables WiFi enumeration. Scans for nearby WiFi networks using the `airport` tool and logs the first few SSIDs. Mimics network reconnaissance; results stay local.

- `--lanarp`: Enables LAN device ARP scan. Runs `arp -a` to list local network devices and logs the first few IPs. Mimics lateral movement preparation; limited scope.

- `--browser`: Enables browser history query. Reads recent URLs from Safari's History.db (last 5) and logs them. Mimics infostealer behavior; may require TCC permission; data stays local.

- `--keychain`: Enables keychain listing. Runs `security list-keychains` to list available keychains and logs the first few. Mimics credential access; results stay local.

- `--clipboard`: Enables clipboard monitoring. Accesses the clipboard via `pbpaste` (without logging contents to avoid sensitive data) and logs the access action. Mimics infostealer reconnaissance.

- `--download`: Enables harmless download. Downloads truncated data from a public test endpoint (`https://httpbin.org/anything`) and saves to `~/Documents/donkey_download.txt`. Mimics multi-stage payload behavior; file stays local.

- `--zshenv`: Enables shell config modification. Appends a benign no-op line to `~/.zshenv` for additional persistence. Mimics evasive injection techniques; easily reversible.

- `--ransom`: Enables ransomware simulation. Creates a few dummy files in ~ (e.g., donkey_dummy1.txt), encrypts them with a simple XOR using static key 'donkeykey', deletes originals, and leaves .enc files. Affects only these test files; runs once; key logged for manual decryption if needed.

**Examples:**
- Basic install (timestamps only):
  ```
  bash installer.sh
  ```
- With reconnaissance and beacon:
  ```
  bash installer.sh --recon --beacon
  ```
- All features:
  ```
  bash installer.sh --recon --beacon --capture --portscan --wifi --lanarp --browser --keychain --clipboard --download --zshenv --ransom
  ```

After installation:
- The script will output the randomized label (e.g., "Installed with randomized label: com.donkey.abc123...").
- Verify the agent is running: `launchctl print gui/$(id -u) | grep com.donkey` (macOS 11+) or `launchctl list | grep com.donkey`.
- Check the log: `tail -f ~/Documents/donkey.log` (should update every ~60 seconds).
- Debug outputs: Check `/tmp/donkey.out` and `/tmp/donkey.err` for any stdout/stderr from script runs.

## Uninstallation

To remove Donkey completely:
```
bash uninstall.sh
```

This will:
- Unload the LaunchAgent (using the stored label from `/tmp/donkey_label`).
- Delete the plist file.
- Delete the Python script.
- Clean up debug files (`/tmp/donkey.out`, `/tmp/donkey.err`).
- Remove any added line from `~/.zshenv` (if `--zshenv` was used).
- Delete `~/Documents/donkey_download.txt` (if `--download` was used) and `~/Documents/donkey_screenshot.png` (if `--capture` was used).
- Delete dummy/encrypted files and flag (if `--ransom` was used: `~/donkey_dummy*.txt`, `~/donkey_dummy*.txt.enc`, `~/.donkey_ransom_done`).
- Remove the temporary label file.

**Notes on Cleanup:**
- The log file (`~/Documents/donkey.log`) is not deleted by default to preserve test data. Remove it manually if needed:
  ```
  rm ~/Documents/donkey.log
  ```
- If you added cron persistence (from earlier suggestions), the uninstaller does not handle it—remove manually with `crontab -e`.

## Testing and Debugging

- **Validate Plist**: `plutil -lint ~/Library/LaunchAgents/com.donkey.*.plist` (replace with actual file name from install output; should output "OK").
- **System Logs**: Use Console.app or `log show --predicate 'subsystem == "com.apple.launchd"' --info --last 10m | grep -i donkey` to check for errors.
- **Manual Test**: Run the script directly, e.g., `python3 ~/donkey.py --recon --beacon` to simulate with options.
- **EDR Testing**: After install, monitor your EDR dashboard for incidents. Features like `--beacon` or `--capture` may trigger alerts for suspicious activity.

If issues arise (e.g., no Python found), the installer will exit with an error message. For custom Python installs (e.g., Homebrew), edit the script to update `$PYTHON_BIN`.

## Contributing

Contributions are welcome! Fork the repo, make changes, and submit a pull request. Focus on keeping additions harmless and ethical.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This tool is for educational and testing purposes only. Do not use on production systems without permission. The author is not responsible for any misuse or unintended consequences.