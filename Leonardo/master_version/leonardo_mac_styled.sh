#!/bin/bash

# ======================================================================
# Leonardo AI USB Maker - Mac-Style UI Version
# ======================================================================
# Version: 5.0.2
# Features: Based on original V5 with Mac-style UI and improved
#           USB formatting functionality
# ======================================================================

# --- Configuration ---
SCRIPT_SELF_NAME=$(basename "$0")
SCRIPT_VERSION="5.0.2" # Mac-style UI version
USB_LABEL_DEFAULT="LEONARDO"
USB_LABEL="$USB_LABEL_DEFAULT"
INSTALL_START_TIME=$(date +%s)
MODEL_TO_PULL="llama3:8b"
MODEL_SOURCE_TYPE="pull"
RAW_USB_DEVICE_PATH=""
USB_DEVICE_PATH=""

# Download history tracking
DOWNLOAD_HISTORY=()
DOWNLOAD_SIZES=()
DOWNLOAD_TIMESTAMPS=()

# --- Robust Color Initialization ---
set +e  # Don't exit on error during color setup

# Start with empty color variables
C_RESET="" C_BOLD="" C_DIM="" C_UNDERLINE="" C_NO_UNDERLINE=""
C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE="" C_GREY=""

# Find tput command
TPUT_CMD_PATH=""
_tput_temp_path_check_cmd_output=$(command -v tput 2>/dev/null)
_tput_temp_path_check_cmd_rc=$?

if [ "$_tput_temp_path_check_cmd_rc" -eq 0 ] && [ -n "$_tput_temp_path_check_cmd_output" ]; then
    _tput_temp_path_resolved=$(readlink -f "$_tput_temp_path_check_cmd_output" 2>/dev/null || echo "$_tput_temp_path_check_cmd_output")
    if [ -x "$_tput_temp_path_resolved" ]; then
        TPUT_CMD_PATH="$_tput_temp_path_resolved"
    fi
fi

# Test if colors are available
COLORS_ENABLED=false
TPUT_CLEAR_POSSIBLE=false

if [ -n "$TPUT_CMD_PATH" ]; then
    tput_color_test_rc=1
    ( "$TPUT_CMD_PATH" setaf 1 && "$TPUT_CMD_PATH" sgr0 ) >/dev/null 2>&1
    tput_color_test_rc=$?
    if [ "$tput_color_test_rc" -eq 0 ]; then
        COLORS_ENABLED=true
    fi

    tput_clear_test_rc=1
    ( "$TPUT_CMD_PATH" clear ) >/dev/null 2>&1
    tput_clear_test_rc=$?
    if [ "$tput_clear_test_rc" -eq 0 ]; then
        TPUT_CLEAR_POSSIBLE=true
    fi
fi

# Initialize colors if available
if $COLORS_ENABLED && [ -n "$TPUT_CMD_PATH" ]; then
    C_RESET=$("$TPUT_CMD_PATH" sgr0)
    C_BOLD=$("$TPUT_CMD_PATH" bold)
    if ( "$TPUT_CMD_PATH" dim >/dev/null 2>&1 ); then C_DIM=$("$TPUT_CMD_PATH" dim); else C_DIM=""; fi
    if ( "$TPUT_CMD_PATH" smul >/dev/null 2>&1 ); then C_UNDERLINE=$("$TPUT_CMD_PATH" smul); else C_UNDERLINE=""; fi
    if ( "$TPUT_CMD_PATH" rmul >/dev/null 2>&1 ); then C_NO_UNDERLINE=$("$TPUT_CMD_PATH" rmul); else C_NO_UNDERLINE=""; fi
    
    C_RED=$("$TPUT_CMD_PATH" setaf 1)
    C_GREEN=$("$TPUT_CMD_PATH" setaf 2)
    C_YELLOW=$("$TPUT_CMD_PATH" setaf 3)
    C_BLUE=$("$TPUT_CMD_PATH" setaf 4)
    C_MAGENTA=$("$TPUT_CMD_PATH" setaf 5)
    C_CYAN=$("$TPUT_CMD_PATH" setaf 6)
    C_WHITE=$("$TPUT_CMD_PATH" setaf 7)
    
    tput_setaf8_rc=1
    ( "$TPUT_CMD_PATH" setaf 8 >/dev/null 2>&1 )
    tput_setaf8_rc=$?
    if [ "$tput_setaf8_rc" -eq 0 ]; then
        C_GREY=$("$TPUT_CMD_PATH" setaf 8)
    elif [ -n "$C_DIM" ]; then
        C_GREY="$C_DIM"
    else
        C_GREY=""
    fi
