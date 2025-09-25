# Get macOS version
ver=$(sw_vers -productVersion)
major=${ver%%.*}

# Retrieve the label from temp file if exists
if [ -f "/tmp/donkey_label" ]; then
  label=$(cat /tmp/donkey_label)
  plist_path="$HOME/Library/LaunchAgents/$label.plist"

  # Unload the agent based on macOS version
  if [[ $major -ge 11 ]]; then
    DOMAIN="gui/$(id -u)"
    launchctl bootout $DOMAIN/$label || true  # Ignore errors if not loaded
  else
    launchctl unload $plist_path || true
  fi

  # Remove the plist file
  rm -f $plist_path

  # Remove the Python script
  rm -f $HOME/donkey.py

  # Optionally remove the log file (uncomment if desired, or run manually)
  # rm -f $HOME/Documents/donkey.log

  # Remove debug output files if they exist
  rm -f /tmp/donkey.out /tmp/donkey.err

  # Clean up zshenv (remove the test line if present)
  sed -i '' '/Donkey test/d' ~/.zshenv 2>/dev/null || true

  # Remove download file if exists
  rm -f $HOME/Documents/donkey_download.txt

  # Remove screenshot if exists (from --capture)
  rm -f $HOME/Documents/donkey_screenshot.png

  # Remove ransomware simulation files if exist (dummies, enc, done flag)
  rm -f $HOME/donkey_dummy*.txt $HOME/donkey_dummy*.txt.enc $HOME/.donkey_ransom_done

  # Remove temporary label file
  rm -f /tmp/donkey_label
else
  echo "No existing installation found (missing /tmp/donkey_label)."
fi
