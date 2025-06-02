#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Leonardo AI USB Maker - Create portable Ollama AI environments
# Version: 5.1.0 (May 28, 2025)
# Authors: Eric & Friendly AI Assistant
# License: MIT
# ═══════════════════════════════════════════════════════════════════════════

# --- Strict Mode Settings ---
set -o errexit   # Exit on error
set -o nounset   # Error on unset variables
set -o pipefail  # Pipe fails on any command failure

# --- Script Identification ---
readonly SCRIPT_SELF_NAME=$(basename "$0")
readonly SCRIPT_VERSION="5.1.0"
readonly SCRIPT_DATE="2025-05-28"
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- Global Configuration ---
# USB Settings
readonly USB_LABEL_DEFAULT="LEONARDO"
USB_LABEL="$USB_LABEL_DEFAULT"
USB_BASE_PATH=""
USB_DEVICE_PATH=""
USB_PARTITION_PATH=""

# Model Settings
readonly DEFAULT_MODEL="llama3:8b"
MODEL_SOURCE_TYPE="pull"  # 'pull' or 'local'
LOCAL_GGUF_PATH=""

# Operation Modes
OPERATION_MODE=""
SELECTED_OS_TARGETS=""
MODELS_TO_INSTALL=()

# UI Configuration
readonly UI_WIDTH=75
readonly UI_BORDER_CHAR="═"
readonly UI_BORDER_TOP_LEFT="╔"
readonly UI_BORDER_TOP_RIGHT="╗"
readonly UI_BORDER_BOTTOM_LEFT="╚"
readonly UI_BORDER_BOTTOM_RIGHT="╝"
readonly UI_BORDER_VERTICAL="║"
readonly UI_BORDER_HORIZONTAL="═"

# --- Color Definitions ---
# Terminal color codes
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"
readonly COLOR_DIM="\033[2m"
readonly COLOR_ITALIC="\033[3m"
readonly COLOR_UNDERLINE="\033[4m"
readonly COLOR_BLINK="\033[5m"
readonly COLOR_INVERT="\033[7m"
readonly COLOR_HIDDEN="\033[8m"

# Text colors
readonly COLOR_BLACK="\033[30m"
readonly COLOR_RED="\033[31m"
readonly COLOR_GREEN="\033[32m"
readonly COLOR_YELLOW="\033[33m"
readonly COLOR_BLUE="\033[34m"
readonly COLOR_MAGENTA="\033[35m"
readonly COLOR_CYAN="\033[36m"
readonly COLOR_WHITE="\033[37m"
readonly COLOR_ORANGE="\033[38;5;208m"

# Background colors
readonly COLOR_BG_BLACK="\033[40m"
readonly COLOR_BG_RED="\033[41m"
readonly COLOR_BG_GREEN="\033[42m"
readonly COLOR_BG_YELLOW="\033[43m"
readonly COLOR_BG_BLUE="\033[44m"
readonly COLOR_BG_MAGENTA="\033[45m"
readonly COLOR_BG_CYAN="\033[46m"
readonly COLOR_BG_WHITE="\033[47m"

# --- Message Severity Levels ---
readonly MSG_DEBUG=0
readonly MSG_INFO=1
readonly MSG_NOTICE=2
readonly MSG_WARNING=3
readonly MSG_ERROR=4
readonly MSG_CRITICAL=5

# --- System Configuration ---
readonly TMP_DIR="/tmp/leonardo_${$}_$(date +%s)"
readonly LOG_FILE="${TMP_DIR}/leonardo.log"

# --- Initialize Global Variables ---
COLORS_ENABLED=true
VERBOSE=false
DRY_RUN=false
PARANOID_MODE=false

# --- Cleanup on Exit ---
cleanup() {
    local exit_code=$?
    
    # Cleanup temporary files if they exist
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
    
    # Reset terminal colors
    echo -n -e "${COLOR_RESET}"
    
    exit $exit_code
}

