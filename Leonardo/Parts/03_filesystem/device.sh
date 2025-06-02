# ==============================================================================
# Filesystem Device Operations
# ==============================================================================

# Global arrays to store discovered USB device paths and their display strings
_CASCADE_USB_PATHS=()
_CASCADE_USB_DISPLAY_STRINGS=()

# Check if a given path is a block device
# Returns 0 if it's a block device, 1 otherwise.
# This version includes multiple verification methods for robustness.
is_block_device() {
    local device_path="$1"
    
    # Debug output to verify function is called with correct arguments
    # echo "DEBUG: is_block_device() called with: '$device_path'" >&2
    
    # Check for empty input
    if [ -z "$device_path" ]; then
        # echo "DEBUG: is_block_device: Empty device path provided" >&2
        return 1
    fi
    
    # Clean up the device path - remove any surrounding whitespace or quotes
    device_path=$(echo "$device_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Add /dev/ prefix if not present and it looks like a device name
    if [[ ! "$device_path" =~ ^/dev/ ]] && [[ "$device_path" =~ ^[sh]d[a-z]|nvme[0-9]n[0-9]|mmcblk[0-9] ]]; then
        device_path="/dev/$device_path"
        # echo "DEBUG: Added /dev/ prefix, now: '$device_path'" >&2
    fi
    
    # Debug output for final path being checked
    # echo "DEBUG: is_block_device: Testing path: '$device_path'" >&2
    
    # Method 1: Direct block device test
    if [ -b "$device_path" ]; then
        # echo "DEBUG: is_block_device: PASSED -b test for '$device_path'" >&2
        return 0  # Success - it's a block device
    else
        # echo "DEBUG: is_block_device: FAILED -b test for '$device_path'" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Method 2: Check using ls -l (looks for 'b' as first character)
    if ls -l "$device_path" 2>/dev/null | grep -q '^b'; then
        # echo "DEBUG: is_block_device: PASSED ls -l test for '$device_path'" >&2
        return 0  # Success - it's a block device
    else
        # echo "DEBUG: is_block_device: FAILED ls -l test for '$device_path'" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Method 3: Check using stat if available
    if command -v stat >/dev/null 2>&1; then
        if stat -c '%F' "$device_path" 2>/dev/null | grep -q 'block special'; then
            # echo "DEBUG: is_block_device: PASSED stat test for '$device_path'" >&2
            return 0  # Success - it's a block device
        else
            # echo "DEBUG: is_block_device: FAILED stat test for '$device_path'" >&2
            : # No-op for potentially sensitive parsers
        fi
    fi
    
    # Method 4: Check if it's a partition of a block device
    local parent_dev
    parent_dev=$(echo "$device_path" | sed -E 's/[0-9]+$//' | sed -E 's/p[0-9]+$//')
    
    if [ "$parent_dev" != "$device_path" ] && [ -b "$parent_dev" ]; then
        # echo "DEBUG: is_block_device: '$device_path' appears to be a partition of block device '$parent_dev'" >&2
        return 0  # Accept partitions of block devices
    else
        # echo "DEBUG: is_block_device: Not a partition of a block device" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Method 5: Check if device exists in /sys/block or as a partition
    local basename
    basename=$(basename "$device_path")
    
    if [ -e "/sys/block/$basename" ] || 
       [ -e "/sys/block/$(echo "$basename" | sed 's/[0-9]*$//')/$(echo "$basename" | sed 's/^[^0-9]*//')" ]; then
        # echo "DEBUG: is_block_device: Found in /sys/block for '$device_path'" >&2
        return 0  # It exists in sysfs
    else
        # echo "DEBUG: is_block_device: Not found in /sys/block for '$device_path'" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # If we get here, all checks have failed
    # echo "DEBUG: is_block_device: FINAL RESULT - NOT a block device: '$device_path'" >&2
    return 1  # Failure - not a block device by any test
}

# Get the size of a block device in bytes
# Expects a validated block device path (e.g., /dev/sdb)
get_block_device_size() {
    local device_path="$1"
    if ! is_block_device "$device_path"; then # Re-validate just in case
        print_error "get_block_device_size: '$device_path' is not a valid block device." >&2
        return 1
    fi
    blockdev --getsize64 "$device_path" 2>/dev/null || {
        print_error "get_block_device_size: Failed to get size for '$device_path'." >&2
        return 1
    }
    return 0
}

# Get the filesystem type of a device or partition
# Expects a validated block device or partition path (e.g., /dev/sdb or /dev/sdb1)
get_fs_type() {
    local device_path="$1"
    # is_block_device also accepts partitions of block devices
    if ! is_block_device "$device_path"; then # Re-validate
        print_error "get_fs_type: '$device_path' is not a valid block device or partition." >&2
        return 1
    fi
    lsblk -no FSTYPE "$device_path" 2>/dev/null || {
        print_error "get_fs_type: Failed to get filesystem type for '$device_path'." >&2
        return 1
    }
    return 0
}

# List available USB/removable devices and populate global arrays.
list_usb_devices() {
    # If we're using the enhanced device selection UI, don't show the old UI
    if [ "$SKIP_DEVICE_SELECTION" = "true" ] && [ -n "$LEONARDO_DEVICE_PATH" ]; then
        # echo "DEBUG: Skipping duplicate device selection UI" >&2
        print_info "Using previously selected device: $LEONARDO_DEVICE_PATH"
        return 0
    fi

    # UI elements removed - select_usb_device will handle UI presentation
    # clear_screen_and_show_art
    # 
    # local box_width=$((UI_WIDTH - 8))
    # local step_text="STEP 1 OF 4: SELECT USB DEVICE"
    # local padding=$(( (box_width - ${#step_text}) / 2 ))
    # 
    # echo -e "${COLOR_CYAN}╔$(repeat_char "═" $((box_width + 2)))╗${COLOR_RESET}"
    # 
    # echo -e "${COLOR_CYAN}║${COLOR_RESET}$(repeat_char " " $padding)${COLOR_BOLD}${COLOR_YELLOW}${step_text}${COLOR_RESET}$(repeat_char " " $((box_width - padding - ${#step_text} + 2)))${COLOR_CYAN}║${COLOR_RESET}"
    # 
    # echo -e "${COLOR_CYAN}╚$(repeat_char "═" $((box_width + 2)))╝${COLOR_RESET}\n"
    
    # Initialize arrays
    _CASCADE_USB_PATHS=()
    _CASCADE_USB_DISPLAY_STRINGS=()
    
    # print_info "Scanning for USB/removable storage devices..." # Moved to select_usb_device
    
    # Check if we have root privileges for better device detection
    local has_root=0
    if [ "$(id -u)" -eq 0 ]; then
        has_root=1
        # echo "DEBUG: Running with root privileges" >&2
    else
        # echo "DEBUG: Running without root privileges (some devices might not be detected)" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Try different methods to detect USB/removable devices
    local device_list=""
    
    # Method 1: Try lsblk with JSON output (most reliable)
    if command -v lsblk >/dev/null 2>&1; then
        # echo "DEBUG: Trying lsblk method..." >&2
        
        # Check if lsblk supports --json
        if lsblk --help 2>&1 | grep -q -- '--json'; then
            # echo "DEBUG: lsblk supports JSON output" >&2
            
            # Get device list with all needed info
            local lsblk_output
            lsblk_output=$(lsblk -d -J -o NAME,SIZE,MODEL,VENDOR,TRAN,RM,MOUNTPOINT,LABEL,FSTYPE,UUID 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$lsblk_output" ]; then
                # Use jq to parse JSON if available
                if command -v jq >/dev/null; then
                    # echo "DEBUG: Using jq to parse lsblk JSON output" >&2
                    
                    # Process each device
                    local device_count=$(echo "$lsblk_output" | jq -r '.blockdevices | length' 2>/dev/null)
                    # echo "DEBUG: Found $device_count block devices" >&2
                    
                    for ((i=0; i<device_count; i++)); do
                        local dev_info
                        dev_info=$(echo "$lsblk_output" | jq -r ".blockdevices[$i] | \
                            [.name, .size // "unknown", .model // "Unknown", .tran // "unknown", 
                            .rm // "0", .mountpoint // "", .label // "", .fstype // "", .uuid // ""] | @tsv" 2>/dev/null)
                        
                        if [ -z "$dev_info" ]; then
                            continue
                        fi
                        
                        IFS=$'\t' read -r dev size model tran rm_flag mountpoint label fstype uuid <<< "$dev_info"
                        
                        # Skip if no device name
                        [ -z "$dev" ] && continue
                        
                        # Construct full device path
                        local dev_path="/dev/$dev"
                        
                        # Skip if not a block device
                        if [ ! -b "$dev_path" ]; then
                            echo "DEBUG: Skipping non-block device: $dev_path" >&2
                            continue
                        fi
                        
                        # Skip if it's a partition (has a number at the end)
                        if [[ "$dev" =~ [0-9]+$ ]]; then
                            echo "DEBUG: Skipping partition: $dev_path" >&2
                            continue
                        fi
                        
                        # Skip if not removable and not a USB device (unless running as non-root)
                        if [ "$rm_flag" != "1" ] && [ "$tran" != "usb" ]; then
                            # For non-root, be more permissive
                            if [ "$has_root" -eq 0 ]; then
                                echo "DEBUG: Non-root mode, including non-removable device: $dev_path" >&2
                            else
                                echo "DEBUG: Skipping non-removable, non-USB device: $dev_path" >&2
                                continue
                            fi
                        fi
                        
                        # Clean up model string
                        model=$(echo "$model" | tr -d '\n\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
                        [ -z "$model" ] && model="Unknown"
                        
                        # Add mount info if mounted
                        local mount_info=""
                        if [ -n "$mountpoint" ] && [ "$mountpoint" != "(null)" ]; then
                            mount_info=" (mounted at $mountpoint)"
                        fi
                        
                        # Add filesystem info if available
                        local fs_info=""
                        if [ -n "$fstype" ] && [ "$fstype" != "(null)" ]; then
                            fs_info=" [$fstype]"
                        fi
                        
                        # Add to arrays
                        _CASCADE_USB_PATHS+=("$dev_path")
                        _CASCADE_USB_DISPLAY_STRINGS+=("$dev_path - $size - $model$mount_info$fs_info")
                        echo "DEBUG: Added device: $dev_path - $size - $model$mount_info$fs_info" >&2
                    done
                else
                    echo "DEBUG: jq not available, falling back to text parsing" >&2
                    # Fall back to text parsing if jq is not available
                    while IFS= read -r line; do
                        if [ -n "$line" ]; then
                            local dev size model tran rm_flag
                            read -r dev size model tran rm_flag <<< "$line"
                            
                            # Skip if no device name
                            [ -z "$dev" ] && continue
                            
                            # Skip if it's a partition (has a number at the end)
                            if [[ "$dev" =~ [0-9]+$ ]]; then
                                continue
                            fi
                            
                            # Construct full device path
                            local dev_path="$dev"
                            
                            # Skip if not a block device
                            [ ! -b "$dev_path" ] && continue
                            
                            # Skip if not removable and not a USB device (unless running as non-root)
                            if [ "$rm_flag" != "1" ] && [ "$tran" != "usb" ]; then
                                # For non-root, be more permissive
                                if [ "$has_root" -eq 0 ]; then
                                    echo "DEBUG: Non-root mode, including non-removable device: $dev_path" >&2
                                else
                                    continue
                                fi
                            fi
                            
                            # Clean up model string
                            model=$(echo "$model" | tr -d '\n\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
                            [ -z "$model" ] && model="Unknown"
                            
                            # Add to arrays
                            _CASCADE_USB_PATHS+=("$dev_path")
                            _CASCADE_USB_DISPLAY_STRINGS+=("$dev_path - $size - $model")
                            echo "DEBUG: Added device: $dev_path - $size - $model" >&2
                        fi
                    done < <(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | grep -v '^$' | while read -r dev size model tran rm_flag; do
                        echo "$dev $size $model $tran $rm_flag"
                    done)
                fi
            fi
        else
            echo "DEBUG: lsblk doesn't support JSON, using text output" >&2
            # Fall back to text parsing for older lsblk versions
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    local dev size model tran rm_flag
                    read -r dev size model tran rm_flag <<< "$line"
                    
                    # Skip if no device name
                    [ -z "$dev" ] && continue
                    
                    # Skip if it's a partition (has a number at the end)
                    if [[ "$dev" =~ [0-9]+$ ]]; then
                        continue
                    fi
                    
                    # Skip if not a block device
                    [ ! -b "$dev" ] && continue
                    
                    # Skip if not removable and not a USB device (unless running as non-root)
                    if [ "$rm_flag" != "1" ] && [ "$tran" != "usb" ]; then
                        # For non-root, be more permissive
                        if [ "$has_root" -eq 0 ]; then
                            echo "DEBUG: Non-root mode, including non-removable device: $dev" >&2
                        else
                            continue
                        fi
                    fi
                    
                    # Clean up model string
                    model=$(echo "$model" | tr -d '\n\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
                    [ -z "$model" ] && model="Unknown"
                    
                    # Add to arrays
                    _CASCADE_USB_PATHS+=("$dev")
                    _CASCADE_USB_DISPLAY_STRINGS+=("$dev - $size - $model")
                    echo "DEBUG: Added device: $dev - $size - $model" >&2
                fi
            done < <(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | grep -v '^$' | while read -r dev size model tran rm_flag; do
                echo "$dev $size $model $tran $rm_flag"
            done)
        fi
    fi
    
    # Method 2: Fall back to /sys/block if lsblk fails or no devices found
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ] && [ -d "/sys/block" ]; then
        echo "DEBUG: Falling back to /sys/block detection..." >&2
        
        for dev in /sys/block/*; do
            local devname=$(basename "$dev")
            local devpath="/dev/$devname"
            
            # Skip loop devices and other non-disk devices
            if [[ "$devname" == loop* ]] || [[ "$devname" == ram* ]] || [[ "$devname" == sr* ]]; then
                echo "DEBUG: Skipping virtual device: $devpath" >&2
                continue
            fi
            
            # Skip if it's a partition (has a number at the end)
            if [[ "$devname" =~ [0-9]+$ ]]; then
                echo "DEBUG: Skipping partition: $devpath" >&2
                continue
            fi
            
            # Skip if not a block device
            if [ ! -b "$devpath" ]; then
                echo "DEBUG: Not a block device: $devpath" >&2
                continue
            fi
            
            # Check if device is removable
            local removable="0"
            if [ -f "$dev/removable" ]; then
                removable=$(cat "$dev/removable" 2>/dev/null || echo "0")
            fi
            
            # Check if device is USB
            local is_usb=0
            if [ -e "$dev/device/uevent" ] && grep -q "DRIVER=usb" "$dev/device/uevent" 2>/dev/null; then
                is_usb=1
            fi
            
            # Skip if not removable and not USB (unless running as non-root)
            if [ "$removable" != "1" ] && [ "$is_usb" != "1" ]; then
                # For non-root, be more permissive
                if [ "$has_root" -eq 0 ]; then
                    echo "DEBUG: Non-root mode, including non-removable device: $devpath" >&2
                else
                    echo "DEBUG: Skipping non-removable, non-USB device: $devpath" >&2
                    continue
                fi
            fi
            
            # Get device size
            local size="unknown"
            if [ -f "$dev/size" ]; then
                local sectors=$(cat "$dev/size" 2>/dev/null)
                if [ -n "$sectors" ] && [ "$sectors" -gt 0 ]; then
                    size=$((sectors * 512))
                    size=$(numfmt --to=si --suffix=B --format="%.1f" $size 2>/dev/null || echo "$size")
                fi
            fi
            
            # Get device model
            local model="Unknown"
            if [ -f "$dev/device/model" ]; then
                model=$(cat "$dev/device/model" 2>/dev/null | tr -d '\n\r' | sed 's/\s\+$//')
                [ -z "$model" ] && model="Unknown"
            fi
            
            # Get mount info if available
            local mount_info=""
            if command -v findmnt >/dev/null; then
                local mount_point=$(findmnt -n -o TARGET --source "$devpath" 2>/dev/null | head -1)
                if [ -n "$mount_point" ]; then
                    mount_info=" (mounted at $mount_point)"
                fi
            fi
            
            # Get filesystem info if available
            local fs_info=""
            if command -v lsblk >/dev/null; then
                local fstype=$(lsblk -no FSTYPE "$devpath" 2>/dev/null | head -1)
                if [ -n "$fstype" ]; then
                    fs_info=" [$fstype]"
                fi
            fi
            
            # Add to arrays
            _CASCADE_USB_PATHS+=("$devpath")
            _CASCADE_USB_DISPLAY_STRINGS+=("$devpath - $size - $model$mount_info$fs_info")
            echo "DEBUG: Added device: $devpath - $size - $model$mount_info$fs_info" >&2
        done
    fi
    
    # Method 3: Last resort - look for common USB device patterns
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ]; then
        echo "DEBUG: Trying last resort device detection..." >&2
        for dev in /dev/sd*; do
            # Skip if not a block device
            [ ! -b "$dev" ] && continue
            
            # Skip if it's a partition (has a number at the end)
            [[ "$dev" =~ [0-9]+$ ]] && continue
            
            # Get device info
            local size="unknown"
            if command -v blockdev >/dev/null; then
                size=$(blockdev --getsize64 "$dev" 2>/dev/null | numfmt --to=si 2>/dev/null || echo "unknown")
            fi
            
            # Add to arrays
            _CASCADE_USB_PATHS+=("$dev")
            _CASCADE_USB_DISPLAY_STRINGS+=("$dev - $size - Unknown")
            echo "DEBUG: Added device (last resort): $dev - $size - Unknown" >&2
        done
    fi

    # If no devices found, show error and return non-zero status
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ]; then
        print_warning "No suitable USB/removable storage devices detected." >&2
        echo "Please connect a USB drive and try again." >&2
        return 1
    fi

    local device_count=${#_CASCADE_USB_PATHS[@]}
    print_info "Found $device_count potential device(s)." >&2
    
    # Debug: List all devices
    print_info "Available devices:" >&2
    for i in "${!_CASCADE_USB_PATHS[@]}"; do
        print_info "  [${i}] ${_CASCADE_USB_PATHS[$i]} - ${_CASCADE_USB_DISPLAY_STRINGS[$i]}" >&2
    done
    
    # Display the device selection UI
    print_info "Rendering device selection UI..." >&2
    
    # Display friendly llama mascot with selection message
    echo -e "\n  ${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET} ${COLOR_BOLD}Please select the USB device you want to use:${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_YELLOW}All data on the selected device will be permanently erased!${COLOR_RESET}\n" > /dev/tty
    
    # Simple header for the device list
    echo -e "  ${COLOR_CYAN}╭$(repeat_char "─" $((UI_WIDTH - 12)))╮${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}#   Device        Size       Model/Description${COLOR_RESET}${COLOR_CYAN}  │${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}├$(repeat_char "─" $((UI_WIDTH - 12)))┤${COLOR_RESET}" > /dev/tty
    
    # Display devices in a simple list format
    local i
    for i in "${!_CASCADE_USB_PATHS[@]}"; do
        local dev_path="${_CASCADE_USB_PATHS[$i]}"
        local display_string="${_CASCADE_USB_DISPLAY_STRINGS[$i]}"
        
        # Extract information from display string
        local size=$(echo "$display_string" | grep -o -E ' - [0-9.]+[KMGTPE]i?B' | sed 's/^ - //' || echo "Unknown")
        local model=$(echo "$display_string" | sed -E 's/^.* - [0-9.]+[KMGTPE]?i?B - //')
        local device_name=$(basename "$dev_path")
        
        # Ensure we have valid values
        size="${size:-Unknown}"
        model="${model:-No description}"
        
        # Determine device type and icon based on model or device name
        local icon="💾" # Default USB icon
        if [[ "$model" == *"Card"* ]] || [[ "$device_name" == mmcblk* ]]; then
            icon="💳" # SD card
        elif [[ "$model" == *"SSD"* ]] || [[ "$device_name" == nvme* ]]; then
            icon="💽" # SSD
        fi
        
        # Format the device row - using simple echo for reliability
        echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}$((i+1))${COLOR_RESET}  ${icon} ${COLOR_YELLOW}$(printf '%-12s' "${device_name}")${COLOR_RESET} $(printf '%-9s' "${size}") ${COLOR_CYAN}${model}${COLOR_RESET}  ${COLOR_CYAN}│${COLOR_RESET}" > /dev/tty
    done

    # Add manual entry and quit options after the loop
    echo -e "  ${COLOR_CYAN}├$(repeat_char "─" $((UI_WIDTH - 12)))┤${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}M)${COLOR_RESET} Manually enter device path                      ${COLOR_CYAN}│${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}Q)${COLOR_RESET} Quit / Cancel                                 ${COLOR_CYAN}│${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}╰$(repeat_char "─" $((UI_WIDTH - 12)))╯${COLOR_RESET}\n" > /dev/tty
    
    return 0 # Successfully displayed device selection options
}

# List available USB/removable devices and prompt user to select one
# Returns the selected device path via stdout
select_usb_device() {
    echo "DEBUG: select_usb_device() starting..." >&2
    
    # If we already have a device selected and want to skip the duplicate selection
    if [ "$SKIP_DEVICE_SELECTION" = "true" ] && [ -n "$LEONARDO_DEVICE_PATH" ]; then
        echo "DEBUG: Using previously selected device: $LEONARDO_DEVICE_PATH" >&2
        echo "$LEONARDO_DEVICE_PATH"
        return 0
    fi

    clear_screen_and_show_art

    # Add step banner
    local box_width_select=$((UI_WIDTH - 8)) # Use a different var name to avoid scope issues if any
    local step_text_select="STEP 1: SELECT USB DEVICE"
    local padding_select=$(( (box_width_select - ${#step_text_select}) / 2 ))
    echo -e "${COLOR_CYAN}╔$(repeat_char "═" $((box_width_select + 2)))╗${COLOR_RESET}"
    echo -e "${COLOR_CYAN}║${COLOR_RESET}$(repeat_char " " $padding_select)${COLOR_BOLD}${COLOR_YELLOW}${step_text_select}${COLOR_RESET}$(repeat_char " " $((box_width_select - padding_select - ${#step_text_select} + 2)))${COLOR_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╚$(repeat_char "═" $((box_width_select + 2)))╝${COLOR_RESET}\n"

    print_info "Scanning for USB/removable storage devices..."
    
    # Reset global arrays
    _CASCADE_USB_PATHS=()
    _CASCADE_USB_DISPLAY_STRINGS=()
    
    # Get list of USB/removable devices
    echo "DEBUG: select_usb_device: Calling list_usb_devices..." >&2
    if ! list_usb_devices; then
        print_error "Failed to list USB devices. Check if you have the required permissions (try running with sudo)."
        return 1
    fi
    
    local num_devices=${#_CASCADE_USB_PATHS[@]}
    echo "DEBUG: select_usb_device: Found $num_devices devices" >&2
    
    if [ $num_devices -eq 0 ]; then
        print_error "No USB/removable devices found."
        
        # Provide helpful troubleshooting steps
        echo -e "\n${COLOR_YELLOW}Troubleshooting steps:${COLOR_RESET}"
        echo "1. Make sure the USB drive is properly connected"
        echo "2. Try unplugging and reconnecting the USB drive"
        echo "3. Check if the device appears in 'lsblk' or 'lsusb' output"
        echo -e "4. ${COLOR_BOLD}Run with sudo${COLOR_RESET} if you see permission errors"
        
        # Show available block devices to help with manual entry
        echo -e "\n${COLOR_YELLOW}Available block devices:${COLOR_RESET}"
        if command -v lsblk >/dev/null 2>&1; then
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | head -n 1
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | grep -v '^NAME'
        else
            echo "(lsblk not available, trying direct /dev listing)"
            ls -l /dev/sd* /dev/hd* /dev/nvme* /dev/mmcblk* 2>/dev/null || echo "Could not list devices"
        fi
        
        return 1
    fi
    
    # Display the device selection menu
    echo -e "\n${COLOR_BOLD}${COLOR_WHITE}Select a USB device to use:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}WARNING: All data on the selected device will be permanently erased!${COLOR_RESET}"
    
    # Display device list with numbers and more details
    for i in "${!_CASCADE_USB_DISPLAY_STRINGS[@]}"; do
        local device_path="${_CASCADE_USB_PATHS[$i]}"
        local device_info="${_CASCADE_USB_DISPLAY_STRINGS[$i]}"
        
        # Get additional info for display
        local size_info=""
        local mount_info=""
        
        if command -v lsblk >/dev/null 2>&1; then
            size_info=$(lsblk -d -o SIZE --nodeps -n "$device_path" 2>/dev/null | xargs)
            local mount_point=$(lsblk -no MOUNTPOINT "$device_path" 2>/dev/null | grep -v '^$' | head -1)
            if [ -n "$mount_point" ]; then
                mount_info="${COLOR_RED}(Mounted at: $mount_point)${COLOR_RESET}"
            fi
        fi
        
        # Format the display line with proper alignment
        printf "  ${COLOR_CYAN}%2d)${COLOR_RESET} %-30s ${COLOR_YELLOW}%10s${COLOR_RESET} %s\n" \
            "$((i+1))" "$device_path" "$size_info" "$mount_info"
    done
    
    # Add option for manual entry
    echo -e "\n  ${COLOR_CYAN}m)${COLOR_RESET} Enter device path manually"
    echo -e "  ${COLOR_CYAN}q)${COLOR_RESET} Quit"
    
    # Prompt for selection
    while true; do
        echo -n -e "\n${COLOR_BOLD}Select device (1-$num_devices, m, q): ${COLOR_RESET}"
        read -r selection
        
        # Trim whitespace
        selection=$(echo "$selection" | xargs)
        
        echo "DEBUG: User input: '$selection'" >&2
        
        case $selection in
            [1-9]|[1-9][0-9])
                # Check if the selection is within range
                if [ "$selection" -ge 1 ] && [ "$selection" -le $num_devices ]; then
                    local selected_device="${_CASCADE_USB_PATHS[$((selection-1))]}"
                    echo "DEBUG: User selected device #$selection: $selected_device" >&2
                    
                    # Verify the device still exists and is accessible
                    if [ ! -e "$selected_device" ]; then
                        print_error "Device '$selected_device' is no longer available. Please try again."
                        continue
                    fi
                    
                    echo "$selected_device"
                    return 0
                else
                    print_error "Invalid selection. Please enter a number between 1 and $num_devices."
                fi
                ;;
            m|M)
                # Manual entry
                echo -e "\n${COLOR_YELLOW}Manual device entry${COLOR_RESET}"
                echo -e "Enter the full device path (e.g., /dev/sdX or sdb)"
                echo -e "Available devices: $(ls /dev/sd* /dev/nvme* /dev/mmcblk* 2>/dev/null | tr '\n' ' ')"
                echo -n -e "${COLOR_BOLD}Device path: ${COLOR_RESET}"
                read -r manual_device
                
                # Trim whitespace and quotes
                manual_device=$(echo "$manual_device" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
                
                # Basic validation
                if [ -z "$manual_device" ]; then
                    print_error "No device path provided."
                    continue
                fi
                
                # Add /dev/ prefix if missing and it looks like a device name
                if [[ ! "$manual_device" =~ ^/dev/ ]] && [[ "$manual_device" =~ ^[sh]d[a-z]|nvme[0-9]n[0-9]|mmcblk[0-9] ]]; then
                    manual_device="/dev/$manual_device"
                    echo "DEBUG: Added /dev/ prefix: $manual_device" >&2
                fi
                
                # Verify the device exists and is a block device
                if [ ! -e "$manual_device" ]; then
                    print_error "Device '$manual_device' does not exist."
                    continue
                fi
                
                if [ ! -b "$manual_device" ]; then
                    print_error "'$manual_device' is not a block device."
                    continue
                fi
                
                echo "DEBUG: User manually entered device: $manual_device" >&2
                echo "$manual_device"
                return 0
                ;;
            q|Q)
                print_info "Operation cancelled by user."
                return 1
                ;;
            *)
                print_error "Invalid selection. Please enter a number between 1 and $num_devices, 'm' for manual entry, or 'q' to quit."
                ;;
        esac
    done

    # Main selection loop handles all exit paths. Device path is echoed and function returns within the loop.
}

# Verify that the selected device is a valid USB device and prompt for confirmation
# Takes the device path as an argument
verify_usb_device() {
    
    local device_path="$1"
    
    # If there's a global device path set and this function was called without arguments,
    # use the global device path instead
    if [ -z "$device_path" ] && [ -n "$LEONARDO_DEVICE_PATH" ]; then
        device_path="$LEONARDO_DEVICE_PATH"
        echo "DEBUG: verify_usb_device: Using global device path: $device_path" >&2
    fi
    
    # Check if device path is empty
    if [ -z "$device_path" ]; then
        echo "DEBUG: verify_usb_device: No device path provided" >&2
        print_error "No device path provided"
        return 1
    fi
    
    # Clean up the device path
    device_path=$(echo "$device_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    echo "DEBUG: verify_usb_device: Checking device: '$device_path'" >&2
    
    # Check if the device exists and is a block device
    echo "DEBUG: verify_usb_device: Running is_block_device check..." >&2
    if ! is_block_device "$device_path"; then
        echo "DEBUG: verify_usb_device: is_block_device check FAILED for '$device_path'" >&2
        print_error "'$device_path' is not a valid block device"
        
        # Try to provide more helpful error messages
        if [ ! -e "$device_path" ]; then
            print_error "The specified device does not exist: $device_path"
            # Check if /dev/ prefix is missing
            if [[ ! "$device_path" =~ ^/dev/ ]] && [ -e "/dev/$device_path" ]; then
                print_info "Note: Did you mean '/dev/$device_path'?"
            fi
        elif [ -d "$device_path" ]; then
            print_error "The specified path is a directory, not a block device"
        elif [ -f "$device_path" ]; then
            print_error "The specified path is a regular file, not a block device"
        fi
        
        # List available block devices to help user
        echo -e "\n${COLOR_YELLOW}Available block devices:${COLOR_RESET}"
        if command -v lsblk >/dev/null 2>&1; then
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | head -n 1
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | grep -v '^NAME'
        else
            echo "(lsblk not available, trying direct /dev listing)"
            ls -l /dev/sd* /dev/hd* /dev/nvme* /dev/mmcblk* 2>/dev/null || echo "Could not list devices"
        fi
        
        return 1
    fi
    
    echo "DEBUG: verify_usb_device: Device passed block device check" >&2
    
    # Get device information for confirmation
    local device_info=""
    local device_size=""
    local device_model=""
    
    if command -v lsblk >/dev/null 2>&1; then
        echo "DEBUG: verify_usb_device: Using lsblk to get device info" >&2
        device_info=$(lsblk -d -o NAME,SIZE,MODEL,VENDOR,TRAN --nodeps -n "$device_path" 2>/dev/null)
        device_size=$(lsblk -d -o SIZE --nodeps -n "$device_path" 2>/dev/null | xargs)
        device_model=$(lsblk -d -o MODEL --nodeps -n "$device_path" 2>/dev/null | xargs)
    else
        echo "DEBUG: verify_usb_device: lsblk not available, using fallback methods" >&2
        # Fallback if lsblk is not available
        device_size=$(blockdev --getsize64 "$device_path" 2>/dev/null | numfmt --to=si 2>/dev/null || echo "unknown size")
        device_info="$(basename "$device_path") - $device_size"
    fi
    
    # Get mount points if any
    local mount_points=""
    if command -v findmnt >/dev/null 2>&1; then
        echo "DEBUG: verify_usb_device: Using findmnt to check mounts" >&2
        mount_points=$(findmnt -n -o TARGET --source "$device_path*" 2>/dev/null | tr '\n' ' ')
    elif command -v mount >/dev/null 2>&1; then
        echo "DEBUG: verify_usb_device: Using mount to check mounts" >&2
        mount_points=$(mount | grep "^$device_path" | awk '{print $3}' | tr '\n' ' ')
    else
        echo "DEBUG: verify_usb_device: No mount checking tools available" >&2
        mount_points="(mount info unavailable)"
    fi
    
    # Check if device is mounted
    if [ -n "$mount_points" ]; then
        echo "DEBUG: verify_usb_device: Device is mounted at: $mount_points" >&2
        print_warning "Device '$device_path' is mounted at: $mount_points"
        
        # Try to unmount automatically if it's a USB device
        if [[ "$device_path" =~ "/dev/sd" || "$device_path" =~ "/dev/nvme" || "$device_path" =~ "/dev/mmcblk" ]]; then
            if confirm "Would you like to try unmounting it automatically?" "yes"; then
                echo "DEBUG: verify_usb_device: Attempting to unmount $device_path" >&2
                if command -v umount >/dev/null 2>&1; then
                    for mp in $mount_points; do
                        echo "Unmounting $mp..."
                        umount "$mp" 2>/dev/null
                    done
                    # Verify unmount was successful
                    mount_points=$(findmnt -n -o TARGET --source "$device_path*" 2>/dev/null | tr '\n' ' ')
                    if [ -n "$mount_points" ]; then
                        print_error "Failed to unmount all partitions of $device_path"
                        if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                            print_info "Operation cancelled by user."
                            return 1
                        fi
                    else
                        print_success "Successfully unmounted all partitions of $device_path"
                    fi
                else
                    print_error "'umount' command not found. Cannot unmount automatically."
                    if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                        print_info "Operation cancelled by user."
                        return 1
                    fi
                fi
            else
                if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                    print_info "Operation cancelled by user."
                    return 1
                fi
            fi
        else
            if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                print_info "Operation cancelled by user."
                return 1
            fi
        fi
    else
        echo "DEBUG: verify_usb_device: Device is not mounted" >&2
    fi
    
    # Final warning confirmation box
    local box_width=70  # Define a width for the warning box
    echo -e "${COLOR_RED}╔$(repeat_char "═" $box_width)╗${COLOR_RESET}"
    echo -e "${COLOR_RED}║${COLOR_RESET} ${COLOR_BOLD}${COLOR_RED}(ಠ‿ಠ)🦙 ALL DATA ON DEVICE ${device_path} WILL BE PERMANENTLY ERASED!${COLOR_RESET}${COLOR_RED}$(printf "%$((box_width - 46 - ${#device_path}))s" "")║${COLOR_RESET}"
    echo -e "${COLOR_RED}║${COLOR_RESET} ${COLOR_RED}This operation is irreversible. Make sure you have backups of any important data.${COLOR_RESET}${COLOR_RED}$(printf "%$((box_width - 75))s" "")║${COLOR_RESET}"
    echo -e "${COLOR_RED}╚$(repeat_char "═" $box_width)╝${COLOR_RESET}"
    echo
    
    # Double confirmation with explicit yes/no options
    echo -e "${COLOR_BOLD}${COLOR_RED}⚠️  Type 'YES' (all caps) to confirm you want to format $device_path: ${COLOR_RESET}"
    local user_confirmation
    read user_confirmation
    
    if [[ "$user_confirmation" != "YES" ]]; then
        print_error "Formatting operation cancelled - confirmation not received." >&2
        return 1
    fi
    
    print_info "Device $device_path verified and confirmed for formatting."
    return 0
}

# Wait for device to settle after making changes
wait_for_device_settle() {
    local device="$1"
    local timeout="${2:-5}" # Default to 5 seconds
    
    print_debug "Waiting for device $device to settle (up to $timeout seconds)..."
    
    # Run udevadm settle with timeout
    if command -v udevadm >/dev/null; then
        sudo udevadm settle --timeout="$timeout" || print_warning "udevadm settle command failed or timed out."
    else
        print_warning "udevadm not found. Relying on sleep to allow device to settle."
        sleep "$timeout" # Fallback if udevadm is not available
    fi
    
    # Additional sleep to ensure the kernel has processed all events, especially after udevadm might have exited early
    sleep 1 
    
    print_debug "Device $device should be settled now."
}
