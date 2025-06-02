# ==============================================================================
# Device Management
# ==============================================================================
# Description: USB device detection, selection, and verification
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,02_ui/warnings.sh
# ==============================================================================

# Check if a path is a block device
# Returns 0 if it is, 1 if not
is_block_device() {
    local device_path="$1"
    
    if [[ -b "$device_path" ]]; then
        log_message "DEBUG" "Device $device_path is a block device"
        return 0
    else
        log_message "DEBUG" "Device $device_path is NOT a block device"
        return 1
    fi
}

# List all USB devices and populate global arrays
# Based on memory 8c229535 and c41e31f6
list_usb_devices() {
    log_message "DEBUG" "Scanning for USB devices"
    
    # Reset global arrays
    _CASCADE_USB_PATHS=()
    _CASCADE_USB_DISPLAY_STRINGS=()
    
    # In test mode, add a test device and return early
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        log_message "DEBUG" "Test mode: Adding dummy test device"
        _CASCADE_USB_PATHS+=("/dev/testdisk")
        _CASCADE_USB_DISPLAY_STRINGS+=("TestDisk (16G - Leonardo Test Device)")
        return 0
    fi
    
    # Get list of all block devices
    echo "DEBUG: list_usb_devices - About to run lsblk" >&2
    log_message "DEBUG" "Running lsblk to get device list"
    local lsblk_output
    lsblk_output=$(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null)
    echo "DEBUG: list_usb_devices - lsblk command finished." >&2
    log_message "DEBUG" "lsblk output: $lsblk_output"
    echo "DEBUG: list_usb_devices - lsblk output captured:" >&2
    echo "$lsblk_output" >&2
    
    # Process each device from lsblk output
    echo "DEBUG: list_usb_devices - Starting to process lsblk output lines." >&2
    local line_num=0
    while IFS= read -r line; do
        echo "DEBUG: list_usb_devices - Processing line #$line_num: [$line]" >&2
        line_num=$((line_num + 1))

        # Robust parsing using Bash regex for: NAME SIZE MODEL TRAN RM
        # Example line: /dev/sdc    114.6G Cruzer Glide            usb     1
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)[[:space:]]+(usb|sata|ide|scsi|nvme)[[:space:]]+([01])$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local size="${BASH_REMATCH[2]}"
            local model="${BASH_REMATCH[3]}"
            local tran="${BASH_REMATCH[4]}"
            local rm="${BASH_REMATCH[5]}"

            # Trim whitespace from model
            model=$(echo "$model" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -z "$model" ]; then
                model="-" # Placeholder if model is empty
            fi
            echo "DEBUG: list_usb_devices - Parsed: NAME='$name', SIZE='$size', MODEL='$model', TRAN='$tran', RM='$rm'" >&2
        else
            echo "DEBUG: list_usb_devices - Failed to parse line with regex: [$line]" >&2
            continue
        fi

        # Filter for USB devices that are removable
        if [[ "$tran" == "usb" && "$rm" == "1" ]]; then
            if [ -z "$name" ] || [ ! -b "$name" ]; then
                echo "DEBUG: list_usb_devices - Invalid device path or not a block device: [$name]. Skipping." >&2
                continue
            fi
            _CASCADE_USB_PATHS+=("$name")
            local display_string
            printf -v display_string "%-12s %-25.25s %s" "$name" "$model" "$size"
            _CASCADE_USB_DISPLAY_STRINGS+=("$display_string")
            echo "DEBUG: list_usb_devices - Added USB: $display_string" >&2
        else
            echo "DEBUG: list_usb_devices - Skipped (not USB or not removable): $name ($tran, $rm)" >&2
        fi
    done < <(echo "$lsblk_output")
        # Redundant block removed
    echo "DEBUG: list_usb_devices - Finished processing lsblk output lines." >&2
    
    # Log the found devices
    log_message "DEBUG" "Found ${#_CASCADE_USB_PATHS[@]} USB devices"
    
    # Return success if we found any devices
    if [[ ${#_CASCADE_USB_PATHS[@]} -gt 0 ]]; then
        log_message "INFO" "Found ${#_CASCADE_USB_PATHS[@]} USB devices"
        return 0
    else
        log_message "WARNING" "No USB devices found"
        return 1
    fi
}

# Show a menu to select a USB device
# Based on memory c41e31f6
select_usb_device() {
    # Check if we're in test mode - if so, handle test device selection
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        # If LEONARDO_TEST_USB is set, use that as the real device for testing
        if [[ -n "${LEONARDO_TEST_USB:-}" ]]; then
            log_message "DEBUG" "Test mode: using real USB device ${LEONARDO_TEST_USB}"
            echo "${LEONARDO_TEST_USB}"
            return 0
        else
            # Default test device if no real device specified
            log_message "DEBUG" "Test mode: auto-selecting test device /dev/testdisk"
            echo "/dev/testdisk"
            return 0
        fi
    fi
    
    # Show step banner
    print_step_banner "1" "Select USB Device"
    
    # Show scanning message
    echo -e "${CYAN}Scanning for USB devices...${NC}"
    echo ""
    
    # Get the list of USB devices
    echo "DEBUG: select_usb_device - About to call list_usb_devices" >&2
    if ! list_usb_devices; then
        echo "DEBUG: select_usb_device - list_usb_devices returned failure" >&2
        echo -e "${RED}No USB devices found.${NC}"
        echo ""
        echo "Please connect a USB drive and try again."
        echo ""
        wait_for_key "Press any key to rescan or Ctrl+C to exit..."
        return 1
    fi
    echo "DEBUG: select_usb_device - list_usb_devices returned successfully" >&2
    
    # Show the list of devices
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ]; then
        echo "No USB devices found." >/dev/tty # Output to TTY for user visibility
        echo "Please ensure your USB device is properly connected." >/dev/tty
        echo "Listing all block devices for diagnostics:" >&2 # Debug to stderr
        lsblk -dpno NAME,SIZE,MODEL,TRAN,RM >&2
        return 1
    fi

    echo "Available USB devices:" >/dev/tty
    printf "  %s   %-12s %-25s %s\n" "Num" "Device" "Model" "Size" >/dev/tty
    printf "  %s   %-12s %-25s %s\n" "--- " "------------" "-------------------------" "----" >/dev/tty
    for i in "${!_CASCADE_USB_DISPLAY_STRINGS[@]}"; do
        printf "  %2d) %s\n" "$((i+1))" "${_CASCADE_USB_DISPLAY_STRINGS[i]}" >/dev/tty
    done
    echo "" >/dev/tty # Extra newline for spacing
    
    # Option for manual entry
    echo "  m. Enter device path manually"
    echo ""
    
    # Get user selection
    local selection
    local device_path
    echo "DEBUG: select_usb_device - Entering selection loop" >&2
    while true; do
        echo "DEBUG: select_usb_device - Top of selection loop" >&2
        local prompt_msg="Select a device (1-${#_CASCADE_USB_PATHS[@]}, m for manual, q to quit): "
        echo "DEBUG: select_usb_device - About to get selection using get_user_input with prompt: [$prompt_msg]" >&2
        get_user_input "$prompt_msg" selection
        echo "DEBUG: select_usb_device - Read selection: [$selection]" >&2
        
        # Manual entry
        if [[ "$selection" == "m" || "$selection" == "M" ]]; then
            local manual_prompt_msg="Enter device path (e.g., /dev/sdb, or q to return): "
            echo "DEBUG: select_usb_device - About to get manual device_path using get_user_input with prompt: [$manual_prompt_msg]" >&2
            get_user_input "$manual_prompt_msg" device_path
            echo "DEBUG: select_usb_device - Read manual device_path: [$device_path]" >&2
            
            # Verify it's a block device
            if is_block_device "$device_path"; then
                break
            else
                echo -e "${RED}Not a valid block device.${NC} Please try again."
            fi
        # Numeric selection
        elif [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#_CASCADE_USB_PATHS[@]}" ]]; then
            device_path="${_CASCADE_USB_PATHS[$((selection-1))]}"
            break
        else
            echo -e "${RED}Invalid selection.${NC} Please try again."
        fi
    done
    
    # Return the selected device path
    echo "$device_path"
    return 0
}

# Verify a USB device selection with the user
verify_usb_device() {
    local device_path="$1"
    
    # In test mode, auto-confirm the device
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        # If we're using a real USB device in test mode
        if [[ -n "${LEONARDO_TEST_USB:-}" && "$device_path" == "${LEONARDO_TEST_USB}" ]]; then
            log_message "INFO" "Test mode: auto-confirming real USB device $device_path"
            
            # Show real device info if available
            echo ""
            echo -e "${CYAN}Selected real USB device (in test mode):${NC}"
            echo "  Device path: $device_path"
            
            # Try to get real device info if possible
            local size model vendor partitions
            size=$(lsblk -dn -o SIZE "$device_path" 2>/dev/null || echo "Unknown")
            model=$(lsblk -dn -o MODEL "$device_path" 2>/dev/null || echo "Unknown")
            vendor=$(lsblk -dn -o VENDOR "$device_path" 2>/dev/null || echo "Unknown")
            partitions=$(lsblk -ln "$device_path" 2>/dev/null | grep -v "^$(basename "$device_path")" | wc -l)
            
            echo "  Size: $size"
            echo "  Model: $model"
            echo "  Vendor: $vendor"
            echo "  Partitions: $partitions"
            echo ""
            echo -e "${YELLOW}Test mode: Real device automatically confirmed. NO ACTUAL FORMATTING will be performed.${NC}"
            return 0
        else
            # Use dummy test device info
            log_message "INFO" "Test mode: auto-confirming test device $device_path"
            
            # Show test device info
            echo ""
            echo -e "${CYAN}Selected test device details:${NC}"
            echo "  Device path: $device_path"
            echo "  Size: 16G (Test Device)"
            echo "  Model: Leonardo Test Device"
            echo "  Vendor: Test"
            echo "  Partitions: 0"
            echo ""
            echo -e "${YELLOW}Test mode: Device automatically confirmed.${NC}"
            return 0
        fi
    fi
    
    # Get device info for real device
    local device_size
    local device_model
    local device_vendor
    local device_parts
    
    device_size=$(lsblk -dno SIZE "$device_path" 2>/dev/null || echo "Unknown")
    device_model=$(lsblk -dno MODEL "$device_path" 2>/dev/null || echo "Unknown")
    device_vendor=$(lsblk -dno VENDOR "$device_path" 2>/dev/null || echo "Unknown")
    device_parts=$(lsblk -no NAME "$device_path" | grep -v "$(basename "$device_path")" | wc -l)
    
    # Clean up model name
    device_model="${device_model//_/ }"
    
    # Show device details
    echo ""
    echo -e "${CYAN}Selected device details:${NC}"
    echo "  Device path: $device_path"
    echo "  Size: $device_size"
    echo "  Model: $device_model"
    echo "  Vendor: $device_vendor"
    echo "  Partitions: $device_parts"
    echo ""
    
    # Confirm selection
    local message="You have selected $device_path ($device_size - $device_model).\nVerify this is the correct device before proceeding."
    if confirm_action "$message" "caution"; then
        log_message "INFO" "User confirmed device selection: $device_path"
        return 0
    else
        log_message "INFO" "User cancelled device selection"
        return 1
    fi
}

# Get device information for health tracking
get_device_info() {
    local device_path="$1"
    local info_type="$2"  # size, model, serial, vendor, etc.
    
    case "$info_type" in
        "size")
            lsblk -dno SIZE "$device_path" 2>/dev/null || echo "Unknown"
            ;;
        "model")
            lsblk -dno MODEL "$device_path" 2>/dev/null || echo "Unknown"
            ;;
        "serial")
            # Try to get serial number (requires root)
            local serial
            serial=$(udevadm info --query=property --name="$device_path" 2>/dev/null | grep ID_SERIAL= | cut -d= -f2)
            echo "${serial:-Unknown}"
            ;;
        "vendor")
            lsblk -dno VENDOR "$device_path" 2>/dev/null || echo "Unknown"
            ;;
        "partitions")
            lsblk -no NAME "$device_path" | grep -v "$(basename "$device_path")" | wc -l
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Get all mounted partitions for a device
get_device_partitions() {
    local device_path="$1"
    local base_name
    base_name=$(basename "$device_path")
    
    # Get all partitions
    lsblk -no NAME "$device_path" | grep -v "^$base_name$" | sed "s|^|/dev/|"
}

