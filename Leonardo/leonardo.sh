#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker
# ==============================================================================
# AUTOMATICALLY ASSEMBLED SCRIPT - DO NOT EDIT DIRECTLY
# Generated on: 2025-05-30 21:41:42
# Generator: assemble.sh v1.0.0
# ==============================================================================

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'


# ==============================================================================
# Component: 00_core/header.sh
# ==============================================================================
#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker - Core Header
# ==============================================================================
# Description: Main script header and initialization
# Author: Leonardo AI Team
# Version: 5.0.0
# License: MIT
# ==============================================================================

# Set umask for secure file creation
umask 077

# Script information
SCRIPT_TITLE="Leonardo AI USB Maker"
SCRIPT_VERSION="5.0.0"
SCRIPT_AUTHOR="Eric™ & The Leonardo AI Team"
SCRIPT_LICENSE="MIT"
SCRIPT_REPO="https://github.com/leonardo-ai/usb-maker"

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"



# ==============================================================================
# Component: 00_core/config.sh
# ==============================================================================
# ==============================================================================
# Global Configuration
# ==============================================================================

# Global variables
SHOW_HELP=false
export VERBOSE=true # Temporarily enable for debugging

# UTF-8 paranoia: check and remediate locale for Unicode box drawing
LEONARDO_ASCII_UI=false

# Check if the terminal supports UTF-8
CHARMAP="$(locale charmap 2>/dev/null)"
if [[ "$CHARMAP" != "UTF-8" ]]; then
    # Try to set to a common UTF-8 locale
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    CHARMAP="$(locale charmap 2>/dev/null)"
    if [[ "$CHARMAP" != "UTF-8" ]]; then
        LEONARDO_ASCII_UI=true
        # Print a clear warning for the user (will be shown by UI code if possible)
        LEONARDO_UTF8_WARNING="\n\e[1;33m[WARNING]\e[0m Your terminal is not using UTF-8 locale. Some UI elements may look wrong (boxes, lines, icons).\n\e[1mDetected locale: \e[0m$(locale | grep LANG)\n\e[1mTo fix this, run:\e[0m\n  export LANG=en_US.UTF-8\n  export LC_ALL=en_US.UTF-8\nThen restart your terminal.\nFor permanent fix, add those lines to your ~/.bashrc or ~/.zshrc.\n"
    fi
fi

# Default settings
DEFAULT_USB_DEVICE=""
DEFAULT_FS_TYPE="exfat"  # exfat works on Windows, macOS, and Linux
DEFAULT_PARTITION_TABLE="gpt"  # Use GPT for UEFI compatibility
DEFAULT_PARTITION_SCHEME="single"  # single or multiple partitions

# Model configuration
DEFAULT_MODEL="llama3-8b"  # Default model to use
SUPPORTED_MODELS=(
    "llama3-8b:Meta LLaMA 3 8B"
    "llama3-70b:Meta LLaMA 3 70B"
    "mistral-7b:Mistral 7B"
    "mixtral-8x7b:Mixtral 8x7B"
)

# Operation modes
OPERATION_MODES=(
    "create:Create a new bootable USB"
    "verify:Verify USB integrity"
    "health:Check USB health"
    "update:Update the script"
    "help:Show help information"
)

# UI configuration
UI_WIDTH=80
UI_PADDING=2
UI_BORDER_CHAR="═"
UI_HEADER_CHAR="─"
UI_FOOTER_CHAR="─"
UI_SECTION_CHAR="─"

# Temporary directory for script operations
TMP_DIR="${TMPDIR:-/tmp}/leonardo-usb-maker-$USER"

# Create temporary directory if it doesn't exist
mkdir -p "$TMP_DIR"

# Log file location
LOG_DIR="${TMP_DIR}/logs"
LOG_FILE="${LOG_DIR}/leonardo-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# Find required terminal utilities and set fallback TERM if needed
if [ -z "$TERM" ]; then
    export TERM="xterm-256color"  # Set a fallback terminal type
fi

# Initialize terminal capabilities
TPUT_CMD_PATH=""
TPUT_CLEAR_POSSIBLE=false
HAS_COLORS=false
TERM_COLS=80
TERM_ROWS=24

if command -v tput >/dev/null 2>&1; then
    TPUT_CMD_PATH="$(command -v tput)"
    if "$TPUT_CMD_PATH" clear >/dev/null 2>&1; then
        TPUT_CLEAR_POSSIBLE=true
    fi
    
    # Try to get terminal size
    TERM_COLS="$("$TPUT_CMD_PATH" cols 2>/dev/null || echo 80)"
    TERM_ROWS="$("$TPUT_CMD_PATH" lines 2>/dev/null || echo 24)"
    
    # Check if terminal supports colors
    if "$TPUT_CMD_PATH" colors >/dev/null 2>&1; then
        if [ "$("$TPUT_CMD_PATH" colors)" -ge 8 ]; then
            HAS_COLORS=true
        fi
    fi
fi

# Set UI width based on terminal width
UI_WIDTH=$((TERM_COLS - 4))
if [ $UI_WIDTH -lt 60 ]; then
    UI_WIDTH=60  # Minimum width to ensure proper formatting
fi

# Runtime configuration
DRY_RUN=false
FORCE=false
VERBOSE=false
QUIET=false
NO_COLOR=false

# Array to keep track of mounted points for cleanup
MOUNT_POINTS=()

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_CRITICAL=4

# Default log level (can be overridden by command line)
LOG_LEVEL=$LOG_LEVEL_INFO



# ==============================================================================
# Component: 00_core/colors.sh
# ==============================================================================
# ==============================================================================
# Color Definitions
# ==============================================================================

# Force all echo commands to use -e to interpret escape sequences
alias echo='echo -e'

# Only define colors when connected to a terminal and colors aren't disabled
if [ -t 1 ] && [ "$NO_COLOR" != "true" ]; then
    # Use more compatible escape sequence format
    # Colors for terminal - using \e instead of \033 for better compatibility
    COLOR_RESET="\e[0m"
    COLOR_BOLD="\e[1m"
    COLOR_DIM="\e[2m"
    COLOR_UNDERLINE="\e[4m"
    COLOR_BLINK="\e[5m"
    COLOR_INVERT="\e[7m"
    
    # Foreground colors
    COLOR_BLACK="\e[30m"
    COLOR_RED="\e[31m"
    COLOR_GREEN="\e[32m"
    COLOR_YELLOW="\e[33m"
    COLOR_BLUE="\e[34m"
    COLOR_MAGENTA="\e[35m"
    COLOR_CYAN="\e[36m"
    COLOR_WHITE="\e[37m"
    
    # Background colors
    COLOR_BG_BLACK="\e[40m"
    COLOR_BG_RED="\e[41m"
    COLOR_BG_GREEN="\e[42m"
    COLOR_BG_YELLOW="\e[43m"
    COLOR_BG_BLUE="\e[44m"
    COLOR_BG_MAGENTA="\e[45m"
    COLOR_BG_CYAN="\e[46m"
    COLOR_BG_WHITE="\e[47m"
    # Custom dark background (256-color dark gray, fallback to black)
    COLOR_BG_DARK="\e[48;5;236m"
    
    # Bright colors
    COLOR_BRIGHT_BLACK="\e[90m"
    COLOR_BRIGHT_RED="\e[91m"
    COLOR_BRIGHT_GREEN="\e[92m"
    COLOR_BRIGHT_YELLOW="\e[93m"
    COLOR_BRIGHT_BLUE="\e[94m"
    COLOR_BRIGHT_MAGENTA="\e[95m"
    COLOR_BRIGHT_CYAN="\e[96m"
    COLOR_BRIGHT_WHITE="\e[97m"
    
    # Custom colors
    # Orange (color between yellow and red for our warning severity system)
    COLOR_ORANGE="\e[38;2;255;140;0m"
    
    # Bright background colors
    COLOR_BG_BRIGHT_BLACK="\e[100m"
    COLOR_BG_BRIGHT_RED="\e[101m"
    COLOR_BG_BRIGHT_GREEN="\e[102m"
    COLOR_BG_BRIGHT_YELLOW="\e[103m"
    COLOR_BG_BRIGHT_BLUE="\e[104m"
    COLOR_BG_BRIGHT_MAGENTA="\e[105m"
    COLOR_BG_BRIGHT_CYAN="\e[106m"
    COLOR_BG_BRIGHT_WHITE="\e[107m"
else
    # No colors for non-terminal output
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
    COLOR_BRIGHT_BLACK=""
    COLOR_BRIGHT_RED=""
    COLOR_BRIGHT_GREEN=""
    COLOR_BRIGHT_YELLOW=""
    COLOR_BRIGHT_BLUE=""
    COLOR_BRIGHT_MAGENTA=""
    COLOR_BRIGHT_CYAN=""
    COLOR_BRIGHT_WHITE=""
    COLOR_BG_BRIGHT_BLACK=""
    COLOR_BG_BRIGHT_RED=""
    COLOR_BG_BRIGHT_GREEN=""
    COLOR_BG_BRIGHT_YELLOW=""
    COLOR_BG_BRIGHT_BLUE=""
    COLOR_BG_BRIGHT_MAGENTA=""
    COLOR_BG_BRIGHT_CYAN=""
    COLOR_BG_BRIGHT_WHITE=""
fi

# Extended color palette for enhanced UI
COLOR_ORANGE="\e[38;5;208m"  # Orange color for caution level warnings
COLOR_PURPLE="\e[38;5;135m"  # Purple for special highlights
COLOR_TEAL="\e[38;5;37m"    # Teal for alternative info highlights
COLOR_PINK="\e[38;5;205m"   # Pink for special features

# Gradient colors for progress bars and specialized UI elements
COLOR_GRADIENT_1="\e[38;5;39m"  # Light blue
COLOR_GRADIENT_2="\e[38;5;45m"  # Cyan
COLOR_GRADIENT_3="\e[38;5;51m"  # Light cyan
COLOR_GRADIENT_4="\e[38;5;87m"  # Sky blue

# Define llama warning levels for different severities
# From user memory: Implemented a progression of warning severities
LLAMA_NORMAL="(•ᴗ•)🦙"  # Friendly llama for normal operations
LLAMA_CAUTION="(>‿-)🦙"  # Mischievous winking llama for first level caution
LLAMA_WARNING="(ಠ‿ಠ)🦙"  # Intense/crazy-eyed llama for serious warnings
LLAMA_WARNING_SERIOUS="(ಠ‿ಠ)🦙"  # Alias for backward compatibility



# ==============================================================================
# Component: 01_utils/logging.sh
# ==============================================================================
# ==============================================================================
# Logging Utilities
# ==============================================================================

# Log a message to file and optionally to stdout
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local to_console="${3:-false}"
    
    # Map log levels to numeric values
    local level_num
    case "$level" in
        DEBUG) level_num=0 ;;
        INFO) level_num=1 ;;
        WARNING) level_num=2 ;;
        ERROR) level_num=3 ;;
        CRITICAL) level_num=4 ;;
        *) level_num=1 ;;
    esac
    
    # Only log if the message level is >= the current log level
    if [ "$level_num" -ge "$LOG_LEVEL" ]; then
        # Strip ANSI color codes for log file
        local clean_message
        clean_message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')
        echo "[$timestamp] [$level] $clean_message" >> "$LOG_FILE"
        
        # Also print to stdout if requested AND not in quiet mode
        # (or if it's an error/critical message which should always be shown)
        if [ "$to_console" = "true" ] && \
           ([ "$QUIET" != true ] || [ "$level" = "ERROR" ] || [ "$level" = "CRITICAL" ]); then
            echo "[$timestamp] [$level] $message"
        fi
    fi
}

# Print a debug message
print_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${COLOR_BLUE}🐛${COLOR_RESET} $1" >&2
        log "$1" "DEBUG" false
    fi
}

# Print an info message
print_info() {
    # Use color only for console output
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} $1" >&2
    # Log to file without sending to console again
    log "$1" "INFO" false
}

# Print a success message
print_success() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $1" >&2
    log "$1" "INFO" false
}

# Print a warning message
print_warning() {
    # Make sure the llama warning is properly displayed
    if [ -n "$LLAMA_CAUTION" ]; then
        echo -e "${COLOR_YELLOW}${LLAMA_CAUTION} ⚠${COLOR_RESET} $1" >&2
    else
        echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $1" >&2
    fi
    log "$1" "WARNING" false
}

# Print an error message
print_error() {
    # Make sure the llama warning is properly displayed
    if [ -n "$LLAMA_WARNING" ]; then
        echo -e "${COLOR_RED}${LLAMA_WARNING} ✗${COLOR_RESET} $1" >&2
    else
        echo -e "${COLOR_RED}✗${COLOR_RESET} $1" >&2
    fi
    log "$1" "ERROR" false
}

# Print a critical error message and exit
print_critical() {
    if [ -n "$LLAMA_WARNING" ]; then
        echo -e "${COLOR_BG_RED}${COLOR_WHITE}${LLAMA_WARNING} CRITICAL ERROR${COLOR_RESET} $1" >&2
    else
        echo -e "${COLOR_BG_RED}${COLOR_WHITE}CRITICAL ERROR${COLOR_RESET} $1" >&2
    fi
    log "$1" "CRITICAL" false
    exit 1
}

# Initialize the log file
init_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || {
        echo "Failed to create log directory: $(dirname "$LOG_FILE")" >&2
        # Fall back to temporary directory
        LOG_FILE="/tmp/leonardo-$(date +%Y%m%d).log"
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
        echo "Using fallback log file: $LOG_FILE" >&2
    }
    
    # Initialize log file with header
    cat > "$LOG_FILE" << EOF
# Leonardo AI USB Maker Log
# Started: $(date)
# Version: $SCRIPT_VERSION
# User: $(whoami)
# Host: $(hostname)
# Command: $0 $*
# ==========================================

EOF

    # Set appropriate permissions
    chmod 600 "$LOG_FILE" 2>/dev/null || true
    
    print_debug "Logging initialized: $LOG_FILE"
}



# ==============================================================================
# Component: 01_utils/system.sh
# ==============================================================================
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



# ==============================================================================
# Component: 02_ui/basic.sh
# ==============================================================================
# ==============================================================================
# Basic UI Components
# ==============================================================================

# Repeat a character N times (Unicode-safe)
repeat_char() {
    local char="$1"
    local count="$2"
    local result=""
    for ((i=0; i<count; i++)); do
        result+="$char"
    done
    echo -n "$result"
}

# Global UI width for all boxes and headers
UI_WIDTH=71

# Print a horizontal line with consistent styling
print_hr() {
    local char="${1:-$UI_BORDER_CHAR}"
    local width=${2:-$UI_WIDTH}
    local color="${3:-$COLOR_DIM}"
    if [[ "$char" =~ [═╔╗╚╝║] ]]; then
        echo -e "${color}$(repeat_char "$char" "$width")${COLOR_RESET}"
    else
        echo -e "${color}$(printf "%${width}s" | tr ' ' "$char")${COLOR_RESET}"
    fi
}

# Print a decorative line
print_line() { 
    local width=${1:-$UI_WIDTH}
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        echo -e "${COLOR_DIM}$(printf '%*s' "$width" | tr ' ' '=')${COLOR_RESET}"
    else
        echo -e "${COLOR_DIM}$(repeat_char "═" "$((width))")${COLOR_RESET}"
    fi
}

# Print a thin divider line for subtle section breaks
print_divider_thin() { 
    echo -e "${COLOR_DIM}⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯${COLOR_RESET}"; 
}

# Print a double line for major section divisions
print_double_line() { 
    local width=${1:-$UI_WIDTH}
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        echo -e "${COLOR_BOLD}${COLOR_MAGENTA}$(printf '%*s' "$width" | tr ' ' '=')${COLOR_RESET}"
    else
        echo -e "${COLOR_BOLD}${COLOR_MAGENTA}╔$(repeat_char "═" "$((width-2))")╗${COLOR_RESET}"
    fi
}

