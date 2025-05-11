#!/bin/bash
# test_brew_manager.sh - Test suite for brew_manager.sh
# This script verifies that brew_manager.sh functions correctly

# Set to exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for tests
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Directory for temporary test files
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Source script path - using mock for testing
SCRIPT_PATH="$(cd "$(dirname "$0")/.." && pwd)/brew_manager.sh"
MOCK_SCRIPT_PATH="${TEST_DIR}/brew_manager.sh"

# Function to print test results
print_result() {
  local status=$1
  local test_name=$2
  local message=$3
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if [[ $status -eq 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}[PASS]${NC} $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}[FAIL]${NC} $test_name: $message"
  fi
}

# Function to mock system utilities for testing
create_mock_env() {
  # Mock script with test hooks
  cp "${SCRIPT_PATH}" "${MOCK_SCRIPT_PATH}"
  chmod +x "${MOCK_SCRIPT_PATH}"
  
  # Create mock bin directory
  mkdir -p "${TEST_DIR}/bin"
  
  # Create mock launchd agents directory
  mkdir -p "${TEST_DIR}/LaunchAgents"
  
  # Create mock logs directory
  mkdir -p "${TEST_DIR}/Logs/Homebrew"
  
  # Mock basic commands
  cat > "${TEST_DIR}/mock_commands.sh" << EOF
# Mock command functions
mock_security() {
  case "\$*" in
    "find-generic-password -s BrewAutoUpdate -a \$USER -w")
      if [[ -f "${TEST_DIR}/keychain_password" ]]; then
        cat "${TEST_DIR}/keychain_password"
        return 0
      else
        return 1
      fi
      ;;
    "add-generic-password"*)
      printf "%s" "mockpassword" > "${TEST_DIR}/keychain_password"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

mock_sudo() {
  if [[ "\$*" == *"echo Password verified"* ]]; then
    return 0
  elif [[ "\$*" == *"cp"* && "\$*" == *"sudoers"* ]]; then
    # Just log the sudo operations for verification
    printf "SUDO: %s\n" "\$*" >> "${TEST_DIR}/sudo_operations.log"
    return 0
  else
    return 0
  fi
}

mock_brew() {
  if [[ "\$1" == "autoupdate" && "\$2" == "delete" ]]; then
    printf "Mock: Deleted autoupdate\n" >> "${TEST_DIR}/brew_operations.log"
    return 0
  elif [[ "\$1" == "update" ]]; then
    printf "Mock: Updated Homebrew\n" >> "${TEST_DIR}/brew_operations.log"
    return 0
  elif [[ "\$1" == "upgrade" ]]; then
    printf "Mock: Upgraded %s\n" "\$2" >> "${TEST_DIR}/brew_operations.log"
    return 0
  elif [[ "\$1" == "cleanup" ]]; then
    printf "Mock: Cleaned up\n" >> "${TEST_DIR}/brew_operations.log"
    return 0
  else
    return 0
  fi
}

mock_launchctl() {
  printf "LAUNCHCTL: %s\n" "\$*" >> "${TEST_DIR}/launchd_operations.log"
  return 0
}

mock_crontab() {
  if [[ "\$*" == "-l" ]]; then
    echo "# Existing crontab entry"
    return 0
  elif [[ "\$*" == "-" ]]; then
    # Save the input to a file for verification
    cat > "${TEST_DIR}/crontab_entries.log"
    return 0
  else
    return 0
  fi
}

mock_git() {
  if [[ "\$*" == "clone https://github.com/omar391/brew-manager ./brew-manager" ]]; then
    # Simulate successful clone by creating the directory and copying the script
    mkdir -p ./brew-manager
    cp "${SCRIPT_PATH}" ./brew-manager/brew_manager.sh
    return 0
  else
    return 1
  fi
}
EOF
  
  source "${TEST_DIR}/mock_commands.sh"
  
  # Patch the script to use our mock commands and directories
  # Use ~ as delimiter for sed to avoid issues with paths containing / or #

  # 1. Replace KEYCHAIN_SERVICE
  sed -i.bak 's~^KEYCHAIN_SERVICE=.*~KEYCHAIN_SERVICE="BrewAutoUpdate"~g' "${MOCK_SCRIPT_PATH}"

  # 2. Replace paths like "${HOME}/bin" with "${TEST_DIR}/bin"
  sed -i.bak "s~\\\"\\\\\\${HOME}/bin~\\\"${TEST_DIR}/bin~g" "${MOCK_SCRIPT_PATH}"
  sed -i.bak "s~\\\"\\\\\\${HOME}/Library/LaunchAgents~\\\"${TEST_DIR}/LaunchAgents~g" "${MOCK_SCRIPT_PATH}"
  sed -i.bak "s~\\\"\\\\\\${HOME}/Library/Logs~\\\"${TEST_DIR}/Logs~g" "${MOCK_SCRIPT_PATH}"

  # 3. Comment out any 'exec ...' line to prevent re-execution
  sed -i.bak 's~^[[:space:]]*exec .*~# Mocked exec: &~g' "${MOCK_SCRIPT_PATH}"

  # 4. Replace 'exit ${?}' in askpass/run_update blocks with 'return 0'
  sed -i.bak 's~^  exit \\\\${?}~  return 0 \\\\# Mocked exit for testing~g' "${MOCK_SCRIPT_PATH}"

  # 5. Comment out any 'main ...' line to prevent main function call
  sed -i.bak 's~^[[:space:]]*main .*~# Mocked main call: &~g' "${MOCK_SCRIPT_PATH}"

  # 6. Replace '|| exit 1' with '|| return 1'
  sed -i.bak 's~|| exit 1~|| return 1 \\\\#mocked~g' "${MOCK_SCRIPT_PATH}"

  # 7. Replace specific 'exit 1' in 'store_password_in_keychain' failure
  sed -i.bak 's~\(store_password_in_keychain || { echo "Failed to store password. Exiting."; \)exit 1\(;} \)~\1return 1\2 \#mocked~g' "${MOCK_SCRIPT_PATH}"

  # Create a test function wrapper
  cat > "${TEST_DIR}/test_functions.sh" << EOF