# Force unmount all partitions on a device
# Based on memory dd2b60d3
force_unmount_device() {
    local device_path="$1"
    local force="${2:-false}"
    local quiet="${3:-false}"
    local retries=3
    local success=false
    
    log_message "INFO" "Unmounting device: $device_path"
    
    # Function to log or echo based on quiet flag
    local _log_or_echo
    _log_or_echo() {
        log_message "INFO" "$1"
        if [[ "$quiet" != "true" ]]; then
            echo -e "$1"
        fi
    }
    
    # Get all partitions for this device
    local partitions=()
    mapfile -t partitions < <(get_device_partitions "$device_path")
    
    # Add the device itself to the list
    partitions+=("$device_path")
    
    # If there are no partitions, just return
    if [[ ${#partitions[@]} -eq 0 ]]; then
        _log_or_echo "No partitions found for $device_path"
        return 0
    fi
    
    _log_or_echo "Unmounting ${#partitions[@]} partitions on $device_path"
    
    for ((retry=1; retry<=retries; retry++)); do
        local all_unmounted=true
        
        # First try: Kill processes using the device
        if [[ "$retry" -ge 2 ]]; then
            _log_or_echo "Attempt $retry: Killing processes using the device..."
            for part in "${partitions[@]}"; do
                fuser -k "$part" 2>/dev/null || true
                lsof "$part" 2>/dev/null | awk '{print $2}' | grep -v PID | xargs -r kill 2>/dev/null || true
            done
        fi
        
        # Unmount all partitions
        for part in "${partitions[@]}"; do
            if mount | grep -q "$part "; then
                _log_or_echo "Unmounting $part..."
                
                # Try umount first
                if umount "$part" 2>/dev/null; then
                    _log_or_echo "Successfully unmounted $part"
                # If that fails and force is true, try more aggressive methods
                elif [[ "$force" == "true" ]]; then
                    _log_or_echo "Trying lazy unmount for $part..."
                    if umount -l "$part" 2>/dev/null; then
                        _log_or_echo "Successfully lazy-unmounted $part"
                    else
                        _log_or_echo "Failed to unmount $part (attempt $retry/$retries)"
                        all_unmounted=false
                    fi
                else
                    _log_or_echo "Failed to unmount $part (attempt $retry/$retries)"
                    all_unmounted=false
                fi
            fi
        done
        
        # If all partitions are unmounted, we're done
        if [[ "$all_unmounted" == "true" ]]; then
            success=true
            break
        fi
        
        # Sleep before next attempt
        sleep 2
    done
    
    # Try to reload the partition table
    if [[ "$success" == "true" || "$force" == "true" ]]; then
        _log_or_echo "Reloading partition table for $device_path..."
        
        # Try multiple methods (based on memory dd2b60d3)
        partprobe "$device_path" 2>/dev/null || true
        blockdev --rereadpt "$device_path" 2>/dev/null || true
        hdparm -z "$device_path" 2>/dev/null || true
        
        # Wait for device to settle
        udevadm settle 2>/dev/null || true
        sleep 1
        
        # Extra aggressive approach for stubborn devices
        if [[ "$force" == "true" ]]; then
            echo 1 > "/sys/block/$(basename "$device_path")/device/delete" 2>/dev/null || true
            sleep 1
            echo "- - -" > /sys/class/scsi_host/host*/scan 2>/dev/null || true
            udevadm settle 2>/dev/null || true
            sleep 2
        fi
    fi
    
    if [[ "$success" == "true" ]]; then
        _log_or_echo "Successfully unmounted device $device_path"
        return 0
    else
        _log_or_echo "Failed to unmount all partitions on $device_path after $retries attempts"
        return 1
    fi
}

# Format a USB device
format_usb_device() {
    local device_path="$1"
    local fs_type="${2:-$DEFAULT_FS_TYPE}"
    local part_type="${3:-$DEFAULT_PARTITION_TABLE}"
    local label="${4:-LEONARDO}"
    local force="${5:-false}"
    
    log_message "INFO" "Formatting device $device_path with $fs_type filesystem"
    
    # Confirm formatting with a danger warning
    local message="You are about to format $device_path with $fs_type filesystem.\nAll data on this device will be PERMANENTLY LOST."
    if ! verify_dangerous_operation "$message" "$device_path" "Format with $fs_type"; then
        log_message "INFO" "Format operation cancelled by user"
        return 1
    fi
    
    # Force unmount the device
    echo -e "${YELLOW}Unmounting device $device_path...${NC}"
    if ! force_unmount_device "$device_path" "true" "false"; then
        log_message "ERROR" "Failed to unmount device $device_path"
        print_error "Failed to unmount device $device_path. The device may be in use."
        return 1
    fi
    
    # Create a new partition table
    echo -e "${YELLOW}Creating new $part_type partition table...${NC}"
    if [[ "$part_type" == "gpt" ]]; then
        # GPT partition table
        parted -s "$device_path" mklabel gpt
    else
        # MBR/msdos partition table
        parted -s "$device_path" mklabel msdos
    fi
    
    # Create a single partition using the entire disk
    echo -e "${YELLOW}Creating partition...${NC}"
    parted -s "$device_path" mkpart primary 1MiB 100%
    
    # Get the partition name
    local partition
    if [[ "$device_path" == *"nvme"* ]]; then
        # NVMe naming convention (e.g., nvme0n1p1)
        partition="${device_path}p1"
    else
        # SCSI/SATA naming convention (e.g., sda1)
        partition="${device_path}1"
    fi
    
    # Wait for the partition to be created
    echo -e "${YELLOW}Waiting for partition to be recognized...${NC}"
    sleep 2
    udevadm settle
    
    # Format the partition with the requested filesystem
    echo -e "${YELLOW}Formatting partition with $fs_type...${NC}"
    case "$fs_type" in
        "exfat")
            mkfs.exfat -n "$label" "$partition"
            ;;
        "ntfs")
            mkfs.ntfs -f -L "$label" "$partition"
            ;;
        "ext4")
            mkfs.ext4 -L "$label" "$partition"
            ;;
        "fat32"|"vfat")
            mkfs.vfat -F 32 -n "$label" "$partition"
            ;;
        *)
            log_message "ERROR" "Unsupported filesystem type: $fs_type"
            print_error "Unsupported filesystem type: $fs_type"
            return 1
            ;;
    esac
    
    # Verify the format was successful
    if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to format partition $partition with $fs_type"
        print_error "Failed to format partition $partition with $fs_type"
        return 1
    fi
    
    # Create a health tracking file on the device
    echo -e "${YELLOW}Creating USB health tracking information...${NC}"
    track_usb_health_start "$device_path" "$partition"
    
    # Show success message
    print_success "Device $device_path has been successfully formatted with $fs_type filesystem."
    log_message "INFO" "Successfully formatted $device_path with $fs_type"
    
    # Return the partition name
    echo "$partition"
    return 0
}