# Print a centered text with optional color
print_centered() {
    local text="$1"
    local width=${2:-$UI_WIDTH}
    local color="${3:-}"
    local padding=$(( (width - ${#text}) / 2 ))
    if [[ $padding -lt 0 ]]; then padding=0; fi
    if [[ -n "$color" ]]; then
        printf "%${padding}s%s%${padding}s\n" "" "${color}${text}${COLOR_RESET}" ""
    else
        printf "%${padding}s%s%${padding}s\n" "" "$text" ""
    fi
}

# Print a main section header with decorative box
print_section_header() {
    local title="$1"
    local width=${2:-$UI_WIDTH} # Argument index adjusted as char arg is removed for simplicity
    local ascii_char="="
    local unicode_char="─"
    local h_line_segment

    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        h_line_segment="$(printf '%*s' "$((width-2))" | tr ' ' "$ascii_char")"
    else
        h_line_segment="$(repeat_char "$unicode_char" "$((width-2))")"
    fi
    
    echo
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}╭${h_line_segment}╮${COLOR_RESET}"
    local visible_len=$(strip_ansi "$title" | awk '{print length}')
    local pad_len=$((width-4-visible_len))
    if [ $pad_len -lt 0 ]; then pad_len=0; fi
    printf "${COLOR_BOLD}${COLOR_MAGENTA}│ %s%*s │${COLOR_RESET}\n" "$title" $pad_len ""
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}╰${h_line_segment}╯${COLOR_RESET}"
    echo
}

# Print a secondary header with subtle styling
print_section_subheader() {
    local title="$1"
    local width=${2:-$UI_WIDTH}
    local prefix="─── "
    local suffix=" "
    local visible_len=$(strip_ansi "$title" | awk '{print length}')
    local pad_len=$((width - 4 - ${#prefix} - visible_len - ${#suffix}))
    if [ $pad_len -lt 0 ]; then pad_len=0; fi
    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╭${prefix}${title}${suffix}$(repeat_char "─" $pad_len)╮${COLOR_RESET}"
    echo -e "${COLOR_DIM}╰$(repeat_char "─" $((width-2)))╯${COLOR_RESET}"
}

# Strip ANSI escape codes for visible length calculation
strip_ansi() {
    # Usage: strip_ansi "$string"
    echo -e "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

# Print a stylized message box with proper formatting
print_message_box() {
    local title_param="$1"
    local message="$2"
    local width=${3:-$UI_WIDTH}
    local color=${4:-$COLOR_BLUE}

    local h_char_unicode="─"
    local h_char_ascii="="
    local h_char=$h_char_unicode
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        h_char=$h_char_ascii
    fi

    local horizontal_line_len=$((width - 2))
    local content_area_width=$((width - 4))

    local top_h_segment
    local bottom_h_segment=$(repeat_char "$h_char" "$horizontal_line_len")

    echo # Top margin

    # Top border
    if [ -n "$title_param" ]; then
        local visible_title_len=$(strip_ansi "$title_param" | awk '{print length}')
        # Line is: ╭─ Title ─...─╮. Chars for segment: width - ╭╮ - ─<space> - <space>─ - Title
        local title_segment_len=$((horizontal_line_len - 2 - 1 - visible_title_len))
        if [ $title_segment_len -lt 0 ]; then title_segment_len=0; fi
        top_h_segment=$(repeat_char "$h_char" "$title_segment_len")
        echo -e "${color}╭─ ${COLOR_BOLD}${title_param}${COLOR_RESET}${color} ${top_h_segment}╮${COLOR_RESET}"
    else
        echo -e "${color}╭${bottom_h_segment}╮${COLOR_RESET}"
    fi

    # Message content
    local line_start=0
    local message_len=${#message}
    if [ $message_len -eq 0 ]; then # Handle empty message: print one empty content line
        print_box_row "" "$color" "$width"
    else
        while [ $line_start -lt $message_len ]; do
            # Extract a chunk that visually fits, then get its actual character length for substringing
            local current_chunk=""
            local current_visible_len=0
            local actual_char_count=0
            
            # Greedily build line_text up to content_area_width visible characters
            local temp_line_start=$line_start
            while [ $temp_line_start -lt $message_len ] && [ $current_visible_len -lt $content_area_width ]; do
                # Add one character at a time to handle ANSI codes correctly
                char_and_ansi="${message:$temp_line_start}" # Get rest of string
                # Find the next character or ANSI sequence
                if [[ $char_and_ansi =~ ^(\\[0-9]{3} | \\e\[[0-9;]*[mK] | . ) ]]; then # regex for char or ansi
                    next_segment="${BASH_REMATCH[1]}"
                else # fallback for unusual characters, take one byte
                    next_segment="${message:$temp_line_start:1}"
                fi
                
                current_chunk+="$next_segment"
                current_visible_len=$(strip_ansi "$current_chunk" | awk '{print length}')
                temp_line_start=$((temp_line_start + ${#next_segment}))
                actual_char_count=$((actual_char_count + ${#next_segment}))

                if [ $current_visible_len -gt $content_area_width ]; then # Overshot
                    current_chunk=${current_chunk::$((${#current_chunk} - ${#next_segment}))} # Remove last segment
                    actual_char_count=$((actual_char_count - ${#next_segment}))
                    break
                fi
            done
            local text_to_print="${message:$line_start:$actual_char_count}"
            line_start=$((line_start + actual_char_count))

            local visible_text_len=$(strip_ansi "$text_to_print" | awk '{print length}')
            local padding_needed=$((content_area_width - visible_text_len))
            if [ $padding_needed -lt 0 ]; then padding_needed=0; fi
            local line_padding_spaces=$(printf '%*s' "$padding_needed" '')
            
            echo -e "${color}│ ${text_to_print}${line_padding_spaces} ${color}│${COLOR_RESET}"
        done
    fi

    # Bottom border
    echo -e "${color}╰${bottom_h_segment}╯${COLOR_RESET}"
    echo # Bottom margin
}

# Enhanced print functions with emojis and colors

# Print an info message
print_info() { 
    echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_RESET}"; 
}

# Print a success message
print_success() { 
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"; 
}

# Print a warning message
print_warning() { 
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"; 
}

# Print an error message
print_error() { 
    echo -e "${COLOR_RED}❌ ERROR: $1${COLOR_RESET}"; 
}

# Print a debug message (only shown when DEBUG=true)
print_debug() { 
    if [ -n "${DEBUG+x}" ] && [ "$DEBUG" = "true" ]; then 
        echo -e "${COLOR_GREY}DEBUG: $1${COLOR_RESET}"; 
    fi; 
}

# Print a fatal error message and exit
print_fatal() { 
    echo -e "${COLOR_BOLD}${COLOR_RED}☠️ FATAL: $1${COLOR_RESET}"; 
    exit 1; 
}

# Print a prompt for user input
print_prompt() { 
    echo -ne "${COLOR_CYAN}➡️  $1${COLOR_RESET}"; 
}

# Print a perfectly padded row inside a box
# Usage: print_box_row <content> <box_color> <width>
print_box_row() {
    local content="$1"
    local color="$2"
    local width="${3:-$UI_WIDTH}"
    local content_width=$((width - 4))
    local visible_len=$(strip_ansi "$content" | awk '{print length}')
    local pad_len=$((content_width - visible_len))
    if [ $pad_len -lt 0 ]; then pad_len=0; fi
    local padding_spaces=$(printf '%*s' "$pad_len" '')
    echo -e "${color}║ ${content}${padding_spaces} ║${COLOR_RESET}"
}

# Print a selectable option
print_option() { 
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}[$1]${COLOR_RESET} $2"; 
}

# Print the Leonardo title art with friendly llama mascot
print_leonardo_title_art() {
    local title_text="Leonardo AI USB Maker ✨ - Forge Your Portable AI Future!"
    local box_color="${COLOR_BOLD}${COLOR_GREEN}"
    local internal_border_char_unicode="║"
    local internal_border_char_ascii="||"
    local internal_border_char=$internal_border_char_unicode

    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        internal_border_char=$internal_border_char_ascii
    fi

    # Content width is UI_WIDTH minus 2 for side borders and 2 for internal padding spaces
    local content_width=$((UI_WIDTH - 4))

    # Calculate padding for the title text
    local visible_title_len=$(strip_ansi "$title_text" | awk '{print length}')
    local title_padding_total=$((content_width - visible_title_len))
    local title_padding_left=$((title_padding_total / 2))
    local title_padding_right=$((title_padding_total - title_padding_left))
    if [ $title_padding_total -lt 0 ]; then # text is wider than content area
        title_padding_left=0
        title_padding_right=0
        # Optionally truncate title_text here if it's too long
    fi
    local title_pad_left_spaces=$(printf '%*s' "$title_padding_left" '')
    local title_pad_right_spaces=$(printf '%*s' "$title_padding_right" '')

    # Calculate padding for empty lines
    local empty_line_padding=$(printf '%*s' "$content_width" '')

    echo -e "${box_color}"
    # Top border - print_double_line already handles UI_WIDTH and ASCII/Unicode
    # It prints ╔════...══╗. We need to ensure its color matches.
    # However, print_double_line has its own color (MAGENTA). We'll use print_hr for top/bottom.
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        echo -e "${box_color}$(repeat_char "=" "$UI_WIDTH")${COLOR_RESET}"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        print_box_row "${title_pad_left_spaces}${title_text}${title_pad_right_spaces}    " "$box_color" "$UI_WIDTH"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        echo -e "${box_color}$(repeat_char "=" "$UI_WIDTH")${COLOR_RESET}"
    else
        echo -e "${box_color}╔$(repeat_char "═" "$((UI_WIDTH-1))")╗${COLOR_RESET}"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        print_box_row "${title_pad_left_spaces}${title_text}${title_pad_right_spaces}    " "$box_color" "$UI_WIDTH"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        echo -e "${box_color}╚$(repeat_char "═" "$((UI_WIDTH-1))")╝${COLOR_RESET}"
    fi

    echo -e "${COLOR_RESET}" # Reset color from box_color just in case
    echo "         (\\(\\   "
    echo "         (•ᴗ•)🦙 "
    echo "         / >)_/"
    echo "        \"Let's make an AI USB!\""
    echo ""
    echo -e "  (Brought to you by the Leonardo team)${COLOR_RESET}"
    echo ""
}

# Print success art when an operation completes successfully
print_leonardo_success_art() {
    echo -e "${COLOR_BOLD}${COLOR_GREEN}"
    echo ""
    echo "           (\\(\\   "
    echo "           (•ᴖ•)🦙  "
    echo "           / >💾 USB "
    echo "          \"Forge Complete!\""
    echo ""
    echo "    🚀 Congratulations! Your Leonardo AI USB is Forged & Ready! 🚀"
    echo -e "${COLOR_RESET}"
}

# Print an animated notification box with different styles
print_notification_box() {
    local message="$1"
    local type="${2:-info}"  # info, success, warning, error
    local width=${3:-$UI_WIDTH}
    local box_width=$((width - 8))
    local color
    local icon
    local title
    local h_char_unicode="─"
    local h_char_ascii="="
    local top_line_segment
    local bottom_line_segment

    # Set color and icon based on notification type
    case "$type" in
        success)
            color="$COLOR_GREEN"
            icon="✅"
            title="SUCCESS"
            ;;
        warning)
            color="$COLOR_YELLOW"
            icon="⚠️"
            title="WARNING"
            ;;
        error)
            color="$COLOR_RED"
            icon="❌"
            title="ERROR"
            ;;
        *) # Default is info
            color="$COLOR_BLUE"
            icon="ℹ️"
            title="INFO"
            ;;
    esac

    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        top_line_segment="$(printf '%*s' $((box_width - ${#title} - 6)) | tr ' ' "$h_char_ascii")"
        bottom_line_segment="$(printf '%*s' $((box_width)) | tr ' ' "$h_char_ascii")"
    else
        top_line_segment="$(repeat_char "$h_char_unicode" "$((box_width - ${#title} - 6))")"
        bottom_line_segment="$(repeat_char "$h_char_unicode" "$((box_width))")"
    fi
    
    # Print the notification box
    echo
    # Top border with title
    echo -e "${color}╭──── ${COLOR_BOLD}$title${COLOR_RESET} ${color}${top_line_segment}╮${COLOR_RESET}"
    
    # Message line with icon
    local msg_line="${icon} ${message}"
    print_box_row "$msg_line" "$color" "$width"
    
    # Bottom border
    echo -e "${color}╰${bottom_line_segment}╯${COLOR_RESET}"
    echo
}

# Print a fancy gradient divider
print_gradient_divider() {
    local width=${1:-$UI_WIDTH}
    local char
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        char="="
        # ASCII fallback is single-byte, safe for printf/tr
        echo -e "${COLOR_GRADIENT_1}$(printf '%*s' $((width/4)) | tr ' ' "$char")${COLOR_GRADIENT_2}$(printf '%*s' $((width/4)) | tr ' ' "$char")${COLOR_GRADIENT_3}$(printf '%*s' $((width/4)) | tr ' ' "$char")${COLOR_GRADIENT_4}$(printf '%*s' $((width/4 + width%4)) | tr ' ' "$char")${COLOR_RESET}"
    else
        char="═"
        # Unicode: use repeat_char for each segment
        local q1=$((width/4))
        local q2=$((width/4))
        local q3=$((width/4))
        local q4=$((width/4 + width%4))
        echo -e "${COLOR_GRADIENT_1}$(repeat_char "$char" "$q1")${COLOR_GRADIENT_2}$(repeat_char "$char" "$q2")${COLOR_GRADIENT_3}$(repeat_char "$char" "$q3")${COLOR_GRADIENT_4}$(repeat_char "$char" "$q4")${COLOR_RESET}"
    fi
}

# Print a task completion status box
print_task_status() {
    local task="$1"
    local status="$2" # success, warning, error, pending
    local width=${3:-$UI_WIDTH}
    local box_width=$((width - 4))
    local status_color
    local status_icon
    local status_text
    
    # Set color and icon based on status
    case "$status" in
        success)
            status_color="$COLOR_GREEN"
            status_icon="✅"
            status_text="COMPLETED"
            ;;
        warning)
            status_color="$COLOR_YELLOW"
            status_icon="⚠️"
            status_text="WARNING"
            ;;
        error)
            status_color="$COLOR_RED"
            status_icon="❌"
            status_text="FAILED"
            ;;
        pending)
            status_color="$COLOR_CYAN"
            status_icon="⏳"
            status_text="PENDING"
            ;;
        *) # Default is pending
            status_color="$COLOR_CYAN"
            status_icon="⏳"
            status_text="PENDING"
            ;;
    esac
    
    # Print the status box
    echo -e "${COLOR_DIM}┌$(printf '%*s' $((box_width)) | tr ' ' '─')┐${COLOR_RESET}"
    printf "${COLOR_DIM}│ %-$((box_width - 15))s${COLOR_RESET} ${status_color}$status_icon $status_text${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET}\n" "$task"
    echo -e "${COLOR_DIM}└$(printf '%*s' $((box_width)) | tr ' ' '─')┘${COLOR_RESET}"
}

# Clear the screen and show the Leonardo title art
clear_screen_and_show_art() {
    # Use tput if available, otherwise use clear command
    if [ -n "$TPUT_CMD_PATH" ] && [ "$TPUT_CLEAR_POSSIBLE" = true ]; then
        "$TPUT_CMD_PATH" clear
    else
        clear
    fi
    print_leonardo_title_art
}

# Display a data destruction warning screen with intense llama warning
show_data_destruction_warning() {
    local device="$1"
    local operation="${2:-format}"
    
    clear_screen_and_show_art
    
    # Show the warning box with red border and intense llama
    echo -e "${COLOR_RED}╭───────────────── ${COLOR_BOLD}⚠️ DATA DESTRUCTION WARNING ⚠️${COLOR_RESET} ${COLOR_RED}────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  ${COLOR_BOLD}${COLOR_RED}(ಠ‿ಠ)🦙 ALL DATA ON THIS DEVICE WILL BE DESTROYED!${COLOR_RESET}  ${COLOR_RED}│${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  Device: ${COLOR_BOLD}$device${COLOR_RESET}                               ${COLOR_RED}│${COLOR_RESET}"
    echo -e "${COLOR_RED}│  Operation: ${COLOR_BOLD}$operation${COLOR_RESET}                         ${COLOR_RED}│${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  This operation cannot be undone. All data on the selected   │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  device will be permanently erased.                           │${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo
    print_warning "Please make sure you have selected the correct device!"
    echo
}

# Show script header with version information
show_header() {
    if [ "$QUIET" != true ]; then
        clear_screen_and_show_art
        print_info "Version: $SCRIPT_VERSION"
        print_info "Log file: $LOG_FILE"
        [ "$DRY_RUN" = true ] && print_warning "DRY RUN MODE: No changes will be made"
        echo
    fi
}

# Show help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help       Show this help message and exit
  -v, --verbose    Enable verbose output
  -q, --quiet      Suppress non-error output
  --dry-run        Don't make any changes, just show what would be done
  --force          Skip confirmation prompts
  --no-color       Disable colored output

Examples:
  # Run in interactive mode
  sudo ./$(basename "$0")
  
  # Run with verbose output
  sudo ./$(basename "$0") -v
  
  # Perform a dry run
  sudo ./$(basename "$0") --dry-run
EOF
}



# ==============================================================================
# Component: 02_ui/interactive.sh
# ==============================================================================
# ==============================================================================
# Interactive UI Components

# UI helpers are sourced by the main assembly script
# ==============================================================================

# Show a beautiful progress bar with gradient colors
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-}"
    local width=40
    local percent=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    # Build the progress bar with gradient colors
    local progress_bar="${COLOR_BOLD}["
    
    # Use different gradient colors based on completion percentage
    if [ $percent -lt 25 ]; then
        progress_bar+="${COLOR_GRADIENT_1}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    elif [ $percent -lt 50 ]; then
        progress_bar+="${COLOR_GRADIENT_2}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    elif [ $percent -lt 75 ]; then
        progress_bar+="${COLOR_GRADIENT_3}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    else
        progress_bar+="${COLOR_GRADIENT_4}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    fi
    
    progress_bar+="${COLOR_DIM}$(printf '%*s' $remaining | tr ' ' '□')${COLOR_RESET}"
    progress_bar+="${COLOR_BOLD}]${COLOR_RESET} ${COLOR_BOLD}${COLOR_CYAN}$percent%${COLOR_RESET}"
    
    # Add message if provided
    if [ -n "$message" ]; then
        progress_bar+=" $message"
    fi
    
    # Print the progress bar
    printf "\r%-80s" "$progress_bar"
    
    # If complete, print a newline
    if [ $current -ge $total ]; then
        echo
    fi
}

# Show an animated spinner with enhanced visuals
show_spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local colors=("${COLOR_GRADIENT_1}" "${COLOR_GRADIENT_2}" "${COLOR_GRADIENT_3}" "${COLOR_GRADIENT_4}")
    local color_index=0
    
    # Hide the cursor if tput is available
    if [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" civis 2>/dev/null || true
    fi
    
    # Start the spinner
    while ps -p $pid >/dev/null 2>&1; do
        for frame in "${frames[@]}"; do
            # Rotate through colors for a gradient effect
            local current_color="${colors[$color_index]}"
            color_index=$(( (color_index + 1) % ${#colors[@]} ))
            
            # Display the spinner with current color and message
            printf "\r${current_color}%s${COLOR_RESET} %s" "$frame" "$message"
            sleep $delay
        done
    done
    
    # Show the cursor again if tput is available
    if [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" cnorm 2>/dev/null || true
    fi
    
    # Clear the spinner line
    printf "\r%-80s\r" " "
}

# Run a command with a spinner
run_with_spinner() {
    local cmd="$1"
    local message="${2:-Running command...}"
    
    # Start the command in the background
    eval "$cmd" &
    local cmd_pid=$!
    
    # Show spinner while command runs
    show_spinner "$cmd_pid" "$message"
    
    # Wait for command to finish and get its exit code
    wait "$cmd_pid"
    local exit_code=$?
    
    echo ""
    return "$exit_code"
}

# Ask user a yes/no/quit question with styling
ask_yes_no_quit() {
    local message="$1"
    local result_var_name="$2"
    local default_choice="${3:-no}"
    local show_quit="${4:-false}"
    local choice
    
    # Format prompt based on default
    local prompt_options
    if [[ "$default_choice" == "yes" ]]; then
        prompt_options="[${COLOR_GREEN}Y${COLOR_RESET}/n${show_quit:+/q}]"
    elif [[ "$default_choice" == "no" ]]; then
        prompt_options="[y/${COLOR_RED}N${COLOR_RESET}${show_quit:+/q}]"
    else
        prompt_options="[y/n${show_quit:+/${COLOR_MAGENTA}Q${COLOR_RESET}}]"
    fi
    
    while true; do
        echo -ne "${COLOR_YELLOW}$message $prompt_options ${COLOR_RESET}"
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        
        # Use default if empty input
        if [ -z "$choice" ]; then choice="$default_choice"; fi
        
        case "$choice" in
            y|yes) 
                eval "$result_var_name=\"yes\""
                return 0 ;;
            n|no) 
                eval "$result_var_name=\"no\""
                return 0 ;;
            q|quit)
                if [ "$show_quit" = "true" ]; then
                    eval "$result_var_name=\"quit\""
                    return 0
                else
                    echo -e "${COLOR_YELLOW}Please answer with 'y' or 'n'.${COLOR_RESET}"
                fi ;;
            *) echo -e "${COLOR_YELLOW}Please answer with 'y' or 'n'.${COLOR_RESET}" ;;
        esac
    done
}

# Get confirmation from user with improved styling and llama progression
confirm() {
    local message="$1"
    local default="${2:-n}"
    local severity="${3:-normal}"
    local choice
    local llama_emoji
    
    # Force mode - skip confirmation
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    # Use the appropriate llama based on severity level as per memory
    case "$severity" in
        normal)
            # Friendly llama for normal operations
            llama_emoji="${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET}"
            ;;
        caution)
            # Mischievous winking llama for first level caution
            llama_emoji="${COLOR_YELLOW}(>‿-)🦙${COLOR_RESET}"
            ;;
        warning)
            # Intense/crazy-eyed llama for serious warnings
            llama_emoji="${COLOR_RED}(ಠ‿ಠ)🦙${COLOR_RESET}"
            ;;
        *)
            llama_emoji="${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET}"
            ;;
    esac
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -ne "$llama_emoji $message [${COLOR_GREEN}Y${COLOR_RESET}/n] " >&2
            read -r choice
            choice=${choice:-y}
        else
            echo -ne "$llama_emoji $message [y/${COLOR_RED}N${COLOR_RESET}] " >&2
            read -r choice
            choice=${choice:-n}
        fi
        
        case "${choice,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo -e "${COLOR_YELLOW}Please answer with 'yes' or 'no'.${COLOR_RESET}" >&2 ;;
        esac
    done
}

# Show a menu of options with enhanced styling
show_menu() {
    local dialog_title="$1"
    local menu_text="$2"
    shift 2
    local menu_options=("$@")
    local choice
    local result_var_name="_menu_choice"
    
    echo -e "\n${COLOR_BOLD}${COLOR_CYAN}╭─── $dialog_title ${COLOR_DIM}─────────────────────────────────────────────╮${COLOR_RESET}"
    if [ -n "$menu_text" ]; then
        echo -e "${COLOR_CYAN}│ ${COLOR_RESET}${menu_text}${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│ ${COLOR_DIM}....................................................................${COLOR_RESET}"
    fi
    
    local option_num=1
    for option in "${menu_options[@]}"; do
        printf "${COLOR_CYAN}│  ${COLOR_BOLD}%s)${COLOR_RESET} %-60s ${COLOR_CYAN}│${COLOR_RESET}\n" "$option_num" "$option"
        option_num=$((option_num + 1))
    done
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╰────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    
    # Get user choice
    while true; do
        print_prompt "Enter your choice (1-$((option_num-1))): "
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((option_num-1)) ]; then
            return $((choice - 1))
        else
            print_warning "Invalid input. Please try again."
        fi
    done
}

# Show a help screen with useful information
show_help_screen() {
    clear_screen_and_show_art
    
    print_section_header "Leonardo AI USB Maker - Help" $UI_WIDTH
    
    # Print the help content in a nicely formatted box
    echo -e "${COLOR_CYAN}╭$(repeat_char "─" $((UI_WIDTH-2)))╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_BOLD}GETTING STARTED:${COLOR_RESET}                                           ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• To create a new Leonardo AI USB, select option 1 from menu.   ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• You'll need an empty USB drive (min. 8GB recommended).       ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• All data on the selected USB will be erased during setup.    ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                 │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_BOLD}ADDING AI MODELS:${COLOR_RESET}                                         ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• Select option 2 to add AI models to an existing Leonardo USB. ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• The USB must be formatted with the Leonardo file structure.  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                 │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_BOLD}USB HEALTH:${COLOR_RESET}                                                ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• Option 3 scans your USB for errors and performance issues.  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• Regular health checks ensure optimal AI model performance.   ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰$(repeat_char "─" $((UI_WIDTH-2)))╯${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}(>‿-)🦙${COLOR_RESET} ${COLOR_DIM}Pro tip: Using exFAT filesystem provides the best cross-platform compatibility.${COLOR_RESET}"
    
    echo -e "\nPress any key to return to the main menu..."
    read -n 1 -s
}

# Show main menu with enhanced visual design
show_main_menu() {
    show_header
    
    # Print fancy gradient divider
    print_gradient_divider
    
    # Menu title with visual styling
    echo -e "\n${COLOR_BOLD}${COLOR_GRADIENT_2}⚡ Leonardo AI USB Maker - Main Menu ⚡${COLOR_RESET}\n"
    
    # Box containing the menu options with icons and visual styling
    local menu_box_width=$((UI_WIDTH - 2))
    echo -e "${COLOR_CYAN}╭$(repeat_char "─" $menu_box_width)╮${COLOR_RESET}"

    # Data-driven menu items: (number, icon, label, description, color)
    local menu_items=(
        "1|💾|Create New USB|Format and set up a new USB drive|${COLOR_BOLD}${COLOR_GREEN}"
        "2|🧠|Add AI Model to USB|Install AI models to existing USB|${COLOR_BOLD}${COLOR_GREEN}"
        "3|🔍|Verify USB Health|Check USB drive for issues|${COLOR_BOLD}${COLOR_GREEN}"
        "4|📜|Download History|View your download history|${COLOR_BOLD}${COLOR_GREEN}"
        "5|ℹ️ |About|About this script and usage guide|${COLOR_BOLD}${COLOR_GREEN}"
        "6|🚪|Exit|Exit the program|${COLOR_BOLD}${COLOR_RED}"
    )

    # Calculate max left segment width (number, icon, label)
    local max_left_len=0
    local left_segments=()
    for item in "${menu_items[@]}"; do
        IFS='|' read -r num icon label desc color <<< "$item"
        local left="  ${color}${num})${COLOR_RESET} ${icon} ${color}${label}${COLOR_RESET}"
        left_segments+=("$left")
        local plain_left=$(strip_ansi "$left")
        local len=${#plain_left}
        if [ $len -gt $max_left_len ]; then max_left_len=$len; fi
    done

    # Helper to print padded menu lines
    print_menu_line() {
        local left="$1"
        local desc="$2"
        local width="$((menu_box_width+2))"
        local content_width=$((width - 4))
        local plain_left=$(strip_ansi "$left")
        local pad_len=$((max_left_len - ${#plain_left}))
        if [ $pad_len -lt 0 ]; then pad_len=0; fi
        local left_padded="$left$(printf '%*s' "$pad_len" '')"
        # Add a consistent gap between left segment and dash
        local content="$left_padded  -  $desc"
        local visible_len=$(strip_ansi "$content" | awk '{print length}')
        local right_pad=$((content_width - visible_len))
        if [ $right_pad -lt 0 ]; then right_pad=0; fi
        local padding_spaces=$(printf '%*s' "$right_pad" '')
        echo -e "${COLOR_CYAN}│ ${COLOR_RESET}${content}${padding_spaces}${COLOR_CYAN} │${COLOR_RESET}"
    }

    # Render menu
    for i in "${!menu_items[@]}"; do
        IFS='|' read -r num icon label desc color <<< "${menu_items[$i]}"
        print_menu_line "${left_segments[$i]}" "$desc"
    done


    echo -e "${COLOR_CYAN}╰$(repeat_char "─" $menu_box_width)╯${COLOR_RESET}"
    
    # Friendly llama mascot offering help
    echo -e "\n${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET} ${COLOR_DIM}Need help? Type 'help' or '?' for more information.${COLOR_RESET}\n"
    
    # Get user choice
    local choice
    while true; do
        print_prompt "Enter your selection (1-6): "
        read choice
        
        # Handle special inputs
        if [[ "$choice" == "help" ]] || [[ "$choice" == "?" ]]; then
            show_help_screen
            show_main_menu
            return $?
        fi
        
        # Process regular menu choices
        case "$choice" in
            1) return 0 ;; # Create New USB Drive
            2) return 1 ;; # Add AI Model to USB
            3) return 2 ;; # Verify USB Health
            4) return 3 ;; # View Download History
            5) return 4 ;; # About
            6) return 5 ;; # Exit
            *) print_warning "Invalid selection. Please enter a number between 1 and 6." ;;
        esac
    done
}
# Show about screen with enhanced visual styling
show_about() {
    clear_screen_and_show_art
    
    # Print fancy gradient divider
    print_gradient_divider
    
    # About title with visual styling
    print_section_header "About Leonardo AI USB Maker" $UI_WIDTH
    
    # Show the about content in a stylized box
    echo -e "${COLOR_GRADIENT_1}╭$(repeat_char "─" $((UI_WIDTH-2)))╮${COLOR_RESET}"
    
    # About content with beautiful formatting
    echo -e "${COLOR_GRADIENT_1}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_1}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_1}│${COLOR_RESET}  ${COLOR_BOLD}Leonardo AI USB Maker${COLOR_RESET} - Forge Your Portable AI Future!      ${COLOR_GRADIENT_1}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_1}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_1}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_2}│${COLOR_RESET}  Version: ${COLOR_BOLD}$SCRIPT_VERSION${COLOR_RESET}                                     ${COLOR_GRADIENT_2}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_2}│${COLOR_RESET}  Build Date: ${COLOR_BOLD}$(date +"%B %Y")${COLOR_RESET}                                ${COLOR_GRADIENT_2}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_2}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_2}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}  A powerful tool for creating bootable USB drives with AI models  ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}  and tools. Easily setup a portable AI environment that works     ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}  across multiple operating systems.                              ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}  Supported Models: ${COLOR_BOLD}Leonardo GPT, NexusAI, AstroLLM${COLOR_RESET}             ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}  Supported Filesystems: ${COLOR_BOLD}exFAT, NTFS, EXT4${COLOR_RESET}                    ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}  ${COLOR_BOLD}© $(date +%Y) Leonardo AI Team${COLOR_RESET}                                ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}╰$(repeat_char "─" $((UI_WIDTH-2)))╯${COLOR_RESET}"
    
    # Show friendly llama mascot
    echo -e "\n${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET} ${COLOR_DIM}Thank you for using Leonardo AI USB Maker!${COLOR_RESET}"
    
    echo -e "\n${COLOR_BOLD}${COLOR_CYAN}Press any key to return to the main menu...${COLOR_RESET}"
    read -n 1 -s
}



# ==============================================================================
# Component: 02_ui/progress.sh
# ==============================================================================
#!/bin/bash
# ==============================================================================
# Operation Progress UI Components
# ==============================================================================

# Operation progress tracking variables
OPERATION_PROGRESS=0
OPERATION_TOTAL=100
OPERATION_STATUS="pending"
OPERATION_MESSAGE=""
OPERATION_START_TIME=0
OPERATION_NAME=""

# Initialize a new operation progress tracker
init_operation_progress() {
    local name="$1"
    local total="${2:-100}"
    
    OPERATION_NAME="$name"
    OPERATION_PROGRESS=0
    OPERATION_TOTAL="$total"
    OPERATION_STATUS="running"
    OPERATION_MESSAGE="Starting operation: $name"
    OPERATION_START_TIME=$(date +%s)
    
    # Log the start of the operation
    log "Starting operation: $name"
}

# Update the operation progress
update_operation_progress() {
    local progress="$1"
    local message="${2:-}"
    
    # Ensure progress is within bounds
    if [ "$progress" -lt 0 ]; then
        progress=0
    elif [ "$progress" -gt "$OPERATION_TOTAL" ]; then
        progress="$OPERATION_TOTAL"
    fi
    
    OPERATION_PROGRESS="$progress"
    
    if [ -n "$message" ]; then
        OPERATION_MESSAGE="$message"
        log "$message"
    fi
    
    # Calculate percentage
    local percent=$((OPERATION_PROGRESS * 100 / OPERATION_TOTAL))
    
    # Update the operation status based on progress
    if [ "$percent" -eq 100 ]; then
        OPERATION_STATUS="complete"
    fi
}

# Complete the operation with a status
complete_operation() {
    local status="${1:-success}"  # success, warning, error
    local message="${2:-Operation complete.}"
    
    OPERATION_PROGRESS="$OPERATION_TOTAL"
    OPERATION_STATUS="$status"
    OPERATION_MESSAGE="$message"
    
    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - OPERATION_START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    
    # Log completion
    log "Operation complete: $OPERATION_NAME (Status: $status, Time: ${minutes}m ${seconds}s)"
    log "$message"
}

# Display the current operation progress screen
show_operation_progress() {
    local title="${1:-$OPERATION_NAME}"
    local show_time="${2:-true}"
    
    # Clear the screen and show header
    clear_screen_and_show_art
    
    # Show operation title
    print_section_header "$title"
    
    # Calculate percentage and elapsed time
    local percent=$((OPERATION_PROGRESS * 100 / OPERATION_TOTAL))
    local current_time=$(date +%s)
    local elapsed=$((current_time - OPERATION_START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    
    # Show progress information
    echo -e "  ${COLOR_BOLD}Progress:${COLOR_RESET} $percent% complete"
    if [ "$show_time" = true ]; then
        echo -e "  ${COLOR_BOLD}Elapsed:${COLOR_RESET} ${minutes}m ${seconds}s"
    fi
    echo -e "  ${COLOR_BOLD}Status:${COLOR_RESET} $OPERATION_MESSAGE"
    echo
    
    # Show progress bar
    show_progress "$OPERATION_PROGRESS" "$OPERATION_TOTAL"
    echo
    
    # Show appropriate status icon
    case "$OPERATION_STATUS" in
        success)
            print_success "Operation completed successfully!"
            ;;
        warning)
            print_warning "Operation completed with warnings."
            ;;
        error)
            print_error "Operation failed."
            ;;
        complete)
            print_success "Operation completed!"
            ;;
        *)
            # Show a spinner for running operations
            echo -en "  ${COLOR_CYAN}⟳${COLOR_RESET} Operation in progress..."
            ;;
    esac
}

