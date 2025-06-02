# ==============================================================================
# Leonardo AI Universal - Core Operations
# ==============================================================================
# Description: Core operations for creating USB devices and managing models
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,02_ui/warnings.sh,03_filesystem/device.sh,03_filesystem/health.sh,05_models/registry.sh,05_models/installer.sh,06_deployment/installer.sh
# ==============================================================================

# Show the main menu
show_main_menu() {
    local choice
    
    while true; do
        # Display the main menu
        clear
        print_banner "Leonardo AI Universal" "$UI_WIDTH"
        
        echo -e "\n${BOLD}${BLUE}Main Menu:${NC}\n"
        # Color-coded menu options based on function
        echo -e "  ${CYAN}1.${NC} ${GREEN}Create New Leonardo AI USB${NC}"           # Green for creation
        echo -e "  ${CYAN}2.${NC} ${YELLOW}Add Models to Existing USB${NC}"          # Yellow for modification
        echo -e "  ${CYAN}3.${NC} ${BLUE}Check USB Health${NC}"                     # Blue for diagnostics
        echo -e "  ${CYAN}4.${NC} ${MAGENTA}List Available Models${NC}"              # Magenta for information
        echo -e "  ${CYAN}5.${NC} ${CYAN}System Information${NC}"                   # Cyan for system info
        echo -e "  ${RED}0.${NC} ${RED}Exit${NC}"                                  # Red for exit
        echo ""
        
        # Show friendly llama mascot
        echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}How can I help you today?${NC}"
        echo ""
        
        # Get user input
        echo -n "Enter your choice [0-5]: "
        read -r choice
        
        # Process the choice
        case $choice in
            1)
                create_new_usb
                ;;
            2)
                add_model_to_usb
                ;;
            3)
                check_usb_health
                ;;
            4)
                show_available_models
                ;;
            5)
                show_system_info
                ;;
            0)
                log_message "INFO" "User chose to exit"
                echo -e "\n${GREEN}Thank you for using Leonardo AI Universal!${NC}"
                cleanup_and_exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice. Please try again.${NC}"
                wait_for_keypress
                ;;
        esac
    done
}

