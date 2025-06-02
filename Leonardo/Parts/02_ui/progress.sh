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
