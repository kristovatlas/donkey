# Parse command-line arguments for features
FEATURES=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --recon|--beacon|--capture|--portscan|--wifi|--lanarp|--browser|--keychain|--clipboard|--download|--zshenv|--ransom)
      FEATURES+=("$1")
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: bash installer.sh [--recon] [--beacon] [--capture] [--portscan] [--wifi] [--lanarp] [--browser] [--keychain] [--clipboard] [--download] [--zshenv] [--ransom]"
      exit 1
      ;;
  esac
done

# Get macOS version
ver=$(sw_vers -productVersion)
major=${ver%%.*}

# Detect the appropriate system Python interpreter: prefer python3 if available (newer macOS), fall back to python (older macOS)
if [ -x /usr/bin/python3 ]; then
  PYTHON_BIN="/usr/bin/python3"
elif [ -x /usr/bin/python ]; then
  PYTHON_BIN="/usr/bin/python"
else
  echo "No system Python found (neither /usr/bin/python3 nor /usr/bin/python is available). Please install Python via Command Line Tools or Homebrew."
  exit 1
fi

# Generate a randomized UUID for the plist label (lowercase, no hyphens)
uuid=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
label="com.donkey.$uuid"
plist_path="$HOME/Library/LaunchAgents/$label.plist"

# Check if donkey is installed (check for /tmp/donkey_label if exists) and uninstall if so
if [ -f "/tmp/donkey_label" ]; then
  old_label=$(cat /tmp/donkey_label)
  old_plist="$HOME/Library/LaunchAgents/$old_label.plist"
  # Unload the agent based on macOS version
  if [[ $major -ge 11 ]]; then
    DOMAIN="gui/$(id -u)"
    launchctl bootout $DOMAIN/$old_label || true  # Ignore errors if not loaded
  else
    launchctl unload $old_plist || true
  fi

  # Remove the plist and Python script (preserve log and any screenshots/downloads)
  rm -f $old_plist
  rm -f $HOME/donkey.py

  # Remove debug output files if they exist
  rm -f /tmp/donkey.out /tmp/donkey.err

  # Clean up zshenv if modified (harmless if not)
  sed -i '' '/Donkey test/d' ~/.zshenv 2>/dev/null || true

  # Remove temporary label file
  rm -f /tmp/donkey_label
fi

# Generate the static Python script with all features (conditional on sys.argv)
cat > ~/donkey.py <<EOL
import sys
import subprocess
import urllib.request
import socket
import ipaddress
import sqlite3
import os
from os.path import expanduser
from datetime import datetime

home = expanduser('~')

# Always append timestamp to log
with open(home + '/Documents/donkey.log', 'a') as log_file:
    log_file.write(str(datetime.now()) + '\\n')

# System reconnaissance (if --recon flag)
if '--recon' in sys.argv:
    try:
        user = subprocess.check_output(['whoami']).decode('utf-8').strip()
        processes = subprocess.check_output(['ps', '-ef']).decode('utf-8').splitlines()
        process_count = len(processes) - 1  # Exclude header
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - User: {user}, Process count: {process_count}\\n")
    except Exception as e:
        pass  # Silently ignore errors

# Harmless network beacon (if --beacon flag)
if '--beacon' in sys.argv:
    try:
        response = urllib.request.urlopen('https://httpbin.org/get')
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Beacon response: {response.status}\\n")
    except Exception as e:
        pass

# Local screen capture (if --capture flag)
if '--capture' in sys.argv:
    try:
        subprocess.call(['screencapture', '-x', home + '/Documents/donkey_screenshot.png'])
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Screenshot saved locally\\n")
    except Exception as e:
        pass

# Local network port scan (if --portscan flag)
if '--portscan' in sys.argv:
    try:
        # Get local IP by connecting to an external server (doesn't send data)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()

        # Assume /24 subnet (common for home networks)
        subnet = '.'.join(local_ip.split('.')[:3]) + '.0/24'
        ports = [22, 80, 443, 445, 3389]  # Common ports: SSH, HTTP, HTTPS, SMB, RDP
        open_ports = []

        # Limit to first 10 hosts to avoid long execution time
        for host in list(ipaddress.IPv4Network(subnet).hosts())[:10]:
            for port in ports:
                scan_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                scan_sock.settimeout(0.5)
                if scan_sock.connect_ex((str(host), port)) == 0:
                    open_ports.append(f"{host}:{port}")
                scan_sock.close()

        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Open ports found: {', '.join(open_ports) or 'None'}\\n")
    except Exception as e:
        pass

# WiFi enumeration (if --wifi flag)
if '--wifi' in sys.argv:
    try:
        wifi_list = subprocess.check_output(['/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', '-s']).decode('utf-8').splitlines()
        ssids = [line.split()[0] for line in wifi_list[1:5]]  # Limit to first few
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Nearby WiFi: {', '.join(ssids) or 'None'}\\n")
    except Exception as e:
        pass

