# ==============================================================================
# Leonardo AI Universal - UI Utilities
# ==============================================================================
# Description: UI utilities and helper functions for the main application
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/colors.sh,00_core/logging.sh,02_ui/basic.sh
# ==============================================================================

# Start a spinner for long-running operations
start_spinner() {
    local message="$1"
    
    # If the spinner function is defined in basic.sh, use it
    if declare -f spinner &>/dev/null; then
        spinner "$message" &
        SPINNER_PID=$!
        return 0
    fi
    
    # Otherwise, define a simple spinner
    local pid
    local delay=0.1
    local spinstr='|/-\'
    
    # Display the message
    echo -n "$message "
    
    # Start the spinner in the background
    (
        while :; do
            local temp=${spinstr#?}
            printf "%c" "${spinstr}"
            spinstr=${temp}${spinstr%"${temp}"}
            sleep ${delay}
            printf "\b"
        done
    ) &
    
    # Store the PID of the spinner
    SPINNER_PID=$!
    disown
}

# Stop the spinner
stop_spinner() {
    # If the spinner function is defined in basic.sh, use its stop function
    if declare -f stop_spinner &>/dev/null; then
        if [[ -n "$SPINNER_PID" ]]; then
            kill -TERM "$SPINNER_PID" &>/dev/null
            SPINNER_PID=""
        fi
        return 0
    fi
    
    # Otherwise, use our simple implementation
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" &>/dev/null
        SPINNER_PID=""
        echo -e "\b${GREEN}Done!${NC}"
    fi
}

# Wait for a keypress
wait_for_keypress() {
    echo -e "\n${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s
}

# Print a box header
print_box_header() {
    local title="$1"
    local width="$2"
    local color="${3:-$BLUE}"
    
    # Print top border
    printf "${color}${BOX_TL}${NC}"
    printf "${color}%${width}s${NC}" | tr ' ' "$BOX_H"
    printf "${color}${BOX_TR}${NC}\n"
    
    # Print title
    local title_len=${#title}
    local padding=$(( (width - title_len) / 2 ))
    
    printf "${color}${BOX_V}${NC}"
    printf "%${padding}s" ""
    printf "${BOLD}${color}%s${NC}" "$title"
    printf "%$((width - title_len - padding))s" ""
    printf "${color}${BOX_V}${NC}\n"
    
    # Print divider
    printf "${color}${BOX_LT}${NC}"
    printf "${color}%${width}s${NC}" | tr ' ' "$BOX_H"
    printf "${color}${BOX_RT}${NC}\n"
}

# Print a box footer
print_box_footer() {
    local width="$1"
    local color="${2:-$BLUE}"
    
    # Print bottom border
    printf "${color}${BOX_BL}${NC}"
    printf "${color}%${width}s${NC}" | tr ' ' "$BOX_H"
    printf "${color}${BOX_BR}${NC}\n"
}

# Print a progress bar
print_progress_bar() {
    local progress="$1"  # Percentage (0-100)
    local width="$2"     # Width of the progress bar
    local color="${3:-$GREEN}"
    
    # Calculate the number of filled and empty slots
    local filled_slots=$(( progress * width / 100 ))
    local empty_slots=$(( width - filled_slots ))
    
    # Print the progress bar
    printf "["
    printf "${color}%${filled_slots}s${NC}" | tr ' ' '#'
    printf "%${empty_slots}s" | tr ' ' '.'
    printf "] %3d%%\r" "$progress"
}

# Show a step header
show_step_header() {
    local title="$1"
    local width="${2:-80}"
    
    # Clear the screen
    clear
    
    # Print the banner
    print_banner "Leonardo AI Universal" "$width"
    
    # Print the step header
    echo -e "\n${BOLD}${BLUE}$title${NC}\n"
    
    # Draw a separator
    printf "${BLUE}%${width}s${NC}\n\n" | tr ' ' '-'
}

# Show an error message
show_error() {
    local message="$1"
    
    # Log the error
    log_message "ERROR" "$message"
    
    # Print the error message
    echo -e "\n${RED}Error:${NC} $message"
    echo ""
    
    # Wait for keypress
    wait_for_keypress
}

# Show a success message
show_success() {
    local message="$1"
    
    # Log the success
    log_message "INFO" "$message"
    
    # Print the success message with friendly llama
    echo -e "\n${GREEN}Success:${NC} $message"
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}All done!${NC}"
    echo ""
    
    # Wait for keypress
    wait_for_keypress
}

# Show a warning message
show_warning() {
    local message="$1"
    local severity="${2:-normal}"  # normal, caution, danger
    
    # Log the warning
    log_message "WARNING" "$message (severity: $severity)"
    
    # Determine color and llama based on severity
    local color="$YELLOW"
    local llama="(•ᴗ•)🦙"
    local llama_color="$YELLOW"
    
    if [[ "$severity" == "caution" ]]; then
        color="$ORANGE"
        llama="(>‿-)🦙"
        llama_color="$ORANGE"
    elif [[ "$severity" == "danger" ]]; then
        color="$RED"
        llama="(ಠ‿ಠ)🦙"
        llama_color="$RED"
    fi
    
    # Print the warning message with appropriate llama
    echo -e "\n${color}Warning:${NC} $message"
    echo -e "${llama_color}${llama}${NC} ${llama_color}Please proceed with caution.${NC}"
    echo ""
}

# Confirm an action
confirm_action() {
    local message="$1"
    local severity="${2:-normal}"  # normal, caution, danger
    
    # Determine prompt color based on severity
    local color="$YELLOW"
    if [[ "$severity" == "caution" ]]; then
        color="$ORANGE"
    elif [[ "$severity" == "danger" ]]; then
        color="$RED"
    fi
    
    # Print the confirmation message
    echo -e "${color}$message${NC} (y/n) "
    
    # Get user input
    local response
    read -r response
    
    # Check response
    case "$response" in
        [Yy]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Print a banner
print_banner() {
    local title="$1"
    local width="${2:-80}"
    
    # Check if the banner function is defined in basic.sh
    if declare -f banner &>/dev/null; then
        banner "$title" "$width"
        return 0
    fi
    
    # Otherwise, use a simple banner implementation
    local title_len=${#title}
    local padding=$(( (width - title_len) / 2 ))
    
    # Print top border
    printf "${BLUE}%${width}s${NC}\n" | tr ' ' '='
    
    # Print title
    printf "%${padding}s" ""
    printf "${BOLD}${BLUE}%s${NC}\n" "$title"
    
    # Print bottom border
    printf "${BLUE}%${width}s${NC}\n" | tr ' ' '='
}

# Get device information
get_device_info() {
    local device="$1"
    local info_type="$2"  # model, size, serial
    
    # Try to get device information using various tools
    case "$info_type" in
        model)
            # Try lsblk first
            local model=$(lsblk -dno MODEL "$device" 2>/dev/null | tr -d '\n')
            
            # If empty, try hdparm
            if [[ -z "$model" ]] && command -v hdparm &>/dev/null; then
                model=$(hdparm -I "$device" 2>/dev/null | grep "Model Number" | cut -d: -f2 | tr -d ' \n')
            fi
            
            # If still empty, use device name
            if [[ -z "$model" ]]; then
                model=$(basename "$device")
            fi
            
            echo "$model"
            ;;
            
        size)
            # Try lsblk first
            lsblk -dno SIZE "$device" 2>/dev/null | tr -d '\n'
            ;;
            
        serial)
            # Try lsblk first
            local serial=$(lsblk -dno SERIAL "$device" 2>/dev/null | tr -d '\n')
            
            # If empty, try hdparm
            if [[ -z "$serial" ]] && command -v hdparm &>/dev/null; then
                serial=$(hdparm -I "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | tr -d ' \n')
            fi
            
            # If still empty, generate a unique identifier
            if [[ -z "$serial" ]]; then
                serial="$(basename "$device")_$(date +%Y%m%d%H%M%S)"
            fi
            
            echo "$serial"
            ;;
    esac
}

# Finalize the installation
finalize_installation() {
    local device="$1"
    
    # Show step header
    show_step_header "Installation Complete" "$UI_WIDTH"
    
    # Show success message with friendly llama
    echo -e "${GREEN}Congratulations!${NC} Your Leonardo AI USB device is ready."
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}Leonardo AI has been successfully installed.${NC}"
    echo ""
    
    # Mount the device to get partition info
    local mount_point="$TMP_DIR/finalize_mount"
    mkdir -p "$mount_point"
    
    if mount "${device}1" "$mount_point"; then
        # Get the number of models installed
        local model_count=0
        if [[ -d "$mount_point/leonardo/models" ]]; then
            model_count=$(find "$mount_point/leonardo/models" -type d -mindepth 1 -maxdepth 1 | wc -l)
        fi
        
        # Show information about the installation
        echo -e "${BOLD}Installation Summary:${NC}"
        echo -e "  Device: ${CYAN}$device${NC}"
        echo -e "  Filesystem: ${CYAN}$(lsblk -dno FSTYPE "${device}1")${NC}"
        echo -e "  Total Size: ${CYAN}$(lsblk -dno SIZE "$device")${NC}"
        echo -e "  Models Installed: ${CYAN}$model_count${NC}"
        echo ""
        
        # Show instructions for using the USB device
        echo -e "${BOLD}Next Steps:${NC}"
        echo -e "  1. Safely eject the USB device."
        echo -e "  2. Insert it into the computer where you want to use Leonardo AI."
        echo -e "  3. Run the ${CYAN}launcher.sh${NC} script on the USB device."
        echo ""
        
        # Show USB device path for reference
        echo -e "${BOLD}USB Device Path:${NC} ${CYAN}${device}1${NC}"
        echo ""
        
        # Unmount the device
        umount "$mount_point"
    else
        # Show warning that we couldn't get detailed information
        echo -e "${YELLOW}Note:${NC} Could not mount the device to get detailed information."
        echo -e "      The installation is complete, but please check the USB device manually."
        echo ""
    fi
    
    # Clean up
    rmdir "$mount_point" 2>/dev/null
    
    # Log the completion
    log_message "INFO" "Installation finalized for $device"
    
    # Wait for keypress
    wait_for_keypress
}
