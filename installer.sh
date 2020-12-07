launchctl unload $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist

#This Python script creates a timestamp log every 60 seconds
cat > ~/donkey.py <<EOL
from os.path import expanduser
from datetime import datetime
home = expanduser('~')
log_file = open(home+'/Documents/donkey.log','a')
log_file.write(str(datetime.now()))
log_file.close()
EOL

#This plist file executes the Python script every 60 seconds
cat > ~/Library/LaunchAgents/com.kristovatlas.donkey.plist <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.kristovatlas.donkey</string>

  <key>Program</key>
    <string>/usr/bin/python</string>

  <key>StartInterval</key>
  <integer>60</integer>

  <key>RunAtLoad</key>
  <true/>

</dict>
</plist>
EOL

#Need to edit the plist file after the fact to inject $HOME into its contents so it can run on any MacOS machine
defaults write "$HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist" ProgramArguments -array /usr/bin/python "$HOME/donkey.py"

launchctl load $HOME/Library/LaunchAgents/com.kristovatlas.donkey.plist
