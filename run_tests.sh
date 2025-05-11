#!/bin/bash
# run_tests.sh - Run all tests for brew_manager.sh

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error counter
ERRORS=0

# Current directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/test"

echo -e "${BLUE}==== Brew Manager Test Suite ====${NC}"
echo "Running all tests from ${TEST_DIR}"
echo

# Run unit tests
echo -e "${YELLOW}Running unit tests...${NC}"
"${TEST_DIR}/test_brew_manager.sh"
if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}Unit tests passed${NC}"
else
  echo -e "${RED}Unit tests failed${NC}"
  ERRORS=$((ERRORS + 1))
fi
echo

# Run GitHub update test
echo -e "${YELLOW}Running GitHub update test...${NC}"
"${TEST_DIR}/test_github_update.sh"
if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}GitHub update test passed${NC}"
else
  echo -e "${RED}GitHub update test failed${NC}"
  ERRORS=$((ERRORS + 1))
fi
echo

# Run functional test
echo -e "${YELLOW}Running functional tests...${NC}"
"${TEST_DIR}/functional_test.sh"
if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}Functional tests passed${NC}"
else
  echo -e "${RED}Functional tests failed${NC}"
  ERRORS=$((ERRORS + 1))
fi
echo

# Print summary
echo -e "${BLUE}==== Test Summary ====${NC}"
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}${ERRORS} test suite(s) failed.${NC}"
  exit 1
fi
