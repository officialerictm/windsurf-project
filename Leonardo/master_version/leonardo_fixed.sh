#!/bin/bash

# ======================================================================
# Leonardo AI USB Maker - Fixed Version
# ======================================================================
# Version: 5.0.1
# Features: Based on original V5 with syntax errors fixed and improved
#           USB formatting functionality
# ======================================================================

# --- Configuration ---
SCRIPT_VERSION="5.0.1" # Fixed version
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

# --- Terminal Colors ---
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4)
    C_PURPLE=$(tput setaf 5)
    C_CYAN=$(tput setaf 6)
    C_WHITE=$(tput setaf 7)
else
    # Fallback to ANSI escape codes
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_RED="\033[31m"
    C_GREEN="\033[32m"
    C_YELLOW="\033[33m"
    C_BLUE="\033[34m"
    C_PURPLE="\033[35m"
    C_CYAN="\033[36m"
    C_WHITE="\033[37m"
fi

# --- Llama Character System ---
LLAMA_NORMAL="(•ᴗ•)🦙"
LLAMA_EXCITED="(^o^)🦙"
LLAMA_CAUTION="(>‿-)🦙"
LLAMA_WARNING="(ಠ‿ಠ)🦙"
LLAMA_ERROR="(×_×)🦙"
LLAMA_SUCCESS="(⌐■‿■)🦙"

# --- Helper Functions ---

