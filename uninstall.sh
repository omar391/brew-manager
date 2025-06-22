#!/bin/bash
# uninstall.sh - Complete uninstall script for brew_manager.sh
# This script removes all components installed by brew_manager.sh
# Created: June 22, 2025
# Author: Omar

echo "=== Homebrew Auto-update Manager - UNINSTALL ==="
echo "This will completely remove all brew_manager components from your system."
echo

# Ask for confirmation
read -p "Are you sure you want to uninstall? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Uninstall cancelled."
	exit 0
fi

echo "Starting uninstall process..."

# 1. Stop and remove launchd service
echo "📍 Removing launchd service..."
PLIST_PATH="${HOME}/Library/LaunchAgents/com.omar.homebrew-autoupdate.plist"
if [[ -f ${PLIST_PATH} ]]; then
	launchctl unload "${PLIST_PATH}" 2>/dev/null || true
	rm -f "${PLIST_PATH}"
	echo "   ✅ Launchd service removed"
else
	echo "   ⚠️  Launchd service not found"
fi

# 2. Remove ~/bin directory and all scripts
echo "📍 Removing scripts from ~/bin..."
if [[ -d "${HOME}/bin" ]]; then
	# Check if there are brew_manager related files
	BREW_FILES=0
	for file in "${HOME}/bin/"*brew_manager* "${HOME}/bin/"*brew_askpass*; do
		[[ -f $file ]] && BREW_FILES=$((BREW_FILES + 1))
	done
	if [[ $BREW_FILES -gt 0 ]]; then
		rm -f "${HOME}/bin/brew_manager.sh"
		rm -f "${HOME}/bin/brew_askpass"
		rm -f "${HOME}/bin/brew_manager_renewal.sh"
		echo "   ✅ Brew manager scripts removed"

		# Check if ~/bin is empty, if so remove it
		if [[ -z "$(ls -A "${HOME}/bin" 2>/dev/null)" ]]; then
			rmdir "${HOME}/bin"
			echo "   ✅ Empty ~/bin directory removed"
		else
			echo "   ℹ️  ~/bin directory kept (contains other files)"
		fi
	else
		echo "   ⚠️  No brew manager scripts found in ~/bin"
	fi
else
	echo "   ⚠️  ~/bin directory not found"
fi

# 3. Remove log directory
echo "📍 Removing log directory..."
LOG_DIR="${HOME}/Library/Logs/Homebrew"
if [[ -d ${LOG_DIR} ]]; then
	rm -rf "${LOG_DIR}"
	echo "   ✅ Homebrew log directory removed"
else
	echo "   ⚠️  Log directory not found"
fi

# 4. Remove cron entries
echo "📍 Removing cron entries..."
CRON_COUNT=$(crontab -l 2>/dev/null | grep -c "brew_manager_renewal.sh" || true)
if [[ $CRON_COUNT -gt 0 ]]; then
	crontab -l 2>/dev/null | grep -v "brew_manager_renewal.sh" >/tmp/clean_crontab
	if [[ -s /tmp/clean_crontab ]]; then
		crontab /tmp/clean_crontab
	else
		crontab -r 2>/dev/null || true
	fi
	rm -f /tmp/clean_crontab
	echo "   ✅ Cron entries removed ($CRON_COUNT entries)"
else
	echo "   ⚠️  No cron entries found"
fi

# 5. Remove SUDO_ASKPASS from shell profile
echo "📍 Cleaning shell profile..."
ZSHRC_ENTRIES=$(grep -c "SUDO_ASKPASS.*brew" ~/.zshrc 2>/dev/null || true)
if [[ $ZSHRC_ENTRIES -gt 0 ]]; then
	# Create backup
	BACKUP_NAME="~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
	cp ~/.zshrc ~/.zshrc.backup."$(date +%Y%m%d_%H%M%S)"
	grep -v "SUDO_ASKPASS.*brew" ~/.zshrc >~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
	echo "   ✅ SUDO_ASKPASS entries removed from .zshrc ($ZSHRC_ENTRIES entries)"
	echo "   ℹ️  Backup created: ${BACKUP_NAME}"
