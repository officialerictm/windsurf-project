# ==============================================================================
# USB Health Monitoring
# ==============================================================================
# Description: Track and report on USB drive health and lifecycle
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,03_filesystem/device.sh
# ==============================================================================

# Load USB health data from a device
load_usb_health_data() {
    local partition="$1"
    local tmp_mount
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        return 0
    fi
    
    log_message "DEBUG" "Loading USB health data from $partition"
    
    # Create a temporary mount point
    tmp_mount="$TMP_DIR/usb_health_mount"
    mkdir -p "$tmp_mount"
    
    # Reset health variables
    USB_MODEL=""
    USB_SERIAL=""
    USB_FIRST_USE_DATE=""
    USB_WRITE_CYCLE_COUNTER=0
    USB_TOTAL_BYTES_WRITTEN=0
    USB_ESTIMATED_LIFESPAN=0
    
    # Mount the partition
    if mount "$partition" "$tmp_mount"; then
        # Check if health data file exists
        USB_HEALTH_DATA_FILE="$tmp_mount/.leonardo_data/health.json"
        
        if [[ -f "$USB_HEALTH_DATA_FILE" ]]; then
            # Extract data using grep and sed (avoid jq dependency)
            USB_MODEL=$(grep -o '"model": "[^"]*"' "$USB_HEALTH_DATA_FILE" | sed 's/"model": "\(.*\)"/\1/')
            USB_SERIAL=$(grep -o '"serial": "[^"]*"' "$USB_HEALTH_DATA_FILE" | sed 's/"serial": "\(.*\)"/\1/')
            USB_FIRST_USE_DATE=$(grep -o '"first_use": "[^"]*"' "$USB_HEALTH_DATA_FILE" | sed 's/"first_use": "\(.*\)"/\1/')
            USB_WRITE_CYCLE_COUNTER=$(grep -o '"write_cycles": [0-9]*' "$USB_HEALTH_DATA_FILE" | sed 's/"write_cycles": \(.*\)/\1/')
            USB_TOTAL_BYTES_WRITTEN=$(grep -o '"total_bytes_written": [0-9]*' "$USB_HEALTH_DATA_FILE" | sed 's/"total_bytes_written": \(.*\)/\1/')
            USB_ESTIMATED_LIFESPAN=$(grep -o '"estimated_lifespan": [0-9]*' "$USB_HEALTH_DATA_FILE" | sed 's/"estimated_lifespan": \(.*\)/\1/')
            
            log_message "INFO" "Loaded USB health data: $USB_MODEL, cycles: $USB_WRITE_CYCLE_COUNTER/$USB_ESTIMATED_LIFESPAN"
        else
            log_message "WARNING" "No health data found for $partition"
        fi
        
        # Unmount the partition
        umount "$tmp_mount"
    else
        log_message "ERROR" "Failed to mount $partition to read health data"
    fi
    
    # Remove the temporary mount point
    rmdir "$tmp_mount"
    
    return 0
}

# Update USB health data after a write operation
update_usb_health_data() {
    local partition="$1"
    local bytes_written="${2:-0}"
    local tmp_mount
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        return 0
    fi
    
    log_message "DEBUG" "Updating USB health data on $partition"
    
    # Load current health data first
    load_usb_health_data "$partition"
    
    # Increment write cycle counter
    USB_WRITE_CYCLE_COUNTER=$((USB_WRITE_CYCLE_COUNTER + 1))
    
    # Add bytes written
    USB_TOTAL_BYTES_WRITTEN=$((USB_TOTAL_BYTES_WRITTEN + bytes_written))
    
    # Create a temporary mount point
    tmp_mount="$TMP_DIR/usb_health_mount"
    mkdir -p "$tmp_mount"
    
    # Mount the partition
    if mount "$partition" "$tmp_mount"; then
        # Create the health data directory if it doesn't exist
        mkdir -p "$tmp_mount/.leonardo_data"
        
        # Set the health data file path
        USB_HEALTH_DATA_FILE="$tmp_mount/.leonardo_data/health.json"
        
        # Create or update the health data file
        cat > "$USB_HEALTH_DATA_FILE" << EOF
{
  "device": {
    "model": "$USB_MODEL",
    "serial": "$USB_SERIAL",
    "first_use": "$USB_FIRST_USE_DATE",
    "estimated_lifespan": $USB_ESTIMATED_LIFESPAN
  },
  "usage": {
    "write_cycles": $USB_WRITE_CYCLE_COUNTER,
    "total_bytes_written": $USB_TOTAL_BYTES_WRITTEN,
    "last_updated": "$(date +%Y-%m-%d)"
  },
  "history": [
    {"date": "$(date +%Y-%m-%d)", "bytes_written": $bytes_written, "operation": "write"}
  ]
}
EOF
        
        # Unmount the partition
        umount "$tmp_mount"
        
        log_message "INFO" "Updated USB health data: cycles=$USB_WRITE_CYCLE_COUNTER, bytes=$USB_TOTAL_BYTES_WRITTEN"
    else
        log_message "ERROR" "Failed to mount $partition to update health data"
    fi
    
    # Remove the temporary mount point
    rmdir "$tmp_mount"
    
    return 0
}

