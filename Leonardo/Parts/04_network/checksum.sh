# ==============================================================================
# Checksum Utilities
# ==============================================================================

# Calculate file checksum
calculate_checksum() {
    local file_path="$1"
    local algorithm="${2:-sha256}"
    
    if [ ! -f "$file_path" ]; then
        print_error "File not found: $file_path"
        return 1
    fi
    
    case "$algorithm" in
        md5|md5sum)
            if command_exists md5sum; then
                md5sum "$file_path" | awk '{print $1}'
                return $?
            elif command_exists md5; then
                md5 -q "$file_path"
                return $?
            else
                print_error "md5sum or md5 command not found"
                return 1
            fi
            ;;
        sha1|sha1sum)
            if command_exists sha1sum; then
                sha1sum "$file_path" | awk '{print $1}'
                return $?
            elif command_exists shasum; then
                shasum -a 1 "$file_path" | awk '{print $1}'
                return $?
            else
                print_error "sha1sum or shasum command not found"
                return 1
            fi
            ;;
        sha256|sha256sum)
            if command_exists sha256sum; then
                sha256sum "$file_path" | awk '{print $1}'
                return $?
            elif command_exists shasum; then
                shasum -a 256 "$file_path" | awk '{print $1}'
                return $?
            else
                print_error "sha256sum or shasum command not found"
                return 1
            fi
            ;;
        *)
            print_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
}

# Verify file checksum
verify_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    local actual_checksum
    
    print_debug "Verifying $algorithm checksum for: $file_path"
    
    actual_checksum=$(calculate_checksum "$file_path" "$algorithm")
    if [ $? -ne 0 ]; then
        print_error "Failed to calculate $algorithm checksum for: $file_path"
        return 1
    fi
    
    if [ "$actual_checksum" = "$expected_checksum" ]; then
        print_success "Checksum verified: $file_path"
        return 0
    else
        print_error "Checksum verification failed for: $file_path"
        print_error "Expected: $expected_checksum"
        print_error "Actual:   $actual_checksum"
        return 1
    fi
}

# Save a checksum file
save_checksum() {
    local file_path="$1"
    local algorithm="${2:-sha256}"
    local checksum_file="${3:-}"
    local checksum
    
    # If no checksum file specified, use the file path with algorithm extension
    if [ -z "$checksum_file" ]; then
        checksum_file="${file_path}.${algorithm}"
    fi
    
    # Calculate the checksum
    checksum=$(calculate_checksum "$file_path" "$algorithm")
    if [ $? -ne 0 ]; then
        print_error "Failed to calculate checksum for: $file_path"
        return 1
    fi
    
    # Save the checksum to file
    echo "$checksum  $(basename "$file_path")" > "$checksum_file"
    
    print_success "Saved $algorithm checksum to: $checksum_file"
    return 0
}

# Verify checksums from a checksum file
verify_checksums_file() {
    local checksum_file="$1"
    local base_dir="${2:-.}"
    local algorithm
    
    # Determine algorithm from file extension
    case "$checksum_file" in
        *.md5) algorithm="md5" ;;
        *.sha1) algorithm="sha1" ;;
        *.sha256) algorithm="sha256" ;;
        *)
            print_error "Unknown checksum file type: $checksum_file"
            return 1
            ;;
    esac
    
    # Check if checksum file exists
    if [ ! -f "$checksum_file" ]; then
        print_error "Checksum file not found: $checksum_file"
        return 1
    fi
    
    # Process each line in the checksum file
    local failed=0
    local passed=0
    local total=0
    
    while read -r line; do
        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        total=$((total + 1))
        
        # Extract checksum and filename
        local expected_checksum
        local filename
        
        # Support both common formats:
        # 1. [checksum]  [filename]
        # 2. [checksum] *[filename]
        if [[ "$line" =~ ^([0-9a-fA-F]+)[[:space:]]+[\*]?([^[:space:]]+)$ ]]; then
            expected_checksum="${BASH_REMATCH[1]}"
            filename="${BASH_REMATCH[2]}"
        else
            print_error "Invalid format in line: $line"
            failed=$((failed + 1))
            continue
        fi
        
        # Verify the file's checksum
        file_path="$base_dir/$filename"
        
        if [ ! -f "$file_path" ]; then
            print_error "File not found: $file_path"
            failed=$((failed + 1))
            continue
        fi
        
        print_info "Verifying: $filename"
        
        if verify_checksum "$file_path" "$expected_checksum" "$algorithm"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done < "$checksum_file"
    
    # Report results
    if [ $total -eq 0 ]; then
        print_warning "No checksums found in file: $checksum_file"
        return 1
    fi
    
    if [ $failed -eq 0 ]; then
        print_success "All checksums verified ($passed/$total)"
        return 0
    else
        print_error "$failed/$total checksums failed"
        return 1
    fi
}

# Get the public IP address
get_public_ip() {
    local services=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://ident.me"
        "https://ipecho.net/plain"
    )
    
    for service in "${services[@]}"; do
        if check_url "$service"; then
            if command_exists curl; then
                curl -sSL "$service" 2>/dev/null && return 0
            elif command_exists wget; then
                wget -qO- "$service" 2>/dev/null && return 0
            fi
        fi
    done
    
    print_error "Could not determine public IP address"
    return 1
}
