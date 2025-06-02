#!/bin/bash
# ==============================================================================
# Leonardo AI Universal - Multi-Environment LLM Deployment System
# ==============================================================================
# AUTOMATICALLY ASSEMBLED SCRIPT - DO NOT EDIT DIRECTLY
# Generated on: 2025-06-01 10:49:27
# Generator: assemble.sh v6.0.0
# ==============================================================================

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'



# ==============================================================================
# Component: 00_core/header.sh
# ==============================================================================
#!/bin/bash
# ==============================================================================
# Leonardo AI Universal - Core Header
# ==============================================================================
# Description: Main script header and initialization
# Author: Leonardo AI Team
# Version: 6.0.0
# License: MIT
# ==============================================================================

# Set umask for secure file creation
umask 077

# Script information
SCRIPT_TITLE="Leonardo AI Universal"
SCRIPT_VERSION="6.0.0"
SCRIPT_AUTHOR="Eric™ & The Leonardo AI Team"
SCRIPT_LICENSE="MIT"
SCRIPT_REPO="https://github.com/leonardo-ai/universal-deployer"
SCRIPT_SELF_NAME=$(basename "$0")

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

# Track installation start time
INSTALL_START_TIME=$(date +%s)

# Welcome message (will be displayed by UI functions later)
WELCOME_MESSAGE="Welcome to Leonardo AI Universal - the multi-environment LLM deployment system"



# ==============================================================================
# Component: 00_core/termfix.sh
# ==============================================================================
# ==============================================================================
# Leonardo AI Universal - Terminal Environment Fix
# ==============================================================================
# Description: Ensures TERM variable is set to avoid errors
# Author: Leonardo AI Team
# Version: 6.0.0
# ==============================================================================

# Set default TERM if not defined
if [[ -z "$TERM" ]]; then
    export TERM=xterm-256color
fi



# ==============================================================================
# Component: 00_core/config.sh
# ==============================================================================
# ==============================================================================
# Global Configuration
# ==============================================================================

# Global variables
SHOW_HELP=false
export VERBOSE=false

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

# Target deployment environments
DEPLOYMENT_ENVIRONMENTS=(
    "usb:USB Drive (portable, works across devices)"
    "local:Local Installation (runs on this machine only)"
    "container:Container (Docker/Podman)"
    "cloud:Cloud Instance (AWS, GCP, Azure)"
    "airgap:Air-Gapped Environment (completely offline)"
)

# Model configuration
DEFAULT_MODEL="llama3-8b"  # Default model to use
SUPPORTED_MODELS=(
    "llama3-8b:Meta LLaMA 3 8B (general purpose, low resource)"
    "llama3-70b:Meta LLaMA 3 70B (high performance, resource intensive)"
    "mistral-7b:Mistral 7B (efficient, strong instruction following)"
    "mixtral-8x7b:Mixtral 8x7B (mixture of experts, best for complex tasks)"
    "claude-instant:Anthropic Claude Instant (fast, efficient chat)"
    "claude-3-opus:Anthropic Claude 3 Opus (extremely powerful reasoning)"
    "gemma-7b:Google Gemma 7B (efficient, balanced performance)"
    "gemma-2b:Google Gemma 2B (ultra-lightweight, mobile-friendly)"
)

# Operation modes
OPERATION_MODES=(
    "create:Create a new deployment"
    "verify:Verify deployment integrity"
    "health:Check deployment health"
    "update:Update the script or models"
    "help:Show help information"
)

# UI configuration
UI_WIDTH=80
UI_PADDING=2
UI_BORDER_CHAR="═"
UI_HEADER_CHAR="─"
UI_FOOTER_CHAR="─"
UI_SECTION_CHAR="─"

# Llama warning levels (based on memory f17ef71f)
LLAMA_NORMAL="(•ᴗ•)🦙"  # Friendly llama for normal operations
LLAMA_CAUTION="(>‿-)🦙"  # Mischievous winking llama for first level caution
LLAMA_DANGER="(ಠ‿ಠ)🦙"   # Intense/crazy-eyed llama for serious warnings
LLAMA_COLOR_NORMAL="\e[33m"  # Yellow
LLAMA_COLOR_CAUTION="\e[38;5;208m"  # Orange
LLAMA_COLOR_DANGER="\e[31m"  # Red

# Temporary directory for script operations
TMP_DIR="${TMPDIR:-/tmp}/leonardo-universal-$USER"

# Create temporary directory if it doesn't exist
mkdir -p "$TMP_DIR"

# Log file location
LOG_DIR="${TMP_DIR}/logs"
LOG_FILE="${LOG_DIR}/leonardo-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# Download directory for model files and other resources
DOWNLOAD_DIR="${TMP_DIR}/downloads"
mkdir -p "$DOWNLOAD_DIR"

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

# USB Drive Lifecycle Management
USB_HEALTH_TRACKING=true
USB_HEALTH_DATA_FILE="" # Will be set based on the USB drive path
USB_WRITE_CYCLE_COUNTER=0
USB_FIRST_USE_DATE=""
USB_TOTAL_BYTES_WRITTEN=0
USB_MODEL=""
USB_SERIAL=""
USB_ESTIMATED_LIFESPAN=0 # In write cycles

# Download history tracking
DOWNLOAD_HISTORY=()
DOWNLOAD_SIZES=()
DOWNLOAD_TIMESTAMPS=()
DOWNLOAD_DESTINATIONS=()
DOWNLOAD_STATUS=()
TOTAL_BYTES_DOWNLOADED=0

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_CRITICAL=4

# Default log level (can be overridden by command line)
LOG_LEVEL=$LOG_LEVEL_INFO

# Arrays for device detection (based on memory 8c229535)
_CASCADE_USB_PATHS=()
_CASCADE_USB_DISPLAY_STRINGS=()



# ==============================================================================
# Component: 00_core/colors.sh
# ==============================================================================
# ==============================================================================
# Terminal Color Initialization and Management
# ==============================================================================
# Description: Handle color output with graceful fallbacks
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh
# ==============================================================================

# Initialize color variables
init_colors() {
    # Check if colors should be disabled
    if [[ "$NO_COLOR" == "true" || "$TERM" == "dumb" ]]; then
        HAS_COLORS=false
    fi
    
    # Reset all color variables
    NC=""            # No color (reset)
    BLACK=""         # Black
    RED=""           # Red
    GREEN=""         # Green
    YELLOW=""        # Yellow
    BLUE=""          # Blue
    MAGENTA=""       # Magenta
    CYAN=""          # Cyan
    WHITE=""         # White
    BOLD=""          # Bold
    DIM=""           # Dim
    UNDERLINE=""     # Underline
    BLINK=""         # Blink
    INVERT=""        # Invert
    
    # Background colors
    BLACK_BG=""      # Black background
    RED_BG=""        # Red background
    GREEN_BG=""      # Green background
    YELLOW_BG=""     # Yellow background
    BLUE_BG=""       # Blue background
    MAGENTA_BG=""    # Magenta background
    CYAN_BG=""       # Cyan background
    WHITE_BG=""      # White background
    RESET_BOLD=""    # Reset bold
    RESET_DIM=""     # Reset dim
    RESET_UNDERLINE="" # Reset underline
    RESET_BLINK=""   # Reset blink
    RESET_INVERT=""  # Reset invert
    
    # Background colors
    BG_BLACK=""      # Background Black
    BG_RED=""        # Background Red
    BG_GREEN=""      # Background Green
    BG_YELLOW=""     # Background Yellow
    BG_BLUE=""       # Background Blue
    BG_MAGENTA=""    # Background Magenta
    BG_CYAN=""       # Background Cyan
    BG_WHITE=""      # Background White
    
    # Only set colors if terminal supports them
    if [[ "$HAS_COLORS" == "true" ]]; then
        # Basic colors
        NC="\e[0m"              # No color (reset)
        BLACK="\e[30m"          # Black
        RED="\e[31m"            # Red
        GREEN="\e[32m"          # Green
        YELLOW="\e[33m"         # Yellow
        BLUE="\e[34m"           # Blue
        MAGENTA="\e[35m"        # Magenta
        CYAN="\e[36m"           # Cyan
        WHITE="\e[37m"          # White
        
        # Text formatting
        BOLD="\e[1m"            # Bold
        DIM="\e[2m"             # Dim
        UNDERLINE="\e[4m"       # Underline
        BLINK="\e[5m"           # Blink
        INVERT="\e[7m"          # Invert
        RESET_BOLD="\e[21m"     # Reset bold
        RESET_DIM="\e[22m"      # Reset dim
        RESET_UNDERLINE="\e[24m" # Reset underline
        RESET_BLINK="\e[25m"    # Reset blink
        RESET_INVERT="\e[27m"   # Reset invert
        
        # Background colors
        BG_BLACK="\e[40m"       # Background Black
        BG_RED="\e[41m"         # Background Red
        BG_GREEN="\e[42m"       # Background Green
        BG_YELLOW="\e[43m"      # Background Yellow
        BG_BLUE="\e[44m"        # Background Blue
        BG_MAGENTA="\e[45m"     # Background Magenta
        BG_CYAN="\e[46m"        # Background Cyan
        BG_WHITE="\e[47m"       # Background White
        
        # Set the llama warning colors
        LLAMA_COLOR_NORMAL="$YELLOW"
        LLAMA_COLOR_CAUTION="\e[38;5;208m"  # Orange (using 256-color)
        LLAMA_COLOR_DANGER="$RED"
    fi
    
    # Export color variables for use in other scripts
    export NC BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
    export BOLD DIM UNDERLINE BLINK INVERT
    export RESET_BOLD RESET_DIM RESET_UNDERLINE RESET_BLINK RESET_INVERT
    export BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
    export LLAMA_COLOR_NORMAL LLAMA_COLOR_CAUTION LLAMA_COLOR_DANGER
}

# Function to colorize text with graceful degradation
colorize() {
    local color_code="$1"
    local text="$2"
    
    if [[ "$HAS_COLORS" == "true" ]]; then
        echo -e "${color_code}${text}${NC}"
    else
        echo "$text"
    fi
}

# Function to get box drawing characters with UTF-8 or ASCII fallback
get_box_chars() {
    if [[ "$LEONARDO_ASCII_UI" == "true" ]]; then
        # ASCII fallbacks for box drawing
        BOX_H="-"        # Horizontal line
        BOX_V="|"        # Vertical line
        BOX_TL="+"       # Top left corner
        BOX_TR="+"       # Top right corner
        BOX_BL="+"       # Bottom left corner
        BOX_BR="+"       # Bottom right corner
        BOX_LT="+"       # Left T-junction
        BOX_RT="+"       # Right T-junction
        BOX_TT="+"       # Top T-junction
        BOX_BT="+"       # Bottom T-junction
        BOX_CROSS="+"    # Cross junction
    else
        # UTF-8 box drawing characters
        BOX_H="─"        # Horizontal line
        BOX_V="│"        # Vertical line
        BOX_TL="┌"       # Top left corner
        BOX_TR="┐"       # Top right corner
        BOX_BL="└"       # Bottom left corner
        BOX_BR="┘"       # Bottom right corner
        BOX_LT="├"       # Left T-junction
        BOX_RT="┤"       # Right T-junction
        BOX_TT="┬"       # Top T-junction
        BOX_BT="┴"       # Bottom T-junction
        BOX_CROSS="┼"    # Cross junction
    fi
    
    # Export box drawing characters
    export BOX_H BOX_V BOX_TL BOX_TR BOX_BL BOX_BR BOX_LT BOX_RT BOX_TT BOX_BT BOX_CROSS
}

# Initialize colors
init_colors

# Get box characters
get_box_chars



# ==============================================================================
# Component: 00_core/logging.sh
# ==============================================================================
# ==============================================================================
# Logging System
# ==============================================================================
# Description: Advanced logging with levels, timestamps and file output
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/colors.sh
# ==============================================================================

# Initialize log file
init_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Create log file with header
    cat > "$LOG_FILE" << EOF
# ====================================================================
# Leonardo AI Universal - Log File
# ====================================================================
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# User: $USER
# System: $(uname -a)
# Script Version: $SCRIPT_VERSION
# ====================================================================

EOF

    # Log startup message
    log_message "INFO" "Logging initialized at $(date '+%Y-%m-%d %H:%M:%S')"
    log_message "INFO" "Leonardo AI Universal $SCRIPT_VERSION starting up"
    
    # Log system information
    log_message "DEBUG" "System: $(uname -a)"
    log_message "DEBUG" "User: $USER"
    log_message "DEBUG" "Working directory: $(pwd)"
    log_message "DEBUG" "Script path: $SCRIPT_PATH"
    
    # Log terminal capabilities
    log_message "DEBUG" "Terminal: $TERM"
    log_message "DEBUG" "Has colors: $HAS_COLORS"
    log_message "DEBUG" "Terminal size: ${TERM_COLS}x${TERM_ROWS}"
    log_message "DEBUG" "UTF-8 UI: $(if [[ "$LEONARDO_ASCII_UI" == "true" ]]; then echo "disabled"; else echo "enabled"; fi)"
}

# Log a message with timestamp and level
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local numeric_level
    
    # Convert level string to numeric value
    case "$level" in
        "DEBUG")    numeric_level=$LOG_LEVEL_DEBUG ;;
        "INFO")     numeric_level=$LOG_LEVEL_INFO ;;
        "WARNING")  numeric_level=$LOG_LEVEL_WARNING ;;
        "ERROR")    numeric_level=$LOG_LEVEL_ERROR ;;
        "CRITICAL") numeric_level=$LOG_LEVEL_CRITICAL ;;
        *)          numeric_level=$LOG_LEVEL_INFO ;;
    esac
    
    # Only log if the level is at or above the configured log level
    if [[ $numeric_level -ge $LOG_LEVEL ]]; then
        # Write to log file
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
        
        # Print to stderr for ERROR and CRITICAL
        if [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
            echo -e "${RED}[$level] $message${NC}" >&2
        # Print to stdout for other levels if verbose
        elif [[ "$level" == "DEBUG" && "$VERBOSE" == "true" ]] || [[ "$level" != "DEBUG" && "$QUIET" != "true" ]]; then
            case "$level" in
                "DEBUG")    echo -e "${BLUE}[$level] $message${NC}" ;;
                "INFO")     echo -e "${GREEN}[$level] $message${NC}" ;;
                "WARNING")  echo -e "${YELLOW}[$level] $message${NC}" ;;
                *)          echo -e "[$level] $message" ;;
            esac
        fi
    fi
}

# Log a command execution for audit
log_command() {
    local command="$1"
    local result="$2"
    local exit_code="$3"
    
    log_message "DEBUG" "Command executed: $command"
    log_message "DEBUG" "Command exit code: $exit_code"
    
    # Log truncated output if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        # Truncate result if too long
        local truncated_result
        if [[ "${#result}" -gt 500 ]]; then
            truncated_result="${result:0:500}... [truncated, full output in log file]"
        else
            truncated_result="$result"
        fi
        log_message "DEBUG" "Command output: $truncated_result"
    fi
    
    # Always log full output to file
    echo "=== COMMAND OUTPUT BEGIN ===" >> "$LOG_FILE"
    echo "$result" >> "$LOG_FILE"
    echo "=== COMMAND OUTPUT END ===" >> "$LOG_FILE"
}

# Log an error and exit
log_error_and_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_message "CRITICAL" "$message"
    log_message "CRITICAL" "Exiting with code $exit_code"
    exit "$exit_code"
}

# Log a warning but continue
log_warning() {
    local message="$1"
    log_message "WARNING" "$message"
}

# Handle a trapped signal
handle_signal() {
    local signal="$1"
    log_message "CRITICAL" "Received signal $signal"
    log_message "CRITICAL" "Performing emergency cleanup"
    
    # Call cleanup function if it exists
    if type cleanup_on_exit &>/dev/null; then
        cleanup_on_exit
    fi
    
    log_message "CRITICAL" "Exiting due to signal $signal"
    exit 128
}

# Set up signal handlers
setup_signal_handlers() {
    trap 'handle_signal INT' INT
    trap 'handle_signal TERM' TERM
    trap 'handle_signal HUP' HUP
}

# Log start of a major operation
log_operation_start() {
    local operation="$1"
    log_message "INFO" "Starting operation: $operation"
}

# Log completion of a major operation
log_operation_complete() {
    local operation="$1"
    local status="$2"
    local duration="$3"
    
    if [[ "$status" == "0" ]]; then
        log_message "INFO" "Operation completed successfully: $operation (Duration: ${duration}s)"
    else
        log_message "ERROR" "Operation failed: $operation (Duration: ${duration}s, Exit code: $status)"
    fi
}

# Initialize logging with proper signal handlers
setup_signal_handlers
init_logging



# ==============================================================================
# Component: 02_ui/basic.sh
# ==============================================================================
# ==============================================================================
# Basic UI Components
# ==============================================================================
# Description: Basic UI components for Leonardo AI Universal
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/colors.sh
# ==============================================================================

# Clear the screen if possible
clear_screen() {
    if [[ "$TPUT_CLEAR_POSSIBLE" == "true" ]]; then
        "$TPUT_CMD_PATH" clear
    else
        echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
    fi
}

# Create a horizontal line of specified length and character
print_line() {
    local length="$1"
    local char="${2:-$BOX_H}"
    local color="${3:-$NC}"
    
    # Print the line
    printf "${color}%*s${NC}\n" "$length" | tr ' ' "$char"
}