# Register cleanup function
if [ -z "${LEONARDO_TEST_MODE:-}" ]; then
    trap cleanup EXIT INT TERM
fi

# --- Core Utility Functions ---

# Initialize the script environment
init_environment() {
    # Create temporary directory
    mkdir -p "$TMP_DIR"
    
    # Initialize log file
    > "$LOG_FILE"
    
    # Check for color support
    check_color_support
    
    # Check required dependencies
    check_dependencies
}

# Check if colors are supported in the terminal
check_color_support() {
    if [ -t 1 ] && [ -n "$(command -v tput)" && "$(tput colors)" -ge 8 ]; then
        COLORS_ENABLED=true
    else
        COLORS_ENABLED=false
    fi
}

# Log a message with timestamp and severity
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Map level to string and color
    local level_str
    local color
    
    case "$level" in
        $MSG_DEBUG) level_str="DEBUG"; color="$COLOR_DIM" ;;
        $MSG_INFO) level_str="INFO"; color="$COLOR_CYAN" ;;
        $MSG_NOTICE) level_str="NOTICE"; color="$COLOR_GREEN" ;;
        $MSG_WARNING) level_str="WARNING"; color="$COLOR_YELLOW" ;;
        $MSG_ERROR) level_str="ERROR"; color="$COLOR_RED" ;;
        $MSG_CRITICAL) level_str="CRITICAL"; color="$COLOR_RED$COLOR_BOLD" ;;
        *) level_str="UNKNOWN"; color="$COLOR_MAGENTA" ;;
    esac
    
    # Log to file
    echo "[$timestamp] [$level_str] $message" >> "$LOG_FILE"
    
    # Log to console if not in quiet mode or if error/warning
    if [ "$VERBOSE" = true ] || [ "$level" -ge $MSG_WARNING ]; then
        echo -e "${color}[${level_str}]${COLOR_RESET} $message" >&2
    fi
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local dep
    
    # List of required commands
    local required_commands=(
        "curl" "wget" "parted" "mkfs.fat" "mkfs.ext4"
        "blkid" "lsblk" "findmnt" "mount" "umount"
        "dd" "partprobe" "sfdisk" "hdparm" "blockdev"
        "tar" "gzip" "unzip" "sha256sum" "md5sum"
    )
    
    # Check each command
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message $MSG_ERROR "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            log_message $MSG_ERROR "  - $dep"
        done
        log_message $MSG_ERROR "Please install the missing packages and try again."
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_message $MSG_ERROR "This script must be run as root. Please use 'sudo'."
        exit 1
    fi
}

# Create a temporary file with automatic cleanup
create_temp_file() {
    local prefix="${1:-tmp}"
    mktemp "$TMP_DIR/${prefix}.XXXXXXXXXX"
}

# Create a temporary directory with automatic cleanup
create_temp_dir() {
    local prefix="${1:-tmp}"
    mktemp -d "$TMP_DIR/${prefix}.XXXXXXXXXX"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a file exists and is readable
file_readable() {
    [ -r "$1" ] && [ -f "$1" ]
}

# Check if a directory exists and is writable
dir_writable() {
    [ -w "$1" ] && [ -d "$1" ]
}

# Get the size of a file in human-readable format
human_readable_size() {
    local bytes=$1
    local units=('B' 'KB' 'MB' 'GB' 'TB' 'PB')
    local unit=0
    
    while ((bytes > 1024)) && [ $unit -lt ${#units[@]} ]; do
        bytes=$(bc <<< "scale=2; $bytes / 1024")
        ((unit++))
    done
    
    echo "${bytes} ${units[$unit]}"
}

# Parse command line arguments
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --paranoid)
                PARANOID_MODE=true
                ;;
            --usb-device=*)
                USB_DEVICE_PATH="${1#*=}"
                ;;
            --model=*)
                MODELS_TO_INSTALL+=("${1#*=}")
                ;;
            --os=*)
                SELECTED_OS_TARGETS="${1#*=}"
                ;;
            *)
                log_message $MSG_WARNING "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Display help information
