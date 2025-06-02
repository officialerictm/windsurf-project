# ==============================================================================
# Leonardo AI Universal - Main Application
# ==============================================================================
# Description: Main application logic and user interface
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/header.sh,00_core/config.sh,00_core/colors.sh,00_core/logging.sh,02_ui/basic.sh,02_ui/warnings.sh,03_filesystem/device.sh,03_filesystem/health.sh,04_network/download.sh,04_network/checksum.sh,05_models/registry.sh,05_models/installer.sh,06_deployment/installer.sh
# ==============================================================================

# Main entry point
main() {
    # Initialize the application
    init_application
    
    # Process command line arguments
    process_arguments "$@"
    
    # Main application loop
    if [[ -z "$COMMAND" ]]; then
        show_main_menu
    else
        execute_command "$COMMAND" "${COMMAND_ARGS[@]}"
    fi
    
    # Cleanup on exit
    cleanup_and_exit 0
}

# Initialize the application
init_application() {
    # Welcome banner
    clear
    echo -e "${BOLD}${BLUE}Initializing Leonardo AI Universal...${NC}"
    
    # Create temporary directories
    mkdir -p "$TMP_DIR"
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$LOG_DIR"
    
    # Initialize systems
    log_message "INFO" "Initializing application"
    init_download_system
    init_model_registry
    
    # Check for necessary tools
    check_required_tools
    
    # Check system requirements
    check_system_requirements
    
    log_message "INFO" "Application initialized successfully"
}

# Check for required tools
check_required_tools() {
    log_message "DEBUG" "Checking for required tools"
    
    local missing_tools=()
    
    # Check for essential tools
    for tool in lsblk mount umount mkfs.exfat mkfs.ext4 mkfs.vfat parted; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # Check for optional but recommended tools
    for tool in jq bc hdparm partprobe sfdisk; do
        if ! command -v "$tool" &>/dev/null; then
            log_message "WARNING" "Optional tool not found: $tool"
        fi
    done
    
    # Report missing essential tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing required tools: ${missing_tools[*]}"
        echo -e "${RED}Error: Missing required tools:${NC} ${missing_tools[*]}"
        echo -e "Please install these tools and try again."
        
        # Suggest installation commands for common distros
        echo -e "\n${YELLOW}To install these tools:${NC}"
        echo -e "${CYAN}Debian/Ubuntu:${NC} sudo apt-get install util-linux mount exfat-utils e2fsprogs dosfstools parted"
        echo -e "${CYAN}Fedora/RHEL:${NC} sudo dnf install util-linux mount exfatprogs e2fsprogs dosfstools parted"
        echo -e "${CYAN}Arch Linux:${NC} sudo pacman -S util-linux exfatprogs e2fsprogs dosfstools parted"
        
        exit 1
    fi
    
    log_message "DEBUG" "All required tools are available"
}

# Check system requirements
check_system_requirements() {
    log_message "DEBUG" "Checking system requirements"
    
    # Check for root/sudo access
    if [[ $EUID -ne 0 ]]; then
        # Check if we need to prompt for root privileges
        if [[ -n "${LEONARDO_NO_ROOT:-}" ]] || [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
            log_message "INFO" "Test mode enabled, continuing with limited privileges"
            echo -e "${YELLOW}Test mode enabled. Running with limited privileges.${NC}"
            echo "USB operations will be in test mode only (no actual formatting)."
            echo ""
            sleep 1
        else
            # Not in test mode and not root - exit with error
            echo -e "\n${RED}Error: This operation requires root privileges.${NC}"
            echo "Please run this script with sudo or as the root user."
            exit 1
        fi
    fi
    
    # Check memory
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    log_message "DEBUG" "System memory: $total_mem MB"
    
    if [[ $total_mem -lt 2048 ]]; then
        log_message "WARNING" "Low memory system detected: $total_mem MB"
        echo -e "${YELLOW}Warning: Low memory system detected.${NC}"
        echo -e "Some large models may not work properly."
        echo ""
    fi
    
    # Check disk space
    local free_space=$(df -m . | awk 'NR==2 {print $4}')
    log_message "DEBUG" "Free space: $free_space MB"
    
    if [[ $free_space -lt 1024 ]]; then
        log_message "WARNING" "Low disk space: $free_space MB"
        echo -e "${YELLOW}Warning: Low disk space.${NC}"
        echo -e "You may not have enough space for downloading models."
        echo ""
    fi
    
    # Check GPU availability (optional)
    if command -v nvidia-smi &>/dev/null; then
        SYSTEM_HAS_NVIDIA_GPU=true
        
        # Try to get GPU memory
        GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | tr -d ' ')
        log_message "INFO" "NVIDIA GPU detected with $GPU_MEMORY MB memory"
    else
        SYSTEM_HAS_NVIDIA_GPU=false
        GPU_MEMORY=0
        log_message "INFO" "No NVIDIA GPU detected"
    fi
    
    log_message "DEBUG" "System requirements check completed"
}

# Process command line arguments
process_arguments() {
    log_message "DEBUG" "Processing command line arguments"
    
    # Reset variables
    COMMAND=""
    COMMAND_ARGS=()
    
    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--debug)
                DEBUG_MODE=true
                LOG_LEVEL="DEBUG"
                ;;
            --create-usb)
                COMMAND="create_usb"
                ;;
            --add-model)
                COMMAND="add_model"
                shift
                [[ $# -gt 0 ]] && COMMAND_ARGS+=("$1")
                ;;
            --list-models)
                COMMAND="list_models"
                ;;
            --check-health)
                COMMAND="check_health"
                ;;
            *)
                # If first positional argument and no command set, treat as command
                if [[ -z "$COMMAND" ]]; then
                    COMMAND="$1"
                else
                    # Otherwise add to command args
                    COMMAND_ARGS+=("$1")
                fi
                ;;
        esac
        shift
    done
    
    log_message "DEBUG" "Command: $COMMAND, Args: ${COMMAND_ARGS[*]}"
}

# Show help information
show_help() {
    echo -e "${BOLD}Leonardo AI Universal v6.0.0${NC}"
    echo -e "Usage: $0 [options] [command]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --version     Show version information"
    echo -e "  -d, --debug       Enable debug mode"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  create-usb        Create a new Leonardo AI USB device"
    echo -e "  add-model MODEL   Add a model to an existing USB device"
    echo -e "  list-models       List available models"
    echo -e "  check-health      Check USB device health"
    echo ""
    echo -e "For more information, visit: https://windsurf.io/leonardo"
}

# Show version information
show_version() {
    echo -e "${BOLD}Leonardo AI Universal v6.0.0${NC}"
    echo -e "Copyright © 2025 Windsurf.io"
    echo -e "License: Proprietary"
    echo -e "All rights reserved."
}

# Execute a command
execute_command() {
    local cmd="$1"
    shift
    local args=("$@")
    
    log_message "INFO" "Executing command: $cmd ${args[*]}"
    
    case "$cmd" in
        create_usb|create-usb)
            create_new_usb "${args[@]}"
            ;;
        add_model|add-model)
            add_model_to_usb "${args[@]}"
            ;;
        list_models|list-models)
            list_available_models "table"
            ;;
        check_health|check-health)
            check_usb_health "${args[@]}"
            ;;
        *)
            log_message "ERROR" "Unknown command: $cmd"
            echo -e "${RED}Error: Unknown command: $cmd${NC}"
            show_help
            return 1
            ;;
    esac
    
    return $?
}
