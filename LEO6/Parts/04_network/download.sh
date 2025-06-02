# ==============================================================================
# Download Management
# ==============================================================================
# Description: Download handling with progress bars and resume capability
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh
# ==============================================================================

# Check if required download tools are available
check_download_tools() {
    local tools_available=false
    
    # Check for curl
    if command -v curl &>/dev/null; then
        DOWNLOAD_TOOL="curl"
        tools_available=true
        log_message "DEBUG" "Using curl for downloads"
    # Check for wget
    elif command -v wget &>/dev/null; then
        DOWNLOAD_TOOL="wget"
        tools_available=true
        log_message "DEBUG" "Using wget for downloads"
    fi
    
    if [[ "$tools_available" != "true" ]]; then
        log_message "ERROR" "No download tools available. Please install curl or wget."
        return 1
    fi
    
    return 0
}

# Initialize download system
init_download_system() {
    # Check for download tools
    if ! check_download_tools; then
        log_message "ERROR" "Failed to initialize download system"
        return 1
    fi
    
    # Reset download tracking arrays
    DOWNLOAD_HISTORY=()
    DOWNLOAD_SIZES=()
    DOWNLOAD_TIMESTAMPS=()
    DOWNLOAD_DESTINATIONS=()
    DOWNLOAD_STATUS=()
    TOTAL_BYTES_DOWNLOADED=0
    
    log_message "INFO" "Download system initialized"
    return 0
}

