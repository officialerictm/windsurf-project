#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker - Main Application
# ==============================================================================

# Create a new USB drive with enhanced UI
create_new_usb() {
    local device
    local filesystem
    local label
    
    # Show header first
    show_header
    
    # Set the USB device selection variables
    export SKIP_DEVICE_SELECTION=true  # Flag to prevent duplicate device selection
    export LEONARDO_DEVICE_PATH=""    # Clear any previous device path
    
    # Select USB device using the enhanced selection screen
    device=$(select_usb_device)
    if [ $? -ne 0 ] || [ -z "$device" ]; then
        print_notification_box "USB device selection failed or was cancelled." "warning"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Export the selected device path for other functions to use
    export LEONARDO_DEVICE_PATH="$device"
    
    # Verify and warn user about the selected device
    if ! verify_usb_device "$device"; then
        print_notification_box "USB device verification failed or was cancelled." "warning"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Select filesystem with enhanced menu
    local fs_options=("exFAT (Windows/Mac/Linux, large files)" "NTFS (Windows, limited macOS/Linux)" "EXT4 (Linux only)")
    show_menu "Select Filesystem" "Choose the filesystem type for your Leonardo AI USB:" "${fs_options[@]}"
    local fs_result=$?
    
    case "$fs_result" in
        0) filesystem="exfat" ;;
        1) filesystem="ntfs" ;;
        2) filesystem="ext4" ;;
        *) 
            print_error "Invalid filesystem selection."
            return 1 ;;
    esac
    
    # Get USB label
    clear_screen_and_show_art
    print_section_header "USB Drive Label"
    echo -e "${COLOR_CYAN}Enter a name for your Leonardo AI USB drive:${COLOR_RESET}"
    echo -e "${COLOR_DIM}(Letters, numbers, and underscores only, no spaces)${COLOR_RESET}"
    echo
    
    # Default label
    label="LEONARDO"
    
    print_prompt "USB Label [$label]: "
    read user_label
    
    if [ -n "$user_label" ]; then
        # Clean up the label - remove spaces and special characters
        label=$(echo "$user_label" | tr -cd '[:alnum:]_')
        if [ -z "$label" ]; then
            label="LEONARDO"
        fi
    fi
    
    echo -e "\nUSB will be labeled as: ${COLOR_BOLD}$label${COLOR_RESET}"
    
    # Show data destruction warning with intense llama
    show_data_destruction_warning "$device" "Format with $filesystem"
    
    # Final confirmation with warning level llama
    if ! confirm "Are you ABSOLUTELY SURE you want to continue with this operation?" "n" "warning"; then
        print_notification_box "Operation cancelled by user." "info"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Format the drive with progress tracking
    if ! run_with_progress "format_usb_device '$device' '$filesystem' '$label'" "Formatting USB Drive" 100; then
        print_notification_box "Failed to format USB drive." "error"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Determine the first partition
    local first_partition
    if [[ "$device" =~ nvme ]]; then
        first_partition="${device}p1"  # NVMe naming convention
    else
        first_partition="${device}1"   # Standard device naming
    fi
    
    # Install the Leonardo system with progress tracking
    if ! run_with_progress "install_leonardo_system '$first_partition' '$filesystem' '$label'" "Installing Leonardo AI System" 100; then
        print_notification_box "Failed to install Leonardo system to USB drive." "error"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Show success screen
    show_success_screen "USB Creation Complete" "Your Leonardo AI USB '$label' has been successfully created and is ready to use!"
    
    return 0
}

