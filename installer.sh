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

# This Python script creates a timestamp log every 60 seconds (added newline for better logging)
cat > ~/donkey.py <<EOL
from os.path import expanduser
from datetime import datetime
home = expanduser('~')
log_file = open(home+'/Documents/donkey.log','a')
log_file.write(str(datetime.now()) + '\\n')
log_file.close()
EOL

# This plist file executes the Python script every 60 seconds using the detected Python
# Note: $HOME in the script path below will be expanded by the shell to the absolute path before writing the plist
cat > ~/Library/LaunchAgents/com.kristovatlas.donkey.plist <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.kristovatlas.donkey</string>

  <key>ProgramArguments</key>
  <array>
    <string>$PYTHON_BIN</string>
    <string>$HOME/donkey.py</string>
  </array>

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
chmod 644 ~/Library/LaunchAgents/com.kristovatlas.donkey.plist

# Unload and load based on macOS version (use bootstrap/bootout on macOS 11+ for better compatibility with modern systems like Sequoia)
if [[ $major -ge 11 ]]; then
  DOMAIN="gui/$(id -u)"
  launchctl bootout $DOMAIN/com.kristovatlas.donkey || true  # Ignore errors if not loaded
  launchctl bootstrap $DOMAIN $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist
else
  launchctl unload $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist || true
  launchctl load $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist
fi
