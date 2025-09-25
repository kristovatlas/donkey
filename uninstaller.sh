# Get macOS version
ver=$(sw_vers -productVersion)
major=${ver%%.*}

# Unload the agent based on macOS version
if [[ $major -ge 11 ]]; then
  DOMAIN="gui/$(id -u)"
  launchctl bootout $DOMAIN/com.kristovatlas.donkey || true  # Ignore errors if not loaded
else
  launchctl unload $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist || true
fi

# Remove the plist file
rm -f $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist

# Remove the Python script
rm -f $HOME/donkey.py

# Optionally remove the log file (uncomment if desired, or run manually)
# rm -f $HOME/Documents/donkey.log

# Remove debug output files if they exist
rm -f /tmp/donkey.out /tmp/donkey.err
