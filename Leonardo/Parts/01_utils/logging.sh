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