else
	echo "   ⚠️  No SUDO_ASKPASS entries found in .zshrc"
fi

# 6. Unset current session SUDO_ASKPASS
echo "📍 Unsetting current session variables..."
if [[ -n ${SUDO_ASKPASS} && ${SUDO_ASKPASS} == *"brew"* ]]; then
	unset SUDO_ASKPASS
	echo "   ✅ SUDO_ASKPASS unset from current session"
else
	echo "   ⚠️  SUDO_ASKPASS not set or not related to brew_manager"
fi

# 7. Remove keychain entry
echo "📍 Removing keychain entry..."
KEYCHAIN_SERVICE="BrewAutoUpdate"
KEYCHAIN_ACCOUNT="${USER}"
if security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" &>/dev/null; then
	security delete-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" 2>/dev/null || true
	echo "   ✅ Keychain entry removed"
else
	echo "   ⚠️  Keychain entry not found"
fi

# 8. Remove sudo configuration files
echo "📍 Removing sudo configuration..."
SUDO_FILES_REMOVED=0
if [[ -f "/etc/sudoers.d/homebrew" ]]; then
	echo "   Removing /etc/sudoers.d/homebrew (requires sudo)..."
	sudo rm -f /etc/sudoers.d/homebrew 2>/dev/null && SUDO_FILES_REMOVED=$((SUDO_FILES_REMOVED + 1))
fi
if [[ -f "/etc/sudoers.d/homebrew_timeout" ]]; then
	echo "   Removing /etc/sudoers.d/homebrew_timeout (requires sudo)..."
	sudo rm -f /etc/sudoers.d/homebrew_timeout 2>/dev/null && SUDO_FILES_REMOVED=$((SUDO_FILES_REMOVED + 1))
fi

if [[ $SUDO_FILES_REMOVED -gt 0 ]]; then
	echo "   ✅ Sudo configuration files removed ($SUDO_FILES_REMOVED files)"
else
	echo "   ⚠️  No sudo configuration files found"
fi

# 9. Final verification
echo
echo "📍 Verifying uninstall..."
REMAINING_ISSUES=0

# Check for remaining files
if [[ -f "${HOME}/bin/brew_manager.sh" ]] || [[ -f "${HOME}/bin/brew_askpass" ]]; then
	echo "   ❌ Some scripts still exist in ~/bin"
	REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

if [[ -f ${PLIST_PATH} ]]; then
	echo "   ❌ Launchd plist still exists"
	REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

if security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" &>/dev/null; then
	echo "   ❌ Keychain entry still exists"
	REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

REMAINING_CRON=$(crontab -l 2>/dev/null | grep -c "brew_manager_renewal.sh" || true)
if [[ $REMAINING_CRON -gt 0 ]]; then
	echo "   ❌ Cron entries still exist ($REMAINING_CRON entries)"
	REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

REMAINING_ZSHRC=$(grep -c "SUDO_ASKPASS.*brew" ~/.zshrc 2>/dev/null || true)
if [[ $REMAINING_ZSHRC -gt 0 ]]; then
	echo "   ❌ SUDO_ASKPASS entries still in .zshrc ($REMAINING_ZSHRC entries)"
	REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

echo
if [[ $REMAINING_ISSUES -eq 0 ]]; then
	echo "🎉 === UNINSTALL COMPLETE === 🎉"
	echo "✅ All brew_manager components have been successfully removed."
	echo "ℹ️  You may need to restart your terminal or run 'source ~/.zshrc' for shell changes to take effect."
else
	echo "⚠️  === UNINSTALL PARTIALLY COMPLETE === ⚠️"
	echo "❌ $REMAINING_ISSUES issue(s) detected. Some components may need manual removal."
fi

echo
echo "You can now reinstall by running './brew_manager.sh' if needed."