# Run an operation with progress tracking
run_with_progress() {
    local cmd="$1"
    local name="${2:-Running operation}"
    local total="${3:-100}"
    
    # Initialize progress
    init_operation_progress "$name" "$total"
    
    # Create a temporary file for progress updates
    local progress_file
    progress_file=$(mktemp -p "${TMP_DIR:-/tmp}" leonardo_progress_XXXXXX)
    
    # Run the command in the background
    (
        # Run the command
        if eval "$cmd" > "${progress_file}.log" 2>&1; then
            # Command succeeded
            echo "100|Operation completed successfully." > "$progress_file"
        else
            # Command failed
            echo "error|Operation failed with status $?." > "$progress_file"
        fi
    ) &
    local cmd_pid=$!
    
    # Show progress while command runs
    while ps -p $cmd_pid >/dev/null 2>&1; do
        # Check for progress updates
        if [ -f "$progress_file" ]; then
            local update
            update=$(cat "$progress_file")
            
            if [[ "$update" == error* ]]; then
                # Extract error message
                local error_msg="${update#error|}"
                complete_operation "error" "$error_msg"
                show_operation_progress
                break
            elif [[ "$update" =~ ^[0-9]+\|.* ]]; then
                # Extract progress and message
                local prog="${update%%|*}"
                local msg="${update#*|}"
                update_operation_progress "$prog" "$msg"
            fi
        fi
        
        # Show progress screen
        show_operation_progress
        
        # Brief pause to reduce CPU usage
        sleep 0.5
    done
    
    # Wait for command to finish and get exit code
    wait "$cmd_pid"
    local exit_code=$?
    
    # Final update
    if [ "$exit_code" -eq 0 ]; then
        if [ "$OPERATION_STATUS" != "error" ]; then
            complete_operation "success" "Operation completed successfully!"
        fi
    else
        complete_operation "error" "Operation failed with exit code $exit_code."
    fi
    
    # Show final progress
    show_operation_progress
    
    # Clean up
    rm -f "$progress_file" "${progress_file}.log"
    
    # Return command exit code
    return "$exit_code"
}

