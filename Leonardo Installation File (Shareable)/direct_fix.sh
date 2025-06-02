#!/bin/bash

# This script takes a direct approach to fix the syntax error by examining and repairing
# the entire fancy_download function

# Start with a fresh copy of the original file
cp -f "Leonardo_AI_USB_Maker_V5.sh.bak" "Leonardo_AI_USB_Maker_V5.sh"

# Extract the problematic function to analyze its structure
echo "Extracting and analyzing the fancy_download function..."
line_start=$(grep -n "^fancy_download()" "Leonardo_AI_USB_Maker_V5.sh" | cut -d':' -f1)
line_end=$(grep -n "^}" "Leonardo_AI_USB_Maker_V5.sh" | head -1 | cut -d':' -f1)

echo "Function starts at line $line_start and ends at line $line_end"

# Create a completely new version of the function that addresses all the syntax issues
cat > fixed_function.sh << 'EOL'
# Enhanced download function with progress bar, history tracking, and error recovery
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
    fi

    # Set total_size if we have a valid size
    if [[ -n "$size_str" && "$size_str" != "0" ]]; then
        total_size=$size_str
        # Format for display
        if [ $total_size -gt 1048576 ]; then
            size_str="$(echo "scale=2; $total_size/1048576" | bc) MB"
        elif [ $total_size -gt 1024 ]; then
            size_str="$(echo "scale=2; $total_size/1024" | bc) KB"
        else
            size_str="$total_size bytes"
        fi
        print_info "Detected file size: $size_str"
    fi

    # Prepare the title with the description
    if ! $quiet; then
        title="${C_BOLD}${C_CYAN}⬇️ DOWNLOADING:${C_RESET} ${C_WHITE}$description${C_RESET} ($size_str)"
        echo -e "$title"
        echo -e "${C_DIM}URL: $url${C_RESET}"
    fi

    # Clear existing animations (in case of multiple downloads in same session)
    if ! $quiet && $animation_started; then
        echo -e "\n\n\n\n\n\n\n\n"
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

    # Show download progress animation
    if ! $quiet; then
        # Create progress box
        echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}"
    fi

    # Wait for download to complete while showing progress
    while [ -d /proc/$pid ] && ! $finished; do
        if [ -f "$output_file" ]; then
            downloaded=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
        fi

        if ! $quiet; then
            # Calculate progress
            if [ $total_size -gt 0 ]; then
                percent=$((downloaded * 100 / total_size))
                if [ $percent -gt 100 ]; then
                    percent=100
                fi
            else
                percent="--"
            fi

            # Calculate download speed
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            if [ $elapsed -gt 0 ]; then
                local bytes_per_sec=$((downloaded / elapsed))
                if [ $bytes_per_sec -gt 1048576 ]; then
                    speed="$(echo "scale=2; $bytes_per_sec/1048576" | bc) MB/s"
                elif [ $bytes_per_sec -gt 1024 ]; then
                    speed="$(echo "scale=2; $bytes_per_sec/1024" | bc) KB/s"
                else
                    speed="$bytes_per_sec B/s"
                fi

                # Calculate ETA
                if [ $total_size -gt 0 ] && [ $bytes_per_sec -gt 0 ]; then
                    local remaining_bytes=$((total_size - downloaded))
                    local remaining_seconds=$((remaining_bytes / bytes_per_sec))
                    if [ $remaining_seconds -ge 3600 ]; then
                        eta="$(($remaining_seconds / 3600))h$(($remaining_seconds % 3600 / 60))m"
                    elif [ $remaining_seconds -ge 60 ]; then
                        eta="$(($remaining_seconds / 60))m$(($remaining_seconds % 60))s"
                    else
                        eta="${remaining_seconds}s"
                    fi
                else
                    eta="--:--"
                fi
            fi

            # Update the progress bar
            local full_bar=""
            if [ "$percent" != "--" ]; then
                local bar_units=$((percent * width / 100))
                full_bar=$(printf "%${bar_units}s" | tr ' ' '█')
                full_bar="$full_bar$(printf "%$((width - bar_units))s" | tr ' ' '░')"
            else
                full_bar=$(printf "%${width}s" | tr ' ' '░')
            fi

            # Get the current llama frame
            local llama_frame=${llama_frames[$((current_frame % ${#llama_frames[@]}))]}
            current_frame=$((current_frame + 1))

            # Move cursor to the start of the progress box
            echo -en "\033[8A"

            # Update progress animation
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} Downloading: ${C_BOLD}$description${C_RESET}                           ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} $llama_frame \"I'm downloading as fast as I can!\"               ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} / >|                                                      ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} ${C_GREEN}$full_bar${C_RESET} $percent%                                 ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} Speed: $speed | ETA: $eta                                ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}"

            sleep 0.2
        else
            sleep 1
        fi
    done

    # Get download exit code
    wait $pid
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        if ! $quiet; then
            # Move cursor to the start of the progress box
            echo -en "\033[8A"

            # Show failure message
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}┌──────────────────────────────────────────────────────────┐${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}│${C_RESET} ${C_RED}DOWNLOAD FAILED:${C_RESET} $description                           ${C_RED}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}│${C_RESET} (ಠ‿ಠ)🦙 \"Oh no! The download failed!\"                     ${C_RED}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}│${C_RESET} / >|                                                      ${C_RED}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}│${C_RESET}                                                          ${C_RED}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}│${C_RESET} Error: $(cat "$temp_file")                               ${C_RED}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}│${C_RESET} Trying to continue...                                    ${C_RED}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_RED}└──────────────────────────────────────────────────────────┘${C_RESET}"

            # Add a newline for spacing
            echo ""
        fi

        print_warning "Download failed: $description"
        print_warning "Error: $(cat "$temp_file")"
    else
        # Get final file size in readable format
        local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "?")
        if [ $file_size -gt 1073741824 ]; then
            file_size="$(echo "scale=2; $file_size/1073741824" | bc) GB"
        elif [ $file_size -gt 1048576 ]; then
            file_size="$(echo "scale=2; $file_size/1048576" | bc) MB"
        elif [ $file_size -gt 1024 ]; then
            file_size="$(echo "scale=2; $file_size/1024" | bc) KB"
        else
            file_size="$file_size bytes"
        fi

        if ! $quiet; then
            # Move cursor to the start of the progress box
            echo -en "\033[8A"

            # Show completion message
            # Show the download target name with completion message
            local display_desc="$description"
            if [ ${#display_desc} -gt 28 ]; then
                display_desc="${display_desc:0:25}..."
            fi

            echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} (^‿^)🦙 \"Download complete!\"                           ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} / >|                                                      ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} ${C_GREEN}$full_bar${C_RESET} 100%                                 ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line

            # Format the file size display more clearly with dynamic spacing
            # Process file size to ensure it fits nicely
            if [ ${#file_size} -gt 30 ]; then
                # For extremely large files, we might need to trim
                file_size_display="${file_size:0:27}..."
            else
                file_size_display="$file_size"
            fi

            echo -e "${C_CYAN}│${C_RESET} Downloaded: ${C_BOLD}$file_size_display${C_RESET}                    ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}"

            # Add a newline for spacing
            echo ""
        fi
    fi

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
EOL

# Replace the function in the script with our fixed version
sed -i "${line_start},${line_end}d" "Leonardo_AI_USB_Maker_V5.sh"
line_before=$((line_start - 1))
sed -i "${line_before}r fixed_function.sh" "Leonardo_AI_USB_Maker_V5.sh"

echo "Replaced the problematic function with a fixed version"
echo "Testing script for syntax errors..."

# Verify the fix
bash -n "Leonardo_AI_USB_Maker_V5.sh"
if [ $? -eq 0 ]; then
    echo "✅ Syntax check passed! The script should now run properly."
else
    echo "❌ Syntax error still exists. Further debugging needed."
fi
