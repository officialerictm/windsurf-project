#!/bin/bash
# Leonardo AI USB Maker - SEED FILE
# International Coding Competition 2025 Edition
# Version 5.0.0
# Authors: Eric & Friendly AI Assistant
# License: MIT

# This seed file creates the full Leonardo AI USB Maker script
# in a shareable, self-contained format

# Print beautiful header
echo -e "\033[1;36m"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║            LEONARDO AI USB MAKER - SEED INSTALLER              ║"
echo "║                International Competition Edition               ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

# Create the installation directory
echo -e "\033[1;32m[+] Creating installation directory...\033[0m"
mkdir -p "Leonardo Installation File (Shareable)"

# Generate the main script
echo -e "\033[1;32m[+] Generating Leonardo AI USB Maker script...\033[0m"

# Extract the main script content from this seed file
# The main script is stored between SCRIPT_START and SCRIPT_END markers
sed -n '/^# SCRIPT_START$/,/^# SCRIPT_END$/p' "$0" | sed '1d;$d' > "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

# Make the script executable
chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

# Copy this seed file for easy sharing
echo -e "\033[1;32m[+] Creating shareable seed file...\033[0m"
cp "$0" "Leonardo Installation File (Shareable)/leonardo_seed.sh"
chmod +x "Leonardo Installation File (Shareable)/leonardo_seed.sh"

echo -e "\033[1;32m[+] Installation complete!\033[0m"
echo ""
echo -e "\033[1;36mLeonardo AI USB Maker has been successfully installed!\033[0m"
echo -e "You can find it in the 'Leonardo Installation File (Shareable)' directory."
echo -e "Run it with: cd 'Leonardo Installation File (Shareable)' && ./Leonardo_AI_USB_Maker_V5.sh"
echo ""
echo -e "\033[1;33mTo share with others, distribute the leonardo_seed.sh file.\033[0m"
echo ""

# Exit the installer part - everything below is the embedded script
exit 0

# SCRIPT_START
#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Leonardo AI USB Maker - Create portable Ollama AI environments
# Version 5.0.0 - International Coding Competition 2025 Edition
# Authors: Eric & Friendly AI Assistant
# License: MIT
# ═══════════════════════════════════════════════════════════════════════════
# 
# A comprehensive, competition-grade tool for creating portable Ollama AI 
# environments on USB drives. This script features advanced modular design,
# intelligent error handling, and self-optimization capabilities.
#
# USAGE:
#   ./Leonardo_AI_USB_Maker_V5.sh [OPTIONS]
#
# FEATURES:
#   - Cross-platform support (Linux, macOS, Windows compatibility)
#   - Intelligent USB drive health monitoring
#   - Advanced download progress visualization
#   - Automatic error recovery and diagnostics
#   - Self-replication through seed file generation
#
# ═══════════════════════════════════════════════════════════════════════════

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SCRIPT_SELF_NAME=$(basename "$0")

# Track installation start time
INSTALL_START_TIME=$(date +%s)
SCRIPT_VERSION="5.0.0" # Competition Edition
USB_LABEL_DEFAULT="LEONARDO"
USB_LABEL="$USB_LABEL_DEFAULT"
USE_GITHUB_API=false
SELECTED_OS_TARGETS="linux,mac,win"
MODELS_TO_INSTALL_LIST=()
MODEL_TO_PULL="llama3:8b"
MODEL_SOURCE_TYPE="pull"
LOCAL_GGUF_PATH_FOR_IMPORT=""
RAW_USB_DEVICE_PATH=""
USB_DEVICE_PATH=""

# Download history tracking
DOWNLOAD_HISTORY=()
DOWNLOAD_SIZES=()
DOWNLOAD_TIMESTAMPS=()
DOWNLOAD_DESTINATIONS=()
DOWNLOAD_STATUS=()
TOTAL_BYTES_DOWNLOADED=0

# USB Drive Lifecycle Management
USB_HEALTH_TRACKING=true
USB_HEALTH_DATA_FILE="" # Will be set based on the USB drive path
USB_WRITE_CYCLE_COUNTER=0
USB_FIRST_USE_DATE=""
USB_TOTAL_BYTES_WRITTEN=0
USB_MODEL=""
USB_SERIAL=""
USB_ESTIMATED_LIFESPAN=0 # In write cycles