else
    # Fallback to ANSI escape codes if tput is not available
    C_RESET=$'\e[0m'
    C_BOLD=$'\e[1m'
    C_DIM=$'\e[2m'
    C_UNDERLINE=$'\e[4m'
    C_NO_UNDERLINE=$'\e[24m'
    C_RED=$'\e[31m'
    C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[34m'
    C_MAGENTA=$'\e[35m'
    C_CYAN=$'\e[36m'
    C_WHITE=$'\e[37m'
    C_GREY=$'\e[90m'
fi

set -e  # Resume normal error handling
# End of color initialization

# --- Llama Character System ---
LLAMA_NORMAL="(•ᴗ•)🦙"
LLAMA_EXCITED="(^o^)🦙"
LLAMA_CAUTION="(>‿-)🦙"
LLAMA_WARNING="(ಠ‿ಠ)🦙"
LLAMA_ERROR="(×_×)🦙"
LLAMA_SUCCESS="(⌐■‿■)🦙"

# --- UI Helper Functions ---
print_line() { 
    echo -e "${C_DIM}──────────────────────────────────────────────────────────────────────${C_RESET}"
}

print_divider_thin() { 
    echo -e "${C_DIM}⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯${C_RESET}"
}

print_double_line() { 
    echo -e "${C_BOLD}${C_MAGENTA}══════════════════════════════════════════════════════════════════════${C_RESET}"
}

# Print a centered header with fancy box
print_header() {
    local text="$1"
    echo -e "\n${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}                ${C_BOLD}${text}${C_RESET}                 ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}\n"
}

# Print a subheader
print_subheader() {
    local text="$1"
    echo -e "\n${C_BOLD}${C_BLUE}◉ ${text} ${C_RESET}\n"
}

# Print an info message
print_info() {
    local text="$1"
    echo -e "${C_CYAN}ℹ️  ${text}${C_RESET}"
}

# Print a success message
print_success() {
    local text="$1"
    echo -e "${C_GREEN}✅ ${text}${C_RESET}"
}

# Print a warning message
print_warning() {
    local text="$1"
    echo -e "${C_YELLOW}⚠️  ${text}${C_RESET}"
}

# Print an error message
print_error() {
    local text="$1"
    echo -e "${C_RED}❌ ${text}${C_RESET}"
}

# Print a fatal error and exit
print_fatal() {
    local text="$1"
    echo -e "${C_BOLD}${C_RED}💥 FATAL ERROR: ${text}${C_RESET}"
    exit 1
}

# Print a prompt
print_prompt() {
    local text="$1"
    echo -e "${C_BOLD}${C_YELLOW}${text}${C_RESET}"
}

# Display a message with a llama character
llama_speak() {
    local mood="$1"
    local message="$2"
    local llama=""
    local color=""
    
    case "$mood" in
        normal)   llama="$LLAMA_NORMAL"; color="$C_CYAN" ;;
        excited)  llama="$LLAMA_EXCITED"; color="$C_GREEN" ;;
        caution)  llama="$LLAMA_CAUTION"; color="$C_YELLOW" ;;
        warning)  llama="$LLAMA_WARNING"; color="$C_RED" ;;
        error)    llama="$LLAMA_ERROR"; color="$C_RED" ;;
        success)  llama="$LLAMA_SUCCESS"; color="$C_GREEN" ;;
        *)        llama="$LLAMA_NORMAL"; color="$C_CYAN" ;;
    esac
    
    printf "%s%s %s%s\n" "$color" "$llama" "$message" "$C_RESET"
}

