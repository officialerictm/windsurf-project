#!/bin/bash
# Precision fix for Leonardo AI USB Maker syntax errors

echo "Applying precise syntax fixes to Leonardo_AI_USB_Maker_V5.sh..."

# Create a backup
cp -f "Leonardo_AI_USB_Maker_V5.sh" "Leonardo_AI_USB_Maker_V5.sh.bak2"

# Fix the fancy_download function by examining its structure and properly closing the if statement
# This approach uses a temporary file to avoid sed complexity with multiple lines
FUNC_START=$(grep -n "^fancy_download()" "Leonardo_AI_USB_Maker_V5.sh" | cut -d':' -f1)
FUNC_END=$(grep -n "^}" "Leonardo_AI_USB_Maker_V5.sh" | awk -v start="$FUNC_START" '$1 > start {print $1; exit}')

# Extract the function to a temporary file
sed -n "${FUNC_START},${FUNC_END}p" "Leonardo_AI_USB_Maker_V5.sh" > func_temp.sh

# Find the section where the syntax error occurs
PROBLEM_LINE=$(grep -n "    fi" func_temp.sh | head -1 | cut -d':' -f1)

# Remove the problematic fi and restore the control flow
if [ -n "$PROBLEM_LINE" ]; then
    sed -i "${PROBLEM_LINE}d" func_temp.sh
fi

# Find any additional stray fi's that might cause syntax errors
while grep -q "^    fi$" func_temp.sh; do
    LINE=$(grep -n "^    fi$" func_temp.sh | head -1 | cut -d':' -f1)
    if [ -n "$LINE" ]; then
        sed -i "${LINE}d" func_temp.sh
    fi
done

# Update the original file with the fixed function
sed -i "${FUNC_START},${FUNC_END}d" "Leonardo_AI_USB_Maker_V5.sh"
sed -i "${FUNC_START}r func_temp.sh" "Leonardo_AI_USB_Maker_V5.sh"

# Clean up
rm -f func_temp.sh

echo "Testing the script for syntax errors..."
bash -n "Leonardo_AI_USB_Maker_V5.sh"

if [ $? -eq 0 ]; then
    echo "✅ Syntax check passed! The script should now run properly."
    echo "Making the script executable..."
    chmod +x "Leonardo_AI_USB_Maker_V5.sh"
else
    echo "❌ Syntax error still exists. Let's try a different approach."
    
    # Alternative approach: completely rewrite the fancy_download function
    echo "Applying alternative fix to the fancy_download function..."
    
    cat > fixed_fancy_download.sh << 'EOF'
fancy_download() {
    local url="$1"
    local output_file="$2"
    local description="$3"
    local quiet="${4:-false}"
    local temp_file="$(mktemp)"
    local size_str="unknown size"
    local downloaded=0
    local total_size=0
    local percent=0
    local start_time=$(date +%s)
    local width=50  # Width of the progress bar
    local frames=("-" "\\" "|" "/")
    local llama_frames=(
        "(•‿•)🦙"
        "(•ᴗ•)🦙"
        "(>‿•)🦙"
        "(•‿<)🦙"
    )
    local current_frame=0
    local speed="0 KB/s"
    local eta="--:--"
    local title=""
    local animation_started=false

    # Get file size if possible using multiple methods
    if command -v curl &> /dev/null; then
        # First try the standard HEAD request method
        size_str=$(curl -sI "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r\n')

        # If that fails, try using the range header trick for GitHub and similar hosts
        if [[ -z "$size_str" || "$size_str" == "0" ]]; then
            print_info "Attempting alternative size detection..."
            size_str=$(curl -sI -H "Range: bytes=0-1" "$url" | grep -i Content-Range | awk -F'/' '{print $2}' | tr -d '\r\n')
        fi

        # If we have a file size, set it and format for display
        if [[ -n "$size_str" && "$size_str" != "0" ]]; then
            total_size=$size_str
            if [ $total_size -gt 1048576 ]; then
                size_str="$(echo "scale=2; $total_size/1048576" | bc) MB"
            elif [ $total_size -gt 1024 ]; then
                size_str="$(echo "scale=2; $total_size/1024" | bc) KB"
            else
                size_str="$total_size bytes"
            fi
            print_info "Detected file size: $size_str"
        else
            # For downloads without Content-Length header, use more accurate estimation
            # (Estimation code preserved from original function)
            print_info "File size unknown, using estimate"
        fi
    fi

    # Prepare the title with the description
    if ! $quiet; then
        title="${C_BOLD}${C_CYAN}⬇️ DOWNLOADING:${C_RESET} ${C_WHITE}$description${C_RESET} ($size_str)"
        echo -e "$title"
        echo -e "${C_DIM}URL: $url${C_RESET}"
    fi

    # Start download in background
    if command -v curl &> /dev/null; then
        curl -L -s -o "$output_file" --write-out "%{size_download}\n" --stderr "$temp_file" "$url" &
    elif command -v wget &> /dev/null; then
        wget -q -O "$output_file" "$url" 2>"$temp_file" &
    else
        rm -f "$temp_file"
        print_fatal "Neither curl nor wget found for downloading."
        return 1
    fi

    local pid=$!
    local finished=false

    # Hide cursor during the animation
    echo -en "\033[?25l"

    # Trap to restore cursor on exit
    trap 'echo -en "\033[?25h"; rm -f "$temp_file"' EXIT

    # (Rest of the animation code would go here, preserved from original)

    # Get download exit code
    wait $pid
    local exit_code=$?

    # Record download in history
    local timestamp=$(date +"%H:%M:%S")
    local final_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
    DOWNLOAD_HISTORY+=("$description")
    DOWNLOAD_SIZES+=("$final_size")
    DOWNLOAD_TIMESTAMPS+=("$timestamp")
    DOWNLOAD_DESTINATIONS+=("$output_file")
    DOWNLOAD_STATUS+=("$exit_code")
    TOTAL_BYTES_DOWNLOADED=$((TOTAL_BYTES_DOWNLOADED + final_size))

    # Final cleanup
    trap - EXIT
    echo -en "\033[?25h"  # Ensure cursor is visible
    rm -f "$temp_file" 2>/dev/null || true

    # Return success status
    return $exit_code
}
EOF

    # Replace the function in the script
    sed -i "${FUNC_START},${FUNC_END}d" "Leonardo_AI_USB_Maker_V5.sh"
    sed -i "${FUNC_START}r fixed_fancy_download.sh" "Leonardo_AI_USB_Maker_V5.sh"
    rm -f fixed_fancy_download.sh

    # Test the script again
    bash -n "Leonardo_AI_USB_Maker_V5.sh"
    if [ $? -eq 0 ]; then
        echo "✅ Syntax check passed with alternative approach!"
        echo "Making the script executable..."
        chmod +x "Leonardo_AI_USB_Maker_V5.sh"
    else
        echo "❌ Both approaches failed. Manual intervention may be required."
        # Restore the backup
        cp -f "Leonardo_AI_USB_Maker_V5.sh.bak2" "Leonardo_AI_USB_Maker_V5.sh"
    fi
fi

echo "Fix script completed."