# Display a success screen with llama celebration
show_success_screen() {
    local title="$1"
    local message="$2"
    
    # Clear screen and show success art
    clear
    print_leonardo_success_art
    
    # Show success message
    print_section_header "$title"
    echo
    echo -e "  ${COLOR_BOLD}${message}${COLOR_RESET}"
    echo
    
    # Show animated confetti (simulated with characters)
    for i in {1..3}; do
        clear_line() {
            echo -ne "\033[2K\r"
        }
        
        for j in {1..5}; do
            symbols=("🎉" "🎊" "✨" "🎈" "🎆" "🎇")
            
            # Print random confetti
            clear_line
            for k in {1..20}; do
                random_symbol=${symbols[$((RANDOM % ${#symbols[@]}))]}
                random_color=$((RANDOM % 7 + 31))  # 31-37 ANSI colors
                echo -ne "\e[${random_color}m$random_symbol\e[0m "
            done
            sleep 0.2
        done
    done
    echo
    echo
    
    # Display completion message
    echo -e "  ${COLOR_BOLD}${COLOR_GREEN}Press any key to continue...${COLOR_RESET}"
    read -n 1 -s
}



# ==============================================================================
# Component: 02_ui/goodbye.sh
# ==============================================================================
#!/bin/bash
# ==============================================================================
# Goodbye Screen for Leonardo AI USB Maker
# ==============================================================================

# Display a friendly goodbye screen with llama mascot
show_goodbye_screen() {
    clear_screen_and_show_art
    
    # Print gradient divider
    print_gradient_divider
    
    # Goodbye box with farewell message
    echo -e "${COLOR_CYAN}╭──────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│  ${COLOR_BOLD}${COLOR_GRADIENT_2}Thank you for using Leonardo AI USB Maker!${COLOR_RESET}                 ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│  We hope you enjoyed forging your portable AI future with us.    │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│  If you found this tool helpful, please consider:                │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   • Starring our repository on GitHub                            │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   • Reporting any issues you encountered                         │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   • Sharing with fellow AI enthusiasts                           │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    
    # Show happy llama mascot waving goodbye
    echo ""
    echo -e "           ${COLOR_YELLOW}(•ᴗ•)/ 🦙${COLOR_RESET}"
    echo -e "           ${COLOR_DIM}Farewell, AI explorer!${COLOR_RESET}"
    echo ""
    
    # Final message with a touch of humor
    echo -e "${COLOR_GRADIENT_1}May your AI models run smoothly and your USB drives remain uncorrupted!${COLOR_RESET}"
    echo ""
    
    # Pause briefly to allow reading the message
    sleep 2
}

# Exit the application gracefully
exit_application() {
    show_goodbye_screen
    log "User exited the application"
    exit 0
}



# ==============================================================================
# Component: 03_filesystem/device.sh
# ==============================================================================
# ==============================================================================
# Filesystem Device Operations
# ==============================================================================

# Global arrays to store discovered USB device paths and their display strings
_CASCADE_USB_PATHS=()
_CASCADE_USB_DISPLAY_STRINGS=()

# Check if a given path is a block device
# Returns 0 if it's a block device, 1 otherwise.
# This version includes multiple verification methods for robustness.
is_block_device() {
    local device_path="$1"
    
    # Debug output to verify function is called with correct arguments
    # echo "DEBUG: is_block_device() called with: '$device_path'" >&2
    
    # Check for empty input
    if [ -z "$device_path" ]; then
        # echo "DEBUG: is_block_device: Empty device path provided" >&2
        return 1
    fi
    
    # Clean up the device path - remove any surrounding whitespace or quotes
    device_path=$(echo "$device_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Add /dev/ prefix if not present and it looks like a device name
    if [[ ! "$device_path" =~ ^/dev/ ]] && [[ "$device_path" =~ ^[sh]d[a-z]|nvme[0-9]n[0-9]|mmcblk[0-9] ]]; then
        device_path="/dev/$device_path"
        # echo "DEBUG: Added /dev/ prefix, now: '$device_path'" >&2
    fi
    
    # Debug output for final path being checked
    # echo "DEBUG: is_block_device: Testing path: '$device_path'" >&2
    
    # Method 1: Direct block device test
    if [ -b "$device_path" ]; then
        # echo "DEBUG: is_block_device: PASSED -b test for '$device_path'" >&2
        return 0  # Success - it's a block device
    else
        # echo "DEBUG: is_block_device: FAILED -b test for '$device_path'" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Method 2: Check using ls -l (looks for 'b' as first character)
    if ls -l "$device_path" 2>/dev/null | grep -q '^b'; then
        # echo "DEBUG: is_block_device: PASSED ls -l test for '$device_path'" >&2
        return 0  # Success - it's a block device
    else
        # echo "DEBUG: is_block_device: FAILED ls -l test for '$device_path'" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Method 3: Check using stat if available
    if command -v stat >/dev/null 2>&1; then
        if stat -c '%F' "$device_path" 2>/dev/null | grep -q 'block special'; then
            # echo "DEBUG: is_block_device: PASSED stat test for '$device_path'" >&2
            return 0  # Success - it's a block device
        else
            # echo "DEBUG: is_block_device: FAILED stat test for '$device_path'" >&2
            : # No-op for potentially sensitive parsers
        fi
    fi
    
    # Method 4: Check if it's a partition of a block device
    local parent_dev
    parent_dev=$(echo "$device_path" | sed -E 's/[0-9]+$//' | sed -E 's/p[0-9]+$//')
    
    if [ "$parent_dev" != "$device_path" ] && [ -b "$parent_dev" ]; then
        # echo "DEBUG: is_block_device: '$device_path' appears to be a partition of block device '$parent_dev'" >&2
        return 0  # Accept partitions of block devices
    else
        # echo "DEBUG: is_block_device: Not a partition of a block device" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Method 5: Check if device exists in /sys/block or as a partition
    local basename
    basename=$(basename "$device_path")
    
    if [ -e "/sys/block/$basename" ] || 
       [ -e "/sys/block/$(echo "$basename" | sed 's/[0-9]*$//')/$(echo "$basename" | sed 's/^[^0-9]*//')" ]; then
        # echo "DEBUG: is_block_device: Found in /sys/block for '$device_path'" >&2
        return 0  # It exists in sysfs
    else
        # echo "DEBUG: is_block_device: Not found in /sys/block for '$device_path'" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # If we get here, all checks have failed
    # echo "DEBUG: is_block_device: FINAL RESULT - NOT a block device: '$device_path'" >&2
    return 1  # Failure - not a block device by any test
}

# Get the size of a block device in bytes
# Expects a validated block device path (e.g., /dev/sdb)
get_block_device_size() {
    local device_path="$1"
    if ! is_block_device "$device_path"; then # Re-validate just in case
        print_error "get_block_device_size: '$device_path' is not a valid block device." >&2
        return 1
    fi
    blockdev --getsize64 "$device_path" 2>/dev/null || {
        print_error "get_block_device_size: Failed to get size for '$device_path'." >&2
        return 1
    }
    return 0
}

# Get the filesystem type of a device or partition
# Expects a validated block device or partition path (e.g., /dev/sdb or /dev/sdb1)
get_fs_type() {
    local device_path="$1"
    # is_block_device also accepts partitions of block devices
    if ! is_block_device "$device_path"; then # Re-validate
        print_error "get_fs_type: '$device_path' is not a valid block device or partition." >&2
        return 1
    fi
    lsblk -no FSTYPE "$device_path" 2>/dev/null || {
        print_error "get_fs_type: Failed to get filesystem type for '$device_path'." >&2
        return 1
    }
    return 0
}

# List available USB/removable devices and populate global arrays.
list_usb_devices() {
    # If we're using the enhanced device selection UI, don't show the old UI
    if [ "$SKIP_DEVICE_SELECTION" = "true" ] && [ -n "$LEONARDO_DEVICE_PATH" ]; then
        # echo "DEBUG: Skipping duplicate device selection UI" >&2
        print_info "Using previously selected device: $LEONARDO_DEVICE_PATH"
        return 0
    fi

    # UI elements removed - select_usb_device will handle UI presentation
    # clear_screen_and_show_art
    # 
    # local box_width=$((UI_WIDTH - 8))
    # local step_text="STEP 1 OF 4: SELECT USB DEVICE"
    # local padding=$(( (box_width - ${#step_text}) / 2 ))
    # 
    # echo -e "${COLOR_CYAN}╔$(repeat_char "═" $((box_width + 2)))╗${COLOR_RESET}"
    # 
    # echo -e "${COLOR_CYAN}║${COLOR_RESET}$(repeat_char " " $padding)${COLOR_BOLD}${COLOR_YELLOW}${step_text}${COLOR_RESET}$(repeat_char " " $((box_width - padding - ${#step_text} + 2)))${COLOR_CYAN}║${COLOR_RESET}"
    # 
    # echo -e "${COLOR_CYAN}╚$(repeat_char "═" $((box_width + 2)))╝${COLOR_RESET}\n"
    
    # Initialize arrays
    _CASCADE_USB_PATHS=()
    _CASCADE_USB_DISPLAY_STRINGS=()
    
    # print_info "Scanning for USB/removable storage devices..." # Moved to select_usb_device
    
    # Check if we have root privileges for better device detection
    local has_root=0
    if [ "$(id -u)" -eq 0 ]; then
        has_root=1
        # echo "DEBUG: Running with root privileges" >&2
    else
        # echo "DEBUG: Running without root privileges (some devices might not be detected)" >&2
        : # No-op for potentially sensitive parsers
    fi
    
    # Try different methods to detect USB/removable devices
    local device_list=""
    
    # Method 1: Try lsblk with JSON output (most reliable)
    if command -v lsblk >/dev/null 2>&1; then
        # echo "DEBUG: Trying lsblk method..." >&2
        
        # Check if lsblk supports --json
        if lsblk --help 2>&1 | grep -q -- '--json'; then
            # echo "DEBUG: lsblk supports JSON output" >&2
            
            # Get device list with all needed info
            local lsblk_output
            lsblk_output=$(lsblk -d -J -o NAME,SIZE,MODEL,VENDOR,TRAN,RM,MOUNTPOINT,LABEL,FSTYPE,UUID 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$lsblk_output" ]; then
                # Use jq to parse JSON if available
                if command -v jq >/dev/null; then
                    # echo "DEBUG: Using jq to parse lsblk JSON output" >&2
                    
                    # Process each device
                    local device_count=$(echo "$lsblk_output" | jq -r '.blockdevices | length' 2>/dev/null)
                    # echo "DEBUG: Found $device_count block devices" >&2
                    
                    for ((i=0; i<device_count; i++)); do
                        local dev_info
                        dev_info=$(echo "$lsblk_output" | jq -r ".blockdevices[$i] | \
                            [.name, .size // "unknown", .model // "Unknown", .tran // "unknown", 
                            .rm // "0", .mountpoint // "", .label // "", .fstype // "", .uuid // ""] | @tsv" 2>/dev/null)
                        
                        if [ -z "$dev_info" ]; then
                            continue
                        fi
                        
                        IFS=$'\t' read -r dev size model tran rm_flag mountpoint label fstype uuid <<< "$dev_info"
                        
                        # Skip if no device name
                        [ -z "$dev" ] && continue
                        
                        # Construct full device path
                        local dev_path="/dev/$dev"
                        
                        # Skip if not a block device
                        if [ ! -b "$dev_path" ]; then
                            echo "DEBUG: Skipping non-block device: $dev_path" >&2
                            continue
                        fi
                        
                        # Skip if it's a partition (has a number at the end)
                        if [[ "$dev" =~ [0-9]+$ ]]; then
                            echo "DEBUG: Skipping partition: $dev_path" >&2
                            continue
                        fi
                        
                        # Skip if not removable and not a USB device (unless running as non-root)
                        if [ "$rm_flag" != "1" ] && [ "$tran" != "usb" ]; then
                            # For non-root, be more permissive
                            if [ "$has_root" -eq 0 ]; then
                                echo "DEBUG: Non-root mode, including non-removable device: $dev_path" >&2
                            else
                                echo "DEBUG: Skipping non-removable, non-USB device: $dev_path" >&2
                                continue
                            fi
                        fi
                        
                        # Clean up model string
                        model=$(echo "$model" | tr -d '\n\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
                        [ -z "$model" ] && model="Unknown"
                        
                        # Add mount info if mounted
                        local mount_info=""
                        if [ -n "$mountpoint" ] && [ "$mountpoint" != "(null)" ]; then
                            mount_info=" (mounted at $mountpoint)"
                        fi
                        
                        # Add filesystem info if available
                        local fs_info=""
                        if [ -n "$fstype" ] && [ "$fstype" != "(null)" ]; then
                            fs_info=" [$fstype]"
                        fi
                        
                        # Add to arrays
                        _CASCADE_USB_PATHS+=("$dev_path")
                        _CASCADE_USB_DISPLAY_STRINGS+=("$dev_path - $size - $model$mount_info$fs_info")
                        echo "DEBUG: Added device: $dev_path - $size - $model$mount_info$fs_info" >&2
                    done
                else
                    echo "DEBUG: jq not available, falling back to text parsing" >&2
                    # Fall back to text parsing if jq is not available
                    while IFS= read -r line; do
                        if [ -n "$line" ]; then
                            local dev size model tran rm_flag
                            read -r dev size model tran rm_flag <<< "$line"
                            
                            # Skip if no device name
                            [ -z "$dev" ] && continue
                            
                            # Skip if it's a partition (has a number at the end)
                            if [[ "$dev" =~ [0-9]+$ ]]; then
                                continue
                            fi
                            
                            # Construct full device path
                            local dev_path="$dev"
                            
                            # Skip if not a block device
                            [ ! -b "$dev_path" ] && continue
                            
                            # Skip if not removable and not a USB device (unless running as non-root)
                            if [ "$rm_flag" != "1" ] && [ "$tran" != "usb" ]; then
                                # For non-root, be more permissive
                                if [ "$has_root" -eq 0 ]; then
                                    echo "DEBUG: Non-root mode, including non-removable device: $dev_path" >&2
                                else
                                    continue
                                fi
                            fi
                            
                            # Clean up model string
                            model=$(echo "$model" | tr -d '\n\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
                            [ -z "$model" ] && model="Unknown"
                            
                            # Add to arrays
                            _CASCADE_USB_PATHS+=("$dev_path")
                            _CASCADE_USB_DISPLAY_STRINGS+=("$dev_path - $size - $model")
                            echo "DEBUG: Added device: $dev_path - $size - $model" >&2
                        fi
                    done < <(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | grep -v '^$' | while read -r dev size model tran rm_flag; do
                        echo "$dev $size $model $tran $rm_flag"
                    done)
                fi
            fi
        else
            echo "DEBUG: lsblk doesn't support JSON, using text output" >&2
            # Fall back to text parsing for older lsblk versions
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    local dev size model tran rm_flag
                    read -r dev size model tran rm_flag <<< "$line"
                    
                    # Skip if no device name
                    [ -z "$dev" ] && continue
                    
                    # Skip if it's a partition (has a number at the end)
                    if [[ "$dev" =~ [0-9]+$ ]]; then
                        continue
                    fi
                    
                    # Skip if not a block device
                    [ ! -b "$dev" ] && continue
                    
                    # Skip if not removable and not a USB device (unless running as non-root)
                    if [ "$rm_flag" != "1" ] && [ "$tran" != "usb" ]; then
                        # For non-root, be more permissive
                        if [ "$has_root" -eq 0 ]; then
                            echo "DEBUG: Non-root mode, including non-removable device: $dev" >&2
                        else
                            continue
                        fi
                    fi
                    
                    # Clean up model string
                    model=$(echo "$model" | tr -d '\n\r' | sed 's/^[ \t]*//;s/[ \t]*$//')
                    [ -z "$model" ] && model="Unknown"
                    
                    # Add to arrays
                    _CASCADE_USB_PATHS+=("$dev")
                    _CASCADE_USB_DISPLAY_STRINGS+=("$dev - $size - $model")
                    echo "DEBUG: Added device: $dev - $size - $model" >&2
                fi
            done < <(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | grep -v '^$' | while read -r dev size model tran rm_flag; do
                echo "$dev $size $model $tran $rm_flag"
            done)
        fi
    fi
    
    # Method 2: Fall back to /sys/block if lsblk fails or no devices found
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ] && [ -d "/sys/block" ]; then
        echo "DEBUG: Falling back to /sys/block detection..." >&2
        
        for dev in /sys/block/*; do
            local devname=$(basename "$dev")
            local devpath="/dev/$devname"
            
            # Skip loop devices and other non-disk devices
            if [[ "$devname" == loop* ]] || [[ "$devname" == ram* ]] || [[ "$devname" == sr* ]]; then
                echo "DEBUG: Skipping virtual device: $devpath" >&2
                continue
            fi
            
            # Skip if it's a partition (has a number at the end)
            if [[ "$devname" =~ [0-9]+$ ]]; then
                echo "DEBUG: Skipping partition: $devpath" >&2
                continue
            fi
            
            # Skip if not a block device
            if [ ! -b "$devpath" ]; then
                echo "DEBUG: Not a block device: $devpath" >&2
                continue
            fi
            
            # Check if device is removable
            local removable="0"
            if [ -f "$dev/removable" ]; then
                removable=$(cat "$dev/removable" 2>/dev/null || echo "0")
            fi
            
            # Check if device is USB
            local is_usb=0
            if [ -e "$dev/device/uevent" ] && grep -q "DRIVER=usb" "$dev/device/uevent" 2>/dev/null; then
                is_usb=1
            fi
            
            # Skip if not removable and not USB (unless running as non-root)
            if [ "$removable" != "1" ] && [ "$is_usb" != "1" ]; then
                # For non-root, be more permissive
                if [ "$has_root" -eq 0 ]; then
                    echo "DEBUG: Non-root mode, including non-removable device: $devpath" >&2
                else
                    echo "DEBUG: Skipping non-removable, non-USB device: $devpath" >&2
                    continue
                fi
            fi
            
            # Get device size
            local size="unknown"
            if [ -f "$dev/size" ]; then
                local sectors=$(cat "$dev/size" 2>/dev/null)
                if [ -n "$sectors" ] && [ "$sectors" -gt 0 ]; then
                    size=$((sectors * 512))
                    size=$(numfmt --to=si --suffix=B --format="%.1f" $size 2>/dev/null || echo "$size")
                fi
            fi
            
            # Get device model
            local model="Unknown"
            if [ -f "$dev/device/model" ]; then
                model=$(cat "$dev/device/model" 2>/dev/null | tr -d '\n\r' | sed 's/\s\+$//')
                [ -z "$model" ] && model="Unknown"
            fi
            
            # Get mount info if available
            local mount_info=""
            if command -v findmnt >/dev/null; then
                local mount_point=$(findmnt -n -o TARGET --source "$devpath" 2>/dev/null | head -1)
                if [ -n "$mount_point" ]; then
                    mount_info=" (mounted at $mount_point)"
                fi
            fi
            
            # Get filesystem info if available
            local fs_info=""
            if command -v lsblk >/dev/null; then
                local fstype=$(lsblk -no FSTYPE "$devpath" 2>/dev/null | head -1)
                if [ -n "$fstype" ]; then
                    fs_info=" [$fstype]"
                fi
            fi
            
            # Add to arrays
            _CASCADE_USB_PATHS+=("$devpath")
            _CASCADE_USB_DISPLAY_STRINGS+=("$devpath - $size - $model$mount_info$fs_info")
            echo "DEBUG: Added device: $devpath - $size - $model$mount_info$fs_info" >&2
        done
    fi
    
    # Method 3: Last resort - look for common USB device patterns
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ]; then
        echo "DEBUG: Trying last resort device detection..." >&2
        for dev in /dev/sd*; do
            # Skip if not a block device
            [ ! -b "$dev" ] && continue
            
            # Skip if it's a partition (has a number at the end)
            [[ "$dev" =~ [0-9]+$ ]] && continue
            
            # Get device info
            local size="unknown"
            if command -v blockdev >/dev/null; then
                size=$(blockdev --getsize64 "$dev" 2>/dev/null | numfmt --to=si 2>/dev/null || echo "unknown")
            fi
            
            # Add to arrays
            _CASCADE_USB_PATHS+=("$dev")
            _CASCADE_USB_DISPLAY_STRINGS+=("$dev - $size - Unknown")
            echo "DEBUG: Added device (last resort): $dev - $size - Unknown" >&2
        done
    fi

    # If no devices found, show error and return non-zero status
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ]; then
        print_warning "No suitable USB/removable storage devices detected." >&2
        echo "Please connect a USB drive and try again." >&2
        return 1
    fi

    local device_count=${#_CASCADE_USB_PATHS[@]}
    print_info "Found $device_count potential device(s)." >&2
    
    # Debug: List all devices
    print_info "Available devices:" >&2
    for i in "${!_CASCADE_USB_PATHS[@]}"; do
        print_info "  [${i}] ${_CASCADE_USB_PATHS[$i]} - ${_CASCADE_USB_DISPLAY_STRINGS[$i]}" >&2
    done
    
    # Display the device selection UI
    print_info "Rendering device selection UI..." >&2
    
    # Display friendly llama mascot with selection message
    echo -e "\n  ${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET} ${COLOR_BOLD}Please select the USB device you want to use:${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_YELLOW}All data on the selected device will be permanently erased!${COLOR_RESET}\n" > /dev/tty
    
    # Simple header for the device list
    echo -e "  ${COLOR_CYAN}╭$(repeat_char "─" $((UI_WIDTH - 12)))╮${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}#   Device        Size       Model/Description${COLOR_RESET}${COLOR_CYAN}  │${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}├$(repeat_char "─" $((UI_WIDTH - 12)))┤${COLOR_RESET}" > /dev/tty
    
    # Display devices in a simple list format
    local i
    for i in "${!_CASCADE_USB_PATHS[@]}"; do
        local dev_path="${_CASCADE_USB_PATHS[$i]}"
        local display_string="${_CASCADE_USB_DISPLAY_STRINGS[$i]}"
        
        # Extract information from display string
        local size=$(echo "$display_string" | grep -o -E ' - [0-9.]+[KMGTPE]i?B' | sed 's/^ - //' || echo "Unknown")
        local model=$(echo "$display_string" | sed -E 's/^.* - [0-9.]+[KMGTPE]?i?B - //')
        local device_name=$(basename "$dev_path")
        
        # Ensure we have valid values
        size="${size:-Unknown}"
        model="${model:-No description}"
        
        # Determine device type and icon based on model or device name
        local icon="💾" # Default USB icon
        if [[ "$model" == *"Card"* ]] || [[ "$device_name" == mmcblk* ]]; then
            icon="💳" # SD card
        elif [[ "$model" == *"SSD"* ]] || [[ "$device_name" == nvme* ]]; then
            icon="💽" # SSD
        fi
        
        # Format the device row - using simple echo for reliability
        echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}$((i+1))${COLOR_RESET}  ${icon} ${COLOR_YELLOW}$(printf '%-12s' "${device_name}")${COLOR_RESET} $(printf '%-9s' "${size}") ${COLOR_CYAN}${model}${COLOR_RESET}  ${COLOR_CYAN}│${COLOR_RESET}" > /dev/tty
    done

    # Add manual entry and quit options after the loop
    echo -e "  ${COLOR_CYAN}├$(repeat_char "─" $((UI_WIDTH - 12)))┤${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}M)${COLOR_RESET} Manually enter device path                      ${COLOR_CYAN}│${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}│${COLOR_RESET} ${COLOR_BOLD}Q)${COLOR_RESET} Quit / Cancel                                 ${COLOR_CYAN}│${COLOR_RESET}" > /dev/tty
    echo -e "  ${COLOR_CYAN}╰$(repeat_char "─" $((UI_WIDTH - 12)))╯${COLOR_RESET}\n" > /dev/tty
    
    return 0 # Successfully displayed device selection options
}

# List available USB/removable devices and prompt user to select one
# Returns the selected device path via stdout
select_usb_device() {
    echo "DEBUG: select_usb_device() starting..." >&2
    
    # If we already have a device selected and want to skip the duplicate selection
    if [ "$SKIP_DEVICE_SELECTION" = "true" ] && [ -n "$LEONARDO_DEVICE_PATH" ]; then
        echo "DEBUG: Using previously selected device: $LEONARDO_DEVICE_PATH" >&2
        echo "$LEONARDO_DEVICE_PATH"
        return 0
    fi

    clear_screen_and_show_art

    # Add step banner
    local box_width_select=$((UI_WIDTH - 8)) # Use a different var name to avoid scope issues if any
    local step_text_select="STEP 1: SELECT USB DEVICE"
    local padding_select=$(( (box_width_select - ${#step_text_select}) / 2 ))
    echo -e "${COLOR_CYAN}╔$(repeat_char "═" $((box_width_select + 2)))╗${COLOR_RESET}"
    echo -e "${COLOR_CYAN}║${COLOR_RESET}$(repeat_char " " $padding_select)${COLOR_BOLD}${COLOR_YELLOW}${step_text_select}${COLOR_RESET}$(repeat_char " " $((box_width_select - padding_select - ${#step_text_select} + 2)))${COLOR_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╚$(repeat_char "═" $((box_width_select + 2)))╝${COLOR_RESET}\n"

    print_info "Scanning for USB/removable storage devices..."
    
    # Reset global arrays
    _CASCADE_USB_PATHS=()
    _CASCADE_USB_DISPLAY_STRINGS=()
    
    # Get list of USB/removable devices
    echo "DEBUG: select_usb_device: Calling list_usb_devices..." >&2
    if ! list_usb_devices; then
        print_error "Failed to list USB devices. Check if you have the required permissions (try running with sudo)."
        return 1
    fi
    
    local num_devices=${#_CASCADE_USB_PATHS[@]}
    echo "DEBUG: select_usb_device: Found $num_devices devices" >&2
    
    if [ $num_devices -eq 0 ]; then
        print_error "No USB/removable devices found."
        
        # Provide helpful troubleshooting steps
        echo -e "\n${COLOR_YELLOW}Troubleshooting steps:${COLOR_RESET}"
        echo "1. Make sure the USB drive is properly connected"
        echo "2. Try unplugging and reconnecting the USB drive"
        echo "3. Check if the device appears in 'lsblk' or 'lsusb' output"
        echo -e "4. ${COLOR_BOLD}Run with sudo${COLOR_RESET} if you see permission errors"
        
        # Show available block devices to help with manual entry
        echo -e "\n${COLOR_YELLOW}Available block devices:${COLOR_RESET}"
        if command -v lsblk >/dev/null 2>&1; then
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | head -n 1
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | grep -v '^NAME'
        else
            echo "(lsblk not available, trying direct /dev listing)"
            ls -l /dev/sd* /dev/hd* /dev/nvme* /dev/mmcblk* 2>/dev/null || echo "Could not list devices"
        fi
        
        return 1
    fi
    
    # Display the device selection menu
    echo -e "\n${COLOR_BOLD}${COLOR_WHITE}Select a USB device to use:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}WARNING: All data on the selected device will be permanently erased!${COLOR_RESET}"
    
    # Display device list with numbers and more details
    for i in "${!_CASCADE_USB_DISPLAY_STRINGS[@]}"; do
        local device_path="${_CASCADE_USB_PATHS[$i]}"
        local device_info="${_CASCADE_USB_DISPLAY_STRINGS[$i]}"
        
        # Get additional info for display
        local size_info=""
        local mount_info=""
        
        if command -v lsblk >/dev/null 2>&1; then
            size_info=$(lsblk -d -o SIZE --nodeps -n "$device_path" 2>/dev/null | xargs)
            local mount_point=$(lsblk -no MOUNTPOINT "$device_path" 2>/dev/null | grep -v '^$' | head -1)
            if [ -n "$mount_point" ]; then
                mount_info="${COLOR_RED}(Mounted at: $mount_point)${COLOR_RESET}"
            fi
        fi
        
        # Format the display line with proper alignment
        printf "  ${COLOR_CYAN}%2d)${COLOR_RESET} %-30s ${COLOR_YELLOW}%10s${COLOR_RESET} %s\n" \
            "$((i+1))" "$device_path" "$size_info" "$mount_info"
    done
    
    # Add option for manual entry
    echo -e "\n  ${COLOR_CYAN}m)${COLOR_RESET} Enter device path manually"
    echo -e "  ${COLOR_CYAN}q)${COLOR_RESET} Quit"
    
    # Prompt for selection
    while true; do
        echo -n -e "\n${COLOR_BOLD}Select device (1-$num_devices, m, q): ${COLOR_RESET}"
        read -r selection
        
        # Trim whitespace
        selection=$(echo "$selection" | xargs)
        
        echo "DEBUG: User input: '$selection'" >&2
        
        case $selection in
            [1-9]|[1-9][0-9])
                # Check if the selection is within range
                if [ "$selection" -ge 1 ] && [ "$selection" -le $num_devices ]; then
                    local selected_device="${_CASCADE_USB_PATHS[$((selection-1))]}"
                    echo "DEBUG: User selected device #$selection: $selected_device" >&2
                    
                    # Verify the device still exists and is accessible
                    if [ ! -e "$selected_device" ]; then
                        print_error "Device '$selected_device' is no longer available. Please try again."
                        continue
                    fi
                    
                    echo "$selected_device"
                    return 0
                else
                    print_error "Invalid selection. Please enter a number between 1 and $num_devices."
                fi
                ;;
            m|M)
                # Manual entry
                echo -e "\n${COLOR_YELLOW}Manual device entry${COLOR_RESET}"
                echo -e "Enter the full device path (e.g., /dev/sdX or sdb)"
                echo -e "Available devices: $(ls /dev/sd* /dev/nvme* /dev/mmcblk* 2>/dev/null | tr '\n' ' ')"
                echo -n -e "${COLOR_BOLD}Device path: ${COLOR_RESET}"
                read -r manual_device
                
                # Trim whitespace and quotes
                manual_device=$(echo "$manual_device" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
                
                # Basic validation
                if [ -z "$manual_device" ]; then
                    print_error "No device path provided."
                    continue
                fi
                
                # Add /dev/ prefix if missing and it looks like a device name
                if [[ ! "$manual_device" =~ ^/dev/ ]] && [[ "$manual_device" =~ ^[sh]d[a-z]|nvme[0-9]n[0-9]|mmcblk[0-9] ]]; then
                    manual_device="/dev/$manual_device"
                    echo "DEBUG: Added /dev/ prefix: $manual_device" >&2
                fi
                
                # Verify the device exists and is a block device
                if [ ! -e "$manual_device" ]; then
                    print_error "Device '$manual_device' does not exist."
                    continue
                fi
                
                if [ ! -b "$manual_device" ]; then
                    print_error "'$manual_device' is not a block device."
                    continue
                fi
                
                echo "DEBUG: User manually entered device: $manual_device" >&2
                echo "$manual_device"
                return 0
                ;;
            q|Q)
                print_info "Operation cancelled by user."
                return 1
                ;;
            *)
                print_error "Invalid selection. Please enter a number between 1 and $num_devices, 'm' for manual entry, or 'q' to quit."
                ;;
        esac
    done

    # Main selection loop handles all exit paths. Device path is echoed and function returns within the loop.
}

# Verify that the selected device is a valid USB device and prompt for confirmation
# Takes the device path as an argument
verify_usb_device() {
    
    local device_path="$1"
    
    # If there's a global device path set and this function was called without arguments,
    # use the global device path instead
    if [ -z "$device_path" ] && [ -n "$LEONARDO_DEVICE_PATH" ]; then
        device_path="$LEONARDO_DEVICE_PATH"
        echo "DEBUG: verify_usb_device: Using global device path: $device_path" >&2
    fi
    
    # Check if device path is empty
    if [ -z "$device_path" ]; then
        echo "DEBUG: verify_usb_device: No device path provided" >&2
        print_error "No device path provided"
        return 1
    fi
    
    # Clean up the device path
    device_path=$(echo "$device_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    echo "DEBUG: verify_usb_device: Checking device: '$device_path'" >&2
    
    # Check if the device exists and is a block device
    echo "DEBUG: verify_usb_device: Running is_block_device check..." >&2
    if ! is_block_device "$device_path"; then
        echo "DEBUG: verify_usb_device: is_block_device check FAILED for '$device_path'" >&2
        print_error "'$device_path' is not a valid block device"
        
        # Try to provide more helpful error messages
        if [ ! -e "$device_path" ]; then
            print_error "The specified device does not exist: $device_path"
            # Check if /dev/ prefix is missing
            if [[ ! "$device_path" =~ ^/dev/ ]] && [ -e "/dev/$device_path" ]; then
                print_info "Note: Did you mean '/dev/$device_path'?"
            fi
        elif [ -d "$device_path" ]; then
            print_error "The specified path is a directory, not a block device"
        elif [ -f "$device_path" ]; then
            print_error "The specified path is a regular file, not a block device"
        fi
        
        # List available block devices to help user
        echo -e "\n${COLOR_YELLOW}Available block devices:${COLOR_RESET}"
        if command -v lsblk >/dev/null 2>&1; then
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | head -n 1
            lsblk -d -o NAME,SIZE,MODEL,TRAN --nodeps | grep -v '^NAME'
        else
            echo "(lsblk not available, trying direct /dev listing)"
            ls -l /dev/sd* /dev/hd* /dev/nvme* /dev/mmcblk* 2>/dev/null || echo "Could not list devices"
        fi
        
        return 1
    fi
    
    echo "DEBUG: verify_usb_device: Device passed block device check" >&2
    
    # Get device information for confirmation
    local device_info=""
    local device_size=""
    local device_model=""
    
    if command -v lsblk >/dev/null 2>&1; then
        echo "DEBUG: verify_usb_device: Using lsblk to get device info" >&2
        device_info=$(lsblk -d -o NAME,SIZE,MODEL,VENDOR,TRAN --nodeps -n "$device_path" 2>/dev/null)
        device_size=$(lsblk -d -o SIZE --nodeps -n "$device_path" 2>/dev/null | xargs)
        device_model=$(lsblk -d -o MODEL --nodeps -n "$device_path" 2>/dev/null | xargs)
    else
        echo "DEBUG: verify_usb_device: lsblk not available, using fallback methods" >&2
        # Fallback if lsblk is not available
        device_size=$(blockdev --getsize64 "$device_path" 2>/dev/null | numfmt --to=si 2>/dev/null || echo "unknown size")
        device_info="$(basename "$device_path") - $device_size"
    fi
    
    # Get mount points if any
    local mount_points=""
    if command -v findmnt >/dev/null 2>&1; then
        echo "DEBUG: verify_usb_device: Using findmnt to check mounts" >&2
        mount_points=$(findmnt -n -o TARGET --source "$device_path*" 2>/dev/null | tr '\n' ' ')
    elif command -v mount >/dev/null 2>&1; then
        echo "DEBUG: verify_usb_device: Using mount to check mounts" >&2
        mount_points=$(mount | grep "^$device_path" | awk '{print $3}' | tr '\n' ' ')
    else
        echo "DEBUG: verify_usb_device: No mount checking tools available" >&2
        mount_points="(mount info unavailable)"
    fi
    
    # Check if device is mounted
    if [ -n "$mount_points" ]; then
        echo "DEBUG: verify_usb_device: Device is mounted at: $mount_points" >&2
        print_warning "Device '$device_path' is mounted at: $mount_points"
        
        # Try to unmount automatically if it's a USB device
        if [[ "$device_path" =~ "/dev/sd" || "$device_path" =~ "/dev/nvme" || "$device_path" =~ "/dev/mmcblk" ]]; then
            if confirm "Would you like to try unmounting it automatically?" "yes"; then
                echo "DEBUG: verify_usb_device: Attempting to unmount $device_path" >&2
                if command -v umount >/dev/null 2>&1; then
                    for mp in $mount_points; do
                        echo "Unmounting $mp..."
                        umount "$mp" 2>/dev/null
                    done
                    # Verify unmount was successful
                    mount_points=$(findmnt -n -o TARGET --source "$device_path*" 2>/dev/null | tr '\n' ' ')
                    if [ -n "$mount_points" ]; then
                        print_error "Failed to unmount all partitions of $device_path"
                        if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                            print_info "Operation cancelled by user."
                            return 1
                        fi
                    else
                        print_success "Successfully unmounted all partitions of $device_path"
                    fi
                else
                    print_error "'umount' command not found. Cannot unmount automatically."
                    if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                        print_info "Operation cancelled by user."
                        return 1
                    fi
                fi
            else
                if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                    print_info "Operation cancelled by user."
                    return 1
                fi
            fi
        else
            if ! confirm "Do you want to continue anyway? This may cause data loss." "no"; then
                print_info "Operation cancelled by user."
                return 1
            fi
        fi
    else
        echo "DEBUG: verify_usb_device: Device is not mounted" >&2
    fi
    
    # Final warning confirmation box
    local box_width=70  # Define a width for the warning box
    echo -e "${COLOR_RED}╔$(repeat_char "═" $box_width)╗${COLOR_RESET}"
    echo -e "${COLOR_RED}║${COLOR_RESET} ${COLOR_BOLD}${COLOR_RED}(ಠ‿ಠ)🦙 ALL DATA ON DEVICE ${device_path} WILL BE PERMANENTLY ERASED!${COLOR_RESET}${COLOR_RED}$(printf "%$((box_width - 46 - ${#device_path}))s" "")║${COLOR_RESET}"
    echo -e "${COLOR_RED}║${COLOR_RESET} ${COLOR_RED}This operation is irreversible. Make sure you have backups of any important data.${COLOR_RESET}${COLOR_RED}$(printf "%$((box_width - 75))s" "")║${COLOR_RESET}"
    echo -e "${COLOR_RED}╚$(repeat_char "═" $box_width)╝${COLOR_RESET}"
    echo
    
    # Double confirmation with explicit yes/no options
    echo -e "${COLOR_BOLD}${COLOR_RED}⚠️  Type 'YES' (all caps) to confirm you want to format $device_path: ${COLOR_RESET}"
    local user_confirmation
    read user_confirmation
    
    if [[ "$user_confirmation" != "YES" ]]; then
        print_error "Formatting operation cancelled - confirmation not received." >&2
        return 1
    fi
    
    print_info "Device $device_path verified and confirmed for formatting."
    return 0
}

# Wait for device to settle after making changes
wait_for_device_settle() {
    local device="$1"
    local timeout="${2:-5}" # Default to 5 seconds
    
    print_debug "Waiting for device $device to settle (up to $timeout seconds)..."
    
    # Run udevadm settle with timeout
    if command -v udevadm >/dev/null; then
        sudo udevadm settle --timeout="$timeout" || print_warning "udevadm settle command failed or timed out."
    else
        print_warning "udevadm not found. Relying on sleep to allow device to settle."
        sleep "$timeout" # Fallback if udevadm is not available
    fi
    
    # Additional sleep to ensure the kernel has processed all events, especially after udevadm might have exited early
    sleep 1 
    
    print_debug "Device $device should be settled now."
}



# ==============================================================================
# Component: 03_filesystem/operations.sh
# ==============================================================================
# ==============================================================================
# Filesystem Operations
# ==============================================================================

# Safely mount a device
safe_mount() {
    local device="$1"
    local mount_point="$2"
    local fs_type="${3:-}"
    local options="${4:-rw,noatime}"
    local result
    
    # Create mount point if it doesn't exist
    mkdir -p "$mount_point" 2>/dev/null || {
        print_error "Failed to create mount point: $mount_point"
        return 1
    }
    
    # Build mount command
    local mount_cmd="mount"
    [ -n "$fs_type" ] && mount_cmd="$mount_cmd -t $fs_type"
    mount_cmd="$mount_cmd -o $options $device $mount_point"
    
    # Execute mount command
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run: $mount_cmd"
        return 0
    fi
    
    print_debug "Mounting: $mount_cmd"
    eval "$mount_cmd" 2>/dev/null
    result=$?
    
    if [ $result -ne 0 ]; then
        print_error "Failed to mount $device at $mount_point"
        return $result
    fi
    
    return 0
}

# Enhanced unmount function to handle stubborn devices
# Based on memory: Added aggressive unmounting to handle the "partition in use" error
safe_umount() {
    local target="$1"
    local max_retries=${2:-5}
    local retry_delay=${3:-1}
    local attempt=1
    local result
    
    # Check if target is a block device or a mount point
    if ! is_block_device "$target" && ! mountpoint -q "$target" 2>/dev/null; then
        print_debug "Not mounted: $target"
        return 0
    fi
    
    print_debug "Attempting to unmount: $target (max $max_retries attempts)"
    
    # Try different unmount methods with increasing aggressiveness
    while [ $attempt -le $max_retries ]; do
        print_debug "Unmount attempt $attempt of $max_retries"
        
        case $attempt in
            1)
                # First try a normal unmount
                print_debug "Trying normal unmount"
                umount "$target" 2>/dev/null
                ;;
            2)
                # Try lazy unmount
                print_debug "Trying lazy unmount"
                umount -l "$target" 2>/dev/null
                ;;
            3)
                # Kill processes using the target
                print_debug "Killing processes using $target"
                fuser -km "$target" 2>/dev/null
                sleep 1
                umount -f "$target" 2>/dev/null
                ;;
            4)
                # Force lazy unmount
                print_debug "Force lazy unmount"
                umount -lf "$target" 2>/dev/null
                ;;
            5)
                # Last resort: try to reload partition table
                print_debug "Reloading partition table as last resort"
                sync
                blockdev --rereadpt "$target" 2>/dev/null || true
                partprobe "$target" 2>/dev/null || true
                hdparm -z "$target" 2>/dev/null || true
                # Try to write directly to sysfs to force re-read
                local dev_name=$(basename "$target")
                echo 1 > "/sys/block/$dev_name/device/rescan" 2>/dev/null || true
                sleep 2
                umount -lf "$target" 2>/dev/null
                ;;
        esac
        
        # Verify if unmount was successful
        if ! is_block_device "$target" || ! mountpoint -q "$target" 2>/dev/null; then
            print_debug "Successfully unmounted: $target (attempt $attempt)"
            return 0
        fi
        
        # Wait before retrying
        sleep $retry_delay
        attempt=$((attempt + 1))
    done
    
    # If we're here, all retries failed
    print_error "Failed to unmount $target after $max_retries attempts"
    return 1
}

# Create a filesystem on a device
create_filesystem() {
    local device="$1"
    local fs_type="${2:-ext4}"
    local label="${3:-}"
    local force="${4:-false}"
    local mkfs_cmd=""
    local result=0
    
    # Validate device
    if ! is_block_device "$device"; then
        print_error "Not a block device: $device"
        return 1
    fi
    
    # Unmount any mounted partitions
    safe_umount "$device" 5 2 || {
        print_error "Failed to unmount device: $device"
        return 1
    }
    
    # Build filesystem creation command
    case "$fs_type" in
        vfat|fat16|fat32)
            mkfs_cmd="mkfs.vfat -F32"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -n '${label:0:11}'"
            ;;
        ext2|ext3|ext4)
            mkfs_cmd="mkfs.$fs_type -F"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -L '$label'"
            [ "$fs_type" = "ext4" ] && mkfs_cmd="$mkfs_cmd -O ^64bit,^metadata_csum"
            ;;
        ntfs)
            mkfs_cmd="mkfs.ntfs -F"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -L '$label'"
            ;;
        exfat)
            mkfs_cmd="mkfs.exfat"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -n '$label'"
            ;;
        *)
            print_error "Unsupported filesystem type: $fs_type"
            return 1
            ;;
    esac
    
    # Add force flag if requested
    [ "$force" = "true" ] && [ "$fs_type" != "exfat" ] && mkfs_cmd="$mkfs_cmd -F"
    
    # Execute filesystem creation
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run: $mkfs_cmd $device"
        return 0
    fi
    
    print_info "Creating $fs_type filesystem on $device..."
    
    # Wait for device to settle
    wait_for_device_settle "$device"
    
    # Create filesystem
    eval "$mkfs_cmd $device" 2>&1 | while IFS= read -r line; do
        print_debug "$line"
    done
    
    result=${PIPESTATUS[0]}
    
    if [ $result -ne 0 ]; then
        print_error "Failed to create $fs_type filesystem on $device"
        return $result
    fi
    
    # Wait for device to settle after filesystem creation
    wait_for_device_settle "$device"
    
    print_success "Created $fs_type filesystem on $device"
    return 0
}

# Create a partition table on a device
create_partition_table() {
    local device="$1"
    local table_type="${2:-gpt}"
    local result=0
    
    # Validate device
    if ! is_block_device "$device"; then
        print_error "Not a block device: $device"
        return 1
    fi
    
    # Unmount any mounted partitions
    safe_umount "$device" || {
        print_error "Failed to unmount device: $device"
        return 1
    }
    
    # Create partition table
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would create $table_type partition table on $device"
        return 0
    fi
    
    print_info "Creating $table_type partition table on $device..."
    
    # Wait for device to settle
    wait_for_device_settle "$device"
    
    # Clear existing partition table - wipe first few MB
    print_debug "Wiping existing partition table..."
    dd if=/dev/zero of="$device" bs=1M count=16 conv=fsync 2>/dev/null
    
    # Create new partition table
    print_debug "Creating new partition table of type $table_type..."
    case "$table_type" in
        gpt)
            parted -s "$device" mklabel gpt 2>&1 | while IFS= read -r line; do
                print_debug "$line"
            done
            result=${PIPESTATUS[0]}
            ;;
        msdos|mbr)
            parted -s "$device" mklabel msdos 2>&1 | while IFS= read -r line; do
                print_debug "$line"
            done
            result=${PIPESTATUS[0]}
            ;;
        *)
            print_error "Unsupported partition table type: $table_type"
            return 1
            ;;
    esac
    
    if [ $result -ne 0 ]; then
        print_error "Failed to create $table_type partition table on $device"
        return $result
    fi
    
    # Use multiple methods to ensure partition table is reread
    # Based on memory about improving partition table reload techniques
    sync
    blockdev --rereadpt "$device" 2>/dev/null || true
    partprobe "$device" 2>/dev/null || true
    hdparm -z "$device" 2>/dev/null || true
    sfdisk -R "$device" 2>/dev/null || true
    
    # Wait for device to settle
    wait_for_device_settle "$device" 3
    
    print_success "Created $table_type partition table on $device"
    return 0
}

# Create a partition on a device
create_partition() {
    local device="$1"
    local part_num="${2:-1}"
    local part_type="${3:-primary}"
    local fs_type="${4:-}"
    local start="${5:-0%}"
    local end="${6:-100%}"
    local part_label="${7:-}"
    local part_guid="${8:-}"
    local result=0
    
    # Validate device
    if ! is_block_device "$device"; then
        print_error "Not a block device: $device"
        return 1
    fi
    
    local parted_executable="parted"
    local common_parted_opts=(-s --align optimal "$device")
    local mkpart_subcommand_args=()
    
    # Detect partition table type
    local table_type
    table_type=$("$parted_executable" -s "$device" print 2>/dev/null | grep "Partition Table:" | awk '{print $3}')

    if [ "$table_type" = "gpt" ]; then
        # For GPT, mkpart takes: name start end
        local gpt_part_name="${part_label:-LeonardoP1}"
        mkpart_subcommand_args+=("$gpt_part_name")
        mkpart_subcommand_args+=("$start")
        mkpart_subcommand_args+=("$end")
    else
        # For MBR (msdos), mkpart takes: type [fs-type] start end
        mkpart_subcommand_args+=("$part_type") # primary, logical, extended
        [ -n "$fs_type" ] && mkpart_subcommand_args+=("$fs_type") # Optional fs-type for MBR partition ID
        mkpart_subcommand_args+=("$start")
        mkpart_subcommand_args+=("$end")
    fi

    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run: $parted_executable ${common_parted_opts[*]} mkpart ${mkpart_subcommand_args[*]}"
    else
        print_info "Creating partition $part_num on $device..."
        wait_for_device_settle "$device"
        print_info "Executing parted mkpart: $parted_executable ${common_parted_opts[*]} mkpart ${mkpart_subcommand_args[*]}"
        
        "$parted_executable" "${common_parted_opts[@]}" mkpart "${mkpart_subcommand_args[@]}" 2>&1 | while IFS= read -r line; do
            print_info "parted output: $line"
        done
        result=${PIPESTATUS[0]}
    fi

    # --- SET Operations (name, guid) if mkpart succeeded --- 
    if [ "$DRY_RUN" != true ] && [ $result -eq 0 ]; then
        # Set name/label if specified
        if [ -n "$part_label" ]; then
            local name_subcommand_args=("$part_num" "$part_label")
            print_info "Executing parted name: $parted_executable ${common_parted_opts[*]} name ${name_subcommand_args[*]}"
            "$parted_executable" "${common_parted_opts[@]}" name "${name_subcommand_args[@]}" 2>&1 | while IFS= read -r line; do
                print_info "parted output: $line"
            done
            result=${PIPESTATUS[0]}
            if [ $result -ne 0 ]; then 
                print_warning "parted set name failed. Continuing..."
                result=0 # Reset result so GUID set can be attempted if needed
            fi 
        fi

        # Set GUID if specified (for GPT) and previous set (name) was okay or not done
        if [ $result -eq 0 ] && [ -n "$part_guid" ]; then
            local guid_subcommand_args=("$part_num" "$part_guid" "on")
            print_info "Executing parted set guid: $parted_executable ${common_parted_opts[*]} set ${guid_subcommand_args[*]}"
            "$parted_executable" "${common_parted_opts[@]}" set "${guid_subcommand_args[@]}" 2>&1 | while IFS= read -r line; do
                print_info "parted output: $line"
            done
            result=${PIPESTATUS[0]}
            if [ $result -ne 0 ]; then print_warning "parted set guid failed. Continuing..."; fi
        fi
    elif [ "$DRY_RUN" = true ]; then # Handle DRY_RUN for set operations
        if [ -n "$part_label" ]; then
             print_info "DRY RUN: Would run: $parted_executable ${common_parted_opts[*]} name $part_num '$part_label'"
        fi
        if [ -n "$part_guid" ]; then
            print_info "DRY RUN: Would run: $parted_executable ${common_parted_opts[*]} set $part_num $part_guid on"
        fi
    fi
    
    # Use multiple methods to ensure partition table is reread
    if [ $result -eq 0 ]; then
        sync
        blockdev --rereadpt "$device" 2>/dev/null || true
        partprobe "$device" 2>/dev/null || true
        hdparm -z "$device" 2>/dev/null || true
        wait_for_device_settle "$device" 3
    else
        print_error "Failed to create partition on $device"
        return $result
    fi
    
    print_success "Created partition $part_num on $device"
    return 0
}

# Install the Leonardo system files to a formatted USB drive
install_leonardo_system() {
    local device="$1"          # Device path (e.g., /dev/sdc1)
    local fs_type="$2"         # Filesystem type (e.g., exfat)
    local label="$3"           # Volume label
    
    # Create a temporary mount point
    local temp_mount_point
    temp_mount_point=$(mktemp -d -p "${TMP_DIR:-/tmp}" leonardo_mount_XXXXXX)
    
    if [ -z "$temp_mount_point" ] || [ ! -d "$temp_mount_point" ]; then
        print_error "Failed to create temporary mount point."
        return 1
    fi
    
    # Mount the device
    print_info "Mounting $device to $temp_mount_point..."
    if ! safe_mount "$device" "$temp_mount_point" "$fs_type"; then
        print_error "Failed to mount $device. Cannot install Leonardo system."
        rmdir "$temp_mount_point" 2>/dev/null
        return 1
    fi
    
    # Create the basic directory structure
    print_info "Creating Leonardo system directory structure..."
    mkdir -p "$temp_mount_point/models" "$temp_mount_point/config" "$temp_mount_point/data" "$temp_mount_point/system"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create directories on USB drive."
        safe_umount "$temp_mount_point"
        rmdir "$temp_mount_point" 2>/dev/null
        return 1
    fi
    
    # Create a simple README file
    print_info "Creating system files..."
    cat > "$temp_mount_point/README.txt" << EOF
Leonardo AI System
==================

This USB drive contains the Leonardo AI system.

Directory Structure:
- models/: Contains AI models
- config/: Configuration files
- data/: User data
- system/: System files

Created: $(date)
Version: 5.0.0
EOF
    
    # Create a simple startup script
    cat > "$temp_mount_point/start_leonardo.sh" << 'EOF'
#!/bin/bash

echo "Starting Leonardo AI System..."
echo "This is a placeholder for the actual Leonardo startup script."
echo "In a real deployment, this would launch the Leonardo AI interface."

echo "\nLeonardo AI is ready to use!"
EOF
    
    # Make the startup script executable
    chmod +x "$temp_mount_point/start_leonardo.sh"
    
    # Create a system info file
    cat > "$temp_mount_point/system/info.json" << EOF
{
  "version": "5.0.0",
  "build_date": "$(date +%Y-%m-%d)",
  "filesystem": "$fs_type",
  "label": "$label"
}
EOF
    
    # Create a sample config file
    cat > "$temp_mount_point/config/system.conf" << EOF
# Leonardo AI System Configuration

# Model settings
DEFAULT_MODEL=llama3-8b
MODEL_PRECISION=f16

# System settings
THREADS=4
CONTEXT_SIZE=4096
MEMORY_LIMIT=8G
EOF
    
    # Verify the files were created successfully
    if [ ! -f "$temp_mount_point/README.txt" ] || 
       [ ! -f "$temp_mount_point/start_leonardo.sh" ] || 
       [ ! -f "$temp_mount_point/system/info.json" ] || 
       [ ! -f "$temp_mount_point/config/system.conf" ]; then
        print_error "Failed to create system files."
        safe_umount "$temp_mount_point"
        rmdir "$temp_mount_point" 2>/dev/null
        return 1
    fi
    
    print_success "Successfully installed Leonardo system files."
    
    # Unmount the device
    print_info "Unmounting $temp_mount_point..."
    if ! safe_umount "$temp_mount_point"; then
        print_error "Failed to unmount $temp_mount_point. The drive may not be safely removed."
        # Don't return error here, as the installation succeeded
    fi
    
    # Remove the temporary mount point
    rmdir "$temp_mount_point" 2>/dev/null
    
    return 0
}

# Format a USB device for Leonardo AI with enhanced reliability
format_usb_device() {
    local device="$1"
    local fs_type="${2:-exfat}"
    local label="${3:-LEONARDO}"
    local max_retries=3
    local retry_count=0
    
    print_info "Preparing to format USB device: $device"
    
    # Aggressively unmount any existing partitions on the device
    print_debug "Ensuring all partitions are unmounted..."
    
    # Find all partitions for this device
    local partitions=()
    while read -r part; do
        if [ -n "$part" ]; then
            partitions+=("$part")
            print_debug "Found partition: $part"
        fi
    done < <(lsblk -nlo NAME "$device" | grep -v "^$(basename "$device")$" || echo "")
    
    # Unmount all found partitions
    for part in "${partitions[@]}"; do
        print_debug "Attempting to unmount: /dev/$part"
        safe_umount "/dev/$part" 5 2
    done
    
    # Kill any processes that might be using the device
    print_debug "Terminating processes using the device..."
    fuser -k "$device" 2>/dev/null || true
    for part in "${partitions[@]}"; do
        fuser -k "/dev/$part" 2>/dev/null || true
    done
    
    # Force the kernel to forget about the device
    print_debug "Resetting device state..."
    sync
    blockdev --flushbufs "$device" 2>/dev/null || true
    
    # Use multiple methods to ensure the device is properly recognized
    print_debug "Refreshing device recognition..."
    udevadm settle --timeout=10
    blockdev --rereadpt "$device" 2>/dev/null || true
    partprobe "$device" 2>/dev/null || true
    hdparm -z "$device" 2>/dev/null || true
    
    # Try direct sysfs method
    local dev_name=$(basename "$device")
    if [ -e "/sys/block/$dev_name/device/rescan" ]; then
        print_debug "Using sysfs to rescan device"
        echo 1 > "/sys/block/$dev_name/device/rescan" 2>/dev/null || true
    fi
    
    # Validate device with retry mechanism
    while [ $retry_count -lt $max_retries ]; do
        # Verify the device exists and is accessible
        if verify_usb_device "$device"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Device verification failed. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to verify device after $max_retries attempts."
            return 1
        fi
    done
    
    # Reset retry counter
    retry_count=0
    
    # Create partition table with retry mechanism
    while [ $retry_count -lt $max_retries ]; do
        if create_partition_table "$device" "gpt"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Failed to create partition table. Retrying ($retry_count/$max_retries)..."
            sleep 2
            
            # Try more aggressive device refresh
            sync
            udevadm settle --timeout=10
            blockdev --rereadpt "$device" 2>/dev/null || true
            partprobe -s "$device" 2>/dev/null || true
        else
            print_error "Failed to create partition table after $max_retries attempts."
            return 1
        fi
    done
    
    # Reset retry counter
    retry_count=0
    
    # Create a single partition spanning the whole device
    while [ $retry_count -lt $max_retries ]; do
        if create_partition "$device" 1 "primary" "$fs_type" "0%" "100%" "$label"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Failed to create partition. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to create partition after $max_retries attempts."
            return 1
        fi
    done
    
    # Wait for device to settle with proper partition recognition
    print_info "Waiting for partition to be recognized..."
    udevadm settle --timeout=10
    sleep 3  # Additional wait time for slow USB devices
    
    # Determine the partition device path
    local part_device
    
    # Check if the partition is detected
    if [[ "$device" =~ [0-9]+$ ]]; then
        # Device name already ends with a number, use p1 suffix
        part_device="${device}p1"
    else
        # Device name doesn't end with a number, use 1 suffix
        part_device="${device}1"
    fi
    
    # Verify partition exists with retry
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if [ -b "$part_device" ]; then
            break
        fi
        
        # Alternative check using lsblk
        if lsblk "$part_device" >/dev/null 2>&1; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Partition not detected yet. Waiting... ($retry_count/$max_retries)"
            sleep 2
            
            # Refresh partition table again
            partprobe "$device" 2>/dev/null || true
            udevadm settle --timeout=5
        else
            print_error "Failed to detect partition: $part_device"
            return 1
        fi
    done
    
    # Create filesystem on the partition with retry mechanism
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if create_filesystem "$part_device" "$fs_type" "$label"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Failed to create filesystem. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to create filesystem after $max_retries attempts."
            return 1
        fi
    done
    
    print_success "USB device $device has been successfully formatted with $fs_type."
    return 0
}



# ==============================================================================
# Component: 04_network/download.sh
# ==============================================================================
# ==============================================================================
# Network Download Operations
# ==============================================================================

# Check if a URL is reachable
check_url() {
    local url="$1"
    local timeout="${2:-10}"
    
    # Check if curl is available
    if command_exists curl; then
        if curl -sSL --max-time "$timeout" --head "$url" &>/dev/null; then
            return 0
        fi
    # Fall back to wget if curl is not available
    elif command_exists wget; then
        if wget -q --spider --timeout="$timeout" "$url" &>/dev/null; then
            return 0
        fi
    else
        print_warning "Neither curl nor wget is available. Cannot check URL: $url"
        return 2
    fi
    
    return 1
}

# Download a file with progress tracking
# Based on memory: Fixed nested heredoc syntax problems in fancy_download function
fancy_download() {
    local url="$1"
    local output_file="${2:-}"
    local show_progress="${3:-true}"
    local resume="${4:-false}"
    local retry_count=0
    local max_retries=5
    local retry_delay=3
    local result=0
    
    # If no output file specified, use the basename of the URL
    if [ -z "$output_file" ]; then
        output_file="${url##*/}"
        # Remove query string if present
        output_file="${output_file%%\?*}"
    fi
    
    # Create output directory if it doesn't exist
    local output_dir="$(dirname "$output_file")"
    mkdir -p "$output_dir" 2>/dev/null || {
        print_error "Failed to create directory: $output_dir"
        return 1
    }
    
    print_info "Downloading: $url"
    print_info "To: $output_file"
    
    # Try to download the file with retries
    while [ $retry_count -lt $max_retries ]; do
        # Choose appropriate download tool
        if command_exists curl; then
            # Build curl command
            local curl_args=("-L" "-f" "-o" "$output_file")
            
            # Add resume flag if requested and file exists
            if [ "$resume" = true ] && [ -f "$output_file" ]; then
                curl_args+=("-C" "-")
                print_debug "Resuming download from $(human_readable_size $(stat -c%s "$output_file"))"
            fi
            
            # Add progress display if requested
            if [ "$show_progress" = true ]; then
                curl_args+=("-#")
            else
                curl_args+=("-s")
            fi
            
            # Execute curl command
            curl "${curl_args[@]}" "$url"
            result=$?
            
        elif command_exists wget; then
            # Build wget command
            local wget_args=("-O" "$output_file")
            
            # Add resume flag (always enabled with -c)
            wget_args+=("-c")
            
            # Add progress display if requested
            if [ "$show_progress" = true ]; then
                wget_args+=("--show-progress")
            else
                wget_args+=("-q")
            fi
            
            # Execute wget command
            wget "${wget_args[@]}" "$url"
            result=$?
            
        else
            print_error "Neither curl nor wget is available. Cannot download file."
            return 1
        fi
        
        # Check download result
        if [ $result -eq 0 ]; then
            # Verify the file was actually downloaded
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                print_success "Downloaded: $url"
                
                # Log download in history
                log_download "$url" "$output_file"
                
                return 0
            else
                print_warning "Download completed but file is empty or missing"
                result=1
            fi
        fi
        
        # If download failed, retry
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Download failed (attempt $retry_count/$max_retries)"
            print_info "Retrying in $retry_delay seconds..."
            sleep $retry_delay
        else
            print_error "Failed to download after $max_retries attempts: $url"
        fi
    done
    
    return 1
}

# Log the download in the download history
log_download() {
    local url="$1"
    local file="$2"
    local size=$(stat -c%s "$file" 2>/dev/null || echo "unknown")
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local history_file="$LOG_DIR/download_history.log"
    
    # Create history directory if it doesn't exist
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || {
        print_debug "Failed to create history directory: $(dirname "$history_file")"
        return 1
    }
    
    # Create history file if it doesn't exist
    if [ ! -f "$history_file" ]; then
        echo "# Leonardo AI USB Maker - Download History" > "$history_file"
        echo "# Format: timestamp|url|file|size" >> "$history_file"
        echo "# =========================================" >> "$history_file"
        
        # Set appropriate permissions
        chmod 600 "$history_file" 2>/dev/null || true
    fi
    
    # Append download to history
    echo "$timestamp|$url|$file|$size" >> "$history_file"
    
    return 0
}

# Show the download history
view_download_history() {
    local history_file="$LOG_DIR/download_history.log"
    
    if [ ! -f "$history_file" ]; then
        print_info "No download history available."
        read -p "Press [Enter] to continue..."
        return 0
    fi
    
    print_section_header "DOWNLOAD HISTORY"
    
    local line_count=$(wc -l < "$history_file")
    local header_lines=3
    local data_lines=$((line_count - header_lines))
    
    if [ $data_lines -le 0 ]; then
        print_info "No downloads recorded yet."
        read -p "Press [Enter] to continue..."
        return 0
    fi
    
    echo "Recent downloads (most recent first):"
    echo
    
    # Skip header lines and display in reverse order (most recent first)
    tail -n $data_lines "$history_file" | sort -r | while IFS='|' read -r timestamp url file size; do
        echo "Time: $timestamp"
        echo "URL: $url"
        echo "File: $file"
        echo "Size: $(human_readable_size $size)"
        echo "----------------------------------------"
    done
    
    read -p "Press [Enter] to continue..."
    return 0
}

# Download a file with checksum verification
download_with_checksum() {
    local url="$1"
    local output_file="${2:-}"
    local expected_checksum="${3:-}"
    local algorithm="${4:-sha256}"
    local retry_count=0
    local max_retries=3
    
    # If no output file specified, use the basename of the URL
    if [ -z "$output_file" ]; then
        output_file="${url##*/}"
        # Remove query string if present
        output_file="${output_file%%\?*}"
    fi
    
    # Try to download the file with retries
    while [ $retry_count -lt $max_retries ]; do
        # Download the file
        fancy_download "$url" "$output_file" true true
        
        # If download failed, retry
        if [ $? -ne 0 ]; then
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Download failed. Retrying ($retry_count/$max_retries)..."
                sleep 2
                continue
            else
                print_error "Failed to download file after $max_retries attempts"
                return 1
            fi
        fi
        
        # If no checksum provided, we're done
        if [ -z "$expected_checksum" ]; then
            print_warning "No checksum provided. Skipping verification."
            return 0
        fi
        
        # Verify the checksum
        print_info "Verifying $algorithm checksum..."
        
        # Calculate the actual checksum
        local actual_checksum
        actual_checksum=$(calculate_checksum "$output_file" "$algorithm")
        
        if [ $? -ne 0 ]; then
            print_error "Failed to calculate checksum."
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Retrying ($retry_count/$max_retries)..."
                rm -f "$output_file"
                sleep 2
                continue
            else
                print_error "Failed to verify checksum after $max_retries attempts"
                return 1
            fi
        fi
        
        # Compare the checksums
        if [ "$actual_checksum" = "$expected_checksum" ]; then
            print_success "Checksum verified successfully."
            return 0
        else
            print_error "Checksum verification failed."
            print_error "  Expected: $expected_checksum"
            print_error "  Actual:   $actual_checksum"
            
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Retrying ($retry_count/$max_retries)..."
                rm -f "$output_file"
                sleep 2
                continue
            else
                print_error "Failed to verify checksum after $max_retries attempts"
                return 1
            fi
        fi
    done
    
    return 1
}



# ==============================================================================
# Component: 04_network/checksum.sh
# ==============================================================================
# ==============================================================================
# Checksum Utilities
# ==============================================================================

# Calculate file checksum
calculate_checksum() {
    local file_path="$1"
    local algorithm="${2:-sha256}"
    
    if [ ! -f "$file_path" ]; then
        print_error "File not found: $file_path"
        return 1
    fi
    
    case "$algorithm" in
        md5|md5sum)
            if command_exists md5sum; then
                md5sum "$file_path" | awk '{print $1}'
                return $?
            elif command_exists md5; then
                md5 -q "$file_path"
                return $?
            else
                print_error "md5sum or md5 command not found"
                return 1
            fi
            ;;
        sha1|sha1sum)
            if command_exists sha1sum; then
                sha1sum "$file_path" | awk '{print $1}'
                return $?
            elif command_exists shasum; then
                shasum -a 1 "$file_path" | awk '{print $1}'
                return $?
            else
                print_error "sha1sum or shasum command not found"
                return 1
            fi
            ;;
        sha256|sha256sum)
            if command_exists sha256sum; then
                sha256sum "$file_path" | awk '{print $1}'
                return $?
            elif command_exists shasum; then
                shasum -a 256 "$file_path" | awk '{print $1}'
                return $?
            else
                print_error "sha256sum or shasum command not found"
                return 1
            fi
            ;;
        *)
            print_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
}

# Verify file checksum
verify_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    local actual_checksum
    
    print_debug "Verifying $algorithm checksum for: $file_path"
    
    actual_checksum=$(calculate_checksum "$file_path" "$algorithm")
    if [ $? -ne 0 ]; then
        print_error "Failed to calculate $algorithm checksum for: $file_path"
        return 1
    fi
    
    if [ "$actual_checksum" = "$expected_checksum" ]; then
        print_success "Checksum verified: $file_path"
        return 0
    else
        print_error "Checksum verification failed for: $file_path"
        print_error "Expected: $expected_checksum"
        print_error "Actual:   $actual_checksum"
        return 1
    fi
}

# Save a checksum file
save_checksum() {
    local file_path="$1"
    local algorithm="${2:-sha256}"
    local checksum_file="${3:-}"
    local checksum
    
    # If no checksum file specified, use the file path with algorithm extension
    if [ -z "$checksum_file" ]; then
        checksum_file="${file_path}.${algorithm}"
    fi
    
    # Calculate the checksum
    checksum=$(calculate_checksum "$file_path" "$algorithm")
    if [ $? -ne 0 ]; then
        print_error "Failed to calculate checksum for: $file_path"
        return 1
    fi
    
    # Save the checksum to file
    echo "$checksum  $(basename "$file_path")" > "$checksum_file"
    
    print_success "Saved $algorithm checksum to: $checksum_file"
    return 0
}

# Verify checksums from a checksum file
verify_checksums_file() {
    local checksum_file="$1"
    local base_dir="${2:-.}"
    local algorithm
    
    # Determine algorithm from file extension
    case "$checksum_file" in
        *.md5) algorithm="md5" ;;
        *.sha1) algorithm="sha1" ;;
        *.sha256) algorithm="sha256" ;;
        *)
            print_error "Unknown checksum file type: $checksum_file"
            return 1
            ;;
    esac
    
    # Check if checksum file exists
    if [ ! -f "$checksum_file" ]; then
        print_error "Checksum file not found: $checksum_file"
        return 1
    fi
    
    # Process each line in the checksum file
    local failed=0
    local passed=0
    local total=0
    
    while read -r line; do
        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        total=$((total + 1))
        
        # Extract checksum and filename
        local expected_checksum
        local filename
        
        # Support both common formats:
        # 1. [checksum]  [filename]
        # 2. [checksum] *[filename]
        if [[ "$line" =~ ^([0-9a-fA-F]+)[[:space:]]+[\*]?([^[:space:]]+)$ ]]; then
            expected_checksum="${BASH_REMATCH[1]}"
            filename="${BASH_REMATCH[2]}"
        else
            print_error "Invalid format in line: $line"
            failed=$((failed + 1))
            continue
        fi
        
        # Verify the file's checksum
        file_path="$base_dir/$filename"
        
        if [ ! -f "$file_path" ]; then
            print_error "File not found: $file_path"
            failed=$((failed + 1))
            continue
        fi
        
        print_info "Verifying: $filename"
        
        if verify_checksum "$file_path" "$expected_checksum" "$algorithm"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done < "$checksum_file"
    
    # Report results
    if [ $total -eq 0 ]; then
        print_warning "No checksums found in file: $checksum_file"
        return 1
    fi
    
    if [ $failed -eq 0 ]; then
        print_success "All checksums verified ($passed/$total)"
        return 0
    else
        print_error "$failed/$total checksums failed"
        return 1
    fi
}