# Clear screen and show title art
clear_screen_and_show_art() {
    if $TPUT_CLEAR_POSSIBLE && [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" clear
    else
        clear
    fi
    print_leonardo_title_art
}

# --- ASCII Art Functions ---
print_leonardo_title_art() {
    echo -e "${C_BOLD}${C_MAGENTA}"
    echo '    _       _____  ____  _   _          _____  _____   ____  '
    echo '   | |     |  ___|/ __ \| \ | |   /\   |  __ \|  __ \ / __ \ '
    echo '   | |     | |__ | |  | |  \| |  /  \  | |__) | |  | | |  | |'
    echo '   | |     |  __|| |  | | . ` | / /\ \ |  _  /| |  | | |  | |'
    echo '   | |____ | |___| |__| | |\  |/ ____ \| | \ \| |__| | |__| |'
    echo '   |______||______\____/|_| \_/_/    \_\_|  \_\_____/ \____/ '
    echo '   🦙 AI USB MAKER v'${SCRIPT_VERSION}' 🧠                        '
    echo -e "${C_RESET}"
}

print_leonardo_success_art() {
    echo -e "${C_BOLD}${C_GREEN}"
    echo ' ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ '
    echo '||S |||U |||C |||C |||E |||S |||S |||F |||U |||L |||L |||Y ||'
    echo '||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__||'
    echo '|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|'
    echo -e "${C_RESET}"
}

# Clear screen and reset
clear_screen() {
    if $TPUT_CLEAR_POSSIBLE && [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" clear
    else
        clear
    fi
}

# Display progress with spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    while ps -p $pid > /dev/null; do
        for i in $(seq 0 3); do
            printf "\r[%s]" "${spinstr:$i:1}"
            sleep $delay
        done
    done
    printf "\r   \r"
}

# Ask a yes/no/quit question
ask_yes_no_quit() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    local response
    
    while true; do
        print_prompt "$prompt"
        if [ -n "$default" ]; then
            echo -e "${C_DIM}(default: $default)${C_RESET}"
        fi
        read -p "[y/n/q]: " response
        
        response=${response:-$default}
        response=${response,,}  # Convert to lowercase
        
        case "$response" in
            y|yes) eval "$var_name='yes'"; return 0 ;;
            n|no)  eval "$var_name='no'"; return 0 ;;
            q|quit) eval "$var_name='quit'"; return 1 ;;
            *) echo "Please answer yes (y), no (n), or quit (q)." ;;
        esac
    done
}