# Get the size of a remote file
get_remote_file_size() {
    local url="$1"
    local size=0
    
    log_message "DEBUG" "Getting size of remote file: $url"
    
    if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
        size=$(curl -sI "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
    elif [[ "$DOWNLOAD_TOOL" == "wget" ]]; then
        size=$(wget --spider --server-response "$url" 2>&1 | grep -i Content-Length | awk '{print $2}' | tail -1)
    fi
    
    # If size is empty or not a number, return 0
    if [[ -z "$size" || ! "$size" =~ ^[0-9]+$ ]]; then
        size=0
    fi
    
    echo "$size"
}

# Format file size for display
format_size() {
    local size="$1"
    
    if [[ $size -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [[ $size -ge 1048576 ]]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    elif [[ $size -ge 1024 ]]; then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "$size bytes"
    fi
}

# Draw a progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local prefix="${4:-Progress:}"
    
    # Calculate percentage
    local percent=0
    if [[ $total -gt 0 ]]; then
        percent=$(( current * 100 / total ))
    fi
    
    # Calculate filled width
    local filled_width=$(( width * current / total ))
    if [[ $filled_width -gt $width ]]; then
        filled_width=$width
    fi
    
    # Calculate empty width
    local empty_width=$(( width - filled_width ))
    
    # Format current and total size
    local current_formatted=$(format_size "$current")
    local total_formatted=$(format_size "$total")
    
    # Draw the progress bar
    printf "\r%-10s [" "$prefix"
    printf "%${filled_width}s" | tr ' ' '='
    printf "%${empty_width}s" | tr ' ' ' '
    printf "] %3d%% %s/%s" "$percent" "$current_formatted" "$total_formatted"
}

# Download a file with progress
download_file() {
    local url="$1"
    local destination="$2"
    local show_progress="${3:-true}"
    local continue="${4:-true}"
    
    log_message "INFO" "Downloading $url to $destination"
    
    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$destination")"
    
    # Get file size if available
    local file_size
    file_size=$(get_remote_file_size "$url")
    
    # Set up common options
    local curl_opts=("-L" "-f" "-S")
    local wget_opts=("-q")
    
    # Add continue option if requested
    if [[ "$continue" == "true" ]]; then
        curl_opts+=("-C" "-")
        wget_opts+=("-c")
    fi
    
    # Add progress option if requested
    if [[ "$show_progress" == "true" && -t 1 ]]; then
        if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
            # Use progress bar for curl
            curl_opts+=("--progress-bar")
        elif [[ "$DOWNLOAD_TOOL" == "wget" ]]; then
            # Use progress bar for wget
            wget_opts+=("--show-progress")
        fi
    else
        # Silent download
        curl_opts+=("-s")
        wget_opts+=("-q")
    fi
    
    # Add output destination
    curl_opts+=("-o" "$destination")
    wget_opts+=("-O" "$destination")
    
    # Start the download
    local start_time
    start_time=$(date +%s)
    local exit_code=0
    
    # Perform the download with the appropriate tool
    if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
        curl "${curl_opts[@]}" "$url" || exit_code=$?
    elif [[ "$DOWNLOAD_TOOL" == "wget" ]]; then
        wget "${wget_opts[@]}" "$url" || exit_code=$?
    fi
    
    # Calculate download time
    local end_time
    end_time=$(date +%s)
    local download_time=$((end_time - start_time))
    
    # Update download tracking
    if [[ $exit_code -eq 0 && -f "$destination" ]]; then
        # Get the actual file size
        local actual_size
        actual_size=$(stat -c%s "$destination" 2>/dev/null || stat -f%z "$destination" 2>/dev/null)
        
        # Update tracking arrays
        DOWNLOAD_HISTORY+=("$url")
        DOWNLOAD_SIZES+=("$actual_size")
        DOWNLOAD_TIMESTAMPS+=("$(date +%Y-%m-%d-%H:%M:%S)")
        DOWNLOAD_DESTINATIONS+=("$destination")
        DOWNLOAD_STATUS+=("success")
        
        # Update total bytes downloaded
        TOTAL_BYTES_DOWNLOADED=$((TOTAL_BYTES_DOWNLOADED + actual_size))
        
        # Calculate download speed
        local speed=0
        if [[ $download_time -gt 0 ]]; then
            speed=$((actual_size / download_time))
        fi
        
        # Log success
        log_message "INFO" "Download complete: $url -> $destination ($(format_size "$actual_size") in ${download_time}s, $(format_size "$speed")/s)"
        
        # Return success
        return 0
    else
        # Log failure
        log_message "ERROR" "Download failed: $url -> $destination (Exit code: $exit_code)"
        
        # Update tracking arrays for failure
        DOWNLOAD_HISTORY+=("$url")
        DOWNLOAD_SIZES+=("0")
        DOWNLOAD_TIMESTAMPS+=("$(date +%Y-%m-%d-%H:%M:%S)")
        DOWNLOAD_DESTINATIONS+=("$destination")
        DOWNLOAD_STATUS+=("failed")
        
        # Return failure
        return 1
    fi
}

# Download multiple files with a single progress bar
download_multiple_files() {
    local urls=("$@")
    local num_files=${#urls[@]}
    local current_file=1
    local all_success=true
    
    echo -e "${CYAN}Downloading $num_files files...${NC}"
    
    for url in "${urls[@]}"; do
        # Extract filename from URL
        local filename
        filename=$(basename "$url")
        
        # Create destination path
        local destination="$TMP_DIR/downloads/$filename"
        
        # Show which file we're downloading
        echo -e "[${current_file}/${num_files}] ${YELLOW}$filename${NC}"
        
        # Download the file
        if ! download_file "$url" "$destination" true; then
            all_success=false
        fi
        
        # Increment counter
        current_file=$((current_file + 1))
        echo ""
    done
    
    if [[ "$all_success" == "true" ]]; then
        echo -e "${GREEN}All downloads completed successfully${NC}"
        return 0
    else
        echo -e "${RED}Some downloads failed${NC}"
        return 1
    fi
}

# Download a file and verify its checksum
download_and_verify() {
    local url="$1"
    local destination="$2"
    local checksum="$3"
    local checksum_type="${4:-sha256}"
    local show_progress="${5:-true}"
    
    # Download the file
    if ! download_file "$url" "$destination" "$show_progress"; then
        return 1
    fi
    
    # Verify the checksum if provided
    if [[ -n "$checksum" ]]; then
        echo -e "${YELLOW}Verifying checksum...${NC}"
        if ! verify_checksum "$destination" "$checksum" "$checksum_type"; then
            echo -e "${RED}Checksum verification failed${NC}"
            return 1
        fi
        echo -e "${GREEN}Checksum verification passed${NC}"
    fi
    
    return 0
}

# Initialize the download system
init_download_system