# Get the public IP address
get_public_ip() {
    local services=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://ident.me"
        "https://ipecho.net/plain"
    )
    
    for service in "${services[@]}"; do
        if check_url "$service"; then
            if command_exists curl; then
                curl -sSL "$service" 2>/dev/null && return 0
            elif command_exists wget; then
                wget -qO- "$service" 2>/dev/null && return 0
            fi
        fi
    done
    
    print_error "Could not determine public IP address"
    return 1
}



# ==============================================================================
# Component: main.sh
# ==============================================================================
#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker - Main Application
# ==============================================================================

# Create a new USB drive with enhanced UI
create_new_usb() {
    local device
    local filesystem
    local label
    
    # Show header first
    show_header
    
    # Set the USB device selection variables
    export SKIP_DEVICE_SELECTION=true  # Flag to prevent duplicate device selection
    export LEONARDO_DEVICE_PATH=""    # Clear any previous device path
    
    # Select USB device using the enhanced selection screen
    device=$(select_usb_device)
    if [ $? -ne 0 ] || [ -z "$device" ]; then
        print_notification_box "USB device selection failed or was cancelled." "warning"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Export the selected device path for other functions to use
    export LEONARDO_DEVICE_PATH="$device"
    
    # Verify and warn user about the selected device
    if ! verify_usb_device "$device"; then
        print_notification_box "USB device verification failed or was cancelled." "warning"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Select filesystem with enhanced menu
    local fs_options=("exFAT (Windows/Mac/Linux, large files)" "NTFS (Windows, limited macOS/Linux)" "EXT4 (Linux only)")
    show_menu "Select Filesystem" "Choose the filesystem type for your Leonardo AI USB:" "${fs_options[@]}"
    local fs_result=$?
    
    case "$fs_result" in
        0) filesystem="exfat" ;;
        1) filesystem="ntfs" ;;
        2) filesystem="ext4" ;;
        *) 
            print_error "Invalid filesystem selection."
            return 1 ;;
    esac
    
    # Get USB label
    clear_screen_and_show_art
    print_section_header "USB Drive Label"
    echo -e "${COLOR_CYAN}Enter a name for your Leonardo AI USB drive:${COLOR_RESET}"
    echo -e "${COLOR_DIM}(Letters, numbers, and underscores only, no spaces)${COLOR_RESET}"
    echo
    
    # Default label
    label="LEONARDO"
    
    print_prompt "USB Label [$label]: "
    read user_label
    
    if [ -n "$user_label" ]; then
        # Clean up the label - remove spaces and special characters
        label=$(echo "$user_label" | tr -cd '[:alnum:]_')
        if [ -z "$label" ]; then
            label="LEONARDO"
        fi
    fi
    
    echo -e "\nUSB will be labeled as: ${COLOR_BOLD}$label${COLOR_RESET}"
    
    # Show data destruction warning with intense llama
    show_data_destruction_warning "$device" "Format with $filesystem"
    
    # Final confirmation with warning level llama
    if ! confirm "Are you ABSOLUTELY SURE you want to continue with this operation?" "n" "warning"; then
        print_notification_box "Operation cancelled by user." "info"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Format the drive with progress tracking
    if ! run_with_progress "format_usb_device '$device' '$filesystem' '$label'" "Formatting USB Drive" 100; then
        print_notification_box "Failed to format USB drive." "error"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Determine the first partition
    local first_partition
    if [[ "$device" =~ nvme ]]; then
        first_partition="${device}p1"  # NVMe naming convention
    else
        first_partition="${device}1"   # Standard device naming
    fi
    
    # Install the Leonardo system with progress tracking
    if ! run_with_progress "install_leonardo_system '$first_partition' '$filesystem' '$label'" "Installing Leonardo AI System" 100; then
        print_notification_box "Failed to install Leonardo system to USB drive." "error"
        read -n 1 -s -p "Press any key to return to the main menu..."
        return 1
    fi
    
    # Show success screen
    show_success_screen "USB Creation Complete" "Your Leonardo AI USB '$label' has been successfully created and is ready to use!"
    
    return 0
}

