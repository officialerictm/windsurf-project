#!/bin/bash

# Test script for Leonardo AI USB Maker Master Version
# This script runs basic tests to verify the functionality

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASS="${GREEN}PASS${NC}"
FAIL="${RED}FAIL${NC}"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local command_to_run="$2"
    
    echo -e "${YELLOW}Running test: ${test_name}${NC}"
    echo -e "Command: ${command_to_run}"
    
    # Run the command and capture output and status
    eval "$command_to_run" > /tmp/leonardo_test_output.txt 2>&1
    local status=$?
    
    # Check if command was successful
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ Test passed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Test failed with status: $status${NC}"
        echo -e "${YELLOW}Output:${NC}"
        cat /tmp/leonardo_test_output.txt
    fi
    
    ((TESTS_RUN++))
    echo ""
}

# Print test header
echo -e "${YELLOW}=== Leonardo AI USB Maker Test Suite ===${NC}\n"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test 1: Check script syntax
run_test "Syntax Check" "bash -n leonardo_master.sh"

# Test 2: Show help
run_test "Show Help" "NO_COLOR=1 ./leonardo_master.sh --help | head -n 20"

# Test 3: Show version (extract version from source)
run_test "Extract Version from Source" "grep -m1 'SCRIPT_VERSION=' leonardo_master.sh | cut -d'\"' -f2"

# Test 4: Check requirements (non-root)
run_test "Check Requirements (non-root)" "NO_COLOR=1 ./leonardo_master.sh --dry-run | head -n 20"

# Test 5: Test model listing from README
run_test "List Available Models in README" "grep -A15 'Supported AI Models' README.md | tail -n +2 | head -n 10"

# Test 6: Check for required commands
run_test "Check Required Commands" "for cmd in lsblk blkid parted mkfs.exfat mount umount curl tar unzip; do command -v $cmd >/dev/null && echo \"$cmd: found\" || echo \"$cmd: not found\"; done"

# Print test summary
echo -e "${YELLOW}=== Test Summary ===${NC}"
echo -e "Tests Run:  ${TESTS_RUN}"
echo -e "Tests Passed: ${TESTS_PASSED}/${TESTS_RUN}"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the output above.${NC}"
    exit 1
fi
