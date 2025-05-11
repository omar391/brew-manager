# Homebrew Auto-update Manager

A comprehensive solution to automate Homebrew updates on macOS with security in mind.

![Homebrew Logo](https://brew.sh/assets/img/homebrew-256x256.png)

## Features

- **Secure Password Management**: Uses macOS Keychain to securely store sudo credentials
- **Automated Updates**: Configures Homebrew to update formulae and casks automatically
- **Self-renewal**: Maintains its own configuration with periodic renewal and updates from the main repository
- **Smart Integration**: Works seamlessly with macOS launch agents
- **User-friendly**: Simple one-time setup process

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
2. Prompt for your sudo password (stored securely in macOS Keychain)
3. Configure necessary sudo permissions
4. Set up a launchd agent for automatic updates
5. Add necessary environment variables to your shell profile
6. Schedule self-renewal

## How It Works

### Security First Approach

This script uses macOS Keychain to securely store your sudo password, which is required for Homebrew operations. The password is:
- Never stored in plain text
- Protected by macOS Keychain security
- Only accessible by the script during update operations

### Automatic Updates

By default, Homebrew will be updated every 12 hours. The update process includes:
- Updating Homebrew itself
- Upgrading installed formulae
- Upgrading installed casks
- Cleaning up outdated versions

### Configuration Renewal

To ensure continued proper function, the script schedules its own renewal every 90 days. During renewal, it will:
- Pull the latest version from the [official repository](https://github.com/omar391/brew-manager)
- Update its configurations to incorporate any improvements
- Reset the renewal timer for another 90 days

This maintains fresh configurations and adapts to any system changes or updates to the tool itself.

## Customization

You can modify these variables in the script to adjust settings:

```bash
UPDATE_INTERVAL=43200  # Update interval in seconds (default: 12 hours)
RENEWAL_DAYS=90        # Self-renewal period in days
```

## Logs

Logs for the automatic updates are stored in:
- `~/Library/Logs/Homebrew/autoupdate.log` - Standard output
- `~/Library/Logs/Homebrew/autoupdate.err` - Error output

## Requirements

- macOS 10.14 or later
- Homebrew installed (https://brew.sh)
- Admin privileges (for initial setup only)

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
- Password storage in Keychain works correctly
- Sudo permissions are properly configured
- Brew autoupdate setup functions as expected  
- GitHub repository updates are fetched correctly
- Crontab renewal entries are created properly

The tests use mock commands to simulate system interactions without making actual changes to your system.

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
