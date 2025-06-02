#!/bin/bash

# ======================================================================
# Leonardo AI USB Maker - Master Version with Enhanced UI
# ======================================================================
# Version: 1.2.0
# Features: Modern CLI interface with llama guide, progress tracking,
#           and improved user experience
# ======================================================================

# Source UI components
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/leonardo_ui.sh" ]; then
    source "${SCRIPT_DIR}/leonardo_ui.sh"
else
    echo "Error: Could not load UI components. leonardo_ui.sh is missing."
    exit 1
fi

# Initialize colors and UI components
init_ui() {
    # Reset
    C_RESET='\033[0m'       # Text Reset
    
    # Regular Colors
    C_BLACK='\033[0;30m'    # Black
    C_RED='\033[0;31m'      # Red
    C_GREEN='\033[0;32m'    # Green
    C_YELLOW='\033[0;33m'   # Yellow
    C_BLUE='\033[0;34m'     # Blue
    C_PURPLE='\033[0;35m'  # Purple
    C_CYAN='\033[0;36m'     # Cyan
    C_WHITE='\033[0;37m'    # White
    
    # Bold
    C_BLACK_BOLD='\033[1;30m'   # Black
    C_RED_BOLD='\033[1;31m'     # Red
    C_GREEN_BOLD='\033[1;32m'   # Green
    C_YELLOW_BOLD='\033[1;33m'  # Yellow
    C_BLUE_BOLD='\033[1;34m'    # Blue
    C_PURPLE_BOLD='\033[1;35m'  # Purple
    C_CYAN_BOLD='\033[1;36m'    # Cyan
    C_WHITE_BOLD='\033[1;37m'   # White
}

# Initialize the UI
init_ui

# Check if running as root for non-privileged operations
check_root_privileges() {
    local operation=$1
    
    # List of operations that require root
    local root_operations=("create_new_usb" "update_existing_usb" "format_usb")
    
    # Check if current operation requires root
    for op in "${root_operations[@]}"; do
        if [ "$operation" = "$op" ]; then
            if [ "$(id -u)" -ne 0 ]; then
                echo -e "${C_RED}Error: This operation requires root privileges.${C_RESET}"
                echo -e "Please run this script with sudo.\n"
                press_any_key
                return 1
            fi
            return 0
        fi
    done
    
    # For non-root operations, ensure we're not running as root
    if [ "$(id -u)" -eq 0 ]; then
        show_error "This operation should not be run as root.\n"
        press_any_key
        return 1
    fi
    
    return 0
}

# Show main menu
show_main_menu() {
    while true; do
        show_header
        llama_speak "normal" "What would you like to do today?"
        echo
        
        local menu_items=(
            "💿 Create New AI USB Drive"
            "🔄 Update Existing AI USB Drive"
            "📋 List Available AI Models"
            "🖥️  Show System Information"
            "ℹ️  About This Tool"
            "👋 Quit"
        )
        
        for i in "${!menu_items[@]}"; do
            local num=$((i+1))
            if [ $num -eq ${#menu_items[@]} ]; then
                echo -e "  [${C_YELLOW}q${C_RESET}] ${menu_items[$i]}"
            else
                echo -e "  [${C_YELLOW}${num}${C_RESET}] ${menu_items[$i]}"
            fi
        done
        
        echo -e "\n${C_WHITE_BOLD}Enter your choice (1-${#menu_items[@]}, q to quit): ${C_RESET}"
        read -r choice
        
        case $choice in
            1) 
                if check_root_privileges "create_new_usb"; then
                    create_new_usb
                fi
                ;;
            2)
                if check_root_privileges "update_existing_usb"; then
                    update_existing_usb
                fi
                ;;
            3) 
                clear_screen
                list_models
                press_any_key
                ;;
            4)
                clear_screen
                show_system_info
                press_any_key
                ;;
            5)
                clear_screen
                show_version
                press_any_key
                ;;
            q|Q)
                clear
                llama_speak "success" "Thank you for using Leonardo AI USB Maker!"
                echo -e "\n${C_CYAN}Have a great day! (•ᴗ•)🦙${C_RESET}\n"
                exit 0
                ;;
            *)
                llama_speak "warning" "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Enhanced show_llama_message for backward compatibility
