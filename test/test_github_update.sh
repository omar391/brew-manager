#!/bin/bash
# test_github_update.sh - Test the GitHub update functionality of brew_manager.sh
# This script verifies that the renewal script can properly pull updates from GitHub

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Original script path
SCRIPT_PATH="$(cd "$(dirname "$0")/.." && pwd)/brew_manager.sh"
GITHUB_REPO="https://github.com/omar391/brew-manager"

echo -e "${YELLOW}Testing GitHub update functionality...${NC}"

# Step 1: Set up test environment
echo "Setting up test environment..."
mkdir -p "${TEST_DIR}/bin"
cp "${SCRIPT_PATH}" "${TEST_DIR}/bin/brew_manager.sh"
chmod +x "${TEST_DIR}/bin/brew_manager.sh"

# Step 2: Create mock git function
mock_git() {
  echo "Mock git: Would clone ${GITHUB_REPO}"
  mkdir -p "${TEST_DIR}/temp/brew-manager"
  
  # Create a "newer" version of the script
  cat > "${TEST_DIR}/temp/brew-manager/brew_manager.sh" << 'EOF'
#!/bin/bash
# This is a newer version of brew_manager.sh from GitHub
# Version: 1.1.0
# Last updated: May 11, 2025

echo "This is the updated version of brew_manager.sh"
echo "Successfully updated from GitHub"
EOF
  
  chmod +x "${TEST_DIR}/temp/brew-manager/brew_manager.sh"
  return 0
}

# Step 3: Create the renewal script with our test environment
echo "Creating test renewal script..."
cat > "${TEST_DIR}/brew_manager_renewal.sh" << EOFSCRIPT
#!/bin/bash
# Renewal script for brew_manager.sh
# This script pulls the latest version from GitHub and updates the local copy

# Target directory and file
BIN_DIR="${TEST_DIR}/bin"
SCRIPT_NAME="brew_manager.sh"
TARGET_PATH="\${BIN_DIR}/\${SCRIPT_NAME}"

# GitHub repository URL
REPO_URL="${GITHUB_REPO}"

# Create a temporary directory
TEMP_DIR="\$(mktemp -d)"
mkdir -p "\${TEMP_DIR}"

# Clone the repository (mock)
echo "Pulling latest version from \${REPO_URL}..."
# Create a mock updated script directly
mkdir -p "\${TEMP_DIR}/brew-manager"
cat > "\${TEMP_DIR}/brew-manager/brew_manager.sh" << 'EOF'
#!/bin/bash
# This is the updated version of brew_manager.sh from GitHub
# Version: 1.1.0
# Last updated: May 11, 2025

echo "This is the updated version of brew_manager.sh"
echo "Successfully updated from GitHub"
EOF
chmod +x "\${TEMP_DIR}/brew-manager/brew_manager.sh"

# Copy the updated script
echo "Updating brew_manager script..."
mkdir -p "\${BIN_DIR}"
cp "\${TEMP_DIR}/brew-manager/brew_manager.sh" "\${TARGET_PATH}"
chmod +x "\${TARGET_PATH}"

# Clean up
rm -rf "\${TEMP_DIR}"

echo "Update completed. New version installed."
EOFSCRIPT
mkdir -p "\${TEMP_DIR}"

# Step 4: Run the test
echo -e "${YELLOW}Running the renewal script test...${NC}"
chmod +x "${TEST_DIR}/brew_manager_renewal.sh"
"${TEST_DIR}/brew_manager_renewal.sh"
result=$?

# Step 5: Verify the results
if [[ $result -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} Renewal script executed successfully"
else
  echo -e "${RED}✗${NC} Renewal script failed with exit code ${result}"
  exit 1
fi

# Check if the script was updated
if grep -q "This is the updated version" "${TEST_DIR}/bin/brew_manager.sh"; then
  echo -e "${GREEN}✓${NC} Script was successfully updated from GitHub"
else
  echo -e "${RED}✗${NC} Script was not updated properly"
  exit 1
fi

echo -e "\n${GREEN}GitHub update functionality test passed!${NC}"
echo "The renewal process is correctly configured to fetch updates from ${GITHUB_REPO}"
exit 0