# Add an AI model to a USB drive
add_ai_model() {
    print_section_header "ADD AI MODEL TO USB"
    
    # List available AI models
    local model_options=()
    local i=0
    
    for model_entry in "${SUPPORTED_MODELS[@]}"; do
        IFS=':' read -r model_id model_name <<< "$model_entry"
        model_options+=("$model_name")
        i=$((i + 1))
    done
    
    # Ask user to select a model
    show_menu "AI MODELS" "Select an AI model:" "${model_options[@]}"
    local model_choice=$?
    
    IFS=':' read -r selected_model_id selected_model_name <<< "${SUPPORTED_MODELS[$model_choice]}"
    
    print_info "Selected model: $selected_model_name ($selected_model_id)"
    
    # Select USB device using enhanced selection function (handles scanning and prompting)
    local selected_device
    selected_device=$(select_usb_device)

    if [ -z "$selected_device" ]; then
        print_error "No device selected."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi

    # Verify the selected device (optional, but good practice)
    # if ! verify_usb_device "$selected_device"; then
    #     # verify_usb_device handles its own error messaging and prompt to quit
    #     read -p "Press [Enter] to return to the main menu..." 
    #     return 1
    # fi
    print_info "Selected USB device: $selected_device"
    
    # Check if the device is formatted and mounted
    local mount_point
    mount_point=$(lsblk -no MOUNTPOINT "$selected_device" | grep -v "^$")
    
    if [ -z "$mount_point" ]; then
        print_error "The selected USB device is not mounted."
        print_info "Please mount the device and try again."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    print_info "USB device is mounted at: $mount_point"
    
    # Create the model directory on the USB
    local model_dir="$mount_point/models/$selected_model_id"
    mkdir -p "$model_dir"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create model directory on USB."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    # Download model files (this is a placeholder)
    print_info "Downloading $selected_model_name files..."
    print_info "This is a placeholder for the actual download process."
    
    # Create a seed file (simulating the actual model download)
    create_seed_file "$model_dir" "$selected_model_id" "2048"
    
    print_success "Added $selected_model_name to USB drive."
    read -p "Press [Enter] to return to the main menu..."
    return 0
}

# Create a seed file with random data (placeholder for actual model)
create_seed_file() {
    local dir="$1"
    local name="$2"
    local size_mb="${3:-10}"
    local seed_file="$dir/${name}_seed.bin"
    
    print_info "Creating seed file: $seed_file ($size_mb MB)"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would create seed file: $seed_file ($size_mb MB)"
        return 0
    fi
    
    # Create random data
    dd if=/dev/urandom of="$seed_file" bs=1M count="$size_mb" status=progress 2>&1 | while IFS= read -r line; do
        print_debug "$line"
    done
    
    if [ -f "$seed_file" ]; then
        print_success "Created seed file: $seed_file"
        # Calculate and save checksums for integrity verification
        save_checksum "$seed_file" "sha256"
        return 0
    else
        print_error "Failed to create seed file"
        return 1
    fi
}

# Check USB drive health
verify_usb_health() {
    print_section_header "USB HEALTH CHECK"
    
    # List available USB devices
    if ! list_usb_devices; then
        print_error "No USB devices found."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    # Ask user to select a device
    local device
    device=$(select_usb_device)
    if [ -z "$device" ]; then
        print_error "No device selected."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    print_info "Checking health of $device..."
    
    # Get device information
    local vendor
    local model
    local size
    
    vendor=$(udevadm info --query=property --name="$device" | grep ID_VENDOR= | cut -d= -f2 || echo "Unknown")
    model=$(udevadm info --query=property --name="$device" | grep ID_MODEL= | cut -d= -f2 || echo "Unknown")
    size=$(blockdev --getsize64 "$device" 2>/dev/null || echo "Unknown")
    size_human=$(human_readable_size "$size")
    
    echo "Device: $device"
    echo "Vendor: $vendor"
    echo "Model: $model"
    echo "Size: $size_human"
    
    # Check if the device is partitioned
    local partitions
    partitions=$(lsblk -no NAME "$device" | grep -v "$(basename "$device")" | wc -l)
    
    if [ "$partitions" -gt 0 ]; then
        echo "Partitions: $partitions"
        
        # Show information for each partition
        lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$device"
    else
        echo "Partitions: None"
    fi
    
    # Check for bad blocks (non-destructive read-only test)
    if confirm "Do you want to perform a basic read test? This may take a while but won't modify any data." false; then
        print_info "Testing device for reading errors (press Ctrl+C to abort)..."
        badblocks -sv -b 4096 -c 10240 -n "$device"
        
        if [ $? -eq 0 ]; then
            print_success "No bad blocks found."
        else
            print_error "Bad blocks detected. This USB drive may be failing."
        fi
    fi
    
    read -p "Press [Enter] to return to the main menu..."
    return 0
}

# Main function
main() {
    # Initialize script
    initialize_script
    
    # Parse arguments
    parse_arguments "$@"
    
    # Show help and exit if requested
    if [ "$SHOW_HELP" = true ]; then
        show_help
        exit 0
    fi
    
    # Main loop
    while true; do
        show_main_menu
        local choice=$?
        
        case $choice in
            0) create_new_usb ;;
            1) add_ai_model ;;
            2) verify_usb_health ;;
            3) view_download_history ;;
            4) show_about ;;
            5) exit_application ;; # Use our enhanced exit function with goodbye screen
            *) print_error "Invalid selection" ;;
        esac
    done
}

# Run the main function
main "$@"