show_llama_message() {
    local message=$1
    local severity=${2:-1}
    
    case $severity in
        1) llama_speak "normal" "$message" ;;
        2) llama_speak "caution" "$message" ;;
        3) llama_speak "error" "$message" ;;
        *) echo -e "\n$message\n" ;;
    esac
}

# Clear screen and show header
clear_screen() {
    clear
    echo -e "${C_CYAN_BOLD}╔══════════════════════════════════════════════════════════════════╗"
    echo -e "║${C_WHITE_BOLD}                  LEONARDO AI USB MAKER v1.0.0${C_CYAN_BOLD}                  ║"
    echo -e "╚══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo
}

# Show llama-themed message based on severity
# 1: Normal (•ᴗ•)🦙
# 2: Warning (>‿-)🦙
# 3: Critical (ಠ‿ಠ)🦙
show_llama_message() {
    local message="$1"
    local severity="${2:-1}"  # Default to normal severity
    
    case $severity in
        1) local llama="(•ᴗ•)🦙" ; local color="$C_GREEN" ;;
        2) local llama="(>‿-)🦙" ; local color="$C_YELLOW" ;;
        3) local llama="(ಠ‿ಠ)🦙" ; local color="$C_RED" ;;
        *) local llama="(•ᴗ•)🦙" ; local color="$C_RESET" ;;
    esac
    
    echo -e "${color}${llama} ${message}${C_RESET}"
}

# Wait for user to press any key
press_any_key() {
    echo -e "\n${C_CYAN}Press any key to continue...${C_RESET}"
    read -n 1 -s -r
}

# Display usage information
show_help() {
    clear_screen
    echo -e "${C_BLUE_BOLD}Leonardo AI USB Maker - Help${C_RESET}\n"
    echo -e "${C_WHITE_BOLD}Description:${C_RESET}"
    echo -e "  Create and manage portable AI environments on USB drives.\n"
    
    echo -e "${C_WHITE_BOLD}Menu Options:${C_RESET}"
    echo -e "  1. Create New AI USB Drive    - Set up a new USB drive with AI models"
    echo -e "  2. Update Existing USB Drive  - Add or update models on an existing drive"
    echo -e "  3. List Available AI Models  - Show all available AI models"
    echo -e "  4. Show System Information   - Display system and USB device information"
    echo -e "  5. About This Tool           - Version and additional information\n"
    
    press_any_key
}

# Show version information with llama style
show_version() {
    clear_screen
    show_header "ABOUT LEONARDO AI USB MAKER"
    
    # Display ASCII art llama
    echo -e "${C_CYAN}"
    echo "    ___    __"
    echo "   /   |  / /___  ____  ____  ____"
    echo "  / /| | / / __ \/ __ \/ __ \/ __/"
    echo " / ___ |/ / /_/ / /_/ / /_/ / /_"
    echo "/_/  |_/\____/ .___/\____/\__/"
    echo "            /_/"
    echo -e "${C_RESET}"
    
    # Version info in a box
    show_info_box "" \
        "${C_WHITE_BOLD}Version:${C_RESET} 1.2.0 (Llama Edition)" \
        "${C_WHITE_BOLD}Author:${C_RESET} Leonardo AI Team" \
        "${C_WHITE_BOLD}License:${C_RESET} MIT" \
        "" \
        "${C_CYAN}Your friendly AI companion for creating" \
        "bootable USB drives with powerful AI models!${C_RESET}"
    
    # System requirements
    echo -e "\n${C_WHITE_BOLD}System Requirements:${C_RESET}"
    echo -e "  • 64-bit Linux system"
    echo -e "  • Minimum 8GB RAM (16GB recommended)"
    echo -e "  • USB drive with at least 32GB capacity"
    echo -e "  • Internet connection for downloading models"
    
    # Fun llama fact
    echo -e "\n${C_CYAN}Did you know?${C_RESET} Llamas are excellent pack animals and can"
    echo -e "carry up to 30% of their body weight! 🦙✨\n"
}

