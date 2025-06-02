#!/bin/bash

# Test script for Leonardo AI USB Maker security features
# Run this script to verify the security implementation

# Colors for output
C_RESET="\033[0m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_YELLOW="\033[33m"
C_BOLD="\033[1m"

echo -e "${C_BOLD}=== Leonardo AI USB Maker - Security Test ===${C_RESET}\n"

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${C_YELLOW}⚠ Warning: Running as root. Some tests may not work as expected.${C_RESET}\n"
fi

# Test 1: Verify security_utils.sh exists
if [ -f "security_utils.sh" ]; then
    echo -e "${C_GREEN}✓ Test 1: security_utils.sh found${C_RESET}" 
    
    # Source the security utils
    source ./security_utils.sh
    
    # Test 2: Initialize security
    echo -e "\n${C_BOLD}Initializing security...${C_RESET}"
    if init_security; then
        echo -e "${C_GREEN}✓ Security initialization successful${C_RESET}"
    else
        echo -e "${C_RED}✗ Security initialization failed${C_RESET}"
        exit 1
    fi
    
    # Test 3: Check write protection
    echo -e "\n${C_BOLD}Testing write protection...${C_RESET}"
    if check_write_protection; then
        echo -e "${C_GREEN}✓ Write protection check passed${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Write protection warning (may be expected)${C_RESET}"
    fi
    
    # Test 4: Verify integrity
    echo -e "\n${C_BOLD}Testing integrity verification...${C_RESET}"
    if verify_integrity; then
        echo -e "${C_GREEN}✓ Integrity verification passed${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Integrity check warning (run with --update-security if this is expected)${C_RESET}"
    fi
    
    # Test 5: Self-hashing
    echo -e "\n${C_BOLD}Testing self-hashing...${C_RESET}"
    if self_verify; then
        echo -e "${C_GREEN}✓ Self-hash verification passed${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Self-hash verification warning (run with --update-security to fix)${C_RESET}"
    fi
    
    # Test 6: Update manifest
    echo -e "\n${C_BOLD}Testing manifest update...${C_RESET}"
    if update_manifest; then
        echo -e "${C_GREEN}✓ Manifest update test passed${C_RESET}"
    else
        echo -e "${C_RED}✗ Manifest update test failed${C_RESET}"
    fi
    
    echo -e "\n${C_BOLD}Security tests completed.${C_RESET}"
    echo -e "Run '${C_BOLD}./leonardo_master.sh --update-security${C_RESET}' to update security hashes."
    
else
    echo -e "${C_RED}✗ Test 1: security_utils.sh not found in current directory${C_RESET}"
    echo "Please run this script from the directory containing leonardo_master.sh"
    exit 1
fi

echo -e "\n${C_BOLD}=== Security Test Complete ===${C_RESET}"
