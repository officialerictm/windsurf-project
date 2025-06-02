#!/bin/bash

# Leonardo AI USB Maker Launcher Script
# This script provides better terminal compatibility and handles sudo gracefully

# Set terminal variables for better color support
export TERM=xterm-256color
export COLORTERM=truecolor

# Define script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/leonardo_master.sh"

# Ensure the main script is executable
chmod +x "$MAIN_SCRIPT" 2>/dev/null

# Flag to track whether to use root
USE_ROOT=0

# Function to show help
show_help() {
    echo "Leonardo AI USB Maker - Launcher"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --no-root     Run without sudo (limited functionality)"
    echo "  --help        Show this help message"
}

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        --no-root)
            USE_ROOT=0
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
    esac
 done

# Run the script
if [ "$(id -u)" != "0" ] && [ "$USE_ROOT" -eq 1 ]; then
    echo "Note: Some USB operations require root privileges."
    echo "You may be prompted for your password."
    
    # Try different sudo approaches
    if sudo -n true 2>/dev/null; then
        # Sudo with no password works
        sudo -E "$MAIN_SCRIPT" "$@"
    else
        # Regular sudo - might prompt for password
        if [ -t 0 ]; then
            # Terminal is interactive
            sudo -E "$MAIN_SCRIPT" "$@"
        else
            # Non-interactive - use a more basic approach
            echo "Error: This script requires an interactive terminal for sudo."
            echo "Try running directly with: sudo ./leonardo_master.sh"
            exit 1
        fi
    fi
else
    # Run without sudo
    "$MAIN_SCRIPT" "$@"
fi

exit $?
