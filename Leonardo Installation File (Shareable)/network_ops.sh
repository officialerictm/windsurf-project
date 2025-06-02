#!/bin/bash

# --- Network Operations ---

# Download a file with progress tracking
fancy_download() {
    local url="$1"
    local output_file="$2"
    local description="${3:-File}"
    local max_retries=3
    local retry_delay=5
    
    # Create output directory if it doesn't exist
    local output_dir="$(dirname "$output_file")"
    mkdir -p "$output_dir"
    
    # Check if file already exists
    if [ -f "$output_file" ]; then
        ui_info "File already exists: $output_file"
        return 0
    fi
    
    local temp_file="${output_file}.downloading"
    local download_cmd
    local http_status
    
    # Determine download command (curl or wget)
    if command -v curl >/dev/null; then
        download_cmd=(
            curl -L --connect-timeout 30 --retry 3 --retry-delay 5
            --progress-bar -o "$temp_file" -w "%{http_code}" "$url"
        )
    elif command -v wget >/dev/null; then
        download_cmd=(
            wget --tries=3 --timeout=30 --waitretry=5 --quiet
            --show-progress -O "$temp_file" "$url"
        )
        # wget doesn't support progress bar in non-interactive mode
        [ "$VERBOSE" = false ] && download_cmd+=(--no-verbose)
    else
        ui_error "Neither curl nor wget is available for downloading files"
        return 1
    fi
    
    ui_info "Downloading $description..."
    ui_debug "URL: $url"
    ui_debug "Output: $output_file"
    
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        # Show progress bar
        (
            while [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; do
                sleep 1
            done
            
            local file_size=0
            local downloaded=0
            
            # Get file size from Content-Length header if available
            if [ -n "${download_cmd[0]}" ] && [ "${download_cmd[0]}" = "curl" ]; then
                file_size=$(curl -sI "$url" | grep -i 'content-length' | awk '{print $2}' | tr -d '\r')
                [ -z "$file_size" ] && file_size=0
            fi
            
            # Update progress while downloading
            while [ -f "${temp_file}.progress" ]; do
                if [ $file_size -gt 0 ]; then
                    downloaded=$(stat -c%s "$temp_file" 2>/dev/null || echo 0)
                    progress_bar $downloaded $file_size 50 "Downloading"
                else
                    local current_size=$(stat -c%s "$temp_file" 2>/dev/null || echo 0)
                    printf "\r${COLOR_CYAN}Downloading:${COLOR_RESET} %s "$(human_readable_size $current_size)"
                fi
                sleep 0.5
            done
        ) & local progress_pid=$!
        
        # Start download
        touch "${temp_file}.progress"
        http_status=$("${download_cmd[@]}" 2>&1 || echo "500")
        
        # Stop progress tracking
        kill $progress_pid 2>/dev/null || true
        wait $progress_pid 2>/dev/null || true
        
        # Check if download was successful
        if [ -f "$temp_file" ] && [ -s "$temp_file" ] && \
           { [ -z "$http_status" ] || [ "$http_status" = "200" ] || [ "$http_status" = "000" ]; }; then
            # Download successful
            mv -f "$temp_file" "$output_file"
            rm -f "${temp_file}.progress"
            
            # Log the download
            local file_size=$(stat -c%s "$output_file" 2>/dev/null || echo 0)
            log_download "$url" "$output_file" "$file_size" "success" "$description"
            
            ui_success "Successfully downloaded $description ($(human_readable_size $file_size))"
            return 0
        else
            # Download failed
            rm -f "$temp_file" "${temp_file}.progress"
            
            if [ $attempt -lt $max_retries ]; then
                ui_warning "Download failed (attempt $attempt/$max_retries). Retrying in ${retry_delay}s..."
                sleep $retry_delay
                ((attempt++))
            else
                log_download "$url" "$output_file" "0" "failed" "$description"
                ui_error "Failed to download $description after $max_retries attempts"
                return 1
            fi
        fi
    done
    
    return 1
}

# Log a download to the history
log_download() {
    local url="$1"
    local output_file="$2"
    local size_bytes="$3"
    local status="$4"
    local description="$5"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Create downloads log file if it doesn't exist
    local log_file="$TMP_DIR/downloads.log"
    if [ ! -f "$log_file" ]; then
        echo "timestamp,url,output_file,size_bytes,status,description" > "$log_file"
    fi
    
    # Append download log
    echo "\"$timestamp\",\"$url\",\"$output_file\",$size_bytes,$status,\"$description\"" >> "$log_file"
}

# Verify file integrity with checksum
verify_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    
    if [ ! -f "$file_path" ]; then
        ui_error "File not found: $file_path"
        return 1
    fi
    
    ui_info "Verifying $algorithm checksum for $(basename "$file_path")"
    
    local actual_checksum
    case "$algorithm" in
        md5)
            actual_checksum=$(md5sum "$file_path" | awk '{print $1}')
            ;;
        sha1)
            actual_checksum=$(sha1sum "$file_path" | awk '{print $1}')
            ;;
        sha256)
            actual_checksum=$(sha256sum "$file_path" | awk '{print $1}')
            ;;
        *)
            ui_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
    
    if [ "$actual_checksum" = "$expected_checksum" ]; then
        ui_success "Checksum verified successfully"
        return 0
    else
        ui_error "Checksum verification failed"
        ui_debug "Expected: $expected_checksum"
        ui_debug "Actual:   $actual_checksum"
        return 1
    fi
}

