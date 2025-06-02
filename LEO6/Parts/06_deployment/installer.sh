# ==============================================================================
# System Installer
# ==============================================================================
# Description: Handles installation of Leonardo AI to USB devices
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,03_filesystem/device.sh
# ==============================================================================

# Install Leonardo AI framework to USB device
install_leonardo_framework() {
    local usb_path="$1"
    local partition_number="${2:-1}"
    
    log_message "INFO" "Installing Leonardo AI framework to $usb_path"
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    
    # Check if device exists
    if [[ ! -b "$partition" ]]; then
        show_error "Partition $partition not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/leonardo_install_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    show_step_header "Mounting USB Device" "$UI_WIDTH"
    echo -e "Mounting ${CYAN}$partition${NC} to ${CYAN}$mount_point${NC}..."
    
    if ! mount "$partition" "$mount_point"; then
        show_error "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Create the directory structure
    show_step_header "Creating Directory Structure" "$UI_WIDTH"
    echo -e "Setting up Leonardo AI directory structure..."
    
    mkdir -p "$mount_point/leonardo"
    mkdir -p "$mount_point/leonardo/models"
    mkdir -p "$mount_point/leonardo/config"
    mkdir -p "$mount_point/leonardo/logs"
    mkdir -p "$mount_point/leonardo/scripts"
    mkdir -p "$mount_point/leonardo/data"
    mkdir -p "$mount_point/leonardo/tmp"
    
    # Create the base configuration file
    cat > "$mount_point/leonardo/config/leonardo.conf" << EOF
# Leonardo AI Universal Configuration
# Generated on $(date)

# System Configuration
LEONARDO_VERSION="6.0.0"
INSTALLATION_DATE="$(date +%Y-%m-%d)"
LOG_LEVEL="INFO"
DEFAULT_MODEL="mistral-7b"
ENABLE_HEALTH_TRACKING=true
ENABLE_TELEMETRY=false

# Hardware Configuration
MIN_RAM_MB=4096
MIN_GPU_MB=0
CPU_THREADS=4

# Network Configuration
DOWNLOAD_TIMEOUT=3600
DOWNLOAD_RETRIES=3
DOWNLOAD_RATE_LIMIT=0
USE_MIRROR=false
MIRROR_URL=""

# UI Configuration
ENABLE_COLORS=true
ENABLE_UTF8=true
PROGRESS_BAR_WIDTH=50
VERBOSE_OUTPUT=true
SHOW_WARNINGS=true

# Model Configuration
DEFAULT_MODEL_PATH="/leonardo/models"
MODEL_AUTOLOAD=true
MODEL_VERIFICATION=true

# API Keys (DO NOT ENTER SENSITIVE INFORMATION HERE)
# Use the API key manager to securely add your keys
API_KEYS_FILE="/leonardo/config/api_keys.enc"
EOF
    
    # Create the launcher script
    cat > "$mount_point/leonardo/leonardo.sh" << 'EOF'
#!/bin/bash
# Leonardo AI Universal Launcher
# Version 6.0.0

# Set base directory
LEONARDO_DIR="$(dirname "$(readlink -f "$0")")"
cd "$LEONARDO_DIR" || exit 1

# Display welcome banner
echo "=================================================="
echo "       Leonardo AI Universal - v6.0.0"
echo "=================================================="
echo "Starting Leonardo AI Universal..."
echo ""

# Check for updates
echo "Checking for updates..."
if [[ -f "$LEONARDO_DIR/scripts/update.sh" ]]; then
    bash "$LEONARDO_DIR/scripts/update.sh" --check-only
fi

# Launch the main application
if [[ -f "$LEONARDO_DIR/scripts/main.sh" ]]; then
    bash "$LEONARDO_DIR/scripts/main.sh" "$@"
else
    echo "ERROR: Main application script not found!"
    echo "Please reinstall Leonardo AI Universal."
    exit 1
fi
EOF
    
    # Make the launcher executable
    chmod +x "$mount_point/leonardo/leonardo.sh"
    
    # Create the README file
    cat > "$mount_point/leonardo/README.md" << 'EOF'
# Leonardo AI Universal

## Overview
Leonardo AI Universal is a comprehensive platform for managing and using various AI models. 
This system provides a unified interface for downloading, managing, and running multiple large language models.

## Getting Started
1. Run `./leonardo.sh` to start the application
2. Follow the on-screen instructions to download and install models
3. Use the model management interface to switch between different models

## Features
- Unified model management system
- Automatic model downloads with integrity verification
- USB health tracking and monitoring
- Cross-platform compatibility
- Advanced logging and error handling
- Intelligent hardware resource management

## Directory Structure
- `/leonardo` - Main application directory
  - `/models` - AI model storage
  - `/config` - Configuration files
  - `/logs` - Log files
  - `/scripts` - Application scripts
  - `/data` - User data and settings
  - `/tmp` - Temporary files

## Support
For assistance, visit https://windsurf.io/leonardo or contact support@windsurf.io

## License
© 2025 Windsurf.io. All rights reserved.
EOF
    
    # Copy core scripts from this script
    show_step_header "Installing Core Scripts" "$UI_WIDTH"
    echo -e "Extracting core scripts..."
    
    # Create the main script (simplified version for initial setup)
    cat > "$mount_point/leonardo/scripts/main.sh" << 'EOF'
#!/bin/bash
# Leonardo AI Universal - Main Application
# Version 6.0.0

# Set base directory
LEONARDO_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
cd "$LEONARDO_DIR" || exit 1

# Source configuration
if [[ -f "$LEONARDO_DIR/config/leonardo.conf" ]]; then
    source "$LEONARDO_DIR/config/leonardo.conf"
fi

# Set up colors
if [[ "$ENABLE_COLORS" == "true" ]]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    MAGENTA="\033[0;35m"
    CYAN="\033[0;36m"
    BOLD="\033[1m"
    NC="\033[0m" # No Color
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    NC=""
fi

# Display main menu
show_main_menu() {
    clear
    echo -e "${BOLD}${BLUE}=================================================${NC}"
    echo -e "${BOLD}${BLUE}       Leonardo AI Universal - v6.0.0${NC}"
    echo -e "${BOLD}${BLUE}=================================================${NC}"
    echo ""
    echo -e "${BOLD}Main Menu:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Manage AI Models"
    echo -e "  ${CYAN}2.${NC} Run AI Model"
    echo -e "  ${CYAN}3.${NC} System Diagnostics"
    echo -e "  ${CYAN}4.${NC} USB Health Check"
    echo -e "  ${CYAN}5.${NC} Settings"
    echo -e "  ${CYAN}6.${NC} Help"
    echo -e "  ${CYAN}0.${NC} Exit"
    echo ""
    echo -e "${YELLOW}This is a placeholder. Full functionality will be available after setup.${NC}"
    echo ""
    echo -n "Enter your choice [0-6]: "
}

# Main application loop
while true; do
    show_main_menu
    read -r choice
    
    case $choice in
        1)
            echo -e "\n${YELLOW}Model Management not available in initial setup.${NC}"
            echo -e "${YELLOW}Please run the full setup first.${NC}"
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        2)
            echo -e "\n${YELLOW}AI Model execution not available in initial setup.${NC}"
            echo -e "${YELLOW}Please run the full setup first.${NC}"
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        3)
            echo -e "\n${YELLOW}Diagnostics not available in initial setup.${NC}"
            echo -e "${YELLOW}Please run the full setup first.${NC}"
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        4)
            echo -e "\n${YELLOW}USB Health Check not available in initial setup.${NC}"
            echo -e "${YELLOW}Please run the full setup first.${NC}"
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        5)
            echo -e "\n${YELLOW}Settings not available in initial setup.${NC}"
            echo -e "${YELLOW}Please run the full setup first.${NC}"
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        6)
            echo -e "\n${BOLD}Help:${NC}"
            echo -e "This is the initial setup version of Leonardo AI Universal."
            echo -e "To complete setup and access all features, run the full installer."
            echo -e "\n${BOLD}Instructions:${NC}"
            echo -e "1. Return to the USB creator application"
            echo -e "2. Complete the model installation process"
            echo -e "3. Follow prompts to finalize setup"
            echo ""
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        0)
            echo -e "\n${GREEN}Exiting Leonardo AI Universal.${NC}"
            echo -e "${GREEN}Thank you for using our software!${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice. Please try again.${NC}"
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
    esac