# Create a new Leonardo AI USB device
create_new_usb() {
    log_message "INFO" "Starting USB creation process"
    
    # Check if we're in test mode
    local test_mode_prefix=""
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        test_mode_prefix="[TEST MODE] "
        log_message "INFO" "Running USB creation in TEST MODE (no actual formatting)"
    fi
    
    # Show step header
    show_step_header "Create New Leonardo AI USB" "$UI_WIDTH"
    
    # We are creating USB, warn the user about data loss
    echo -e "\n${BG_RED}${WHITE} ${test_mode_prefix}WARNING: DESTRUCTIVE OPERATION ${NC}"
    show_danger "This is a destructive operation that will erase ALL data on the selected device."
    echo -e "${RED}You are about to create a new Leonardo Universal USB drive.${NC}"
    echo -e "${RED}This will ${BOLD}ERASE ALL DATA${NC}${RED} on the selected USB drive.${NC}"
    echo -e "${YELLOW}Make sure you have backed up any important files.${NC}\n"
    
    # Confirm the action
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operation canceled."
        return 1
    fi
    
    log_message "DEBUG" "User confirmed USB creation"
    
    # Select USB device - SIMPLIFIED FLOW TO PREVENT FREEZING
    log_message "DEBUG" "Calling select_usb_device..."
    local device_path
    device_path=$(select_usb_device)
    select_status=$?
    
    log_message "DEBUG" "select_usb_device returned: $select_status, device_path=$device_path"
    
    if [[ $select_status -ne 0 || -z "$device_path" ]]; then
        echo -e "${RED}No USB device selected.${NC}"
        return 1
    fi
    
    # Verify the selection with one more warning
    log_message "DEBUG" "Verifying USB device: $device_path"
    if ! verify_usb_device "$device_path"; then
        log_message "INFO" "User canceled USB device verification"
        return 1
    fi
    
    # If in test mode, stop here and show success message
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        echo -e "\n${GREEN}TEST MODE: USB device selection successful!${NC}"
        echo -e "Selected device: ${CYAN}$device_path${NC}"
        echo -e "${YELLOW}Note: No actual formatting performed in test mode.${NC}"
        return 0
    fi
    
    # SIMPLIFIED - REMOVED DUPLICATE CONFIRMATION AND SELECTION
    # Format the device
    echo -e "\n${GREEN}Preparing to format USB device: ${CYAN}$device_path${NC}"
    log_message "INFO" "Preparing to format USB device: $device_path"
    
    # Add clear debug messages
    echo -e "${YELLOW}Device path: $device_path${NC}"
    log_message "DEBUG" "Proceeding with device: $device_path"
    
    # No need for second verification - already verified above
    # Continue with formatting process
    
    # Show filesystem selection menu
    show_step_header "Select Filesystem" "$UI_WIDTH"
    echo -e "Choose a filesystem type for your Leonardo AI USB device:"
    echo ""
    echo -e "  ${CYAN}1.${NC} exFAT     (${GREEN}Recommended${NC}, compatible with Windows, macOS, Linux)"
    echo -e "  ${CYAN}2.${NC} NTFS      (Windows, limited macOS/Linux support)"
    echo -e "  ${CYAN}3.${NC} ext4      (Linux only)"
    echo -e "  ${CYAN}4.${NC} FAT32     (All systems, 4GB file size limit)"
    echo ""
    
    # Get filesystem choice
    local fs_choice
    echo -n "Enter your choice [1-4, default=1]: "
    read -r fs_choice
    
    # Set filesystem based on choice
    case $fs_choice in
        2)
            FS_TYPE="ntfs"
            ;;
        3)
            FS_TYPE="ext4"
            ;;
        4)
            FS_TYPE="vfat"
            ;;
        *)
            FS_TYPE="exfat"
            ;;
    esac
    
    log_message "INFO" "Selected filesystem: $FS_TYPE"
    
    # Show data destruction warning with intense llama
    show_data_destruction_warning "$device" "format with $FS_TYPE"
    
    # Final confirmation with danger llama
    if ! confirm_action "I understand this will DESTROY ALL DATA. Proceed?" "danger"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "USB creation cancelled at final confirmation"
        return 0
    fi
    
    # Format the device
    show_step_header "Formatting USB Device" "$UI_WIDTH"
    echo -e "Formatting ${CYAN}$device${NC} with ${CYAN}$FS_TYPE${NC} filesystem..."
    echo -e "This may take a few minutes. Please wait..."
    echo ""
    
    # Use spinner while formatting
    start_spinner "Formatting"
    
    if ! format_usb_device "$device" "$FS_TYPE"; then
        stop_spinner
        show_error "Failed to format the USB device.\nPlease check the logs for details."
        log_message "ERROR" "USB formatting failed for $device with $FS_TYPE"
        return 1
    fi
    
    stop_spinner
    show_success "USB device formatted successfully"
    
    # Install Leonardo AI framework
    show_step_header "Installing Leonardo AI" "$UI_WIDTH"
    echo -e "Installing Leonardo AI Universal to the USB device..."
    echo ""
    
    # Use spinner while installing
    start_spinner "Installing"
    
    if ! install_leonardo_framework "$device"; then
        stop_spinner
        show_error "Failed to install Leonardo AI framework.\nPlease check the logs for details."
        log_message "ERROR" "Leonardo AI framework installation failed"
        return 1
    fi
    
    stop_spinner
    show_success "Leonardo AI framework installed successfully"
    
    # Prompt for model installation
    show_step_header "Model Installation" "$UI_WIDTH"
    echo -e "Would you like to install an AI model now?"
    echo -e "You can add models later using the 'Add Models' option from the main menu."
    echo ""
    
    if confirm_action "Install AI model now?"; then
        # Get the system requirements
        local total_mem=$(free -m | awk '/^Mem:/{print $2}')
        local total_mem_gb=$((total_mem / 1024))
        
        # Select model to install
        local model_id
        model_id=$(select_model "$total_mem_gb" "$GPU_MEMORY")
        
        if [[ -n "$model_id" ]]; then
            # Install the selected model
            show_step_header "Installing Model" "$UI_WIDTH"
            echo -e "Installing ${CYAN}$(get_model_info "$model_id" "name")${NC}..."
            echo ""
            
            if ! install_model "$model_id" "$device"; then
                show_error "Failed to install the model.\nPlease check the logs for details."
                log_message "ERROR" "Model installation failed for $model_id"
            else
                show_success "Model installed successfully"
            fi
        else
            echo -e "\n${YELLOW}Model installation skipped.${NC}"
            log_message "INFO" "Model installation skipped"
        fi
    else
        echo -e "\n${YELLOW}Model installation skipped.${NC}"
        log_message "INFO" "Model installation skipped by user"
    fi
    
    # Finalize the installation
    finalize_installation "$device"
    
    # Return success
    return 0
}

