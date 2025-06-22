#!/bin/bash
# brew_manager.sh - All-in-one Homebrew Auto-update Manager with Keychain integration
# Created: May 11, 2025
# Author: Omar

# Ensure the script is in the ~/bin directory
# Break complex command into separate steps to avoid masking return values
cd "$(dirname "$0")" || exit 1
current_dir=$(pwd)
script_full_path="${current_dir}/$(basename "$0")"
target_path="${HOME}/bin/$(basename "$0")"

# Check if we need to copy the script to ~/bin
if [[ "${script_full_path}" != "${target_path}" ]]; then
  echo "Moving script to ~/bin directory..."
  mkdir -p "${HOME}/bin"
  cp "${script_full_path}" "${target_path}"
  chmod +x "${target_path}"
  echo "Script copied to ${target_path}"
  echo "Executing from the new location..."

  # Execute the script from its new location and pass any arguments
  exec "${target_path}" "$@"
  # The exec command replaces the current process, so this line will never be reached
fi

# Make sure we're in a safe directory
cd "${HOME}" || exit 1

# Configuration
KEYCHAIN_SERVICE="BrewAutoUpdate"
KEYCHAIN_ACCOUNT="${USER}"
UPDATE_INTERVAL=43200  # 12 hours in seconds
RENEWAL_DAYS=90        # Renew configuration every 90 days
GITHUB_REPO="https://github.com/omar391/brew-manager"  # Official repository URL

# Check if the first argument is "askpass" to provide the keychain password
if [[ "${1}" == "askpass" ]]; then
  security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" -w
  exit ${?}
fi

# Function to run the actual brew update process
run_brew_update() {
  echo "Starting Homebrew update process at $(date)"
  
  # Clean up old logs before starting
  cleanup_old_logs
  
  # Export the SUDO_ASKPASS for any sudo calls
  export SUDO_ASKPASS="${HOME}/bin/brew_askpass"
  
  # Run the actual brew commands with error handling
  /opt/homebrew/bin/brew update || echo "Error during brew update"
  /opt/homebrew/bin/brew upgrade --formula || echo "Error during brew formula upgrade"
  /opt/homebrew/bin/brew upgrade --cask || echo "Error during brew cask upgrade"
  /opt/homebrew/bin/brew cleanup || echo "Error during brew cleanup"
  
  echo "Homebrew update completed at $(date)"
}

# Function to clean up old log files
cleanup_old_logs() {
  echo "Cleaning up old log files..."
  
  local log_dir="${HOME}/Library/Logs/Homebrew"
  local max_log_size_mb=50  # Maximum size per log file in MB
  local max_log_age_days=30 # Keep logs for 30 days
  local max_rotated_logs=5  # Keep this many rotated log files
  
  # Check if log directory exists
  if [[ ! -d "${log_dir}" ]]; then
    echo "Log directory not found: ${log_dir}"
    return 0
  fi
  
  # Function to rotate a log file
  rotate_log_file() {
    local log_file="$1"
    local base_name
    base_name=$(basename "${log_file}")
    
    if [[ ! -f "${log_file}" ]]; then
      return 0
    fi
    
    # Get file size in MB
    local file_size_mb
    file_size_mb=$(stat -f%z "${log_file}" 2>/dev/null | awk '{print int($1/1024/1024)}')
    
    if [[ ${file_size_mb} -gt ${max_log_size_mb} ]]; then
      echo "Rotating large log file: ${log_file} (${file_size_mb}MB)"
      
      # Rotate existing numbered logs
      for ((i=max_rotated_logs-1; i>=1; i--)); do
        if [[ -f "${log_file}.${i}" ]]; then
          mv "${log_file}.${i}" "${log_file}.$((i+1))"
        fi
      done
      
      # Move current log to .1
      mv "${log_file}" "${log_file}.1"
      
      # Create new empty log file
      touch "${log_file}"
      
      # Remove old rotated logs beyond the limit
      for ((i=max_rotated_logs+1; i<=10; i++)); do
        [[ -f "${log_file}.${i}" ]] && rm -f "${log_file}.${i}"
      done
      
      echo "Log file rotated successfully"
    fi
  }
  
  # Rotate log files if they're too large
  rotate_log_file "${log_dir}/autoupdate.log"
  rotate_log_file "${log_dir}/autoupdate.err"
  
  # Clean up old rotated log files by age
  find "${log_dir}" -name "autoupdate.log.*" -mtime +${max_log_age_days} -delete 2>/dev/null || true
  find "${log_dir}" -name "autoupdate.err.*" -mtime +${max_log_age_days} -delete 2>/dev/null || true
  
  # Display current log file sizes
  for log_file in "${log_dir}/autoupdate.log" "${log_dir}/autoupdate.err"; do
    if [[ -f "${log_file}" ]]; then
      local size_kb
      size_kb=$(stat -f%z "${log_file}" 2>/dev/null | awk '{print int($1/1024)}')
      echo "Current log size: $(basename "${log_file}") - ${size_kb}KB"
    fi
  done
  
  echo "Log cleanup completed"
}

