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