# List available AI models with enhanced UI
list_models() {
    clear_screen
    show_section "AVAILABLE AI MODELS"
    
    llama_speak "normal" "Choose your AI companion:"
    echo
    
    # Display model comparison table
    show_table "" "Model,Size,Speed,Quality,Memory" \
        "🔥 Llama 3 (8B),8GB,★★★☆,★★★★,16GB+" \
        "🌟 Mistral (7B),7GB,★★★☆,★★★★,16GB+" \
        "💎 Gemma (2B),2GB,★★★★,★★★,8GB+" \
        "🧠 Phi-2 (2.7B),3GB,★★★★,★★★,8GB+" \
        "🛠️  Custom Model,Varies,Varies,Varies,Varies"
    
    # Get user selection
    while true; do
        echo -e "\n${C_WHITE_BOLD}Select a model (1-5) or 'b' to go back: ${C_RESET}"
        read -r choice
        
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            return 0
        fi
        
        if [[ "$choice" =~ ^[1-5]$ ]]; then
            local models=("Llama 3 (8B)" "Mistral (7B)" "Gemma (2B)" "Phi-2 (2.7B)" "Custom Model")
            local selected_model="${models[$((choice-1))]}"
            
            # Show selected model with llama
            clear_screen
            show_section "SELECTED MODEL"
            echo
            llama_speak "excited" "You selected: ${C_WHITE_BOLD}${selected_model}${C_RESET}"
            
            # Show model details
            case $choice in
                1) # Llama 3
                    show_info_box "" \
                        "${C_WHITE_BOLD}Model:${C_RESET} Llama 3 (8B)" \
                        "${C_WHITE_BOLD}Size:${C_RESET} 8GB" \
                        "${C_WHITE_BOLD}Best for:${C_RESET} General purpose AI tasks" \
                        "${C_WHITE_BOLD}Requirements:${C_RESET} 16GB+ RAM recommended"
                    ;;
                2) # Mistral
                    show_info_box "" \
                        "${C_WHITE_BOLD}Model:${C_RESET} Mistral (7B)" \
                        "${C_WHITE_BOLD}Size:${C_RESET} 7GB" \
                        "${C_WHITE_BOLD}Best for:${C_RESET} High-quality text generation" \
                        "${C_WHITE_BOLD}Requirements:${C_RESET} 16GB+ RAM recommended"
                    ;;
                3) # Gemma
                    show_info_box "" \
                        "${C_WHITE_BOLD}Model:${C_RESET} Gemma (2B)" \
                        "${C_WHITE_BOLD}Size:${C_RESET} 2GB" \
                        "${C_WHITE_BOLD}Best for:${C_RESET} Resource-constrained devices" \
                        "${C_WHITE_BOLD}Requirements:${C_RESET} 8GB+ RAM"
                    ;;
                4) # Phi-2
                    show_info_box "" \
                        "${C_WHITE_BOLD}Model:${C_RESET} Phi-2 (2.7B)" \
                        "${C_WHITE_BOLD}Size:${C_RESET} 3GB" \
                        "${C_WHITE_BOLD}Best for:${C_RESET} Efficient AI applications" \
                        "${C_WHITE_BOLD}Requirements:${C_RESET} 8GB+ RAM"
                    ;;
                5) # Custom
                    show_info_box "" \
                        "${C_WHITE_BOLD}Model:${C_RESET} Custom Model" \
                        "${C_WHITE_BOLD}Size:${C_RESET} Varies" \
                        "${C_WHITE_BOLD}Best for:${C_RESET} Advanced users" \
                        "${C_WHITE_BOLD}Requirements:${C_RESET} Depends on model"
                    ;;
            esac
            
            # Ask if user wants to proceed
            echo -e "\n${C_WHITE_BOLD}Would you like to create a USB with this model? (y/N): ${C_RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if check_root_privileges "create_new_usb"; then
                    create_new_usb "$selected_model"
                fi
            fi
            return 0
            ;;
        b|B)
            return 0
            ;;
        *)
            llama_speak "warning" "Invalid selection. Please try again."
            sleep 1
            return 1
            ;;
    esac
}