# Check if the script was called to run update
if [[ "${1}" == "run_update" ]]; then
  run_brew_update
  exit ${?}
fi

# Check if the script was called to clean logs
if [[ "${1}" == "clean_logs" ]]; then
  cleanup_old_logs
  exit ${?}
fi

# Check if the script was called with help
if [[ "${1}" == "help" ]] || [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
  echo "=== Homebrew Auto-update Manager - Help ==="
  echo
  echo "Usage: $0 [COMMAND]"
  echo
  echo "Commands:"
  echo "  (no args)    - Install/setup auto-update system"
  echo "  run_update   - Manually run brew update process"
  echo "  clean_logs   - Clean up and rotate old log files"
  echo "  help         - Show this help message"
  echo
  echo "Log Management:"
  echo "  📁 Location: ~/Library/Logs/Homebrew/"
  echo "  🔄 Auto-rotation: Files >50MB"
  echo "  📊 Retention: 5 rotated files, 30 days max age"
  echo
  echo "Configuration:"
  echo "  🕐 Update interval: $((UPDATE_INTERVAL / 3600)) hours"
  echo "  🔄 Auto-renewal: Every ${RENEWAL_DAYS} days"
  echo "  📂 Installation: ~/bin/brew_manager.sh"
  echo
  echo "Uninstall:"
  echo "  Run './uninstall.sh' to completely remove all components"
  exit 0
fi

# Function to store password in keychain (only needed once)
store_password_in_keychain() {
  echo "This script needs to store your sudo password in the macOS Keychain."
  echo "This is needed only once and will be securely stored."
  
  # Check if password already exists
  if security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" &>/dev/null; then
    echo "Password already exists in Keychain."
    return 0
  fi
  
  # Function to get and verify password
  get_and_verify_password() {
    local password
    local attempts=0
    local max_attempts=3
    
    while [[ $attempts -lt $max_attempts ]]; do
      # Clear any existing sudo timestamp to ensure fresh authentication
      sudo -k 2>/dev/null || true
      
      echo -n "Enter your sudo password: "
      read -rs password
      echo
      
      # Verify password works with a timeout and proper error handling
      if timeout 10 bash -c "echo '$password' | sudo -S -v" &>/dev/null; then
        # Store in keychain
        if security add-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" -w "${password}" 2>/dev/null; then
          echo "Password stored securely in Keychain."
          return 0
        else
          echo "Error: Failed to store password in Keychain."
          return 1
        fi
      else
        attempts=$((attempts + 1))
        if [[ $attempts -lt $max_attempts ]]; then
          echo "Incorrect password. Please try again. (Attempt $attempts/$max_attempts)"
        else
          echo "Too many failed attempts. Please run the script again."
          return 1
        fi
      fi
    done
    
    return 1
  }
  
  # Call the verification function
  get_and_verify_password
}

# Function to configure sudo for brew
configure_sudo() {
  echo "Configuring sudo permissions for brew..."
  
  # Create temp file
  local tmpfile
  tmpfile=$(mktemp)
  echo "${USER} ALL=(ALL) NOPASSWD: /opt/homebrew/bin/brew upgrade*, /opt/homebrew/bin/brew cleanup" > "${tmpfile}"
  
  # Get password from keychain with error handling
  local password
  if ! password=$(security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" -w 2>/dev/null); then
    echo "Error: Could not retrieve password from keychain."
    rm "${tmpfile}"
    return 1
  fi
  
  # Verify password works before proceeding
  if ! echo "${password}" | sudo -S -v &>/dev/null; then
    echo "Error: Stored password is no longer valid. Please re-run setup."
    security delete-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" 2>/dev/null || true
    rm "${tmpfile}"
    return 1
  fi
  
  # Apply sudo config
  if ! echo "${password}" | sudo -S cp "${tmpfile}" /etc/sudoers.d/homebrew; then
    echo "Error: Failed to apply sudo configuration."
    rm "${tmpfile}"
    return 1
  fi
  
  if ! echo "${password}" | sudo -S chmod 440 /etc/sudoers.d/homebrew; then
    echo "Error: Failed to set sudo configuration permissions."
    rm "${tmpfile}"
    return 1
  fi
  
  rm "${tmpfile}"
  
  # Set sudo timeout
  local timeout_file
  timeout_file=$(mktemp)
  echo "Defaults:${USER} timestamp_timeout=7200" > "${timeout_file}"
  
  if ! echo "${password}" | sudo -S cp "${timeout_file}" /etc/sudoers.d/homebrew_timeout; then
    echo "Error: Failed to apply sudo timeout configuration."
    rm "${timeout_file}"
    return 1
  fi
  
  if ! echo "${password}" | sudo -S chmod 440 /etc/sudoers.d/homebrew_timeout; then
    echo "Error: Failed to set sudo timeout configuration permissions."
    rm "${timeout_file}"
    return 1
  fi
  
  rm "${timeout_file}"
  
  echo "Sudo configuration complete."
}

# Function to set up brew autoupdate
setup_brew_autoupdate() {
  echo "Setting up brew autoupdate..."
  
  # First delete any existing configuration
  brew autoupdate delete
  
  # Use the hardcoded path to this script to avoid directory issues
  local script_path="${HOME}/bin/brew_manager.sh"
  echo "Using script path: ${script_path}"
  
  # Create askpass wrapper script
  local askpass_wrapper="${HOME}/bin/brew_askpass"
  cat > "${askpass_wrapper}" << ASKPASS_EOF
#!/bin/bash
# Simple askpass wrapper for brew_manager.sh
${script_path} askpass
ASKPASS_EOF
  chmod +x "${askpass_wrapper}"

  # Set up our SUDO_ASKPASS variable for startup
  export SUDO_ASKPASS="${askpass_wrapper}"
  
  # Create a special launchd plist that sets our SUDO_ASKPASS
  local plist_path="${HOME}/Library/LaunchAgents/com.omar.homebrew-autoupdate.plist"
  
  cat > "${plist_path}" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.omar.homebrew-autoupdate</string>
    <key>ProgramArguments</key>
    <array>
        <string>${script_path}</string>
        <string>run_update</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StartInterval</key>
    <integer>${UPDATE_INTERVAL}</integer>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/Homebrew/autoupdate.err</string>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/Homebrew/autoupdate.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>SUDO_ASKPASS</key>
        <string>${askpass_wrapper}</string>
    </dict>
    <key>ServiceDescription</key>
    <string>Homebrew Package Auto-Update</string>
    <key>ProcessType</key>
    <string>Standard</string>
</dict>
</plist>
EOL

  # Create logs directory
  mkdir -p "${HOME}/Library/Logs/Homebrew"
  
  # Load the plist
  launchctl unload "${plist_path}" 2>/dev/null || true
  launchctl load -w "${plist_path}"
  
  echo "Custom brew autoupdate configured via launchd."
}

# Function to add script to user profile
add_to_profile() {
  echo "Adding to shell profile..."
  
  # Add SUDO_ASKPASS to .zshrc with wrapper script path
  local askpass_wrapper="${HOME}/bin/brew_askpass"
  if ! grep -q "SUDO_ASKPASS=\"${askpass_wrapper}\"" ~/.zshrc; then
    echo "export SUDO_ASKPASS=\"${askpass_wrapper}\"" >> ~/.zshrc
    echo "Added SUDO_ASKPASS to ~/.zshrc"
  fi
}

# Function to schedule renewal
schedule_renewal() {
  echo "Scheduling renewal in ${RENEWAL_DAYS} days..."
  
  # Path to this script - convert to absolute path
  local script_path
  # Split command to avoid masking return values
  cd "$(dirname "$0")" || exit 1
  local current_dir
  current_dir=$(pwd)
  script_path="${current_dir}/$(basename "$0")"
  
  # Remove any existing crontab entry for this script
  crontab -l 2>/dev/null | grep -v "${script_path}" | crontab -
  
  # Create a renewal script that will pull the latest version from GitHub
  local renewal_script="${HOME}/bin/brew_manager_renewal.sh"
  cat > "${renewal_script}" << EOL
#!/bin/bash
# Renewal script for brew_manager.sh
# This script pulls the latest version from GitHub and updates the local copy

# Target directory and file
BIN_DIR="\${HOME}/bin"
SCRIPT_NAME="brew_manager.sh"
TARGET_PATH="\${BIN_DIR}/\${SCRIPT_NAME}"

# GitHub repository URL
REPO_URL="${GITHUB_REPO}"

# Create a temporary directory
TEMP_DIR=\$(mktemp -d)
cd "\${TEMP_DIR}" || exit 1

# Clone the repository
echo "Pulling latest version from \${REPO_URL}..."
git clone "\${REPO_URL}" ./brew-manager
if [[ \$? -ne 0 ]]; then
  echo "Failed to clone repository. Using existing script."
  rm -rf "\${TEMP_DIR}"
  "\${TARGET_PATH}"
  exit 1
fi

# Copy the updated script
echo "Updating brew_manager script..."
mkdir -p "\${BIN_DIR}"
cp ./brew-manager/brew_manager.sh "\${TARGET_PATH}"
chmod +x "\${TARGET_PATH}"

# Clean up
rm -rf "\${TEMP_DIR}"

# Run the updated script
echo "Running updated script..."
"\${TARGET_PATH}"
EOL
  
  # Make the renewal script executable
  chmod +x "${renewal_script}"
  
  # Add new entry to run the renewal script in specified days
  # Split command to avoid masking return values
  local renewal_date
  renewal_date=$(date -v+${RENEWAL_DAYS}d "+%d %m *")
  (crontab -l 2>/dev/null; echo "0 0 ${renewal_date} ${renewal_script}") | crontab -
  
  echo "Renewal scheduled with auto-update from GitHub repository."
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
  echo "Homebrew will now update automatically every $((UPDATE_INTERVAL / 3600)) hours."
  echo "This configuration will automatically renew in ${RENEWAL_DAYS} days."
  echo "During renewal, the latest version will be pulled from ${GITHUB_REPO}"
  echo
  echo "Log Management:"
  echo "  📁 Logs location: ~/Library/Logs/Homebrew/"
  echo "  🔄 Automatic cleanup: Files >50MB will be rotated"
  echo "  🗑️  Manual cleanup: Run '~/bin/brew_manager.sh clean_logs'"
  echo "  📊 Log retention: 5 rotated files, 30 days max age"
}

# If not used as askpass, run the main function
[[ "${1}" != "askpass" ]] && main