# Add a model to an existing USB device
add_model_to_usb() {
    log_message "INFO" "Starting model addition process"
    
    # Show step header
    show_step_header "Add Models to Existing USB" "$UI_WIDTH"
    
    # Show initial guidance with friendly llama
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}This will add AI models to an existing Leonardo AI USB device.${NC}"
    echo -e "     Please make sure your USB device is connected."
    echo ""
    
    # Confirm initial action
    if ! confirm_action "Continue with model addition?"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "Model addition cancelled by user at initial confirmation"
        return 0
    fi
    
    # Get the USB device
    local device
    device=$(select_usb_device)
    
    # Check if device selection was cancelled
    if [[ -z "$device" ]]; then
        echo -e "\n${YELLOW}Device selection cancelled.${NC}"
        log_message "INFO" "Model addition cancelled: no device selected"
        return 0
    fi
    
    # Verify the selected device
    if ! verify_usb_device "$device"; then
        echo -e "\n${YELLOW}Device verification cancelled.${NC}"
        log_message "INFO" "Model addition cancelled: device verification failed"
        return 0
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_check_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "${device}1" "$mount_point"; then
        show_error "Failed to mount the USB device.\nPlease check that it is properly formatted."
        log_message "ERROR" "Failed to mount ${device}1"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if Leonardo AI is installed
    if [[ ! -d "$mount_point/leonardo" ]]; then
        umount "$mount_point"
        rmdir "$mount_point"
        show_error "Leonardo AI not found on this USB device.\nPlease use the 'Create New Leonardo AI USB' option first."
        log_message "ERROR" "Leonardo AI not found on ${device}1"
        return 1
    fi
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Get the system requirements
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb=$((total_mem / 1024))
    
    # Select model to install
    show_step_header "Select AI Model" "$UI_WIDTH"
    echo -e "Select an AI model to install:"
    echo ""
    
    local model_id
    model_id=$(select_model "$total_mem_gb" "$GPU_MEMORY")
    
    if [[ -z "$model_id" ]]; then
        echo -e "\n${YELLOW}Model selection cancelled.${NC}"
        log_message "INFO" "Model addition cancelled: no model selected"
        return 0
    fi
    
    # Confirm model installation with caution llama
    show_warning "You are about to install $(get_model_info "$model_id" "name")" "caution"
    echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}This may take some time depending on your internet connection.${NC}"
    echo -e "     Model size: ${CYAN}$(get_model_info "$model_id" "size")MB${NC}"
    echo -e "     Requirements: ${CYAN}$(get_model_info "$model_id" "requirements")${NC}"
    echo ""
    
    if ! confirm_action "Continue with model installation?"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "Model addition cancelled by user at model confirmation"
        return 0
    fi
    
    # Install the selected model
    show_step_header "Installing Model" "$UI_WIDTH"
    echo -e "Installing ${CYAN}$(get_model_info "$model_id" "name")${NC}..."
    echo ""
    
    if ! install_model "$model_id" "$device"; then
        show_error "Failed to install the model.\nPlease check the logs for details."
        log_message "ERROR" "Model installation failed for $model_id"
        return 1
    fi
    
    # Show success message
    show_success "Model installed successfully"
    
    # Ask if user wants to install another model
    if confirm_action "Would you like to install another model?"; then
        add_model_to_usb
    else
        echo -e "\n${GREEN}Models installation complete.${NC}"
        log_message "INFO" "Model addition completed successfully"
        wait_for_keypress
    fi
    
    # Return success
    return 0
}