# Show system information with enhanced UI
show_system_info() {
    clear_screen
    show_section "SYSTEM INFORMATION"
    
    llama_speak "normal" "Let me check your system details..."
    echo
    
    # Get system information with better formatting
    local os_info=$(lsb_release -d 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//')
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local cpu_info=$(grep 'model name' /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//')
    local cpu_cores=$(nproc)
    local mem_total=$(free -h | grep 'Mem:' | awk '{print $2}')
    local mem_used=$(free -h | grep 'Mem:' | awk '{print $3}')
    local mem_avail=$(free -h | grep 'Mem:' | awk '{print $7}')
    local disk_total=$(df -h / | awk 'NR==2 {print $2}')
    local disk_used=$(df -h / | awk 'NR==2 {print $3}')
    local disk_avail=$(df -h / | awk 'NR==2 {print $4}')
    local disk_use=$(df -h / | awk 'NR==2 {print $5}')
    local uptime=$(uptime -p | sed 's/^up //')
    local load_avg=$(cat /proc/loadavg | awk '{print $1 " " $2 " " $3}')
    
    # Show system info in a nice box
    show_info_box "System Details" \
        "${C_WHITE_BOLD}OS:${C_RESET} $os_info" \
        "${C_WHITE_BOLD}Kernel:${C_RESET} $kernel" \
        "${C_WHITE_BOLD}Architecture:${C_RESET} $arch" \
        "${C_WHITE_BOLD}Uptime:${C_RESET} $uptime" \
        "${C_WHITE_BOLD}Load Average:${C_RESET} $load_avg" \
        "" \
        "${C_WHITE_BOLD}CPU:${C_RESET} $cpu_info" \
        "${C_WHITE_BOLD}CPU Cores:${C_RESET} $cpu_cores" \
        "" \
        "${C_WHITE_BOLD}Memory:${C_RESET} $mem_used used / $mem_avail available / $mem_total total" \
        "${C_WHITE_BOLD}Disk Usage:${C_RESET} $disk_used used / $disk_avail available / $disk_total total ($disk_use)"
    
    # Check for required tools with progress
    echo -e "\n${C_WHITE_BOLD}🔍 Checking required tools:${C_RESET}"
    
    local tools=(
        "lsblk:Disk management"
        "mkfs.vfat:Filesystem creation"
        "parted:Partition management"
        "curl:File downloads"
        "wget:Alternative downloader"
    )
    
    local missing_tools=()
    local total_tools=${#tools[@]}
    local installed_count=0
    
    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool description <<< "$tool_info"
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "  ${C_GREEN}✓${C_RESET} ${C_WHITE_BOLD}$tool${C_RESET} - $description"
            ((installed_count++))
        else
            echo -e "  ${C_RED}✗${C_RESET} ${C_WHITE_BOLD}$tool${C_RESET} - $description"
            missing_tools+=("$tool")
        fi
    done
    
    # Show installation progress
    local progress=$((installed_count * 100 / total_tools))
    show_progress_bar $progress "Tool check"
    echo
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        llama_speak "warning" "Some required tools are missing. You may need to install them."
        echo -e "\n${C_YELLOW}To install missing tools, run:${C_RESET}"
        echo -e "  ${C_CYAN}sudo apt-get install ${missing_tools[*]}${C_RESET}\n"
    else
        llama_speak "success" "All required tools are installed!"
    fi
    
    # Show system health status
    echo -e "\n${C_WHITE_BOLD}System Health:${C_RESET}"
    
    # Check disk space
    local disk_use_percent=$(echo $disk_use | tr -d '%')
    if [ $disk_use_percent -gt 90 ]; then
        echo -e "  ${C_RED}⚠  Disk space is critically low!${C_RESET} (${disk_use} used)"
    elif [ $disk_use_percent -gt 75 ]; then
        echo -e "  ${C_YELLOW}⚠  Disk space is getting low.${C_RESET} (${disk_use} used)"
    else
        echo -e "  ${C_GREEN}✓  Disk space is good.${C_RESET} (${disk_use} used)"
    fi
    
    # Check memory usage
    local mem_avail_kb=$(free | grep 'Mem:' | awk '{print $7}')
    local mem_total_kb=$(free | grep 'Mem:' | awk '{print $2}')
    local mem_use_percent=$((100 - (mem_avail_kb * 100 / mem_total_kb)))
    
    if [ $mem_use_percent -gt 90 ]; then
        echo -e "  ${C_RED}⚠  Memory usage is very high!${C_RESET} (${mem_use_percent}% used)"
    elif [ $mem_use_percent -gt 75 ]; then
        echo -e "  ${C_YELLOW}⚠  Memory usage is high.${C_RESET} (${mem_use_percent}% used)"
    else
        echo -e "  ${C_GREEN}✓  Memory usage is normal.${C_RESET} (${mem_use_percent}% used)"
    fi
    
    # Check CPU load
    local load_avg_1m=$(echo $load_avg | awk '{print $1}')
    local cpu_cores=$(nproc)
    local load_percent=$(echo "scale=0; ($load_avg_1m * 100) / $cpu_cores" | bc)
    
    if [ $load_percent -gt 90 ]; then
        echo -e "  ${C_RED}⚠  CPU load is very high!${C_RESET} (${load_avg_1m} avg, ${cpu_cores} cores)"
    elif [ $load_percent -gt 75 ]; then
        echo -e "  ${C_YELLOW}⚠  CPU load is high.${C_RESET} (${load_avg_1m} avg, ${cpu_cores} cores)"
    else
        echo -e "  ${C_GREEN}✓  CPU load is normal.${C_RESET} (${load_avg_1m} avg, ${cpu_cores} cores)"
    fi
    
    press_any_key
}

# Format USB drive with retry logic
format_usb() {
    local device="$1"
    local label="LEONARDO_AI"
    local retries=3
    local count=0
    
    show_llama_message "Preparing to format ${device}..." 2
    
    while [ $count -lt $retries ]; do
        # Unmount any mounted partitions
        for partition in "${device}"*; do
            if mount | grep -q "$partition"; then
                show_llama_message "Unmounting $partition..." 1
                sudo umount -l "$partition" 2>/dev/null || true
            fi
        done
        
        # Kill processes using the device
        sudo lsof -t "${device}"* 2>/dev/null | xargs -r sudo kill -9 2>/dev/null || true
        
        # Sync and sleep to ensure device is ready
        sync
        sleep 2
        
        # Create new partition table and single partition
        show_llama_message "Creating new partition table on $device..." 1
        sudo parted -s "$device" mklabel gpt mkpart primary fat32 0% 100% >/dev/null 2>&1
        
        # Format as FAT32 with label
        local part="${device}1"
        show_llama_message "Formatting $part as FAT32..." 1
        
        # Wait for partition to be available
        sudo udevadm settle
        sleep 2
        
        # Try multiple formatting methods
        if command -v mkfs.fat &>/dev/null; then
            sudo mkfs.fat -F 32 -n "$label" "$part" >/dev/null 2>&1
        else
            sudo mkfs.vfat -F 32 -n "$label" "$part" >/dev/null 2>&1
        fi
        
        # Verify the format was successful
        if [ $? -eq 0 ]; then
            show_llama_message "Successfully formatted $device" 1
            return 0
        fi
        
        count=$((count + 1))
        show_llama_message "Format attempt $count failed, retrying..." 2
        sleep 3
    done
    
    show_llama_message "Failed to format $device after $retries attempts" 3
    return 1
}

# Download AI model
download_model() {
    local model="$1"
    local target_dir="$2"
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    show_llama_message "Downloading $model model..." 1
    
    # Simulate download with progress
    for i in {1..10}; do
        printf "\rDownloading... %d%%" $((i * 10))
        sleep 0.2
    done
    printf "\rDownload complete!   \n"
    
    # Create a dummy model file for demonstration
    echo "# $model AI Model" > "${target_dir}/${model}.bin"
    echo "# This is a placeholder for the actual $model model." >> "${target_dir}/${model}.bin"
    echo "# In a real implementation, this would contain the actual model weights." >> "${target_dir}/${model}.bin"
    
    # Create a README file
    cat > "${target_dir}/README.txt" <<EOF
Leonardo AI USB Drive
====================

This USB drive contains the $model AI model.

To use this model, you'll need compatible software that can load and run it.

Model: $model
Created: $(date)
EOF
    
    return 0
}

# Detect USB devices
detect_usb_devices() {
    echo -e "\n${C_BLUE}${C_BOLD}Detecting USB devices...${C_RESET}\n"
    
    # Use lsblk to list block devices
    if ! command -v lsblk &> /dev/null; then
        echo -e "${C_RED}Error: lsblk command not found. Please install util-linux.${C_RESET}"
        return 1
    fi
    
    # List USB devices with human-readable sizes
    lsblk -d -o NAME,MODEL,SIZE,TRAN,MOUNTPOINT | grep -v '^loop' | grep -v '^sr0'
    
    echo -e "\n${C_YELLOW}Note:${C_RESET} Look for devices with 'usb' in the TRAN column.\n"
}

# Create README file with usage instructions
create_readme() {
    local mount_point="$1"
    cat > "$mount_point/README.txt" <<EOF
Leonardo AI USB Drive
====================

This USB drive contains AI models and tools for offline AI processing.

Contents:
- /models: Contains the AI model files
- /config: Configuration files
- /logs: Log files for debugging

To use this drive:
1. Insert the USB drive into your computer
2. Run the appropriate launcher script for your operating system
3. Follow the on-screen instructions

For more information, visit: https://example.com/leonardo-ai

Version: $SCRIPT_VERSION
Created on: $(date)
EOF
}

# Create launcher scripts for different operating systems
create_launcher_scripts() {
    local mount_point="$1"
    
    # Linux launcher
    cat > "$mount_point/start_linux.sh" <<'EOF'
#!/bin/bash
# Linux launcher for Leonardo AI USB

echo "Starting Leonardo AI (Linux)..."
# Add your Linux-specific launch commands here
python3 /path/to/leonardo_ai.py "$@"
EOF

    # Windows launcher
    cat > "$mount_point/start_windows.bat" <<'EOF'
@echo off
:: Windows launcher for Leonardo AI USB

echo Starting Leonardo AI (Windows)...
:: Add your Windows-specific launch commands here
python leonardo_ai.py %*
pause
EOF

    # macOS launcher
    cat > "$mount_point/start_mac.sh" <<'EOF'
#!/bin/bash
# macOS launcher for Leonardo AI USB

echo "Starting Leonardo AI (macOS)..."
# Add your macOS-specific launch commands here
python3 /path/to/leonardo_ai.py "$@"
EOF

    # Make scripts executable
    chmod +x "$mount_point/start_linux.sh" "$mount_point/start_mac.sh"
}

# Update an existing AI USB drive
update_existing_usb() {
    clear_screen
    show_llama_message "Update Existing AI USB Drive" 1
    
    # Detect USB devices
    local device=$(detect_usb_devices)
    if [ -z "$device" ]; then
        show_llama_message "No USB devices found. Please insert a USB drive and try again." 2
        press_any_key
        return 1
    fi
    
    # Create mount point
    local mount_point="/mnt/leonardo_update"
    mkdir -p "$mount_point"
    
    # Try to mount the device
    if ! mount "${device}1" "$mount_point" 2>/dev/null; then
        show_llama_message "Failed to mount $device. It may not be formatted correctly." 3
        rmdir "$mount_point" 2>/dev/null
        press_any_key
        return 1
    fi
    
    # Check if this is a Leonardo AI USB
    if [ ! -f "$mount_point/LEONARDO_AI_VERSION" ]; then
        show_llama_message "This doesn't appear to be a Leonardo AI USB drive." 2
        umount "$mount_point" 2>/dev/null
        rmdir "$mount_point" 2>/dev/null
        press_any_key
        return 1
    fi
    
    # Show current version
    local current_version=$(cat "$mount_point/LEONARDO_AI_VERSION" 2>/dev/null || echo "Unknown")
    echo -e "${C_WHITE_BOLD}Current Version:${C_RESET} $current_version"
    echo -e "${C_WHITE_BOLD}New Version:${C_RESET} $SCRIPT_VERSION\n"
    
    # Show update options
    echo -e "${C_WHITE_BOLD}Available Updates:${C_RESET}"
    echo -e "1. Update AI models"
    echo -e "2. Update system files"
    echo -e "3. Check for updates"
    echo -e "4. Back to main menu\n"
    
    read -p "${C_YELLOW_BOLD}Select an option (1-4): ${C_RESET}" choice
    
    case $choice in
        1)
            # Update AI models
            list_models
            read -p "${C_YELLOW_BOLD}Select a model to add (1-5) or 'b' to go back: ${C_RESET}" model_choice
            
            case $model_choice in
                [1-5])
                    local models=("llama3-8b" "mistral-7b" "gemma-2b" "phi-2.7b" "custom")
                    local selected_model=${models[$((model_choice-1))]}
                    download_model "$selected_model" "$mount_point/models"
                    ;;
                b|B)
                    ;;
                *)
                    show_llama_message "Invalid selection" 2
                    ;;
            esac
            ;;
        2)
            # Update system files
            show_llama_message "Updating system files..." 1
            # Create/update launcher scripts
            create_launcher_scripts "$mount_point"
            # Update version file
            echo "$SCRIPT_VERSION" > "$mount_point/LEONARDO_AI_VERSION"
            show_llama_message "System files updated successfully!" 1
            ;;
        3)
            # Check for updates
            show_llama_message "Checking for updates..." 1
            if [ "$current_version" = "$SCRIPT_VERSION" ]; then
                echo -e "${C_GREEN}You have the latest version.${C_RESET}\n"
            else
                echo -e "${C_YELLOW}An update is available!${C_RESET}"
                echo -e "Current version: $current_version"
                echo -e "New version: $SCRIPT_VERSION\n"
                read -p "${C_YELLOW_BOLD}Would you like to update? (y/N): ${C_RESET}" update_confirm
                if [[ $update_confirm =~ ^[Yy]$ ]]; then
                    # Update system files
                    create_launcher_scripts "$mount_point"
                    echo "$SCRIPT_VERSION" > "$mount_point/LEONARDO_AI_VERSION"
                    show_llama_message "Update completed successfully!" 1
                fi
            fi
            ;;
        4|b|B)
            # Go back
            ;;
        *)
            show_llama_message "Invalid option" 2
            ;;
    esac
    
    # Cleanup
    sync
    umount "$mount_point" 2>/dev/null
    rmdir "$mount_point" 2>/dev/null
    
    press_any_key
}