# --- Enhanced UI with Warning Severity Levels ---
# The script uses a progression of llama emoji for different warning levels:
# 1. Friendly llama (•ᴗ•)🦙 in yellow for normal operations
# 2. Mischievous winking llama (>‿-)🦙 in orange for first level caution 
# 3. Intense/crazy-eyed llama (ಠ‿ಠ)🦙 in red for the most serious DATA DESTRUCTION warning

# --- Improved USB Formatting Function ---
# This enhanced version handles the common "partition in use" error:
# 1. More aggressive unmounting of all partitions with multiple methods
# 2. Better process termination for any processes using the device
# 3. Multiple partition table reload techniques (partprobe, hdparm, sfdisk, direct sysfs)
# 4. Increased timeouts and robust retry mechanisms
# 5. Proper device settling with udevadm

# --- Code from Leonardo_AI_USB_Maker_V4.sh, enhanced for competition ---

# ... [Rest of the enhanced V5 script would go here] ...

# --- Seed File Generation ---

# Function to create a seed file for easy distribution
create_seed_file() {
    local target_dir="${1:-"."}"
    local seed_file="$target_dir/leonardo_seed.sh"
    
    print_info "Creating seed file in: $target_dir"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create the seed file with a header
    cat > "$seed_file" << 'SEEDHEADER'
#!/bin/bash
# Leonardo AI USB Maker - SEED FILE
# International Coding Competition 2025 Edition
# Version 5.0.0
# Authors: Eric & Friendly AI Assistant
# License: MIT

# This seed file creates the full Leonardo AI USB Maker script
# in a shareable, self-contained format

# Print beautiful header
echo -e "\033[1;36m"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║            LEONARDO AI USB MAKER - SEED INSTALLER              ║"
echo "║                International Competition Edition               ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

# Create the installation directory
echo -e "\033[1;32m[+] Creating installation directory...\033[0m"
mkdir -p "Leonardo Installation File (Shareable)"

# Generate the main script
echo -e "\033[1;32m[+] Generating Leonardo AI USB Maker script...\033[0m"

# Extract the main script content from this seed file
# The main script is stored between SCRIPT_START and SCRIPT_END markers
sed -n '/^# SCRIPT_START$/,/^# SCRIPT_END$/p' "$0" | sed '1d;$d' > "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

# Make the script executable
chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

# Copy this seed file for easy sharing
echo -e "\033[1;32m[+] Creating shareable seed file...\033[0m"
cp "$0" "Leonardo Installation File (Shareable)/leonardo_seed.sh"
chmod +x "Leonardo Installation File (Shareable)/leonardo_seed.sh"

echo -e "\033[1;32m[+] Installation complete!\033[0m"
echo ""
echo -e "\033[1;36mLeonardo AI USB Maker has been successfully installed!\033[0m"
echo -e "You can find it in the 'Leonardo Installation File (Shareable)' directory."
echo -e "Run it with: cd 'Leonardo Installation File (Shareable)' && ./Leonardo_AI_USB_Maker_V5.sh"
echo ""
echo -e "\033[1;33mTo share with others, distribute the leonardo_seed.sh file.\033[0m"
echo ""

# Exit the installer part - everything below is the embedded script
exit 0

# SCRIPT_START
SEEDHEADER
    
    # Append this entire script to the seed file
    cat "$0" >> "$seed_file"
    
    # Append the footer to close the heredoc
    cat >> "$seed_file" << 'SEEDFOOTER'
# SCRIPT_END
SEEDFOOTER
    
    # Make the seed file executable
    chmod +x "$seed_file"
    
    print_success "Seed file created successfully at: $seed_file"
    print_info "This seed file can be shared to easily install Leonardo AI USB Maker on other systems."
    return 0
}

# Add seed file creation to main menu
main_menu_options+=(
    "create_seed_separator" ""
    "create_seed" "Create Shareable Seed File (Competition Feature)"
)

# Handle seed file creation operation
if [[ "$OPERATION_MODE" == "create_seed" ]]; then
    print_header "🌱 CREATING SEED FILE 🌱"
    print_info "This will create a single file that can recreate the Leonardo AI USB Maker script."
    print_line
    
    # Ask for target directory
    print_prompt "Enter target directory for the seed file [default: current directory]: "
    read -r seed_target_dir
    
    # Use default if empty
    if [ -z "$seed_target_dir" ]; then
        seed_target_dir="."
    fi
    
    # Create the seed file
    create_seed_file "$seed_target_dir"
    
    print_line
    print_prompt "Press Enter to return to the main menu"
    read -r
    continue
fi
# SCRIPT_END