# Test wrapper for the original functions
test_store_password() {
  # Override read to provide test password
  read() {
    printf "%s" "testpassword" > "${TEST_DIR}/user_password"
  }
  
  # Override security command
  security() {
    mock_security "\$@"
  }
  
  # Override sudo command
  sudo() {
    mock_sudo "\$@"
  }
  
  # Source the script to get functions
  source "${MOCK_SCRIPT_PATH}"
  
  # Call the function
  store_password_in_keychain
  return \$?
}

test_configure_sudo() {
  # Override security command
  security() {
    mock_security "\$@"
  }
  
  # Override sudo command
  sudo() {
    mock_sudo "\$@"
  }
  
  # Source the script to get functions
  source "${MOCK_SCRIPT_PATH}"
  
  # Call the function
  configure_sudo
  return \$?
}

test_setup_brew_autoupdate() {
  # Override brew command
  brew() {
    mock_brew "\$@"
  }
  
  # Override launchctl command
  launchctl() {
    mock_launchctl "\$@"
  }
  
  # Source the script to get functions
  source "${MOCK_SCRIPT_PATH}"
  
  # Call the function
  setup_brew_autoupdate
  return \$?
}

test_add_to_profile() {
  # Mock grep to always return false (so we add the entry)
  grep() {
    return 1
  }
  
  # Source the script to get functions
  source "${MOCK_SCRIPT_PATH}"
  
  # Call the function
  cd "\$(dirname "${MOCK_SCRIPT_PATH}")" || return 1
  add_to_profile
  return \$?
}

test_schedule_renewal() {
  # Override crontab command
  crontab() {
    mock_crontab "\$@"
  }
  
  # Source the script to get functions
  source "${MOCK_SCRIPT_PATH}"
  
  # Call the function
  cd "\$(dirname "${MOCK_SCRIPT_PATH}")" || return 1
  schedule_renewal
  return \$?
}

test_run_brew_update() {
  # Override brew command
  brew() {
    mock_brew "\$@"
  }
  
  # Source the script to get functions
  source "${MOCK_SCRIPT_PATH}"
  
  # Call the function
  run_brew_update
  return \$?
}

test_renewal_script() {
  # Setup the renewal script
  test_schedule_renewal
  
  # Check if the renewal script was created
  if [[ -f "${TEST_DIR}/bin/brew_manager_renewal.sh" ]]; then
    # Make it executable in case it wasn't
    chmod +x "${TEST_DIR}/bin/brew_manager_renewal.sh"
    
    # Override git command
    git() {
      mock_git "\$@"
    }
    
    # Run the renewal script in a subshell to test it
    (
      cd "${TEST_DIR}" || return 1
      # Mock HOME to our test dir
      HOME="${TEST_DIR}"
      
      # Run the renewal script
      "${TEST_DIR}/bin/brew_manager_renewal.sh"
    )
    
    # Check if it created the updated script
    if [[ -f "${TEST_DIR}/bin/brew_manager.sh" ]]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}
EOF
  
  source "${TEST_DIR}/test_functions.sh"
}

# Run tests
run_tests() {
  echo -e "${YELLOW}Running tests for brew_manager.sh...${NC}"
  
  # Test 1: Password storage
  test_store_password
  print_result $? "Password storage" "Failed to store password in keychain"
  
  # Test 2: Sudo configuration
  test_configure_sudo
  print_result $? "Sudo configuration" "Failed to configure sudo permissions"
  
  # Test 3: Brew autoupdate setup
  test_setup_brew_autoupdate
  print_result $? "Brew autoupdate setup" "Failed to set up brew autoupdate"
  
  # Test 4: Profile configuration
  test_add_to_profile
  print_result $? "Profile configuration" "Failed to add to profile"
  
  # Test 5: Renewal scheduling
  test_schedule_renewal
  print_result $? "Renewal scheduling" "Failed to schedule renewal"
  
  # Test 6: Brew update process
  test_run_brew_update
  print_result $? "Brew update process" "Failed to run brew update"
  
  # Test 7: Renewal script functionality
  test_renewal_script
  print_result $? "Renewal script functionality" "Failed to execute renewal script"
  
  # Test 8: Check if launchd plist was created
  if [[ -f "${TEST_DIR}/LaunchAgents/com.omar.homebrew-autoupdate.plist" ]]; then
    print_result 0 "LaunchAgent plist creation" "LaunchAgent plist not created"
  else
    print_result 1 "LaunchAgent plist creation" "LaunchAgent plist not created"
  fi
  
  # Test 9: Check if renewal script was created
  if [[ -f "${TEST_DIR}/bin/brew_manager_renewal.sh" ]]; then
    print_result 0 "Renewal script creation" "Renewal script not created"
  else
    print_result 1 "Renewal script creation" "Renewal script not created"
  fi
  
  # Print summary
  echo -e "${YELLOW}Test Summary:${NC}"
  echo -e "Total tests: ${TESTS_RUN}"
  echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
  if [[ ${TESTS_FAILED} -gt 0 ]]; then
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    return 1
  else
    echo -e "Failed: ${TESTS_FAILED}"
    return 0
  fi
}

# Main test execution
create_mock_env
run_tests

exit $?