# Create a new AI USB drive
create_new_usb() {
    clear_screen
    show_llama_message "Create New AI USB Drive" 1
    
    # Detect USB devices
    local device=$(detect_usb_devices)
    if [ -z "$device" ]; then
        show_llama_message "No USB devices found. Please insert a USB drive and try again." 2
        press_any_key
        return 1
    fi
    
    # List available models
    list_models
    read -p "${C_YELLOW}Select a model (1-5) or 'b' to go back: ${C_RESET}" model_choice
    
    # Handle model selection
    local model=""
    case $model_choice in
        1) model="llama3-8b" ;;
        2) model="mistral-7b" ;;
        3) model="gemma-2b" ;;
        4) model="phi-2.7b" ;;
        5) model="custom" ;;
        b|B) return 0 ;;
        *)
            show_llama_message "Invalid selection. Please try again." 2
            press_any_key
            return 1
            ;;
    esac
    
    if [[ -z "$model" ]]; then
        echo -e "${C_RED}No model specified. Aborting.${C_RESET}"
        return 1
    fi
    
    # Confirm before proceeding with formatting
    echo -e "\n${C_RED}${C_BOLD}WARNING: This will erase ALL data on $device${C_RESET}"
    read -p "Are you sure you want to continue? (y/N) " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        show_llama_message "Operation cancelled by user." 1
        return 1
    fi
    
    # Create mount point
    local mount_point="/mnt/leonardo_ai"
    mkdir -p "$mount_point"
    
    # Format the USB drive
    if ! format_usb "$device"; then
        show_llama_message "Failed to format USB drive." 3
        rmdir "$mount_point" 2>/dev/null
        press_any_key
        return 1
    fi
    
    # Create filesystem and mount
    if ! mkfs.vfat -F 32 "${device}1" -n LEONARDO_AI; then
        show_llama_message "Failed to create filesystem on USB drive." 3
        rmdir "$mount_point" 2>/dev/null
        press_any_key
        return 1
    fi
    
    mount "${device}1" "$mount_point"
    if [ $? -ne 0 ]; then
        show_llama_message "Failed to mount USB drive." 3
        rmdir "$mount_point" 2>/dev/null
        press_any_key
        return 1
    fi
    
    # Create directory structure
    mkdir -p "$mount_point/models" "$mount_point/config" "$mount_point/logs"
    
    # Save version information
    echo "$SCRIPT_VERSION" > "$mount_point/LEONARDO_AI_VERSION"
    
    # Download selected model
    show_llama_message "Downloading $model model..." 1
    if ! download_model "$model" "$mount_point/models"; then
        show_llama_message "Failed to download model." 3
        umount "$mount_point" 2>/dev/null
        rmdir "$mount_point" 2>/dev/null
        press_any_key
        return 1
    fi
    
    # Create README and launcher scripts
    create_readme "$mount_point"
    create_launcher_scripts "$mount_point"
    
    # Set permissions
    chmod -R 755 "$mount_point"
    
    # Sync and unmount
    sync
    umount "$mount_point"
    rmdir "$mount_point"
    
    show_llama_message "AI USB drive created successfully!" 1
    echo -e "${C_GREEN}Device: $device"
    echo -e "Model: $model"
    echo -e "You can now safely remove the USB drive.${C_RESET}\n"
    
    press_any_key
}