# Display USB health status
display_usb_health() {
    local partition="$1"
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        echo -e "${YELLOW}USB health tracking is disabled${NC}"
        return 0
    fi
    
    # Load health data
    load_usb_health_data "$partition"
    
    # Check if we have health data
    if [[ -z "$USB_MODEL" || -z "$USB_FIRST_USE_DATE" ]]; then
        echo -e "${RED}No health data found for this device${NC}"
        return 1
    fi
    
    # Calculate health percentage
    local health_percent=0
    if [[ $USB_ESTIMATED_LIFESPAN -gt 0 ]]; then
        health_percent=$(( 100 - (USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN) ))
        # Ensure it's not negative
        if [[ $health_percent -lt 0 ]]; then
            health_percent=0
        fi
    fi
    
    # Determine health status and color
    local health_status
    local health_color
    
    if [[ $health_percent -ge 75 ]]; then
        health_status="Excellent"
        health_color="$GREEN"
    elif [[ $health_percent -ge 50 ]]; then
        health_status="Good"
        health_color="$CYAN"
    elif [[ $health_percent -ge 25 ]]; then
        health_status="Fair"
        health_color="$YELLOW"
    else
        health_status="Poor"
        health_color="$RED"
    fi
    
    # Format total bytes written
    local bytes_human
    if [[ $USB_TOTAL_BYTES_WRITTEN -ge 1073741824 ]]; then
        # GB
        bytes_human="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN / 1073741824" | bc) GB"
    elif [[ $USB_TOTAL_BYTES_WRITTEN -ge 1048576 ]]; then
        # MB
        bytes_human="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN / 1048576" | bc) MB"
    elif [[ $USB_TOTAL_BYTES_WRITTEN -ge 1024 ]]; then
        # KB
        bytes_human="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN / 1024" | bc) KB"
    else
        # Bytes
        bytes_human="$USB_TOTAL_BYTES_WRITTEN bytes"
    fi
    
    # Calculate age in days
    local first_use_sec=$(date -d "$USB_FIRST_USE_DATE" +%s 2>/dev/null || echo 0)
    local today_sec=$(date +%s)
    local age_days=$(( (today_sec - first_use_sec) / 86400 ))
    
    # Display health information in a box
    print_box_header "USB Drive Health Report" "$UI_WIDTH" "$health_color"
    
    # Basic device info
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Device:" "$USB_MODEL" $((UI_WIDTH - 30 - ${#USB_MODEL})) ""
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Serial:" "$USB_SERIAL" $((UI_WIDTH - 30 - ${#USB_SERIAL})) ""
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC} (%d days)%*s ${health_color}${BOX_V}${NC}\n" "First used:" "$USB_FIRST_USE_DATE" "$age_days" $((UI_WIDTH - 40 - ${#USB_FIRST_USE_DATE})) ""
    
    # Separator
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$health_color"
    
    # Health status
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}${health_color}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Health status:" "$health_status" $((UI_WIDTH - 35 - ${#health_status})) ""
    
    # Health bar
    local bar_width=$((UI_WIDTH - 30))
    local filled_width=$((bar_width * health_percent / 100))
    local empty_width=$((bar_width - filled_width))
    
    printf "${health_color}${BOX_V}${NC} %-20s [" "Health remaining:"
    printf "${health_color}%${filled_width}s${NC}" | tr ' ' '#'
    printf "${DIM}%${empty_width}s${NC}" | tr ' ' '-'
    printf "] ${BOLD}%d%%${NC}%*s ${health_color}${BOX_V}${NC}\n" "$health_percent" $((UI_WIDTH - bar_width - 30)) ""
    
    # Write cycles
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%d${NC} of %d (%.1f%%)%*s ${health_color}${BOX_V}${NC}\n" "Write cycles:" "$USB_WRITE_CYCLE_COUNTER" "$USB_ESTIMATED_LIFESPAN" "$(echo "scale=1; $USB_WRITE_CYCLE_COUNTER * 100 / $USB_ESTIMATED_LIFESPAN" | bc)" $((UI_WIDTH - 50)) ""
    
    # Total data written
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Total data written:" "$bytes_human" $((UI_WIDTH - 30 - ${#bytes_human})) ""
    
    # Recommendations
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$health_color"
    
    local recommendation
    if [[ $health_percent -lt 25 ]]; then
        recommendation="Consider replacing this drive soon. It has exceeded 75% of its expected lifetime."
    elif [[ $health_percent -lt 50 ]]; then
        recommendation="This drive has used more than half of its expected lifetime. Plan for future replacement."
    else
        recommendation="This drive is in good health and should continue to function well."
    fi
    
    printf "${health_color}${BOX_V}${NC} ${BOLD}Recommendation:${NC}%*s ${health_color}${BOX_V}${NC}\n" $((UI_WIDTH - 18)) ""
    print_box_content "  $recommendation" "$UI_WIDTH" "$health_color" 2 2
    
    # Footer
    print_box_footer "$UI_WIDTH" "$health_color"
}

# Verify USB health and make recommendations
verify_usb_health() {
    local partition="$1"
    
    # Load health data
    load_usb_health_data "$partition"
    
    # Check if we have health data
    if [[ -z "$USB_MODEL" || -z "$USB_FIRST_USE_DATE" ]]; then
        return 1
    fi
    
    # Calculate health percentage
    local health_percent=0
    if [[ $USB_ESTIMATED_LIFESPAN -gt 0 ]]; then
        health_percent=$(( 100 - (USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN) ))
        # Ensure it's not negative
        if [[ $health_percent -lt 0 ]]; then
            health_percent=0
        fi
    fi
    
    # Return health code
    if [[ $health_percent -ge 75 ]]; then
        return 0  # Excellent
    elif [[ $health_percent -ge 50 ]]; then
        return 1  # Good
    elif [[ $health_percent -ge 25 ]]; then
        return 2  # Fair
    else
        return 3  # Poor
    fi
}