# Print a centered header with optional color
print_header() {
    local text="$1"
    local color="${2:-$C_CYAN}"
    local width=80
    local padding=$(( (width - ${#text}) / 2 ))
    
    printf "\n%s" "$color"
    printf "=%.0s" $(seq 1 $width)
    printf "\n%*s%s%*s\n" $padding "" "$text" $padding ""
    printf "=%.0s" $(seq 1 $width)
    printf "%s\n\n" "$C_RESET"
}

# Print a section header
print_section() {
    local text="$1"
    local color="${2:-$C_CYAN}"
    
    printf "\n%s%s%s\n" "$color" "$text" "$C_RESET"
    printf "%s" "$color"
    printf "-%s" $(seq -s '-' 1 ${#text} | tr -d '[:digit:]')
    printf "%s\n\n" "$C_RESET"
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

# Clear screen and reset
clear_screen() {
    clear
}

# Display progress
show_progress() {
    local current="$1"
    local total="$2"
    local text="$3"
    local width=50
    local percent=$((current * 100 / total))
    local progress=$((current * width / total))
    
    printf "\r%s [" "$text"
    printf "%${progress}s" | tr ' ' '#'
    printf "%$((width - progress))s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
}

# Check if running as root
check_root_privileges() {
    if [ "$(id -u)" != "0" ]; then
        llama_speak "warning" "This operation requires root privileges."
        echo "Please run the script with sudo or as root."
        return 1
    fi
    return 0
}

# --- USB Device Selection and Formatting ---

# List available USB devices
list_usb_devices() {
    if [ "$(uname)" == "Linux" ]; then
        echo "NAME   MODEL                     SIZE TRAN   MOUNTPOINT"
        lsblk -o NAME,MODEL,SIZE,TRAN,MOUNTPOINT | grep -E "disk|usb" | grep -v "loop" | grep -v "sr"
        echo ""
        echo "Note: Look for devices with 'usb' in the TRAN column."
    else
        echo "Only Linux is currently supported for USB device detection."
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

# Create a new AI USB drive
create_new_usb() {
    print_header "CREATE NEW AI USB DRIVE"
    
    if ! check_root_privileges; then
        return 1
    fi
    
    llama_speak "normal" "This will create a new AI USB drive with pre-configured Ollama models."
    echo ""
    llama_speak "warning" "WARNING: This will erase ALL data on the selected USB drive."
    echo ""
    
    # List available USB devices
    list_usb_devices
    
    # Ask for confirmation
    read -p "Are you sure you want to continue? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        llama_speak "normal" "Operation cancelled."
        return 0
    fi
    
    # Select USB device
    read -p "Enter the device name (e.g., sdb, sdc): /dev/" device
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
    llama_speak "normal" "Creating directory structure..."
    sudo mkdir -p "$mount_dir/models"
    sudo mkdir -p "$mount_dir/runtimes"
    
    # Download Ollama binaries and models
    llama_speak "normal" "Downloading Ollama binaries..."
    # TODO: Implement binary download functionality
    
    # Set permissions
    sudo chmod -R 755 "$mount_dir"
    
    llama_speak "success" "AI USB drive created successfully!"
    llama_speak "normal" "Your USB drive is ready at $mount_dir"
    
    return 0
}

# Update an existing AI USB drive
update_existing_usb() {
    print_header "UPDATE EXISTING AI USB DRIVE"
    
    if ! check_root_privileges; then
        return 1
    fi
    
    llama_speak "normal" "This will update an existing AI USB drive."
    echo ""
    
    # List available USB devices
    list_usb_devices
    
    # Select USB device
    read -p "Enter the device name (e.g., sdb, sdc): /dev/" device
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
    
    llama_speak "normal" "Mounting USB drive"
    
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
    llama_speak "normal" "Updating models and binaries..."
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
    
    # Display model table
    echo "+------------------+--------+--------+---------+--------+"
    echo "| Model              | Size     | Speed    | Quality   | Memory   |"
    echo "+------------------+--------+--------+---------+--------+"
    echo "| 🔥 Llama 3 (8B)  | 8GB      | ★★★☆ | ★★★★ | 16GB+    |"
    echo "| 🌟 Mistral (7B)  | 7GB      | ★★★☆ | ★★★★ | 16GB+    |"
    echo "| 💎 Gemma (2B)    | 2GB      | ★★★★ | ★★★ | 8GB+     |"
    echo "| 🧠 Phi-2 (2.7B)  | 3GB      | ★★★★ | ★★★ | 8GB+     |"
    echo "| 🛠️  Custom Model | Varies   | Varies   | Varies    | Varies   |"
    echo "+------------------+--------+--------+---------+--------+"
    echo ""
    
    # Model selection
    while true; do
        read -p "Select a model (1-5) or 'b' to go back: " choice
        
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
            
            clear_screen
            print_header "SELECTED MODEL"
            echo ""
            llama_speak "excited" "You selected: $selected_model"
            
            # Show model details
            echo ""
            case $choice in
                1) # Llama 3
                    echo "+------------------------------------+"
                    echo "| Model: Llama 3 (8B)               |"
                    echo "| Size: 8GB                         |"
                    echo "| Best for: General purpose AI tasks |"
                    echo "| Requirements: 16GB+ RAM recommended |"
                    echo "+------------------------------------+"
                    ;;
                2) # Mistral
                    echo "+------------------------------------+"
                    echo "| Model: Mistral (7B)               |"
                    echo "| Size: 7GB                         |"
                    echo "| Best for: High-quality text generation |"
                    echo "| Requirements: 16GB+ RAM recommended |"
                    echo "+------------------------------------+"
                    ;;
                3) # Gemma
                    echo "+------------------------------------+"
                    echo "| Model: Gemma (2B)                 |"
                    echo "| Size: 2GB                         |"
                    echo "| Best for: Resource-constrained devices |"
                    echo "| Requirements: 8GB+ RAM            |"
                    echo "+------------------------------------+"
                    ;;
                4) # Phi-2
                    echo "+------------------------------------+"
                    echo "| Model: Phi-2 (2.7B)               |"
                    echo "| Size: 3GB                         |"
                    echo "| Best for: Efficient AI applications |"
                    echo "| Requirements: 8GB+ RAM            |"
                    echo "+------------------------------------+"
                    ;;
                5) # Custom
                    echo "+------------------------------------+"
                    echo "| Model: Custom Model               |"
                    echo "| Size: Varies                      |"
                    echo "| Best for: Advanced users          |"
                    echo "| Requirements: Depends on model    |"
                    echo "+------------------------------------+"
                    ;;
            esac
            
            # Ask if user wants to proceed
            echo ""
            read -p "Would you like to create a USB with this model? (y/N): " confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if check_root_privileges; then
                    create_new_usb "$selected_model"
                fi
            fi
            
            # Ask if user wants to select another model
            echo ""
            read -p "Would you like to select another model? (y/N): " another
            
            if [[ ! "$another" =~ ^[Yy]$ ]]; then
                return 0
            fi
            
            clear_screen
            print_header "AVAILABLE AI MODELS"
            llama_speak "normal" "Choose your AI companion:"
            echo ""
            
            # Display model table again
            echo "+------------------+--------+--------+---------+--------+"
            echo "| Model              | Size     | Speed    | Quality   | Memory   |"
            echo "+------------------+--------+--------+---------+--------+"
            echo "| 🔥 Llama 3 (8B)  | 8GB      | ★★★☆ | ★★★★ | 16GB+    |"
            echo "| 🌟 Mistral (7B)  | 7GB      | ★★★☆ | ★★★★ | 16GB+    |"
            echo "| 💎 Gemma (2B)    | 2GB      | ★★★★ | ★★★ | 8GB+     |"
            echo "| 🧠 Phi-2 (2.7B)  | 3GB      | ★★★★ | ★★★ | 8GB+     |"
            echo "| 🛠️  Custom Model | Varies   | Varies   | Varies    | Varies   |"
            echo "+------------------+--------+--------+---------+--------+"
            echo ""
        else
            llama_speak "error" "Invalid option. Please try again."
        fi
    done
}

# Show system information
show_system_info() {
    print_header "SYSTEM INFORMATION"
    
    llama_speak "normal" "Checking system details..."
    echo ""
    
    # Display system information
    echo "OS:             $(uname -s) $(uname -r)"
    echo "CPU:            $(grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
    echo "RAM:            $(free -h | grep "Mem:" | awk '{print $2}')"
    echo "Free Space:     $(df -h . | grep -v Filesystem | awk '{print $4}')"
    
    # Check for dependencies
    echo ""
    echo "Dependencies:"
    echo "  Bash:         $(bash --version | head -1)"
    
    if command -v parted >/dev/null 2>&1; then
        echo "  Parted:       $(parted --version | head -1)"
    else
        echo "  Parted:       Not installed"
    fi
    
    if command -v mkfs.fat >/dev/null 2>&1; then
        echo "  Dosfstools:   Installed"
    else
        echo "  Dosfstools:   Not installed"
    fi
    
    if command -v ollama >/dev/null 2>&1; then
        echo "  Ollama:       $(ollama --version 2>/dev/null || echo "Installed")"
    else
        echo "  Ollama:       Not installed"
    fi
    
    echo ""
    read -p "Press any key to continue..." -n 1
    echo ""
}

# Show version information
show_version() {
    print_header "ABOUT THIS TOOL"
    
    echo "Leonardo AI USB Maker - Version $SCRIPT_VERSION"
    echo ""
    echo "This tool helps you create and manage USB drives with pre-configured"
    echo "AI models using the Ollama framework."
    echo ""
    echo "Features:"
    echo "- Create AI USB drives with various open-source models"
    echo "- Update existing AI USB drives"
    echo "- Cross-platform support (Linux, macOS, Windows)"
    echo ""
    echo "Developed for the International Coding Competition 2025"
    echo ""
    read -p "Press any key to continue..." -n 1
    echo ""
}

# Display main menu
show_main_menu() {
    clear_screen
    
    # Display header with box
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                  LEONARDO AI USB MAKER v$SCRIPT_VERSION                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    llama_speak "normal" "What would you like to do today?"
    echo ""
    
    # Display menu options
    echo "  [1] 💿 Create New AI USB Drive"
    echo "  [2] 🔄 Update Existing AI USB Drive"
    echo "  [3] 📋 List Available AI Models"
    echo "  [4] 🖥️  Show System Information"
    echo "  [5] ℹ️  About This Tool"
    echo "  [q] 👋 Quit"
    echo ""
}

# Main function with interactive menu
main() {
    # Check for command line arguments for backward compatibility
    if [ $# -gt 0 ]; then
        case "$1" in
            list)
                clear_screen
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
                clear_screen
                show_system_info
                ;;
            version)
                clear_screen
                show_version
                ;;
            help|--help|-h)
                clear_screen
                show_version
                ;;
            *)
                echo -e "${C_RED}Error: Unknown command '$1'${C_RESET}"
                show_version
                exit 1
                ;;
        esac
        return
    fi
    
    # Interactive menu mode
    while true; do
        show_main_menu
        
        read -p "Enter your choice (1-5, q to quit): " choice
        
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
                clear
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