# Main function with interactive menu
main() {
    # Check for command line arguments for backward compatibility
    if [ $# -gt 0 ]; then
        case "$1" in
            list)
                clear_screen
                list_models
                press_any_key
                ;;
            create)
                shift
                check_root_privileges "create_new_usb" && create_new_usb
                ;;
            update)
                shift
                check_root_privileges "update_existing_usb" && update_existing_usb
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
                show_help
                ;;
            *)
                echo -e "${C_RED}Error: Unknown command '$1'${C_RESET}"
                show_help
                exit 1
                ;;
        esac
        return
    fi
    
    # Interactive menu mode
    while true; do
        show_main_menu
        
        # Show current USB status if available
        if [ -n "$USB_DEVICE" ]; then
            echo -e "${C_GREEN}Current USB: $USB_DEVICE${C_RESET}\n"
        fi
        
        read -p "${C_WHITE_BOLD}Enter your choice (1-5, q to quit): ${C_RESET}" choice
        
        case $choice in
            1) 
                if check_root_privileges "create_new_usb"; then
                    create_new_usb
                fi
                ;;
            2)
                if check_root_privileges "update_existing_usb"; then
                    update_existing_usb
                fi
                ;;
            3) list_models ;;
            4) show_system_info ;;
            5) show_version ;;
            q|Q)
                clear
                show_llama_message "Thank you for using Leonardo AI USB Maker!" 1
                echo -e "\n${C_CYAN}Have a great day! (•ᴗ•)🦙${C_RESET}\n"
                exit 0
                ;;
            *)
                show_llama_message "Invalid option. Please try again." 2
                sleep 1
                ;;
        esac
    done
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    # Run the main function with all arguments
    main "$@"
fi