show_help() {
    cat << EOF
${COLOR_BOLD}${COLOR_CYAN}Leonardo AI USB Maker v${SCRIPT_VERSION}${COLOR_RESET}

Usage: ${SCRIPT_SELF_NAME} [options]

Options:
  -h, --help            Show this help message and exit
  -v, --verbose         Enable verbose output
  --dry-run             Run without making any changes
  --paranoid           Enable extra security checks
  --usb-device=DEVICE   Specify USB device (e.g., /dev/sdX)
  --model=MODEL        AI model to install (can be used multiple times)
  --os=OS_LIST         Comma-separated list of target OS (linux,mac,win)

Examples:
  ${SCRIPT_SELF_NAME} --usb-device=/dev/sdb --model=llama3:8b --os=linux,mac
  ${SCRIPT_SELF_NAME} --verbose --dry-run

${COLOR_DIM}For more information, visit: https://github.com/yourusername/leonardo-ai-usb${COLOR_RESET}
EOF
}

# --- UI Components ---

# Print a horizontal line
ui_hr() {
    local width=${1:-$UI_WIDTH}
    local char=${2:-$UI_BORDER_HORIZONTAL}
    printf "%${width}s" | tr ' ' "$char"
}

# Print a header box
ui_header() {
    local title="$1"
    local width=$((UI_WIDTH - 4))
    local padding=$(( (width - ${#title}) / 2 ))
    local padding_extra=$(( (width - ${#title}) % 2 ))
    
    local left_pad=$(printf "%${padding}s" | tr ' ' "$UI_BORDER_HORIZONTAL")
    local right_pad=$(printf "%$((padding + padding_extra))s" | tr ' ' "$UI_BORDER_HORIZONTAL")
    
    echo -e "${COLOR_CYAN}${UI_BORDER_TOP_LEFT}${left_pad} ${COLOR_BOLD}${title}${COLOR_RESET} ${COLOR_CYAN}${right_pad}${UI_BORDER_TOP_RIGHT}${COLOR_RESET}"
}

# Print a footer
ui_footer() {
    local width=$((UI_WIDTH - 2))
    echo -e "${COLOR_CYAN}${UI_BORDER_BOTTOM_LEFT}$(ui_hr $width)${UI_BORDER_BOTTOM_RIGHT}${COLOR_RESET}"
}

# Print a section header
ui_section() {
    echo -e "\n${COLOR_BLUE}${COLOR_BOLD}==>${COLOR_RESET} ${COLOR_BOLD}$1${COLOR_RESET}"
}

# Print a success message
ui_success() {
    echo -e "${COLOR_GREEN}${COLOR_BOLD}✓${COLOR_RESET} ${COLOR_GREEN}$1${COLOR_RESET}"
    log_message $MSG_INFO "SUCCESS: $1"
}

# Print a warning message
ui_warning() {
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}⚠️  WARNING:${COLOR_RESET} ${COLOR_YELLOW}$1${COLOR_RESET}" >&2
    log_message $MSG_WARNING "WARNING: $1"
}

# Print an error message
ui_error() {
    echo -e "${COLOR_RED}${COLOR_BOLD}✗ ERROR:${COLOR_RESET} ${COLOR_RED}$1${COLOR_RESET}" >&2
    log_message $MSG_ERROR "ERROR: $1"
}

# Print a critical error message and exit
ui_critical() {
    echo -e "\n${COLOR_BG_RED}${COLOR_WHITE}${COLOR_BOLD} FATAL ERROR ${COLOR_RESET} ${COLOR_RED}${COLOR_BOLD}$1${COLOR_RESET}\n" >&2
    log_message $MSG_CRITICAL "CRITICAL: $1"
    exit 1
}

# Print an info message
ui_info() {
    echo -e "${COLOR_CYAN}${COLOR_BOLD}ℹ INFO:${COLOR_RESET} $1"
    log_message $MSG_INFO "INFO: $1"
}

# Print a debug message (only in verbose mode)
ui_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${COLOR_DIM}[DEBUG] $1${COLOR_RESET}"
    fi
    log_message $MSG_DEBUG "DEBUG: $1"
}

# Ask for user confirmation
confirm() {
    local prompt="${1:-Are you sure?} [y/N] "
    local default="${2:-false}"
    
    if [ "$default" = true ]; then
        prompt="${1:-Are you sure?} [Y/n] "
    fi
    
    while true; do
        read -r -p "$prompt" response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                return 0
                ;;
            [nN][oO]|[nN]) 
                return 1
                ;;
            *)
                if [ "$default" = true ]; then
                    return 0
                else
                    return 1
                fi
                ;;
        esac
    done
}

# Show a menu and get user selection
show_menu() {
    local title="$1"
    local prompt="$2"
    local -n options_ref=$3
    shift 3
    
    local options=("$@")
    local valid_choices=()
    local choice
    
    # Clear screen and show title
    clear
    ui_header "$title"
    
    # Display menu options
    for ((i=0; i<${#options[@]}; i+=2)); do
        local key="${options[i]}"
        local desc="${options[i+1]}"
        
        # Skip empty descriptions (used for separators)
        if [ -z "$desc" ]; then
            echo
            continue
        fi
        
        # Add to valid choices
        valid_choices+=("$key")
        
        # Display option
        echo -e "${COLOR_BOLD}${COLOR_GREEN}${key})${COLOR_RESET} ${desc}"
    done
    
    # Show quit option
    echo -e "${COLOR_BOLD}${COLOR_RED}q)${COLOR_RESET} Quit\n"
    
    # Get user input
    while true; do
        read -r -p "${prompt} " choice
        
        # Check for quit
        if [ "$choice" = "q" ]; then
            echo "q"
            return 1
        fi
        
        # Check if choice is valid
        for valid_choice in "${valid_choices[@]}"; do
            if [ "$choice" = "$valid_choice" ]; then
                echo "$choice"
                return 0
            fi
        done
        
        ui_error "Invalid choice. Please try again."
    done
}

# Show a progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local label="${4:-Progress:}"
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    # Create the bar
    local bar="${COLOR_GREEN}"
    for ((i=0; i<filled; i++)); do
        bar+="="
    done
    
    bar+="${COLOR_RED}${COLOR_BOLD}>${COLOR_RESET}${COLOR_YELLOW}"
    
    for ((i=filled; i<width-1; i++)); do
        bar+=" "
    done
    
    bar+="${COLOR_RESET}"
    
    # Print the progress bar
    printf "\r${COLOR_BOLD}${label}${COLOR_RESET} [%s] %d%%" "$bar" "$percent"
    
    # Add newline if complete
    if [ $current -ge $total ]; then
        echo
    fi
}

# Show a spinner for indeterminate progress
spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    
    # Hide cursor
    tput civis
    
    # Start the spinner
    while ps -p $pid > /dev/null 2>&1; do
        for char in "${spin_chars[@]}"; do
            printf "\r${COLOR_CYAN}${char}${COLOR_RESET} ${message}"
            sleep $delay
            
            # Check if process is still running
            if ! ps -p $pid > /dev/null 2>&1; then
                break 2
            fi
        done
    done
    
    # Show cursor and clear line
    tput cnorm
    printf "\r%-50s\n" "${COLOR_GREEN}✓${COLOR_RESET} ${message}"
}

# --- Filesystem Operations ---

# Check if a path is a block device
is_block_device() {
    [ -b "$1" ] && return 0 || return 1
}

# Check if a path is a USB device
is_usb_device() {
    local device="$1"
    local syspath
    
    # Get the sysfs path for the device
    syspath="$(readlink -f "/sys/block/$(basename "$device")" 2>/dev/null || true)"
    
    # Check if it's a USB device by looking at the device path
    if [[ "$syspath" == */usb* ]]; then
        return 0
    fi
    
    # Check using lsblk if available
    if command -v lsblk >/dev/null; then
        if lsblk -dno HOTPLUG "$device" 2>/dev/null | grep -q '^1$'; then
            return 0
        fi
    fi
    
    return 1
}

# Get the size of a block device in bytes
get_device_size() {
    local device="$1"
    if [ -b "$device" ]; then
        blockdev --getsize64 "$device" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get the filesystem type of a device
get_fs_type() {
    local device="$1"
    if [ -b "$device" ]; then
        lsblk -no FSTYPE "$device" 2>/dev/null || echo "unknown"
    else
        echo "none"
    fi
}

# Unmount a device and all its partitions
unmount_device() {
    local device="$1"
    local mounted_partitions
    local attempts=3
    
    # Find all mounted partitions of the device
    mounted_partitions=$(mount | grep "^$device" | awk '{print $1}' || true)
    
    # Unmount all mounted partitions
    for partition in $mounted_partitions; do
        ui_debug "Unmounting partition: $partition"
        for ((i=1; i<=attempts; i++)); do
            if umount "$partition" 2>/dev/null; then
                ui_debug "Successfully unmounted $partition"
                break
            else
                if [ $i -eq $attempts ]; then
                    ui_warning "Failed to unmount $partition after $attempts attempts"
                    return 1
                fi
                sleep 1
            fi
        done
    done
    
    return 0
}

# Format a device with the specified filesystem
format_device() {
    local device="$1"
    local fstype="${2:-vfat}"
    local label="${3:-}"
    local options=()
    
    # Unmount the device first
    if ! unmount_device "$device"; then
        ui_error "Failed to unmount device $device before formatting"
        return 1
    fi
    
    # Set filesystem-specific options
    case "$fstype" in
        vfat|fat32)
            fstype="vfat"
            options=(-F 32 -n "$label")
            ;;
        ext4)
            options=(-F -L "$label")
            ;;
        ntfs)
            options=(-f -L "$label")
            ;;
        *)
            ui_error "Unsupported filesystem type: $fstype"
            return 1
            ;;
    esac
    
    ui_info "Formatting $device as $fstype with label '$label'..."
    
    # Format the device
    if [ "$DRY_RUN" = true ]; then
        ui_warning "DRY RUN: Would format $device as $fstype with options: ${options[*]}"
        return 0
    fi
    
    # Create a new partition table (wipes all data!)
    if ! dd if=/dev/zero of="$device" bs=1M count=10 2>/dev/null; then
        ui_error "Failed to wipe partition table on $device"
        return 1
    fi
    
    # Create a new partition
    if ! echo 'type=0FC63DAF-8483-4772-8E79-3D69D8477DE4' | sfdisk --label gpt "$device" >/dev/null; then
        ui_error "Failed to create partition on $device"
        return 1
    fi
    
    # Get the partition path
    local partition="${device}1"
    if [[ "$device" == *"nvme"* ]] || [[ "$device" == *"mmcblk"* ]]; then
        partition="${device}p1"
    fi
    
    # Wait for the partition to be available
    partprobe "$device"
    sleep 2
    
    # Format the partition
    case "$fstype" in
        vfat)
            if ! mkfs.vfat -F 32 -n "$label" "$partition" >/dev/null; then
                ui_error "Failed to format $partition as $fstype"
                return 1
            fi
            ;;
        ext4)
            if ! mkfs.ext4 -F -L "$label" "$partition" >/dev/null; then
                ui_error "Failed to format $partition as $fstype"
                return 1
            fi
            ;;
        ntfs)
            if ! mkfs.ntfs -f -L "$label" "$partition" >/dev/null; then
                ui_error "Failed to format $partition as $fstype"
                return 1
            fi
            ;;
    esac
    
    ui_success "Successfully formatted $device as $fstype"
    return 0
}

