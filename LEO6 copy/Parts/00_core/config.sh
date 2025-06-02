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