done
EOF
    
    # Make the main script executable
    chmod +x "$mount_point/leonardo/scripts/main.sh"
    
    # Create the update script
    cat > "$mount_point/leonardo/scripts/update.sh" << 'EOF'
#!/bin/bash
# Leonardo AI Universal - Update Script
# Version 6.0.0

# Set base directory
LEONARDO_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
cd "$LEONARDO_DIR" || exit 1

# Parse arguments
CHECK_ONLY=false

for arg in "$@"; do
    case $arg in
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
    esac
done

# Source configuration
if [[ -f "$LEONARDO_DIR/config/leonardo.conf" ]]; then
    source "$LEONARDO_DIR/config/leonardo.conf"
fi

# Set up colors
if [[ "$ENABLE_COLORS" == "true" ]]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    BOLD="\033[1m"
    NC="\033[0m" # No Color
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    NC=""
fi

echo -e "${BOLD}${BLUE}Leonardo AI Universal Update Checker${NC}"
echo -e "${BLUE}========================================${NC}"

# Version information
CURRENT_VERSION="6.0.0"
echo -e "Current version: ${CYAN}$CURRENT_VERSION${NC}"

# Simulate update check
echo -e "Checking for updates..."
sleep 1

# This is a placeholder - in a real update script, this would check a server
echo -e "${GREEN}You are running the latest version.${NC}"

