#!/bin/bash
# Test script for USB device detection

echo "============================================================"
echo "                  USB DETECTION TEST SCRIPT                  "
echo "============================================================"
echo

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}1. Checking for root privileges${NC}"
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Not running as root. Some operations may be limited.${NC}"
else
    echo -e "${GREEN}Running with root privileges.${NC}"
fi
echo

echo -e "${CYAN}2. Raw listing of all block devices${NC}"
echo -e "${YELLOW}Running: lsblk -dp${NC}"
lsblk -dp
echo

echo -e "${CYAN}3. Detailed listing with USB info${NC}"
echo -e "${YELLOW}Running: lsblk -dpno NAME,SIZE,MODEL,TRAN,RM${NC}"
lsblk -dpno NAME,SIZE,MODEL,TRAN,RM
echo

echo -e "${CYAN}4. Finding USB removable devices${NC}"
usb_devices=()
display_strings=()

# Function to process each line
process_device_line() {
    line="$1"
    # Skip if empty
    [ -z "$line" ] && return
    
    # Parse fields while handling spaces in model names
    # Format: NAME SIZE MODEL TRAN RM
    path=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    
    # Extract transport (TRAN) which is near the end
    transport=""
    removable=""
    if [[ "$line" =~ usb[[:space:]]+([0-9]) ]]; then
        transport="usb"
        removable="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ sata[[:space:]]+([0-9]) ]]; then
        transport="sata"
        removable="${BASH_REMATCH[1]}"
    fi
    
    # Get model by removing the known fields
    model=$(echo "$line" | awk -v path="$path" -v size="$size" -v transport="$transport" -v removable="$removable" \
        '{sub(path, ""); sub(size, ""); sub(transport, ""); sub(removable, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}')
    
    echo -e "Checking device: path=${YELLOW}$path${NC}, size=$size, model='$model', transport=${BLUE}$transport${NC}, removable=${GREEN}$removable${NC}"
    
    # Only include USB devices with removable flag
    if [[ "$transport" == "usb" && "$removable" == "1" ]]; then
        # Add the device to our arrays
        usb_devices+=("$path")
        
        # Clean up model name (replace underscores with spaces)
        model="${model//_/ }"
        
        # Create display string
        display_string="${path} (${size} - ${model})"
        display_strings+=("$display_string")
        
        echo -e "${GREEN}Found USB device: $display_string${NC}"
    fi
}

# Process each line from lsblk
while IFS= read -r line; do
    process_device_line "$line"
done < <(lsblk -dpno NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | sort)

echo
echo -e "${CYAN}5. Summary of detected USB devices${NC}"
if [[ ${#usb_devices[@]} -gt 0 ]]; then
    echo -e "${GREEN}Found ${#usb_devices[@]} USB devices:${NC}"
    for ((i=0; i<${#usb_devices[@]}; i++)); do
        echo "  $((i+1)). ${display_strings[$i]}"
    done
else
    echo -e "${RED}No USB devices found.${NC}"
    echo "Please connect a USB drive and try again."
fi

echo
echo -e "${CYAN}6. Local environment variables${NC}"
echo "PATH=$PATH"
echo "TERM=$TERM"

echo
echo "============================================================"
echo "                    TEST SCRIPT COMPLETE                     "
echo "============================================================"
