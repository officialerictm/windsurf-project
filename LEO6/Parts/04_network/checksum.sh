# ==============================================================================
# Checksum Verification
# ==============================================================================
# Description: Functions to verify file integrity using checksums
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh
# ==============================================================================

# Check if required checksum tools are available
check_checksum_tools() {
    local has_md5=false
    local has_sha1=false
    local has_sha256=false
    local has_sha512=false
    
    # Check for md5sum or md5
    if command -v md5sum &>/dev/null; then
        MD5_TOOL="md5sum"
        has_md5=true
    elif command -v md5 &>/dev/null; then
        MD5_TOOL="md5"
        has_md5=true
    fi
    
    # Check for sha1sum
    if command -v sha1sum &>/dev/null; then
        SHA1_TOOL="sha1sum"
        has_sha1=true
    fi
    
    # Check for sha256sum
    if command -v sha256sum &>/dev/null; then
        SHA256_TOOL="sha256sum"
        has_sha256=true
    fi
    
    # Check for sha512sum
    if command -v sha512sum &>/dev/null; then
        SHA512_TOOL="sha512sum"
        has_sha512=true
    fi
    
    # Log available tools
    log_message "DEBUG" "Checksum tools available: md5=$has_md5, sha1=$has_sha1, sha256=$has_sha256, sha512=$has_sha512"
    
    # Return success if at least one tool is available
    if [[ "$has_md5" == "true" || "$has_sha1" == "true" || "$has_sha256" == "true" || "$has_sha512" == "true" ]]; then
        return 0
    else
        log_message "ERROR" "No checksum tools available"
        return 1
    fi
}

# Calculate a file's checksum
calculate_checksum() {
    local file="$1"
    local type="${2:-sha256}"
    
    log_message "DEBUG" "Calculating $type checksum for $file"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_message "ERROR" "File not found: $file"
        return 1
    fi
    
    # Calculate checksum based on type
    case "$type" in
        md5)
            if [[ "$MD5_TOOL" == "md5sum" ]]; then
                md5sum "$file" | cut -d ' ' -f 1
            elif [[ "$MD5_TOOL" == "md5" ]]; then
                md5 -q "$file"
            else
                log_message "ERROR" "MD5 checksum tool not available"
                return 1
            fi
            ;;
        sha1)
            if [[ -n "$SHA1_TOOL" ]]; then
                sha1sum "$file" | cut -d ' ' -f 1
            else
                log_message "ERROR" "SHA1 checksum tool not available"
                return 1
            fi
            ;;
        sha256)
            if [[ -n "$SHA256_TOOL" ]]; then
                sha256sum "$file" | cut -d ' ' -f 1
            else
                log_message "ERROR" "SHA256 checksum tool not available"
                return 1
            fi
            ;;
        sha512)
            if [[ -n "$SHA512_TOOL" ]]; then
                sha512sum "$file" | cut -d ' ' -f 1
            else
                log_message "ERROR" "SHA512 checksum tool not available"
                return 1
            fi
            ;;
        *)
            log_message "ERROR" "Unsupported checksum type: $type"
            return 1
            ;;
    esac
    
    return $?
}

# Verify a file's checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    local type="${3:-sha256}"
    
    log_message "INFO" "Verifying $type checksum for $file"
    
    # Calculate the actual checksum
    local actual
    actual=$(calculate_checksum "$file" "$type")
    local exit_code=$?
    
    # Check if calculation succeeded
    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "Failed to calculate checksum"
        return 1
    fi
    
    # Convert to lowercase for comparison
    expected="${expected,,}"
    actual="${actual,,}"
    
    # Log checksums
    log_message "DEBUG" "Expected $type: $expected"
    log_message "DEBUG" "Actual $type: $actual"
    
    # Compare checksums
    if [[ "$actual" == "$expected" ]]; then
        log_message "INFO" "Checksum verification passed"
        return 0
    else
        log_message "ERROR" "Checksum verification failed"
        return 1
    fi
}

# Verify multiple files against a checksum file
verify_checksum_file() {
    local checksum_file="$1"
    local base_dir="${2:-.}"
    local type="${3:-sha256}"
    
    log_message "INFO" "Verifying checksums from file: $checksum_file"
    
    # Check if checksum file exists
    if [[ ! -f "$checksum_file" ]]; then
        log_message "ERROR" "Checksum file not found: $checksum_file"
        return 1
    fi
    
    # Track verification results
    local total=0
    local passed=0
    local failed=0
    
    # Process each line in the checksum file
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi
        
        # Parse the line (format depends on checksum type)
        local expected
        local filename
        
        # Handle BSD-style md5 format (md5 -r)
        if [[ "$line" =~ ^MD5\ \(([^\)]+)\)\ =\ ([0-9a-f]+)$ ]]; then
            filename="${BASH_REMATCH[1]}"
            expected="${BASH_REMATCH[2]}"
        # Handle standard format (hash filename)
        else
            expected=$(echo "$line" | awk '{print $1}')
            filename=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
            
            # Handle potential file indicators like '*' for binary mode
            filename=$(echo "$filename" | sed 's/^\*//')
        fi
        
        # Build the full file path
        local file_path="$base_dir/$filename"
        
        # Increment total
        total=$((total + 1))
        
        # Check if file exists
        if [[ ! -f "$file_path" ]]; then
            log_message "WARNING" "File not found: $file_path"
            failed=$((failed + 1))
            continue
        fi
        
        # Verify the checksum
        if verify_checksum "$file_path" "$expected" "$type"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done < "$checksum_file"
    
    # Log results
    log_message "INFO" "Checksum verification results: $passed/$total passed, $failed failed"
    
    # Return success if all passed
    if [[ $failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Generate a checksum file for a directory
generate_checksum_file() {
    local directory="$1"
    local output_file="$2"
    local type="${3:-sha256}"
    local pattern="${4:-*}"
    
    log_message "INFO" "Generating $type checksums for $directory to $output_file"
    
    # Check if directory exists
    if [[ ! -d "$directory" ]]; then
        log_message "ERROR" "Directory not found: $directory"
        return 1
    fi
    
    # Create output file with header
    cat > "$output_file" << EOF
# Generated by Leonardo AI Universal on $(date)
# Checksum type: $type
# Directory: $directory

EOF
    
    # Find files matching pattern and calculate checksums
    local file_count=0
    
    # Use find to get all files, excluding directories
    while IFS= read -r file; do
        # Calculate checksum
        local checksum
        checksum=$(calculate_checksum "$file" "$type")
        
        # Get relative path
        local relative_path
        relative_path="${file#$directory/}"
        
        # Write to output file
        echo "$checksum  $relative_path" >> "$output_file"
        
        # Increment counter
        file_count=$((file_count + 1))
    done < <(find "$directory" -type f -name "$pattern" | sort)
    
    log_message "INFO" "Generated checksums for $file_count files"
    
    # Return success
    return 0
}

# Initialize checksum system
check_checksum_tools