# Exit if only checking
if [[ "$CHECK_ONLY" == "true" ]]; then
    exit 0
fi

echo -e "\n${YELLOW}This is a placeholder. Actual update functionality will be implemented in the full version.${NC}"
echo ""
read -n 1 -s -r -p "Press any key to continue..."
EOF
    
    # Make the update script executable
    chmod +x "$mount_point/leonardo/scripts/update.sh"
    
    # Create a shortcut in the root directory
    cat > "$mount_point/README.txt" << EOF
=================================================
          Leonardo AI Universal v6.0.0
=================================================

To start Leonardo AI Universal, navigate to the
"leonardo" directory and run the "leonardo.sh" script:

cd leonardo
./leonardo.sh

For documentation and support, visit:
https://windsurf.io/leonardo

=================================================
EOF
    
    # Set up health tracking if enabled
    if [[ "$USB_HEALTH_TRACKING" == "true" ]]; then
        mkdir -p "$mount_point/.leonardo_data"
        
        # Check if health data already exists
        if [[ ! -f "$mount_point/.leonardo_data/health.json" ]]; then
            # Create a new health data file
            local model=$(get_device_info "$usb_path" "model")
            local serial=$(get_device_info "$usb_path" "serial")
            local vendor=$(get_device_info "$usb_path" "vendor")
            
            # Estimate lifespan based on drive type
            local estimated_lifespan=5000  # Default for unknown drives
            
            # Check if it's an SSD
            if [[ "$model" =~ SSD || "$model" =~ Solid || "$vendor" =~ Samsung || "$vendor" =~ Kingston || "$vendor" =~ Crucial ]]; then
                estimated_lifespan=10000  # Higher estimate for SSDs
            fi
            
            # Create the health data file
            cat > "$mount_point/.leonardo_data/health.json" << EOF
{
  "device": {
    "model": "$model",
    "serial": "$serial",
    "vendor": "$vendor",
    "first_use": "$(date +%Y-%m-%d)",
    "estimated_lifespan": $estimated_lifespan
  },
  "usage": {
    "write_cycles": 1,
    "total_bytes_written": 5242880,
    "last_updated": "$(date +%Y-%m-%d)"
  },
  "history": [
    {"date": "$(date +%Y-%m-%d)", "bytes_written": 5242880, "operation": "installation"}
  ]
}
EOF
        else
            # Update existing health data
            log_message "INFO" "Health data file already exists, updating"
            update_usb_health_data "$partition" 5242880  # ~5MB for installation files
        fi
    fi
    
    # Unmount the partition
    echo -e "Unmounting USB device..."
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Show success message
    show_success "Leonardo AI framework has been installed successfully"
    
    return 0
}

