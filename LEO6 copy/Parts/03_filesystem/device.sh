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
    
    # Use lsblk to find USB devices
    while IFS= read -r line; do
        # Skip if empty
        [ -z "$line" ] && continue
        
        # Parse line (path, size, model, transport, removable)
        local path size model transport removable
        read -r path size model transport removable <<< "$line"
        
        # Only include USB devices with removable flag
        if [[ "$transport" == "usb" && "$removable" == "1" ]]; then
            # Add the device to our arrays
            _CASCADE_USB_PATHS+=("$path")
            
            # Clean up model name (replace underscores with spaces)
            model="${model//_/ }"
            
            # Create display string
            local display_string="${path} (${size} - ${model})"
            _CASCADE_USB_DISPLAY_STRINGS+=("$display_string")
            
            log_message "DEBUG" "Found USB device: $display_string"
        fi
    done < <(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | sort)
    
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
    # Show step banner
    print_step_banner "1" "Select USB Device"
    
    # Show scanning message
    echo -e "${CYAN}Scanning for USB devices...${NC}"
    echo ""
    
    # Get the list of USB devices
    if ! list_usb_devices; then
        echo -e "${RED}No USB devices found.${NC}"
        echo ""
        echo "Please connect a USB drive and try again."
        echo ""
        wait_for_key "Press any key to rescan or Ctrl+C to exit..."
        return 1
    fi
    
    # Show the list of devices
    echo -e "${CYAN}Available USB devices:${NC}"
    echo ""
    
    local i
    for i in "${!_CASCADE_USB_DISPLAY_STRINGS[@]}"; do
        echo "  $((i+1)). ${_CASCADE_USB_DISPLAY_STRINGS[$i]}"
    done
    
    # Option for manual entry
    echo "  m. Enter device path manually"
    echo ""
    
    # Get user selection
    local selection
    local device_path
    while true; do
        echo -n "Select a device (1-${#_CASCADE_USB_PATHS[@]}, m): "
        read -r selection
        
        # Manual entry
        if [[ "$selection" == "m" || "$selection" == "M" ]]; then
            echo -n "Enter device path (e.g., /dev/sdb): "
            read -r device_path
            
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
    
    # Get device info
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
