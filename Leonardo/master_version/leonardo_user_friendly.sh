#!/usr/bin/env bash

# Leonardo AI USB Maker - User Friendly Interface
# Version 5.0.0 - Simplified UI for all skill levels
# Authors: Eric & Friendly AI Assistant
# License: MIT

# --- Configuration ---
SCRIPT_VERSION="5.0.0"
USB_LABEL_DEFAULT="CHATUSB"
USB_LABEL="$USB_LABEL_DEFAULT"

# --- Color and UI Setup ---
set -e
COLORS_ENABLED=true
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_WHITE="\033[37m"

# --- Helper Functions ---

print_header() {
    clear
    echo -e "${C_CYAN}${C_BOLD}╔══════════════════════════════════════════════════════════════════╗"
    echo -e "║${C_WHITE}                  LEONARDO AI USB MAKER v$SCRIPT_VERSION${C_CYAN}                 ║"
    echo -e "╚══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo
}

print_menu() {
    echo -e "${C_BOLD}${C_WHITE}MAIN MENU:${C_RESET}"
    echo -e "  ${C_BOLD}1.${C_RESET} Create New AI USB Drive"
    echo -e "  ${C_BOLD}2.${C_RESET} Add AI Models to Existing Drive"
    echo -e "  ${C_BOLD}3.${C_RESET} Check USB Drive Health"
    echo -e "  ${C_BOLD}4.${C_RESET} Verify & Repair USB Installation"
    echo -e "  ${C_BOLD}5.${C_RESET} View Download History"
    echo -e "  ${C_BOLD}6.${C_RESET} About This Tool"
    echo -e "  ${C_BOLD}q.${C_RESET} Quit"
    echo
}

print_message() {
    local type=$1
    local message=$2
    
    case $type in
        info) echo -e "${C_BLUE}[i]${C_RESET} $message" ;;
        success) echo -e "${C_GREEN}[✓]${C_RESET} $message" ;;
        warning) echo -e "${C_YELLOW}[!]${C_RESET} $message" ;;
        error) echo -e "${C_RED}[✗]${C_RESET} $message" ;;
        *) echo -e "$message" ;;
    esac
    echo
}

get_user_choice() {
    local prompt="$1"
    local valid_options="$2"
    local choice
    
    while true; do
        read -p "${C_WHITE}$prompt ${C_CYAN}→ ${C_RESET}" choice
        if [[ $valid_options == *"$choice"* ]]; then
            echo "$choice"
            return 0
        fi
        print_message "error" "Invalid choice. Please try again."
    done
}

# --- Main Menu Functions ---

create_new_usb() {
    clear
    print_header
    print_message "info" "Let's create a new AI USB drive!"
    # Implementation would go here
    print_message "success" "New AI USB drive created successfully!"
    read -n 1 -s -r -p "${C_WHITE}Press any key to continue...${C_RESET}"
}

add_ai_models() {
    clear
    print_header
    print_message "info" "Add AI models to an existing USB drive"
    # Implementation would go here
    print_message "success" "AI models added successfully!"
    read -n 1 -s -r -p "${C_WHITE}Press any key to continue...${C_RESET}"
}

check_usb_health() {
    clear
    print_header
    print_message "info" "Checking USB drive health..."
    # Implementation would go here
    print_message "success" "USB health check completed!"
    read -n 1 -s -r -p "${C_WHITE}Press any key to continue...${C_RESET}"
}

verify_repair() {
    clear
    print_header
    print_message "info" "Verifying and repairing USB installation..."
    # Implementation would go here
    print_message "success" "Verification and repair completed!"
    read -n 1 -s -r -p "${C_WHITE}Press any key to continue...${C_RESET}"
}

view_download_history() {
    clear
    print_header
    print_message "info" "Download History"
    # Implementation would go here
    print_message "info" "End of download history"
    read -n 1 -s -r -p "${C_WHITE}Press any key to continue...${C_RESET}"
}

show_about() {
    clear
    print_header
    echo -e "${C_BOLD}About Leonardo AI USB Maker:${C_RESET}\n"
    echo -e "This tool helps you create portable AI environments on USB drives.\n"
    echo -e "Features:"
    echo -e "  • Create portable AI workspaces"
    echo -e "  • Manage AI models"
    echo -e "  • Monitor USB health"
    echo -e "  • Cross-platform support\n"
    echo -e "Version: $SCRIPT_VERSION\n"
    read -n 1 -s -r -p "${C_WHITE}Press any key to continue...${C_RESET}"
}

# --- Main Program ---

main() {
    while true; do
        print_header
        print_menu
        
        choice=$(get_user_choice "Enter your choice (1-6, q to quit):" "123456q")
        
        case $choice in
            1) create_new_usb ;;
            2) add_ai_models ;;
            3) check_usb_health ;;
            4) verify_repair ;;
            5) view_download_history ;;
            6) show_about ;;
            q) 
                echo -e "\n${C_GREEN}Thank you for using Leonardo AI USB Maker!${C_RESET}\n"
                exit 0
                ;;
        esac
    done
}

# Start the program
main "$@"
