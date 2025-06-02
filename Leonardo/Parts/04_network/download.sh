# ==============================================================================
# Network Download Operations
# ==============================================================================

# Check if a URL is reachable
check_url() {
    local url="$1"
    local timeout="${2:-10}"
    
    # Check if curl is available
    if command_exists curl; then
        if curl -sSL --max-time "$timeout" --head "$url" &>/dev/null; then
            return 0
        fi
    # Fall back to wget if curl is not available
    elif command_exists wget; then
        if wget -q --spider --timeout="$timeout" "$url" &>/dev/null; then
            return 0
        fi
    else
        print_warning "Neither curl nor wget is available. Cannot check URL: $url"
        return 2
    fi
    
    return 1
}

# Download a file with progress tracking
# Based on memory: Fixed nested heredoc syntax problems in fancy_download function
fancy_download() {
    local url="$1"
    local output_file="${2:-}"
    local show_progress="${3:-true}"
    local resume="${4:-false}"
    local retry_count=0
    local max_retries=5
    local retry_delay=3
    local result=0
    
    # If no output file specified, use the basename of the URL
    if [ -z "$output_file" ]; then
        output_file="${url##*/}"
        # Remove query string if present
        output_file="${output_file%%\?*}"
    fi
    
    # Create output directory if it doesn't exist
    local output_dir="$(dirname "$output_file")"
    mkdir -p "$output_dir" 2>/dev/null || {
        print_error "Failed to create directory: $output_dir"
        return 1
    }
    
    print_info "Downloading: $url"
    print_info "To: $output_file"
    
    # Try to download the file with retries
    while [ $retry_count -lt $max_retries ]; do
        # Choose appropriate download tool
        if command_exists curl; then
            # Build curl command
            local curl_args=("-L" "-f" "-o" "$output_file")
            
            # Add resume flag if requested and file exists
            if [ "$resume" = true ] && [ -f "$output_file" ]; then
                curl_args+=("-C" "-")
                print_debug "Resuming download from $(human_readable_size $(stat -c%s "$output_file"))"
            fi
            
            # Add progress display if requested
            if [ "$show_progress" = true ]; then
                curl_args+=("-#")
            else
                curl_args+=("-s")
            fi
            
            # Execute curl command
            curl "${curl_args[@]}" "$url"
            result=$?
            
        elif command_exists wget; then
            # Build wget command
            local wget_args=("-O" "$output_file")
            
            # Add resume flag (always enabled with -c)
            wget_args+=("-c")
            
            # Add progress display if requested
            if [ "$show_progress" = true ]; then
                wget_args+=("--show-progress")
            else
                wget_args+=("-q")
            fi
            
            # Execute wget command
            wget "${wget_args[@]}" "$url"
            result=$?
            
        else
            print_error "Neither curl nor wget is available. Cannot download file."
            return 1
        fi
        
        # Check download result
        if [ $result -eq 0 ]; then
            # Verify the file was actually downloaded
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                print_success "Downloaded: $url"
                
                # Log download in history
                log_download "$url" "$output_file"
                
                return 0
            else
                print_warning "Download completed but file is empty or missing"
                result=1
            fi
        fi
        
        # If download failed, retry
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Download failed (attempt $retry_count/$max_retries)"
            print_info "Retrying in $retry_delay seconds..."
            sleep $retry_delay
        else
            print_error "Failed to download after $max_retries attempts: $url"
        fi
    done
    
    return 1
}

# Log the download in the download history
log_download() {
    local url="$1"
    local file="$2"
    local size=$(stat -c%s "$file" 2>/dev/null || echo "unknown")
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local history_file="$LOG_DIR/download_history.log"
    
    # Create history directory if it doesn't exist
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || {
        print_debug "Failed to create history directory: $(dirname "$history_file")"
        return 1
    }
    
    # Create history file if it doesn't exist
    if [ ! -f "$history_file" ]; then
        echo "# Leonardo AI USB Maker - Download History" > "$history_file"
        echo "# Format: timestamp|url|file|size" >> "$history_file"
        echo "# =========================================" >> "$history_file"
        
        # Set appropriate permissions
        chmod 600 "$history_file" 2>/dev/null || true
    fi
    
    # Append download to history
    echo "$timestamp|$url|$file|$size" >> "$history_file"
    
    return 0
}

# Show the download history
view_download_history() {
    local history_file="$LOG_DIR/download_history.log"
    
    if [ ! -f "$history_file" ]; then
        print_info "No download history available."
        read -p "Press [Enter] to continue..."
        return 0
    fi
    
    print_section_header "DOWNLOAD HISTORY"
    
    local line_count=$(wc -l < "$history_file")
    local header_lines=3
    local data_lines=$((line_count - header_lines))
    
    if [ $data_lines -le 0 ]; then
        print_info "No downloads recorded yet."
        read -p "Press [Enter] to continue..."
        return 0
    fi
    
    echo "Recent downloads (most recent first):"
    echo
    
    # Skip header lines and display in reverse order (most recent first)
    tail -n $data_lines "$history_file" | sort -r | while IFS='|' read -r timestamp url file size; do
        echo "Time: $timestamp"
        echo "URL: $url"
        echo "File: $file"
        echo "Size: $(human_readable_size $size)"
        echo "----------------------------------------"
    done
    
    read -p "Press [Enter] to continue..."
    return 0
}

# Download a file with checksum verification
download_with_checksum() {
    local url="$1"
    local output_file="${2:-}"
    local expected_checksum="${3:-}"
    local algorithm="${4:-sha256}"
    local retry_count=0
    local max_retries=3
    
    # If no output file specified, use the basename of the URL
    if [ -z "$output_file" ]; then
        output_file="${url##*/}"
        # Remove query string if present
        output_file="${output_file%%\?*}"
    fi
    
    # Try to download the file with retries
    while [ $retry_count -lt $max_retries ]; do
        # Download the file
        fancy_download "$url" "$output_file" true true
        
        # If download failed, retry
        if [ $? -ne 0 ]; then
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Download failed. Retrying ($retry_count/$max_retries)..."
                sleep 2
                continue
            else
                print_error "Failed to download file after $max_retries attempts"
                return 1
            fi
        fi
        
        # If no checksum provided, we're done
        if [ -z "$expected_checksum" ]; then
            print_warning "No checksum provided. Skipping verification."
            return 0
        fi
        
        # Verify the checksum
        print_info "Verifying $algorithm checksum..."
        
        # Calculate the actual checksum
        local actual_checksum
        actual_checksum=$(calculate_checksum "$output_file" "$algorithm")
        
        if [ $? -ne 0 ]; then
            print_error "Failed to calculate checksum."
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Retrying ($retry_count/$max_retries)..."
                rm -f "$output_file"
                sleep 2
                continue
            else
                print_error "Failed to verify checksum after $max_retries attempts"
                return 1
            fi
        fi
        
        # Compare the checksums
        if [ "$actual_checksum" = "$expected_checksum" ]; then
            print_success "Checksum verified successfully."
            return 0
        else
            print_error "Checksum verification failed."
            print_error "  Expected: $expected_checksum"
            print_error "  Actual:   $actual_checksum"
            
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Retrying ($retry_count/$max_retries)..."
                rm -f "$output_file"
                sleep 2
                continue
            else
                print_error "Failed to verify checksum after $max_retries attempts"
                return 1
            fi
        fi
    done
    
    return 1
}
