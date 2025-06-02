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
            # Create a lookup table for known file patterns
            declare -A size_lookup
            # Ollama binaries sizes by platform (in bytes, verified May 2025)
            size_lookup["ollama-linux-amd64"]="128974000"     # ~129MB
            size_lookup["ollama-darwin"]="110250000"          # ~110MB
            size_lookup["ollama-windows"]="138529000"         # ~139MB

            # Parse GitHub URLs for more accurate size estimation
            if [[ "$url" == *"github.com"* && "$url" == *"/releases/download/"* ]]; then
                print_info "Using GitHub API for file size detection..."

                # Extract repository and release information from URL
                repo_path=$(echo "$url" | sed -E 's|.+github\.com/([^/]+/[^/]+)/releases/download/.+|\1|')
                file_name=$(basename "$url")
                tag_version=$(echo "$url" | sed -E 's|.+/releases/download/([^/]+)/.+|\1|')

                # Use GitHub API to get release assets and find the matching file
                if [[ -n "$repo_path" && -n "$tag_version" ]]; then
                    # Try curl with GitHub API to get release assets
                    api_url="https://api.github.com/repos/$repo_path/releases/tags/$tag_version"
                    api_response=$(curl -s "$api_url")

                    # Extract size for the specific asset we're downloading
                    if [[ -n "$api_response" && "$api_response" != *"Not Found"* ]]; then
                        # Parse the JSON response with grep and sed to extract file size
                        # We look for our specific filename and grab the size field
                        asset_info=$(echo "$api_response" | grep -A 20 "\"name\":\s*\"$file_name\"" | grep -m 1 "\"size\"")
                        if [[ -n "$asset_info" ]]; then
                            asset_size=$(echo "$asset_info" | sed -E 's/.*"size":\s*([0-9]+).*/\1/')
                            if [[ -n "$asset_size" && "$asset_size" != "0" ]]; then
                                total_size=$asset_size
                                # Format the size for display
                                if [ $total_size -gt 1073741824 ]; then  # 1GB
                                    size_str="$(echo "scale=2; $total_size/1073741824" | bc) GB"
                                elif [ $total_size -gt 1048576 ]; then  # 1MB
                                    size_str="$(echo "scale=2; $total_size/1048576" | bc) MB"
                                elif [ $total_size -gt 1024 ]; then  # 1KB
                                    size_str="$(echo "scale=2; $total_size/1024" | bc) KB"
                                else
                                    size_str="$total_size bytes"
                                fi
                                print_info "GitHub API detected file size: $size_str"
                            fi
                        fi
                    fi
                fi
            fi

            # If we still don't have a size, check our lookup table for known files
            if [[ -z "$size_str" || "$size_str" == "0" ]]; then
                # Try to match against our lookup table entries
                for pattern in "${!size_lookup[@]}"; do
                    if [[ "$url" == *"$pattern"* ]]; then
                        total_size=${size_lookup[$pattern]}
                        # Format the size
                        if [ $total_size -gt 1073741824 ]; then  # 1GB
                            size_str="$(echo "scale=2; $total_size/1073741824" | bc) GB"
                        elif [ $total_size -gt 1048576 ]; then  # 1MB
                            size_str="$(echo "scale=2; $total_size/1048576" | bc) MB"
                        elif [ $total_size -gt 1024 ]; then  # 1KB
                            size_str="$(echo "scale=2; $total_size/1024" | bc) KB"
                        else
                            size_str="$total_size bytes"
                        fi
                        print_info "Lookup table detected file size: $size_str"
                        break
                    fi
                done
            fi

            # Last resort: educated guess based on file extension
            if [[ -z "$size_str" || "$size_str" == "0" ]]; then
                if [[ "$url" == *".tgz"* || "$url" == *".tar.gz"* ]]; then
                    if [[ "$url" == *"ollama"* && "$url" == *"linux"* ]]; then
                        total_size=129000000  # More accurate Linux estimate
                        size_str="~129MB (estimated)"
                    elif [[ "$url" == *"ollama"* && "$url" == *"darwin"* ]]; then
                        total_size=110000000  # More accurate macOS estimate
                        size_str="~110MB (estimated)"
                    elif [[ "$url" == *"ollama"* && "$url" == *"windows"* ]]; then
                        total_size=139000000  # More accurate Windows estimate
                        size_str="~139MB (estimated)"
                    else
                        total_size=100000000  # Generic compressed archive
                        size_str="~100MB (estimated)"
                    fi
                elif [[ "$url" == *".zip"* ]]; then
                    total_size=50000000  # Generic zip estimate
                    size_str="~50MB (estimated)"
                elif [[ "$url" == *".exe"* ]]; then
                    total_size=120000000  # Generic executable estimate
                    size_str="~120MB (estimated)"
                else
                    total_size=20000000  # Generic unknown file
                    size_str="~20MB (estimated)"
                fi
                print_info "Estimated file size based on file type: $size_str"
            fi
        fi
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

    # Set up initial empty lines for the animation box that we'll update later
    # Also capture the number of lines we need to move up for animation updates
    local animation_lines=0
    if ! $quiet; then
        # Determine the number of lines our animation box will use
        if [[ "$description" == *"Linux"* && "$description" == *"Ollama"* ]] || \
           [[ "$description" == *"macOS"* && "$description" == *"Ollama"* ]] || \
           [[ "$description" == *"Windows"* && "$description" == *"Ollama"* ]]; then
            # For known large downloads, use the 9-line format (with two-line progress info)
            animation_lines=9
        else
            # For standard downloads, use the standard 8-line format
            animation_lines=8
        fi

        # Create the appropriate number of empty lines for our animation box
        for ((i = 0; i < animation_lines; i++)); do
            echo ""
        done
    fi

    # Initialize animation frame counter
    local animation_started=false

    # Draw the initial box with placeholder values
    if ! $quiet; then
        echo -e "${C_CYAN}┌──────────────────────────────────────────┐${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} (\\(\\                                    ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${llama_frames[0]} Downloading...                  ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} / >|                                    ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} Initializing...                         ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} Speed: --.- KB/s | ETA: --:-- | 0/0 KB ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}└──────────────────────────────────────────┘${C_RESET}"
    fi

    # Wait a moment to start downloading
    sleep 0.5

    # Animation loop
    while kill -0 $pid 2>/dev/null; do
        if [ -f "$output_file" ]; then
            downloaded=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
        fi

        # Calculate percentage, speed, and ETA
        elapsed=$(($(date +%s) - start_time))
        if [ $elapsed -gt 0 ] && [ $downloaded -gt 0 ]; then
            speed_bytes=$((downloaded / elapsed))

            if [ $speed_bytes -gt 1073741824 ]; then  # Greater than 1GB/s
                speed="$(echo "scale=2; $speed_bytes/1073741824" | bc) GB/s"
            elif [ $speed_bytes -gt 1048576 ]; then  # Greater than 1MB/s
                speed="$(echo "scale=2; $speed_bytes/1048576" | bc) MB/s"
            elif [ $speed_bytes -gt 1024 ]; then  # Greater than 1KB/s
                speed="$(echo "scale=2; $speed_bytes/1024" | bc) KB/s"
            else
                speed="$speed_bytes B/s"
            fi

            if [ $total_size -gt 0 ] && [ $speed_bytes -gt 0 ]; then
                eta_seconds=$(( (total_size - downloaded) / speed_bytes ))
                eta_min=$((eta_seconds / 60))
                eta_sec=$((eta_seconds % 60))
                if [ $eta_seconds -lt 0 ]; then
                    eta="00:00"
                else
                    eta="$(printf "%02d:%02d" $eta_min $eta_sec)"
                fi
            fi
        fi

        # Format downloaded and total size with better precision
        local downloaded_fmt="?"
        local total_fmt="?"

        if [ $downloaded -gt 0 ]; then
            if [ $downloaded -gt 1073741824 ]; then  # 1GB
                downloaded_fmt="$(echo "scale=1; $downloaded/1073741824" | bc)G"
            elif [ $downloaded -gt 1048576 ]; then  # 1MB
                downloaded_fmt="$(echo "scale=1; $downloaded/1048576" | bc)M"
            else
                downloaded_fmt="$(echo "scale=1; $downloaded/1024" | bc)K"
            fi
        fi

        if [ $total_size -gt 0 ]; then
            if [ $total_size -gt 1073741824 ]; then  # 1GB
                total_fmt="$(echo "scale=1; $total_size/1073741824" | bc)G"
            elif [ $total_size -gt 1048576 ]; then  # 1MB
                total_fmt="$(echo "scale=1; $total_size/1048576" | bc)M"
            else
                total_fmt="$(echo "scale=1; $total_size/1024" | bc)K"
            fi
        fi

        # If downloaded is greater than total_size, update total_size
        if [ $total_size -gt 0 ] && [ $downloaded -gt $total_size ]; then
            total_size=$downloaded
            # Update total_fmt with consistent formatting
            if [ $total_size -gt 1073741824 ]; then  # 1GB
                total_fmt="$(echo "scale=1; $total_size/1073741824" | bc)G"
            elif [ $total_size -gt 1048576 ]; then  # 1MB
                total_fmt="$(echo "scale=1; $total_size/1048576" | bc)M"
            else
                total_fmt="$(echo "scale=1; $total_size/1024" | bc)K"
            fi
        fi

        # Calculate percentage - handle cases where downloaded size exceeds estimated total
        if [ $total_size -gt 0 ]; then
            # If downloaded already exceeds total_size, update total_size to downloaded
            # This ensures our percentage calculation is accurate when estimates were wrong
            if [ $downloaded -gt $total_size ]; then
                total_size=$downloaded
                # Update the displayed size string too
                if [ $total_size -gt 1073741824 ]; then  # 1GB
                    size_str="$(echo "scale=2; $total_size/1073741824" | bc) GB"
                elif [ $total_size -gt 1048576 ]; then  # 1MB
                    size_str="$(echo "scale=2; $total_size/1048576" | bc) MB"
                elif [ $total_size -gt 1024 ]; then  # 1KB
                    size_str="$(echo "scale=2; $total_size/1024" | bc) KB"
                else
                    size_str="$total_size bytes"
                fi
                # Log that we've updated the size estimate
                if [ $((current_frame % 30)) -eq 0 ]; then
                    print_info "Updating size estimate to: $size_str based on actual download"
                fi
            fi

            # Now calculate percentage with possibly updated total_size
            percent=$(( (downloaded * 100) / total_size ))
            if [ $percent -gt 100 ]; then
                percent=100
            fi
        else
            percent=0
        fi

        # Choose color based on percentage
        local color=${C_RED}
        if [ $percent -gt 30 ]; then color=${C_YELLOW}; fi
        if [ $percent -gt 60 ]; then color=${C_GREEN}; fi

        # Prepare progress bar
        local filled=$(( percent * width / 100 ))
        local empty=$(( width - filled ))
        local bar=""
        for ((i = 0; i < filled; i++)); do bar="${bar}▓"; done
        for ((i = 0; i < empty; i++)); do bar="${bar}░"; done

        # Get current animation frame
        local spinner="${frames[$((current_frame % ${#frames[@]}))]}"
        local llama="${llama_frames[$((current_frame % ${#llama_frames[@]}))]}"

        current_frame=$((current_frame + 1))

        # Format the progress info for the display box - make it more readable
        local size_info="$downloaded_fmt/$total_fmt"
        # Adjust formatting based on content length
        if [[ ${#speed} -gt 7 || ${#eta} -gt 7 || ${#size_info} -gt 16 ]]; then
            # For longer values, put each on its own line
            local progress_line1="Speed: $speed | ETA: $eta"
            local progress_line2="Size: $size_info"
            # Set a flag to indicate we're using the two-line format
            local use_two_lines=true
        else
            # For shorter values, keep them on one line
            local progress_info="Speed: $speed | ETA: $eta | $size_info"
            local use_two_lines=false
        fi

        # Create padding for right alignment of percentage
        local percent_pad=""
        if [ $percent -lt 10 ]; then
            percent_pad="  "
        elif [ $percent -lt 100 ]; then
            percent_pad=" "
        fi

        # Only update the display occasionally to reduce terminal spam
        if [ $((current_frame % 3)) -eq 0 ] && ! $quiet; then
            # Move cursor up based on the number of lines in our display format
            if [ "$use_two_lines" = true ]; then
                # For the two-line format, we need to move up 9 lines
                echo -en "\033[9A\r"
            else
                # For the one-line format, we need to move up 8 lines
                echo -en "\033[8A\r"
            fi

            # Draw the new frame with manual spacing for consistent appearance
            # Using a wider box (60 characters wide content area) to better fit larger file sizes
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} (\\(\\                                                      ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line

            # Show the download target name, truncated if too long
            local display_desc="$description"
            if [ ${#display_desc} -gt 38 ]; then
                display_desc="${display_desc:0:35}..."
            fi

            echo -e "${C_CYAN}│${C_RESET} $llama Downloading: ${C_BOLD}$display_desc${C_RESET}      ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET} / >|                                                      ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line
            echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line

            # Wider progress bar for better visual appeal
            echo -e "${C_CYAN}│${C_RESET} ${color}$bar${C_RESET} ${percent}%${percent_pad}                                 ${C_CYAN}│${C_RESET}"
            echo -en "\033[K" # Clear to end of line

            # Display progress info - either one or two lines based on size
            if [ "$use_two_lines" = true ]; then
                # For large files, use two lines for better readability
                echo -e "${C_CYAN}│${C_RESET} $progress_line1                              ${C_CYAN}│${C_RESET}"
                echo -en "\033[K" # Clear to end of line
                echo -e "${C_CYAN}│${C_RESET} $progress_line2                              ${C_CYAN}│${C_RESET}"
                echo -en "\033[K" # Clear to end of line
                echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}"
            else
                # For smaller files, use one line
                echo -e "${C_CYAN}│${C_RESET} $progress_info                              ${C_CYAN}│${C_RESET}"
                echo -en "\033[K" # Clear to end of line
                echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}"
                # Extra empty line since we're not using the two-line format
                echo -en "\033[K" # Clear to end of line
                echo ""
            fi
        fi

        sleep 0.1
    done

    # Check if the download was successful
    wait $pid
    local exit_code=$?

    # Check download success
    if [[ $exit_code -ne 0 || ! -f "$output_file" || $(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0") -eq 0 ]]; then
        if ! $quiet; then
            echo ""
        fi
        print_error "Failed to download $description. Please check your internet connection and try again."
        return 1
    fi

    # Show completion animation if not in quiet mode
    if ! $quiet; then
        # Get final file size in readable format
        local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "?")
        if [ "$file_size" != "?" ] && [ $file_size -gt 1073741824 ]; then  # 1GB
            file_size="$(echo "scale=2; $file_size/1073741824" | bc) GB"
        elif [ "$file_size" != "?" ] && [ $file_size -gt 1048576 ]; then  # 1MB
            file_size="$(echo "scale=2; $file_size/1048576" | bc) MB"
        elif [ "$file_size" != "?" ] && [ $file_size -gt 1024 ]; then  # 1KB
            file_size="$(echo "scale=2; $file_size/1024" | bc) KB"
        else
            file_size="$file_size bytes"
        fi

        # Create a full progress bar for 100% completion
        local full_bar=""
        for ((i = 0; i < width; i++)); do full_bar="${full_bar}▓"; done

        # Clear all previous animation lines
        # First determine how many lines we need to move up based on our animation format
        local lines_to_clear=8
        if [ "$use_two_lines" = true ]; then
            lines_to_clear=9
        fi

        # Move cursor up to start of animation box
        echo -en "\033[${lines_to_clear}A\r"

        # Clear ALL lines by printing empty lines
        for ((i=0; i<lines_to_clear; i++)); do
            echo -en "\033[K\n"
        echo -en "\033[${lines_to_clear}A\r"

        # Draw the completion animation - using the wider box format
        echo -en "\033[K" # Clear to end of line
        echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}"
        echo -en "\033[K" # Clear to end of line
        echo -e "${C_CYAN}│${C_RESET} (\\(\\                                                      ${C_CYAN}│${C_RESET}"
        echo -en "\033[K" # Clear to end of line

        # Show the download target name with completion message
        local display_desc="$description"
        if [ ${#display_desc} -gt 28 ]; then
            display_desc="${display_desc:0:25}..."
        fi

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