# Check USB device health
check_usb_health() {
    log_message "INFO" "Starting USB health check"
    
    # Show step header
    show_step_header "Check USB Health" "$UI_WIDTH"
    
    # Show initial guidance with friendly llama
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}This will check the health of your Leonardo AI USB device.${NC}"
    echo -e "     Please make sure your USB device is connected."
    echo ""
    
    # Confirm initial action
    if ! confirm_action "Continue with health check?"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "Health check cancelled by user at initial confirmation"
        return 0
    fi
    
    # Get the USB device
    local device
    device=$(select_usb_device)
    
    # Check if device selection was cancelled
    if [[ -z "$device" ]]; then
        echo -e "\n${YELLOW}Device selection cancelled.${NC}"
        log_message "INFO" "Health check cancelled: no device selected"
        return 0
    fi
    
    # Verify the selected device
    if ! verify_usb_device "$device"; then
        echo -e "\n${YELLOW}Device verification cancelled.${NC}"
        log_message "INFO" "Health check cancelled: device verification failed"
        return 0
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/health_check_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "${device}1" "$mount_point"; then
        show_error "Failed to mount the USB device.\nPlease check that it is properly formatted."
        log_message "ERROR" "Failed to mount ${device}1"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if Leonardo AI is installed
    if [[ ! -d "$mount_point/leonardo" ]]; then
        umount "$mount_point"
        rmdir "$mount_point"
        show_error "Leonardo AI not found on this USB device.\nPlease use the 'Create New Leonardo AI USB' option first."
        log_message "ERROR" "Leonardo AI not found on ${device}1"
        return 1
    fi
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Display USB health
    show_step_header "USB Health Report" "$UI_WIDTH"
    echo -e "Analyzing USB device health..."
    echo ""
    
    # Display health information
    if ! display_usb_health "${device}1"; then
        show_warning "No health data found for this device." "caution"
        echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}This USB device may not have been created with health tracking.${NC}"
        echo -e "     Consider creating a new USB device with health tracking enabled."
        log_message "WARNING" "No health data found for ${device}1"
    fi
    
    # Wait for user acknowledgment
    echo ""
    wait_for_keypress
    
    # Return success
    return 0
}

# Show available models
show_available_models() {
    log_message "INFO" "Displaying available models"
    
    # Show step header
    show_step_header "Available AI Models" "$UI_WIDTH"
    
    # Get the system requirements
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb=$((total_mem / 1024))
    
    # Show models compatible with this system
    echo -e "Models compatible with your system (${CYAN}${total_mem_gb}GB RAM${NC}, ${CYAN}${GPU_MEMORY}MB GPU${NC}):"
    echo ""
    
    # Filter and display models
    filter_models_by_requirements "$total_mem_gb" "$GPU_MEMORY"
    
    # Wait for user acknowledgment
    echo ""
    wait_for_keypress
    
    # Return success
    return 0
}