# Add an AI model to a USB drive
add_ai_model() {
    print_section_header "ADD AI MODEL TO USB"
    
    # List available AI models
    local model_options=()
    local i=0
    
    for model_entry in "${SUPPORTED_MODELS[@]}"; do
        IFS=':' read -r model_id model_name <<< "$model_entry"
        model_options+=("$model_name")
        i=$((i + 1))
    done
    
    # Ask user to select a model
    show_menu "AI MODELS" "Select an AI model:" "${model_options[@]}"
    local model_choice=$?
    
    IFS=':' read -r selected_model_id selected_model_name <<< "${SUPPORTED_MODELS[$model_choice]}"
    
    print_info "Selected model: $selected_model_name ($selected_model_id)"
    
    # Select USB device using enhanced selection function (handles scanning and prompting)
    local selected_device
    selected_device=$(select_usb_device)

    if [ -z "$selected_device" ]; then
        print_error "No device selected."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi

    # Verify the selected device (optional, but good practice)
    # if ! verify_usb_device "$selected_device"; then
    #     # verify_usb_device handles its own error messaging and prompt to quit
    #     read -p "Press [Enter] to return to the main menu..." 
    #     return 1
    # fi
    print_info "Selected USB device: $selected_device"
    
    # Check if the device is formatted and mounted
    local mount_point
    mount_point=$(lsblk -no MOUNTPOINT "$selected_device" | grep -v "^$")
    
    if [ -z "$mount_point" ]; then
        print_error "The selected USB device is not mounted."
        print_info "Please mount the device and try again."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    print_info "USB device is mounted at: $mount_point"
    
    # Create the model directory on the USB
    local model_dir="$mount_point/models/$selected_model_id"
    mkdir -p "$model_dir"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create model directory on USB."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    # Download model files (this is a placeholder)
    print_info "Downloading $selected_model_name files..."
    print_info "This is a placeholder for the actual download process."
    
    # Create a seed file (simulating the actual model download)
    create_seed_file "$model_dir" "$selected_model_id" "2048"
    
    print_success "Added $selected_model_name to USB drive."
    read -p "Press [Enter] to return to the main menu..."
    return 0
}