# LAN device ARP scan (if --lanarp flag)
if '--lanarp' in sys.argv:
    try:
        arp_output = subprocess.check_output(['arp', '-a']).decode('utf-8').splitlines()
        devices = [line.split()[1].strip('()') for line in arp_output[:5]]  # Limit to first few
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - LAN devices (ARP): {', '.join(devices) or 'None'}\\n")
    except Exception as e:
        pass

# Browser history query (if --browser flag)
if '--browser' in sys.argv:
    try:
        history_db = home + '/Library/Safari/History.db'
        conn = sqlite3.connect(history_db)
        cursor = conn.cursor()
        cursor.execute("SELECT url FROM history_items ORDER BY visit_time DESC LIMIT 5")
        urls = [row[0] for row in cursor.fetchall()]
        conn.close()
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Recent browser URLs: {', '.join(urls) or 'None'}\\n")
    except Exception as e:
        pass

# Keychain listing (if --keychain flag)
if '--keychain' in sys.argv:
    try:
        keychains = subprocess.check_output(['security', 'list-keychains']).decode('utf-8').splitlines()
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Keychains: {', '.join(keychains[:3]) or 'None'}\\n")  # Limit
    except Exception as e:
        pass

# Clipboard monitoring (if --clipboard flag) - access but do not log contents
if '--clipboard' in sys.argv:
    try:
        _ = subprocess.check_output(['pbpaste'])  # Access clipboard without using/logging content
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Clipboard accessed\\n")
    except Exception as e:
        pass

# Harmless download (if --download flag)
if '--download' in sys.argv:
    try:
        url = 'https://httpbin.org/anything'  # Public test endpoint
        data = urllib.request.urlopen(url).read().decode('utf-8')[:100]  # Truncate for brevity
        download_path = home + '/Documents/donkey_download.txt'
        with open(download_path, 'w') as f:
            f.write(data)
        with open(home + '/Documents/donkey.log', 'a') as log_file:
            log_file.write(f"{datetime.now()} - Harmless file downloaded to {download_path}\\n")
    except Exception as e:
        pass

# Ransomware simulation (if --ransom flag) - create and encrypt dummy files only once
if '--ransom' in sys.argv:
    try:
        done_flag = home + '/.donkey_ransom_done'
        if not os.path.exists(done_flag):
            # Create dummy files
            dummies = [home + '/donkey_dummy1.txt', home + '/donkey_dummy2.txt', home + '/donkey_dummy3.txt']
            for dummy in dummies:
                with open(dummy, 'w') as f:
                    f.write('This is harmless dummy data for testing.\\n')

            # Static key for XOR encryption
            key = b'donkeykey'

            # Encrypt each dummy
            for dummy in dummies:
                with open(dummy, 'rb') as f:
                    data = f.read()
                encrypted = bytes(b ^ key[i % len(key)] for i, b in enumerate(data))
                enc_path = dummy + '.enc'
                with open(enc_path, 'wb') as f:
                    f.write(encrypted)
                os.remove(dummy)  # Remove original to simulate

            # Log and set done flag
            with open(home + '/Documents/donkey.log', 'a') as log_file:
                log_file.write(f"{datetime.now()} - Dummy files encrypted (simulation; key: donkeykey for XOR decryption if needed)\\n")
            open(done_flag, 'w').close()
    except Exception as e:
        pass
EOL

# If --zshenv flag, append benign line to ~/.zshenv
if [[ " ${FEATURES[*]} " =~ " --zshenv " ]]; then
  echo 'echo "Donkey test" > /dev/null' >> ~/.zshenv
fi

# Build the ProgramArguments section dynamically based on selected features
PROGRAM_ARGS="  <key>ProgramArguments</key>
  <array>
    <string>$PYTHON_BIN</string>
    <string>$HOME/donkey.py</string>"
for feat in "${FEATURES[@]}"; do
  PROGRAM_ARGS="$PROGRAM_ARGS
    <string>$feat</string>"
done
PROGRAM_ARGS="$PROGRAM_ARGS
  </array>"

# This plist file executes the Python script every 60 seconds using the detected Python
cat > $plist_path <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>

$PROGRAM_ARGS

  <key>StartInterval</key>
  <integer>60</integer>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/tmp/donkey.out</string>

  <key>StandardErrorPath</key>
  <string>/tmp/donkey.err</string>

</dict>
</plist>
EOL

# Ensure proper permissions
chmod 644 $plist_path

# Save the label for uninstall
echo "$label" > /tmp/donkey_label

# Load based on macOS version (use bootstrap on macOS 11+)
if [[ $major -ge 11 ]]; then
  DOMAIN="gui/$(id -u)"
  launchctl bootstrap $DOMAIN $plist_path
else
  launchctl load $plist_path
fi

echo "Installed with randomized label: $label"