# Mount a device to a mount point
mount_device() {
    local device="$1"
    local mount_point="$2"
    local fstype="${3:-auto}"
    local options="${4:-rw,noatime}"
    
    # Create mount point if it doesn't exist
    if [ ! -d "$mount_point" ]; then
        mkdir -p "$mount_point"
    fi
    
    # Mount the device
    if ! mount -t "$fstype" -o "$options" "$device" "$mount_point" 2>/dev/null; then
        ui_error "Failed to mount $device at $mount_point"
        return 1
    fi
    
    ui_debug "Mounted $device at $mount_point"
    return 0
}

# Safely copy files with progress
safe_copy() {
    local src="$1"
    local dest="$2"
    local preserve_perms="${3:-true}"
    
    # Check if source exists
    if [ ! -e "$src" ]; then
        ui_error "Source does not exist: $src"
        return 1
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir="$(dirname "$dest")"
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi
    
    ui_debug "Copying $src to $dest"
    
    # Use rsync if available for better progress and error handling
    if command -v rsync >/dev/null; then
        local rsync_opts=(-a)
        [ "$preserve_perms" = false ] && rsync_opts=(-rltD)
        
        if [ "$VERBOSE" = true ]; then
            rsync_opts+=(-v --progress)
        fi
        
        if ! rsync "${rsync_opts[@]}" "$src" "$dest"; then
            ui_error "Failed to copy $src to $dest"
            return 1
        fi
    else
        # Fall back to cp
        local cp_opts=(-a)
        [ "$preserve_perms" = false ] && cp_opts=(-r)
        
        if ! cp "${cp_opts[@]}" "$src" "$dest"; then
            ui_error "Failed to copy $src to $dest"
            return 1
        fi
    fi
    
    return 0
}

