#!/bin/bash

# Test script for the list_usb_devices function
# This will help verify the USB device detection and UI rendering

# Set up necessary variables and functions first
# We need to define these before sourcing the device.sh file

# Define UI width for device display
UI_WIDTH=72

# Define color constants
COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_MAGENTA="\033[1;35m"
COLOR_CYAN="\033[1;36m"
COLOR_WHITE="\033[1;37m"
COLOR_BOLD="\033[1m"

# Export VERBOSE for debugging
export VERBOSE=true

# Define basic logging functions if not already available
print_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "[DEBUG] $*" >&2
    fi
}

print_info() {
    echo -e "[INFO] $*" >&2
}

print_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*" >&2
}

print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Helper function to repeat a character
repeat_char() {
    local char="$1"
    local count="$2"
    printf "%${count}s" | tr ' ' "$char"
}

# Function to clear screen and show art (placeholder)
clear_screen_and_show_art() {
    clear
    echo -e "\n${COLOR_CYAN}=== Leonardo AI USB Maker - Device Detection Test ===${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}       (•ᴗ•)🦙 Device Detection Test${COLOR_RESET}\n"
}

# Empty the arrays used by the device detection
_CASCADE_USB_PATHS=()
_CASCADE_USB_DISPLAY_STRINGS=()

# Source the device functions file
source "./Leonardo/Parts/03_filesystem/device.sh"

# Clear the screen to prepare for test
clear

echo "===== Testing USB Device Detection ====="
echo "Running list_usb_devices function...\n"

# Run the function
if list_usb_devices; then
    echo "\nSuccess! Found USB devices and displayed selection UI."
    echo "Number of devices found: ${#_CASCADE_USB_PATHS[@]}"
    echo
    echo "Device paths:"
    for path in "${_CASCADE_USB_PATHS[@]}"; do
        echo "  - $path"
    done
    echo
    echo "Device display strings:"
    for display in "${_CASCADE_USB_DISPLAY_STRINGS[@]}"; do
        echo "  - $display"
    done
else
    echo "\nNo USB devices found or error occurred."
fi

echo
echo "Test completed."