# Print a string centered in a box of specified width
print_centered() {
    local text="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$NC}"
    
    # Remove ANSI color codes for length calculation
    local plain_text
    plain_text=$(echo -e "$text" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    
    # Calculate padding
    local padding=$(( (width - ${#plain_text}) / 2 ))
    
    # If padding is negative, truncate the text
    if [[ $padding -lt 0 ]]; then
        text="${text:0:$width-3}..."
        padding=0
    fi
    
    # Print the centered text
    printf "%*s${color}%s${NC}%*s\n" $padding "" "$text" $padding ""
}

# Print a box line with the given character
print_box_line() {
    local char="$1"
    local width="${2:-$UI_WIDTH}"
    local left_char="${3:-$char}"
    local right_char="${4:-$char}"
    local color="${5:-$NC}"
    
    # Calculate the inner width
    local inner_width=$((width - 2))
    
    # Print the box line
    printf "${color}%s%*s%s${NC}\n" "$left_char" "$inner_width" | tr ' ' "$char" | tr -d '\n'
    printf "%s\n" "$right_char"
}

# Print a box with a title
print_box_header() {
    local title="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$CYAN}"
    
    # Print the top border
    print_box_line "$BOX_H" "$width" "$BOX_TL" "$BOX_TR" "$color"
    
    # Print the title if provided
    if [[ -n "$title" ]]; then
        printf "${color}${BOX_V}${NC} %-$((width-4))s ${color}${BOX_V}${NC}\n" "$title"
        print_box_line "$BOX_H" "$width" "$BOX_LT" "$BOX_RT" "$color"
    fi
}

# Print a box footer
print_box_footer() {
    local width="${1:-$UI_WIDTH}"
    local color="${2:-$CYAN}"
    
    # Print the bottom border
    print_box_line "$BOX_H" "$width" "$BOX_BL" "$BOX_BR" "$color"
}

# Print box content with left and right borders
print_box_content() {
    local text="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$CYAN}"
    local left_pad="${4:-1}"
    local right_pad="${5:-1}"
    
    # Calculate content width (accounting for borders and padding)
    local content_width=$((width - 2 - left_pad - right_pad))
    
    # Wrap text to content width and add borders
    echo -e "$text" | fold -s -w "$content_width" | while IFS= read -r line; do
        printf "${color}${BOX_V}${NC}%*s%-*s${color}${BOX_V}${NC}\n" "$left_pad" "" "$((content_width + right_pad))" "$line"
    done
}

# Print a complete box with title and content
print_box() {
    local title="$1"
    local content="$2"
    local width="${3:-$UI_WIDTH}"
    local color="${4:-$CYAN}"
    
    print_box_header "$title" "$width" "$color"
    print_box_content "$content" "$width" "$color"
    print_box_footer "$width" "$color"
}

# Print a title for a section
print_section_title() {
    local title="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$YELLOW}"
    
    echo ""
    print_line "$width" "$UI_SECTION_CHAR" "$color"
    print_centered "${BOLD}${color}${title}${NC}" "$width"
    print_line "$width" "$UI_SECTION_CHAR" "$color"
    echo ""
}

# Print a banner for the application
print_banner() {
    clear_screen
    
    # Calculate banner width
    local banner_width="$UI_WIDTH"
    
    # Colors for the banner
    local banner_color="$CYAN"
    local version_color="$GREEN"
    
    cat << EOF

$banner_color
  _                                    _          _    ___ 
 | |    ___  ___  _ __   __ _ _ __ __| | ___    / \  |_ _|
 | |   / _ \/ _ \| '_ \ / _\` | '__/ _\` |/ _ \  / _ \  | | 
 | |__|  __/ (_) | | | | (_| | | | (_| | (_) |/ ___ \ | | 
 |_____\___|\___/|_| |_|\__,_|_|  \__,_|\___/_/   \_\___|
                                                          
 ${version_color}Universal - Multi-Environment LLM Deployment System${NC}
 
EOF
    
    print_line "$banner_width" "$UI_BORDER_CHAR" "$banner_color"
    print_centered "${banner_color}Version ${SCRIPT_VERSION} | ${SCRIPT_LICENSE} License${NC}" "$banner_width"
    print_line "$banner_width" "$UI_BORDER_CHAR" "$banner_color"
    echo ""
}

# Print a step banner for longer operations
print_step_banner() {
    local step_number="$1"
    local step_title="$2"
    local total_steps="${3:-4}"
    local width="${4:-$UI_WIDTH}"
    local step_color="${5:-$CYAN}"
    
    # Clear the screen
    clear_screen
    
    # Print the main banner in compact form
    echo -e "${step_color}Leonardo AI Universal ${NC}${BOLD}|${NC} ${GREEN}Version ${SCRIPT_VERSION}${NC}"
    print_line "$width" "$UI_HEADER_CHAR" "$step_color"
    
    # Calculate progress percentage
    local progress=$((step_number * 100 / total_steps))
    
    # Print step information
    echo -e "${BOLD}Step ${step_number} of ${total_steps}:${NC} ${step_title} ${DIM}(${progress}% complete)${NC}"
    
    # Print a visual progress bar
    local bar_width=$((width - 10))
    local filled_width=$((bar_width * step_number / total_steps))
    local empty_width=$((bar_width - filled_width))
    
    printf "${step_color}[${NC}"
    printf "%${filled_width}s" | tr ' ' '#'
    printf "%${empty_width}s" | tr ' ' '-'
    printf "${step_color}]${NC}\n"
    
    print_line "$width" "$UI_HEADER_CHAR" "$step_color"
    echo ""
}

# Print a success message
print_success() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    echo ""
    print_box_header "SUCCESS" "$width" "$GREEN"
    print_box_content "$message" "$width" "$GREEN"
    print_box_footer "$width" "$GREEN"
    echo ""
}

# Print an error message
print_error() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    echo ""
    print_box_header "ERROR" "$width" "$RED"
    print_box_content "$message" "$width" "$RED"
    print_box_footer "$width" "$RED"
    echo ""
}

# Print a hint message
print_hint() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    echo -e "${BLUE}${BOLD}Hint:${NC} $message"
}

# Print a spinner for long-running operations
start_spinner() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spinstr='|/-\'
    
    # Don't show spinner in quiet mode
    if [[ "$QUIET" == "true" ]]; then
        return
    fi
    
    # Start the spinner in background
    echo -e -n "${CYAN}${message}${NC} "
    
    # If we're not in a terminal, don't use the spinner
    if ! [[ -t 1 ]]; then
        echo -n "..."
        return
    fi
    
    # Run the spinner
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    
    # Clear the spinner
    printf "   \b\b\b"
    echo -e "${GREEN}[Done]${NC}"
}

# Wait for a keypress
wait_for_key() {
    local message="${1:-Press any key to continue...}"
    
    echo -e "$message"
    read -r -n 1 -s
    echo ""
}

# Show a welcome message
show_welcome() {
    print_banner
    
    # Print welcome message
    print_box_header "Welcome" "$UI_WIDTH" "$GREEN"
    print_box_content "$WELCOME_MESSAGE" "$UI_WIDTH" "$GREEN"
    print_box_footer "$UI_WIDTH" "$GREEN"
    
    # Show UTF-8 warning if needed
    if [[ -n "$LEONARDO_UTF8_WARNING" ]]; then
        echo -e "$LEONARDO_UTF8_WARNING"
    fi
    
    echo ""
    wait_for_key
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

# Get user input directly from /dev/tty
get_user_input() {
    local prompt_message="$1"
    local result_var_name="$2"
    local input_value

    echo -n "$prompt_message" >&2 # Print prompt to stderr
    read -r input_value          # Read from stdin
    
    # Trim leading/trailing whitespace (optional, but good practice)
    input_value=$(echo "$input_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    eval "$result_var_name=\"$input_value\""
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
# Component: 02_ui/warnings.sh
# ==============================================================================
# ==============================================================================
# Warning System
# ==============================================================================
# Description: Graduated warning system with llama mascots for different severity levels
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/colors.sh,02_ui/basic.sh
# ==============================================================================

# Print a message with appropriate llama mascot and severity color
# Based on memory f17ef71f - Implemented progression of warning severities
print_llama_message() {
    local severity="$1"  # normal, caution, danger
    local message="$2"
    local width="${3:-$UI_WIDTH}"
    
    local llama_icon=""
    local llama_color=""
    local box_color=""
    local title=""
    
    # Ensure we have box drawing characters defined
    # Force ASCII mode for better compatibility
    LEONARDO_ASCII_UI=true
    get_box_chars
    
    # Set the appropriate llama mascot and colors based on severity
    case "$severity" in
        "normal")
            llama_icon="$LLAMA_NORMAL"
            llama_color="$LLAMA_COLOR_NORMAL"
            box_color="$YELLOW"
            title="NOTICE"
            ;;
        "caution")
            llama_icon="$LLAMA_CAUTION"
            llama_color="$LLAMA_COLOR_CAUTION"
            box_color="$LLAMA_COLOR_CAUTION"
            title="CAUTION"
            ;;
        "danger")
            llama_icon="$LLAMA_DANGER"
            llama_color="$LLAMA_COLOR_DANGER"
            box_color="$RED"
            title="⚠️ WARNING ⚠️"
            ;;
        *)
            llama_icon="$LLAMA_NORMAL"
            llama_color="$LLAMA_COLOR_NORMAL"
            box_color="$YELLOW"
            title="NOTICE"
            ;;
    esac
    
    # Create a helper function for box line printing (for consistent formatting)
    local _print_box_line
    _print_box_line() {
        print_box_line "$BOX_H" "$width" "$1" "$2" "$box_color"
    }
    
    # Print the message box with llama mascot
    echo ""
    _print_box_line "$BOX_TL" "$BOX_TR"
    
    # Print title if provided
    printf "${box_color}${BOX_V}${NC} ${BOLD}${box_color}%s${NC}%*s ${box_color}${BOX_V}${NC}\n" "$title" $((width - ${#title} - 4)) ""
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print llama mascot
    printf "${box_color}${BOX_V}${NC} ${llama_color}%s${NC}%*s ${box_color}${BOX_V}${NC}\n" "$llama_icon" $((width - ${#llama_icon} - 4)) ""
    
    # Print the message
    print_box_content "$message" "$width" "$box_color" 2 2
    
    # Print the bottom of the box
    _print_box_line "$BOX_BL" "$BOX_BR"
    echo ""
}

# Show a friendly notice (normal operations)
show_notice() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    print_llama_message "normal" "$message" "$width"
}

# Show a caution warning (first level warning)
show_caution() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    print_llama_message "caution" "$message" "$width"
}

# Show a danger warning (most severe)
show_danger() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    print_llama_message "danger" "$message" "$width"
}

# Show detailed data destruction warning
# Based on memory 0f09a1d0 - Enhanced data destruction warning
show_data_destruction_warning() {
    local device="$1"
    local operation="${2:-Format USB Drive}"
    local width="${3:-$UI_WIDTH}"
    
    # Create a helper function for box line printing (for consistent formatting)
    local _print_box_line
    _print_box_line() {
        print_box_line "$BOX_H" "$width" "$1" "$2" "$RED"
    }
    
    # Print the warning box
    echo ""
    _print_box_line "$BOX_TL" "$BOX_TR"
    
    # Print title
    print_centered "${BOLD}${RED}⚠️ DATA DESTRUCTION IMMINENT ⚠️${NC}" "$width"
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print llama mascot with message
    printf "${RED}${BOX_V}${NC} ${RED}${LLAMA_DANGER} ${BOLD}THIS IS YOUR FINAL WARNING!${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 30 - ${#LLAMA_DANGER})) ""
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print operation details
    printf "${RED}${BOX_V}${NC} ${BOLD}Target Device:${NC} %-$((width-20))s ${RED}${BOX_V}${NC}\n" "$device"
    printf "${RED}${BOX_V}${NC} ${BOLD}Operation:${NC} %-$((width-16))s ${RED}${BOX_V}${NC}\n" "$operation"
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print consequences
    printf "${RED}${BOX_V}${NC} ${BOLD}This operation will:${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 21)) ""
    printf "${RED}${BOX_V}${NC}   • ${BOLD}${RED}PERMANENTLY ERASE ALL DATA${NC} on the device%*s ${RED}${BOX_V}${NC}\n" $((width - 51)) ""
    printf "${RED}${BOX_V}${NC}   • ${BOLD}${RED}DELETE ALL EXISTING PARTITIONS${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 41)) ""
    printf "${RED}${BOX_V}${NC}   • ${BOLD}${RED}DESTROY ALL FILE SYSTEMS${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 36)) ""
    _print_box_line "$BOX_LT" "$BOX_RT"
    
    # Print verification reminders
    printf "${RED}${BOX_V}${NC} ${BOLD}Before continuing, verify:${NC}%*s ${RED}${BOX_V}${NC}\n" $((width - 28)) ""
    printf "${RED}${BOX_V}${NC}   • You have backed up all important data%*s ${RED}${BOX_V}${NC}\n" $((width - 47)) ""
    printf "${RED}${BOX_V}${NC}   • You are targeting the correct device%*s ${RED}${BOX_V}${NC}\n" $((width - 45)) ""
    printf "${RED}${BOX_V}${NC}   • You understand this action is irreversible%*s ${RED}${BOX_V}${NC}\n" $((width - 50)) ""
    
    # Print the bottom of the box
    _print_box_line "$BOX_BL" "$BOX_BR"
    echo ""
}

# Request user confirmation with appropriate warning level
confirm_action() {
    local message="$1"
    local severity="${2:-normal}"  # normal, caution, danger
    local default="${3:-n}"        # y or n
    
    # Show the warning with appropriate llama
    case "$severity" in
        "normal") show_notice "$message" ;;
        "caution") show_caution "$message" ;;
        "danger") show_danger "$message" ;;
    esac
    
    # Set up prompt based on default
    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="Continue? [Y/n]: "
    else
        prompt="Continue? [y/N]: "
    fi
    
    # Ask for confirmation
    local response
    echo -n "$prompt"
    read -r response
    
    # Process response
    response="${response:-$default}"
    case "${response,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# Verify dangerous operation with double confirmation
verify_dangerous_operation() {
    local message="$1"
    local device="$2"
    local operation="$3"
    
    # First confirmation with caution level
    if ! confirm_action "$message" "caution"; then
        return 1
    fi
    
    # Show detailed destruction warning
    show_data_destruction_warning "$device" "$operation"
    
    # Final confirmation with danger level
    local final_message="Type 'YES, I AM SURE' (all uppercase) to confirm you want to proceed:"
    echo -e "$final_message"
    
    local response
    read -r response
    
    if [[ "$response" == "YES, I AM SURE" ]]; then
        return 0
    else
        echo -e "\n${YELLOW}Operation cancelled by user.${NC}"
        return 1
    fi
}



# ==============================================================================
# Component: 03_filesystem/device.sh
# ==============================================================================
# ==============================================================================
# Device Management
# ==============================================================================
# Description: USB device detection, selection, and verification
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,02_ui/warnings.sh
# ==============================================================================

# Check if a path is a block device
# Returns 0 if it is, 1 if not
is_block_device() {
    local device_path="$1"
    
    if [[ -b "$device_path" ]]; then
        log_message "DEBUG" "Device $device_path is a block device"
        return 0
    else
        log_message "DEBUG" "Device $device_path is NOT a block device"
        return 1
    fi
}

# List all USB devices and populate global arrays
# Based on memory 8c229535 and c41e31f6
list_usb_devices() {
    log_message "DEBUG" "Scanning for USB devices"
    
    # Reset global arrays
    _CASCADE_USB_PATHS=()
    _CASCADE_USB_DISPLAY_STRINGS=()
    
    # In test mode, add a test device and return early
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        log_message "DEBUG" "Test mode: Adding dummy test device"
        _CASCADE_USB_PATHS+=("/dev/testdisk")
        _CASCADE_USB_DISPLAY_STRINGS+=("TestDisk (16G - Leonardo Test Device)")
        return 0
    fi
    
    # Get list of all block devices
    echo "DEBUG: list_usb_devices - About to run lsblk" >&2
    log_message "DEBUG" "Running lsblk to get device list"
    local lsblk_output
    lsblk_output=$(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null)
    echo "DEBUG: list_usb_devices - lsblk command finished." >&2
    log_message "DEBUG" "lsblk output: $lsblk_output"
    echo "DEBUG: list_usb_devices - lsblk output captured:" >&2
    echo "$lsblk_output" >&2
    
    # Process each device from lsblk output
    echo "DEBUG: list_usb_devices - Starting to process lsblk output lines." >&2
    local line_num=0
    while IFS= read -r line; do
        echo "DEBUG: list_usb_devices - Processing line #$line_num: [$line]" >&2
        line_num=$((line_num + 1))

        # Robust parsing using Bash regex for: NAME SIZE MODEL TRAN RM
        # Example line: /dev/sdc    114.6G Cruzer Glide            usb     1
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)[[:space:]]+(usb|sata|ide|scsi|nvme)[[:space:]]+([01])$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local size="${BASH_REMATCH[2]}"
            local model="${BASH_REMATCH[3]}"
            local tran="${BASH_REMATCH[4]}"
            local rm="${BASH_REMATCH[5]}"

            # Trim whitespace from model
            model=$(echo "$model" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -z "$model" ]; then
                model="-" # Placeholder if model is empty
            fi
            echo "DEBUG: list_usb_devices - Parsed: NAME='$name', SIZE='$size', MODEL='$model', TRAN='$tran', RM='$rm'" >&2
        else
            echo "DEBUG: list_usb_devices - Failed to parse line with regex: [$line]" >&2
            continue
        fi

        # Filter for USB devices that are removable
        if [[ "$tran" == "usb" && "$rm" == "1" ]]; then
            if [ -z "$name" ] || [ ! -b "$name" ]; then
                echo "DEBUG: list_usb_devices - Invalid device path or not a block device: [$name]. Skipping." >&2
                continue
            fi
            _CASCADE_USB_PATHS+=("$name")
            local display_string
            printf -v display_string "%-12s %-25.25s %s" "$name" "$model" "$size"
            _CASCADE_USB_DISPLAY_STRINGS+=("$display_string")
            echo "DEBUG: list_usb_devices - Added USB: $display_string" >&2
        else
            echo "DEBUG: list_usb_devices - Skipped (not USB or not removable): $name ($tran, $rm)" >&2
        fi
    done < <(echo "$lsblk_output")
        # Redundant block removed
    echo "DEBUG: list_usb_devices - Finished processing lsblk output lines." >&2
    
    # Log the found devices
    log_message "DEBUG" "Found ${#_CASCADE_USB_PATHS[@]} USB devices"
    
    # Return success if we found any devices
    if [[ ${#_CASCADE_USB_PATHS[@]} -gt 0 ]]; then
        log_message "INFO" "Found ${#_CASCADE_USB_PATHS[@]} USB devices"
        return 0
    else
        log_message "WARNING" "No USB devices found"
        return 1
    fi
}

# Show a menu to select a USB device
# Based on memory c41e31f6
select_usb_device() {
    # Check if we're in test mode - if so, handle test device selection
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        # If LEONARDO_TEST_USB is set, use that as the real device for testing
        if [[ -n "${LEONARDO_TEST_USB:-}" ]]; then
            log_message "DEBUG" "Test mode: using real USB device ${LEONARDO_TEST_USB}"
            echo "${LEONARDO_TEST_USB}"
            return 0
        else
            # Default test device if no real device specified
            log_message "DEBUG" "Test mode: auto-selecting test device /dev/testdisk"
            echo "/dev/testdisk"
            return 0
        fi
    fi
    
    # Show step banner
    print_step_banner "1" "Select USB Device"
    
    # Show scanning message
    echo -e "${CYAN}Scanning for USB devices...${NC}"
    echo ""
    
    # Get the list of USB devices
    echo "DEBUG: select_usb_device - About to call list_usb_devices" >&2
    if ! list_usb_devices; then
        echo "DEBUG: select_usb_device - list_usb_devices returned failure" >&2
        echo -e "${RED}No USB devices found.${NC}"
        echo ""
        echo "Please connect a USB drive and try again."
        echo ""
        wait_for_key "Press any key to rescan or Ctrl+C to exit..."
        return 1
    fi
    echo "DEBUG: select_usb_device - list_usb_devices returned successfully" >&2
    
    # Show the list of devices
    if [ ${#_CASCADE_USB_PATHS[@]} -eq 0 ]; then
        echo "No USB devices found." >/dev/tty # Output to TTY for user visibility
        echo "Please ensure your USB device is properly connected." >/dev/tty
        echo "Listing all block devices for diagnostics:" >&2 # Debug to stderr
        lsblk -dpno NAME,SIZE,MODEL,TRAN,RM >&2
        return 1
    fi

    echo "Available USB devices:" >/dev/tty
    printf "  %s   %-12s %-25s %s\n" "Num" "Device" "Model" "Size" >/dev/tty
    printf "  %s   %-12s %-25s %s\n" "--- " "------------" "-------------------------" "----" >/dev/tty
    for i in "${!_CASCADE_USB_DISPLAY_STRINGS[@]}"; do
        printf "  %2d) %s\n" "$((i+1))" "${_CASCADE_USB_DISPLAY_STRINGS[i]}" >/dev/tty
    done
    echo "" >/dev/tty # Extra newline for spacing
    
    # Option for manual entry
    echo "  m. Enter device path manually"
    echo ""
    
    # Get user selection
    local selection
    local device_path
    echo "DEBUG: select_usb_device - Entering selection loop" >&2
    while true; do
        echo "DEBUG: select_usb_device - Top of selection loop" >&2
        local prompt_msg="Select a device (1-${#_CASCADE_USB_PATHS[@]}, m for manual, q to quit): "
        echo "DEBUG: select_usb_device - About to get selection using get_user_input with prompt: [$prompt_msg]" >&2
        get_user_input "$prompt_msg" selection
        echo "DEBUG: select_usb_device - Read selection: [$selection]" >&2
        
        # Manual entry
        if [[ "$selection" == "m" || "$selection" == "M" ]]; then
            local manual_prompt_msg="Enter device path (e.g., /dev/sdb, or q to return): "
            echo "DEBUG: select_usb_device - About to get manual device_path using get_user_input with prompt: [$manual_prompt_msg]" >&2
            get_user_input "$manual_prompt_msg" device_path
            echo "DEBUG: select_usb_device - Read manual device_path: [$device_path]" >&2
            
            # Verify it's a block device
            if is_block_device "$device_path"; then
                break
            else
                echo -e "${RED}Not a valid block device.${NC} Please try again."
            fi
        # Numeric selection
        elif [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#_CASCADE_USB_PATHS[@]}" ]]; then
            device_path="${_CASCADE_USB_PATHS[$((selection-1))]}"
            break
        else
            echo -e "${RED}Invalid selection.${NC} Please try again."
        fi
    done
    
    # Return the selected device path
    echo "$device_path"
    return 0
}

# Verify a USB device selection with the user
verify_usb_device() {
    local device_path="$1"
    
    # In test mode, auto-confirm the device
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        # If we're using a real USB device in test mode
        if [[ -n "${LEONARDO_TEST_USB:-}" && "$device_path" == "${LEONARDO_TEST_USB}" ]]; then
            log_message "INFO" "Test mode: auto-confirming real USB device $device_path"
            
            # Show real device info if available
            echo ""
            echo -e "${CYAN}Selected real USB device (in test mode):${NC}"
            echo "  Device path: $device_path"
            
            # Try to get real device info if possible
            local size model vendor partitions
            size=$(lsblk -dn -o SIZE "$device_path" 2>/dev/null || echo "Unknown")
            model=$(lsblk -dn -o MODEL "$device_path" 2>/dev/null || echo "Unknown")
            vendor=$(lsblk -dn -o VENDOR "$device_path" 2>/dev/null || echo "Unknown")
            partitions=$(lsblk -ln "$device_path" 2>/dev/null | grep -v "^$(basename "$device_path")" | wc -l)
            
            echo "  Size: $size"
            echo "  Model: $model"
            echo "  Vendor: $vendor"
            echo "  Partitions: $partitions"
            echo ""
            echo -e "${YELLOW}Test mode: Real device automatically confirmed. NO ACTUAL FORMATTING will be performed.${NC}"
            return 0
        else
            # Use dummy test device info
            log_message "INFO" "Test mode: auto-confirming test device $device_path"
            
            # Show test device info
            echo ""
            echo -e "${CYAN}Selected test device details:${NC}"
            echo "  Device path: $device_path"
            echo "  Size: 16G (Test Device)"
            echo "  Model: Leonardo Test Device"
            echo "  Vendor: Test"
            echo "  Partitions: 0"
            echo ""
            echo -e "${YELLOW}Test mode: Device automatically confirmed.${NC}"
            return 0
        fi
    fi
    
    # Get device info for real device
    local device_size
    local device_model
    local device_vendor
    local device_parts
    
    device_size=$(lsblk -dno SIZE "$device_path" 2>/dev/null || echo "Unknown")
    device_model=$(lsblk -dno MODEL "$device_path" 2>/dev/null || echo "Unknown")
    device_vendor=$(lsblk -dno VENDOR "$device_path" 2>/dev/null || echo "Unknown")
    device_parts=$(lsblk -no NAME "$device_path" | grep -v "$(basename "$device_path")" | wc -l)
    
    # Clean up model name
    device_model="${device_model//_/ }"
    
    # Show device details
    echo ""
    echo -e "${CYAN}Selected device details:${NC}"
    echo "  Device path: $device_path"
    echo "  Size: $device_size"
    echo "  Model: $device_model"
    echo "  Vendor: $device_vendor"
    echo "  Partitions: $device_parts"
    echo ""
    
    # Confirm selection
    local message="You have selected $device_path ($device_size - $device_model).\nVerify this is the correct device before proceeding."
    if confirm_action "$message" "caution"; then
        log_message "INFO" "User confirmed device selection: $device_path"
        return 0
    else
        log_message "INFO" "User cancelled device selection"
        return 1
    fi
}

# Get device information for health tracking
get_device_info() {
    local device_path="$1"
    local info_type="$2"  # size, model, serial, vendor, etc.
    
    case "$info_type" in
        "size")
            lsblk -dno SIZE "$device_path" 2>/dev/null || echo "Unknown"
            ;;
        "model")
            lsblk -dno MODEL "$device_path" 2>/dev/null || echo "Unknown"
            ;;
        "serial")
            # Try to get serial number (requires root)
            local serial
            serial=$(udevadm info --query=property --name="$device_path" 2>/dev/null | grep ID_SERIAL= | cut -d= -f2)
            echo "${serial:-Unknown}"
            ;;
        "vendor")
            lsblk -dno VENDOR "$device_path" 2>/dev/null || echo "Unknown"
            ;;
        "partitions")
            lsblk -no NAME "$device_path" | grep -v "$(basename "$device_path")" | wc -l
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Get all mounted partitions for a device
get_device_partitions() {
    local device_path="$1"
    local base_name
    base_name=$(basename "$device_path")
    
    # Get all partitions
    lsblk -no NAME "$device_path" | grep -v "^$base_name$" | sed "s|^|/dev/|"
}

# Force unmount all partitions on a device
# Based on memory dd2b60d3
force_unmount_device() {
    local device_path="$1"
    local force="${2:-false}"
    local quiet="${3:-false}"
    local retries=3
    local success=false
    
    log_message "INFO" "Unmounting device: $device_path"
    
    # Function to log or echo based on quiet flag
    local _log_or_echo
    _log_or_echo() {
        log_message "INFO" "$1"
        if [[ "$quiet" != "true" ]]; then
            echo -e "$1"
        fi
    }
    
    # Get all partitions for this device
    local partitions=()
    mapfile -t partitions < <(get_device_partitions "$device_path")
    
    # Add the device itself to the list
    partitions+=("$device_path")
    
    # If there are no partitions, just return
    if [[ ${#partitions[@]} -eq 0 ]]; then
        _log_or_echo "No partitions found for $device_path"
        return 0
    fi
    
    _log_or_echo "Unmounting ${#partitions[@]} partitions on $device_path"
    
    for ((retry=1; retry<=retries; retry++)); do
        local all_unmounted=true
        
        # First try: Kill processes using the device
        if [[ "$retry" -ge 2 ]]; then
            _log_or_echo "Attempt $retry: Killing processes using the device..."
            for part in "${partitions[@]}"; do
                fuser -k "$part" 2>/dev/null || true
                lsof "$part" 2>/dev/null | awk '{print $2}' | grep -v PID | xargs -r kill 2>/dev/null || true
            done
        fi
        
        # Unmount all partitions
        for part in "${partitions[@]}"; do
            if mount | grep -q "$part "; then
                _log_or_echo "Unmounting $part..."
                
                # Try umount first
                if umount "$part" 2>/dev/null; then
                    _log_or_echo "Successfully unmounted $part"
                # If that fails and force is true, try more aggressive methods
                elif [[ "$force" == "true" ]]; then
                    _log_or_echo "Trying lazy unmount for $part..."
                    if umount -l "$part" 2>/dev/null; then
                        _log_or_echo "Successfully lazy-unmounted $part"
                    else
                        _log_or_echo "Failed to unmount $part (attempt $retry/$retries)"
                        all_unmounted=false
                    fi
                else
                    _log_or_echo "Failed to unmount $part (attempt $retry/$retries)"
                    all_unmounted=false
                fi
            fi
        done
        
        # If all partitions are unmounted, we're done
        if [[ "$all_unmounted" == "true" ]]; then
            success=true
            break
        fi
        
        # Sleep before next attempt
        sleep 2
    done
    
    # Try to reload the partition table
    if [[ "$success" == "true" || "$force" == "true" ]]; then
        _log_or_echo "Reloading partition table for $device_path..."
        
        # Try multiple methods (based on memory dd2b60d3)
        partprobe "$device_path" 2>/dev/null || true
        blockdev --rereadpt "$device_path" 2>/dev/null || true
        hdparm -z "$device_path" 2>/dev/null || true
        
        # Wait for device to settle
        udevadm settle 2>/dev/null || true
        sleep 1
        
        # Extra aggressive approach for stubborn devices
        if [[ "$force" == "true" ]]; then
            echo 1 > "/sys/block/$(basename "$device_path")/device/delete" 2>/dev/null || true
            sleep 1
            echo "- - -" > /sys/class/scsi_host/host*/scan 2>/dev/null || true
            udevadm settle 2>/dev/null || true
            sleep 2
        fi
    fi
    
    if [[ "$success" == "true" ]]; then
        _log_or_echo "Successfully unmounted device $device_path"
        return 0
    else
        _log_or_echo "Failed to unmount all partitions on $device_path after $retries attempts"
        return 1
    fi
}

# Format a USB device
format_usb_device() {
    local device_path="$1"
    local fs_type="${2:-$DEFAULT_FS_TYPE}"
    local part_type="${3:-$DEFAULT_PARTITION_TABLE}"
    local label="${4:-LEONARDO}"
    local force="${5:-false}"
    
    log_message "INFO" "Formatting device $device_path with $fs_type filesystem"
    
    # Confirm formatting with a danger warning
    local message="You are about to format $device_path with $fs_type filesystem.\nAll data on this device will be PERMANENTLY LOST."
    if ! verify_dangerous_operation "$message" "$device_path" "Format with $fs_type"; then
        log_message "INFO" "Format operation cancelled by user"
        return 1
    fi
    
    # Force unmount the device
    echo -e "${YELLOW}Unmounting device $device_path...${NC}"
    if ! force_unmount_device "$device_path" "true" "false"; then
        log_message "ERROR" "Failed to unmount device $device_path"
        print_error "Failed to unmount device $device_path. The device may be in use."
        return 1
    fi
    
    # Create a new partition table
    echo -e "${YELLOW}Creating new $part_type partition table...${NC}"
    if [[ "$part_type" == "gpt" ]]; then
        # GPT partition table
        parted -s "$device_path" mklabel gpt
    else
        # MBR/msdos partition table
        parted -s "$device_path" mklabel msdos
    fi
    
    # Create a single partition using the entire disk
    echo -e "${YELLOW}Creating partition...${NC}"
    parted -s "$device_path" mkpart primary 1MiB 100%
    
    # Get the partition name
    local partition
    if [[ "$device_path" == *"nvme"* ]]; then
        # NVMe naming convention (e.g., nvme0n1p1)
        partition="${device_path}p1"
    else
        # SCSI/SATA naming convention (e.g., sda1)
        partition="${device_path}1"
    fi
    
    # Wait for the partition to be created
    echo -e "${YELLOW}Waiting for partition to be recognized...${NC}"
    sleep 2
    udevadm settle
    
    # Format the partition with the requested filesystem
    echo -e "${YELLOW}Formatting partition with $fs_type...${NC}"
    case "$fs_type" in
        "exfat")
            mkfs.exfat -n "$label" "$partition"
            ;;
        "ntfs")
            mkfs.ntfs -f -L "$label" "$partition"
            ;;
        "ext4")
            mkfs.ext4 -L "$label" "$partition"
            ;;
        "fat32"|"vfat")
            mkfs.vfat -F 32 -n "$label" "$partition"
            ;;
        *)
            log_message "ERROR" "Unsupported filesystem type: $fs_type"
            print_error "Unsupported filesystem type: $fs_type"
            return 1
            ;;
    esac
    
    # Verify the format was successful
    if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to format partition $partition with $fs_type"
        print_error "Failed to format partition $partition with $fs_type"
        return 1
    fi
    
    # Create a health tracking file on the device
    echo -e "${YELLOW}Creating USB health tracking information...${NC}"
    track_usb_health_start "$device_path" "$partition"
    
    # Show success message
    print_success "Device $device_path has been successfully formatted with $fs_type filesystem."
    log_message "INFO" "Successfully formatted $device_path with $fs_type"
    
    # Return the partition name
    echo "$partition"
    return 0
}

# Initialize USB health tracking
track_usb_health_start() {
    local device_path="$1"
    local partition="$2"
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        return 0
    fi
    
    # Get device information
    USB_MODEL=$(get_device_info "$device_path" "model")
    USB_SERIAL=$(get_device_info "$device_path" "serial")
    USB_FIRST_USE_DATE=$(date +%Y-%m-%d)
    USB_WRITE_CYCLE_COUNTER=0
    USB_TOTAL_BYTES_WRITTEN=0
    
    # Estimate lifespan based on device type
    if [[ "$USB_MODEL" =~ [Ss][Ss][Dd] ]]; then
        # SSD typically has higher write endurance
        USB_ESTIMATED_LIFESPAN=3000
    else
        # Flash drives have lower write endurance
        USB_ESTIMATED_LIFESPAN=1000
    fi
    
    # Create a temporary mount point
    local tmp_mount
    tmp_mount="$TMP_DIR/usb_health_mount"
    mkdir -p "$tmp_mount"
    
    # Mount the partition
    if mount "$partition" "$tmp_mount"; then
        # Create the health data directory
        mkdir -p "$tmp_mount/.leonardo_data"
        
        # Set the health data file path
        USB_HEALTH_DATA_FILE="$tmp_mount/.leonardo_data/health.json"
        
        # Create the health data file
        cat > "$USB_HEALTH_DATA_FILE" << EOF
{
  "device": {
    "model": "$USB_MODEL",
    "serial": "$USB_SERIAL",
    "first_use": "$USB_FIRST_USE_DATE",
    "estimated_lifespan": $USB_ESTIMATED_LIFESPAN
  },
  "usage": {
    "write_cycles": $USB_WRITE_CYCLE_COUNTER,
    "total_bytes_written": $USB_TOTAL_BYTES_WRITTEN,
    "last_updated": "$(date +%Y-%m-%d)"
  },
  "history": []
}
EOF
        
        # Unmount the partition
        umount "$tmp_mount"
    fi
    
    # Remove the temporary mount point
    rmdir "$tmp_mount"
    
    log_message "INFO" "Initialized USB health tracking for $device_path"
}



# ==============================================================================
# Component: 03_filesystem/health.sh
# ==============================================================================
# ==============================================================================
# USB Health Monitoring
# ==============================================================================
# Description: Track and report on USB drive health and lifecycle
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,03_filesystem/device.sh
# ==============================================================================

# Load USB health data from a device
load_usb_health_data() {
    local partition="$1"
    local tmp_mount
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        return 0
    fi
    
    log_message "DEBUG" "Loading USB health data from $partition"
    
    # Create a temporary mount point
    tmp_mount="$TMP_DIR/usb_health_mount"
    mkdir -p "$tmp_mount"
    
    # Reset health variables
    USB_MODEL=""
    USB_SERIAL=""
    USB_FIRST_USE_DATE=""
    USB_WRITE_CYCLE_COUNTER=0
    USB_TOTAL_BYTES_WRITTEN=0
    USB_ESTIMATED_LIFESPAN=0
    
    # Mount the partition
    if mount "$partition" "$tmp_mount"; then
        # Check if health data file exists
        USB_HEALTH_DATA_FILE="$tmp_mount/.leonardo_data/health.json"
        
        if [[ -f "$USB_HEALTH_DATA_FILE" ]]; then
            # Extract data using grep and sed (avoid jq dependency)
            USB_MODEL=$(grep -o '"model": "[^"]*"' "$USB_HEALTH_DATA_FILE" | sed 's/"model": "\(.*\)"/\1/')
            USB_SERIAL=$(grep -o '"serial": "[^"]*"' "$USB_HEALTH_DATA_FILE" | sed 's/"serial": "\(.*\)"/\1/')
            USB_FIRST_USE_DATE=$(grep -o '"first_use": "[^"]*"' "$USB_HEALTH_DATA_FILE" | sed 's/"first_use": "\(.*\)"/\1/')
            USB_WRITE_CYCLE_COUNTER=$(grep -o '"write_cycles": [0-9]*' "$USB_HEALTH_DATA_FILE" | sed 's/"write_cycles": \(.*\)/\1/')
            USB_TOTAL_BYTES_WRITTEN=$(grep -o '"total_bytes_written": [0-9]*' "$USB_HEALTH_DATA_FILE" | sed 's/"total_bytes_written": \(.*\)/\1/')
            USB_ESTIMATED_LIFESPAN=$(grep -o '"estimated_lifespan": [0-9]*' "$USB_HEALTH_DATA_FILE" | sed 's/"estimated_lifespan": \(.*\)/\1/')
            
            log_message "INFO" "Loaded USB health data: $USB_MODEL, cycles: $USB_WRITE_CYCLE_COUNTER/$USB_ESTIMATED_LIFESPAN"
        else
            log_message "WARNING" "No health data found for $partition"
        fi
        
        # Unmount the partition
        umount "$tmp_mount"
    else
        log_message "ERROR" "Failed to mount $partition to read health data"
    fi
    
    # Remove the temporary mount point
    rmdir "$tmp_mount"
    
    return 0
}

# Update USB health data after a write operation
update_usb_health_data() {
    local partition="$1"
    local bytes_written="${2:-0}"
    local tmp_mount
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        return 0
    fi
    
    log_message "DEBUG" "Updating USB health data on $partition"
    
    # Load current health data first
    load_usb_health_data "$partition"
    
    # Increment write cycle counter
    USB_WRITE_CYCLE_COUNTER=$((USB_WRITE_CYCLE_COUNTER + 1))
    
    # Add bytes written
    USB_TOTAL_BYTES_WRITTEN=$((USB_TOTAL_BYTES_WRITTEN + bytes_written))
    
    # Create a temporary mount point
    tmp_mount="$TMP_DIR/usb_health_mount"
    mkdir -p "$tmp_mount"
    
    # Mount the partition
    if mount "$partition" "$tmp_mount"; then
        # Create the health data directory if it doesn't exist
        mkdir -p "$tmp_mount/.leonardo_data"
        
        # Set the health data file path
        USB_HEALTH_DATA_FILE="$tmp_mount/.leonardo_data/health.json"
        
        # Create or update the health data file
        cat > "$USB_HEALTH_DATA_FILE" << EOF
{
  "device": {
    "model": "$USB_MODEL",
    "serial": "$USB_SERIAL",
    "first_use": "$USB_FIRST_USE_DATE",
    "estimated_lifespan": $USB_ESTIMATED_LIFESPAN
  },
  "usage": {
    "write_cycles": $USB_WRITE_CYCLE_COUNTER,
    "total_bytes_written": $USB_TOTAL_BYTES_WRITTEN,
    "last_updated": "$(date +%Y-%m-%d)"
  },
  "history": [
    {"date": "$(date +%Y-%m-%d)", "bytes_written": $bytes_written, "operation": "write"}
  ]
}
EOF
        
        # Unmount the partition
        umount "$tmp_mount"
        
        log_message "INFO" "Updated USB health data: cycles=$USB_WRITE_CYCLE_COUNTER, bytes=$USB_TOTAL_BYTES_WRITTEN"
    else
        log_message "ERROR" "Failed to mount $partition to update health data"
    fi
    
    # Remove the temporary mount point
    rmdir "$tmp_mount"
    
    return 0
}

# Display USB health status
display_usb_health() {
    local partition="$1"
    
    # Only if health tracking is enabled
    if [[ "$USB_HEALTH_TRACKING" != "true" ]]; then
        echo -e "${YELLOW}USB health tracking is disabled${NC}"
        return 0
    fi
    
    # Load health data
    load_usb_health_data "$partition"
    
    # Check if we have health data
    if [[ -z "$USB_MODEL" || -z "$USB_FIRST_USE_DATE" ]]; then
        echo -e "${RED}No health data found for this device${NC}"
        return 1
    fi
    
    # Calculate health percentage
    local health_percent=0
    if [[ $USB_ESTIMATED_LIFESPAN -gt 0 ]]; then
        health_percent=$(( 100 - (USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN) ))
        # Ensure it's not negative
        if [[ $health_percent -lt 0 ]]; then
            health_percent=0
        fi
    fi
    
    # Determine health status and color
    local health_status
    local health_color
    
    if [[ $health_percent -ge 75 ]]; then
        health_status="Excellent"
        health_color="$GREEN"
    elif [[ $health_percent -ge 50 ]]; then
        health_status="Good"
        health_color="$CYAN"
    elif [[ $health_percent -ge 25 ]]; then
        health_status="Fair"
        health_color="$YELLOW"
    else
        health_status="Poor"
        health_color="$RED"
    fi
    
    # Format total bytes written
    local bytes_human
    if [[ $USB_TOTAL_BYTES_WRITTEN -ge 1073741824 ]]; then
        # GB
        bytes_human="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN / 1073741824" | bc) GB"
    elif [[ $USB_TOTAL_BYTES_WRITTEN -ge 1048576 ]]; then
        # MB
        bytes_human="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN / 1048576" | bc) MB"
    elif [[ $USB_TOTAL_BYTES_WRITTEN -ge 1024 ]]; then
        # KB
        bytes_human="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN / 1024" | bc) KB"
    else
        # Bytes
        bytes_human="$USB_TOTAL_BYTES_WRITTEN bytes"
    fi
    
    # Calculate age in days
    local first_use_sec=$(date -d "$USB_FIRST_USE_DATE" +%s 2>/dev/null || echo 0)
    local today_sec=$(date +%s)
    local age_days=$(( (today_sec - first_use_sec) / 86400 ))
    
    # Display health information in a box
    print_box_header "USB Drive Health Report" "$UI_WIDTH" "$health_color"
    
    # Basic device info
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Device:" "$USB_MODEL" $((UI_WIDTH - 30 - ${#USB_MODEL})) ""
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Serial:" "$USB_SERIAL" $((UI_WIDTH - 30 - ${#USB_SERIAL})) ""
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC} (%d days)%*s ${health_color}${BOX_V}${NC}\n" "First used:" "$USB_FIRST_USE_DATE" "$age_days" $((UI_WIDTH - 40 - ${#USB_FIRST_USE_DATE})) ""
    
    # Separator
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$health_color"
    
    # Health status
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}${health_color}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Health status:" "$health_status" $((UI_WIDTH - 35 - ${#health_status})) ""
    
    # Health bar
    local bar_width=$((UI_WIDTH - 30))
    local filled_width=$((bar_width * health_percent / 100))
    local empty_width=$((bar_width - filled_width))
    
    printf "${health_color}${BOX_V}${NC} %-20s [" "Health remaining:"
    printf "${health_color}%${filled_width}s${NC}" | tr ' ' '#'
    printf "${DIM}%${empty_width}s${NC}" | tr ' ' '-'
    printf "] ${BOLD}%d%%${NC}%*s ${health_color}${BOX_V}${NC}\n" "$health_percent" $((UI_WIDTH - bar_width - 30)) ""
    
    # Write cycles
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%d${NC} of %d (%.1f%%)%*s ${health_color}${BOX_V}${NC}\n" "Write cycles:" "$USB_WRITE_CYCLE_COUNTER" "$USB_ESTIMATED_LIFESPAN" "$(echo "scale=1; $USB_WRITE_CYCLE_COUNTER * 100 / $USB_ESTIMATED_LIFESPAN" | bc)" $((UI_WIDTH - 50)) ""
    
    # Total data written
    printf "${health_color}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${health_color}${BOX_V}${NC}\n" "Total data written:" "$bytes_human" $((UI_WIDTH - 30 - ${#bytes_human})) ""
    
    # Recommendations
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$health_color"
    
    local recommendation
    if [[ $health_percent -lt 25 ]]; then
        recommendation="Consider replacing this drive soon. It has exceeded 75% of its expected lifetime."
    elif [[ $health_percent -lt 50 ]]; then
        recommendation="This drive has used more than half of its expected lifetime. Plan for future replacement."
    else
        recommendation="This drive is in good health and should continue to function well."
    fi
    
    printf "${health_color}${BOX_V}${NC} ${BOLD}Recommendation:${NC}%*s ${health_color}${BOX_V}${NC}\n" $((UI_WIDTH - 18)) ""
    print_box_content "  $recommendation" "$UI_WIDTH" "$health_color" 2 2
    
    # Footer
    print_box_footer "$UI_WIDTH" "$health_color"
}

# Verify USB health and make recommendations
verify_usb_health() {
    local partition="$1"
    
    # Load health data
    load_usb_health_data "$partition"
    
    # Check if we have health data
    if [[ -z "$USB_MODEL" || -z "$USB_FIRST_USE_DATE" ]]; then
        return 1
    fi
    
    # Calculate health percentage
    local health_percent=0
    if [[ $USB_ESTIMATED_LIFESPAN -gt 0 ]]; then
        health_percent=$(( 100 - (USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN) ))
        # Ensure it's not negative
        if [[ $health_percent -lt 0 ]]; then
            health_percent=0
        fi
    fi
    
    # Return health code
    if [[ $health_percent -ge 75 ]]; then
        return 0  # Excellent
    elif [[ $health_percent -ge 50 ]]; then
        return 1  # Good
    elif [[ $health_percent -ge 25 ]]; then
        return 2  # Fair
    else
        return 3  # Poor
    fi
}



# ==============================================================================
# Component: 04_network/download.sh
# ==============================================================================
# ==============================================================================
# Download Management
# ==============================================================================
# Description: Download handling with progress bars and resume capability
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh
# ==============================================================================

# Check if required download tools are available
check_download_tools() {
    local tools_available=false
    
    # Check for curl
    if command -v curl &>/dev/null; then
        DOWNLOAD_TOOL="curl"
        tools_available=true
        log_message "DEBUG" "Using curl for downloads"
    # Check for wget
    elif command -v wget &>/dev/null; then
        DOWNLOAD_TOOL="wget"
        tools_available=true
        log_message "DEBUG" "Using wget for downloads"
    fi
    
    if [[ "$tools_available" != "true" ]]; then
        log_message "ERROR" "No download tools available. Please install curl or wget."
        return 1
    fi
    
    return 0
}

# Initialize download system
init_download_system() {
    # Check for download tools
    if ! check_download_tools; then
        log_message "ERROR" "Failed to initialize download system"
        return 1
    fi
    
    # Reset download tracking arrays
    DOWNLOAD_HISTORY=()
    DOWNLOAD_SIZES=()
    DOWNLOAD_TIMESTAMPS=()
    DOWNLOAD_DESTINATIONS=()
    DOWNLOAD_STATUS=()
    TOTAL_BYTES_DOWNLOADED=0
    
    log_message "INFO" "Download system initialized"
    return 0
}

# Get the size of a remote file
get_remote_file_size() {
    local url="$1"
    local size=0
    
    log_message "DEBUG" "Getting size of remote file: $url"
    
    if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
        size=$(curl -sI "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
    elif [[ "$DOWNLOAD_TOOL" == "wget" ]]; then
        size=$(wget --spider --server-response "$url" 2>&1 | grep -i Content-Length | awk '{print $2}' | tail -1)
    fi
    
    # If size is empty or not a number, return 0
    if [[ -z "$size" || ! "$size" =~ ^[0-9]+$ ]]; then
        size=0
    fi
    
    echo "$size"
}

# Format file size for display
format_size() {
    local size="$1"
    
    if [[ $size -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [[ $size -ge 1048576 ]]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    elif [[ $size -ge 1024 ]]; then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "$size bytes"
    fi
}

# Draw a progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local prefix="${4:-Progress:}"
    
    # Calculate percentage
    local percent=0
    if [[ $total -gt 0 ]]; then
        percent=$(( current * 100 / total ))
    fi
    
    # Calculate filled width
    local filled_width=$(( width * current / total ))
    if [[ $filled_width -gt $width ]]; then
        filled_width=$width
    fi
    
    # Calculate empty width
    local empty_width=$(( width - filled_width ))
    
    # Format current and total size
    local current_formatted=$(format_size "$current")
    local total_formatted=$(format_size "$total")
    
    # Draw the progress bar
    printf "\r%-10s [" "$prefix"
    printf "%${filled_width}s" | tr ' ' '='
    printf "%${empty_width}s" | tr ' ' ' '
    printf "] %3d%% %s/%s" "$percent" "$current_formatted" "$total_formatted"
}

# Download a file with progress
download_file() {
    local url="$1"
    local destination="$2"
    local show_progress="${3:-true}"
    local continue="${4:-true}"
    
    log_message "INFO" "Downloading $url to $destination"
    
    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$destination")"
    
    # Get file size if available
    local file_size
    file_size=$(get_remote_file_size "$url")
    
    # Set up common options
    local curl_opts=("-L" "-f" "-S")
    local wget_opts=("-q")
    
    # Add continue option if requested
    if [[ "$continue" == "true" ]]; then
        curl_opts+=("-C" "-")
        wget_opts+=("-c")
    fi
    
    # Add progress option if requested
    if [[ "$show_progress" == "true" && -t 1 ]]; then
        if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
            # Use progress bar for curl
            curl_opts+=("--progress-bar")
        elif [[ "$DOWNLOAD_TOOL" == "wget" ]]; then
            # Use progress bar for wget
            wget_opts+=("--show-progress")
        fi
    else
        # Silent download
        curl_opts+=("-s")
        wget_opts+=("-q")
    fi
    
    # Add output destination
    curl_opts+=("-o" "$destination")
    wget_opts+=("-O" "$destination")
    
    # Start the download
    local start_time
    start_time=$(date +%s)
    local exit_code=0
    
    # Perform the download with the appropriate tool
    if [[ "$DOWNLOAD_TOOL" == "curl" ]]; then
        curl "${curl_opts[@]}" "$url" || exit_code=$?
    elif [[ "$DOWNLOAD_TOOL" == "wget" ]]; then
        wget "${wget_opts[@]}" "$url" || exit_code=$?
    fi
    
    # Calculate download time
    local end_time
    end_time=$(date +%s)
    local download_time=$((end_time - start_time))
    
    # Update download tracking
    if [[ $exit_code -eq 0 && -f "$destination" ]]; then
        # Get the actual file size
        local actual_size
        actual_size=$(stat -c%s "$destination" 2>/dev/null || stat -f%z "$destination" 2>/dev/null)
        
        # Update tracking arrays
        DOWNLOAD_HISTORY+=("$url")
        DOWNLOAD_SIZES+=("$actual_size")
        DOWNLOAD_TIMESTAMPS+=("$(date +%Y-%m-%d-%H:%M:%S)")
        DOWNLOAD_DESTINATIONS+=("$destination")
        DOWNLOAD_STATUS+=("success")
        
        # Update total bytes downloaded
        TOTAL_BYTES_DOWNLOADED=$((TOTAL_BYTES_DOWNLOADED + actual_size))
        
        # Calculate download speed
        local speed=0
        if [[ $download_time -gt 0 ]]; then
            speed=$((actual_size / download_time))
        fi
        
        # Log success
        log_message "INFO" "Download complete: $url -> $destination ($(format_size "$actual_size") in ${download_time}s, $(format_size "$speed")/s)"
        
        # Return success
        return 0
    else
        # Log failure
        log_message "ERROR" "Download failed: $url -> $destination (Exit code: $exit_code)"
        
        # Update tracking arrays for failure
        DOWNLOAD_HISTORY+=("$url")
        DOWNLOAD_SIZES+=("0")
        DOWNLOAD_TIMESTAMPS+=("$(date +%Y-%m-%d-%H:%M:%S)")
        DOWNLOAD_DESTINATIONS+=("$destination")
        DOWNLOAD_STATUS+=("failed")
        
        # Return failure
        return 1
    fi
}

# Download multiple files with a single progress bar
download_multiple_files() {
    local urls=("$@")
    local num_files=${#urls[@]}
    local current_file=1
    local all_success=true
    
    echo -e "${CYAN}Downloading $num_files files...${NC}"
    
    for url in "${urls[@]}"; do
        # Extract filename from URL
        local filename
        filename=$(basename "$url")
        
        # Create destination path
        local destination="$TMP_DIR/downloads/$filename"
        
        # Show which file we're downloading
        echo -e "[${current_file}/${num_files}] ${YELLOW}$filename${NC}"
        
        # Download the file
        if ! download_file "$url" "$destination" true; then
            all_success=false
        fi
        
        # Increment counter
        current_file=$((current_file + 1))
        echo ""
    done
    
    if [[ "$all_success" == "true" ]]; then
        echo -e "${GREEN}All downloads completed successfully${NC}"
        return 0
    else
        echo -e "${RED}Some downloads failed${NC}"
        return 1
    fi
}

# Download a file and verify its checksum
download_and_verify() {
    local url="$1"
    local destination="$2"
    local checksum="$3"
    local checksum_type="${4:-sha256}"
    local show_progress="${5:-true}"
    
    # Download the file
    if ! download_file "$url" "$destination" "$show_progress"; then
        return 1
    fi
    
    # Verify the checksum if provided
    if [[ -n "$checksum" ]]; then
        echo -e "${YELLOW}Verifying checksum...${NC}"
        if ! verify_checksum "$destination" "$checksum" "$checksum_type"; then
            echo -e "${RED}Checksum verification failed${NC}"
            return 1
        fi
        echo -e "${GREEN}Checksum verification passed${NC}"
    fi
    
    return 0
}

# Initialize the download system
init_download_system



# ==============================================================================
# Component: 04_network/checksum.sh
# ==============================================================================
# ==============================================================================
# Checksum Verification
# ==============================================================================
# Description: Functions to verify file integrity using checksums
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh
# ==============================================================================

# Check if required checksum tools are available
check_checksum_tools() {
    local has_md5=false
    local has_sha1=false
    local has_sha256=false
    local has_sha512=false
    
    # Check for md5sum or md5
    if command -v md5sum &>/dev/null; then
        MD5_TOOL="md5sum"
        has_md5=true
    elif command -v md5 &>/dev/null; then
        MD5_TOOL="md5"
        has_md5=true
    fi
    
    # Check for sha1sum
    if command -v sha1sum &>/dev/null; then
        SHA1_TOOL="sha1sum"
        has_sha1=true
    fi
    
    # Check for sha256sum
    if command -v sha256sum &>/dev/null; then
        SHA256_TOOL="sha256sum"
        has_sha256=true
    fi
    
    # Check for sha512sum
    if command -v sha512sum &>/dev/null; then
        SHA512_TOOL="sha512sum"
        has_sha512=true
    fi
    
    # Log available tools
    log_message "DEBUG" "Checksum tools available: md5=$has_md5, sha1=$has_sha1, sha256=$has_sha256, sha512=$has_sha512"
    
    # Return success if at least one tool is available
    if [[ "$has_md5" == "true" || "$has_sha1" == "true" || "$has_sha256" == "true" || "$has_sha512" == "true" ]]; then
        return 0
    else
        log_message "ERROR" "No checksum tools available"
        return 1
    fi
}

# Calculate a file's checksum
calculate_checksum() {
    local file="$1"
    local type="${2:-sha256}"
    
    log_message "DEBUG" "Calculating $type checksum for $file"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_message "ERROR" "File not found: $file"
        return 1
    fi
    
    # Calculate checksum based on type
    case "$type" in
        md5)
            if [[ "$MD5_TOOL" == "md5sum" ]]; then
                md5sum "$file" | cut -d ' ' -f 1
            elif [[ "$MD5_TOOL" == "md5" ]]; then
                md5 -q "$file"
            else
                log_message "ERROR" "MD5 checksum tool not available"
                return 1
            fi
            ;;
        sha1)
            if [[ -n "$SHA1_TOOL" ]]; then
                sha1sum "$file" | cut -d ' ' -f 1
            else
                log_message "ERROR" "SHA1 checksum tool not available"
                return 1
            fi
            ;;
        sha256)
            if [[ -n "$SHA256_TOOL" ]]; then
                sha256sum "$file" | cut -d ' ' -f 1
            else
                log_message "ERROR" "SHA256 checksum tool not available"
                return 1
            fi
            ;;
        sha512)
            if [[ -n "$SHA512_TOOL" ]]; then
                sha512sum "$file" | cut -d ' ' -f 1
            else
                log_message "ERROR" "SHA512 checksum tool not available"
                return 1
            fi
            ;;
        *)
            log_message "ERROR" "Unsupported checksum type: $type"
            return 1
            ;;
    esac
    
    return $?
}

# Verify a file's checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    local type="${3:-sha256}"
    
    log_message "INFO" "Verifying $type checksum for $file"
    
    # Calculate the actual checksum
    local actual
    actual=$(calculate_checksum "$file" "$type")
    local exit_code=$?
    
    # Check if calculation succeeded
    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "Failed to calculate checksum"
        return 1
    fi
    
    # Convert to lowercase for comparison
    expected="${expected,,}"
    actual="${actual,,}"
    
    # Log checksums
    log_message "DEBUG" "Expected $type: $expected"
    log_message "DEBUG" "Actual $type: $actual"
    
    # Compare checksums
    if [[ "$actual" == "$expected" ]]; then
        log_message "INFO" "Checksum verification passed"
        return 0
    else
        log_message "ERROR" "Checksum verification failed"
        return 1
    fi
}

# Verify multiple files against a checksum file
verify_checksum_file() {
    local checksum_file="$1"
    local base_dir="${2:-.}"
    local type="${3:-sha256}"
    
    log_message "INFO" "Verifying checksums from file: $checksum_file"
    
    # Check if checksum file exists
    if [[ ! -f "$checksum_file" ]]; then
        log_message "ERROR" "Checksum file not found: $checksum_file"
        return 1
    fi
    
    # Track verification results
    local total=0
    local passed=0
    local failed=0
    
    # Process each line in the checksum file
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi
        
        # Parse the line (format depends on checksum type)
        local expected
        local filename
        
        # Handle BSD-style md5 format (md5 -r)
        if [[ "$line" =~ ^MD5\ \(([^\)]+)\)\ =\ ([0-9a-f]+)$ ]]; then
            filename="${BASH_REMATCH[1]}"
            expected="${BASH_REMATCH[2]}"
        # Handle standard format (hash filename)
        else
            expected=$(echo "$line" | awk '{print $1}')
            filename=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
            
            # Handle potential file indicators like '*' for binary mode
            filename=$(echo "$filename" | sed 's/^\*//')
        fi
        
        # Build the full file path
        local file_path="$base_dir/$filename"
        
        # Increment total
        total=$((total + 1))
        
        # Check if file exists
        if [[ ! -f "$file_path" ]]; then
            log_message "WARNING" "File not found: $file_path"
            failed=$((failed + 1))
            continue
        fi
        
        # Verify the checksum
        if verify_checksum "$file_path" "$expected" "$type"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done < "$checksum_file"
    
    # Log results
    log_message "INFO" "Checksum verification results: $passed/$total passed, $failed failed"
    
    # Return success if all passed
    if [[ $failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Generate a checksum file for a directory
generate_checksum_file() {
    local directory="$1"
    local output_file="$2"
    local type="${3:-sha256}"
    local pattern="${4:-*}"
    
    log_message "INFO" "Generating $type checksums for $directory to $output_file"
    
    # Check if directory exists
    if [[ ! -d "$directory" ]]; then
        log_message "ERROR" "Directory not found: $directory"
        return 1
    fi
    
    # Create output file with header
    cat > "$output_file" << EOF
# Generated by Leonardo AI Universal on $(date)
# Checksum type: $type
# Directory: $directory

EOF
    
    # Find files matching pattern and calculate checksums
    local file_count=0
    
    # Use find to get all files, excluding directories
    while IFS= read -r file; do
        # Calculate checksum
        local checksum
        checksum=$(calculate_checksum "$file" "$type")
        
        # Get relative path
        local relative_path
        relative_path="${file#$directory/}"
        
        # Write to output file
        echo "$checksum  $relative_path" >> "$output_file"
        
        # Increment counter
        file_count=$((file_count + 1))
    done < <(find "$directory" -type f -name "$pattern" | sort)
    
    log_message "INFO" "Generated checksums for $file_count files"
    
    # Return success
    return 0
}

# Initialize checksum system
check_checksum_tools



# ==============================================================================
# Component: 05_models/registry.sh
# ==============================================================================
# ==============================================================================
# Model Registry
# ==============================================================================
# Description: Management of available AI models and their metadata
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,04_network/download.sh
# ==============================================================================

# Model registry - maps model IDs to information
declare -A MODEL_REGISTRY
declare -A MODEL_URLS
declare -A MODEL_CHECKSUMS
declare -A MODEL_SIZES
declare -A MODEL_REQUIREMENTS

# Initialize the model registry
init_model_registry() {
    log_message "INFO" "Initializing model registry"
    
    # Reset model arrays
    MODEL_REGISTRY=()
    MODEL_URLS=()
    MODEL_CHECKSUMS=()
    MODEL_SIZES=()
    MODEL_REQUIREMENTS=()
    
    # Register the supported models
    # Format: register_model ID NAME DESCRIPTION [SIZE_MB] [URL] [CHECKSUM] [REQUIREMENTS]
    
    # LLaMA 3 8B
    register_model "llama3-8b" "Meta LLaMA 3 8B" "General purpose, low resource LLM with strong performance" \
        "4800" \
        "https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct/resolve/main/consolidated.00.pth" \
        "e51fd235"
    
    # LLaMA 3 70B
    register_model "llama3-70b" "Meta LLaMA 3 70B" "High performance LLM for complex reasoning tasks" \
        "41500" \
        "https://huggingface.co/meta-llama/Meta-Llama-3-70B-Instruct/resolve/main/consolidated.00.pth" \
        "3e00bbb2" \
        "RAM:32GB,GPU:24GB"
    
    # Mistral 7B
    register_model "mistral-7b" "Mistral 7B" "Efficient, strong instruction following model" \
        "4300" \
        "https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2/resolve/main/consolidated.00.pth" \
        "9f43825c"
    
    # Mixtral 8x7B
    register_model "mixtral-8x7b" "Mixtral 8x7B" "Mixture of experts, best for complex tasks" \
        "26500" \
        "https://huggingface.co/mistralai/Mixtral-8x7B-Instruct-v0.1/resolve/main/consolidated.00.pth" \
        "21e8d6a5" \
        "RAM:24GB,GPU:16GB"
    
    # Claude Instant
    register_model "claude-instant" "Anthropic Claude Instant" "Fast, efficient chat model for everyday use" \
        "5200" \
        "https://anthropic.api/models/claude-instant" \
        "" \
        "API_KEY:anthropic"
    
    # Claude 3 Opus
    register_model "claude-3-opus" "Anthropic Claude 3 Opus" "Extremely powerful reasoning and instruction following" \
        "0" \
        "https://anthropic.api/models/claude-3-opus" \
        "" \
        "API_KEY:anthropic"
    
    # Gemma 7B
    register_model "gemma-7b" "Google Gemma 7B" "Efficient, balanced performance" \
        "4100" \
        "https://huggingface.co/google/gemma-7b-it/resolve/main/consolidated.00.pth" \
        "c72bf3a0"
    
    # Gemma 2B
    register_model "gemma-2b" "Google Gemma 2B" "Ultra-lightweight, mobile-friendly model" \
        "1300" \
        "https://huggingface.co/google/gemma-2b-it/resolve/main/consolidated.00.pth" \
        "fb5fe0de"
    
    log_message "INFO" "Model registry initialized with ${#MODEL_REGISTRY[@]} models"
}

# Register a model in the registry
register_model() {
    local id="$1"
    local name="$2"
    local description="$3"
    local size="${4:-0}"
    local url="${5:-}"
    local checksum="${6:-}"
    local requirements="${7:-}"
    
    MODEL_REGISTRY["$id"]="$name|$description"
    MODEL_URLS["$id"]="$url"
    MODEL_CHECKSUMS["$id"]="$checksum"
    MODEL_SIZES["$id"]="$size"
    MODEL_REQUIREMENTS["$id"]="$requirements"
    
    log_message "DEBUG" "Registered model: $id ($name)"
}

# Get model information by ID
get_model_info() {
    local id="$1"
    local field="${2:-name}"  # name, description, url, checksum, size, requirements
    
    # Check if model exists
    if [[ -z "${MODEL_REGISTRY[$id]}" ]]; then
        log_message "WARNING" "Model not found: $id"
        return 1
    fi
    
    # Parse model information
    local info="${MODEL_REGISTRY[$id]}"
    local name description
    IFS='|' read -r name description <<< "$info"
    
    # Return requested field
    case "$field" in
        name)
            echo "$name"
            ;;
        description)
            echo "$description"
            ;;
        url)
            echo "${MODEL_URLS[$id]}"
            ;;
        checksum)
            echo "${MODEL_CHECKSUMS[$id]}"
            ;;
        size)
            echo "${MODEL_SIZES[$id]}"
            ;;
        requirements)
            echo "${MODEL_REQUIREMENTS[$id]}"
            ;;
        *)
            log_message "WARNING" "Unknown field: $field"
            return 1
            ;;
    esac
    
    return 0
}

# Check if a model exists in the registry
model_exists() {
    local id="$1"
    
    if [[ -n "${MODEL_REGISTRY[$id]}" ]]; then
        return 0
    else
        return 1
    fi
}

# List all available models
list_available_models() {
    local format="${1:-table}"  # table, list, or json
    
    log_message "INFO" "Listing available models in format: $format"
    
    case "$format" in
        table)
            # Print header
            printf "%-15s %-30s %-10s %s\n" "ID" "NAME" "SIZE" "DESCRIPTION"
            printf "%-15s %-30s %-10s %s\n" "---------------" "------------------------------" "----------" "------------------------------------"
            
            # Print each model
            for id in "${!MODEL_REGISTRY[@]}"; do
                local name description
                IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
                local size="${MODEL_SIZES[$id]}"
                
                # Format size
                if [[ $size -ge 1024 ]]; then
                    size="$(echo "scale=1; $size / 1024" | bc) GB"
                else
                    size="$size MB"
                fi
                
                printf "%-15s %-30s %-10s %s\n" "$id" "$name" "$size" "$description"
            done
            ;;
        
        list)
            # Print each model on a line
            for id in "${!MODEL_REGISTRY[@]}"; do
                local name description
                IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
                echo "$id: $name - $description"
            done
            ;;
        
        json)
            # Print as JSON
            echo "{"
            echo "  \"models\": ["
            
            local first=true
            for id in "${!MODEL_REGISTRY[@]}"; do
                if [[ "$first" != "true" ]]; then
                    echo ","
                fi
                first=false
                
                local name description
                IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
                local size="${MODEL_SIZES[$id]}"
                local requirements="${MODEL_REQUIREMENTS[$id]}"
                
                echo -n "    {"
                echo -n "\"id\":\"$id\","
                echo -n "\"name\":\"$name\","
                echo -n "\"description\":\"$description\","
                echo -n "\"size\":$size,"
                echo -n "\"requirements\":\"$requirements\""
                echo -n "}"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        
        *)
            log_message "WARNING" "Unknown format: $format"
            return 1
            ;;
    esac
    
    return 0
}

# Filter models based on system requirements
filter_models_by_requirements() {
    local ram="${1:-0}"  # Available RAM in GB
    local gpu="${2:-0}"  # Available GPU memory in GB
    local api_keys="${3:-}"  # Available API keys (comma-separated)
    
    log_message "INFO" "Filtering models by requirements: RAM=${ram}GB, GPU=${gpu}GB, API keys: $api_keys"
    
    # Create array for API keys
    local -a available_api_keys
    IFS=',' read -ra available_api_keys <<< "$api_keys"
    
    # Print header
    printf "%-15s %-30s %-10s %s\n" "ID" "NAME" "SIZE" "REQUIREMENTS"
    printf "%-15s %-30s %-10s %s\n" "---------------" "------------------------------" "----------" "------------------------------------"
    
    # Check each model
    for id in "${!MODEL_REGISTRY[@]}"; do
        local requirements="${MODEL_REQUIREMENTS[$id]}"
        local meets_requirements=true
        
        # Check RAM requirements
        if [[ "$requirements" =~ RAM:([0-9]+)GB ]]; then
            local required_ram="${BASH_REMATCH[1]}"
            if [[ $ram -lt $required_ram ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check GPU requirements
        if [[ "$requirements" =~ GPU:([0-9]+)GB ]]; then
            local required_gpu="${BASH_REMATCH[1]}"
            if [[ $gpu -lt $required_gpu ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check API key requirements
        if [[ "$requirements" =~ API_KEY:([a-z0-9_]+) ]]; then
            local required_api_key="${BASH_REMATCH[1]}"
            local has_api_key=false
            
            for key in "${available_api_keys[@]}"; do
                if [[ "$key" == "$required_api_key" ]]; then
                    has_api_key=true
                    break
                fi
            done
            
            if [[ "$has_api_key" != "true" ]]; then
                meets_requirements=false
            fi
        fi
        
        # Only print if meets requirements
        if [[ "$meets_requirements" == "true" ]]; then
            local name description
            IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
            local size="${MODEL_SIZES[$id]}"
            
            # Format size
            if [[ $size -ge 1024 ]]; then
                size="$(echo "scale=1; $size / 1024" | bc) GB"
            else
                size="$size MB"
            fi
            
            printf "%-15s %-30s %-10s %s\n" "$id" "$name" "$size" "$requirements"
        fi
    done
    
    return 0
}

# Select a model with interactive menu
select_model() {
    local ram="${1:-0}"  # Available RAM in GB
    local gpu="${2:-0}"  # Available GPU memory in GB
    local api_keys="${3:-}"  # Available API keys (comma-separated)
    
    log_message "INFO" "Selecting model with requirements: RAM=${ram}GB, GPU=${gpu}GB, API keys: $api_keys"
    
    # Create array for API keys
    local -a available_api_keys
    IFS=',' read -ra available_api_keys <<< "$api_keys"
    
    # Create arrays for compatible models
    local -a compatible_ids
    local -a compatible_names
    local -a compatible_descriptions
    local -a compatible_sizes
    
    # Filter models by requirements
    for id in "${!MODEL_REGISTRY[@]}"; do
        local requirements="${MODEL_REQUIREMENTS[$id]}"
        local meets_requirements=true
        
        # Check RAM requirements
        if [[ "$requirements" =~ RAM:([0-9]+)GB ]]; then
            local required_ram="${BASH_REMATCH[1]}"
            if [[ $ram -lt $required_ram ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check GPU requirements
        if [[ "$requirements" =~ GPU:([0-9]+)GB ]]; then
            local required_gpu="${BASH_REMATCH[1]}"
            if [[ $gpu -lt $required_gpu ]]; then
                meets_requirements=false
            fi
        fi
        
        # Check API key requirements
        if [[ "$requirements" =~ API_KEY:([a-z0-9_]+) ]]; then
            local required_api_key="${BASH_REMATCH[1]}"
            local has_api_key=false
            
            for key in "${available_api_keys[@]}"; do
                if [[ "$key" == "$required_api_key" ]]; then
                    has_api_key=true
                    break
                fi
            done
            
            if [[ "$has_api_key" != "true" ]]; then
                meets_requirements=false
            fi
        fi
        
        # Add to compatible models if meets requirements
        if [[ "$meets_requirements" == "true" ]]; then
            local name description
            IFS='|' read -r name description <<< "${MODEL_REGISTRY[$id]}"
            local size="${MODEL_SIZES[$id]}"
            
            compatible_ids+=("$id")
            compatible_names+=("$name")
            compatible_descriptions+=("$description")
            compatible_sizes+=("$size")
        fi
    done
    
    # Check if any compatible models found
    if [[ ${#compatible_ids[@]} -eq 0 ]]; then
        log_message "WARNING" "No compatible models found for your system"
        echo -e "${RED}No compatible models found for your system.${NC}"
        echo "Consider upgrading your hardware or adding API keys."
        return 1
    fi
    
    # Print header
    echo -e "${CYAN}Compatible AI Models for Your System${NC}"
    echo ""
    
    # Show models with numbers
    for i in "${!compatible_ids[@]}"; do
        local id="${compatible_ids[$i]}"
        local name="${compatible_names[$i]}"
        local description="${compatible_descriptions[$i]}"
        local size="${compatible_sizes[$i]}"
        
        # Format size
        if [[ $size -ge 1024 ]]; then
            size="$(echo "scale=1; $size / 1024" | bc) GB"
        else
            size="$size MB"
        fi
        
        echo -e "${BOLD}$((i+1)). ${GREEN}${name}${NC} (${YELLOW}${size}${NC})"
        echo "   ${DIM}${description}${NC}"
        echo ""
    done
    
    # Get user selection
    local selection
    while true; do
        echo -n "Select a model (1-${#compatible_ids[@]}): "
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#compatible_ids[@]}" ]]; then
            local selected_id="${compatible_ids[$((selection-1))]}"
            log_message "INFO" "User selected model: $selected_id"
            echo "$selected_id"
            return 0
        else
            echo -e "${RED}Invalid selection.${NC} Please try again."
        fi
    done
}

# Initialize the model registry
init_model_registry



# ==============================================================================
# Component: 05_models/installer.sh
# ==============================================================================
# ==============================================================================
# Model Installation
# ==============================================================================
# Description: Handles installation of AI models to USB devices
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,04_network/download.sh,05_models/registry.sh
# ==============================================================================

# Install a model to the USB device
install_model() {
    local model_id="$1"
    local usb_path="$2"
    local partition_number="${3:-1}"
    
    # Get model information
    local model_name=$(get_model_info "$model_id" "name")
    local model_url=$(get_model_info "$model_id" "url")
    local model_checksum=$(get_model_info "$model_id" "checksum")
    local model_size=$(get_model_info "$model_id" "size")
    local model_reqs=$(get_model_info "$model_id" "requirements")
    
    log_message "INFO" "Installing model: $model_id ($model_name) to $usb_path"
    
    # Check if model exists
    if ! model_exists "$model_id"; then
        show_error "Model $model_id not found in registry"
        return 1
    fi
    
    # Check if URL is available
    if [[ -z "$model_url" ]]; then
        show_error "No download URL available for $model_name"
        return 1
    fi
    
    # Verify USB device
    if [[ ! -b "$usb_path" ]]; then
        show_error "Invalid USB device path: $usb_path"
        return 1
    fi
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    if [[ ! -b "$partition" ]]; then
        show_error "Partition ${partition} not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_install_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    show_step_header "Mounting USB Device" "$UI_WIDTH"
    echo -e "Mounting ${CYAN}$partition${NC} to ${CYAN}$mount_point${NC}..."
    
    if ! mount "$partition" "$mount_point"; then
        show_error "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Create the model directory structure
    local models_dir="$mount_point/leonardo/models"
    local model_dir="$models_dir/$model_id"
    
    mkdir -p "$model_dir"
    
    # Show download information
    show_step_header "Downloading $model_name" "$UI_WIDTH"
    
    # Format model size for display
    local display_size
    if [[ "$model_size" -gt 1024 ]]; then
        display_size="$(echo "scale=2; $model_size / 1024" | bc) GB"
    else
        display_size="$model_size MB"
    fi
    
    # Show download info with friendly llama
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} Downloading ${GREEN}$model_name${NC}"
    echo -e "     Size: ${CYAN}$display_size${NC}"
    echo -e "     Destination: ${CYAN}$model_dir${NC}"
    echo ""
    
    # Check available space
    local available_space
    available_space=$(df -m "$mount_point" | awk 'NR==2 {print $4}')
    
    log_message "DEBUG" "Available space: ${available_space}MB, Required: ${model_size}MB"
    
    if [[ "$available_space" -lt "$model_size" ]]; then
        show_error "Not enough space on USB device. Available: ${available_space}MB, Required: ${model_size}MB"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Calculate filename from URL
    local filename=$(basename "$model_url")
    
    # Download the model
    if ! download_file "$model_url" "$model_dir/$filename" true true; then
        show_error "Failed to download $model_name"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Verify checksum if available
    if [[ -n "$model_checksum" ]]; then
        show_step_header "Verifying $model_name" "$UI_WIDTH"
        echo -e "Verifying file integrity..."
        
        if ! verify_checksum "$model_dir/$filename" "$model_checksum" "sha256"; then
            show_warning "Checksum verification failed for $model_name" "caution"
            echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}The downloaded file may be corrupted or incomplete.${NC}"
            echo -e "     Do you want to keep the downloaded file anyway?"
            
            if ! confirm_action "Keep the downloaded file?"; then
                echo -e "Removing downloaded file..."
                rm -f "$model_dir/$filename"
                umount "$mount_point"
                rmdir "$mount_point"
                return 1
            fi
        else
            show_success "Checksum verification passed"
        fi
    fi
    
    # Create the model metadata file
    local metadata_file="$model_dir/metadata.json"
    
    cat > "$metadata_file" << EOF
{
  "id": "$model_id",
  "name": "$model_name",
  "description": "$(get_model_info "$model_id" "description")",
  "version": "1.0.0",
  "size": $model_size,
  "files": [
    "$filename"
  ],
  "requirements": "$model_reqs",
  "installation_date": "$(date +%Y-%m-%d)",
  "download_url": "$model_url",
  "checksum": "$model_checksum"
}
EOF
    
    # Create an info.txt file with basic usage instructions
    local info_file="$model_dir/info.txt"
    
    cat > "$info_file" << EOF
Model: $model_name ($model_id)
Installed: $(date +%Y-%m-%d)
Size: $display_size

Requirements:
$(echo "$model_reqs" | sed 's/,/\n/g' | sed 's/:/: /g')

Usage Instructions:
- This model is ready to use with Leonardo AI Universal
- For API-based models, ensure you have the necessary API keys configured
- Refer to the documentation for specific usage examples
- Do not delete or modify any files in this directory

For support, visit: https://windsurf.io/leonardo
EOF
    
    # Update the main models index
    local index_file="$models_dir/index.json"
    
    # Create the directory structure if it doesn't exist
    mkdir -p "$(dirname "$index_file")"
    
    # Create or update the index file
    if [[ -f "$index_file" ]]; then
        # Check if jq is available for proper JSON manipulation
        if command -v jq &>/dev/null; then
            # Use jq to add model to array without parsing the whole file
            jq --arg id "$model_id" --arg name "$model_name" \
               '.models += [{"id": $id, "name": $name, "path": "'$model_id'"}]' \
               "$index_file" > "$index_file.tmp" && mv "$index_file.tmp" "$index_file"
        else
            # Simple append (not ideal but works without jq)
            # First remove the last two lines (closing brackets)
            head -n -2 "$index_file" > "$index_file.tmp"
            
            # Check if we need to add a comma
            if grep -q "\"id\":" "$index_file.tmp"; then
                echo "  }," >> "$index_file.tmp"
            else
                echo "  }" >> "$index_file.tmp"
            fi
            
            # Add the new model entry
            cat >> "$index_file.tmp" << EOF
  {
    "id": "$model_id",
    "name": "$model_name",
    "path": "$model_id"
  }
]
}
EOF
            # Replace the original file
            mv "$index_file.tmp" "$index_file"
        fi
    else
        # Create new index file
        cat > "$index_file" << EOF
{
  "last_updated": "$(date +%Y-%m-%d)",
  "models": [
    {
      "id": "$model_id",
      "name": "$model_name",
      "path": "$model_id"
    }
  ]
}
EOF
    fi
    
    # Update USB health data
    if [[ "$USB_HEALTH_TRACKING" == "true" ]]; then
        # Convert model size to bytes
        local size_bytes=$(( model_size * 1024 * 1024 ))
        update_usb_health_data "$partition" "$size_bytes"
    fi
    
    # Unmount the partition
    echo -e "Unmounting USB device..."
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Show success message
    show_success "$model_name has been installed successfully"
    
    return 0
}

# List installed models on USB device
list_installed_models() {
    local usb_path="$1"
    local partition_number="${2:-1}"
    local format="${3:-table}"  # table, list, or json
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    
    log_message "INFO" "Listing installed models on $partition in format: $format"
    
    # Check if device exists
    if [[ ! -b "$partition" ]]; then
        log_message "ERROR" "Partition $partition not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_list_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "$partition" "$mount_point"; then
        log_message "ERROR" "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if models directory exists
    local models_dir="$mount_point/leonardo/models"
    if [[ ! -d "$models_dir" ]]; then
        log_message "WARNING" "No models directory found on $partition"
        umount "$mount_point"
        rmdir "$mount_point"
        
        if [[ "$format" == "json" ]]; then
            echo '{"models": []}'
        else
            echo "No models installed on this device."
        fi
        return 0
    fi
    
    # Read models from index file or scan directories
    local index_file="$models_dir/index.json"
    local installed_models=()
    local model_names=()
    local model_sizes=()
    
    if [[ -f "$index_file" ]]; then
        # Read from index file if available
        if command -v jq &>/dev/null; then
            # Use jq to parse JSON if available
            while IFS= read -r line; do
                installed_models+=("$line")
            done < <(jq -r '.models[].id' "$index_file" 2>/dev/null)
            
            while IFS= read -r line; do
                model_names+=("$line")
            done < <(jq -r '.models[].name' "$index_file" 2>/dev/null)
        else
            # Simple grep parsing without jq
            while IFS= read -r line; do
                if [[ "$line" =~ \"id\":\ *\"([^\"]+)\" ]]; then
                    installed_models+=("${BASH_REMATCH[1]}")
                fi
                
                if [[ "$line" =~ \"name\":\ *\"([^\"]+)\" ]]; then
                    model_names+=("${BASH_REMATCH[1]}")
                fi
            done < "$index_file"
        fi
    else
        # Scan directories if no index file
        for model_dir in "$models_dir"/*; do
            if [[ -d "$model_dir" ]]; then
                local model_id=$(basename "$model_dir")
                installed_models+=("$model_id")
                
                # Try to get name from metadata
                local metadata_file="$model_dir/metadata.json"
                if [[ -f "$metadata_file" ]]; then
                    local name
                    if command -v jq &>/dev/null; then
                        name=$(jq -r '.name' "$metadata_file" 2>/dev/null)
                    else
                        name=$(grep -o '"name": *"[^"]*"' "$metadata_file" | sed 's/"name": *"\(.*\)"/\1/')
                    fi
                    model_names+=("$name")
                else
                    model_names+=("$model_id")
                fi
            fi
        done
    fi
    
    # Get model sizes
    for i in "${!installed_models[@]}"; do
        local model_dir="$models_dir/${installed_models[$i]}"
        local size_mb=0
        
        # Try to get size from metadata
        local metadata_file="$model_dir/metadata.json"
        if [[ -f "$metadata_file" ]]; then
            if command -v jq &>/dev/null; then
                size_mb=$(jq -r '.size' "$metadata_file" 2>/dev/null)
            else
                size_mb=$(grep -o '"size": *[0-9]*' "$metadata_file" | sed 's/"size": *\([0-9]*\)/\1/')
            fi
        fi
        
        # If metadata doesn't have size, calculate from files
        if [[ -z "$size_mb" || "$size_mb" == "null" || "$size_mb" -eq 0 ]]; then
            local size_bytes=$(du -sb "$model_dir" | cut -f1)
            size_mb=$(( size_bytes / 1024 / 1024 ))
        fi
        
        model_sizes+=("$size_mb")
    done
    
    # Output based on format
    case "$format" in
        table)
            # Print header
            printf "%-15s %-30s %-10s\n" "ID" "NAME" "SIZE"
            printf "%-15s %-30s %-10s\n" "---------------" "------------------------------" "----------"
            
            # Print each model
            for i in "${!installed_models[@]}"; do
                local id="${installed_models[$i]}"
                local name="${model_names[$i]}"
                local size="${model_sizes[$i]}"
                
                # Format size
                if [[ $size -ge 1024 ]]; then
                    size="$(echo "scale=1; $size / 1024" | bc) GB"
                else
                    size="$size MB"
                fi
                
                printf "%-15s %-30s %-10s\n" "$id" "$name" "$size"
            done
            ;;
        
        list)
            # Print each model on a line
            for i in "${!installed_models[@]}"; do
                local id="${installed_models[$i]}"
                local name="${model_names[$i]}"
                local size="${model_sizes[$i]}"
                
                # Format size
                if [[ $size -ge 1024 ]]; then
                    size="$(echo "scale=1; $size / 1024" | bc) GB"
                else
                    size="$size MB"
                fi
                
                echo "$id: $name ($size)"
            done
            ;;
        
        json)
            # Print as JSON
            echo "{"
            echo "  \"models\": ["
            
            local first=true
            for i in "${!installed_models[@]}"; do
                if [[ "$first" != "true" ]]; then
                    echo ","
                fi
                first=false
                
                local id="${installed_models[$i]}"
                local name="${model_names[$i]}"
                local size="${model_sizes[$i]}"
                
                echo -n "    {"
                echo -n "\"id\":\"$id\","
                echo -n "\"name\":\"$name\","
                echo -n "\"size\":$size"
                echo -n "}"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        
        *)
            log_message "WARNING" "Unknown format: $format"
            ;;
    esac
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    return 0
}

# Remove a model from USB device
remove_model() {
    local model_id="$1"
    local usb_path="$2"
    local partition_number="${3:-1}"
    
    log_message "INFO" "Removing model $model_id from $usb_path"
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    
    # Check if device exists
    if [[ ! -b "$partition" ]]; then
        show_error "Partition $partition not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_remove_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "$partition" "$mount_point"; then
        show_error "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if model exists
    local model_dir="$mount_point/leonardo/models/$model_id"
    if [[ ! -d "$model_dir" ]]; then
        show_error "Model $model_id not found on USB device"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Get model name and size
    local model_name="$model_id"
    local model_size=0
    
    # Try to get name and size from metadata
    local metadata_file="$model_dir/metadata.json"
    if [[ -f "$metadata_file" ]]; then
        if command -v jq &>/dev/null; then
            model_name=$(jq -r '.name' "$metadata_file" 2>/dev/null)
            model_size=$(jq -r '.size' "$metadata_file" 2>/dev/null)
        else
            model_name=$(grep -o '"name": *"[^"]*"' "$metadata_file" | sed 's/"name": *"\(.*\)"/\1/')
            model_size=$(grep -o '"size": *[0-9]*' "$metadata_file" | sed 's/"size": *\([0-9]*\)/\1/')
        fi
    fi
    
    # If metadata doesn't have size, calculate from files
    if [[ -z "$model_size" || "$model_size" == "null" || "$model_size" -eq 0 ]]; then
        local size_bytes=$(du -sb "$model_dir" | cut -f1)
        model_size=$(( size_bytes / 1024 / 1024 ))
    fi
    
    # Format size for display
    local display_size
    if [[ "$model_size" -gt 1024 ]]; then
        display_size="$(echo "scale=2; $model_size / 1024" | bc) GB"
    else
        display_size="$model_size MB"
    fi
    
    # Show warning with mischievous llama
    show_warning "You are about to remove $model_name ($model_id)" "caution"
    echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}This will free up ${CYAN}$display_size${ORANGE} of space.${NC}"
    echo -e "     All model files will be permanently deleted."
    echo ""
    
    # Confirm deletion
    if ! confirm_action "Remove this model?"; then
        echo -e "Operation cancelled."
        umount "$mount_point"
        rmdir "$mount_point"
        return 0
    fi
    
    # Remove the model directory
    rm -rf "$model_dir"
    
    # Update the index file if it exists
    local index_file="$mount_point/leonardo/models/index.json"
    if [[ -f "$index_file" ]]; then
        if command -v jq &>/dev/null; then
            # Use jq to remove model from array
            jq --arg id "$model_id" '.models = [.models[] | select(.id != $id)]' \
               "$index_file" > "$index_file.tmp" && mv "$index_file.tmp" "$index_file"
        else
            # Simple grep/sed based removal (not as reliable)
            grep -v "\"id\": *\"$model_id\"" "$index_file" > "$index_file.tmp"
            mv "$index_file.tmp" "$index_file"
        fi
    fi
    
    # Update USB health data
    if [[ "$USB_HEALTH_TRACKING" == "true" ]]; then
        # We don't track removals in write cycles, but it's a good idea to update the timestamp
        update_usb_health_data "$partition" 0
    fi
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Show success message
    show_success "$model_name has been removed successfully"
    
    return 0
}



# ==============================================================================
# Component: 06_deployment/installer.sh
# ==============================================================================
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



# ==============================================================================
# Component: 07_main/ui_utils.sh
# ==============================================================================
# ==============================================================================
# Leonardo AI Universal - UI Utilities
# ==============================================================================
# Description: UI utilities and helper functions for the main application
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/colors.sh,00_core/logging.sh,02_ui/basic.sh
# ==============================================================================

# Start a spinner for long-running operations
start_spinner() {
    local message="$1"
    
    # If the spinner function is defined in basic.sh, use it
    if declare -f spinner &>/dev/null; then
        spinner "$message" &
        SPINNER_PID=$!
        return 0
    fi
    
    # Otherwise, define a simple spinner
    local pid
    local delay=0.1
    local spinstr='|/-\'
    
    # Display the message
    echo -n "$message "
    
    # Start the spinner in the background
    (
        while :; do
            local temp=${spinstr#?}
            printf "%c" "${spinstr}"
            spinstr=${temp}${spinstr%"${temp}"}
            sleep ${delay}
            printf "\b"
        done
    ) &
    
    # Store the PID of the spinner
    SPINNER_PID=$!
    disown
}

# Stop the spinner
stop_spinner() {
    # If the spinner function is defined in basic.sh, use its stop function
    if declare -f stop_spinner &>/dev/null; then
        if [[ -n "$SPINNER_PID" ]]; then
            kill -TERM "$SPINNER_PID" &>/dev/null
            SPINNER_PID=""
        fi
        return 0
    fi
    
    # Otherwise, use our simple implementation
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" &>/dev/null
        SPINNER_PID=""
        echo -e "\b${GREEN}Done!${NC}"
    fi
}

# Wait for a keypress
wait_for_keypress() {
    echo -e "\n${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s
}

# Print a box header
print_box_header() {
    local title="$1"
    local width="$2"
    local color="${3:-$BLUE}"
    
    # Print top border
    printf "${color}${BOX_TL}${NC}"
    printf "${color}%${width}s${NC}" | tr ' ' "$BOX_H"
    printf "${color}${BOX_TR}${NC}\n"
    
    # Print title
    local title_len=${#title}
    local padding=$(( (width - title_len) / 2 ))
    
    printf "${color}${BOX_V}${NC}"
    printf "%${padding}s" ""
    printf "${BOLD}${color}%s${NC}" "$title"
    printf "%$((width - title_len - padding))s" ""
    printf "${color}${BOX_V}${NC}\n"
    
    # Print divider
    printf "${color}${BOX_LT}${NC}"
    printf "${color}%${width}s${NC}" | tr ' ' "$BOX_H"
    printf "${color}${BOX_RT}${NC}\n"
}

# Print a box footer
print_box_footer() {
    local width="$1"
    local color="${2:-$BLUE}"
    
    # Print bottom border
    printf "${color}${BOX_BL}${NC}"
    printf "${color}%${width}s${NC}" | tr ' ' "$BOX_H"
    printf "${color}${BOX_BR}${NC}\n"
}

# Print a progress bar
print_progress_bar() {
    local progress="$1"  # Percentage (0-100)
    local width="$2"     # Width of the progress bar
    local color="${3:-$GREEN}"
    
    # Calculate the number of filled and empty slots
    local filled_slots=$(( progress * width / 100 ))
    local empty_slots=$(( width - filled_slots ))
    
    # Print the progress bar
    printf "["
    printf "${color}%${filled_slots}s${NC}" | tr ' ' '#'
    printf "%${empty_slots}s" | tr ' ' '.'
    printf "] %3d%%\r" "$progress"
}

# Show a step header
show_step_header() {
    local title="$1"
    local width="${2:-80}"
    
    # Clear the screen
    clear
    
    # Print the banner
    print_banner "Leonardo AI Universal" "$width"
    
    # Print the step header
    echo -e "\n${BOLD}${BLUE}$title${NC}\n"
    
    # Draw a separator
    printf "${BLUE}%${width}s${NC}\n\n" | tr ' ' '-'
}

# Show an error message
show_error() {
    local message="$1"
    
    # Log the error
    log_message "ERROR" "$message"
    
    # Print the error message
    echo -e "\n${RED}Error:${NC} $message"
    echo ""
    
    # Wait for keypress
    wait_for_keypress
}

# Show a success message
show_success() {
    local message="$1"
    
    # Log the success
    log_message "INFO" "$message"
    
    # Print the success message with friendly llama
    echo -e "\n${GREEN}Success:${NC} $message"
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}All done!${NC}"
    echo ""
    
    # Wait for keypress
    wait_for_keypress
}

# Show a warning message
show_warning() {
    local message="$1"
    local severity="${2:-normal}"  # normal, caution, danger
    
    # Log the warning
    log_message "WARNING" "$message (severity: $severity)"
    
    # Determine color and llama based on severity
    local color="$YELLOW"
    local llama="(•ᴗ•)🦙"
    local llama_color="$YELLOW"
    
    if [[ "$severity" == "caution" ]]; then
        color="$ORANGE"
        llama="(>‿-)🦙"
        llama_color="$ORANGE"
    elif [[ "$severity" == "danger" ]]; then
        color="$RED"
        llama="(ಠ‿ಠ)🦙"
        llama_color="$RED"
    fi
    
    # Print the warning message with appropriate llama
    echo -e "\n${color}Warning:${NC} $message"
    echo -e "${llama_color}${llama}${NC} ${llama_color}Please proceed with caution.${NC}"
    echo ""
}

# Confirm an action
confirm_action() {
    local message="$1"
    local severity="${2:-normal}"  # normal, caution, danger
    
    # Determine prompt color based on severity
    local color="$YELLOW"
    if [[ "$severity" == "caution" ]]; then
        color="$LLAMA_COLOR_CAUTION"
    elif [[ "$severity" == "danger" ]]; then
        color="$RED"
    fi
    
    # Print the confirmation message
    echo -e "${color}$message${NC} (y/n) "
    
    # Get user input
    local response
    read -r response
    
    # Check response
    case "$response" in
        [Yy]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Print a banner
print_banner() {
    local title="$1"
    local width="${2:-80}"
    
    # Check if the banner function is defined in basic.sh
    if declare -f banner &>/dev/null; then
        banner "$title" "$width"
        return 0
    fi
    
    # Otherwise, use a simple banner implementation
    local title_len=${#title}
    local padding=$(( (width - title_len) / 2 ))
    
    # Print top border
    printf "${BLUE}%${width}s${NC}\n" | tr ' ' '='
    
    # Print title
    printf "%${padding}s" ""
    printf "${BOLD}${BLUE}%s${NC}\n" "$title"
    
    # Print bottom border
    printf "${BLUE}%${width}s${NC}\n" | tr ' ' '='
}

# Get device information
get_device_info() {
    local device="$1"
    local info_type="$2"  # model, size, serial
    
    # Try to get device information using various tools
    case "$info_type" in
        model)
            # Try lsblk first
            local model=$(lsblk -dno MODEL "$device" 2>/dev/null | tr -d '\n')
            
            # If empty, try hdparm
            if [[ -z "$model" ]] && command -v hdparm &>/dev/null; then
                model=$(hdparm -I "$device" 2>/dev/null | grep "Model Number" | cut -d: -f2 | tr -d ' \n')
            fi
            
            # If still empty, use device name
            if [[ -z "$model" ]]; then
                model=$(basename "$device")
            fi
            
            echo "$model"
            ;;
            
        size)
            # Try lsblk first
            lsblk -dno SIZE "$device" 2>/dev/null | tr -d '\n'
            ;;
            
        serial)
            # Try lsblk first
            local serial=$(lsblk -dno SERIAL "$device" 2>/dev/null | tr -d '\n')
            
            # If empty, try hdparm
            if [[ -z "$serial" ]] && command -v hdparm &>/dev/null; then
                serial=$(hdparm -I "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | tr -d ' \n')
            fi
            
            # If still empty, generate a unique identifier
            if [[ -z "$serial" ]]; then
                serial="$(basename "$device")_$(date +%Y%m%d%H%M%S)"
            fi
            
            echo "$serial"
            ;;
    esac
}

# Finalize the installation
finalize_installation() {
    local device="$1"
    
    # Show step header
    show_step_header "Installation Complete" "$UI_WIDTH"
    
    # Show success message with friendly llama
    echo -e "${GREEN}Congratulations!${NC} Your Leonardo AI USB device is ready."
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}Leonardo AI has been successfully installed.${NC}"
    echo ""
    
    # Mount the device to get partition info
    local mount_point="$TMP_DIR/finalize_mount"
    mkdir -p "$mount_point"
    
    if mount "${device}1" "$mount_point"; then
        # Get the number of models installed
        local model_count=0
        if [[ -d "$mount_point/leonardo/models" ]]; then
            model_count=$(find "$mount_point/leonardo/models" -type d -mindepth 1 -maxdepth 1 | wc -l)
        fi
        
        # Show information about the installation
        echo -e "${BOLD}Installation Summary:${NC}"
        echo -e "  Device: ${CYAN}$device${NC}"
        echo -e "  Filesystem: ${CYAN}$(lsblk -dno FSTYPE "${device}1")${NC}"
        echo -e "  Total Size: ${CYAN}$(lsblk -dno SIZE "$device")${NC}"
        echo -e "  Models Installed: ${CYAN}$model_count${NC}"
        echo ""
        
        # Show instructions for using the USB device
        echo -e "${BOLD}Next Steps:${NC}"
        echo -e "  1. Safely eject the USB device."
        echo -e "  2. Insert it into the computer where you want to use Leonardo AI."
        echo -e "  3. Run the ${CYAN}launcher.sh${NC} script on the USB device."
        echo ""
        
        # Show USB device path for reference
        echo -e "${BOLD}USB Device Path:${NC} ${CYAN}${device}1${NC}"
        echo ""
        
        # Unmount the device
        umount "$mount_point"
    else
        # Show warning that we couldn't get detailed information
        echo -e "${YELLOW}Note:${NC} Could not mount the device to get detailed information."
        echo -e "      The installation is complete, but please check the USB device manually."
        echo ""
    fi
    
    # Clean up
    rmdir "$mount_point" 2>/dev/null
    
    # Log the completion
    log_message "INFO" "Installation finalized for $device"
    
    # Wait for keypress
    wait_for_keypress
}



# ==============================================================================
# Component: 07_main/operations.sh
# ==============================================================================
# ==============================================================================
# Leonardo AI Universal - Core Operations
# ==============================================================================
# Description: Core operations for creating USB devices and managing models
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,02_ui/warnings.sh,03_filesystem/device.sh,03_filesystem/health.sh,05_models/registry.sh,05_models/installer.sh,06_deployment/installer.sh
# ==============================================================================

# Show the main menu
show_main_menu() {
    local choice
    
    while true; do
        # Display the main menu
        clear
        print_banner "Leonardo AI Universal" "$UI_WIDTH"
        
        echo -e "\n${BOLD}${BLUE}Main Menu:${NC}\n"
        # Color-coded menu options based on function
        echo -e "  ${CYAN}1.${NC} ${GREEN}Create New Leonardo AI USB${NC}"           # Green for creation
        echo -e "  ${CYAN}2.${NC} ${YELLOW}Add Models to Existing USB${NC}"          # Yellow for modification
        echo -e "  ${CYAN}3.${NC} ${BLUE}Check USB Health${NC}"                     # Blue for diagnostics
        echo -e "  ${CYAN}4.${NC} ${MAGENTA}List Available Models${NC}"              # Magenta for information
        echo -e "  ${CYAN}5.${NC} ${CYAN}System Information${NC}"                   # Cyan for system info
        echo -e "  ${RED}0.${NC} ${RED}Exit${NC}"                                  # Red for exit
        echo ""
        
        # Show friendly llama mascot
        echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}How can I help you today?${NC}"
        echo ""
        
        # Get user input
        echo -n "Enter your choice [0-5]: "
        read -r choice
        
        # Process the choice
        case $choice in
            1)
                create_new_usb
                ;;
            2)
                add_model_to_usb
                ;;
            3)
                check_usb_health
                ;;
            4)
                show_available_models
                ;;
            5)
                show_system_info
                ;;
            0)
                log_message "INFO" "User chose to exit"
                echo -e "\n${GREEN}Thank you for using Leonardo AI Universal!${NC}"
                cleanup_and_exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice. Please try again.${NC}"
                wait_for_keypress
                ;;
        esac
    done
}

# Create a new Leonardo AI USB device
create_new_usb() {
    log_message "INFO" "Starting USB creation process"
    
    # Check if we're in test mode
    local test_mode_prefix=""
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        test_mode_prefix="[TEST MODE] "
        log_message "INFO" "Running USB creation in TEST MODE (no actual formatting)"
    fi
    
    # Show step header
    show_step_header "Create New Leonardo AI USB" "$UI_WIDTH"
    
    # We are creating USB, warn the user about data loss
    echo -e "\n${BG_RED}${WHITE} ${test_mode_prefix}WARNING: DESTRUCTIVE OPERATION ${NC}"
    show_danger "This is a destructive operation that will erase ALL data on the selected device."
    echo -e "${RED}You are about to create a new Leonardo Universal USB drive.${NC}"
    echo -e "${RED}This will ${BOLD}ERASE ALL DATA${NC}${RED} on the selected USB drive.${NC}"
    echo -e "${YELLOW}Make sure you have backed up any important files.${NC}\n"
    
    # Confirm the action
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operation canceled."
        return 1
    fi
    
    log_message "DEBUG" "User confirmed USB creation"
    
    # Select USB device - SIMPLIFIED FLOW TO PREVENT FREEZING
    log_message "DEBUG" "Calling select_usb_device..."
    local device_path
    device_path=$(select_usb_device)
    select_status=$?
    
    log_message "DEBUG" "select_usb_device returned: $select_status, device_path=$device_path"
    
    if [[ $select_status -ne 0 || -z "$device_path" ]]; then
        echo -e "${RED}No USB device selected.${NC}"
        return 1
    fi
    
    # Verify the selection with one more warning
    log_message "DEBUG" "Verifying USB device: $device_path"
    if ! verify_usb_device "$device_path"; then
        log_message "INFO" "User canceled USB device verification"
        return 1
    fi
    
    # If in test mode, stop here and show success message
    if [[ -n "${LEONARDO_TEST_MODE:-}" ]]; then
        echo -e "\n${GREEN}TEST MODE: USB device selection successful!${NC}"
        echo -e "Selected device: ${CYAN}$device_path${NC}"
        echo -e "${YELLOW}Note: No actual formatting performed in test mode.${NC}"
        return 0
    fi
    
    # SIMPLIFIED - REMOVED DUPLICATE CONFIRMATION AND SELECTION
    # Format the device
    echo -e "\n${GREEN}Preparing to format USB device: ${CYAN}$device_path${NC}"
    log_message "INFO" "Preparing to format USB device: $device_path"
    
    # Add clear debug messages
    echo -e "${YELLOW}Device path: $device_path${NC}"
    log_message "DEBUG" "Proceeding with device: $device_path"
    
    # No need for second verification - already verified above
    # Continue with formatting process
    
    # Show filesystem selection menu
    show_step_header "Select Filesystem" "$UI_WIDTH"
    echo -e "Choose a filesystem type for your Leonardo AI USB device:"
    echo ""
    echo -e "  ${CYAN}1.${NC} exFAT     (${GREEN}Recommended${NC}, compatible with Windows, macOS, Linux)"
    echo -e "  ${CYAN}2.${NC} NTFS      (Windows, limited macOS/Linux support)"
    echo -e "  ${CYAN}3.${NC} ext4      (Linux only)"
    echo -e "  ${CYAN}4.${NC} FAT32     (All systems, 4GB file size limit)"
    echo ""
    
    # Get filesystem choice
    local fs_choice
    echo -n "Enter your choice [1-4, default=1]: "
    read -r fs_choice
    
    # Set filesystem based on choice
    case $fs_choice in
        2)
            FS_TYPE="ntfs"
            ;;
        3)
            FS_TYPE="ext4"
            ;;
        4)
            FS_TYPE="vfat"
            ;;
        *)
            FS_TYPE="exfat"
            ;;
    esac
    
    log_message "INFO" "Selected filesystem: $FS_TYPE"
    
    # Show data destruction warning with intense llama
    show_data_destruction_warning "$device" "format with $FS_TYPE"
    
    # Final confirmation with danger llama
    if ! confirm_action "I understand this will DESTROY ALL DATA. Proceed?" "danger"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "USB creation cancelled at final confirmation"
        return 0
    fi
    
    # Format the device
    show_step_header "Formatting USB Device" "$UI_WIDTH"
    echo -e "Formatting ${CYAN}$device${NC} with ${CYAN}$FS_TYPE${NC} filesystem..."
    echo -e "This may take a few minutes. Please wait..."
    echo ""
    
    # Use spinner while formatting
    start_spinner "Formatting"
    
    if ! format_usb_device "$device" "$FS_TYPE"; then
        stop_spinner
        show_error "Failed to format the USB device.\nPlease check the logs for details."
        log_message "ERROR" "USB formatting failed for $device with $FS_TYPE"
        return 1
    fi
    
    stop_spinner
    show_success "USB device formatted successfully"
    
    # Install Leonardo AI framework
    show_step_header "Installing Leonardo AI" "$UI_WIDTH"
    echo -e "Installing Leonardo AI Universal to the USB device..."
    echo ""
    
    # Use spinner while installing
    start_spinner "Installing"
    
    if ! install_leonardo_framework "$device"; then
        stop_spinner
        show_error "Failed to install Leonardo AI framework.\nPlease check the logs for details."
        log_message "ERROR" "Leonardo AI framework installation failed"
        return 1
    fi
    
    stop_spinner
    show_success "Leonardo AI framework installed successfully"
    
    # Prompt for model installation
    show_step_header "Model Installation" "$UI_WIDTH"
    echo -e "Would you like to install an AI model now?"
    echo -e "You can add models later using the 'Add Models' option from the main menu."
    echo ""
    
    if confirm_action "Install AI model now?"; then
        # Get the system requirements
        local total_mem=$(free -m | awk '/^Mem:/{print $2}')
        local total_mem_gb=$((total_mem / 1024))
        
        # Select model to install
        local model_id
        model_id=$(select_model "$total_mem_gb" "$GPU_MEMORY")
        
        if [[ -n "$model_id" ]]; then
            # Install the selected model
            show_step_header "Installing Model" "$UI_WIDTH"
            echo -e "Installing ${CYAN}$(get_model_info "$model_id" "name")${NC}..."
            echo ""
            
            if ! install_model "$model_id" "$device"; then
                show_error "Failed to install the model.\nPlease check the logs for details."
                log_message "ERROR" "Model installation failed for $model_id"
            else
                show_success "Model installed successfully"
            fi
        else
            echo -e "\n${YELLOW}Model installation skipped.${NC}"
            log_message "INFO" "Model installation skipped"
        fi
    else
        echo -e "\n${YELLOW}Model installation skipped.${NC}"
        log_message "INFO" "Model installation skipped by user"
    fi
    
    # Finalize the installation
    finalize_installation "$device"
    
    # Return success
    return 0
}

# Add a model to an existing USB device
add_model_to_usb() {
    log_message "INFO" "Starting model addition process"
    
    # Show step header
    show_step_header "Add Models to Existing USB" "$UI_WIDTH"
    
    # Show initial guidance with friendly llama
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}This will add AI models to an existing Leonardo AI USB device.${NC}"
    echo -e "     Please make sure your USB device is connected."
    echo ""
    
    # Confirm initial action
    if ! confirm_action "Continue with model addition?"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "Model addition cancelled by user at initial confirmation"
        return 0
    fi
    
    # Get the USB device
    local device
    device=$(select_usb_device)
    
    # Check if device selection was cancelled
    if [[ -z "$device" ]]; then
        echo -e "\n${YELLOW}Device selection cancelled.${NC}"
        log_message "INFO" "Model addition cancelled: no device selected"
        return 0
    fi
    
    # Verify the selected device
    if ! verify_usb_device "$device"; then
        echo -e "\n${YELLOW}Device verification cancelled.${NC}"
        log_message "INFO" "Model addition cancelled: device verification failed"
        return 0
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_check_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "${device}1" "$mount_point"; then
        show_error "Failed to mount the USB device.\nPlease check that it is properly formatted."
        log_message "ERROR" "Failed to mount ${device}1"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if Leonardo AI is installed
    if [[ ! -d "$mount_point/leonardo" ]]; then
        umount "$mount_point"
        rmdir "$mount_point"
        show_error "Leonardo AI not found on this USB device.\nPlease use the 'Create New Leonardo AI USB' option first."
        log_message "ERROR" "Leonardo AI not found on ${device}1"
        return 1
    fi
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Get the system requirements
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb=$((total_mem / 1024))
    
    # Select model to install
    show_step_header "Select AI Model" "$UI_WIDTH"
    echo -e "Select an AI model to install:"
    echo ""
    
    local model_id
    model_id=$(select_model "$total_mem_gb" "$GPU_MEMORY")
    
    if [[ -z "$model_id" ]]; then
        echo -e "\n${YELLOW}Model selection cancelled.${NC}"
        log_message "INFO" "Model addition cancelled: no model selected"
        return 0
    fi
    
    # Confirm model installation with caution llama
    show_warning "You are about to install $(get_model_info "$model_id" "name")" "caution"
    echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}This may take some time depending on your internet connection.${NC}"
    echo -e "     Model size: ${CYAN}$(get_model_info "$model_id" "size")MB${NC}"
    echo -e "     Requirements: ${CYAN}$(get_model_info "$model_id" "requirements")${NC}"
    echo ""
    
    if ! confirm_action "Continue with model installation?"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "Model addition cancelled by user at model confirmation"
        return 0
    fi
    
    # Install the selected model
    show_step_header "Installing Model" "$UI_WIDTH"
    echo -e "Installing ${CYAN}$(get_model_info "$model_id" "name")${NC}..."
    echo ""
    
    if ! install_model "$model_id" "$device"; then
        show_error "Failed to install the model.\nPlease check the logs for details."
        log_message "ERROR" "Model installation failed for $model_id"
        return 1
    fi
    
    # Show success message
    show_success "Model installed successfully"
    
    # Ask if user wants to install another model
    if confirm_action "Would you like to install another model?"; then
        add_model_to_usb
    else
        echo -e "\n${GREEN}Models installation complete.${NC}"
        log_message "INFO" "Model addition completed successfully"
        wait_for_keypress
    fi
    
    # Return success
    return 0
}

# Check USB device health
check_usb_health() {
    log_message "INFO" "Starting USB health check"
    
    # Show step header
    show_step_header "Check USB Health" "$UI_WIDTH"
    
    # Show initial guidance with friendly llama
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} ${YELLOW}This will check the health of your Leonardo AI USB device.${NC}"
    echo -e "     Please make sure your USB device is connected."
    echo ""
    
    # Confirm initial action
    if ! confirm_action "Continue with health check?"; then
        echo -e "\n${YELLOW}Operation cancelled.${NC}"
        log_message "INFO" "Health check cancelled by user at initial confirmation"
        return 0
    fi
    
    # Get the USB device
    local device
    device=$(select_usb_device)
    
    # Check if device selection was cancelled
    if [[ -z "$device" ]]; then
        echo -e "\n${YELLOW}Device selection cancelled.${NC}"
        log_message "INFO" "Health check cancelled: no device selected"
        return 0
    fi
    
    # Verify the selected device
    if ! verify_usb_device "$device"; then
        echo -e "\n${YELLOW}Device verification cancelled.${NC}"
        log_message "INFO" "Health check cancelled: device verification failed"
        return 0
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/health_check_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "${device}1" "$mount_point"; then
        show_error "Failed to mount the USB device.\nPlease check that it is properly formatted."
        log_message "ERROR" "Failed to mount ${device}1"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if Leonardo AI is installed
    if [[ ! -d "$mount_point/leonardo" ]]; then
        umount "$mount_point"
        rmdir "$mount_point"
        show_error "Leonardo AI not found on this USB device.\nPlease use the 'Create New Leonardo AI USB' option first."
        log_message "ERROR" "Leonardo AI not found on ${device}1"
        return 1
    fi
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Display USB health
    show_step_header "USB Health Report" "$UI_WIDTH"
    echo -e "Analyzing USB device health..."
    echo ""
    
    # Display health information
    if ! display_usb_health "${device}1"; then
        show_warning "No health data found for this device." "caution"
        echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}This USB device may not have been created with health tracking.${NC}"
        echo -e "     Consider creating a new USB device with health tracking enabled."
        log_message "WARNING" "No health data found for ${device}1"
    fi
    
    # Wait for user acknowledgment
    echo ""
    wait_for_keypress
    
    # Return success
    return 0
}

# Show available models
show_available_models() {
    log_message "INFO" "Displaying available models"
    
    # Show step header
    show_step_header "Available AI Models" "$UI_WIDTH"
    
    # Get the system requirements
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb=$((total_mem / 1024))
    
    # Show models compatible with this system
    echo -e "Models compatible with your system (${CYAN}${total_mem_gb}GB RAM${NC}, ${CYAN}${GPU_MEMORY}MB GPU${NC}):"
    echo ""
    
    # Filter and display models
    filter_models_by_requirements "$total_mem_gb" "$GPU_MEMORY"
    
    # Wait for user acknowledgment
    echo ""
    wait_for_keypress
    
    # Return success
    return 0
}

# Show system information
show_system_info() {
    log_message "INFO" "Displaying system information"
    
    # Show step header
    show_step_header "System Information" "$UI_WIDTH"
    
    # Get system information
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb=$(echo "scale=1; $total_mem / 1024" | bc)
    local free_space=$(df -h . | awk 'NR==2 {print $4}')
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^ *//')
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
    
    # Display system information
    print_box_header "System Information" "$UI_WIDTH" "$BLUE"
    
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "OS:" "$(uname -o)" $((UI_WIDTH - 25 - $(uname -o | wc -c))) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Kernel:" "$(uname -r)" $((UI_WIDTH - 25 - $(uname -r | wc -c))) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "CPU:" "$cpu_model" $((UI_WIDTH - 25 - ${#cpu_model})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "CPU Cores:" "$cpu_cores" $((UI_WIDTH - 25 - ${#cpu_cores})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s GB${NC}%*s ${BLUE}${BOX_V}${NC}\n" "RAM:" "$total_mem_gb" $((UI_WIDTH - 28 - ${#total_mem_gb})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Free Disk Space:" "$free_space" $((UI_WIDTH - 25 - ${#free_space})) ""
    
    # GPU information
    if [[ "$SYSTEM_HAS_NVIDIA_GPU" == "true" ]]; then
        local gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "GPU:" "$gpu_model" $((UI_WIDTH - 25 - ${#gpu_model})) ""
        printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s MB${NC}%*s ${BLUE}${BOX_V}${NC}\n" "GPU Memory:" "$GPU_MEMORY" $((UI_WIDTH - 29 - ${#GPU_MEMORY})) ""
    else
        printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "GPU:" "None detected" $((UI_WIDTH - 25 - 13)) ""
    fi
    
    # Application information
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$BLUE"
    
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Leonardo Version:" "6.0.0" $((UI_WIDTH - 25 - 5)) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Log Level:" "$LOG_LEVEL" $((UI_WIDTH - 25 - ${#LOG_LEVEL})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Debug Mode:" "$DEBUG_MODE" $((UI_WIDTH - 25 - ${#DEBUG_MODE})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "UTF-8 Support:" "$HAS_UTF8_LOCALE" $((UI_WIDTH - 25 - ${#HAS_UTF8_LOCALE})) ""
    printf "${BLUE}${BOX_V}${NC} %-20s ${BOLD}%s${NC}%*s ${BLUE}${BOX_V}${NC}\n" "Color Support:" "$HAS_COLOR_SUPPORT" $((UI_WIDTH - 25 - ${#HAS_COLOR_SUPPORT})) ""
    
    # Footer
    print_box_footer "$UI_WIDTH" "$BLUE"
    
    # Wait for user acknowledgment
    echo ""
    wait_for_keypress
    
    # Return success
    return 0
}

# Show data destruction warning
show_data_destruction_warning() {
    local device="$1"
    local operation="$2"
    
    # Get device info
    local device_model=$(get_device_info "$device" "model")
    local device_size=$(get_device_info "$device" "size")
    
    # Helper function for box lines
    print_box_line() {
        local char="$1"
        local width="$2"
        local left_edge="${3:-$char}"
        local right_edge="${4:-$char}"
        local color="${5:-$RED}"
        
        printf "${color}${left_edge}${NC}"
        printf "${color}%${width}s${NC}" | tr ' ' "$char"
        printf "${color}${right_edge}${NC}\n"
    }
    
    # Clear screen and show warning box
    clear
    echo ""
    
    # Warning header
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_TL" "$BOX_TR" "$RED"
    
    # Title
    local title="⚠️ DATA DESTRUCTION IMMINENT ⚠️"
    local padding=$(( (UI_WIDTH - ${#title}) / 2 ))
    printf "${RED}${BOX_V}${NC}%${padding}s${BOLD}${RED}%s${NC}%${padding}s${RED}${BOX_V}${NC}\n" "" "$title" ""
    
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_LT" "$BOX_RT" "$RED"
    
    # Intense llama warning
    printf "${RED}${BOX_V}${NC} ${RED}(ಠ‿ಠ)🦙 THIS IS YOUR FINAL WARNING!${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 35)) ""
    
    # Empty line
    printf "${RED}${BOX_V}${NC}%${UI_WIDTH}s${RED}${BOX_V}${NC}\n" ""
    
    # Target info
    printf "${RED}${BOX_V}${NC} ${BOLD}Target Device:${NC} ${CYAN}$device${NC} ($device_model, $device_size)%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 50 - ${#device} - ${#device_model} - ${#device_size})) ""
    printf "${RED}${BOX_V}${NC} ${BOLD}Operation:${NC} ${CYAN}$operation${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 30 - ${#operation})) ""
    
    # Empty line
    printf "${RED}${BOX_V}${NC}%${UI_WIDTH}s${RED}${BOX_V}${NC}\n" ""
    
    # Consequences
    printf "${RED}${BOX_V}${NC} ${BOLD}This operation will:${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 25)) ""
    printf "${RED}${BOX_V}${NC}   - ${RED}PERMANENTLY ERASE ALL DATA${NC} on the device%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 45)) ""
    printf "${RED}${BOX_V}${NC}   - ${RED}DELETE ALL EXISTING PARTITIONS${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 35)) ""
    printf "${RED}${BOX_V}${NC}   - ${RED}DESTROY ALL FILE SYSTEMS${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 30)) ""
    
    # Empty line
    printf "${RED}${BOX_V}${NC}%${UI_WIDTH}s${RED}${BOX_V}${NC}\n" ""
    
    # Verification
    printf "${RED}${BOX_V}${NC} ${BOLD}Verify that:${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 20)) ""
    printf "${RED}${BOX_V}${NC}   - You have backed up all important data%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 45)) ""
    printf "${RED}${BOX_V}${NC}   - You have selected the correct device%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 43)) ""
    printf "${RED}${BOX_V}${NC}   - You understand this action is ${BOLD}${RED}IRREVERSIBLE${NC}%*s${RED}${BOX_V}${NC}\n" $((UI_WIDTH - 50)) ""
    
    # Footer
    print_box_line "$BOX_H" "$UI_WIDTH" "$BOX_BL" "$BOX_BR" "$RED"
    
    # Log the warning
    log_message "WARNING" "Data destruction warning displayed for $device"
    
    # Empty line
    echo ""
}

# Cleanup and exit
cleanup_and_exit() {
    local exit_code="$1"
    
    log_message "INFO" "Cleaning up temporary files"
    
    # Remove temporary directories if they exist
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    
    log_message "INFO" "Exiting with code $exit_code"
    exit "$exit_code"
}

# Call main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi



# ==============================================================================
# Component: 07_main/main.sh
# ==============================================================================
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



# ==============================================================================
# Component: 00_core/footer.sh
# ==============================================================================
# ==============================================================================
# Leonardo AI Universal - Core Footer
# ==============================================================================
# Description: Script footer that ensures main function is called at the end
# Author: Leonardo AI Team
# Version: 6.0.0
# ==============================================================================

# Call main function if script is executed directly (moved to end of script)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