# Download a file with checksum verification
download_with_checksum() {
    local url="$1"
    local output_file="$2"
    local checksum="$3"
    local description="${4:-File}"
    local algorithm="${5:-sha256}"
    
    # Download the file
    if ! fancy_download "$url" "$output_file" "$description"; then
        return 1
    fi
    
    # Verify checksum if provided
    if [ -n "$checksum" ]; then
        if ! verify_checksum "$output_file" "$checksum" "$algorithm"; then
            ui_error "Checksum verification failed for $description"
            rm -f "$output_file"
            return 1
        fi
    fi
    
    return 0
}

# Get the content of a URL
http_get() {
    local url="$1"
    local output=""
    
    if command -v curl >/dev/null; then
        output=$(curl -s -L --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || echo "")
    elif command -v wget >/dev/null; then
        output=$(wget -q -O - --timeout=30 "$url" 2>/dev/null || echo "")
    else
        ui_error "Neither curl nor wget is available for HTTP requests"
        return 1
    fi
    
    if [ -z "$output" ]; then
        ui_error "Failed to fetch URL: $url"
        return 1
    fi
    
    echo "$output"
    return 0
}

# Check if a URL exists and is accessible
url_exists() {
    local url="$1"
    local status_code
    
    if command -v curl >/dev/null; then
        status_code=$(curl -s -o /dev/null -w "%{http_code}" -L --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || echo "000")
    elif command -v wget >/dev/null; then
        status_code=$(wget --spider -S "$url" 2>&1 | grep "HTTP/" | awk '{print $2}' | tail -n1)
        [ -z "$status_code" ] && status_code="000"
    else
        ui_error "Neither curl nor wget is available for URL checking"
        return 1
    fi
    
    # Check if status code is 2xx or 3xx
    [[ "$status_code" =~ ^[23][0-9]{2}$ ]] && return 0 || return 1
}

# Get the size of a remote file
get_remote_file_size() {
    local url="$1"
    local size=0
    
    if command -v curl >/dev/null; then
        size=$(curl -sI -L "$url" | grep -i 'content-length' | awk '{print $2}' | tr -d '\r')
    elif command -v wget >/dev/null; then
        size=$(wget --spider --server-response -O - "$url" 2>&1 | grep -i 'content-length' | awk '{print $2}' | tail -n1)
    fi
    
    # Convert to bytes (remove commas if present)
    size=$(echo "$size" | tr -d ',')
    
    # Return 0 if size is not a number
    [[ "$size" =~ ^[0-9]+$ ]] && echo "$size" || echo "0"
}