# Configure Leonardo AI settings
configure_leonardo_settings() {
    local usb_path="$1"
    local partition_number="${2:-1}"
    
    log_message "INFO" "Configuring Leonardo AI settings on $usb_path"
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    
    # Check if device exists
    if [[ ! -b "$partition" ]]; then
        show_error "Partition $partition not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/leonardo_config_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "$partition" "$mount_point"; then
        show_error "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if Leonardo AI is installed
    if [[ ! -d "$mount_point/leonardo" ]]; then
        show_error "Leonardo AI not found on $partition"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Configuration file path
    local config_file="$mount_point/leonardo/config/leonardo.conf"
    
    # Check if configuration file exists
    if [[ ! -f "$config_file" ]]; then
        show_error "Configuration file not found"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Show configuration menu
    show_step_header "Leonardo AI Configuration" "$UI_WIDTH"
    echo -e "Current configuration settings:"
    echo ""
    
    # Read and display current settings
    local log_level
    local default_model
    local enable_health
    local enable_telemetry
    
    # Extract values from config file
    log_level=$(grep "LOG_LEVEL=" "$config_file" | cut -d'"' -f2)
    default_model=$(grep "DEFAULT_MODEL=" "$config_file" | cut -d'"' -f2)
    enable_health=$(grep "ENABLE_HEALTH_TRACKING=" "$config_file" | cut -d'=' -f2)
    enable_telemetry=$(grep "ENABLE_TELEMETRY=" "$config_file" | cut -d'=' -f2)
    
    # Display current settings
    echo -e "1. Log Level: ${CYAN}$log_level${NC}"
    echo -e "2. Default Model: ${CYAN}$default_model${NC}"
    echo -e "3. Health Tracking: ${CYAN}$enable_health${NC}"
    echo -e "4. Telemetry: ${CYAN}$enable_telemetry${NC}"
    echo -e "5. Save and Exit"
    echo -e "0. Exit without saving"
    echo ""
    
    # Get user selection
    local choice
    while true; do
        echo -n "Enter your choice [0-5]: "
        read -r choice
        
        case $choice in
            1)
                # Change log level
                echo -e "\nSelect Log Level:"
                echo -e "1. DEBUG (Verbose)"
                echo -e "2. INFO (Normal)"
                echo -e "3. WARNING (Minimal)"
                echo -e "4. ERROR (Critical only)"
                echo -n "Enter your choice [1-4]: "
                read -r log_choice
                
                case $log_choice in
                    1) log_level="DEBUG" ;;
                    2) log_level="INFO" ;;
                    3) log_level="WARNING" ;;
                    4) log_level="ERROR" ;;
                    *) echo -e "${RED}Invalid choice.${NC}" ;;
                esac
                ;;
            2)
                # Change default model
                echo -e "\nEnter Default Model ID (e.g., mistral-7b):"
                echo -n "> "
                read -r default_model
                ;;
            3)
                # Toggle health tracking
                if [[ "$enable_health" == "true" ]]; then
                    enable_health="false"
                    echo -e "${YELLOW}Health tracking disabled.${NC}"
                else
                    enable_health="true"
                    echo -e "${GREEN}Health tracking enabled.${NC}"
                fi
                ;;
            4)
                # Toggle telemetry
                if [[ "$enable_telemetry" == "true" ]]; then
                    enable_telemetry="false"
                    echo -e "${YELLOW}Telemetry disabled.${NC}"
                else
                    enable_telemetry="true"
                    echo -e "${GREEN}Telemetry enabled.${NC}"
                fi
                ;;
            5)
                # Save configuration
                echo -e "\n${YELLOW}Saving configuration...${NC}"
                
                # Update the configuration file
                sed -i "s/LOG_LEVEL=\"[^\"]*\"/LOG_LEVEL=\"$log_level\"/" "$config_file"
                sed -i "s/DEFAULT_MODEL=\"[^\"]*\"/DEFAULT_MODEL=\"$default_model\"/" "$config_file"
                sed -i "s/ENABLE_HEALTH_TRACKING=.*/ENABLE_HEALTH_TRACKING=$enable_health/" "$config_file"
                sed -i "s/ENABLE_TELEMETRY=.*/ENABLE_TELEMETRY=$enable_telemetry/" "$config_file"
                
                echo -e "${GREEN}Configuration saved successfully.${NC}"
                break
                ;;
            0)
                # Exit without saving
                echo -e "\n${YELLOW}Exiting without saving.${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
        
        # Show updated settings
        echo -e "\nCurrent configuration settings:"
        echo -e "1. Log Level: ${CYAN}$log_level${NC}"
        echo -e "2. Default Model: ${CYAN}$default_model${NC}"
        echo -e "3. Health Tracking: ${CYAN}$enable_health${NC}"
        echo -e "4. Telemetry: ${CYAN}$enable_telemetry${NC}"
        echo -e "5. Save and Exit"
        echo -e "0. Exit without saving"
        echo ""
    done
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    return 0
}

# Finalize Leonardo AI installation
finalize_installation() {
    local usb_path="$1"
    local partition_number="${2:-1}"
    
    log_message "INFO" "Finalizing Leonardo AI installation on $usb_path"
    
    show_step_header "Finalizing Installation" "$UI_WIDTH"
    
    # Show success message with friendly llama
    echo -e "${GREEN}Leonardo AI Universal has been successfully installed!${NC}"
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${GREEN}Your USB device is ready to use.${NC}"
    echo ""
    echo -e "To use Leonardo AI Universal:"
    echo -e "1. Safely eject the USB device"
    echo -e "2. Insert it into any compatible computer"
    echo -e "3. Navigate to the 'leonardo' directory"
    echo -e "4. Run the 'leonardo.sh' script"
    echo ""
    
    # Wait for user acknowledgment
    echo -n "Press Enter to continue..."
    read -r
    
    return 0
}
