# Homebrew Auto-update Manager

A comprehensive, production-ready solution to automate Homebrew updates on macOS with enterprise-grade security and reliability.

![Homebrew Logo](https://brew.sh/assets/img/homebrew-256x256.png)

## Features

- **🔒 Secure Password Management**: Uses macOS Keychain with robust multi-attempt verification and timeout protection
- **🚀 Automated Updates**: Configures Homebrew to update formulae and casks automatically every 12 hours
- **🔄 Self-renewal**: Maintains its own configuration with periodic renewal and updates from the main repository (90 days)
- **📊 Advanced Log Management**: Automatic log rotation, cleanup, and retention policies
- **🛡️ Enterprise Security**: SUDO_ASKPASS integration with minimal privilege escalation
- **🧹 Complete Uninstall**: Professional uninstall script that removes all traces
- **💬 User-friendly**: Comprehensive help system, clear feedback, and intuitive commands
- **⚙️ Smart Integration**: Works seamlessly with macOS launchd agents

## Installation

Simply download and run the script:

```bash
# Clone the repository
git clone https://github.com/omar391/brew-manager.git
cd brew-manager

# Make the script executable
chmod +x brew_manager.sh

# Run the script
./brew_manager.sh
```

The script will:
1. Copy itself to your `~/bin` directory
2. Prompt for your sudo password (stored securely in macOS Keychain with verification)
3. Configure necessary sudo permissions with minimal privilege escalation
4. Set up a launchd agent for automatic updates (12-hour intervals)
5. Add necessary environment variables to your shell profile (.zshrc)
6. Schedule self-renewal (90-day GitHub updates)
7. Configure comprehensive log management

## Usage

Once installed, the script provides several commands:

```bash
# Get help and see all available commands
~/bin/brew_manager.sh help

# Manually run a brew update
~/bin/brew_manager.sh run_update

# Clean up and rotate log files
~/bin/brew_manager.sh clean_logs

# Reinstall/reconfigure (no arguments)
~/bin/brew_manager.sh
```

## Uninstallation

To completely remove all components:

```bash
# Run the uninstall script
./uninstall.sh
```

The uninstaller will remove:
- All scripts from `~/bin`
- launchd service and plist
- Log directories and files
- Cron job entries
- Keychain password entries
- sudo configuration files
- Shell profile entries (.zshrc)

## How It Works

### 🔒 Security First Approach

This script uses macOS Keychain to securely store your sudo password with enterprise-grade security:
- **Multi-attempt verification**: Up to 3 attempts with timeout protection
- **Password validation**: Verifies credentials work before storing
- **Automatic cleanup**: Removes invalid passwords automatically
- **SUDO_ASKPASS integration**: Secure automated sudo operations
- **Minimal privileges**: Only grants NOPASSWD for specific brew commands
- **Keychain protection**: Leverages macOS security infrastructure

### 🚀 Automatic Updates

By default, Homebrew will be updated every 12 hours via launchd. The update process includes:
- Updating Homebrew itself (`brew update`)
- Upgrading installed formulae (`brew upgrade --formula`)
- Upgrading installed casks (`brew upgrade --cask`)
- Cleaning up outdated versions (`brew cleanup`)
- Automatic log rotation and cleanup

### 📊 Log Management

Comprehensive logging with intelligent management:
- **Location**: `~/Library/Logs/Homebrew/`
- **Auto-rotation**: Files >50MB are automatically rotated
- **Retention**: Keeps 5 rotated files, 30 days maximum age
- **Manual cleanup**: Available via `clean_logs` command
- **Size monitoring**: Displays current log file sizes

### 🔄 Configuration Renewal

To ensure continued proper function, the script schedules its own renewal every 90 days:
- Pulls the latest version from the [official repository](https://github.com/omar391/brew-manager)
- Updates configurations to incorporate improvements
- Resets the renewal timer for another 90 days
- Maintains compatibility with system changes

## Customization

You can modify these variables in the script to adjust settings:

```bash
UPDATE_INTERVAL=43200  # Update interval in seconds (default: 12 hours)
RENEWAL_DAYS=90        # Self-renewal period in days
KEYCHAIN_SERVICE="BrewAutoUpdate"  # Keychain service name
GITHUB_REPO="https://github.com/omar391/brew-manager"  # Repository URL
```

### Log Management Settings

```bash
max_log_size_mb=50     # Maximum size per log file in MB
max_log_age_days=30    # Keep logs for 30 days
max_rotated_logs=5     # Keep this many rotated log files
```

## File Locations

After installation, the following files are created:

**Scripts:**
- `~/bin/brew_manager.sh` - Main script
- `~/bin/brew_askpass` - SUDO_ASKPASS wrapper
- `~/bin/brew_manager_renewal.sh` - Auto-renewal script

**Configuration:**
- `~/Library/LaunchAgents/com.omar.homebrew-autoupdate.plist` - launchd service
- `/etc/sudoers.d/homebrew` - sudo permissions
- `/etc/sudoers.d/homebrew_timeout` - sudo timeout settings

**Logs:**
- `~/Library/Logs/Homebrew/autoupdate.log` - Standard output
- `~/Library/Logs/Homebrew/autoupdate.err` - Error output
- `~/Library/Logs/Homebrew/autoupdate.log.*` - Rotated logs

**Security:**
- macOS Keychain entry: Service "BrewAutoUpdate", Account: your username

## Requirements

- macOS 10.14 or later
- Homebrew installed ([brew.sh](https://brew.sh))
- Admin privileges (for initial setup only)
- Bash shell (zsh supported)
- `timeout` command (included with macOS)

## Troubleshooting

### Common Issues

**Password prompt keeps retrying:**
- Fixed in latest version with timeout protection
- Clear any existing sudo timestamps: `sudo -k`

**SUDO_ASKPASS not working:**
- Restart your terminal or run: `source ~/.zshrc`
- Check if `~/bin/brew_askpass` exists and is executable

**launchd service not running:**
- Check service status: `launchctl list | grep homebrew`
- Reload service: `launchctl unload ~/Library/LaunchAgents/com.omar.homebrew-autoupdate.plist && launchctl load -w ~/Library/LaunchAgents/com.omar.homebrew-autoupdate.plist`

**Logs not rotating:**
- Run manual cleanup: `~/bin/brew_manager.sh clean_logs`
- Check log directory permissions: `ls -la ~/Library/Logs/Homebrew/`

### Getting Help

```bash
# Show help and all available commands
~/bin/brew_manager.sh help

# Check current setup
launchctl list | grep homebrew
crontab -l | grep brew
ls -la ~/bin/brew*
```

## Testing

The project includes a comprehensive test suite to verify functionality:

```bash
# Run all tests
./run_tests.sh

# Or run individual test components
./test/test_brew_manager.sh    # Unit tests
./test/test_github_update.sh   # GitHub update functionality test
./test/functional_test.sh      # End-to-end functional test
```

These tests ensure that:
- **Password Management**: Keychain storage, verification, and timeout handling
- **Security**: SUDO_ASKPASS integration and sudo permissions
- **Automation**: launchd service setup and configuration
- **Log Management**: Rotation, cleanup, and retention policies
- **Self-renewal**: GitHub repository updates and cron scheduling
- **Uninstall**: Complete removal of all components

The tests use mock commands to simulate system interactions without making actual changes to your system.

## Performance & Resource Usage

- **Memory footprint**: Minimal (~2MB during execution)
- **CPU usage**: Low impact, only during scheduled updates
- **Disk space**: Log files managed automatically with rotation
- **Network**: Only during updates and 90-day renewals
- **Battery impact**: Negligible on laptops

## Security Considerations

- **Password storage**: Encrypted in macOS Keychain
- **Privilege escalation**: Minimal, only for specific brew commands
- **Network security**: HTTPS GitHub connections only
- **File permissions**: Proper 440 permissions on sudo files
- **Access control**: User-specific configurations
- **Audit trail**: Comprehensive logging of all operations

## Changelog

### Latest Version
- ✅ Fixed password prompt retry issues with timeout protection
- ✅ Enhanced error handling and validation
- ✅ Added comprehensive log management with rotation
- ✅ Implemented complete uninstall functionality
- ✅ Added help system and user guidance
- ✅ Improved SUDO_ASKPASS integration
- ✅ Enhanced security with password verification

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Acknowledgements

- [Homebrew](https://brew.sh/) - The amazing package manager for macOS
