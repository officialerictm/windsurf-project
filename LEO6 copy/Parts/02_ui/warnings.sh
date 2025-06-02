# ==============================================================================
# Warning System
# ==============================================================================
# Description: Graduated warning system with llama mascots for different severity levels
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/colors.sh,02_ui/basic.sh
# ==============================================================================

# Print a message with appropriate llama mascot and severity color
# Based on memory f17ef71f - Implemented progression of warning severities
print_llama_message() {
    local severity="$1"  # normal, caution, danger
    local message="$2"
    local width="${3:-$UI_WIDTH}"
    
    local llama_icon=""
    local llama_color=""
    local box_color=""
    local title=""
    
    # Set the appropriate llama mascot and colors based on severity
    case "$severity" in
        "normal")
            llama_icon="$LLAMA_NORMAL"
            llama_color="$LLAMA_COLOR_NORMAL"
            box_color="$YELLOW"
            title="NOTICE"
            ;;
        "caution")
            llama_icon="$LLAMA_CAUTION"
            llama_color="$LLAMA_COLOR_CAUTION"
            box_color="$LLAMA_COLOR_CAUTION"
            title="CAUTION"
            ;;
        "danger")
            llama_icon="$LLAMA_DANGER"
            llama_color="$LLAMA_COLOR_DANGER"
            box_color="$RED"
            title="⚠️ WARNING ⚠️"
            ;;
        *)
            llama_icon="$LLAMA_NORMAL"
            llama_color="$LLAMA_COLOR_NORMAL"
            box_color="$YELLOW"
            title="NOTICE"
            ;;
    esac
    
    # Create a helper function for box line printing (for consistent formatting)
    local _print_box_line
    _print_box_line() {
        print_box_line "$BOX_H" "$width" "$1" "$2" "$box_color"
    }
    
    # Print the message box with llama mascot
    echo ""
    _print_box_line "$BOX_TL" "$BOX_TR"
    
    # Print title if provided
    printf "${box_color}${BOX_V}${NC} ${BOLD}${box_color}%s${NC}%*s ${box_color}${BOX_V}${NC}\n" "$title" $((width - ${#title} - 4)) ""
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print llama mascot
    printf "${box_color}${BOX_V}${NC} ${llama_color}%s${NC}%*s ${box_color}${BOX_V}${NC}\n" "$llama_icon" $((width - ${#llama_icon} - 4)) ""
    
    # Print the message
    print_box_content "$message" "$width" "$box_color" 2 2
    
    # Print the bottom of the box
    _print_box_line "$BOX_BL" "$BOX_BR"
    echo ""
}

# Show a friendly notice (normal operations)
show_notice() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    print_llama_message "normal" "$message" "$width"
}

# Show a caution warning (first level warning)
show_caution() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    print_llama_message "caution" "$message" "$width"
}

# Show a danger warning (most severe)
show_danger() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    print_llama_message "danger" "$message" "$width"
}

# Show detailed data destruction warning
# Based on memory 0f09a1d0 - Enhanced data destruction warning
show_data_destruction_warning() {
    local device="$1"
    local operation="${2:-Format USB Drive}"
    local width="${3:-$UI_WIDTH}"
    
    # Create a helper function for box line printing (for consistent formatting)
    local _print_box_line
    _print_box_line() {
        print_box_line "$BOX_H" "$width" "$1" "$2" "$RED"
    }
    
    # Print the warning box
    echo ""
    _print_box_line "$BOX_TL" "$BOX_TR"
    
    # Print title
    print_centered "${BOLD}${RED}⚠️ DATA DESTRUCTION IMMINENT ⚠️${NC}" "$width"
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print llama mascot with message
    printf "${RED}${BOX_V}${NC} ${RED}${LLAMA_DANGER} ${BOLD}THIS IS YOUR FINAL WARNING!${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 30 - ${#LLAMA_DANGER})) ""
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print operation details
    printf "${RED}${BOX_V}${NC} ${BOLD}Target Device:${NC} %-$((width-20))s ${RED}${BOX_V}${NC}\n" "$device"
    printf "${RED}${BOX_V}${NC} ${BOLD}Operation:${NC} %-$((width-16))s ${RED}${BOX_V}${NC}\n" "$operation"
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print consequences
    printf "${RED}${BOX_V}${NC} ${BOLD}This operation will:${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 21)) ""
    printf "${RED}${BOX_V}${NC}   • ${BOLD}${RED}PERMANENTLY ERASE ALL DATA${NC} on the device%*s ${RED}${BOX_V}${NC}\n" $((width - 51)) ""
    printf "${RED}${BOX_V}${NC}   • ${BOLD}${RED}DELETE ALL EXISTING PARTITIONS${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 41)) ""
    printf "${RED}${BOX_V}${NC}   • ${BOLD}${RED}DESTROY ALL FILE SYSTEMS${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 36)) ""
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print verification reminders
    printf "${RED}${BOX_V}${NC} ${BOLD}Before continuing, verify:${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 28)) ""
    printf "${RED}${BOX_V}${NC}   • You have backed up all important data%*s ${RED}${BOX_V}${NC}\n" $((width - 47)) ""
    printf "${RED}${BOX_V}${NC}   • You are targeting the correct device%*s ${RED}${BOX_V}${NC}\n" $((width - 45)) ""
    printf "${RED}${BOX_V}${NC}   • You understand this action is irreversible%*s ${RED}${BOX_V}${NC}\n" $((width - 50)) ""
    
    # Print the bottom of the box
    _print_box_line "$BOX_BL" "$BOX_BR"
    echo ""
}

# Request user confirmation with appropriate warning level
confirm_action() {
    local message="$1"
    local severity="${2:-normal}"  # normal, caution, danger
    local default="${3:-n}"        # y or n
    
    # Show the warning with appropriate llama
    case "$severity" in
        "normal") show_notice "$message" ;;
        "caution") show_caution "$message" ;;
        "danger") show_danger "$message" ;;
    esac
    
    # Set up prompt based on default
    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="Continue? [Y/n]: "
    else
        prompt="Continue? [y/N]: "
    fi
    
    # Ask for confirmation
    local response
    echo -n "$prompt"
    read -r response
    
    # Process response
    response="${response:-$default}"
    case "${response,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# Verify dangerous operation with double confirmation
verify_dangerous_operation() {
    local message="$1"
    local device="$2"
    local operation="$3"
    
    # First confirmation with caution level
    if ! confirm_action "$message" "caution"; then
        return 1
    fi
    
    # Show detailed destruction warning
    show_data_destruction_warning "$device" "$operation"
    
    # Final confirmation with danger level
    local final_message="Type 'YES, I AM SURE' (all uppercase) to confirm you want to proceed:"
    echo -e "$final_message"
    
    local response
    read -r response
    
    if [[ "$response" == "YES, I AM SURE" ]]; then
        return 0
    else
        echo -e "\n${YELLOW}Operation cancelled by user.${NC}"
        return 1
    fi
}