# Initialize USB health tracking
track_usb_health_start() {
    local device_path="$1"
    local partition="$2"
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        return 0
    fi
    
    # Get device information
    USB_MODEL=$(get_device_info "$device_path" "model")
    USB_SERIAL=$(get_device_info "$device_path" "serial")
    USB_FIRST_USE_DATE=$(date +%Y-%m-%d)
    USB_WRITE_CYCLE_COUNTER=0
    USB_TOTAL_BYTES_WRITTEN=0
    
    # Estimate lifespan based on device type
    if [[ "$USB_MODEL" =~ [Ss][Ss][Dd] ]]; then
        # SSD typically has higher write endurance
        USB_ESTIMATED_LIFESPAN=3000
    else
        # Flash drives have lower write endurance
        USB_ESTIMATED_LIFESPAN=1000
    fi
    
    # Create a temporary mount point
    local tmp_mount
    tmp_mount="$TMP_DIR/usb_health_mount"
    mkdir -p "$tmp_mount"
    
    # Mount the partition
    if mount "$partition" "$tmp_mount"; then
        # Create the health data directory
        mkdir -p "$tmp_mount/.leonardo_data"
        
        # Set the health data file path
        USB_HEALTH_DATA_FILE="$tmp_mount/.leonardo_data/health.json"
        
        # Create the health data file
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
  "history": []
}
EOF
        
        # Unmount the partition
        umount "$tmp_mount"
    fi
    
    # Remove the temporary mount point
    rmdir "$tmp_mount"
    
    log_message "INFO" "Initialized USB health tracking for $device_path"
}
