#!/bin/zsh
# brew_manager.sh - All-in-one Homebrew Auto-update Manager with Keychain integration
# Created: May 11, 2025
# Author: Omar

# Ensure the script is in the ~/bin directory
script_full_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
target_path="$HOME/bin/$(basename "$0")"

# Check if we need to copy the script to ~/bin
if [[ "$script_full_path" != "$target_path" ]]; then
  echo "Moving script to ~/bin directory..."
  mkdir -p "$HOME/bin"
  cp "$script_full_path" "$target_path"
  chmod +x "$target_path"
  echo "Script copied to $target_path"
  echo "Executing from the new location..."
  
  # Execute the script from its new location and pass any arguments
  exec "$target_path" "$@"
  # The exec command replaces the current process, so this line will never be reached
fi

# Make sure we're in a safe directory
cd "$HOME" || exit 1

# Configuration
KEYCHAIN_SERVICE="BrewAutoUpdate"
KEYCHAIN_ACCOUNT="$USER"
UPDATE_INTERVAL=43200  # 12 hours in seconds
RENEWAL_DAYS=90        # Renew configuration every 90 days

# Check if the first argument is "askpass" to provide the keychain password
if [[ "$1" == "askpass" ]]; then
  security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w
  exit $?
fi

# Function to run the actual brew update process
run_brew_update() {
  echo "Starting Homebrew update process at $(date)"
  
  # Export the SUDO_ASKPASS for any sudo calls
  export SUDO_ASKPASS="$(dirname "$0")/$(basename "$0") askpass"
  
  # Run the actual brew commands with error handling
  /opt/homebrew/bin/brew update || echo "Error during brew update"
  /opt/homebrew/bin/brew upgrade --formula || echo "Error during brew formula upgrade"
  /opt/homebrew/bin/brew upgrade --cask || echo "Error during brew cask upgrade"
  /opt/homebrew/bin/brew cleanup || echo "Error during brew cleanup"
  
  echo "Homebrew update completed at $(date)"
}

# Check if the script was called to run update
if [[ "$1" == "run_update" ]]; then
  run_brew_update
  exit $?
fi

# Function to store password in keychain (only needed once)
store_password_in_keychain() {
  echo "This script needs to store your sudo password in the macOS Keychain."
  echo "This is needed only once and will be securely stored."
  
  # Check if password already exists
  if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" &>/dev/null; then
    echo "Password already exists in Keychain."
    return 0
  fi
  
  # Prompt for password
  echo -n "Enter your sudo password: "
  read -s password
  echo
  
  # Verify password works
  if echo "$password" | sudo -S echo "Password verified" &>/dev/null; then
    # Store in keychain
    security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w "$password"
    echo "Password stored securely in Keychain."
    return 0
  else
    echo "Incorrect password. Please try again."
    return 1
  fi
}

# Function to configure sudo for brew
configure_sudo() {
  echo "Configuring sudo permissions for brew..."
  
  # Create temp file
  local tmpfile=$(mktemp)
  echo "$USER ALL=(ALL) NOPASSWD: /opt/homebrew/bin/brew upgrade*, /opt/homebrew/bin/brew cleanup" > "$tmpfile"
  
  # Get password from keychain
  local password=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w)
  
  # Apply sudo config
  echo "$password" | sudo -S cp "$tmpfile" /etc/sudoers.d/homebrew
  echo "$password" | sudo -S chmod 440 /etc/sudoers.d/homebrew
  rm "$tmpfile"
  
  # Set sudo timeout
  local timeout_file=$(mktemp)
  echo "Defaults:$USER timestamp_timeout=7200" > "$timeout_file"
  echo "$password" | sudo -S cp "$timeout_file" /etc/sudoers.d/homebrew_timeout
  echo "$password" | sudo -S chmod 440 /etc/sudoers.d/homebrew_timeout
  rm "$timeout_file"
  
  echo "Sudo configuration complete."
}

# Function to set up brew autoupdate
setup_brew_autoupdate() {
  echo "Setting up brew autoupdate..."
  
  # First delete any existing configuration
  brew autoupdate delete
  
  # Use the hardcoded path to this script to avoid directory issues
  local script_path="$HOME/bin/brew_manager.sh"
  echo "Using script path: $script_path"
  
  # Set up our SUDO_ASKPASS variable for startup
  export SUDO_ASKPASS="$script_path askpass"
  
  # Create a special launchd plist that sets our SUDO_ASKPASS
  local plist_path="$HOME/Library/LaunchAgents/com.omar.homebrew-autoupdate.plist"
  
  # Ensure script_path is correctly set for the plist
  local askpass_path="${script_path} askpass"
  
  cat > "$plist_path" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.omar.homebrew-autoupdate</string>
    <key>ProgramArguments</key>
    <array>
        <string>$script_path</string>
        <string>run_update</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StartInterval</key>
    <integer>$UPDATE_INTERVAL</integer>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/Homebrew/autoupdate.err</string>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/Homebrew/autoupdate.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>SUDO_ASKPASS</key>
        <string>${askpass_path}</string>
    </dict>
    <key>ServiceDescription</key>
    <string>Homebrew Package Auto-Update</string>
    <key>ProcessType</key>
    <string>Standard</string>
</dict>
</plist>
EOL

  # Create logs directory
  mkdir -p "$HOME/Library/Logs/Homebrew"
  
  # Load the plist
  launchctl unload "$plist_path" 2>/dev/null || true
  launchctl load -w "$plist_path"
  
  echo "Custom brew autoupdate configured via launchd."
}

# Function to add script to user profile
add_to_profile() {
  echo "Adding to shell profile..."
  
  # Add SUDO_ASKPASS to .zshrc with absolute path
  local script_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  if ! grep -q "SUDO_ASKPASS=\"$script_path askpass\"" ~/.zshrc; then
    echo "export SUDO_ASKPASS=\"$script_path askpass\"" >> ~/.zshrc
    echo "Added SUDO_ASKPASS to ~/.zshrc"
  fi
}

# Function to schedule renewal
schedule_renewal() {
  echo "Scheduling renewal in $RENEWAL_DAYS days..."
  
  # Path to this script - convert to absolute path
  local script_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  
  # Remove any existing crontab entry for this script
  (crontab -l 2>/dev/null | grep -v "$script_path") | crontab -
  
  # Add new entry to run this script in 90 days
  (crontab -l 2>/dev/null; echo "0 0 $(date -v+${RENEWAL_DAYS}d "+%d %m *") $script_path") | crontab -
  
  echo "Renewal scheduled."
}

# Main function
main() {
  echo "=== Homebrew Auto-update Manager ==="
  echo "Starting setup process..."
  
  # Store password
  store_password_in_keychain || { echo "Failed to store password. Exiting."; exit 1; }
  
  # Configure sudo
  configure_sudo
  
  # Set up brew autoupdate
  setup_brew_autoupdate
  
  # Add to profile
  add_to_profile
  
  # Schedule renewal
  schedule_renewal
  
  echo "=== Setup Complete ==="
  echo "Homebrew will now update automatically every $(($UPDATE_INTERVAL / 3600)) hours."
  echo "This configuration will automatically renew in $RENEWAL_DAYS days."
}

# If not used as askpass, run the main function
[[ "$1" != "askpass" ]] && main
