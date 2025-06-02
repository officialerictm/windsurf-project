#!/bin/bash

# Security Utilities for Leonardo AI USB
# Implements trustless security and tamper detection

# Colors and formatting
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RESET='\033[0m'
C_BOLD='\033[1m'

# Print status messages with consistent formatting
print_status() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "info") echo -e "[${C_BOLD}INFO${C_RESET}] ${message}" ;;
        "success") echo -e "[${C_GREEN}✓${C_RESET}] ${message}" ;;
        "warning") echo -e "[${C_YELLOW}!${C_RESET}] ${message}" ;;
        "error") echo -e "[${C_RED}✗${C_RESET}] ${message}" ;;
        *) echo -e "[?] ${message}" ;;
    esac
}

# Check if the script is running from a read-only filesystem
check_readonly() {
    local script_path="$(realpath "$0" 2>/dev/null || echo "$0")"
    local script_dir="$(dirname "$script_path")"
    
    if [ -w "$script_dir" ]; then
        print_status "warning" "Script directory is writable. For maximum security, run from read-only media."
        return 1
    else
        print_status "success" "Running from read-only media"
        return 0
    fi
}

# Generate a hash of critical files and compare against stored hashes
verify_integrity() {
    local manifest_file="${LEONARDO_ROOT}/.manifest.sha256"
    local temp_manifest="$(mktemp)"
    
    # Generate hashes of critical files
    find "${LEONARDO_ROOT}" -type f -not -path "${LEONARDO_ROOT}/.hashes/*" -not -path "${LEONARDO_ROOT}/models/*" \
        -exec sha256sum {} + > "$temp_manifest" 2>/dev/null
    
    if [ -f "$manifest_file" ]; then
        # Compare with stored manifest
        if ! sha256sum -c "$manifest_file" --status 2>/dev/null; then
            print_status "error" "Integrity check failed! Files have been modified."
            print_status "info" "Run '${C_BOLD}${0} --update-manifest${C_RESET}' if you made intentional changes."
            return 1
        else
            print_status "success" "Integrity check passed"
            return 0
        fi
    else
        # No manifest found, create one
        print_status "warning" "No integrity manifest found. Creating one now..."
        mkdir -p "$(dirname "$manifest_file")"
        cp "$temp_manifest" "$manifest_file"
        print_status "info" "Manifest created at ${manifest_file}"
        return 0
    fi
}

# Check for hardware write protection
check_write_protection() {
    local device="$(findmnt -n -o SOURCE --target "$0" 2>/dev/null | cut -d'[' -f1)"
    
    if [ -z "$device" ]; then
        print_status "warning" "Could not determine device. Write protection check skipped."
        return 0
    fi
    
    # Check for physical write protection
    if [ -f "/sys/block/$(basename "$device")/ro" ]; then
        if [ "$(cat "/sys/block/$(basename "$device")/ro" 2>/dev/null)" = "1" ]; then
            print_status "success" "Hardware write protection is enabled"
            return 0
        fi
    fi
    
    # Check for read-only mount
    if findmnt -n -o OPTIONS "$device" 2>/dev/null | grep -q '\bro\b'; then
        print_status "warning" "Filesystem is mounted read-only"
        return 0
    fi
    
    print_status "warning" "Write protection not detected. For maximum security, enable hardware write protection."
    return 1
}

# Self-hashing verification
self_verify() {
    local script_path="$(realpath "$0" 2>/dev/null || echo "$0")"
    local expected_hash=""
    
    # Get the expected hash (stored in the script itself)
    expected_hash=$(grep -A1 "# BEGIN HASH" "$script_path" | tail -1 | awk '{print $2}')
    
    if [ -z "$expected_hash" ]; then
        print_status "warning" "No hash found in script. First run?"
        return 0
    fi
    
    # Calculate current hash
    local current_hash=$(grep -v "# BEGIN HASH" "$script_path" | grep -v "# END HASH" | sha256sum | awk '{print $1}')
    
    if [ "$current_hash" != "$expected_hash" ]; then
        print_status "error" "Script integrity check failed!"
        print_status "error" "Expected: $expected_hash"
        print_status "error" "Found:    $current_hash"
        return 1
    else
        print_status "success" "Script integrity verified"
        return 0
    fi
}

# Initialize security features
init_security() {
    # Set LEONARDO_ROOT if not set
    if [ -z "${LEONARDO_ROOT}" ]; then
        export LEONARDO_ROOT="$(dirname "$(realpath "$0" 2>/dev/null || echo "$0")")"
    fi
    
    # Check if running from read-only media
    check_readonly
    
    # Verify script integrity
    if ! self_verify; then
        print_status "error" "Security check failed. Exiting."
        exit 1
    fi
    
    # Check hardware write protection
    check_write_protection
    
    # Verify file integrity
    if ! verify_integrity; then
        print_status "error" "Integrity verification failed. Exiting."
        exit 1
    fi
    
    return 0
}

# Update the integrity manifest
update_manifest() {
    local manifest_file="${LEONARDO_ROOT}/.manifest.sha256"
    
    print_status "info" "Updating integrity manifest..."
    
    # Generate new manifest
    find "${LEONARDO_ROOT}" -type f -not -path "${LEONARDO_ROOT}/.hashes/*" -not -path "${LEONARDO_ROOT}/models/*" \
        -exec sha256sum {} + > "$manifest_file" 2>/dev/null
    
    # Update self-hash
    update_self_hash
    
    print_status "success" "Manifest updated successfully"
}

# Update the script's self-hash
update_self_hash() {
    local script_path="$(realpath "$0" 2>/dev/null || echo "$0")"
    local temp_file="$(mktemp)"
    local script_hash=$(grep -v "# BEGIN HASH" "$script_path" | grep -v "# END HASH" | sha256sum | awk '{print $1}')
    
    # Create a temporary file without the hash section
    awk '/^# BEGIN HASH$/{exit} {print}' "$script_path" > "$temp_file"
    
    # Add the new hash section
    echo "" >> "$temp_file"
    echo "# BEGIN HASH" >> "$temp_file"
    echo "# $script_hash" >> "$temp_file"
    echo "# END HASH" >> "$temp_file"
    
    # Replace the original script
    cat "$temp_file" > "$script_path"
    rm -f "$temp_file"
    
    print_status "info" "Updated self-hash"
}

# Main entry point for security checks
if [ "$1" = "--update-manifest" ]; then
    update_manifest
    exit 0
fi

# Initialize security if this script is sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    init_security
fi