# Create a seed file with random data (placeholder for actual model)
create_seed_file() {
    local dir="$1"
    local name="$2"
    local size_mb="${3:-10}"
    local seed_file="$dir/${name}_seed.bin"
    
    print_info "Creating seed file: $seed_file ($size_mb MB)"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would create seed file: $seed_file ($size_mb MB)"
        return 0
    fi
    
    # Create random data
    dd if=/dev/urandom of="$seed_file" bs=1M count="$size_mb" status=progress 2>&1 | while IFS= read -r line; do
        print_debug "$line"
    done
    
    if [ -f "$seed_file" ]; then
        print_success "Created seed file: $seed_file"
        # Calculate and save checksums for integrity verification
        save_checksum "$seed_file" "sha256"
        return 0
    else
        print_error "Failed to create seed file"
        return 1
    fi
}

# Check USB drive health
verify_usb_health() {
    print_section_header "USB HEALTH CHECK"
    
    # List available USB devices
    if ! list_usb_devices; then
        print_error "No USB devices found."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    # Ask user to select a device
    local device
    device=$(select_usb_device)
    if [ -z "$device" ]; then
        print_error "No device selected."
        read -p "Press [Enter] to return to the main menu..."
        return 1
    fi
    
    print_info "Checking health of $device..."
    
    # Get device information
    local vendor
    local model
    local size
    
    vendor=$(udevadm info --query=property --name="$device" | grep ID_VENDOR= | cut -d= -f2 || echo "Unknown")
    model=$(udevadm info --query=property --name="$device" | grep ID_MODEL= | cut -d= -f2 || echo "Unknown")
    size=$(blockdev --getsize64 "$device" 2>/dev/null || echo "Unknown")
    size_human=$(human_readable_size "$size")
    
    echo "Device: $device"
    echo "Vendor: $vendor"
    echo "Model: $model"
    echo "Size: $size_human"
    
    # Check if the device is partitioned
    local partitions
    partitions=$(lsblk -no NAME "$device" | grep -v "$(basename "$device")" | wc -l)
    
    if [ "$partitions" -gt 0 ]; then
        echo "Partitions: $partitions"
        
        # Show information for each partition
        lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$device"
    else
        echo "Partitions: None"
    fi
    
    # Check for bad blocks (non-destructive read-only test)
    if confirm "Do you want to perform a basic read test? This may take a while but won't modify any data." false; then
        print_info "Testing device for reading errors (press Ctrl+C to abort)..."
        badblocks -sv -b 4096 -c 10240 -n "$device"
        
        if [ $? -eq 0 ]; then
            print_success "No bad blocks found."
        else
            print_error "Bad blocks detected. This USB drive may be failing."
        fi
    fi
    
    read -p "Press [Enter] to return to the main menu..."
    return 0
}

# Main function
main() {
    # Initialize script
    initialize_script
    
    # Parse arguments
    parse_arguments "$@"
    
    # Show help and exit if requested
    if [ "$SHOW_HELP" = true ]; then
        show_help
        exit 0
    fi
    
    # Main loop
    while true; do
        show_main_menu
        local choice=$?
        
        case $choice in
            0) create_new_usb ;;
            1) add_ai_model ;;
            2) verify_usb_health ;;
            3) view_download_history ;;
            4) show_about ;;
            5) exit_application ;; # Use our enhanced exit function with goodbye screen
            *) print_error "Invalid selection" ;;
        esac
    done
}

# Run the main function
main "$@"