# Show system information
show_system_info() {
    log_message "INFO" "Displaying system information"
    
    # Show step header
    show_step_header "System Information" "$UI_WIDTH"
    
    # Get system information
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb=$(echo "scale=1; $total_mem / 1024" | bc)
    local free_space=$(df -h . | awk 'NR==2 {print $4}')
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^ *//')
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
    
    # Display system information
    print_box_header "System Information" "$UI_WIDTH" "$BLUE"
    
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "OS:" "$(uname -o)" $((UI_WIDTH - 25 - $(uname -o | wc -c))) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Kernel:" "$(uname -r)" $((UI_WIDTH - 25 - $(uname -r | wc -c))) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "CPU:" "$cpu_model" $((UI_WIDTH - 25 - ${#cpu_model})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "CPU Cores:" "$cpu_cores" $((UI_WIDTH - 25 - ${#cpu_cores})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s GB${NC}%*s ${BLUE}${BOX_V}${NC}\n" "RAM:" "$total_mem_gb" $((UI_WIDTH - 28 - ${#total_mem_gb})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Free Disk Space:" "$free_space" $((UI_WIDTH - 25 - ${#free_space})) ""
    
    # GPU information
    if [[ "$SYSTEM_HAS_NVIDIA_GPU" == "true" ]]; then
        local gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "GPU:" "$gpu_model" $((UI_WIDTH - 25 - ${#gpu_model})) ""
        printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s MB${NC}%*s ${BLUE}${BOX_V}${NC}\n" "GPU Memory:" "$GPU_MEMORY" $((UI_WIDTH - 29 - ${#GPU_MEMORY})) ""
    else
        printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "GPU:" "None detected" $((UI_WIDTH - 25 - 13)) ""
    fi
    
    # Application information
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$BLUE"
    
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Leonardo Version:" "6.0.0" $((UI_WIDTH - 25 - 5)) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Log Level:" "$LOG_LEVEL" $((UI_WIDTH - 25 - ${#LOG_LEVEL})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Debug Mode:" "$DEBUG_MODE" $((UI_WIDTH - 25 - ${#DEBUG_MODE})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "UTF-8 Support:" "$HAS_UTF8_LOCALE" $((UI_WIDTH - 25 - ${#HAS_UTF8_LOCALE})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Color Support:" "$HAS_COLOR_SUPPORT" $((UI_WIDTH - 25 - ${#HAS_COLOR_SUPPORT})) ""
    
    # Footer
    print_box_footer "$UI_WIDTH" "$BLUE"
    
    # Wait for user acknowledgment
    echo ""
    wait_for_keypress
    
    # Return success
    return 0
}

# Show data destruction warning
show_data_destruction_warning() {
    local device="$1"
    local operation="$2"
    
    # Get device info
    local device_model=$(get_device_info "$device" "model")
    local device_size=$(get_device_info "$device" "size")
    
    # Helper function for box lines
    print_box_line() {
        local char="$1"
        local width="$2"
        local left_edge="${3:-$char}"
        local right_edge="${4:-$char}"
        local color="${5:-$RED}"
        
        printf "${color}${left_edge}${NC}"
        printf "${color}%${width}s${NC}" | tr ' ' "$char"
        printf "${color}${right_edge}${NC}\n"
    }
    
    # Clear screen and show warning box
    clear
    echo ""
    
    # Warning header
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_TL" "$BOX_TR" "$RED"
    
    # Title
    local title="⚠️ DATA DESTRUCTION IMMINENT ⚠️"
    local padding=$(( (UI_WIDTH - ${#title}) / 2 ))
    printf "${RED}${BOX_V}${NC}%${padding}s${BOLD}${RED}%s${NC}%${padding}s${RED}${BOX_V}${NC}\n" "" "$title" ""
    
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$RED"
    
    # Intense llama warning
    printf "${RED}${BOX_V}${NC} ${RED}(ಠ‿ಠ)🦙 THIS IS YOUR FINAL WARNING!${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 35)) ""
    
    # Empty line
    printf "${RED}${BOX_V}${NC}%${UI_WIDTH}s${RED}${BOX_V}${NC}\n" ""
    
    # Target info
    printf "${RED}${BOX_V}${NC} ${BOLD}Target Device:${NC} ${CYAN}$device${NC} ($device_model, $device_size)%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 50 - ${#device} - ${#device_model} - ${#device_size})) ""
    printf "${RED}${BOX_V}${NC} ${BOLD}Operation:${NC} ${CYAN}$operation${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 30 - ${#operation})) ""
    
    # Empty line
    printf "${RED}${BOX_V}${NC}%${UI_WIDTH}s${RED}${BOX_V}${NC}\n" ""
    
    # Consequences
    printf "${RED}${BOX_V}${NC} ${BOLD}This operation will:${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 25)) ""
    printf "${RED}${BOX_V}${NC}   - ${RED}PERMANENTLY ERASE ALL DATA${NC} on the device%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 45)) ""
    printf "${RED}${BOX_V}${NC}   - ${RED}DELETE ALL EXISTING PARTITIONS${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 35)) ""
    printf "${RED}${BOX_V}${NC}   - ${RED}DESTROY ALL FILE SYSTEMS${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 30)) ""
    
    # Empty line
    printf "${RED}${BOX_V}${NC}%${UI_WIDTH}s${RED}${BOX_V}${NC}\n" ""
    
    # Verification
    printf "${RED}${BOX_V}${NC} ${BOLD}Verify that:${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 20)) ""
    printf "${RED}${BOX_V}${NC}   - You have backed up all important data%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 45)) ""
    printf "${RED}${BOX_V}${NC}   - You have selected the correct device%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 43)) ""
    printf "${RED}${BOX_V}${NC}   - You understand this action is ${BOLD}${RED}IRREVERSIBLE${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 50)) ""
    
    # Footer
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_BL" "$BOX_BR" "$RED"
    
    # Log the warning
    log_message "WARNING" "Data destruction warning displayed for $device"
    
    # Empty line
    echo ""
}

# Cleanup and exit
cleanup_and_exit() {
    local exit_code="$1"
    
    log_message "INFO" "Cleaning up temporary files"
    
    # Remove temporary directories if they exist
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    
    log_message "INFO" "Exiting with code $exit_code"
    exit "$exit_code"
}

# Call main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