# Recursively set permissions on a directory
set_permissions() {
    local path="$1"
    local dir_perm="${2:-755}"
    local file_perm="${3:-644}"
    
    if [ ! -e "$path" ]; then
        ui_warning "Path does not exist: $path"
        return 1
    fi
    
    # Set directory permissions
    find "$path" -type d -exec chmod "$dir_perm" {} +
    
    # Set file permissions
    find "$path" -type f -exec chmod "$file_perm" {} +
    
    # Make scripts executable
    find "$path" -type f -name "*.sh" -exec chmod +x {} +
    
    return 0
}

# Calculate the size of a directory in bytes
calculate_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -bs "$dir" | awk '{print $1}'
    else
        echo "0"
    fi
}

# Check if there's enough free space on a filesystem
check_disk_space() {
    local path="$1"
    local required_bytes=$2
    local available_bytes
    
    available_bytes=$(df -P "$path" | awk 'NR==2 {print $4*1024}')
    
    if [ "$available_bytes" -lt "$required_bytes" ]; then
        ui_error "Not enough space on $path. Required: $(human_readable_size $required_bytes), Available: $(human_readable_size $available_bytes)"
        return 1
    fi
    
    return 0
}

# Create a directory if it doesn't exist
ensure_dir_exists() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir"; then
            ui_error "Failed to create directory: $dir"
            return 1
        fi
        
        if ! chmod "$mode" "$dir"; then
            ui_warning "Failed to set permissions on directory: $dir"
        fi
    fi
    
    return 0
}

# Remove a directory and its contents
remove_dir() {
    local dir="$1"
    
    if [ -d "$dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            ui_warning "DRY RUN: Would remove directory: $dir"
            return 0
        fi
        
        if ! rm -rf "$dir"; then
            ui_error "Failed to remove directory: $dir"
            return 1
        fi
    fi
    
    return 0
}
# Source network operations
source "${SCRIPT_DIR}/network_ops.sh"