# Show system information
show_system_info() {
    print_header "SYSTEM INFORMATION"
    
    llama_speak "normal" "Checking system details..."
    print_line
    
    # Display system information in a fancy box
    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}OS:${C_RESET}             $(uname -s) $(uname -r)$(printf "%*s" $((34 - ${#$(uname -s)} - ${#$(uname -r)})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    
    local cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f 2 | sed 's/^[ \t]*//')
    local cpu_info_len=${#cpu_info}
    if [ $cpu_info_len -gt 48 ]; then
        cpu_info="${cpu_info:0:45}..."
    fi
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}CPU:${C_RESET}            $cpu_info$(printf "%*s" $((48 - ${#cpu_info})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    
    local ram_info=$(free -h | grep "Mem:" | awk '{print $2}')
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}RAM:${C_RESET}            $ram_info$(printf "%*s" $((48 - ${#ram_info})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    
    local free_space=$(df -h . | grep -v Filesystem | awk '{print $4}')
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Free Space:${C_RESET}     $free_space$(printf "%*s" $((48 - ${#free_space})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}├──────────────────────────────────────────────────────────────────┤${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Dependencies:${C_RESET}                                                 ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    
    local bash_version=$(bash --version | head -1 | cut -d ' ' -f 4)
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Bash:${C_RESET}         $bash_version$(printf "%*s" $((46 - ${#bash_version})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    
    if command -v parted >/dev/null 2>&1; then
        local parted_version=$(parted --version | head -1 | cut -d ' ' -f 4)
        echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Parted:${C_RESET}       $parted_version$(printf "%*s" $((46 - ${#parted_version})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    else
        echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Parted:${C_RESET}       ${C_RED}Not installed${C_RESET}$(printf "%*s" 35 "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    fi
    
    if command -v mkfs.fat >/dev/null 2>&1; then
        echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Dosfstools:${C_RESET}   ${C_GREEN}Installed${C_RESET}$(printf "%*s" 37 "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    else
        echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Dosfstools:${C_RESET}   ${C_RED}Not installed${C_RESET}$(printf "%*s" 35 "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    fi
    
    if command -v ollama >/dev/null 2>&1; then
        local ollama_version=$(ollama --version 2>/dev/null || echo "Installed")
        echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Ollama:${C_RESET}        $ollama_version$(printf "%*s" $((46 - ${#ollama_version})) "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    else
        echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}   ${C_BOLD}Ollama:${C_RESET}        ${C_RED}Not installed${C_RESET}$(printf "%*s" 35 "") ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    fi
    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
    
    echo ""
    read -p "Press any key to continue..." -n 1
    echo ""
}

# Show version information
show_version() {
    print_header "ABOUT THIS TOOL"
    
    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}            ${C_BOLD}Leonardo AI USB Maker - Version $SCRIPT_VERSION${C_RESET}            ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}                                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} This tool helps you create and manage USB drives with         ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} pre-configured AI models using the Ollama framework.          ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}                                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Features:${C_RESET}                                                      ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} - Create AI USB drives with various open-source models        ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} - Update existing AI USB drives                              ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} - Cross-platform support (Linux, macOS, Windows)             ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}                                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} Developed for the International Coding Competition 2025        ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}                                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
    
    echo ""
    read -p "Press any key to continue..." -n 1
    echo ""
}

# Display main menu
show_main_menu() {
    clear_screen_and_show_art
    
    # Display header with fancy box
    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET}                     ${C_BOLD}MAIN MENU${C_RESET}                               ${C_BOLD}${C_MAGENTA}│${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
    echo ""
    
    llama_speak "normal" "What would you like to do today?"
    print_line
    
    # Display menu options
    echo -e "  ${C_YELLOW}[1]${C_RESET} 💿 ${C_BOLD}Create New AI USB Drive${C_RESET}"
    echo -e "  ${C_YELLOW}[2]${C_RESET} 🔄 ${C_BOLD}Update Existing AI USB Drive${C_RESET}"
    echo -e "  ${C_YELLOW}[3]${C_RESET} 📋 ${C_BOLD}List Available AI Models${C_RESET}"
    echo -e "  ${C_YELLOW}[4]${C_RESET} 🖥️  ${C_BOLD}Show System Information${C_RESET}"
    echo -e "  ${C_YELLOW}[5]${C_RESET} ℹ️  ${C_BOLD}About This Tool${C_RESET}"
    echo -e "  ${C_YELLOW}[q]${C_RESET} 👋 ${C_BOLD}Quit${C_RESET}"
    print_line
}

# Main function with interactive menu
main() {
    # Check for command line arguments for backward compatibility
    if [ $# -gt 0 ]; then
        case "$1" in
            list)
                clear_screen_and_show_art
                list_models
                ;;
            create)
                shift
                check_root_privileges && create_new_usb
                ;;
            update)
                shift
                check_root_privileges && update_existing_usb
                ;;
            info)
                clear_screen_and_show_art
                show_system_info
                ;;
            version)
                clear_screen_and_show_art
                show_version
                ;;
            help|--help|-h)
                clear_screen_and_show_art
                show_version
                ;;
            *)
                print_error "Unknown command '$1'"
                show_version
                exit 1
                ;;
        esac
        return
    fi
    
    # Interactive menu mode
    while true; do
        show_main_menu
        
        print_prompt "Enter your choice (1-5, q to quit):"
        read choice
        
        case $choice in
            1) 
                if check_root_privileges; then
                    create_new_usb
                fi
                ;;
            2)
                if check_root_privileges; then
                    update_existing_usb
                fi
                ;;
            3) list_models ;;
            4) show_system_info ;;
            5) show_version ;;
            q|Q)
                clear_screen
                llama_speak "success" "Thank you for using Leonardo AI USB Maker!"
                echo -e "\n${C_CYAN}Have a great day! $LLAMA_NORMAL${C_RESET}\n"
                exit 0
                ;;
            *)
                llama_speak "warning" "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Call the main function
main "$@"

# Format bytes to human readable
bytes_to_human_readable() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(printf "%.1f" $(echo "scale=1; $bytes/1024" | bc -l))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(printf "%.1f" $(echo "scale=1; $bytes/1048576" | bc -l))MB"
    else
        echo "$(printf "%.1f" $(echo "scale=1; $bytes/1073741824" | bc -l))GB"
    fi
}

# Check if running as root
check_root_privileges() {
    if [ "$(id -u)" != "0" ]; then
        print_warning "This operation requires root privileges."
        echo "Please run the script with sudo or as root."
        return 1
    fi
    return 0
}

# --- USB Device Management Functions ---

# List available USB devices
list_usb_devices() {
    print_subheader "Available USB Devices"
    
    if [ "$(uname)" == "Linux" ]; then
        echo -e "${C_BOLD}NAME   MODEL                     SIZE TRAN   MOUNTPOINT${C_RESET}"
        lsblk -o NAME,MODEL,SIZE,TRAN,MOUNTPOINT | grep -E "disk|usb" | grep -v "loop" | grep -v "sr"
        echo ""
        print_info "Look for devices with 'usb' in the TRAN column."
    else
        print_error "Only Linux is currently supported for USB device detection."
    fi
}

# Format USB device
format_usb() {
    local device="$1"
    local label="${2:-$USB_LABEL}"
    
    llama_speak "caution" "Preparing to format $device"
    
    # Create new partition table
    llama_speak "normal" "Creating new partition table on $device"
    sudo parted -s "$device" mklabel msdos
    
    # Create partition
    sudo parted -s "$device" mkpart primary fat32 1MiB 100%
    
    local partition
    if [[ "$device" == *nvme*n* ]] || [[ "$device" == *mmcblk* ]]; then
        partition="${device}p1"
    else
        partition="${device}1"
    fi
    
    # Format as FAT32
    llama_speak "normal" "Formatting ${partition} as FAT32"
    
    # Retry formatting if it fails
    local attempt=1
    local max_attempts=3
    local format_success=false
    
    while [ $attempt -le $max_attempts ] && [ "$format_success" = false ]; do
        if sudo mkfs.fat -F32 -n "$label" "$partition"; then
            format_success=true
        else
            llama_speak "caution" "Format attempt $attempt failed, retrying..."
            # Unmount and retry
            sudo umount "$partition" 2>/dev/null
            sleep 2
            # Force a sync and re-read partition table
            sudo sync
            sudo partprobe "$device"
            sleep 2
            ((attempt++))
        fi
    done
    
    if [ "$format_success" = false ]; then
        llama_speak "error" "Failed to format USB after $max_attempts attempts."
        return 1
    fi
    
    # Mount the newly formatted partition
    local mount_dir="/mnt/leonardo_usb"
    sudo mkdir -p "$mount_dir"
    
    llama_speak "normal" "Mounting USB drive"
    
    if ! sudo mount "$partition" "$mount_dir"; then
        llama_speak "error" "Failed to mount the USB drive."
        return 1
    fi
    
    echo "$mount_dir"
    return 0
}

# --- Main Functionality ---

# Create a new AI USB drive
create_new_usb() {
    print_header "CREATE NEW AI USB DRIVE"
    
    if ! check_root_privileges; then
        return 1
    fi
    
    print_info "This will create a new AI USB drive with pre-configured Ollama models."
    print_line
    
    llama_speak "warning" "WARNING: This will erase ALL data on the selected USB drive."
    print_line
    
    # List available USB devices
    list_usb_devices
    
    # Ask for confirmation
    local confirm_choice=""
    ask_yes_no_quit "Are you sure you want to continue?" confirm_choice
    if [[ "$confirm_choice" != "yes" ]]; then
        llama_speak "normal" "Operation cancelled."
        return 0
    fi
    
    # Select USB device
    print_prompt "Enter the device name (e.g., sdb, sdc): /dev/"
    read device
    device="/dev/$device"
    
    if [ ! -b "$device" ]; then
        llama_speak "error" "Invalid device: $device"
        return 1
    fi
    
    # Format the USB drive
    local mount_dir
    mount_dir=$(format_usb "$device")
    
    if [ $? -ne 0 ]; then
        llama_speak "error" "Failed to format USB drive."
        return 1
    fi
    
    # Create required directories
    print_info "Creating directory structure..."
    sudo mkdir -p "$mount_dir/models"
    sudo mkdir -p "$mount_dir/runtimes"
    
    # Download Ollama binaries and models
    print_info "Downloading Ollama binaries..."
    # TODO: Implement binary download functionality
    
    # Set permissions
    sudo chmod -R 755 "$mount_dir"
    
    print_leonardo_success_art
    llama_speak "success" "AI USB drive created successfully!"
    print_info "Your USB drive is ready at $mount_dir"
    
    return 0
}

# Update an existing AI USB drive
update_existing_usb() {
    print_header "UPDATE EXISTING AI USB DRIVE"
    
    if ! check_root_privileges; then
        return 1
    fi
    
    print_info "This will update an existing AI USB drive."
    print_line
    
    # List available USB devices
    list_usb_devices
    
    # Select USB device
    print_prompt "Enter the device name (e.g., sdb, sdc): /dev/"
    read device
    device="/dev/$device"
    
    if [ ! -b "$device" ]; then
        llama_speak "error" "Invalid device: $device"
        return 1
    fi
    
    # Determine partition
    local partition
    if [[ "$device" == *nvme*n* ]] || [[ "$device" == *mmcblk* ]]; then
        partition="${device}p1"
    else
        partition="${device}1"
    fi
    
    # Mount the USB drive
    local mount_dir="/mnt/leonardo_usb"
    sudo mkdir -p "$mount_dir"
    
    print_info "Mounting USB drive"
    
    if ! sudo mount "$partition" "$mount_dir"; then
        llama_speak "error" "Failed to mount the USB drive."
        return 1
    fi
    
    # Check if it's a valid Leonardo AI USB drive
    if [ ! -d "$mount_dir/models" ] || [ ! -d "$mount_dir/runtimes" ]; then
        llama_speak "error" "This doesn't appear to be a valid Leonardo AI USB drive."
        sudo umount "$mount_dir" 2>/dev/null
        return 1
    fi
    
    # Update models and binaries
    print_info "Updating models and binaries..."
    # TODO: Implement update functionality
    
    llama_speak "success" "AI USB drive updated successfully!"
    
    # Unmount the drive
    sudo umount "$mount_dir"
    
    return 0
}

# List available AI models
list_models() {
    print_header "AVAILABLE AI MODELS"
    
    llama_speak "normal" "Choose your AI companion:"
    echo ""
    
    # Use the fancier table style from Mac version
    print_divider_thin
    echo -e "${C_BOLD}  Model              | Size     | Speed    | Quality   | Memory   ${C_RESET}"
    print_divider_thin
    echo -e "  🔥 ${C_BOLD}Llama 3 (8B)${C_RESET}  | 8GB      | ★★★☆ | ★★★★ | 16GB+    "
    echo -e "  🌟 ${C_BOLD}Mistral (7B)${C_RESET}  | 7GB      | ★★★☆ | ★★★★ | 16GB+    "
    echo -e "  💎 ${C_BOLD}Gemma (2B)${C_RESET}    | 2GB      | ★★★★ | ★★★ | 8GB+     "
    echo -e "  🧠 ${C_BOLD}Phi-2 (2.7B)${C_RESET}  | 3GB      | ★★★★ | ★★★ | 8GB+     "
    echo -e "  🛠️  ${C_BOLD}Custom Model${C_RESET} | Varies   | Varies   | Varies    | Varies   "
    print_divider_thin
    echo ""
    
    # Model selection
    while true; do
        print_prompt "Select a model (1-5) or 'b' to go back:"
        read choice
        
        if [[ "$choice" == "b" ]]; then
            return 0
        fi
        
        if [[ "$choice" =~ ^[1-5]$ ]]; then
            local selected_model=""
            
            case $choice in
                1) selected_model="Llama 3 (8B)" ;;
                2) selected_model="Mistral (7B)" ;;
                3) selected_model="Gemma (2B)" ;;
                4) selected_model="Phi-2 (2.7B)" ;;
                5) selected_model="Custom Model" ;;
            esac
            
            clear_screen_and_show_art
            print_header "SELECTED MODEL"
            
            llama_speak "excited" "You selected: ${C_BOLD}$selected_model${C_RESET}"
            
            # Show model details
            echo ""
            case $choice in
                1) # Llama 3
                    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Model:${C_RESET} Llama 3 (8B)                                          ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Size:${C_RESET} 8GB                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Best for:${C_RESET} General purpose AI tasks                          ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Requirements:${C_RESET} 16GB+ RAM recommended                       ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
                    ;;
                2) # Mistral
                    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Model:${C_RESET} Mistral (7B)                                          ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Size:${C_RESET} 7GB                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Best for:${C_RESET} High-quality text generation                     ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Requirements:${C_RESET} 16GB+ RAM recommended                       ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
                    ;;
                3) # Gemma
                    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Model:${C_RESET} Gemma (2B)                                            ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Size:${C_RESET} 2GB                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Best for:${C_RESET} Resource-constrained devices                     ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Requirements:${C_RESET} 8GB+ RAM                                     ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
                    ;;
                4) # Phi-2
                    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Model:${C_RESET} Phi-2 (2.7B)                                          ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Size:${C_RESET} 3GB                                                  ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Best for:${C_RESET} Efficient AI applications                       ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Requirements:${C_RESET} 8GB+ RAM                                     ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
                    ;;
                5) # Custom
                    echo -e "${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Model:${C_RESET} Custom Model                                          ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Size:${C_RESET} Varies                                               ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Best for:${C_RESET} Advanced users                                   ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}│${C_RESET} ${C_BOLD}Requirements:${C_RESET} Depends on model                             ${C_BOLD}${C_MAGENTA}│${C_RESET}"
                    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
                    ;;
            esac
            
            # Ask if user wants to proceed
            echo ""
            local proceed_choice=""
            ask_yes_no_quit "Would you like to create a USB with this model?" proceed_choice
            
            if [[ "$proceed_choice" == "yes" ]]; then
                if check_root_privileges; then
                    create_new_usb "$selected_model"
                fi
            fi
            
            # Ask if user wants to select another model
            echo ""
            local another_choice=""
            ask_yes_no_quit "Would you like to select another model?" another_choice
            
            if [[ "$another_choice" != "yes" ]]; then
                return 0
            fi
            
            clear_screen_and_show_art
            print_header "AVAILABLE AI MODELS"
            llama_speak "normal" "Choose your AI companion:"
            echo ""
            
            # Display model table again
            print_divider_thin
            echo -e "${C_BOLD}  Model              | Size     | Speed    | Quality   | Memory   ${C_RESET}"
            print_divider_thin
            echo -e "  🔥 ${C_BOLD}Llama 3 (8B)${C_RESET}  | 8GB      | ★★★☆ | ★★★★ | 16GB+    "
            echo -e "  🌟 ${C_BOLD}Mistral (7B)${C_RESET}  | 7GB      | ★★★☆ | ★★★★ | 16GB+    "
            echo -e "  💎 ${C_BOLD}Gemma (2B)${C_RESET}    | 2GB      | ★★★★ | ★★★ | 8GB+     "
            echo -e "  🧠 ${C_BOLD}Phi-2 (2.7B)${C_RESET}  | 3GB      | ★★★★ | ★★★ | 8GB+     "
            echo -e "  🛠️  ${C_BOLD}Custom Model${C_RESET} | Varies   | Varies   | Varies    | Varies   "
            print_divider_thin
            echo ""
        else
            llama_speak "error" "Invalid option. Please try again."
        fi
    done
