# ==============================================================================
# System Utilities
# ==============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # List of required commands
    local required_commands=(
        "parted" "mkfs.vfat" "mkfs.ntfs" "mkfs.ext4" "sgdisk" "dd" "lsblk"
        "blkid" "mount" "umount" "partprobe" "fuser" "udevadm" "hdparm" "sfdisk"
        "md5sum" "sha1sum" "sha256sum"
    )
    
    # Check each command
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check for at least one download tool
    if ! command_exists curl && ! command_exists wget; then
        missing_deps+=("curl or wget (at least one is required)")
    fi
    
    # If any dependencies are missing, show an error and exit
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "The following required dependencies are missing:"
        for dep in "${missing_deps[@]}"; do
            print_error "  - $dep"
        done
        print_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_debug "All dependencies are available"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root. Please use 'sudo $0' or run as root."
        exit 1
    fi
    print_debug "Running with root privileges"
}

# Initialize the script
initialize_script() {
    # Set up signal handlers for clean exit
    trap cleanup INT TERM
    
    # Create necessary directories
    mkdir -p "$TMP_DIR/downloads" "$TMP_DIR/mount"
    
    # Add mount point to cleanup list
    MOUNT_POINTS+=("$TMP_DIR/mount")
    
    # Initialize logging
    init_logging
    
    print_debug "Script initialized"
}

# Clean up temporary files and directories
cleanup() {
    local exit_code=$?
    
    print_debug "Cleaning up..."
    
    # Only clean up if not in dry run mode
    if [ "$DRY_RUN" != true ]; then
        # Unmount any mounted filesystems
        for mount_point in "${MOUNT_POINTS[@]}"; do
            if mountpoint -q "$mount_point" 2>/dev/null; then
                print_debug "Unmounting $mount_point"
                umount -l "$mount_point" 2>/dev/null || true
            fi
        done
        
        # Remove temporary directory if it exists
        if [ -d "$TMP_DIR" ]; then
            print_debug "Removing temporary directory: $TMP_DIR"
            rm -rf --one-file-system "$TMP_DIR" 2>/dev/null || true
        fi
    fi
    
    # Exit with the appropriate status code
    if [ $exit_code -ne 0 ]; then
        print_error "Script failed with exit code $exit_code"
    else
        print_debug "Script completed successfully"
    fi
    
    # Don't use exit here as it can cause issues with subshells
    # Just return the exit code and let the trap handlers manage exiting
    return $exit_code
}

# Convert bytes to human-readable format
human_readable_size() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit=0
    
    while (( $(echo "$bytes > 1024" | bc -l) )); do
        bytes=$(echo "scale=2; $bytes / 1024" | bc)
        unit=$((unit + 1))
    done
    
    echo "$bytes ${units[$unit]}"
}

# Get the size of a file or directory
get_size() {
    local path="$1"
    
    if [ -f "$path" ]; then
        # For files, use stat
        stat -c %s "$path" 2>/dev/null || stat -f %z "$path" 2>/dev/null
    elif [ -d "$path" ]; then
        # For directories, use du
        du -sb "$path" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Check if a string is a valid URL
is_valid_url() {
    local url="$1"
    local regex='^(https?|ftp)://[^\s/$.?#].[^\s]*$'
    
    if [[ $url =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

# Parse command line arguments
parse_arguments() {
    # Don't use local here - avoids syntax error when used outside a function context
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                # Reset all color variables
                COLOR_RESET=""
                COLOR_BOLD=""
                COLOR_DIM=""
                COLOR_UNDERLINE=""
                COLOR_BLINK=""
                COLOR_INVERT=""
                COLOR_BLACK=""
                COLOR_RED=""
                COLOR_GREEN=""
                COLOR_YELLOW=""
                COLOR_BLUE=""
                COLOR_MAGENTA=""
                COLOR_CYAN=""
                COLOR_WHITE=""
                COLOR_BG_BLACK=""
                COLOR_BG_RED=""
                COLOR_BG_GREEN=""
                COLOR_BG_YELLOW=""
                COLOR_BG_BLUE=""
                COLOR_BG_MAGENTA=""
                COLOR_BG_CYAN=""
                COLOR_BG_WHITE=""
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_debug "Command line arguments parsed"
}
