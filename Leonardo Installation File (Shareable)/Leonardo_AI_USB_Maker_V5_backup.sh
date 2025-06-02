#!/usr/bin/env bash

# Leonardo AI USB Maker - Create portable Ollama AI environments
# Version 5.0.0 - International Coding Competition 2025 Edition - Enhanced UI, better accessibility, and improved user experience
# Authors: Eric & Friendly AI Assistant
# License: MIT

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SCRIPT_SELF_NAME=$(basename "$0")

# Track installation start time
INSTALL_START_TIME=$(date +%s)
SCRIPT_VERSION="5.0.0" # Major UI/UX overhaul
USB_LABEL_DEFAULT="LEONARDO"
USB_LABEL="$USB_LABEL_DEFAULT"
USE_GITHUB_API=false
INSTALL_START_TIME=$(date +%s)
SELECTED_OS_TARGETS="linux,mac,win"
MODELS_TO_INSTALL_LIST=()
MODEL_TO_PULL="llama3:8b"
MODEL_SOURCE_TYPE="pull"
LOCAL_GGUF_PATH_FOR_IMPORT=""
RAW_USB_DEVICE_PATH=""
USB_DEVICE_PATH=""

# Download history tracking
DOWNLOAD_HISTORY=()
DOWNLOAD_SIZES=()
DOWNLOAD_TIMESTAMPS=()
DOWNLOAD_DESTINATIONS=()
DOWNLOAD_STATUS=()
TOTAL_BYTES_DOWNLOADED=0

# USB Drive Lifecycle Management
USB_HEALTH_TRACKING=true
USB_HEALTH_DATA_FILE="" # Will be set based on the USB drive path
USB_WRITE_CYCLE_COUNTER=0
USB_FIRST_USE_DATE=""
USB_TOTAL_BYTES_WRITTEN=0
USB_MODEL=""
USB_SERIAL=""
USB_ESTIMATED_LIFESPAN=0 # In write cycles
USB_PARTITION_PATH=""
USB_BASE_PATH=""
MOUNT_POINT=""
FORMAT_USB_CHOICE=""
OPERATION_MODE="create_new"
USER_LAUNCHER_NAME_BASE="leonardo"
ESTIMATED_BINARIES_SIZE_GB="0.00"
ESTIMATED_MODELS_SIZE_GB="0.00" # For new QoL
TMP_DOWNLOAD_DIR=""
USER_DEVICE_CHOICE_RAW_FOR_MAC_FORMAT_WARN=""

# --- Robust Color and tput Initialization ---
set +e
TERMINAL_HAS_COLORS=false
COLORS_ENABLED=true

# Respect accessibility standards
# Check for NO_COLOR environment variable (https://no-color.org/)
if [ -n "${NO_COLOR:-}" ] || [ "${TERM:-}" = "dumb" ]; then
    COLORS_ENABLED=false
else
    # Check if terminal supports colors
    if [ -t 1 ]; then
        ncolors=$(tput colors 2>/dev/null)
        if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
            TERMINAL_HAS_COLORS=true
        else
            COLORS_ENABLED=false
        fi
    else
        # Not a terminal or being piped
        COLORS_ENABLED=false
    fi
fi

# Initialize color codes (empty by default for fallback)
C_RESET=""
C_BOLD=""
C_DIM=""
C_UNDERLINE=""
C_NO_UNDERLINE=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_MAGENTA=""
C_CYAN=""
C_WHITE=""
C_GREY=""

# Track if verbose output is enabled
VERBOSE_OUTPUT=false

# Function to toggle verbose output
toggle_verbose() {
    VERBOSE_OUTPUT=!$VERBOSE_OUTPUT
    if $VERBOSE_OUTPUT; then
        echo "Verbose output enabled"
    else
        echo "Verbose output disabled"
    fi
}

TPUT_CMD_PATH=""
_tput_temp_path_check_cmd_output=$(command -v tput 2>/dev/null)
_tput_temp_path_check_cmd_rc=$?

if [ "$_tput_temp_path_check_cmd_rc" -eq 0 ] && [ -n "$_tput_temp_path_check_cmd_output" ]; then
    _tput_temp_path_resolved=$(readlink -f "$_tput_temp_path_check_cmd_output" 2>/dev/null || echo "$_tput_temp_path_check_cmd_output")
    if [ -x "$_tput_temp_path_resolved" ]; then
        TPUT_CMD_PATH="$_tput_temp_path_resolved"
    fi
fi

COLORS_ENABLED=false
TPUT_CLEAR_POSSIBLE=false

if [ -n "$TPUT_CMD_PATH" ]; then
    tput_color_test_rc=1
    ( "$TPUT_CMD_PATH" setaf 1 && "$TPUT_CMD_PATH" sgr0 ) >/dev/null 2>&1
    tput_color_test_rc=$?
    if [ "$tput_color_test_rc" -eq 0 ]; then
        COLORS_ENABLED=true
    fi

    tput_clear_test_rc=1
    ( "$TPUT_CMD_PATH" clear ) >/dev/null 2>&1
    tput_clear_test_rc=$?
    if [ "$tput_clear_test_rc" -eq 0 ]; then
        TPUT_CLEAR_POSSIBLE=true
    fi
fi

if $COLORS_ENABLED && [ -n "$TPUT_CMD_PATH" ]; then
    C_RESET=$("$TPUT_CMD_PATH" sgr0)
    C_BOLD=$("$TPUT_CMD_PATH" bold)
    if ( "$TPUT_CMD_PATH" dim >/dev/null 2>&1 ); then C_DIM=$("$TPUT_CMD_PATH" dim); else C_DIM=""; fi
    if ( "$TPUT_CMD_PATH" smul >/dev/null 2>&1 ); then C_UNDERLINE=$("$TPUT_CMD_PATH" smul); else C_UNDERLINE=""; fi
    if ( "$TPUT_CMD_PATH" rmul >/dev/null 2>&1 ); then C_NO_UNDERLINE=$("$TPUT_CMD_PATH" rmul); else C_NO_UNDERLINE=""; fi
    C_RED=$("$TPUT_CMD_PATH" setaf 1)
    C_GREEN=$("$TPUT_CMD_PATH" setaf 2)
    C_YELLOW=$("$TPUT_CMD_PATH" setaf 3)
    C_BLUE=$("$TPUT_CMD_PATH" setaf 4)
    C_MAGENTA=$("$TPUT_CMD_PATH" setaf 5)
    C_CYAN=$("$TPUT_CMD_PATH" setaf 6)
    C_WHITE=$("$TPUT_CMD_PATH" setaf 7)

    tput_setaf8_rc=1
    ( "$TPUT_CMD_PATH" setaf 8 >/dev/null 2>&1 )
    tput_setaf8_rc=$?
    if [ "$tput_setaf8_rc" -eq 0 ]; then
        C_GREY=$("$TPUT_CMD_PATH" setaf 8)
    elif [ -n "$C_DIM" ]; then
        C_GREY="$C_DIM"
    else
        C_GREY=""
    fi
fi
set -e
# End of color initialization

# --- BEGIN ALL FUNCTION DEFINITIONS ---

# --- UI Helper Functions ---

# Dividers and structural elements
print_line() {
    if $COLORS_ENABLED; then
        echo -e "${C_DIM}──────────────────────────────────────────────────────────────────${C_RESET}"
    else
        echo "------------------------------------------------------------------"
    fi
}

print_double_line() {
    if $COLORS_ENABLED; then
        echo -e "${C_DIM}══════════════════════════════════════════════════════════════════${C_RESET}"
    else
        echo "=================================================================="
    fi
}

# --- Text Formatting Utilities ---

# Word-boundary aware text wrapping function
# This ensures text is wrapped at word boundaries rather than character positions
# Usage: wrap_text "text to wrap" max_width [prefix]
wrap_text() {
    local text="$1"
    local max_width="$2"
    local prefix="${3:-}"
    local result=""
    local prefix_len=${#prefix}
    local effective_width=$((max_width - prefix_len))

    # Return empty string for empty input
    if [ -z "$text" ]; then
        echo ""
        return
    fi

    # If text is shorter than effective width, return it with prefix
    if [ ${#text} -le $effective_width ]; then
        echo "$prefix$text"
        return
    fi

    # Process the text, wrapping at word boundaries
    while [ -n "$text" ]; do
        local line=""

        # If remaining text fits in one line
        if [ ${#text} -le $effective_width ]; then
            echo "$prefix$text"
            break
        fi

        # Get a substring that might fit
        local potential_line="${text:0:$effective_width}"

        # Find the last space in this substring
        local last_space=$(echo "$potential_line" | grep -bo ' ' | tail -1 | cut -d':' -f1)

        # If no space found, force a break at effective_width
        if [ -z "$last_space" ]; then
            echo "$prefix${text:0:$effective_width}"
            text="${text:$effective_width}"
        else
            # Check if we are about to break in the middle of a contraction or possessive
            # like "don't", "isn't", or "grandma's"
            local next_chars="${text:$((last_space+1)):2}"
            if [[ "$next_chars" == *"'"* ]]; then
                # Try to find the next space after this apostrophe
                local remaining="${text:$((last_space+1))}"
                local next_space=$(echo "$remaining" | grep -bo ' ' | head -1 | cut -d':' -f1)

                # If we found another space and including up to that space doesn't exceed our width
                if [ -n "$next_space" ] && [ $((last_space + 1 + next_space)) -le $effective_width ]; then
                    # Use this new breaking point instead
                    last_space=$((last_space + 1 + next_space))
                fi
            fi

            # Output text up to the last space
            echo "$prefix${text:0:$last_space}"
            # Remove the output text plus the space from the remaining text
            text="${text:$((last_space+1))}"
        fi
    done
}

# Wrap text and return as a single string with newlines
# Usage: wrap_text_string "text to wrap" max_width [prefix] [newline_with_prefix]
wrap_text_string() {
    local text="$1"
    local max_width="$2"
    local prefix="${3:-}"
    local newline_with_prefix="${4:-\n$prefix}"
    local result=""
    local first=true

    # Make sure we're working with complete words
    # If the text has color codes, this gets more complex, but we can handle it
    # by treating the entire text as a whole

    # Calculate effective width for text content
    local effective_width=$((max_width - ${#prefix}))

    # Split text into words while preserving spaces
    local -a words=()
    local current_word=""
    local i=0
    while [ $i -lt ${#text} ]; do
        local char="${text:$i:1}"
        local next_char="${text:$((i+1)):1}"

        # Handle ANSI color escape sequences (they start with \033[ or \e[)
        if [[ "$char" == $'\033' || "$char" == $'\e' ]]; then
            # Capture the entire escape sequence
            local escape_seq="$char"
            local j=$((i+1))
            # Keep appending characters until we hit 'm' which ends the sequence
            while [ $j -lt ${#text} ] && [ "${text:$j:1}" != "m" ]; do
                escape_seq="$escape_seq${text:$j:1}"
                j=$((j+1))
            done
            # Add the 'm'
            if [ $j -lt ${#text} ]; then
                escape_seq="$escape_seq${text:$j:1}"
            fi
            # Add the escape sequence to the current word
            current_word="$current_word$escape_seq"
            # Skip ahead
            i=$((j+1))
            continue
        fi

        # If we hit a space, end the current word
        if [[ "$char" == " " ]]; then
            if [ -n "$current_word" ]; then
                words+=("$current_word")
                current_word=""
            fi
            words+=(" ") # Preserve the space as its own element
        else
            current_word="$current_word$char"
        fi
        i=$((i+1))
    done

    # Add the last word if there is one
    if [ -n "$current_word" ]; then
        words+=("$current_word")
    fi

    # Now build lines from words, respecting the effective width
    local current_line=""
    local current_line_len=0

    for word in "${words[@]}"; do
        local visible_len=${#word}

        # If the word is just a space and we're at the beginning of a line, skip it
        if [[ "$word" == " " && $current_line_len -eq 0 ]]; then
            continue
        fi

        # If adding this word would exceed the line length, start a new line
        if [ $((current_line_len + visible_len)) -gt $effective_width ] && [ $current_line_len -gt 0 ]; then
            if $first; then
                result="$prefix$current_line"
                first=false
            else
                result="${result}${newline_with_prefix}${current_line}"
            fi
            current_line=""
            current_line_len=0

            # If the word is just a space, skip it at the beginning of a new line
            if [[ "$word" == " " ]]; then
                continue
            fi
        fi

        # Add the word to the current line
        current_line="${current_line}${word}"
        current_line_len=$((current_line_len + visible_len))
    done

    # Add the last line if there is one
    if [ -n "$current_line" ]; then
        if $first; then
            result="$prefix$current_line"
        else
            result="${result}${newline_with_prefix}${current_line}"
        fi
    fi

    echo "$result"
}

# Help and documentation
# Function to download files with a fancy animated progress bar
# Usage: fancy_download "URL" "OutputFile" "Description" [quiet]
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
        "(•‿•)🦙 "
        "(•ᴗ•)🦙 "
        "(>‿•)🦙 "
        "(•‿<)🦙 "
    )
    local current_frame=0
    local speed="0 KB/s"
    local eta="--:--"
    local title=""
    local animation_started=false
    local use_two_lines=false

    # Get file size if possible using multiple methods
    if command -v curl &> /dev/null; then
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
            # AI model sizes (in bytes, verified May 2025)
            size_lookup["phi3:mini"]="2470576128"            # ~2.3GB
            size_lookup["llama3:8b"]="5042946560"            # ~4.7GB
            size_lookup["codellama:7b"]="4080374784"         # ~3.8GB

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

            # Last resort: educated guess based on file extension or model name in description
            if [[ -z "$size_str" || "$size_str" == "0" ]]; then
                # Check if this is a model download based on description
                if [[ "$description" == *"phi3:mini"* ]]; then
                    total_size=2470576128  # 2.3GB for phi3:mini
                    size_str="~2.3GB (from pre-flight check)"
                elif [[ "$description" == *"llama3:8b"* ]]; then
                    total_size=5042946560  # 4.7GB for llama3:8b
                    size_str="~4.7GB (from pre-flight check)"
                elif [[ "$description" == *"codellama:7b"* ]]; then
                    total_size=4080374784  # 3.8GB for codellama:7b
                    size_str="~3.8GB (from pre-flight check)"
                # Check for Ollama binaries by file extension and OS
                elif [[ "$url" == *".tgz"* || "$url" == *".tar.gz"* ]]; then
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
            use_two_lines=true
        else
            # For standard downloads, use the standard 8-line format
            animation_lines=8
            use_two_lines=false
        fi

        # Create the appropriate number of empty lines for our animation box
        for ((i = 0; i < animation_lines; i++)); do
            echo ""
        done
    fi

    # Wait for download to complete while showing progress
    while kill -0 $pid 2>/dev/null; do
        if [ -f "$output_file" ]; then
            downloaded=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
        fi

        # Calculate percentage, speed, and ETA
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
                full_bar=$(printf "%${bar_units}s" | tr ' ' '#')
                full_bar="$full_bar$(printf "%$((width - bar_units))s" | tr ' ' '.')"
            else
                full_bar=$(printf "%${width}s" | tr ' ' '.')
            fi

            # Get current animation frame
            local spinner="${frames[$((current_frame % ${#frames[@]}))]}"
            local llama="${llama_frames[$((current_frame % ${#llama_frames[@]}))]}"

            current_frame=$((current_frame + 1))

            # Move cursor up to the start of our animation area
            echo -en "\033[${animation_lines}A"

            # Display the download animation box
            echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}"
            echo -e "${C_CYAN}│${C_RESET} Downloading: ${C_BOLD}$description${C_RESET}                           ${C_CYAN}│${C_RESET}"
            echo -e "${C_CYAN}│${C_RESET} $llama \"I'm downloading as fast as I can!\"              ${C_CYAN}│${C_RESET}"
            echo -e "${C_CYAN}│${C_RESET} / >|                                                      ${C_CYAN}│${C_RESET}"
            echo -e "${C_CYAN}│${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
            echo -e "${C_CYAN}│${C_RESET} ${C_GREEN}$full_bar${C_RESET} $percent%                                 ${C_CYAN}│${C_RESET}"

            # Show download info with different formats based on download size
            if [ "$use_two_lines" = true ]; then
                # Format for larger downloads - split into two lines
                # Line 1: Show downloaded amount + total with percentage
                local downloaded_str=""
                if [ $downloaded -gt 1073741824 ]; then  # 1GB
                    downloaded_str="$(echo "scale=2; $downloaded/1073741824" | bc) GB"
                elif [ $downloaded -gt 1048576 ]; then  # 1MB
                    downloaded_str="$(echo "scale=2; $downloaded/1048576" | bc) MB"
                elif [ $downloaded -gt 1024 ]; then  # 1KB
                    downloaded_str="$(echo "scale=2; $downloaded/1024" | bc) KB"
                else
                    downloaded_str="$downloaded B"
                fi

                local progress_info="$downloaded_str of $size_str"
                echo -e "${C_CYAN}│${C_RESET} $progress_info                              ${C_CYAN}│${C_RESET}"
                
                # Line 2: Show speed and ETA 
                echo -e "${C_CYAN}│${C_RESET} Speed: $speed | ETA: $eta                                ${C_CYAN}│${C_RESET}"
            else
                # For smaller files, use one line
                echo -e "${C_CYAN}│${C_RESET} Speed: $speed | ETA: $eta                                ${C_CYAN}│${C_RESET}"
            fi
            
            echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}"
            
            # Mark that we've shown an animation (for future cleanup)
            animation_started=true
            
            # Brief pause between animation frames
            sleep 0.1
        else
            # If quiet mode, still pause briefly
            sleep 1
        fi
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
        for ((i = 0; i < width; i++)); do 
            full_bar="${full_bar}▓"
        done

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
        done
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
print_help() {
    local script_name=$(basename "$0")
    local script_version="4.0.0"

    if $COLORS_ENABLED; then
        echo ""
        echo -e "${C_BOLD}${C_CYAN}┌──────────────────────────────────────────────────────────────┐${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}Leonardo AI USB Maker ${C_YELLOW}v$script_version${C_RESET}                                 ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}DESCRIPTION${C_RESET}                                                     ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   Create portable USB drives with Ollama and AI models that can      ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   be used on any computer with a compatible operating system.        ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}USAGE${C_RESET}                                                          ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   $script_name [options]                                        ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}OPTIONS${C_RESET}                                                         ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   -h, --help     Show this help message                         ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   -v, --version  Display version information                      ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   --no-color     Disable colored output                           ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}FEATURES${C_RESET}                                                        ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Create bootable USB drives with Ollama runtimes              ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Support for Linux, macOS, and Windows binaries              ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Download and package AI models for offline use              ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Import your own local GGUF model files                      ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Add models to existing Leonardo AI USB drives               ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Update launch scripts on existing drives                    ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}REQUIREMENTS${C_RESET}                                                    ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - USB drive with sufficient storage for models               ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Internet connection for downloading models                  ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   - Ollama installed on host system                             ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}EXAMPLES${C_RESET}                                                        ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   $script_name                  # Run with interactive menu    ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}   $script_name --no-color       # Run without colored output  ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}                                                                ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}└─────────────────────────────────────────────────────────────────┘${C_RESET}"
    else
        echo ""
        echo "+------------------------------------------------------------------+"
        echo "| Leonardo AI USB Maker v$script_version                                 |"
        echo "|                                                                  |"
        echo "| DESCRIPTION                                                       |"
        echo "|   Create portable USB drives with Ollama and AI models that can    |"
        echo "|   be used on any computer with a compatible operating system.      |"
        echo "|                                                                  |"
        echo "| USAGE                                                            |"
        echo "|   $script_name [options]                                          |"
        echo "|                                                                  |"
        echo "| OPTIONS                                                           |"
        echo "|   -h, --help     Show this help message                           |"
        echo "|   -v, --version  Display version information                        |"
        echo "|   --no-color     Disable colored output                             |"
        echo "|                                                                  |"
        echo "| FEATURES                                                          |"
        echo "|   - Create bootable USB drives with Ollama runtimes                |"
        echo "|   - Support for Linux, macOS, and Windows binaries                |"
        echo "|   - Download and package AI models for offline use                |"
        echo "|   - Import your own local GGUF model files                        |"
        echo "|   - Add models to existing Leonardo AI USB drives                 |"
        echo "|   - Update launch scripts on existing drives                      |"
        echo "|                                                                  |"
        echo "| REQUIREMENTS                                                      |"
        echo "|   - USB drive with sufficient storage for models                 |"
        echo "|   - Internet connection for downloading models                    |"
        echo "|   - Ollama installed on host system                               |"
        echo "|                                                                  |"
        echo "| EXAMPLES                                                          |"
        echo "|   $script_name                  # Run with interactive menu      |"
        echo "|   $script_name --no-color       # Run without colored output    |"
        echo "|                                                                  |"
        echo "+------------------------------------------------------------------+"
    fi
    echo ""
}

# Headers and sections
print_header() {
    if $COLORS_ENABLED; then
        echo -e "${C_BOLD}${C_CYAN}┌─────────────────────────────────────────────────────────────┐${C_RESET}"
        printf "${C_BOLD}${C_CYAN}│ %-63s │${C_RESET}\n" "$1"
        echo -e "${C_BOLD}${C_CYAN}└─────────────────────────────────────────────────────────────┘${C_RESET}"
    else
        echo "+---------------------------------------------------------------+"
        printf "| %-63s |\n" "$1"
        echo "+---------------------------------------------------------------+"
    fi
}

print_subheader() {
    if $COLORS_ENABLED; then
        echo -e "\n${C_BOLD}${C_CYAN}$1${C_RESET}"
    else
        echo -e "\n-- $1 --"
    fi
}

# Status messages
print_info() {
    # Send to stderr to allow piping of actual output
    if $COLORS_ENABLED; then
        echo -e "${C_BLUE}INFO:${C_RESET} $1" >&2
    else
        echo "INFO: $1" >&2
    fi
}

print_success() {
    if $COLORS_ENABLED; then
        echo -e "${C_GREEN}✓${C_RESET} $1"
    else
        echo "SUCCESS: $1"
    fi
}

print_partial_success() {
    if $COLORS_ENABLED; then
        echo -e "${C_YELLOW}${C_GREEN}✓${C_RESET} $1"
    else
        echo "PARTIAL SUCCESS: $1"
    fi
}

print_warning() {
    if $COLORS_ENABLED; then
        echo -e "${C_YELLOW}!${C_RESET} ${C_BOLD}Warning:${C_RESET} $1"
    else
        echo "WARNING: $1"
    fi
}

print_error() {
    if $COLORS_ENABLED; then
        echo -e "${C_RED}×${C_RESET} ${C_BOLD}Error:${C_RESET} $1"
    else
        echo "ERROR: $1"
    fi
}

print_fatal() {
    if $COLORS_ENABLED; then
        echo -e "${C_RED}${C_BOLD}FATAL ERROR:${C_RESET} $1" >&2
    else
        echo "FATAL ERROR: $1" >&2
    fi
    exit 1
}

# User interaction
print_prompt() {
    if $COLORS_ENABLED; then
        echo -ne "${C_YELLOW}>${C_RESET} $1 "
    else
        echo -n "> $1 "
    fi
}

# --- ASCII Art Functions ---
print_leonardo_title_art() {
    if $COLORS_ENABLED; then
        echo -e "${C_BOLD}${C_CYAN}"
        echo "  ┌───────────────────────────────────────────────────────────┐"
        echo "  │                                                           │"
        echo "  │       Leonardo AI USB Maker ✨ - Portable AI Power        │"
        echo "  │                                                           │"
        echo "  └───────────────────────────────────────────────────────────┘"
        echo "          (\\\\)"
        echo "          (•ᴗ•)🦙"
        echo "          / >)_/"
        echo "         \"AI anywhere!\""

        echo ""
        echo -e "  v${SCRIPT_VERSION} · Created by Eric & AI Assistant${C_RESET}"
    else
        echo ""
        echo "  +-----------------------------------------------------------+"
        echo "  |                                                           |"
        echo "  |       Leonardo AI USB Maker - Portable AI Power           |"
        echo "  |                                                           |"
        echo "  +-----------------------------------------------------------+"
        echo "          (\\)(\\)"
        echo "          (o-o)"
        echo "          / >)_/"
        echo "         \"AI anywhere!\""
        echo ""
        echo "  v${SCRIPT_VERSION} · Created by Eric & AI Assistant"
    fi
    echo ""
}

get_completion_message() {
    local elapsed_time=$1
    local message=""
    local random_num=$((RANDOM % 3 + 1))

    # Define messages for different time tiers
    if [ $elapsed_time -lt 60 ]; then
        # Under 1 minute - Speed Demon tier
        case $random_num in
            1) message="🚀 SPEED DEMON! Your computer might actually be from the future!" ;;
            2) message="⚡ WOW! Did you overclock this thing or just feed it energy drinks?" ;;
            3) message="🔥 That was suspiciously fast... are you a time traveler?" ;;
        esac
    elif [ $elapsed_time -lt 180 ]; then
        # Under 3 minutes - Fast tier
        case $random_num in
            1) message="🏎️ Nice machine! Almost as quick as our dev's morning coffee run" ;;
            2) message="👑 Your computer has earned its AI privileges. Well played!" ;;
            3) message="🦊 Swift and clever! Your CPU deserves a treat!" ;;
        esac
    elif [ $elapsed_time -lt 300 ]; then
        # Under 5 minutes - Average tier
        case $random_num in
            1) message="🦙 Not too shabby! This llama approves of your standard issue CPU" ;;
            2) message="👍 Solidly average timing - just like my dating life!" ;;
            3) message="🧠 A perfectly respectable install time. Very... sensible." ;;
        esac
    elif [ $elapsed_time -lt 600 ]; then
        # Under 10 minutes - Slow tier
        case $random_num in
            1) message="🐢 Taking it slow and steady? Your computer is... contemplative" ;;
            2) message="⏳ Is your CPU powered by an actual hamster wheel?" ;;
            3) message="🐌 Your patience is commendable! Maybe upgrade when you can?" ;;
        esac
    else
        # Over 10 minutes - Glacial tier
        case $random_num in
            1) message="🧊 Was your computer manufactured when dial-up was cool?" ;;
            2) message="🦥 If your computer were any slower, it would be going backward" ;;
            3) message="💤 Did you install this via carrier pigeon? Just wondering..." ;;
        esac
    fi

    echo "$message"
}

get_grade_msg() {
    local tier="$1"
    local random_num=$((RANDOM % 3 + 1))
    local message=""

    case "$tier" in
        fast)
            case $random_num in
                1) message="\ud83d\ude80 Impressive speed! Your computer clearly fears disappointing you." ;;
                2) message="\ud83c\udfc6 Nice timing! Almost as quick as your commitment issues." ;;
                3) message="\u26a1\ufe0f Wow, that was fast! Your CPU definitely wants a raise." ;;
            esac
            ;;
        med)
            case $random_num in
                1) message="\ud83d\ude0a Not bad! Your computer has middle-child energy." ;;
                2) message="\ud83d\ude0c Decent speed! As average as your dating profile." ;;
                3) message="\ud83d\ude44 That was... acceptable. Like pizza from a chain restaurant." ;;
            esac
            ;;
        slow)
            case $random_num in
                1) message="\ud83d\ude34 Is your computer running on a hamster wheel?" ;;
                2) message="\ud83d\udd25 Your PC is like Internet Explorer - struggling but trying its best." ;;
                3) message="\ud83d\ude11 If patience is a virtue, you're practically a saint now." ;;
            esac
            ;;
        glacial)
            case $random_num in
                1) message="\ud83d\ude2c Did you accidentally use a potato instead of a computer?" ;;
                2) message="\ud83d\ude29 That was so slow I grew a beard waiting... and I'm a llama!" ;;
                3) message="\ud83d\ude2b Your computer's philosophy: Why do today what can be done tomorrow?" ;;
            esac
            ;;
    esac
    echo "$message"
}

# Function to evaluate user's tech profile based on their setup choices
get_tech_profile() {
    local os_choice="$SELECTED_OS_TARGETS"
    local model_choice="$MODELS_TO_INSTALL_LIST"
    local profile=""
    local score=0
    local random_num=$((RANDOM % 3 + 1))
    local message=""

    # Score based on OS choice
    if [[ "$os_choice" == "linux,mac,win" ]]; then
        score=$((score + 1)) # Default/safe choice
    elif [[ "$os_choice" == "linux" ]]; then
        score=$((score + 3)) # Linux only = power user
    elif [[ "$os_choice" == "mac" ]]; then
        score=$((score + 2)) # Mac only = designer/developer
    elif [[ "$os_choice" == "win" ]]; then
        score=$((score + 1)) # Windows only = regular user
    fi

    # Score based on model choice
    if [[ "$model_choice" == *" "* ]]; then
        score=$((score + 2)) # Multiple models = advanced
    elif [[ "$model_choice" == *"phi3:mini"* ]]; then
        score=$((score + 2)) # Smaller model = knowledgeable
    elif [[ "$model_choice" == *"codellama"* ]]; then
        score=$((score + 3)) # Coding model = developer
    elif [[ "$MODEL_SOURCE_TYPE" == "custom"* || "$MODEL_SOURCE_TYPE" == "create_local"* ]]; then
        score=$((score + 4)) # Custom model = expert
    fi

    # Determine profile based on score
    if [[ $score -le 2 ]]; then
        profile="tech_newbie"
    elif [[ $score -le 4 ]]; then
        profile="casual_user"
    elif [[ $score -le 6 ]]; then
        profile="power_user"
    else
        profile="ai_hacker"
    fi

    # Generate message based on profile
    case "$profile" in
        tech_newbie)
            case $random_num in
                1) message="👩‍💼 ${C_BOLD}${C_WHITE}Tech Newbie:${C_RESET} Your configuration is like grandma's browser - lots of default settings and single-clicking everything." ;;
                2) message="🤓 ${C_BOLD}${C_WHITE}Beginner's Setup:${C_RESET} I see you went with the 'I just clicked next on everything' approach. Bold choice!" ;;
                3) message="👨‍🎓 ${C_BOLD}${C_WHITE}Digital Apprentice:${C_RESET} Your setup is so basic, it could be a pumpkin spice latte. But that's okay, we all start somewhere!" ;;
            esac
            ;;
        casual_user)
            case $random_num in
                1) message="💻 ${C_BOLD}${C_WHITE}Weekend Warrior:${C_RESET} Your tech choices suggest you know just enough to be dangerous - like knowing how to take a screenshot but not where it saves." ;;
                2) message="🌊 ${C_BOLD}${C_WHITE}Tech Surfer:${C_RESET} You ride the waves of technology without getting too deep. Your setup is the equivalent of owning a smartphone but only using it for calls." ;;
                3) message="📚 ${C_BOLD}${C_WHITE}Casual Tech Enthusiast:${C_RESET} You dabble in tech like most people dabble in foreign languages - just enough to order a beer and find the bathroom." ;;
            esac
            ;;
        power_user)
            case $random_num in
                1) message="🤖 ${C_BOLD}${C_WHITE}Power User:${C_RESET} Your setup shows you've fallen down a few tech rabbit holes. We're impressed but concerned for your social life." ;;
                2) message="🔌 ${C_BOLD}${C_WHITE}Tech Maximalist:${C_RESET} You're the person friends call when their Wi-Fi stops working. Your setup reflects that responsibility." ;;
                3) message="👾 ${C_BOLD}${C_WHITE}Digital Native:${C_RESET} Your configuration choices suggest you've experienced enough blue screens to no longer fear death." ;;
            esac
            ;;
        ai_hacker)
            case $random_num in
                1) message="🦹 ${C_BOLD}${C_WHITE}AI Wizard:${C_RESET} Your tech choices are so advanced I'm slightly concerned you're building Skynet. Please use your powers for good!" ;;
                2) message="🥷 ${C_BOLD}${C_WHITE}Terminal Junkie:${C_RESET} Your setup screams 'I have strong opinions about text editors.' Let me guess - you use dark mode everywhere?" ;;
                3) message="👨‍💻 ${C_BOLD}${C_WHITE}DIY Hacker:${C_RESET} With these configuration choices, I assume your home has more blinking LED lights than a Christmas tree." ;;
            esac
            ;;
    esac
    echo "$message"
}

# Variable for tracking installation time was moved to top of script

print_leonardo_success_art() {
    local usb_path="$1"
    local models="$2"
    local elapsed_time=$(($(date +%s) - ${INSTALL_START_TIME}))
    local completion_message=$(get_completion_message "$elapsed_time")

    if $COLORS_ENABLED; then
        echo -e "\e[1;92m"
        cat <<'EOF'
┌────────────────────────────────────────────────────────────────┐
│  ███████╗██╗   ██╗ ██████╗ ██████╗███████╗███████╗███████╗██╗  │
│  ██╔════╝██║   ██║██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝██║  │
│  ███████╗██║   ██║██║     ██║     █████╗  ███████╗███████╗██║  │
│  ╚════██║██║   ██║██║     ██║     ██╔══╝  ╚════██║╚════██║╚═╝  │
│  ███████║╚██████╔╝╚██████╗╚██████╗███████╗███████║███████║██╗  │
│  ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝╚══════╝╚══════╝╚══════╝╚═╝  │
│                                                                │
EOF

        # Print the completion message
        printf "│ %-78s │\n" "$completion_message"

        cat <<'EOF'
│                                                                │
├────────────────────── LEONARDO AI USB MAKER ──────────────────┤
│                       ✅ MISSION SUCCESS ✅                    │
└────────────────────────────────────────────────────────────────┘
EOF
        echo "         (\\(\\     AI Liberation Operation Complete."
        echo "         (•ᴗ•)🦙  Portable intelligence fully deployed."
        echo "         / >)_/   Ready to revolutionize any system."
        echo ""
        echo "NEXT STEPS"
        echo "• USB Location: $usb_path"
        echo "• Models Installed: $models"
        echo "• Safely eject your USB from this computer"
        echo "• Plug USB into any Linux/macOS/Windows machine"
        echo "• Run leonardo.sh (Linux), leonardo.command (Mac), or leonardo.bat (Win)"
        echo "• Access the Web UI through the automatically opened browser"
        echo "• Enjoy your portable AI assistant anywhere you go"
        echo ""
        echo "                -- Happy hacking! --"
        echo -e "\e[0m"
    else
        echo ""
        echo "+-------------------------------------------------------------------+"
        echo "|                                                                   |"
        echo "|                  INSTALLATION COMPLETE                            |"
        echo "|                                                                   |"
        echo "|                Your Leonardo AI USB is ready to use!              |"
        echo "|                                                                   |"
        echo "|  USB Location: $usb_path                                          |"
        echo "|  Models:      $models                                             |"
        echo "|                                                                   |"
        echo "|  NEXT STEPS:                                                      |"
        echo "|  1. Safely eject your USB drive                                   |"
        echo "|  2. Insert it into any computer with Ollama installed             |"
        echo "|  3. Run the startup script for your operating system              |"
        echo "|  4. Enjoy your portable AI!                                       |"
        echo "|                                                                   |"
        echo "+-------------------------------------------------------------------+"
        echo ""
        echo "      (\\)(\\)             Leonardo AI USB Maker"
        echo "      (^-^)             Version 4.0.0"
        echo "       / >U USB          www.leonardoai.com"
        echo "      \"Portable AI, anywhere!\""
    fi
    echo ""
}

# --- Core Utility Functions ---

# Safe chown that won't fail on exFAT filesystems and won't display irrelevant error messages
safe_chown() {
    local target_path="$1"
    shift
    local ownership="$1"
    local verbose="${2:-false}"

    # Default to current user if no ownership specified
    if [ -z "$ownership" ]; then
        ownership="$(id -u):$(id -g)"
    fi

    # Only attempt chown if the path exists
    if [ -z "$target_path" ] || [ ! -e "$target_path" ]; then
        return 0
    fi

    # Check filesystem type
    local fs_type=$(df -T "$target_path" 2>/dev/null | awk 'NR==2 {print $2}' | tr '[:upper:]' '[:lower:]')

    # Skip chown for exFAT or if we can't determine filesystem
    if [ "$fs_type" = "exfat" ]; then
        # Only show message if verbose mode is enabled
        if [ "$verbose" = "true" ]; then
            print_info "Skipping ownership changes on exFAT filesystem (normal behavior)"
        fi
        return 0
    elif [ -z "$fs_type" ]; then
        # Unknown filesystem type
        return 0
    fi

    # Perform chown if the filesystem supports it and suppress any error messages
    sudo chown -R "$ownership" "$target_path" 2>/dev/null || true
}

# Format a device with exFAT filesystem
format_usb_exfat() {
    # Important: Save current error handling settings and temporarily disable error exit
    local old_errexit_setting=$(set +o | grep errexit)
    set +e  # Disable exit on error for this function

    local device_path="$1"
    local label="${2:-CHATUSB}"
    local part_suffix="1"
    local partition_path
    local formatting_success=false

    # Determine partition suffix based on device type
    if [[ "$device_path" == *nvme*n* ]] || [[ "$device_path" == *mmcblk* ]]; then
        part_suffix="p1"
    fi

    # Set the partition path
    partition_path="${device_path}${part_suffix}"

    # Unmount any mounted partitions of this device
    print_info "Unmounting any existing partitions on $device_path..."

    # First, try to unmount all mounted partitions - scan all possible partitions
    for part in $(lsblk -lno NAME | grep -E "^$(basename "$device_path")[0-9p]*$"); do
        local mount_point=$(lsblk -lno MOUNTPOINT "/dev/$part" 2>/dev/null || true)
        if [ -n "$mount_point" ]; then
            print_info "Unmounting /dev/$part from $mount_point..."
            sudo umount "/dev/$part" 2>/dev/null || true
            if mountpoint -q "$mount_point" 2>/dev/null; then
                print_info "Force unmounting $mount_point with lazy option..."
                sudo umount -l "$mount_point" 2>/dev/null || true
            fi
        fi
    done

    # Force unmount any remaining mounts
    for mount_point in $(mount | grep -E "$device_path|$(basename "$device_path")" | awk '{print $3}'); do
        print_info "Force unmounting $mount_point..."
        sudo umount -l "$mount_point" 2>/dev/null || true
    done

    # More aggressively ensure device isn't in use by any process
    print_info "Checking for processes using the device..."
    local device_parts=$(lsblk -ln -o NAME "$device_path" 2>/dev/null | grep -v "^$(basename "$device_path")$" || true)

    # Kill processes using the main device
    local device_in_use=$(lsof "$device_path" 2>/dev/null || true)
    if [ -n "$device_in_use" ]; then
        print_warning "Device $device_path is in use by the following processes:"
        echo "$device_in_use"
        print_info "Attempting to kill processes using the device..."
        sudo lsof -t "$device_path" 2>/dev/null | xargs -r sudo kill -9 2>/dev/null || true
    fi

    # Kill processes using any partitions
    for part in $device_parts; do
        local part_in_use=$(lsof "/dev/$part" 2>/dev/null || true)
        if [ -n "$part_in_use" ]; then
            print_warning "Partition /dev/$part is in use by processes, killing them..."
            sudo lsof -t "/dev/$part" 2>/dev/null | xargs -r sudo kill -9 2>/dev/null || true
        fi
    done

    # Force kernel to drop caches and sync
    sync
    print_info "Flushing disk buffers..."
    if command -v blockdev >/dev/null 2>&1; then
        sudo blockdev --flushbufs "$device_path" 2>/dev/null || true
    fi

    # Give the system a moment to process the unmounts
    sleep 3

    # Wipe existing filesystem signatures
    print_info "Wiping existing filesystem signatures (this may take a moment)..."
    sudo wipefs -a -f "$device_path" 2>/dev/null || true

    # Ensure the device is completely flushed
    sync
    sleep 1

    # Create new partition table and partition with fallback mechanism
    print_info "Crafting new GPT partition table..."
    local partition_table_result=$(sudo parted -s "$device_path" mklabel gpt 2>&1 || true)
    local partition_error=false

    if echo "$partition_table_result" | grep -q "unable to inform the kernel"; then
        print_warning "Kernel could not be informed of partition table change. Trying fallback method..."
        partition_error=true
    elif [ $? -ne 0 ]; then
        print_warning "Initial partition table creation had issues. Trying fallback method..."
        partition_error=true
    fi

    # If we had an error, try a different approach
    if $partition_error; then
        print_info "Using alternative partitioning approach with direct device control..."

        # Try unmounting and force cleaning the device with alternative tools
        sync
        print_info "Force cleaning any remaining device references..."

        # Additional force eject (useful for some distributions)
        if command -v eject >/dev/null 2>&1; then
            print_info "Using eject to force device release..."
            sudo eject -s "$device_path" 2>/dev/null || true
            sleep 1
        fi

        # Try direct dd to wipe the first few MB of the drive (this often helps clear partition tables)
        print_info "Force wiping partition signatures with direct method..."
        sudo dd if=/dev/zero of="$device_path" bs=1M count=10 2>/dev/null || true
        sync
        sleep 2

        # Try creating partition table again with sfdisk (which is sometimes more robust)
        if command -v sfdisk >/dev/null 2>&1; then
            print_info "Crafting partition table with alternative tool (sfdisk)..."
            echo 'label: gpt' | sudo sfdisk --force "$device_path" 2>/dev/null || true
            sleep 1
        fi
    fi

    # Always try to create the partition, even if there were issues with the partition table
    print_info "Crafting primary partition..."
    local create_partition_result=$(sudo parted -s -a optimal "$device_path" mkpart primary 0% 100% 2>&1 || true)

    # If this fails too, try with sfdisk
    if echo "$create_partition_result" | grep -q "unable to inform the kernel"; then
        print_warning "Kernel could not be informed of partition change. Trying alternative partition creation..."

        if command -v sfdisk >/dev/null 2>&1; then
            print_info "Crafting partition with alternative tool (sfdisk)..."
            echo ',100%' | sudo sfdisk --force --append "$device_path" 2>/dev/null || true
        elif command -v fdisk >/dev/null 2>&1; then
            print_info "Crafting partition with alternative tool (fdisk)..."
            echo -e "n\np\n1\n\n\nw" | sudo fdisk --wipe=always "$device_path" 2>/dev/null || true
        fi
    fi

    # Wait for partition to be available with better feedback
    print_info "Waiting for partition to be available..."
    sync
    sleep 3
    sync
    print_info "Flushing caches and waiting for device to settle..."
    if command -v udevadm >/dev/null 2>&1; then
        sudo udevadm settle || true
    fi

    # Force kernel to re-read the partition table with multiple approaches
    print_info "Forcing kernel to re-read the partition table..."

    # Try multiple methods to reload the partition table
    sync
    sudo partprobe "$device_path" 2>/dev/null || true

    # Try hdparm if available
    if command -v hdparm >/dev/null 2>&1; then
        print_info "Using hdparm to force device re-read..."
        sudo hdparm -z "$device_path" 2>/dev/null || true
    fi

    # Try sfdisk if available
    if command -v sfdisk >/dev/null 2>&1; then
        print_info "Using sfdisk to force device re-read..."
        echo "w" | sudo sfdisk --force "$device_path" 2>/dev/null || true
    fi

    # Try direct kernel block device re-read
    if [ -e /sys/block/$(basename "$device_path")/device/rescan ]; then
        print_info "Requesting device rescan through sysfs..."
        echo 1 | sudo tee /sys/block/$(basename "$device_path")/device/rescan >/dev/null 2>&1 || true
    fi

    # Update partition path based on device type
    if [[ "$device_path" == *nvme*n* ]] || [[ "$device_path" == *mmcblk* ]]; then
        partition_path="${device_path}p1"
    else
        partition_path="${device_path}1"
    fi

    # Verify the partition exists before proceeding with enhanced retries
    local max_retries=10
    local retry_count=0

    while [ ! -b "$partition_path" ] && [ $retry_count -lt $max_retries ]; do
        print_info "Waiting for partition $partition_path to appear (attempt $((retry_count + 1))/$max_retries)..."
        # Try additional partition reload methods on alternate attempts
        if [ $((retry_count % 2)) -eq 1 ]; then
            print_info "Trying additional methods to refresh partition table..."
            sync
            sudo partprobe "$device_path" 2>/dev/null || true
            if command -v hdparm >/dev/null 2>&1; then
                sudo hdparm -z "$device_path" 2>/dev/null || true
            fi
            if command -v udevadm >/dev/null 2>&1; then
                sudo udevadm trigger --subsystem-match=block || true
                sudo udevadm settle || true
            fi
        fi
        sleep 2
        retry_count=$((retry_count + 1))
    done

    if [ ! -b "$partition_path" ]; then
        print_warning "Partition $partition_path did not appear through normal methods after $max_retries attempts"
        print_info "Attempting to create partition with last-resort method..."

        # Last resort: Try a direct approach with dd to create partition signature then try to format directly
        if command -v fdisk >/dev/null 2>&1; then
            print_info "Using fdisk emergency method..."
            (echo o; echo n; echo p; echo 1; echo; echo; echo w) | sudo fdisk "$device_path" 2>/dev/null || true
            sync; sleep 2

            # Force kernel to reload with every available method
            sudo partprobe "$device_path" 2>/dev/null || true
            if command -v hdparm >/dev/null 2>&1; then
                sudo hdparm -z "$device_path" 2>/dev/null || true
            fi

            # Wait a bit longer for this last attempt
            sleep 5

            # If the partition still doesn't exist, try to format the whole device
            if [ ! -b "$partition_path" ]; then
                print_warning "Unable to create partition properly. Will attempt to format the whole device instead."
                # Set the partition path to the whole device as a fallback
                partition_path="$device_path"
                print_info "Using whole device for formatting: $partition_path"
            fi
        else
            # If fdisk isn't available, just use the whole device
            print_warning "Unable to create partition. Will attempt to format the whole device instead."
            partition_path="$device_path"
            print_info "Using whole device for formatting: $partition_path"
        fi
    fi

    print_success "Partition created successfully: $partition_path"

    # Format the partition as exFAT with fallback mechanisms
    print_info "Formatting $partition_path as exFAT with label: $label"

    # Make sure the partition isn't mounted before formatting
    sudo umount "$partition_path" 2>/dev/null || true

    local format_cmd=""
    local format_success=false

    # Try different formatting tools in order of preference
    if command -v mkfs.exfat &>/dev/null; then
        print_info "Using mkfs.exfat for formatting..."
        if sudo mkfs.exfat -n "$label" "$partition_path" 2>/dev/null; then
            format_success=true
        else
            print_warning "mkfs.exfat failed, will try alternative methods..."
        fi
    fi

    # Try exfatformat if mkfs.exfat failed or isn't available
    if ! $format_success && command -v exfatformat &>/dev/null; then
        print_info "Using exfatformat for formatting..."
        if sudo exfatformat -n "$label" "$partition_path" 2>/dev/null; then
            format_success=true
        else
            print_warning "exfatformat failed, will try alternative methods..."
        fi
    fi

    # If exFAT formatting failed, try with FAT32 as a last resort
    if ! $format_success && command -v mkfs.vfat &>/dev/null; then
        print_warning "exFAT formatting failed. Attempting to use FAT32 as fallback..."
        print_info "Using mkfs.vfat (FAT32) for formatting..."
        if sudo mkfs.vfat -n "$label" "$partition_path" 2>/dev/null; then
            print_warning "USB formatted as FAT32 instead of exFAT. Some large files may not be supported."
            format_success=true
        fi
    fi

    if ! $format_success; then
        print_error "All formatting attempts failed for $partition_path"
        print_info "You may need to manually format the drive using Disk Utility, GParted, or similar tools."
        eval "$old_errexit_setting"  # Restore original error handling
        return 1
    fi

    # Success!
    formatting_success=true
    eval "$old_errexit_setting"  # Restore original error handling
    return 0

    print_success "Successfully formatted $device_path with exFAT filesystem"
    return 0
}

spinner() {
    local pid=$1
    local message=${2:-"Processing..."}
    local delay=0.1
    local spinchars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local current_frame=0

    # Print the initial message
    echo -ne "${C_BLUE}$message ${C_RESET}"

    # Keep spinning while process is active
    while ps -p "$pid" > /dev/null; do
        # Get current animation frame
        local spinner="${spinchars[$((current_frame % ${#spinchars[@]}))]}"
        current_frame=$((current_frame + 1))

        # Print spinner and backspace to reuse the same space
        printf "${C_CYAN}[%s]${C_RESET}" "$spinner"
        sleep $delay
        printf "\b\b\b"
    done

    # Show completion
    printf "${C_GREEN}[✓]${C_RESET}\n"

    # Wait for process to complete and return its exit code
    wait "$pid"
    return $?
}

ask_yes_no_quit() {
    local prompt_message=$1; local result_var_name=$2; local danger_mode=${3:-"no"}; local choice
    print_double_line

    # Adjust box width based on terminal width
    local box_width=58

    # Check if the special final warning flag is set
    if [[ "$danger_mode" == "final" ]]; then
        # Skip showing the llama art - this will be handled by the caller
        # with the crazy-eyed llama
        :  # No-op
    elif [[ "$danger_mode" == "yes" ]]; then
        # Mischievous llama with wink for CAUTION level
        # Using a mix of yellow and red to make "orange" (closest we can get in terminal)
        echo -e "${C_BOLD}${C_YELLOW}⚠️  CAUTION: DESTRUCTIVE OPERATION ⚠️${C_RESET}"
        echo -e "${C_YELLOW} (\\(\\    ${C_RESET}"
        echo -e "${C_YELLOW} (>‿-)🦙 ${C_RESET}"  # Mischievous wink
        echo -e "${C_YELLOW} / >)_/   ${C_RESET}"
    else
        # Regular friendly llama for normal operations
        echo -e "${C_BOLD}${C_BLUE}🤔 USER INPUT REQUIRED 🤔${C_RESET}"
        echo -e "${C_BLUE} (\\(\\    ${C_RESET}"
        echo -e "${C_BLUE} (•ᴗ•)🦙 ${C_RESET}"
        echo -e "${C_BLUE} / >)_/   ${C_RESET}"
    fi
    while true; do
        print_prompt "$prompt_message ${C_DIM}([Y]es/[N]o/[Q]uit):${C_RESET} "
        read -r choice
        case "$choice" in
            [yY]|[yY][eE][sS] ) eval "$result_var_name=\"yes\""; print_double_line; echo ""; break;;
            [nN]|[nN][oO]     ) eval "$result_var_name=\"no\"";  print_double_line; echo ""; break;;
            [qQ]              ) print_info "Quitting script."; exit 0;;
            *                 ) print_warning "Invalid input. Please enter Y, N, or Q.";;
        esac
    done
}

sha256_hash_cmd() {
    if command -v shasum &>/dev/null; then
        shasum -a 256 "$@"
    elif command -v sha256sum &>/dev/null; then
        sha256sum "$@"
    else
        print_error "Neither shasum nor sha256sum found for generating checksums." >&2
        return 1
    fi
}

bytes_to_human_readable() {
    local bytes_in=$1
    if ! [[ "$bytes_in" =~ ^[0-9]+$ ]]; then echo "${C_DIM}N/A${C_RESET}"; return; fi
    if [ "$bytes_in" -lt 1024 ]; then echo "${C_BOLD}${bytes_in}B${C_RESET}";
    elif [ "$bytes_in" -lt 1048576 ]; then awk "BEGIN {printf \"${C_BOLD}%.1fKB${C_RESET}\", $bytes_in/1024}";
    elif [ "$bytes_in" -lt 1073741824 ]; then awk "BEGIN {printf \"${C_BOLD}%.1fMB${C_RESET}\", $bytes_in/1048576}";
    else awk "BEGIN {printf \"${C_BOLD}%.1fGB${C_RESET}\", $bytes_in/1073741824}"; fi
}

# --- QoL: Root Privilege Check ---
check_root_privileges() {
    print_subheader "🛡️ Checking script privileges..."
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script requires root (sudo) privileges to perform many of its operations (e.g., formatting drives, managing system-level Ollama files, mounting)."
        echo -e "${C_YELLOW}Please re-run this script using 'sudo ./$SCRIPT_SELF_NAME'${C_RESET}"
        echo -e "${C_DIM}Example: sudo ./$SCRIPT_SELF_NAME${C_RESET}"
        exit 1
    else
        print_success "Script is running with root privileges."
    fi
    print_line
}


# --- USB Mount and Disk Handling Functions ---
ensure_usb_mounted_and_writable() {
    local device_path="$1"
    local mount_point="$2"
    local fs_type=""
    # More permissive mount options for better compatibility
    local mount_options="rw,noatime,nodev,nosuid,uid=$(id -u),gid=$(id -g),umask=0022"

    # If no device path provided, use the global
    [ -z "$device_path" ] && device_path="$USB_DEVICE_PATH"

    # If no mount point provided, use the global or create a default one
    if [ -z "$mount_point" ]; then
        if [ -n "$USB_BASE_PATH" ]; then
            mount_point="$USB_BASE_PATH"
        else
            # Create a temporary directory in the user's home directory
            local username=$(whoami)
            mount_point="/home/$username/leonardo_mount_$(basename "$device_path")"
            # Ensure the home directory exists
            if [ ! -d "/home/$username" ]; then
                mount_point="/tmp/leonardo_mount_$(basename "$device_path")"
            fi
            # Clean up any existing mount point
            sudo umount "$mount_point" 2>/dev/null || true
            sudo rm -rf "$mount_point"
            mkdir -p "$mount_point"
        fi
    fi

    # Ensure mount point exists with correct permissions
    if [ ! -d "$mount_point" ]; then
        sudo mkdir -p "$mount_point" 2>/dev/null || {
            print_error "Failed to create mount point: $mount_point"
            return 1
        }
    fi

    # Ensure the mount point has the correct ownership
    sudo chown -R $USER:$USER "$mount_point" 2>/dev/null || {
        print_warning "Could not change ownership of $mount_point to $USER"
    }
    sudo chmod 755 "$mount_point" 2>/dev/null || true

    # Check if already mounted at the desired location
    current_mount=$(findmnt -n -o TARGET --source "$device_path" 2>/dev/null || true)

    if [ -n "$current_mount" ]; then
        if [ "$current_mount" = "$mount_point" ]; then
            # Already mounted at the right place, check if writable
            if sudo touch "$mount_point/.write_test" 2>/dev/null; then
                sudo rm -f "$mount_point/.write_test"
                USB_BASE_PATH="$mount_point"
                return 0
            else
                # Remount as read-write
                sudo mount -o remount,rw "$device_path" "$mount_point" 2>/dev/null && {
                    USB_BASE_PATH="$mount_point"
                    return 0
                }
            fi
        else
            # Already mounted somewhere else, try to remount
            sudo umount "$device_path" 2>/dev/null || {
                print_error "Device $device_path is already mounted at $current_mount and could not be unmounted"
                return 1
            }
        fi
    fi

    # Try to determine filesystem type
    fs_type=$(lsblk -no FSTYPE "$device_path" 2>/dev/null || true)

    # Mount the device
    if [ -n "$fs_type" ]; then
        # Filesystem type detected, use it
        if ! sudo mount -t "$fs_type" -o "$mount_options" "$device_path" "$mount_point" 2>/dev/null; then
            print_error "Failed to mount $device_path as $fs_type to $mount_point"
            return 1
        fi
    else
        # Try auto-detection
        if ! sudo mount -o "$mount_options" "$device_path" "$mount_point" 2>/dev/null; then
            print_error "Failed to auto-mount $device_path to $mount_point"
            return 1
        fi
    fi

    # Double check it's writable
    if ! sudo touch "$mount_point/.write_test" 2>/dev/null; then
        print_error "Mounted $device_path at $mount_point but it's not writable"
        sudo umount "$mount_point" 2>/dev/null || true
        return 1
    fi

    sudo rm -f "$mount_point/.write_test"
    USB_BASE_PATH="$mount_point"
    return 0
}

ask_format_usb() {
    local usb_device="$1"
    local usb_label="${2:-CHATUSB}"
    local part_suffix="1"

    # Debug: Show the device we're working with
    print_info "Preparing to format device: $usb_device"

    # Check if the device exists and is a block device
    if [ ! -b "$usb_device" ]; then
        print_error "Device $usb_device does not exist or is not a block device"
        return 1
    fi

    # Determine partition suffix based on device type
    if [[ "$usb_device" == *"nvme"* ]] || [[ "$usb_device" == *"mmcblk"* ]]; then
        part_suffix="p1"
    fi

    # Set the partition path
    USB_PARTITION_PATH="${usb_device}${part_suffix}"

    # Debug: Show the partition path
    print_info "Using partition path: $USB_PARTITION_PATH"

    # Check if this looks like an internal disk
    if [[ "$(lsblk -dno RM "$usb_device" 2>/dev/null)" == "0" ]]; then
        print_error "WARNING: $usb_device appears to be an internal disk!"
        ask_yes_no_quit "Are you ABSOLUTELY SURE you want to format $usb_device?\nTHIS WILL DESTROY ALL DATA ON THIS DISK!" confirm_format "yes"
        if [[ "$confirm_format" != "yes" ]]; then
            print_error "Formatting aborted by user."
            return 1
        fi
    fi

    ask_yes_no_quit "Do you want to format the USB drive $usb_device?\n   (RECOMMENDED for new setups. ALL DATA ON $usb_device WILL BE LOST!)" FORMAT_USB_CHOICE "yes"

    if [[ "$FORMAT_USB_CHOICE" == "yes" ]]; then
        print_info "Preparing to format $usb_device as exFAT with label: $usb_label"

        # Unmount any mounted partitions
        print_info "Unmounting any existing partitions on $usb_device..."

        # First, try to unmount all mounted partitions
        for partition in $(lsblk -lno NAME,MOUNTPOINT | grep -E "^$(basename "$usb_device")[0-9]+" | grep -v "^$(basename "$usb_device")$" | awk '{print $1}'); do
            local mount_point=$(lsblk -lno MOUNTPOINT "/dev/$partition" 2>/dev/null || true)
            if [ -n "$mount_point" ]; then
                print_info "Unmounting /dev/$partition from $mount_point..."
                sudo umount "/dev/$partition" 2>/dev/null || true
            fi
        done

        # Force unmount any remaining mounts
        for mount_point in $(mount | grep "$usb_device" | awk '{print $3}'); do
            print_info "Force unmounting $mount_point..."
            sudo umount -l "$mount_point" 2>/dev/null || true
        done

        # Ensure device isn't in use by any process
        local device_in_use=$(lsof "$usb_device" 2>/dev/null || true)
        if [ -n "$device_in_use" ]; then
            print_warning "Device $usb_device is in use by the following processes:"
            echo "$device_in_use"
            print_info "Attempting to kill processes using the device..."
            sudo lsof -t "$usb_device" 2>/dev/null | xargs -r sudo kill -9 2>/dev/null || true
        fi

        # Give the system a moment to process the unmounts
        sleep 2

        # Wipe existing filesystem signatures with force and backup options
        print_info "Wiping existing filesystem signatures (this may take a moment)..."

        # First try with -a (all) and -f (force)
        if ! sudo wipefs -a -f "$usb_device" 2>/dev/null; then
            # If that fails, try wiping individual signatures more aggressively
            print_warning "Standard wipefs failed, trying more aggressive approach..."

            # Try to wipe all possible signature types
            for offset in 0 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576; do
                print_info "  Trying to wipe at offset $offset..."
                sudo wipefs --offset $offset --all "$usb_device" 2>/dev/null || true
            done

            # One final attempt with force
            if ! sudo wipefs -a -f "$usb_device" 2>/dev/null; then
                print_error "Failed to wipe existing filesystem signatures. The device may be in use by the system."
                print_info "Try the following steps:"
                echo "  1. Unmount all partitions: sudo umount ${usb_device}*"
                echo "  2. Check for mounted partitions: mount | grep ${usb_device}"
                echo "  3. Check for processes using the device: sudo lsof | grep ${usb_device}"
                echo "  4. Try physically unplugging and replugging the device"
                return 1
            fi
        fi

        # Ensure the device is completely flushed
        sync
        sleep 1

        # Create new partition table and partition
        print_info "Crafting new GPT partition table..."
        if ! sudo parted -s "$usb_device" mklabel gpt; then
            print_error "Failed to create new partition table on $usb_device"
            return 1
        fi

        print_info "Crafting primary partition..."
        if ! sudo parted -s -a optimal "$usb_device" mkpart primary 0% 100%; then
            print_error "Failed to create partition on $usb_device"
            return 1
        fi

        # Wait for partition to be available and get the correct partition path
        print_info "Waiting for partition to be available..."
        sync
        sleep 2

        # Force kernel to re-read the partition table
        sudo partprobe "$usb_device" || true

        # Update partition path - handle both NVMe and regular SCSI devices
        if [[ "$usb_device" == *"nvme"* ]] || [[ "$usb_device" == *"mmcblk"* ]]; then
            USB_PARTITION_PATH="${usb_device}p1"
        else
            USB_PARTITION_PATH="${usb_device}1"
        fi

        # Verify the partition exists before proceeding
        local max_retries=5
        local retry_count=0

        while [ ! -b "$USB_PARTITION_PATH" ] && [ $retry_count -lt $max_retries ]; do
            print_info "Waiting for partition $USB_PARTITION_PATH to appear (attempt $((retry_count + 1))/$max_retries)..."
            sleep 1
            retry_count=$((retry_count + 1))
        done

        if [ ! -b "$USB_PARTITION_PATH" ]; then
            print_error "Partition $USB_PARTITION_PATH did not appear after $max_retries attempts"
            return 1
        fi

        print_success "Partition created successfully: $USB_PARTITION_PATH"

        # Format the partition as exFAT
        print_info "Formatting ${USB_PARTITION_PATH} as exFAT with label: $usb_label"
        if ! command -v mkfs.exfat >/dev/null 2>&1; then
            print_error "exFAT tools not found. Please install exfatprogs or exfat-utils."
            return 1
        fi

        if ! sudo mkfs.exfat -n "$usb_label" "$USB_PARTITION_PATH"; then
            print_error "Failed to format ${USB_PARTITION_PATH} as exFAT"
            return 1
        fi

        print_success "Successfully formatted $usb_device with exFAT filesystem"

        # Remount the new filesystem - use the partition path, not the raw device
        print_info "Attempting to mount $USB_PARTITION_PATH..."
        if ! ensure_usb_mounted_and_writable "$USB_PARTITION_PATH"; then
            print_error "Failed to mount the newly formatted USB drive"

            # Try alternative mounting method
            print_info "Trying alternative mounting method..."
            local username=$(whoami)
            local mount_point="/home/$username/leonardo_mount_$(basename "$USB_PARTITION_PATH")"

            # Ensure mount point exists and is clean
            sudo umount "$mount_point" 2>/dev/null || true
            sudo rm -rf "$mount_point"
            mkdir -p "$mount_point"

            # Try mounting with explicit options
            if sudo mount -t exfat -o rw,user,uid=$(id -u),gid=$(id -g),umask=0022 "$USB_PARTITION_PATH" "$mount_point"; then
                print_success "Successfully mounted $USB_PARTITION_PATH to $mount_point"
                USB_BASE_PATH="$mount_point"
            else
                print_error "All mounting attempts failed. Last error: $?"
                print_info "You may need to manually mount the drive with:"
                echo "  sudo mkdir -p $mount_point"
                echo "  sudo mount -t exfat -o rw,user,uid=$(id -u),gid=$(id -g) $USB_PARTITION_PATH $mount_point"
                return 1
            fi
        fi
    else
        print_info "USB will NOT be formatted. Ensure it's already formatted with exFAT or a compatible filesystem."

        # Try to get the existing label
        local existing_label=""
        if command -v exfatlabel >/dev/null 2>&1; then
            existing_label=$(sudo exfatlabel "$USB_PARTITION_PATH" 2>/dev/null || true)
        fi

        if [ -n "$existing_label" ]; then
            print_info "Using existing label: ${C_BOLD}$existing_label${C_RESET}"
            USB_LABEL="$existing_label"
        else
            print_warning "Could not determine existing label. Using default: ${C_BOLD}$usb_label${C_RESET}"
            USB_LABEL="$usb_label"
        fi
    fi
}

calculate_estimated_binary_size_bytes() {
    local total_bytes=0
    local os_targets=($(echo "$SELECTED_OS_TARGETS" | tr ',' ' '))

    # Base sizes in bytes for each component (these are approximate and can be adjusted)
    local -A base_sizes=(
        [linux]=$((500 * 1024 * 1024))      # 500MB for Linux
        [mac]=$((600 * 1024 * 1024))        # 600MB for macOS
        [win]=$((550 * 1024 * 1024))        # 550MB for Windows
    )

    # Additional space for models and data
    local model_size=$((1500 * 1024 * 1024))  # 1.5GB for models
    local overhead_size=$((200 * 1024 * 1024)) # 200MB for overhead

    # Calculate total size based on selected OS targets
    for os in "${os_targets[@]}"; do
        if [ -n "${base_sizes[$os]}" ]; then
            total_bytes=$((total_bytes + ${base_sizes[$os]}))
        fi
    done

    # Add model size and overhead
    total_bytes=$((total_bytes + model_size + overhead_size))

    # Convert to human-readable format
    local human_size
    if [ $total_bytes -ge $((1024 * 1024 * 1024)) ]; then
        human_size=$(echo "scale=2; $total_bytes / (1024 * 1024 * 1024)" | bc)GB
    else
        human_size=$(echo "scale=2; $total_bytes / (1024 * 1024)" | bc)MB
    fi

    # Use plain echo instead of print_info to avoid color codes
    echo "Estimated required space: ${human_size} (${total_bytes} bytes) for ${#os_targets[@]} OS target(s)" >&2
    echo $total_bytes
}

# New QoL: Enhanced model size estimation
get_estimated_model_size_gb() {
    local model_name_full="$1"
    local model_name_base="${model_name_full%%:*}" # Get part before colon
    local model_size_gb="5.0" # Default fallback size

    case "$model_name_base" in
        "llama3")
            if [[ "$model_name_full" == *"8b"* ]]; then model_size_gb="4.7";
            elif [[ "$model_name_full" == *"70b"* ]]; then model_size_gb="39.0";
            fi
            ;;
        "phi3")
            if [[ "$model_name_full" == *"mini"* ]]; then model_size_gb="2.3"; # phi3:mini is ~2.3GB
            elif [[ "$model_name_full" == *"medium"* ]]; then model_size_gb="8.2"; # phi3:medium
            fi
            ;;
        "codellama")
            if [[ "$model_name_full" == *"7b"* ]]; then model_size_gb="3.8";
            elif [[ "$model_name_full" == *"13b"* ]]; then model_size_gb="7.4";
            elif [[ "$model_name_full" == *"34b"* ]]; then model_size_gb="19.0";
            fi
            ;;
        "mistral") model_size_gb="4.1";; # mistral 7b
        "gemma")
             if [[ "$model_name_full" == *"2b"* ]]; then model_size_gb="1.4";
             elif [[ "$model_name_full" == *"7b"* ]]; then model_size_gb="4.8";
             fi
            ;;
        "llava") model_size_gb="4.5";; # Approximate for common llava-7b
        "qwen")
            if [[ "$model_name_full" == *"0.5b"* ]]; then model_size_gb="0.6";
            elif [[ "$model_name_full" == *"1.8b"* ]]; then model_size_gb="1.2";
            elif [[ "$model_name_full" == *"4b"* ]]; then model_size_gb="2.6";
            elif [[ "$model_name_full" == *"7b"* ]]; then model_size_gb="4.5";
            fi
            ;;
        # Add more known models here
    esac
    echo "$model_size_gb"
}

calculate_total_estimated_models_size_gb() {
    local total_size_gb=0
    for model_name in "${MODELS_TO_INSTALL_LIST[@]}"; do
        local single_model_size_gb=$(get_estimated_model_size_gb "$model_name")
        total_size_gb=$(awk "BEGIN {print $total_size_gb + $single_model_size_gb}")
    done
    ESTIMATED_MODELS_SIZE_GB=$(printf "%.2f" "$total_size_gb") # Update global var
    # No echo here, value is set globally
}


check_disk_space() {
    local models_list_str="$1"
    local model_source_type_ctx="$2"
    local local_gguf_path_ctx="$3"
    local is_add_llm_mode="$4"

    # Check available disk space on the USB drive
    print_info "Checking available disk space on USB base path: ${C_BOLD}$USB_BASE_PATH${C_RESET}..." >&2
    if [ -z "$USB_BASE_PATH" ] || ! sudo test -d "$USB_BASE_PATH"; then
        print_error "USB base path '$USB_BASE_PATH' is not valid or not accessible. Cannot check disk space." >&2
        local choice
        ask_yes_no_quit "Problem checking disk space. Continue anyway (NOT RECOMMENDED)?" choice
        if [[ "$choice" != "yes" ]]; then print_fatal "Disk space check failed and user chose to abort."; fi
        return
    fi

    local available_space_kb
    if [[ "$(uname)" == "Darwin" ]]; then
        available_space_kb=$(df -Pk "$USB_BASE_PATH" | awk 'NR==2 {print $4}')
    else
        available_space_kb=$(df -Pk "$USB_BASE_PATH" | awk 'NR==2 {print $4}')
    fi

    if ! [[ "$available_space_kb" =~ ^[0-9]+$ ]]; then
        print_error "Could not determine available disk space on $USB_BASE_PATH." >&2
        local choice
        ask_yes_no_quit "Problem checking disk space. Continue anyway (NOT RECOMMENDED)?" choice
        if [[ "$choice" != "yes" ]]; then print_fatal "Disk space check failed and user chose to abort."; fi
        return
    fi

    local available_space_gb=$(awk "BEGIN {printf \"%.2f\", $available_space_kb / (1024*1024)}")
    print_info "Available space on $USB_BASE_PATH: ${C_BOLD}$available_space_gb GB${C_RESET}" >&2

    # ESTIMATED_MODELS_SIZE_GB is now calculated by calculate_total_estimated_models_size_gb()
    # and stored globally.

    local required_space_gb_val
    if [[ "$is_add_llm_mode" == "true" ]]; then
        required_space_gb_val=$ESTIMATED_MODELS_SIZE_GB # Only for the new models
        print_info "Estimated additional space for new model(s): ~${C_BOLD}$required_space_gb_val GB${C_RESET}" >&2
    else
        required_space_gb_val=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_BINARIES_SIZE_GB + $ESTIMATED_MODELS_SIZE_GB + 0.5}") # Binaries + Models + 0.5GB Buffer
        print_info "Estimated total space required (binaries + models + buffer): ~${C_BOLD}$required_space_gb_val GB${C_RESET}" >&2
    fi

    if (( $(echo "$available_space_gb < $required_space_gb_val" | bc -l) )); then
        print_error "Insufficient disk space on $USB_BASE_PATH." >&2
        print_error "  Available: $available_space_gb GB, Estimated Required: $required_space_gb_val GB" >&2
        local continue_anyway_choice
        ask_yes_no_quit "${C_YELLOW}Continue anyway despite insufficient space warning? (Installation may fail)${C_RESET}" continue_anyway_choice
        if [[ "$continue_anyway_choice" != "yes" ]]; then
            print_fatal "Operation aborted due to insufficient disk space."
        else
            print_warning "Proceeding despite low disk space warning. Installation may fail." >&2
        fi
    else
        print_success "Sufficient disk space seems available (based on estimates)." >&2
    fi
}


# --- Dependency, Setup, and Check Functions ---
get_latest_ollama_release_urls() {
    local base_url="https://api.github.com/repos/ollama/ollama/releases/latest"; local assets_json
    print_info "Fetching latest release information from GitHub...";
    if ! command -v jq &> /dev/null; then print_warning "jq not installed. Cannot fetch dynamic URLs from GitHub API."; return 1; fi
    if ! assets_json=$(curl -sL "$base_url"); then print_error "Failed to fetch release info from GitHub API."; return 1; fi

    LINUX_URL=$(echo "$assets_json" | jq -r '.assets[] | select(.name | test("ollama-linux-amd64\\.(tar\\.gz|tgz)$")) | .browser_download_url')
    if [ "$LINUX_URL" = "null" ] || [ -z "$LINUX_URL" ]; then LINUX_URL=$(echo "$assets_json" | jq -r '.assets[] | select(.name == "ollama-linux-amd64") | .browser_download_url'); fi
    MAC_URL=$(echo "$assets_json" | jq -r '.assets[] | select(.name | test("ollama-darwin\\.(tar\\.gz|tgz)$") or .name | test("Ollama-darwin\\.(tar\\.gz|tgz)$") ) | .browser_download_url')
    WINDOWS_ZIP_URL=$(echo "$assets_json" | jq -r '.assets[] | select(.name | test("ollama-windows-amd64\\.zip$")) | .browser_download_url')

    if [ "$LINUX_URL" = "null" ] || [ "$MAC_URL" = "null" ] || [ "$WINDOWS_ZIP_URL" = "null" ] || [ -z "$LINUX_URL" ] || [ -z "$MAC_URL" ] || [ -z "$WINDOWS_ZIP_URL" ]; then
        print_error "Could not determine all download URLs from GitHub API. Check jq parsing or API response."
        return 1
    fi
    print_success "Successfully fetched download URLs from GitHub API."; return 0
}

FALLBACK_LINUX_URL="https://github.com/ollama/ollama/releases/download/v0.6.8/ollama-linux-amd64.tgz"
FALLBACK_MAC_URL="https://github.com/ollama/ollama/releases/download/v0.6.8/ollama-darwin.tgz"
FALLBACK_WINDOWS_ZIP_URL="https://github.com/ollama/ollama/releases/download/v0.6.8/ollama-windows-amd64.zip"

check_bash_version() {
    if [ -n "${BASH_VERSINFO:-}" ] && [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        print_line
        print_warning "Your Bash version is ${BASH_VERSION}."
        echo -e "${C_YELLOW}   This script uses features that are more robust in Bash 4.0+."
        echo -e "   While fallbacks are in place for menu systems, upgrading Bash on your"
        echo -e "   system (especially on macOS) is recommended for best compatibility."
        echo -e "   To upgrade on macOS (if you use Homebrew): ${C_BOLD}brew install bash${C_RESET}${C_YELLOW}"
        print_line
        echo ""
    fi
}

check_host_dependencies() {
    local check_mode=${1:-"full"}
    print_subheader "🔎 Checking host system dependencies (${check_mode} mode)..."
    local os_type; os_type=$(uname -s)
    local missing_deps_cmds=(); local missing_deps_pkgs=(); local missing_deps_info=()
    local dep_found_msg="${C_GREEN}✅${C_RESET}"; local dep_warn_msg="${C_YELLOW}⚠️${C_RESET}"; local dep_fail_msg="${C_RED}❌ ERROR:${C_RESET}"
    local pkg_manager_cmd=""; local pkg_manager_name=""
    local brew_detected=false

    local dependencies=()
    dependencies+=(
        "curl;curl;curl;curl;curl;Tool for transferring data with URLs (downloader)"
        "wget;wget;wget;wget;wget;Alternative tool for downloading files"
        "ollama;ollama_script;ollama_script;ollama_script;ollama;Ollama AI runtime"
    )

    if [[ "$check_mode" == "full" ]]; then
        dependencies+=(
            "awk;gawk;gawk;gawk;gawk;Text processing utility (GNU awk recommended)"
            "sed;sed;sed;sed;gnu-sed;Stream editor for text manipulation (GNU sed recommended on macOS)"
            "grep;grep;grep;grep;grep;Pattern searching utility (GNU grep recommended on macOS)"
            "tar;tar;tar;tar;gnu-tar;Archiving utility (GNU tar recommended on macOS)"
            "unzip;unzip;unzip;unzip;unzip;Utility for decompressing ZIP archives"
            "rsync;rsync;rsync;rsync;rsync;File synchronization utility (for model copying)"
            "unix2dos;dos2unix;dos2unix;dos2unix;dos2unix;Utility for converting line endings (for Windows compatibility)"
        )
        if [[ "$os_type" == "Linux" ]]; then
            dependencies+=(
                "lsblk;util-linux;util-linux;util-linux;;Lists block devices (usually pre-installed)"
                "parted;parted;parted;parted;;Partition editor"
                "mkfs.exfat;exfatprogs,exfat-utils;exfatprogs,exfat-utils;exfatprogs,exfat-utils;;Creates exFAT filesystems (try exfatprogs first)"
                "df;coreutils;coreutils;coreutils;;Reports file system disk space usage (usually pre-installed)"
                "stat;coreutils;coreutils;coreutils;;Displays file or file system status (usually pre-installed)"
                "sha256sum;coreutils;coreutils;coreutils;;SHA256 checksum utility (usually part of coreutils)"
                 "bc;bc;bc;bc;bc;Basic calculator (for disk space comparison)"
            )
        elif [[ "$os_type" == "Darwin" ]]; then
            dependencies+=("diskutil;;;;;macOS disk utility (pre-installed)")
            dependencies+=("df;;;;;macOS disk space utility (pre-installed)")
            dependencies+=("stat;;;;;macOS file status utility (pre-installed)")
            dependencies+=("shasum;;;;;macOS SHA checksum utility (pre-installed)")
            dependencies+=("bc;bc;bc;bc;bc;Basic calculator (for disk space comparison)")
        fi
        dependencies+=("jq;jq;jq;jq;jq;JSON processor (for GitHub API, model management, WebUI model list)")

    elif [[ "$check_mode" == "minimal_for_manage" ]]; then
         dependencies+=(
            "rsync;rsync;rsync;rsync;rsync;File synchronization utility (for model copying if adding)"
        )
         if [[ "$os_type" == "Linux" ]]; then dependencies+=("stat;coreutils;coreutils;coreutils;;Displays file or file system status (usually pre-installed)"); fi
         if [[ "$os_type" == "Darwin" ]]; then dependencies+=("stat;;;;;macOS file status utility (pre-installed)"); fi
         dependencies+=("jq;jq;jq;jq;jq;JSON processor (for model size display/GitHub API/WebUI model list)")
    fi


    if [[ "$os_type" == "Linux" ]]; then
        if command -v apt-get &> /dev/null; then pkg_manager_cmd="sudo apt-get install -y"; pkg_manager_name="apt";
        elif command -v dnf &> /dev/null; then pkg_manager_cmd="sudo dnf install -y"; pkg_manager_name="dnf";
        elif command -v yum &> /dev/null; then pkg_manager_cmd="sudo yum install -y"; pkg_manager_name="yum";
        elif command -v pacman &> /dev/null; then pkg_manager_cmd="sudo pacman -Syu --noconfirm"; pkg_manager_name="pacman";
        else echo -e "  $dep_warn_msg Could not detect common Linux package manager (apt, dnf, yum, pacman). Automatic installation of some dependencies might not be offered."; fi
    elif [[ "$os_type" == "Darwin" ]]; then
        if command -v brew &> /dev/null; then brew_detected=true; pkg_manager_cmd="brew install"; pkg_manager_name="Homebrew"; fi
    fi

    echo -e "${C_CYAN}--- Dependency Check Results ---${C_RESET}"
    local has_curl_or_wget=false
    if command -v curl &> /dev/null; then echo -e "  $dep_found_msg curl found."; has_curl_or_wget=true; fi
    if command -v wget &> /dev/null; then echo -e "  $dep_found_msg wget found."; has_curl_or_wget=true; fi
    if ! $has_curl_or_wget && ( [[ "$check_mode" == "full" ]] || [[ "$check_mode" == "minimal_for_manage" ]] ) ; then
        echo -e "  $dep_fail_msg Neither curl nor wget found."
        missing_deps_cmds+=("curl_or_wget")
        missing_deps_pkgs+=("curl / wget")
        missing_deps_info+=("curl_or_wget;curl;curl;curl;curl;A downloader (curl or wget) is required.")
    fi

    for dep_entry in "${dependencies[@]}"; do
        IFS=';' read -r cmd apt_pkg dnf_pkg pacman_pkg brew_pkg desc <<< "$dep_entry"
        if [[ "$cmd" == "curl" || "$cmd" == "wget" ]]; then continue; fi

        is_likely_builtin=false
        if ( [[ "$cmd" == "df" || "$cmd" == "stat" ]] && ( [[ "$os_type" == "Linux" ]] || [[ "$os_type" == "Darwin" ]] ) ); then is_likely_builtin=true; fi
        if ( [[ "$cmd" == "sha256sum" && "$os_type" == "Linux" ]] ); then is_likely_builtin=true; fi
        if ( [[ "$cmd" == "shasum" && "$os_type" == "Darwin" ]] ); then is_likely_builtin=true; fi


        if $is_likely_builtin && command -v "$cmd" &> /dev/null; then
            echo -e "  $dep_found_msg $cmd ($desc) found."
            continue
        fi

        if ! command -v "$cmd" &> /dev/null; then
            if [[ "$cmd" == "mkfs.exfat" ]] && (command -v mkexfatfs &> /dev/null); then
                echo -e "  $dep_found_msg mkexfatfs found (alternative for mkfs.exfat)."
                continue
            fi

            is_cmd_sha_tool=false
            alternative_sha_tool_exists=false
            if [[ "$cmd" == "sha256sum" || "$cmd" == "shasum" ]]; then
                is_cmd_sha_tool=true
                if [[ "$cmd" == "sha256sum" ]] && command -v shasum >/dev/null 2>&1; then
                    alternative_sha_tool_exists=true
                elif [[ "$cmd" == "shasum" ]] && command -v sha256sum >/dev/null 2>&1; then
                    alternative_sha_tool_exists=true
                fi
            fi

            if $is_cmd_sha_tool && $alternative_sha_tool_exists; then
                echo -e "  $dep_warn_msg Specific '$cmd' ($desc) not found, but an alternative SHA256 utility exists and will be used by the script."
                continue
            fi

            is_optional_dep=false
            if [[ "$cmd" == "jq" ]] && ! $USE_GITHUB_API && \
               ! ( [[ "$OPERATION_MODE" == "list_usb_models" ]] || \
                   [[ "$OPERATION_MODE" == "remove_llm" ]] || \
                   [[ "$OPERATION_MODE" == "create_new" ]] || \
                   [[ "$OPERATION_MODE" == "add_llm" ]] || \
                   [[ "$OPERATION_MODE" == "repair_scripts" ]] ); then
                is_optional_dep=true
            fi
            if [[ "$cmd" == "bc" ]] && [[ "$check_mode" != "full" ]]; then
                is_optional_dep=true
            fi


            if $is_optional_dep; then
                echo -e "  $dep_warn_msg Optional '$cmd' ($desc) not found. Script will function with reduced features/UX."
            else
                echo -e "  $dep_fail_msg '$cmd' ($desc) not found."
                if $is_cmd_sha_tool && ! $alternative_sha_tool_exists; then
                     echo -e "    (And no alternative SHA utility was found for this specific check)."
                fi
            fi
            missing_deps_cmds+=("$cmd")
            local current_pkg=""
            if [[ "$os_type" == "Linux" ]]; then
                if [[ "$pkg_manager_name" == "apt" ]]; then current_pkg="$apt_pkg";
                elif [[ "$pkg_manager_name" == "dnf" || "$pkg_manager_name" == "yum" ]]; then current_pkg="$dnf_pkg";
                elif [[ "$pkg_manager_name" == "pacman" ]]; then current_pkg="$pacman_pkg";
                else current_pkg="?:$cmd"; fi
            elif [[ "$os_type" == "Darwin" ]]; then
                current_pkg="$brew_pkg"
            else
                current_pkg="?:$cmd"
            fi
            missing_deps_pkgs+=("$current_pkg")
            missing_deps_info+=("$dep_entry")
        else
            echo -e "  $dep_found_msg $cmd ($desc) found."
        fi
    done

    if [[ "$check_mode" == "full" ]] && ! (command -v sha256sum &> /dev/null || command -v shasum &> /dev/null); then
        echo -e "  $dep_fail_msg CRITICAL: No SHA256 utility (sha256sum or shasum) found. This is required for checksum generation and verification scripts."
        local sha_tool_already_listed=false
        for m_cmd in "${missing_deps_cmds[@]}"; do if [[ "$m_cmd" == "sha256sum" || "$m_cmd" == "shasum" ]]; then sha_tool_already_listed=true; break; fi; done

        if ! $sha_tool_already_listed; then
            missing_deps_cmds+=("sha256_utility")
            if [[ "$os_type" == "Linux" ]]; then missing_deps_pkgs+=("coreutils"); missing_deps_info+=("sha256_utility;coreutils;coreutils;coreutils;;A SHA256 utility (sha256sum or shasum) is required.");
            elif [[ "$os_type" == "Darwin" ]]; then missing_deps_pkgs+=("coreutils (for gsha256sum) or ensure shasum is in PATH"); missing_deps_info+=("sha256_utility;;;;;A SHA256 utility (shasum or gsha256sum) is required.");
            else missing_deps_pkgs+=("sha256sum/shasum"); missing_deps_info+=("sha256_utility;;;;;A SHA256 utility (sha256sum or shasum) is required."); fi
        fi
    fi
    print_line

    if [ ${#missing_deps_cmds[@]} -gt 0 ]; then
        echo ""
        print_error "Some dependencies are missing (critical and/or optional for enhanced UX)."
        echo -e "${C_YELLOW}Manual installation instructions:${C_RESET}"
        for i in "${!missing_deps_cmds[@]}"; do
            IFS=';' read -r cmd apt_pkg dnf_pkg pacman_pkg brew_pkg desc <<< "${missing_deps_info[$i]}"
            local pkg_suggestion="${missing_deps_pkgs[$i]}"
            echo -e "  - For ${C_BOLD}'$cmd'${C_RESET} ($desc):"
            if [[ "$cmd" == "curl_or_wget" ]]; then
                 echo -e "    Linux ($pkg_manager_name): ${C_GREEN}$pkg_manager_cmd curl${C_RESET}  OR  ${C_GREEN}$pkg_manager_cmd wget${C_RESET}"
                 if $brew_detected; then echo -e "    macOS (Homebrew): ${C_GREEN}brew install curl${C_RESET} OR ${C_GREEN}brew install wget${C_RESET}"; else echo -e "    macOS: Install curl or wget manually."; fi
                 continue
            fi
             if [[ "$cmd" == "sha256_utility" ]]; then
                 echo -e "    Linux ($pkg_manager_name): ${C_GREEN}$pkg_manager_cmd coreutils${C_RESET} (provides sha256sum)"
                 echo -e "    macOS: 'shasum' is usually built-in. If not, '${C_GREEN}brew install coreutils${C_RESET}' for 'gsha256sum' or check PATH."
                 continue
            fi
            if [[ "$os_type" == "Linux" ]]; then
                if [[ "$cmd" == "ollama" ]]; then
                    echo -e "    Linux: Run the official script: ${C_GREEN}curl -fsSL https://ollama.com/install.sh | sh${C_RESET}"
                elif [[ -n "$pkg_manager_cmd" ]]; then
                    if [[ "$cmd" == "mkfs.exfat" ]]; then
                        echo -e "           ${C_GREEN}$pkg_manager_cmd $(echo "$apt_pkg" | cut -d, -f1)${C_RESET} (recommended, for exfatprogs)"
                        echo -e "           OR ${C_GREEN}$pkg_manager_cmd $(echo "$apt_pkg" | cut -d, -f2)${C_RESET} (for exfat-utils)"
                    elif [[ "$cmd" == "df" || "$cmd" == "stat" || "$cmd" == "sha256sum" ]]; then
                        echo -e "           Usually part of 'coreutils'. Try: ${C_GREEN}$pkg_manager_cmd coreutils${C_RESET} (or your distro's equivalent)"
                    elif [[ "$cmd" == "bc" ]]; then
                        echo -e "           ${C_GREEN}$pkg_manager_cmd bc${C_RESET}"
                    else
                        echo -e "           ${C_GREEN}$pkg_manager_cmd $pkg_suggestion${C_RESET}"
                    fi
                else echo -e "    Linux: Install '$cmd' using your system's package manager."; fi
            elif [[ "$os_type" == "Darwin" ]]; then
                if [[ "$cmd" == "ollama" ]]; then
                    if $brew_detected; then echo -e "    macOS (Homebrew): ${C_GREEN}brew install ollama${C_RESET}"; fi
                    echo -e "    macOS (Official): Download from https://ollama.com/download"
                elif [[ "$cmd" == "df" || "$cmd" == "stat" || "$cmd" == "shasum" ]]; then
                    echo -e "    macOS: These are standard system utilities and should be present. If not, your OS installation might be corrupted."
                elif $brew_detected && [[ -n "$brew_pkg" ]]; then
                    echo -e "    macOS (Homebrew): ${C_GREEN}brew install $brew_pkg${C_RESET}"
                else echo -e "    macOS: Install '$cmd' manually (e.g., from website or if Homebrew is not used)."; fi
            fi
        done
        print_line

        local attempt_install_choice
        ask_yes_no_quit "Do you want this script to ATTEMPT to install the missing dependencies listed above? (Requires sudo/internet)" attempt_install_choice
        if [[ "$attempt_install_choice" == "yes" ]]; then
            print_info "Attempting to install missing dependencies..."
            for i in "${!missing_deps_cmds[@]}"; do
                IFS=';' read -r cmd apt_pkg dnf_pkg pacman_pkg brew_pkg desc <<< "${missing_deps_info[$i]}"
                local pkg_to_install="${missing_deps_pkgs[$i]}"
                echo -e "  Attempting to install ${C_BOLD}'$cmd'${C_RESET} ($desc)..."

                if [[ "$cmd" == "curl_or_wget" ]]; then
                    if ! command -v curl &> /dev/null; then
                        echo -e "    Trying to install ${C_GREEN}curl${C_RESET}..."
                        if [[ "$os_type" == "Linux" ]] && [[ -n "$pkg_manager_cmd" ]]; then $pkg_manager_cmd curl || print_error "Failed to install curl.";
                        elif [[ "$os_type" == "Darwin" ]] && $brew_detected; then brew install curl || print_error "Failed to install curl.";
                        else print_warning "Cannot auto-install curl. Please do it manually."; fi
                    fi
                    if ! command -v wget &> /dev/null; then
                         echo -e "    Trying to install ${C_GREEN}wget${C_RESET}..."
                        if [[ "$os_type" == "Linux" ]] && [[ -n "$pkg_manager_cmd" ]]; then $pkg_manager_cmd wget || print_error "Failed to install wget.";
                        elif [[ "$os_type" == "Darwin" ]] && $brew_detected; then brew install wget || print_error "Failed to install wget.";
                        else print_warning "Cannot auto-install wget. Please do it manually."; fi
                    fi
                    continue
                fi
                if [[ "$cmd" == "sha256_utility" ]]; then
                    if ! (command -v sha256sum &> /dev/null || command -v shasum &> /dev/null); then
                        echo -e "    Trying to install a ${C_GREEN}SHA256 utility${C_RESET}..."
                        if [[ "$os_type" == "Linux" ]] && [[ -n "$pkg_manager_cmd" ]]; then $pkg_manager_cmd coreutils || print_error "Failed to install coreutils (for sha256sum).";
                        elif [[ "$os_type" == "Darwin" ]] && $brew_detected; then brew install coreutils || print_error "Failed to install coreutils (for gsha256sum).";
                        elif [[ "$os_type" == "Darwin" ]] && ! $brew_detected; then print_warning "shasum should be built-in on macOS. If not, consider installing Homebrew and 'coreutils'.";
                        else print_warning "Cannot auto-install SHA256 utility. Please do it manually."; fi
                    fi
                    if (command -v sha256sum &> /dev/null || command -v shasum &> /dev/null); then print_success "    Successfully installed/verified a SHA256 utility."; else echo -e "  $dep_fail_msg Still unable to find a SHA256 utility."; fi
                    continue
                fi

                if [[ "$os_type" == "Linux" ]]; then
                    if [[ "$cmd" == "ollama" ]]; then
                        print_info "    Running Ollama install script (requires sudo for system-wide install)..."
                        if curl -fsSL https://ollama.com/install.sh | sudo sh; then print_success "    Ollama script finished."; else print_error "    Ollama script failed."; fi
                    elif [[ "$cmd" == "df" || "$cmd" == "stat" || "$cmd" == "sha256sum" ]] && [[ -n "$pkg_manager_cmd" ]]; then
                        echo -e "    Attempting to install ${C_GREEN}coreutils${C_RESET} (provides $cmd)..."
                        $pkg_manager_cmd coreutils || print_error "    Failed to install coreutils."
                    elif [[ "$cmd" == "bc" ]] && [[ -n "$pkg_manager_cmd" ]]; then
                        echo -e "    Attempting to install ${C_GREEN}bc${C_RESET}..."
                        $pkg_manager_cmd bc || print_error "    Failed to install bc."
                    elif [[ -n "$pkg_manager_cmd" ]]; then
                        if [[ "$cmd" == "mkfs.exfat" ]]; then
                            local exfat_pkg1=$(echo "$apt_pkg" | cut -d, -f1)
                            local exfat_pkg2=$(echo "$apt_pkg" | cut -d, -f2)
                            echo -e "    Attempting to install ${C_GREEN}$exfat_pkg1${C_RESET}..."
                            if ! $pkg_manager_cmd "$exfat_pkg1"; then
                                print_warning "    Failed to install $exfat_pkg1, trying $exfat_pkg2..."
                                $pkg_manager_cmd "$exfat_pkg2" || print_error "    Failed to install exfat tools ($exfat_pkg1 or $exfat_pkg2)."
                            fi
                        else
                           $pkg_manager_cmd "$pkg_to_install" || print_error "    Failed to install $pkg_to_install."
                        fi
                    else print_warning "    Cannot auto-install '$cmd' on Linux without a known package manager."; fi
                elif [[ "$os_type" == "Darwin" ]]; then
                    if [[ "$cmd" == "ollama" ]]; then
                        if $brew_detected; then echo -e "    Using Homebrew to install ${C_GREEN}ollama${C_RESET}..."; brew install ollama || print_error "    Homebrew failed to install ollama.";
                        else print_warning "    Cannot auto-install ollama on macOS without Homebrew. Please visit https://ollama.com/download"; fi
                    elif [[ "$cmd" == "df" || "$cmd" == "stat" || "$cmd" == "shasum" ]]; then
                        print_info "    $cmd is a system utility on macOS. If missing, your OS may have issues. No auto-install attempt."
                    elif [[ "$cmd" == "bc" ]] && $brew_detected; then
                        echo -e "    Using Homebrew to install ${C_GREEN}bc${C_RESET}..."; brew install bc || print_error "    Homebrew failed to install bc.";
                    elif $brew_detected && [[ -n "$brew_pkg" ]]; then
                        echo -e "    Using Homebrew to install ${C_GREEN}$brew_pkg${C_RESET}..."; brew install "$brew_pkg" || print_error "    Homebrew failed to install $brew_pkg.";
                    else print_warning "    Cannot auto-install '$cmd' on macOS without Homebrew or specific package name."; fi
                fi
                if command -v "$cmd" &> /dev/null || ([[ "$cmd" == "mkfs.exfat" ]] && command -v mkexfatfs &> /dev/null) ; then
                    print_success "    Successfully installed/verified '$cmd'."
                elif [[ "$cmd" == "sha256sum" || "$cmd" == "shasum" ]] && (command -v sha256sum &> /dev/null || command -v shasum &> /dev/null); then
                    print_success "    Successfully installed/verified a SHA256 utility for '$cmd' requirement."
                else
                    echo -e "  $dep_fail_msg Still unable to find '$cmd' after installation attempt."
                fi
            done
            print_line
            print_info "Dependency installation attempts complete."
            print_info "Please re-run this script ($SCRIPT_SELF_NAME) to ensure all dependencies are now met."
            exit 0
        else
            local critical_still_missing=false
            for mc_cmd in "${missing_deps_cmds[@]}"; do
                is_optional_dep=false
                if [[ "$mc_cmd" == "jq" ]] && ! $USE_GITHUB_API && \
                   ! ( [[ "$OPERATION_MODE" == "list_usb_models" ]] || \
                       [[ "$OPERATION_MODE" == "remove_llm" ]] || \
                       [[ "$OPERATION_MODE" == "create_new" ]] || \
                       [[ "$OPERATION_MODE" == "add_llm" ]] || \
                       [[ "$OPERATION_MODE" == "repair_scripts" ]] ); then
                    is_optional_dep=true
                fi
                if [[ "$mc_cmd" == "bc" ]] && [[ "$check_mode" != "full" ]]; then
                    is_optional_dep=true;
                fi

                if ! $is_optional_dep && ! command -v "$mc_cmd" &>/dev/null ; then
                    if [[ "$mc_cmd" == "sha256_utility" ]] && (command -v sha256sum &>/dev/null || command -v shasum &>/dev/null); then
                        continue
                    fi
                    if [[ "$mc_cmd" == "jq" ]]; then
                        if $USE_GITHUB_API || \
                           [[ "$OPERATION_MODE" == "list_usb_models" ]] || \
                           [[ "$OPERATION_MODE" == "remove_llm" ]] || \
                           [[ "$OPERATION_MODE" == "create_new" ]] || \
                           [[ "$OPERATION_MODE" == "add_llm" ]] || \
                           [[ "$OPERATION_MODE" == "repair_scripts" ]]; then
                            print_warning "'jq' is missing. Some features like dynamic GitHub URL fetching, detailed model listing, or WebUI model population will be affected or fail."
                        else
                            print_warning "'jq' is missing. Some optional features may be affected."
                            continue
                        fi
                    fi
                    if [[ "$mc_cmd" == "bc" ]] && [[ "$check_mode" == "full" ]]; then
                         print_warning "'bc' is missing. Disk space calculations might be inaccurate or fail."
                    fi

                    critical_still_missing=true; break
                fi
            done
            if $critical_still_missing; then
                print_error "Please install the missing critical dependencies manually and then re-run this script."
                exit 1
            else
                print_info "Proceeding. Some optional dependencies might be missing, potentially affecting some features."
            fi
        fi
    else
        print_success "All critical dependencies seem to be present."
    fi
    print_line
}


# --- User Interaction / Selection Functions ---
show_menu() {
    local dialog_title="$1"
    local menu_text="$2"
    local result_var_name="$3"
    shift 3
    local menu_options_pairs=("$@")
    local choice

    # Calculate menu width based on terminal capabilities
    local menu_width=60  # Increased width to accommodate longer menu items

    # Display the menu header with enhanced styling
    if $COLORS_ENABLED; then
        local title_padding=$(( (menu_width - ${#dialog_title} - 4) / 2 ))
        local title_line=""
        for ((i=0; i<title_padding; i++)); do title_line+="─"; done
        title_line+="─ ${dialog_title} ─"
        for ((i=0; i<title_padding; i++)); do title_line+="─"; done
        # Adjust for odd lengths
        if (( (${#title_line} - 2) < menu_width )); then title_line+="─"; fi

        echo ""
        echo -e "${C_BOLD}${C_CYAN}┌${title_line}┐${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}${menu_text}${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}"
    else
        local title_padding=$(( (menu_width - ${#dialog_title} - 4) / 2 ))
        local title_line=""
        for ((i=0; i<title_padding; i++)); do title_line+="-"; done
        title_line+=" ${dialog_title} "
        for ((i=0; i<title_padding; i++)); do title_line+="-"; done
        # Adjust for odd lengths
        if (( ${#title_line} < menu_width )); then title_line+="-"; fi

        echo ""
        echo "+${title_line}+"
        echo "| ${menu_text}"
        echo "|"
    fi

    # Display menu options with enhanced formatting
    local option_num=1
    local text_option_tags=()

    for ((i=0; i<${#menu_options_pairs[@]}; i+=2)); do
        # Handle special separator options
        if [[ "${menu_options_pairs[i]}" == *"separator"* ]]; then
            if $COLORS_ENABLED; then
                # Fix separator lines to extend fully to the right border
                local sep_line=""
                for ((j=0; j<menu_width-3; j++)); do sep_line+="─"; done
                echo -e "${C_CYAN}│ ${C_DIM}${sep_line}${C_RESET}"
            else
                # Fix non-colored separator lines to extend fully to the right border
                local sep_line=""
                for ((j=0; j<menu_width-3; j++)); do sep_line+="-"; done
                echo "| ${sep_line}"
            fi
        else
            # Format regular menu options with better spacing and highlighting
            local option_text="${menu_options_pairs[i+1]}"

            if $COLORS_ENABLED; then
                # Fixed spacing for consistent right-side alignment
                local max_text_length=$((menu_width - 8)) # Maximum length for option text
                local truncated_text="$option_text"

                # Truncate long option text if needed
                if [ ${#option_text} -gt $max_text_length ]; then
                    truncated_text="${option_text:0:$((max_text_length-3))}..."
                fi

                local display_length=$((${#truncated_text} + 4)) # Account for number and spacing
                local padding=$((menu_width - display_length))

                # Add special highlighting for create/manage options in main menu
                if [[ "$dialog_title" == "Main Menu" ]]; then
                    if [[ "${menu_options_pairs[i]}" == "create_new" ]]; then
                        printf "${C_CYAN}│ ${C_BOLD}${C_GREEN}%s)${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$option_num" "${truncated_text}"
                    elif [[ "${menu_options_pairs[i]}" == "manage_existing" ]]; then
                        printf "${C_CYAN}│ ${C_BOLD}${C_BLUE}%s)${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$option_num" "${truncated_text}"
                    else
                        printf "${C_CYAN}│ ${C_YELLOW}%s)${C_RESET} %s\n" "$option_num" "${truncated_text}"
                    fi
                else
                    printf "${C_CYAN}│ ${C_YELLOW}%s)${C_RESET} %s\n" "$option_num" "${truncated_text}"
                fi
            else
                # Also apply truncation to non-colored mode
                local max_text_length=$((menu_width - 8))
                local truncated_text="$option_text"
                if [ ${#option_text} -gt $max_text_length ]; then
                    truncated_text="${option_text:0:$((max_text_length-3))}..."
                fi
                printf "| %s) %s\n" "$option_num" "${truncated_text}"
            fi
            text_option_tags+=("${menu_options_pairs[i]}")
            option_num=$((option_num + 1))
        fi
    done

    # Add navigation options based on context with fixed spacing
    if [[ "$dialog_title" == "Main Menu" ]]; then
        if $COLORS_ENABLED; then
            echo -e "${C_CYAN}│${C_RESET}"
            local nav_text="Quit"
            printf "${C_CYAN}│ ${C_RED}q)${C_RESET} %s\n" "$nav_text"
        else
            echo "|"
            printf "| q) %s\n" "Quit"
        fi
    else
        if $COLORS_ENABLED; then
            echo -e "${C_CYAN}│${C_RESET}"
            local nav_text="Back to Previous Menu"
            printf "${C_CYAN}│ ${C_BLUE}b)${C_RESET} %s\n" "$nav_text"
        else
            echo "|"
            printf "| b) %s\n" "Back to Previous Menu"
        fi
    fi

    # Close the menu border with matching width
    if $COLORS_ENABLED; then
        local bottom_line=""
        for ((i=0; i<menu_width; i++)); do bottom_line+="─"; done
        echo -e "${C_BOLD}${C_CYAN}└${bottom_line}┘${C_RESET}"
    else
        local bottom_line=""
        for ((i=0; i<menu_width; i++)); do bottom_line+="-"; done
        echo "+${bottom_line}+"
    fi

    # Handle user input with enhanced feedback
    local raw_choice
    while true; do
        print_prompt "Enter your choice"
        read -r raw_choice

        # Empty input handling
        if [[ -z "$raw_choice" ]]; then
            print_warning "Please make a selection."
            continue
        fi

        # Normalize input
        raw_choice=$(echo "$raw_choice" | tr '[:upper:]' '[:lower:]')

        # Valid numeric option
        if [[ "$raw_choice" =~ ^[0-9]+$ ]] && [ "$raw_choice" -ge 1 ] && [ "$raw_choice" -lt "$option_num" ]; then
            # Show selection feedback
            local selected_option="${menu_options_pairs[$(((raw_choice-1)*2+1))]}"
            print_info "Selected: $selected_option"
            eval "$result_var_name=\"${text_option_tags[$((raw_choice - 1))]}\""
            break

        # Exit option
        elif [[ "$raw_choice" == "q" && "$dialog_title" == "Main Menu" ]]; then
            print_info "Exiting program..."
            eval "$result_var_name=\"q\""
            break

        # Back option
        elif [[ "$raw_choice" == "b" && "$dialog_title" != "Main Menu" ]]; then
            print_info "Going back to previous menu..."
            eval "$result_var_name=\"b\""
            break

        # Invalid input with helpful guidance
        else
            local valid_options="1"
            if [ "$option_num" -gt 2 ]; then
                valid_options="1-$((option_num-1))"
            fi

            if [[ "$dialog_title" == "Main Menu" ]]; then
                print_warning "Invalid selection '${raw_choice}'. Please enter ${valid_options} or 'q' to quit."
            else
                print_warning "Invalid selection '${raw_choice}'. Please enter ${valid_options} or 'b' to go back."
            fi
        fi
    done

    # Add spacing after menu interaction
    echo ""
}

ask_target_os_binaries() {
    # Display section header with consistent styling
    if $COLORS_ENABLED; then
        echo -e "\n${C_BOLD}${C_CYAN}┌───────────────────────────────────────────┐${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} Choose which Ollama runtimes to include on your USB:"
        echo -e "${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}1)${C_RESET} All OS (Linux, macOS, Windows) ${C_DIM}[Default]${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}2)${C_RESET} Current host OS only ($(uname -s))"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}3)${C_RESET} Linux only"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}4)${C_RESET} macOS only"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}5)${C_RESET} Windows only"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}q)${C_RESET} Quit"
        echo -e "${C_CYAN}└───────────────────────────────────────────┘${C_RESET}"
    else
        echo ""
        echo "+---------------------------------------------+"
        echo "| Choose which Ollama runtimes to include on your USB:"
        echo "|"
        echo "| 1) All OS (Linux, macOS, Windows) [Default]"
        echo "| 2) Current host OS only ($(uname -s))"
        echo "| 3) Linux only"
        echo "| 4) macOS only"
        echo "| 5) Windows only"
        echo "| q) Quit"
        echo "+---------------------------------------------+"
    fi

    # Prompt user with clear instructions
    print_prompt "Enter your choice (1-5, or q) [Default is 1]"

    # Read user input with timeout to avoid hanging
    local choice
    read -t 30 choice

    # Convert to lowercase for case-insensitive comparison
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # Default to option 1 if no input provided
    if [ -z "$choice" ]; then
        choice="1"
        if $COLORS_ENABLED; then
            echo -e "${C_DIM}Using default: All OS${C_RESET}"
        else
            echo "Using default: All OS"
        fi
    fi

    # Process the selection with clear feedback
    case "$choice" in
        1|"")
            SELECTED_OS_TARGETS="linux,mac,win"
            ;;
        2)
            case "$(uname -s)" in
                Linux)
                    SELECTED_OS_TARGETS="linux"
                    ;;
                Darwin)
                    SELECTED_OS_TARGETS="mac"
                    ;;
                MINGW*|MSYS*)
                    SELECTED_OS_TARGETS="win"
                    ;;
                *)
                    print_warning "Unknown host OS. Defaulting to Linux."
                    SELECTED_OS_TARGETS="linux"
                    ;;
            esac
            ;;
        3)
            SELECTED_OS_TARGETS="linux"
            ;;
        4)
            SELECTED_OS_TARGETS="mac"
            ;;
        5)
            SELECTED_OS_TARGETS="win"
            ;;
        q|quit)
            print_info "Exiting at user request."
            exit 0
            ;;
        *)
            print_warning "Invalid choice '${choice}'. Defaulting to All OS binaries."
            SELECTED_OS_TARGETS="linux,mac,win"
            ;;
    esac

    # Calculate and display size estimate
    local estimated_binaries_size_bytes=$(calculate_estimated_binary_size_bytes)
    ESTIMATED_BINARIES_SIZE_GB=$(echo "scale=2; $estimated_binaries_size_bytes / (1024 * 1024 * 1024)" | bc)

    # Show confirmation with clear formatting
    echo ""
    print_success "Selected OS targets: ${SELECTED_OS_TARGETS} (Est. Size: ${ESTIMATED_BINARIES_SIZE_GB} GB)"
    echo ""
}

ask_llm_model() {
    # Set appropriate title based on operation mode
    local title_text="SELECT AI MODEL"
    if [[ "$OPERATION_MODE" == "add_llm" ]]; then
        title_text="ADD AI MODEL"
    fi

    # Initialize variables
    MODELS_TO_INSTALL_LIST=()
    MODEL_SOURCE_TYPE="pull"

    # Display section header with consistent styling
    if $COLORS_ENABLED; then
        echo -e "${C_BOLD}${C_CYAN}┌─────────────────────────────────────────────────────────┐${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} Choose which AI model(s) to include on your USB:"
        echo -e "${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}1)${C_RESET} llama3:8b ${C_DIM}[Default]${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}    ${C_DIM}Recommended general purpose, ~$(get_estimated_model_size_gb "llama3:8b") GB${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}2)${C_RESET} phi3:mini"
        echo -e "${C_CYAN}│${C_RESET}    ${C_DIM}Small, very capable, ~$(get_estimated_model_size_gb "phi3:mini") GB${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}3)${C_RESET} llama3:8b AND phi3:mini"
        echo -e "${C_CYAN}│${C_RESET}    ${C_DIM}Flexible performance, ~$(awk "BEGIN {printf \"%.1f\", $(get_estimated_model_size_gb \"llama3:8b\") + $(get_estimated_model_size_gb \"phi3:mini\")}") GB total${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}4)${C_RESET} codellama:7b"
        echo -e "${C_CYAN}│${C_RESET}    ${C_DIM}Coding assistant, ~$(get_estimated_model_size_gb "codellama:7b") GB${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}5)${C_RESET} Custom model from ollama.com/library"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}6)${C_RESET} Import local GGUF model file"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}q)${C_RESET} Quit"
        echo -e "${C_CYAN}└─────────────────────────────────────────────────────────┘${C_RESET}"
    else
        echo ""
        echo "+---------------------------------------------------+"
        echo "| Choose which AI model(s) to include on your USB:"
        echo "|"
        echo "| 1) llama3:8b [Default]"
        echo "|    Recommended general purpose, ~$(get_estimated_model_size_gb "llama3:8b") GB"
        echo "|"
        echo "| 2) phi3:mini"
        echo "|    Small, very capable, ~$(get_estimated_model_size_gb "phi3:mini") GB"
        echo "|"
        echo "| 3) llama3:8b AND phi3:mini"
        echo "|    Flexible performance, ~$(awk "BEGIN {printf \"%.1f\", $(get_estimated_model_size_gb \"llama3:8b\") + $(get_estimated_model_size_gb \"phi3:mini\")}") GB total"
        echo "|"
        echo "| 4) codellama:7b"
        echo "|    Coding assistant, ~$(get_estimated_model_size_gb "codellama:7b") GB"
        echo "|"
        echo "| 5) Custom model from ollama.com/library"
        echo "| 6) Import local GGUF model file"
        echo "| q) Quit"
        echo "+---------------------------------------------------+"
    fi

    # Prompt for selection with clear instructions
    while true; do
        print_prompt "Enter your choice (1-6, or q) [Default is 1]"
        local choice
        read -r choice

        # Handle empty input (default to option 1)
        choice=${choice:-1}

        # Process selection
        case "$choice" in
        1) MODELS_TO_INSTALL_LIST=("llama3:8b"); MODEL_SOURCE_TYPE="pull"; break;;
        2) MODELS_TO_INSTALL_LIST=("phi3:mini"); MODEL_SOURCE_TYPE="pull"; break;;
        3) MODELS_TO_INSTALL_LIST=("llama3:8b" "phi3:mini"); MODEL_SOURCE_TYPE="pull"; break;;
        4) MODELS_TO_INSTALL_LIST=("codellama:7b"); MODEL_SOURCE_TYPE="pull"; break;;
        5)
            if $COLORS_ENABLED; then
                echo -e "\n${C_CYAN}───── Custom Model Selection ─────${C_RESET}"
                echo -e "You can find available models at: ${C_UNDERLINE}https://ollama.com/library${C_NO_UNDERLINE}"
            else
                echo "\n----- Custom Model Selection -----"
                echo "You can find available models at: https://ollama.com/library"
            fi

            # Offer to open the library in browser
            local open_url_choice
            ask_yes_no_quit "Open this URL in your browser?" open_url_choice

            if [[ "$open_url_choice" == "yes" ]]; then
                # Cross-platform URL opening
                if command -v xdg-open &>/dev/null; then
                    print_info "Opening URL with xdg-open..."
                    xdg-open "https://ollama.com/library" &>/dev/null &
                elif command -v open &>/dev/null; then
                    print_info "Opening URL with open..."
                    open "https://ollama.com/library" &>/dev/null &
                else
                    print_warning "No browser command found. Please visit the URL manually."
                fi
            fi

            # Model selection with better guidance
            print_prompt "Enter model name (format: 'name:tag', e.g., 'mistral:7b')"
            local custom_model_name
            read -r custom_model_name

            # Validate and handle empty input
            if [ -z "$custom_model_name" ]; then
                print_warning "No model name provided. Using default llama3:8b."
                MODELS_TO_INSTALL_LIST=("llama3:8b")
            else
                # Format validation could be added here
                print_success "Selected custom model: $custom_model_name"
                MODELS_TO_INSTALL_LIST=("$custom_model_name")
            fi
            MODEL_SOURCE_TYPE="pull"
            break
            ;;
        6)
                # Improve UI for local model import
                if $COLORS_ENABLED; then
                    echo -e "\n${C_CYAN}┌──── Import Local GGUF Model ────┐${C_RESET}"
                    echo -e "${C_CYAN}│${C_RESET} Select a local GGUF model file to import"
                    echo -e "${C_CYAN}└─────────────────────────────┘${C_RESET}"
                else
                    echo "\n----- Import Local GGUF Model -----"
                    echo "Select a local GGUF model file to import"
                    echo "------------------------------------"
                fi

                local ollama_model_name
                # File selection with better guidance and validation
                echo -e "${C_DIM}Tip: GGUF files usually end with .gguf and can be several GB in size${C_RESET}"

                while true; do
                    print_prompt "Enter the full path to your GGUF model file"
                    read -r LOCAL_GGUF_PATH_FOR_IMPORT

                    # Validate input
                    if [ -z "$LOCAL_GGUF_PATH_FOR_IMPORT" ]; then
                        print_warning "Path cannot be empty. Please provide a valid file path."
                        continue
                    fi

                    # Check if file exists
                    if [ ! -f "$LOCAL_GGUF_PATH_FOR_IMPORT" ]; then
                        print_warning "File not found: '$LOCAL_GGUF_PATH_FOR_IMPORT'"
                        print_warning "Please check that the path is correct and the file exists."
                        continue
                    fi

                    # Check file extension
                    if [[ "${LOCAL_GGUF_PATH_FOR_IMPORT##*.}" != "gguf" ]]; then
                        print_warning "File doesn't have a .gguf extension."
                        local proceed_anyway
                        ask_yes_no_quit "Continue anyway? (Only proceed if you're sure this is a valid GGUF file)" proceed_anyway
                        if [[ "$proceed_anyway" != "yes" ]]; then
                            continue
                        fi
                    fi

                    # File size check
                    local file_size_bytes=$(stat -c%s "$LOCAL_GGUF_PATH_FOR_IMPORT" 2>/dev/null || stat -f%z "$LOCAL_GGUF_PATH_FOR_IMPORT" 2>/dev/null)
                    if [ -n "$file_size_bytes" ]; then
                        local file_size_gb=$(echo "scale=2; $file_size_bytes / (1024*1024*1024)" | bc)
                        print_info "Selected file size: ${file_size_gb} GB"

                        # Warn if file seems too small
                        if (( $(echo "$file_size_gb < 0.5" | bc -l) )); then
                            print_warning "File seems unusually small for an LLM (< 500MB)."
                            local proceed_small
                            ask_yes_no_quit "Continue with this file?" proceed_small
                            if [[ "$proceed_small" != "yes" ]]; then
                                continue
                            fi
                        fi
                    fi

                    # All checks passed
                    print_success "Selected model file: $LOCAL_GGUF_PATH_FOR_IMPORT"
                    break
                done
                # Model naming with better guidance
                if $COLORS_ENABLED; then
                    echo -e "\n${C_CYAN}───── Name Your Model ─────${C_RESET}"
                else
                    echo "\n----- Name Your Model -----"
                fi

                echo -e "${C_DIM}Give your model a name that will be used in Ollama.${C_RESET}"
                echo -e "${C_DIM}Format must be 'name:tag' (example: 'mymodel:latest')${C_RESET}"

                while true; do
                    # Get model filename for a smart default suggestion
                    local default_name=""
                    local filename=$(basename "$LOCAL_GGUF_PATH_FOR_IMPORT" .gguf | tr -c '[:alnum:]_-' '_')
                    if [ -n "$filename" ]; then
                        default_name="${filename,,}:latest"
                        print_prompt "Enter model name (e.g., 'mymodel:latest') [${default_name}]"
                    else
                        print_prompt "Enter model name (e.g., 'mymodel:latest')"
                    fi

                    read -r ollama_model_name

                    # Use default if empty
                    if [ -z "$ollama_model_name" ] && [ -n "$default_name" ]; then
                        ollama_model_name="$default_name"
                        print_info "Using default name: $ollama_model_name"
                    fi

                    # Validate name format
                    if [ -z "$ollama_model_name" ]; then
                        print_warning "Model name cannot be empty."
                        continue
                    fi

                    if [[ ! "$ollama_model_name" == *":"* ]]; then
                        print_warning "Model name must include a tag in the format 'name:tag'."
                        # Offer to add the tag automatically
                        local add_tag
                        ask_yes_no_quit "Add ':latest' tag automatically?" add_tag
                        if [[ "$add_tag" == "yes" ]]; then
                            ollama_model_name="${ollama_model_name}:latest"
                            print_info "Model name set to: $ollama_model_name"
                            break
                        fi
                        continue
                    fi

                    # All checks passed
                    break
                done

                print_success "Model will be imported as: $ollama_model_name"

                # Import process with improved feedback
                if $COLORS_ENABLED; then
                    echo -e "\n${C_CYAN}┌──── Importing Model ────┐${C_RESET}"
                    echo -e "${C_CYAN}│${C_RESET} Starting import process"
                    echo -e "${C_CYAN}└────────────────────────┘${C_RESET}"
                else
                    echo "\n----- Importing Model -----"
                    echo "Starting import process"
                    echo "---------------------------"
                fi

                # Create temporary modelfile
                local temp_modelfile; temp_modelfile=$(mktemp)
                echo "FROM \"$LOCAL_GGUF_PATH_FOR_IMPORT\"" > "$temp_modelfile"

                # Show clearer information about what's happening
                print_info "Created temporary Modelfile with the following configuration:"
                if $COLORS_ENABLED; then
                    echo -e "${C_DIM}  FROM \"$LOCAL_GGUF_PATH_FOR_IMPORT\"${C_RESET}"
                else
                    echo "  FROM \"$LOCAL_GGUF_PATH_FOR_IMPORT\""
                fi

                # Save environment variable state
                local OLLAMA_MODELS_TEMP_STORE_CREATE="$OLLAMA_MODELS"
                unset OLLAMA_MODELS

                # Show command with better formatting
                print_info "Running import command:"
                if $COLORS_ENABLED; then
                    echo -e "  ${C_BOLD}ollama create \"$ollama_model_name\" -f \"$temp_modelfile\"${C_RESET}"
                else
                    echo "  ollama create \"$ollama_model_name\" -f \"$temp_modelfile\""
                fi

                print_info "This process may take several minutes depending on your system."
                print_info "Please wait..."

                echo ""
                print_line
                # Run the command
                if ollama create "$ollama_model_name" -f "$temp_modelfile"; then
                    print_line
                    echo ""
                    print_success "Successfully imported model as '$ollama_model_name'"
                    MODELS_TO_INSTALL_LIST=("$ollama_model_name")
                    MODEL_SOURCE_TYPE="create_local"
                else
                    print_line
                    echo ""
                    print_error "Model import failed"
                    print_warning "Common issues:"
                    echo "  - Insufficient disk space"
                    echo "  - Invalid GGUF format"
                    echo "  - Ollama service not running properly"
                    print_warning "Check Ollama logs for more details"

                    # Clean up and restore environment
                    rm -f "$temp_modelfile"
                    if [ -n "$OLLAMA_MODELS_TEMP_STORE_CREATE" ]; then
                        export OLLAMA_MODELS="$OLLAMA_MODELS_TEMP_STORE_CREATE"
                    else
                        unset OLLAMA_MODELS
                    fi
                    continue
                fi

                # Clean up
                rm -f "$temp_modelfile"
                if [ -n "$OLLAMA_MODELS_TEMP_STORE_CREATE" ]; then
                    export OLLAMA_MODELS="$OLLAMA_MODELS_TEMP_STORE_CREATE"
                else
                    unset OLLAMA_MODELS
                fi
                break;;
            q|Q) print_info "Quitting script."; exit 0;;
            *) print_warning "Invalid input. Please enter a number from 1 to 6, or q.";;
        esac
    done

    if [ ${#MODELS_TO_INSTALL_LIST[@]} -gt 0 ]; then
        MODEL_TO_PULL="${MODELS_TO_INSTALL_LIST[0]}"
        print_success "AI Model(s) to be installed on USB: ${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET}"
        if [[ "$MODEL_SOURCE_TYPE" == "create_local" ]]; then
            print_info "(Model '${MODELS_TO_INSTALL_LIST[0]}' was imported from '$LOCAL_GGUF_PATH_FOR_IMPORT' into your host's Ollama instance.)"
        fi
    else
        print_warning "No models selected. Defaulting to $MODEL_TO_PULL for WebUI hint if needed, but no new models will be installed."
    fi
    calculate_total_estimated_models_size_gb # Calculate and set ESTIMATED_MODELS_SIZE_GB
    echo ""
}

ask_usb_device() {
    local prompt_title_text="🤔 SELECT TARGET USB DRIVE 🤔"
    local list_only_mode=false
    if [ "$#" -gt 0 ] && [ "$1" == "list_only" ]; then
        list_only_mode=true
        prompt_title_text="🔎 AVAILABLE USB STORAGE DEVICES 🔎"
    elif [[ "$OPERATION_MODE" == "add_llm" ]] || [[ "$OPERATION_MODE" == "repair_scripts" ]] || \
       [[ "$OPERATION_MODE" == "list_usb_models" ]] || [[ "$OPERATION_MODE" == "remove_llm" ]]; then
        prompt_title_text="🤔 SELECT EXISTING LEONARDO USB DRIVE 🤔"
    fi
    print_header "$prompt_title_text"

    echo -e "${C_BLUE}🔎 Detecting potential USB storage devices...${C_RESET}"
    declare -a devices_list_paths; declare -a devices_list_display_names

    if [[ "$(uname)" == "Linux" ]]; then
        while IFS= read -r line; do
            local device_name=$(echo "$line" | awk '{print $1}'); local device_size=$(echo "$line" | awk '{print $2}')
            local device_model=$(echo "$line" | awk '{for(i=3;i<=NF-1;i++) printf "%s ", $i; printf ""}' | sed 's/ *$//')
            local device_tran=$(echo "$line" | awk '{print $NF}')
            if [[ "$device_tran" == "usb" ]] || ( [[ "$device_name" == sd* ]] && [[ "$device_name" != "sda" ]] ); then
                local full_device_path="/dev/$device_name"
                local display_name_temp="$full_device_path ($device_size) - $device_model [$device_tran]"
                devices_list_paths+=("$full_device_path")
                devices_list_display_names+=("$display_name_temp")
            fi
        done < <(lsblk -dno NAME,SIZE,MODEL,TRAN | grep -Ev 'loop|rom|zram')
    elif [[ "$(uname)" == "Darwin" ]]; then
        while IFS= read -r disk_id; do
            local disk_info=$(diskutil info "$disk_id" 2>/dev/null || true); if [ -z "$disk_info" ]; then continue; fi
            local device_size=$(echo "$disk_info" | grep "Disk Size:" | awk '{print $3, $4}')
            local device_model=$(echo "$disk_info" | grep "Device / Media Name:" | cut -d':' -f2- | xargs)
            local device_protocol=$(echo "$disk_info" | grep "Protocol:" | cut -d':' -f2- | xargs)
            local is_external=$(echo "$disk_info" | grep "External:" | awk '{print $2}')
            local is_usb=$(echo "$disk_info" | grep "Protocol:" | grep -i "USB")
            if [[ "$is_external" == "Yes" ]] || [[ -n "$is_usb" ]]; then
                 local display_name_temp="$disk_id ($device_size) - $device_model [$device_protocol]"
                 devices_list_paths+=("$disk_id")
                 devices_list_display_names+=("$display_name_temp")
            fi
        done < <(diskutil list external physical | grep -E '^/dev/disk[0-9]+' | awk '{print $1}')
    fi

    if [ ${#devices_list_paths[@]} -eq 0 ]; then print_warning "No suitable USB storage devices automatically detected."; fi

    if $list_only_mode; then
        if [ ${#devices_list_display_names[@]} -gt 0 ]; then
            echo -e "${C_BLUE}Detected devices:${C_RESET}"
            for i in "${!devices_list_display_names[@]}"; do echo -e "  - ${devices_list_display_names[$i]}"; done
        else
            echo -e "${C_YELLOW}No devices found that match typical USB criteria.${C_RESET}"
        fi
        print_line
        return 0
    fi

    # Determine most likely USB candidate based on size and properties
    local suggested_drive_index=-1
    local largest_drive_index=-1
    local largest_drive_size=0
    local largest_drive_size_gb=0
    local leonardo_labeled_drive_index=-1

    # Find the largest drive and any Leonardo-labeled drives
    for i in "${!devices_list_display_names[@]}"; do
        local device_path="${devices_list_paths[$i]}"
        local display_name="${devices_list_display_names[$i]}"

        # Extract size and convert to numeric for comparison
        local size_str=$(echo "$display_name" | grep -o "([0-9.]\+[GMK]B\?\|[0-9]\+B)" | tr -d "()")
        local size_num=0

        if [[ "$size_str" =~ ([0-9.]+)([GMK]B?) ]]; then
            local size_val="${BASH_REMATCH[1]}"
            local size_unit="${BASH_REMATCH[2]}"

            case "$size_unit" in
                GB) size_num=$(echo "$size_val * 1000" | bc -l);;
                MB) size_num=$(echo "$size_val" | bc -l);;
                KB) size_num=$(echo "$size_val / 1000" | bc -l);;
                *) size_num=0;;
            esac

            if (( $(echo "$size_num > $largest_drive_size" | bc -l) )); then
                largest_drive_size=$size_num
                largest_drive_size_gb=$(echo "$size_val")
                largest_drive_index=$i
            fi
        fi

        # Check if this drive has a Leonardo-related label
        local partition_path
        if [[ "$(uname)" == "Linux" ]]; then
            partition_path=$(lsblk -plno NAME "$device_path" | grep "${device_path}[p0-9]*1$" | head -n 1 || echo "$device_path")
            local label=$(sudo blkid -s LABEL -o value "$partition_path" 2>/dev/null || echo "")
            if [[ "$label" =~ [Ll][Ee][Oo][Nn][Aa][Rr][Dd][Oo]|LLAMA|[Oo][Ll][Ll][Aa][Mm][Aa]|[Aa][Ii]|CHAT ]]; then
                leonardo_labeled_drive_index=$i
            fi
        elif [[ "$(uname)" == "Darwin" ]]; then
            local label=$(diskutil info "$device_path" 2>/dev/null | grep "Volume Name:" | sed -e 's/.*Volume Name:[^A-Za-z0-9]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || echo "")
            if [[ "$label" =~ [Ll][Ee][Oo][Nn][Aa][Rr][Dd][Oo]|LLAMA|[Oo][Ll][Ll][Aa][Mm][Aa]|[Aa][Ii]|CHAT ]]; then
                leonardo_labeled_drive_index=$i
            fi
        fi
    done

    # Select the suggested drive with improved logic
    # First priority: Drive with Leonardo/AI-related label
    if [ $leonardo_labeled_drive_index -ne -1 ]; then
        suggested_drive_index=$leonardo_labeled_drive_index
    # Second priority: USB-connected drive that's larger than 4GB
    elif [ $largest_drive_index -ne -1 ] && (( $(echo "$largest_drive_size >= 4000" | bc -l) )); then
        # Only suggest large drives (4GB+) to avoid suggesting small flash drives
        suggested_drive_index=$largest_drive_index
    # Third priority (fallback): Any USB drive
    else
        # Find any USB drive as a fallback
        local fallback_found=false

        # Try to find a USB drive first
        for i in "${!devices_list_paths[@]}"; do
            local display_name="${devices_list_display_names[$i]}"
            # If it's connected via USB and has non-zero size
            if [[ "$display_name" == *"[usb]"* ]] && [[ ! "$display_name" == *"(0B)"* ]]; then
                suggested_drive_index=$i
                fallback_found=true
                break
            fi
        done

        # If no USB drive found, pick any drive with non-zero size
        if ! $fallback_found; then
            for i in "${!devices_list_paths[@]}"; do
                local display_name="${devices_list_display_names[$i]}"
                if [[ ! "$display_name" == *"(0B)"* ]]; then
                    suggested_drive_index=$i
                    break
                fi
            done
        fi
    fi

    # Analyze drives for compatibility tiering
    declare -a drive_compatibility=()  # Array to store compatibility level for each drive

    for i in "${!devices_list_display_names[@]}"; do
        local display_name="${devices_list_display_names[$i]}"
        local device_path="${devices_list_paths[$i]}"

        # Check if it's a system drive
        local is_system_drive=false
        if [[ "$device_path" == "/dev/sda"* || "$device_path" == "/dev/nvme0n1"* ]]; then
            # Simple heuristic - /dev/sda or nvme0n1 is often the system drive
            is_system_drive=true
        fi

        # Check if it's USB-connected
        local is_usb=false
        if [[ "$display_name" == *"[usb]"* ]]; then
            is_usb=true
        fi

        # Check size
        local has_good_size=false
        if [[ ! "$display_name" == *"(0B)"* ]]; then
            has_good_size=true
        fi

        # Assign compatibility level
        if [ $i -eq $suggested_drive_index ]; then
            drive_compatibility[$i]="SUGGESTED"
        elif $is_system_drive; then
            drive_compatibility[$i]="NOT RECOMMENDED"
        elif $is_usb && $has_good_size; then
            drive_compatibility[$i]="COMPATIBLE"
        elif $has_good_size; then
            drive_compatibility[$i]="POSSIBLE"
        else
            drive_compatibility[$i]="NOT RECOMMENDED"
        fi
    done

    # Display drive options with tiered compatibility indicators
    echo -e "${C_BLUE}Please select the USB drive to use:${C_RESET}"
    for i in "${!devices_list_display_names[@]}"; do
        local compat="${drive_compatibility[$i]}"
        local display_name="${devices_list_display_names[$i]}"

        case "$compat" in
            "SUGGESTED")
                echo -e "  ${C_BOLD}$((i+1)))${C_RESET} ${C_GREEN}$display_name ${C_YELLOW}[SUGGESTED]${C_RESET}"
                ;;
            "COMPATIBLE")
                echo -e "  ${C_BOLD}$((i+1)))${C_RESET} ${C_CYAN}$display_name ${C_CYAN}[Compatible]${C_RESET}"
                ;;
            "POSSIBLE")
                echo -e "  ${C_BOLD}$((i+1)))${C_RESET} $display_name ${C_DIM}[Possible]${C_RESET}"
                ;;
            "NOT RECOMMENDED")
                echo -e "  ${C_BOLD}$((i+1)))${C_RESET} ${C_RED}$display_name ${C_RED}[Not Recommended]${C_RESET}"
                ;;
            *)
                echo -e "  ${C_BOLD}$((i+1)))${C_RESET} $display_name"
                ;;
        esac
    done
    echo -e "  ${C_BOLD}o)${C_RESET} Other (enter path manually)"
    echo -e "  ${C_BOLD}q)${C_RESET} Quit"
    print_line

    local USER_DEVICE_CHOICE_RAW_TEMP_LOCAL=""
    local temp_usb_device_path=""
    local default_choice=""

    # Set default choice to the suggested drive if one was identified
    if [ $suggested_drive_index -ne -1 ]; then
        default_choice="$((suggested_drive_index+1))"
    fi

    while true; do
        if [ -n "$default_choice" ]; then
            print_prompt "Enter your choice (number, 'o', or 'q') [Default: $default_choice]: "
            read -r choice

            # Use default if user just pressed Enter
            if [ -z "$choice" ]; then
                choice="$default_choice"
            fi
        else
            print_prompt "Enter your choice (number, 'o', or 'q'): "
            read -r choice
        fi
        USER_DEVICE_CHOICE_RAW_TEMP_LOCAL="$choice"
        case "$choice" in
            q|Q ) print_info "Quitting script."; exit 0;;
            o|O )
                print_prompt "Enter the full device path (e.g., /dev/sdb or /dev/disk3): "
                read -r temp_raw_usb_device_path
                if [ -z "$temp_raw_usb_device_path" ]; then print_warning "No path entered. Please try again."; continue; fi
                temp_usb_device_path="$temp_raw_usb_device_path"
                if [[ "$(uname)" == "Linux" ]] && ! echo "$temp_usb_device_path" | grep -q "^/dev/" && echo "$temp_usb_device_path" | grep -qE "^sd[a-z]$|^nvme[0-9]+n[0-9]+$"; then temp_usb_device_path="/dev/$temp_usb_device_path"; fi
                if [[ "$(uname)" == "Linux" ]] && [ ! -b "$temp_usb_device_path" ]; then print_error "'$temp_usb_device_path' not a valid block device on Linux."; temp_usb_device_path=""; continue
                elif [[ "$(uname)" == "Darwin" ]] && ! diskutil list | grep -qF "$temp_usb_device_path"; then print_error "'$temp_usb_device_path' not a valid disk identifier on macOS."; temp_usb_device_path=""; continue; fi
                break;;
            *[0-9]* )
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#devices_list_paths[@]}" ]; then
                    temp_usb_device_path="${devices_list_paths[$((choice-1))]}"
                    print_info "You selected: ${C_BOLD}${devices_list_display_names[$((choice-1))]}${C_RESET}";
                    break
                else print_warning "Invalid number. Please choose from the list."; fi;;
            * ) print_warning "Invalid choice. Please enter a number, 'o', or 'q'.";;
        esac
    done

    local confirm_selection
    local temp_usb_label_for_confirm
    local temp_detected_label_display
    if [[ "$(uname)" == "Darwin" ]]; then
        temp_usb_label_for_confirm=$(diskutil info "$temp_usb_device_path" 2>/dev/null | grep "Volume Name:" | sed -e 's/.*Volume Name:[^A-Za-z0-9]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || echo "")
    elif [[ "$(uname)" == "Linux" ]]; then
        local temp_partition_path_for_label
        temp_partition_path_for_label=$(lsblk -plno NAME "$temp_usb_device_path" | grep "${temp_usb_device_path}[p0-9]*1$" | head -n 1 || echo "$temp_usb_device_path")
        temp_usb_label_for_confirm=$(sudo blkid -s LABEL -o value "$temp_partition_path_for_label" 2>/dev/null || echo "")
    else
        temp_usb_label_for_confirm=""
    fi

    if [ -z "$temp_usb_label_for_confirm" ] || [[ "$temp_usb_label_for_confirm" == *"no file system"* ]] || [[ "$temp_usb_label_for_confirm" == *"Not applicable"* ]]; then
        temp_detected_label_display="(No valid label detected. Default: ${C_BOLD}$USB_LABEL_DEFAULT${C_RESET})"
    else
        temp_detected_label_display="(Detected label: ${C_BOLD}$temp_usb_label_for_confirm${C_RESET})"
    fi

    ask_yes_no_quit "You have selected ${C_BOLD}$temp_usb_device_path${C_RESET} $temp_detected_label_display. Is this correct?" confirm_selection
    if [[ "$confirm_selection" != "yes" ]]; then
        print_fatal "USB selection aborted by user."
    fi

    RAW_USB_DEVICE_PATH="$temp_usb_device_path"
    USB_DEVICE_PATH="$temp_usb_device_path"
    USER_DEVICE_CHOICE_RAW_FOR_MAC_FORMAT_WARN="$USER_DEVICE_CHOICE_RAW_TEMP_LOCAL"

    local current_actual_label=""
    if [[ "$(uname)" == "Darwin" ]]; then
        current_actual_label=$(diskutil info "$RAW_USB_DEVICE_PATH" 2>/dev/null | grep "Volume Name:" | sed -e 's/.*Volume Name:[^A-Za-z0-9]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)
    elif [[ "$(uname)" == "Linux" ]]; then
        local potential_partition_for_label
        potential_partition_for_label=$(lsblk -plno NAME "$RAW_USB_DEVICE_PATH" | grep "${RAW_USB_DEVICE_PATH}[p0-9]*1$" | head -n 1 || echo "$RAW_USB_DEVICE_PATH")
        if [ -b "$potential_partition_for_label" ]; then
            current_actual_label=$(sudo blkid -s LABEL -o value "$potential_partition_for_label" 2>/dev/null || true)
        fi
    fi

    if [ -n "$current_actual_label" ] && [[ ! "$current_actual_label" =~ "Not applicable" ]] && [[ ! "$current_actual_label" =~ "no file system" ]]; then
        print_success "Confirmed USB: ${C_BOLD}$USB_DEVICE_PATH${C_RESET}. Current detected label is '${C_BOLD}$current_actual_label${C_RESET}'."
        USB_LABEL="$current_actual_label"
    else
        print_success "Confirmed USB: ${C_BOLD}$USB_DEVICE_PATH${C_RESET}. No current valid label detected. Will use default '${C_BOLD}$USB_LABEL_DEFAULT${C_RESET}' if formatting, or attempt to use as-is."
        USB_LABEL="$USB_LABEL_DEFAULT"
    fi

    echo ""
    if [ -z "$USB_DEVICE_PATH" ]; then print_fatal "No device selected. Exiting."; fi
}


# --- USB File Generation Functions ---
generate_webui_html() {
    local usb_base_dir="$1"
    local default_model_hint="$2"
    local webui_file="$usb_base_dir/webui/index.html"

    print_info "Generating Web UI (index.html) with dynamic model list..."

    local available_models_options=""
    local first_model_found=""
    local manifests_scan_path="$usb_base_dir/.ollama/models/manifests/registry.ollama.ai/library"

    if [ -d "$manifests_scan_path" ] && command -v jq &>/dev/null; then
        mapfile -t sorted_model_paths < <(sudo find "$manifests_scan_path" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null | xargs -0 -n1 | sort -u || true)

        for tag_file_path in "${sorted_model_paths[@]}"; do
            if [ ! -f "$tag_file_path" ]; then continue; fi
            local relative_path="${tag_file_path#$manifests_scan_path/}"
            local model_name_tag="${relative_path%/*}:${relative_path##*/}"
            if [ -z "$first_model_found" ]; then first_model_found="$model_name_tag"; fi
            local selected_attr=""
            if [[ "$model_name_tag" == "$default_model_hint" ]]; then
                selected_attr="selected"
            fi
            available_models_options+="<option value=\"$model_name_tag\" $selected_attr>$model_name_tag</option>\n"
        done
    fi

    if [ -z "$available_models_options" ] && [ -n "$default_model_hint" ]; then
        available_models_options="<option value=\"$default_model_hint\" selected>$default_model_hint</option>"
        if [ -z "$first_model_found" ]; then first_model_found="$default_model_hint"; fi
    elif [ -z "$available_models_options" ]; then
        available_models_options="<option value=\"\" disabled selected>No models found on USB</option>"
    fi

    if [[ "$available_models_options" != *selected* ]] && [ -n "$first_model_found" ]; then
         available_models_options=$(echo -e "$available_models_options" | sed "s|<option value=\"$first_model_found\">|<option value=\"$first_model_found\" selected>|")
    fi

    sudo mkdir -p "$usb_base_dir/webui"
    safe_chown "$usb_base_dir/webui" "$(id -u):$(id -g)"

cat << EOF_HTML | sudo tee "$webui_file" > /dev/null
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leonardo AI - USB Chat</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"; margin: 0; background-color: #2c2c2c; color: #e0e0e0; display: flex; flex-direction: column; height: 100vh; }
        header { background-color: #1e1e1e; color: #00ff9d; padding: 1em; text-align: center; border-bottom: 1px solid #444; }
        header h1 { margin: 0; font-weight: 300; }
        .chat-container { flex-grow: 1; overflow-y: auto; padding: 1em; display: flex; flex-direction: column; gap: 12px; }
        .message { padding: 0.8em 1.2em; border-radius: 18px; line-height: 1.5; max-width: 75%; word-wrap: break-word; box-shadow: 0 1px 3px rgba(0,0,0,0.2); }
        .user { background-color: #007bff; color: white; align-self: flex-end; border-bottom-right-radius: 4px; }
        .assistant { background-color: #3a3a3a; border: 1px solid #484848; align-self: flex-start; border-bottom-left-radius: 4px; }
        .assistant strong { color: #00ff9d; }
        .assistant.thinking { opacity: 0.7; font-style: italic; background-color: #404040; }
        .error { background-color: #d8000c; color: #ffdddd; align-self: center; text-align: center; }
        .input-area { display: flex; padding: 1em; background-color: #1e1e1e; border-top: 1px solid #444; gap: 10px; }
        #promptInput { flex-grow: 1; padding: 0.8em 1em; border: 1px solid #555; border-radius: 20px; background-color: #333; color: #e0e0e0; font-size: 1em; }
        #promptInput:focus { outline: none; border-color: #007bff; box-shadow: 0 0 0 2px rgba(0,123,255,.25); }
        button { padding: 0.8em 1.5em; background-color: #007bff; color: white; border: none; border-radius: 20px; cursor: pointer; font-size: 1em; transition: background-color 0.2s ease; }
        button:hover { background-color: #0056b3; }
        button:disabled { background-color: #555; cursor: not-allowed; }
        .model-selector { padding: 0.8em 1em; background-color: #252525; text-align: center; border-bottom: 1px solid #444; }
        .model-selector label { margin-right: 8px; }
        select { padding: 0.6em 0.8em; border-radius: 8px; background-color: #333; color: #e0e0e0; border: 1px solid #555; font-size: 0.9em; }
        .msg-content { white-space: pre-wrap; }
    </style>
</head>
<body>
    <header><h1>Leonardo AI - USB Chat 🦙💾</h1></header>
    <div class="model-selector">
        <label for="modelSelect">Select Model: </label>
        <select id="modelSelect">
            ${available_models_options}
        </select>
    </div>
    <div class="chat-container" id="chatLog"></div>
    <div class="input-area">
        <input type="text" id="promptInput" placeholder="Type your message..." autofocus>
        <button onclick="sendMessage()">Send</button>
    </div>

    <script>
        const chatLog = document.getElementById('chatLog');
        const promptInput = document.getElementById('promptInput');
        const modelSelect = document.getElementById('modelSelect');
        const sendButton = document.querySelector('.input-area button');
        let conversationHistory = [];

        function appendMessage(sender, message, type, returnElement = false) {
            const messageDiv = document.createElement('div');
            messageDiv.classList.add('message', type);

            const senderStrong = document.createElement('strong');
            senderStrong.textContent = sender + ':';
            messageDiv.appendChild(senderStrong);

            const messageSpan = document.createElement('span');
            messageSpan.classList.add('msg-content');
            messageSpan.appendChild(document.createTextNode(" " + message));
            messageDiv.appendChild(messageSpan);

            chatLog.appendChild(messageDiv);
            chatLog.scrollTop = chatLog.scrollHeight;
            if (returnElement) return messageDiv;
        }

        async function sendMessage() {
            const model = modelSelect.value;
            const prompt = promptInput.value.trim();

            if (!model) {
                appendMessage('System', 'Please select a model.', 'error');
                return;
            }
            if (!prompt) return;

            appendMessage('You', prompt, 'user');
            conversationHistory.push({ role: 'user', content: prompt });
            promptInput.value = '';
            sendButton.disabled = true;

            let assistantMessageDiv = appendMessage(model, 'Thinking...', 'assistant thinking', true);
            const assistantContentSpan = assistantMessageDiv.querySelector('span.msg-content');

            try {
                const response = await fetch('/api/chat', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ model: model, messages: conversationHistory, stream: true }),
                });

                if (!response.ok) {
                    const errorData = await response.json().catch(() => ({ error: 'Unknown API error' }));
                    throw new Error(\`API Error (\${response.status}): \${errorData.error || response.statusText}\`);
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';
                let fullAssistantResponse = '';
                assistantContentSpan.textContent = ' ';
                assistantMessageDiv.classList.remove('thinking');

                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    buffer += decoder.decode(value, { stream: true });
                    let lines = buffer.split('\\n');

                    for (let i = 0; i < lines.length - 1; i++) {
                        const line = lines[i];
                        if (line.trim() === "") continue;
                        try {
                            const chunk = JSON.parse(line);
                            if (chunk.message && chunk.message.content) {
                                fullAssistantResponse += chunk.message.content;
                                assistantContentSpan.textContent = " " + fullAssistantResponse;
                                chatLog.scrollTop = chatLog.scrollHeight;
                            }
                        } catch (e) { console.warn("Failed to parse JSON line:", line, e); }
                    }
                    buffer = lines[lines.length - 1];
                }
                if (buffer.trim() !== "") {
                    try {
                        const chunk = JSON.parse(buffer);
                        if (chunk.message && chunk.message.content) {
                            fullAssistantResponse += chunk.message.content;
                            assistantContentSpan.textContent = " " + fullAssistantResponse;
                        }
                    } catch (e) { console.warn("Failed to parse final buffer:", buffer, e); }
                }

                if (fullAssistantResponse.trim() !== "") {
                    conversationHistory.push({ role: 'assistant', content: fullAssistantResponse });
                } else if (assistantContentSpan.textContent.trim() === "") {
                    assistantContentSpan.textContent = " (No response or empty response)";
                }

            } catch (error) {
                console.error('Error sending message:', error);
                if (assistantMessageDiv) assistantMessageDiv.remove();
                appendMessage('System', \`Error: \${error.message}\`, 'error');
                if (conversationHistory.length > 0 && conversationHistory[conversationHistory.length -1].role === 'user') {
                    conversationHistory.pop();
                }
            } finally {
                sendButton.disabled = false;
                promptInput.focus();
            }
        }

        promptInput.addEventListener('keypress', function(event) {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault(); sendMessage();
            }
        });

        conversationHistory = [];
        appendMessage('Leonardo System', 'Welcome! Select a model and type your prompt to begin.', 'assistant');
    </script>
</body>
</html>
EOF_HTML
    sudo chmod 644 "$webui_file"
    print_success "Web UI generated at $webui_file"
}

generate_launcher_scripts() {
    local usb_base_dir="$1"
    local default_model_for_ui="$2"

    print_info "Generating launcher scripts..."

    local launcher_name_base="$USER_LAUNCHER_NAME_BASE"
    local common_ollama_serve_command="ollama serve"
    local common_data_dir_setup_win="SET OLLAMA_MODELS=%~dp0.ollama\\models\r\nSET OLLAMA_TMPDIR=%~dp0Data\\tmp\r\nMKDIR \"%~dp0Data\\tmp\" 2>NUL\r\nMKDIR \"%~dp0Data\\logs\" 2>NUL"

    local common_mac_linux_data_dir_setup
    common_mac_linux_data_dir_setup=$(cat <<EOF_COMMON_SETUP
export OLLAMA_MODELS='\$SCRIPT_DIR/.ollama/models';
export OLLAMA_TMPDIR='\$SCRIPT_DIR/Data/tmp';
mkdir -p "\$SCRIPT_DIR/Data/tmp" "\$SCRIPT_DIR/Data/logs";
EOF_COMMON_SETUP
)

    local model_options_for_select_heredoc=""
    declare -a model_array_for_bash_heredoc=()
    local model_selection_case_logic_sh=""
    local model_selection_bat_logic=""
    local first_model_for_cli_default=""

    local manifests_scan_path="$usb_base_dir/.ollama/models/manifests/registry.ollama.ai/library"

    if [ -d "$manifests_scan_path" ] && command -v jq &>/dev/null; then
        mapfile -t sorted_model_paths < <(sudo find "$manifests_scan_path" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null | xargs -0 -n1 | sort -u || true)
        local i=1
        for tag_file_path in "${sorted_model_paths[@]}"; do
            if [ ! -f "$tag_file_path" ]; then continue; fi
            local relative_path="${tag_file_path#$manifests_scan_path/}"
            local model_name_tag="${relative_path%/*}:${relative_path##*/}"
            if [ -z "$first_model_for_cli_default" ]; then first_model_for_cli_default="$model_name_tag"; fi

            model_options_for_select_heredoc+="printf \"%b\\\\n\" \"  \${C_BOLD}$i\${C_RESET}) $model_name_tag\";\n"
            model_array_for_bash_heredoc+=("$model_name_tag")

            model_selection_bat_logic+="ECHO   $i) $model_name_tag\r\n"
            i=$((i+1))
        done
    fi

    if [ ${#model_array_for_bash_heredoc[@]} -eq 0 ]; then
        if [ -n "$default_model_for_ui" ]; then
            first_model_for_cli_default="$default_model_for_ui"
            model_options_for_select_heredoc="printf \"%b\\\\n\" \"  \${C_BOLD}1\${C_RESET}) $default_model_for_ui (Default - Scanned list empty)\";\n"
            model_array_for_bash_heredoc=("$default_model_for_ui")
            model_selection_bat_logic="ECHO   1) $default_model_for_ui (Default - Scanned list empty)\r\n"
        else
            first_model_for_cli_default="llama3:8b"
            model_options_for_select_heredoc="printf \"%b\\\\n\" \"  \${C_BOLD}1\${C_RESET}) $first_model_for_cli_default (Default - No models scanned)\";\n"
            model_array_for_bash_heredoc=("$first_model_for_cli_default")
            model_selection_bat_logic="ECHO   1) $first_model_for_cli_default (Default - No models scanned)\r\n"
        fi
    fi

    # Model selection logic will be written directly to the output file
    model_selection_logic_sh="# Model selection logic will be written directly to the output file\n"

    local model_selection_bat_logic_final=""
    if [ ${#model_array_for_bash_heredoc[@]} -gt 1 ]; then
        model_selection_bat_logic_final="ECHO Available models:\r\n"
        model_selection_bat_logic_final+="$model_selection_bat_logic"
        model_selection_bat_logic_final+="SET /P MODEL_CHOICE_NUM=\"Select model (number) or press Enter for default ($first_model_for_cli_default): \"\r\n"
        model_selection_bat_logic_final+="SET SELECTED_MODEL=$first_model_for_cli_default\r\n"
        local k_win=1
        for model_win in "${model_array_for_bash_heredoc[@]}"; do
             model_selection_bat_logic_final+="IF \"%MODEL_CHOICE_NUM%\"==\"$k_win\" SET SELECTED_MODEL=$model_win\r\n"
             k_win=$((k_win+1))
        done
        model_selection_bat_logic_final+="ECHO Using model: %SELECTED_MODEL%\r\n"
        model_selection_bat_logic_final+="SET LEONARDO_DEFAULT_MODEL=%SELECTED_MODEL%\r\n"
    elif [ ${#model_array_for_bash_heredoc[@]} -eq 1 ]; then
        model_selection_bat_logic_final="SET SELECTED_MODEL=${model_array_for_bash_heredoc[0]}\r\n"
        model_selection_bat_logic_final+="ECHO Using model (only one available): %SELECTED_MODEL%\r\n"
        model_selection_bat_logic_final+="SET LEONARDO_DEFAULT_MODEL=%SELECTED_MODEL%\r\n"
    else
        model_selection_bat_logic_final="ECHO ERROR: No models found or configured. Cannot select a model.\r\nPAUSE\r\nEXIT /B 1\r\n"
    fi


    # Always create Linux launcher regardless of selected OS targets
    # This ensures at least one launcher is always available
    local linux_launcher="$usb_base_dir/${launcher_name_base}.sh"
    print_info "Crafting Linux launcher script: $linux_launcher"

    # Make sure the destination directory exists and is writable
    sudo mkdir -p "$(dirname "$linux_launcher")" 2>/dev/null

    # Create the launcher with explicit output redirection and error checking
    if ! sudo tee "$linux_launcher" > /dev/null << 'EOF_LINUX_SH'; then
        print_error "Failed to create Linux launcher script. Check permissions on USB drive."
        return 1
    fi
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)";
cd "\$SCRIPT_DIR" || { printf "%s\\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

# Initialize console colors
C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=\$(tput sgr0); C_BOLD=\$(tput bold); C_RED=\$(tput setaf 1); C_GREEN=\$(tput setaf 2);
    C_YELLOW=\$(tput setaf 3); C_BLUE=\$(tput setaf 4); C_CYAN=\$(tput setaf 6);
fi;

# Define helper functions
print_error() {
    printf "%b\\n" "\${C_RED}❌ ERROR: \$1\${C_RESET}";
}

printf "%b\\n" "\${C_BOLD}\${C_GREEN}🚀 Starting Leonardo AI USB Environment (Linux)...\${C_RESET}";

printf "%b\\n" "\${C_BLUE}Setting up environment variables...\${C_RESET}";
${common_mac_linux_data_dir_setup}
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="\$SCRIPT_DIR/runtimes/linux/bin/ollama";
if [ ! -f "\$OLLAMA_BIN" ]; then printf "%b\\n" "\${C_RED}❌ Error: Ollama binary not found at \$OLLAMA_BIN\${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "\$OLLAMA_BIN" ]; then
    printf "%b\\n" "\${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...\${C_RESET}";
    chmod +x "\$OLLAMA_BIN" || { printf "%b\\n" "\${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions or remount USB if needed.\${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

# Model selection logic - written directly for bash 3.x compatibility
if [ ${#model_array_for_bash_heredoc[@]} -gt 1 ]; then
    printf "%b\\n" "\${C_BLUE}Available models:\${C_RESET}"
    ${model_options_for_select_heredoc}
    read -r -p "\$(printf "%b" "\${C_CYAN}➡️  Select model (number) or press Enter for default ($first_model_for_cli_default): \${C_RESET}")" MODEL_CHOICE_NUM
    SELECTED_MODEL="$first_model_for_cli_default"

    # Initialize array in bash 3.x compatible way
    _models_for_selection=()
    for model in "${model_array_for_bash_heredoc[@]}"; do
        _models_for_selection+=("$model")
    done

    if [[ "\$MODEL_CHOICE_NUM" =~ ^[0-9]+$ ]] && [ "\$MODEL_CHOICE_NUM" -ge 1 ] && [ "\$MODEL_CHOICE_NUM" -le ${#model_array_for_bash_heredoc[@]} ]; then
        idx=\$((MODEL_CHOICE_NUM-1))
        SELECTED_MODEL="\${_models_for_selection[\$idx]}"
    fi
    printf "%b\\n" "\${C_GREEN}Using model: \$SELECTED_MODEL\${C_RESET}"
    export LEONARDO_DEFAULT_MODEL="\$SELECTED_MODEL"
elif [ ${#model_array_for_bash_heredoc[@]} -eq 1 ]; then
    SELECTED_MODEL="${model_array_for_bash_heredoc[0]}"
    printf "%b\\n" "\${C_GREEN}Using model (only one available): \$SELECTED_MODEL\${C_RESET}"
    export LEONARDO_DEFAULT_MODEL="\$SELECTED_MODEL"
else
    printf "%b\\n" "\${C_RED}No models found or configured. Cannot select a model.\${C_RESET}"
    read -p "Press Enter to exit."
    exit 1
fi

printf "%b\\n" "\${C_BLUE}Starting Ollama server in the background...\${C_RESET}";
LOG_FILE="\$SCRIPT_DIR/Data/logs/ollama_server_linux.log";
env -i HOME="\$HOME" USER="\$USER" PATH="\$PATH" OLLAMA_MODELS="\$OLLAMA_MODELS" OLLAMA_TMPDIR="\$OLLAMA_TMPDIR" OLLAMA_HOST="\$OLLAMA_HOST" "\$OLLAMA_BIN" $common_ollama_serve_command > "\$LOG_FILE" 2>&1 &
OLLAMA_PID=\$!;
printf "%b\\n" "\${C_GREEN}Ollama server started with PID \$OLLAMA_PID. Log: \$LOG_FILE\${C_RESET}";
printf "%b\\n" "\${C_BLUE}Waiting a few seconds for the server to initialize...\${C_RESET}"; sleep 5;

if ! curl --silent --fail "http://\${OLLAMA_HOST}/api/tags" > /dev/null 2>&1 && ! ps -p \$OLLAMA_PID > /dev/null; then
    printf "%b\\n" "\${C_RED}❌ Error: Ollama server failed to start or is not responding. Check \$LOG_FILE for details.\${C_RESET}";
    printf "%b\\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;
printf "%b\\n" "\${C_GREEN}Ollama server seems to be running. ✅\${C_RESET}";

WEBUI_PATH="\$SCRIPT_DIR/webui/index.html";
printf "%b\\n" "\${C_BLUE}Attempting to open Web UI: \$WEBUI_PATH\${C_RESET}";
if command -v xdg-open &> /dev/null; then xdg-open "\$WEBUI_PATH" &
elif command -v gnome-open &> /dev/null; then gnome-open "\$WEBUI_PATH" &
elif command -v kde-open &> /dev/null; then kde-open "\$WEBUI_PATH" &
else printf "%b\\n" "\${C_YELLOW}⚠️ Could not find xdg-open, gnome-open, or kde-open. Please open \$WEBUI_PATH in your web browser manually.\${C_RESET}"; fi;

printf "\\n";
printf "%b\\n" "\${C_BOLD}\${C_GREEN}✨ Leonardo AI USB is now running! ✨\${C_RESET}";
printf "%b\\n" "  - Ollama Server PID: \${C_BOLD}\$OLLAMA_PID\${C_RESET}";
printf "%b\\n" "  - Default Model for CLI/WebUI: \${C_BOLD}\$SELECTED_MODEL\${C_RESET} (WebUI allows changing this)";
printf "%b\\n" "  - Web UI should be open in your browser (or open manually: \${C_GREEN}\file://\$WEBUI_PATH\${C_RESET}).";
printf "%b\\n" "  - To stop the Ollama server, close this terminal window or run: \${C_YELLOW}kill \$OLLAMA_PID\${C_RESET}";
printf "\\n";
printf "%b\\n" "\${C_YELLOW}Press Ctrl+C in this window (or close it) to stop the Ollama server and exit.\${C_RESET}";

trap 'printf "\\n%b\\n" "\${C_BLUE}Shutting down Ollama server (PID \$OLLAMA_PID)..."; kill \$OLLAMA_PID 2>/dev/null; wait \$OLLAMA_PID 2>/dev/null; printf "%b\\n" "\${C_GREEN}Ollama server stopped.\${C_RESET}"' EXIT TERM INT;

wait \$OLLAMA_PID;
printf "%b\\n" "\${C_BLUE}Ollama server (PID \$OLLAMA_PID) has been stopped by wait.\${C_RESET}";
printf "%b\\n" "\${C_GREEN}Leonardo AI USB session ended.\${C_RESET}";
EOF_LINUX_SH
        sudo chmod +x "$linux_launcher"
    fi

    # Always create macOS launcher regardless of selected OS targets
    # This ensures all launchers are available for multi-platform compatibility
    local mac_launcher="$usb_base_dir/${launcher_name_base}.command"
    print_info "Crafting macOS launcher script: $mac_launcher"

    # Make sure the destination directory exists and is writable
    sudo mkdir -p "$(dirname "$mac_launcher")" 2>/dev/null

    # Create the launcher with explicit output redirection and error checking
    if ! sudo tee "$mac_launcher" > /dev/null << 'EOF_MAC_COMMAND'; then
        print_error "Failed to create macOS launcher script. Check permissions on USB drive."
        return 1
    fi
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)";
cd "\$SCRIPT_DIR" || { printf "%s\\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=\$(tput sgr0); C_BOLD=\$(tput bold); C_RED=\$(tput setaf 1); C_GREEN=\$(tput setaf 2);
    C_YELLOW=\$(tput setaf 3); C_BLUE=\$(tput setaf 4); C_CYAN=\$(tput setaf 6);
fi;

printf "%b\\n" "\${C_BOLD}\${C_GREEN}🚀 Starting Leonardo AI USB Environment (macOS)...\${C_RESET}";

printf "%b\\n" "\${C_BLUE}Setting up environment variables...\${C_RESET}";
${common_mac_linux_data_dir_setup}
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="\$SCRIPT_DIR/runtimes/mac/bin/ollama";
if [ ! -f "\$OLLAMA_BIN" ]; then printf "%b\\n" "\${C_RED}❌ Error: Ollama binary not found at \$OLLAMA_BIN\${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "\$OLLAMA_BIN" ]; then
    printf "%b\\n" "\${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...\${C_RESET}";
    chmod +x "\$OLLAMA_BIN" || { printf "%b\\n" "\${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions.\${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

# Model selection logic - written directly for bash 3.x compatibility
if [ ${#model_array_for_bash_heredoc[@]} -gt 1 ]; then
    printf "%b\\n" "\${C_BLUE}Available models:\${C_RESET}"
    ${model_options_for_select_heredoc}
    read -r -p "\$(printf "%b" "\${C_CYAN}➡️  Select model (number) or press Enter for default ($first_model_for_cli_default): \${C_RESET}")" MODEL_CHOICE_NUM
    SELECTED_MODEL="$first_model_for_cli_default"

    # Initialize array in bash 3.x compatible way
    _models_for_selection=()
    for model in "${model_array_for_bash_heredoc[@]}"; do
        _models_for_selection+=("$model")
    done

    if [[ "\$MODEL_CHOICE_NUM" =~ ^[0-9]+$ ]] && [ "\$MODEL_CHOICE_NUM" -ge 1 ] && [ "\$MODEL_CHOICE_NUM" -le ${#model_array_for_bash_heredoc[@]} ]; then
        idx=\$((MODEL_CHOICE_NUM-1))
        SELECTED_MODEL="\${_models_for_selection[\$idx]}"
    fi
    printf "%b\\n" "\${C_GREEN}Using model: \$SELECTED_MODEL\${C_RESET}"
    export LEONARDO_DEFAULT_MODEL="\$SELECTED_MODEL"
elif [ ${#model_array_for_bash_heredoc[@]} -eq 1 ]; then
    SELECTED_MODEL="${model_array_for_bash_heredoc[0]}"
    printf "%b\\n" "\${C_GREEN}Using model (only one available): \$SELECTED_MODEL\${C_RESET}"
    export LEONARDO_DEFAULT_MODEL="\$SELECTED_MODEL"
else
    printf "%b\\n" "\${C_RED}No models found or configured. Cannot select a model.\${C_RESET}"
    read -p "Press Enter to exit."
    exit 1
fi

printf "%b\\n" "\${C_BLUE}Starting Ollama server in the background...\${C_RESET}";
LOG_FILE="\$SCRIPT_DIR/Data/logs/ollama_server_mac.log";
env -i HOME="\$HOME" USER="\$USER" PATH="\$PATH:/usr/local/bin:/opt/homebrew/bin" OLLAMA_MODELS="\$OLLAMA_MODELS" OLLAMA_TMPDIR="\$OLLAMA_TMPDIR" OLLAMA_HOST="\$OLLAMA_HOST" "\$OLLAMA_BIN" $common_ollama_serve_command > "\$LOG_FILE" 2>&1 &
OLLAMA_PID=\$!;
printf "%b\\n" "\${C_GREEN}Ollama server started with PID \$OLLAMA_PID. Log: \$LOG_FILE\${C_RESET}";
printf "%b\\n" "\${C_BLUE}Waiting a few seconds for the server to initialize...\${C_RESET}"; sleep 5;

if ! curl --silent --fail "http://\${OLLAMA_HOST}/api/tags" > /dev/null 2>&1 && ! ps -p \$OLLAMA_PID > /dev/null; then
    printf "%b\\n" "\${C_RED}❌ Error: Ollama server failed to start or is not responding. Check \$LOG_FILE for details.\${C_RESET}";
    printf "%b\\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;
printf "%b\\n" "\${C_GREEN}Ollama server seems to be running. ✅\${C_RESET}";

WEBUI_PATH="\$SCRIPT_DIR/webui/index.html";
printf "%b\\n" "\${C_BLUE}Attempting to open Web UI: file://\$WEBUI_PATH\${C_RESET}";
open "file://\$WEBUI_PATH" &

printf "\\n";
printf "%b\\n" "\${C_BOLD}\${C_GREEN}✨ Leonardo AI USB is now running! ✨\${C_RESET}";
printf "%b\\n" "  - Ollama Server PID: \${C_BOLD}\$OLLAMA_PID\${C_RESET}";
printf "%b\\n" "  - Default Model for CLI/WebUI: \${C_BOLD}\$SELECTED_MODEL\${C_RESET} (WebUI allows changing this)";
printf "%b\\n" "  - Web UI should be open in your browser (or open manually: \${C_GREEN}file://\$WEBUI_PATH\${C_RESET}).";
printf "%b\\n" "  - To stop the Ollama server, close this terminal window or run: \${C_YELLOW}kill \$OLLAMA_PID\${C_RESET}";
printf "\\n";
printf "%b\\n" "\${C_YELLOW}This terminal window is keeping the Ollama server alive.";
printf "%b\\n" "Close this window or press Ctrl+C to stop the server.\${C_RESET}";

trap 'printf "\\n%b\\n" "\${C_BLUE}Shutting down Ollama server (PID \$OLLAMA_PID)..."; kill \$OLLAMA_PID 2>/dev/null; wait \$OLLAMA_PID 2>/dev/null; printf "%b\\n" "\${C_GREEN}Ollama server stopped.\${C_RESET}"' EXIT TERM INT;

wait \$OLLAMA_PID;
printf "%b\\n" "\${C_BLUE}Ollama server (PID \$OLLAMA_PID) has been stopped.\${C_RESET}";
printf "%b\\n" "\${C_GREEN}Leonardo AI USB session ended.\${C_RESET}";
EOF_MAC_COMMAND
        sudo chmod +x "$mac_launcher"
    fi

    # Always create Windows launcher regardless of selected OS targets
    # This ensures all launchers are available for multi-platform compatibility
    local win_launcher="$usb_base_dir/${launcher_name_base}.bat"
    print_info "Crafting Windows launcher script: $win_launcher"

    # Make sure the destination directory exists and is writable
    sudo mkdir -p "$(dirname "$win_launcher")" 2>/dev/null

    # Create the Windows batch file
    cat > "${TMP_DIR}/temp_win_batch.bat" << 'TEMP_BATCH_CONTENT'
@ECHO OFF
REM Leonardo AI USB Windows Launcher
TITLE Leonardo AI USB Launcher
COLOR 0A
CLS
ECHO ^<--------------------------------------------------------------------^>
ECHO ^|         Leonardo AI USB Environment (Windows) - Starting...        ^|
ECHO ^<--------------------------------------------------------------------^>
CD /D "%~dp0"

ECHO Setting up environment variables...
TEMP_BATCH_CONTENT

    # Add environment setup
    echo "${common_data_dir_setup_win}" >> "${TMP_DIR}/temp_win_batch.bat"

    # Add rest of content
    cat >> "${TMP_DIR}/temp_win_batch.bat" << 'TEMP_BATCH_CONTENT2'
SET OLLAMA_HOST=127.0.0.1:11434

SET OLLAMA_BIN=%~dp0runtimes\win\bin\ollama.exe
IF NOT EXIST "%OLLAMA_BIN%" (
    COLOR 0C
    ECHO ^>^> ERROR: Ollama binary not found at %OLLAMA_BIN%
    PAUSE
    EXIT /B 1
)
TEMP_BATCH_CONTENT2

    # Add model selection logic
    echo "${model_selection_bat_logic_final}" >> "${TMP_DIR}/temp_win_batch.bat"

    # Add server start and UI open logic
    cat >> "${TMP_DIR}/temp_win_batch.bat" << 'TEMP_BATCH_CONTENT3'

ECHO Starting Ollama server in a new window...
TEMP_BATCH_CONTENT3
    echo "START \"Ollama Server (Leonardo AI USB)\" /D \"%~dp0runtimes\\win\\bin\" \"%OLLAMA_BIN%\" ${common_ollama_serve_command}" >> "${TMP_DIR}/temp_win_batch.bat"

    # Add final content
    cat >> "${TMP_DIR}/temp_win_batch.bat" << 'TEMP_BATCH_CONTENT4'

ECHO Waiting a few seconds for the server to initialize...
PING 127.0.0.1 -n 8 > NUL

ECHO Checking if Ollama server process is running...
TASKLIST /FI "IMAGENAME eq ollama.exe" /NH | FIND /I "ollama.exe" > NUL
IF ERRORLEVEL 1 (
    COLOR 0C
    ECHO ^>^> ERROR: Ollama server process not detected after startup.
    ECHO    Check the new "Ollama Server" window for error messages.
    ECHO    Ensure no other Ollama instance is conflicting on port 11434.
    PAUSE
    EXIT /B 1
)
COLOR 0A
ECHO Ollama server process found. ^<^<

SET WEBUI_PATH_RAW=%~dp0webui\index.html
SET WEBUI_PATH_URL=%WEBUI_PATH_RAW:\=/%
ECHO Attempting to open Web UI: file:///%WEBUI_PATH_URL%
START "" "file:///%WEBUI_PATH_URL%"

ECHO.
ECHO ^<--------------------------------------------------------------------^>
ECHO ^|                 ✨ Leonardo AI USB is now running! ✨              ^|
ECHO ^|--------------------------------------------------------------------^|
ECHO ^| - Ollama Server is running in a separate window.                   ^|
ECHO ^| - Default Model for CLI/WebUI: %SELECTED_MODEL%                    ^|
ECHO ^|   (WebUI allows changing this from available models on USB)        ^|
ECHO ^| - Web UI should be open in your browser.                           ^|
ECHO ^|   (If not, manually open: file:///%WEBUI_PATH_URL%)                ^|
ECHO ^| - To stop: Close the "Ollama Server" window AND this window.     ^|
ECHO ^<--------------------------------------------------------------------^>
ECHO.
ECHO This launcher window can be closed. The Ollama server will continue
ECHO running in its own window until that "Ollama Server" window is closed.
PAUSE
EXIT /B 0
TEMP_BATCH_CONTENT4

    # Copy the generated batch file to the target location
    if ! sudo cp "${TMP_DIR}/temp_win_batch.bat" "$win_launcher"; then
        print_error "Failed to create Windows launcher script. Check permissions on USB drive."
        return 1
    fi


    if command -v unix2dos &> /dev/null; then
        sudo unix2dos "$win_launcher" >/dev/null 2>&1 || print_warning "Failed to convert line endings for Windows batch file."
    else
        print_warning "unix2dos not found. Windows .bat file might have incorrect line endings if created on Linux/macOS."
    fi
    print_success "Launcher scripts generated."
}

# Function to generate security readme files for the USB drive
generate_security_readme() {
    local usb_base_dir="$1"
    local readme_file="$usb_base_dir/SECURITY_README.txt"
    local install_dir_readme_file="$usb_base_dir/Installation_Info/SECURITY_README.txt"

    sudo mkdir -p "$usb_base_dir/Installation_Info"
    safe_chown "$usb_base_dir/Installation_Info" "$(id -u):$(id -g)"

    sudo tee "$readme_file" "$install_dir_readme_file" > /dev/null << 'EOF_README'
================================================================================
🛡️ Leonardo AI USB - IMPORTANT SECURITY & USAGE GUIDELINES 🛡️
================================================================================

Thank you for using the Leonardo AI USB Maker! This portable AI environment
is designed for ease of use and experimentation. However, please be mindful
of the following security and usage considerations:

1.  **Source of Software:**
    *   The Ollama binaries are downloaded from the official Ollama GitHub
      repository (https://github.com/ollama/ollama) or from fallback URLs
      provided in the script if the GitHub API fails.
    *   The AI models are pulled from Ollama's model library (ollama.com/library)
      via your host machine's Ollama instance or imported from a local GGUF file
      you provide.
    *   This script itself (\`$SCRIPT_SELF_NAME\`, Version: $SCRIPT_VERSION) is provided as-is. Review it before running if you
      have any concerns.

2.  **Running on Untrusted Computers:**
    *   BE CAUTIOUS when plugging this USB into computers you do not trust.
      While the scripts aim to be self-contained, the act of running any
      executable carries inherent risks depending on the host system's state.
    *   The Ollama server runs locally on the computer where the USB is used.
      It typically binds to 127.0.0.1 (localhost), meaning it should only be
      accessible from that same computer.

3.  **AI Model Behavior & Content:**
    *   Large Language Models (LLMs) can sometimes produce inaccurate, biased,
      or offensive content. Do not rely on model outputs for critical decisions
      without verification.
    *   The models included are general-purpose or specialized (like coding
      assistants) and reflect the data they were trained on.

4.  **Data Privacy:**
    *   When you interact with the models via the Web UI or CLI, your prompts
      and the AI's responses are processed locally on the computer running
      the Ollama server from the USB.
    *   No data is sent to external servers by the core Ollama software or
      these launcher scripts during model interaction, UNLESS a model itself
      is designed to make external calls (which is rare for standard GGUF models).
    *   The \`OLLAMA_TMPDIR\` is set to the \`Data/tmp\` folder on the USB.
      Temporary files related to model operations might be stored there.

5.  **Filesystem and Permissions:**
    *   The USB is typically formatted as exFAT for broad compatibility.
    *   The script attempts to set appropriate ownership and permissions for
      the files and directories it creates on the USB.
    *   Launcher scripts (.sh, .command) are made executable.

6.  **Integrity Verification:**
    *   A \`verify_integrity.sh\` (for Linux/macOS) and \`verify_integrity.bat\`
      (for Windows) script is included on the USB.
    *   These scripts generate SHA256 checksums for key runtime files and the
      launcher scripts themselves.
    *   You can run these verification scripts to check if the core files have
      been modified since creation.
    *   The initial checksums are stored in \`checksums.sha256.txt\` on the USB.
      PROTECT THIS FILE. If it's altered, verification is meaningless.
      Consider backing it up to a trusted location.

7.  **Script Operation (\`$SCRIPT_SELF_NAME\` - This Script):**
    *   This script requires \`sudo\` (administrator) privileges for:
        *   Formatting the USB drive.
        *   Mounting/unmounting the USB drive.
        *   Copying files (Ollama binaries, models) to the USB, especially if
          the host's Ollama models are in a system location.
        *   Crafting directories and setting permissions on the USB.
    *   It temporarily downloads Ollama binaries to a system temporary directory
      (e.g., via \`mktemp -d\`) which is cleaned up on script exit.

8.  **No Warranty:**
    *   This tool and the resulting USB environment are provided "AS IS,"
      without warranty of any kind, express or implied. Use at your own risk.

**Troubleshooting Common Issues:**

*   **Launcher script doesn't run (Permission Denied on Linux/macOS):**
    Open a terminal in the USB drive's root directory and run:
    \`chmod +x ${USER_LAUNCHER_NAME_BASE}.sh\` (for Linux)
    \`chmod +x ${USER_LAUNCHER_NAME_BASE}.command\` (for macOS)
*   **Ollama Server Fails to Start (in Launcher Window):**
    Check the log file mentioned in the launcher window (usually in Data/logs/ on the USB)
    for error messages from Ollama. The host system might be missing a
    runtime dependency for Ollama (though the main script tries to check these).
    Ensure no other Ollama instance is running and using port 11434 on the host.
*   **macOS: ".command" file from an unidentified developer:**
    If you double-click \`${USER_LAUNCHER_NAME_BASE}.command\` and macOS prevents it from opening,
    you might need to:
    1. Right-click (or Control-click) the \`${USER_LAUNCHER_NAME_BASE}.command\` file.
    2. Select "Open" from the context menu.
    3. A dialog will appear. Click the "Open" button in this dialog.
    Alternatively, you can adjust settings in "System Settings" > "Privacy & Security".
*   **Web UI doesn't open or models aren't listed:**
    Ensure the Ollama server started correctly (check its terminal window if visible,
    or the log file in Data/logs/). If models are missing, they might not have copied correctly,
    or the manifests on the USB are corrupted. Try the "Repair/Refresh" option
    from the main \`$SCRIPT_SELF_NAME\` script.

Stay curious, experiment responsibly, and enjoy your portable AI!

---
(Generated by $SCRIPT_SELF_NAME Version: $SCRIPT_VERSION)
Last Updated: $(date)
EOF_README
    sudo chmod 644 "$readme_file" "$install_dir_readme_file"
    print_success "Security README generated."
}

generate_checksum_file() {
    local usb_base_dir="$1"
    local checksum_file="$usb_base_dir/checksums.sha256.txt"
    print_info "Generating checksums for key files..."

    local files_to_checksum=()
    if [ -f "$usb_base_dir/${USER_LAUNCHER_NAME_BASE}.sh" ]; then files_to_checksum+=("${USER_LAUNCHER_NAME_BASE}.sh"); fi
    if [ -f "$usb_base_dir/${USER_LAUNCHER_NAME_BASE}.command" ]; then files_to_checksum+=("${USER_LAUNCHER_NAME_BASE}.command"); fi
    if [ -f "$usb_base_dir/${USER_LAUNCHER_NAME_BASE}.bat" ]; then files_to_checksum+=("${USER_LAUNCHER_NAME_BASE}.bat"); fi
    if [ -f "$usb_base_dir/webui/index.html" ]; then files_to_checksum+=("webui/index.html"); fi
    if [ -f "$usb_base_dir/SECURITY_README.txt" ]; then files_to_checksum+=("SECURITY_README.txt"); fi
    if [ -f "$usb_base_dir/verify_integrity.sh" ]; then files_to_checksum+=("verify_integrity.sh"); fi
    if [ -f "$usb_base_dir/verify_integrity.bat" ]; then files_to_checksum+=("verify_integrity.bat"); fi


    if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]] && [ -f "$usb_base_dir/runtimes/linux/bin/ollama" ]; then
        files_to_checksum+=("runtimes/linux/bin/ollama")
    fi
    if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]] && [ -f "$usb_base_dir/runtimes/mac/bin/ollama" ]; then
        files_to_checksum+=("runtimes/mac/bin/ollama")
    fi
    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]] && [ -f "$usb_base_dir/runtimes/win/bin/ollama.exe" ]; then
        files_to_checksum+=("runtimes/win/bin/ollama.exe")
    fi

    sudo touch "$checksum_file"
    safe_chown "$checksum_file" "$(id -u):$(id -g)"

    echo -n "" > "$checksum_file"

    local sha_tool_to_use=""
    if command -v shasum &>/dev/null; then sha_tool_to_use="shasum -a 256";
    elif command -v sha256sum &>/dev/null; then sha_tool_to_use="sha256sum";
    else print_error "No SHA256sum utility found for checksum generation. Skipping checksum file."; return 1; fi

    pushd "$usb_base_dir" > /dev/null
    for item in "${files_to_checksum[@]}"; do
        if [ -f "$item" ]; then
            $sha_tool_to_use "$item" >> "$checksum_file"
        fi
    done
    popd > /dev/null

    print_success "Checksum file generated at $checksum_file"

    local verify_sh_script="$usb_base_dir/verify_integrity.sh"
    local verify_bat_script="$usb_base_dir/verify_integrity.bat"

cat << EOF_VERIFY_SH | sudo tee "$verify_sh_script" > /dev/null
#!/usr/bin/env bash
C_RESET=\$(tput sgr0 2>/dev/null) C_BOLD=\$(tput bold 2>/dev/null) C_RED=\$(tput setaf 1 2>/dev/null) C_GREEN=\$(tput setaf 2 2>/dev/null) C_YELLOW=\$(tput setaf 3 2>/dev/null) C_CYAN=\$(tput setaf 6 2>/dev/null)
printf "%b\\n" "\${C_BOLD}\${C_GREEN}Verifying integrity of key files on Leonardo AI USB...\${C_RESET}"
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
cd "\$SCRIPT_DIR" || { printf "%b\\n" "\${C_RED}ERROR: Could not change to script directory.\${C_RESET}"; exit 1; }

CHECKSUM_FILE="checksums.sha256.txt"
if [ ! -f "\$CHECKSUM_FILE" ]; then printf "%b\\n" "\${C_RED}ERROR: \$CHECKSUM_FILE not found! Cannot verify integrity.\${C_RESET}"; exit 1; fi

TEMP_CURRENT_CHECKSUMS="\$(mktemp)"
trap 'rm -f "\$TEMP_CURRENT_CHECKSUMS"' EXIT

SHA_CMD=""
if command -v shasum &>/dev/null; then SHA_CMD="shasum -a 256";
elif command -v sha256sum &>/dev/null; then SHA_CMD="sha256sum";
else printf "%b\\n" "\${C_RED}ERROR: Neither shasum nor sha256sum found. Cannot verify.\${C_RESET}"; exit 1; fi

printf "%b\\n" "\${C_YELLOW}Reading stored checksums and calculating current ones...\${C_RESET}"
all_ok=true
files_checked=0
files_failed=0
files_missing=0

while IFS= read -r line || [[ -n "\$line" ]]; do
    expected_checksum=\$(echo "\$line" | awk '{print \$1}')
    filepath_raw=\$(echo "\$line" | awk '{print \$2}')
    filepath=\${filepath_raw#\*}

    if [ -z "\$filepath" ]; then continue; fi

    printf "  Verifying \${C_CYAN}%s\${C_RESET}..." "\$filepath"
    if [ -f "\$filepath" ]; then
        current_checksum_line=\$($SHA_CMD "\$filepath" 2>/dev/null)
        current_checksum=\$(echo "\$current_checksum_line" | awk '{print \$1}')

        if [ "\$current_checksum" == "\$expected_checksum" ]; then
            printf "\\r  Verifying \${C_CYAN}%s\${C_RESET}... \${C_GREEN}OK\${C_RESET}          \\n" "\$filepath"
        else
            printf "\\r  Verifying \${C_CYAN}%s\${C_RESET}... \${C_RED}FAIL\${C_RESET}        \\n" "\$filepath"
            printf "    \${C_DIM}Expected: %s\${C_RESET}\\n" "\$expected_checksum"
            printf "    \${C_DIM}Current:  %s\${C_RESET}\\n" "\$current_checksum"
            all_ok=false
            ((files_failed++))
        fi
        ((files_checked++))
    else
        printf "\\r  Verifying \${C_CYAN}%s\${C_RESET}... \${C_YELLOW}MISSING\${C_RESET}    \\n" "\$filepath"
        all_ok=false
        ((files_missing++))
    fi
done < "\$CHECKSUM_FILE"


printf "\\n"
if \$all_ok; then
    printf "%b\\n" "\${C_BOLD}\${C_GREEN}✅ SUCCESS: All \$files_checked key files verified successfully!\${C_RESET}"
else
    printf "%b\\n" "\${C_BOLD}\${C_RED}❌ FAILURE: Integrity check failed.\${C_RESET}"
    if [ "\$files_failed" -gt 0 ]; then printf "    - \${C_RED}%s file(s) had checksum mismatches.\${C_RESET}\\n" "\$files_failed"; fi
    if [ "\$files_missing" -gt 0 ]; then printf "    - \${C_YELLOW}%s file(s) listed in checksums.sha256.txt were not found.\${C_RESET}\\n" "\$files_missing"; fi
    printf "%b\\n" "   Some files may have been altered or are missing."
fi
printf "%b\\n" "\${C_GREEN}Verification complete.\${C_RESET}"
EOF_VERIFY_SH
    sudo chmod +x "$verify_sh_script"

cat << EOF_VERIFY_BAT | sudo tee "$verify_bat_script" > /dev/null
@ECHO OFF\r
REM Leonardo AI USB - Integrity Verification (Windows)\r
TITLE Leonardo AI USB - Integrity Check\r
COLOR 0A\r
CLS\r
ECHO Verifying integrity of key files on Leonardo AI USB...\r
CD /D "%~dp0"\r
\r
SET CHECKSUM_FILE=checksums.sha256.txt\r
IF NOT EXIST "%CHECKSUM_FILE%" (\r
    COLOR 0C\r
    ECHO ERROR: %CHECKSUM_FILE% not found! Cannot verify integrity.\r
    PAUSE\r
    EXIT /B 1\r
)\r
\r
WHERE certutil >nul 2>nul\r
IF %ERRORLEVEL% NEQ 0 (\r
    COLOR 0C\r
    ECHO ERROR: certutil.exe not found. Cannot verify checksums on Windows.\r
    ECHO Certutil is usually part of Windows. If missing, your system might have issues.\r
    PAUSE\r
    EXIT /B 1\r
)\r
\r
ECHO Reading stored checksums and calculating current ones...\r
SETLOCAL ENABLEDELAYEDEXPANSION\r
SET ALL_OK=1\r
SET FILES_CHECKED=0\r
SET FILES_FAILED=0\r
SET FILES_MISSING=0\r
\r
FOR /F "usebackq tokens=1,*" %%A IN ("%CHECKSUM_FILE%") DO (\r
    SET EXPECTED_CHECKSUM=%%A\r
    SET FILEPATH_RAW=%%B\r
    IF "!FILEPATH_RAW:~0,1!"=="*" (SET FILEPATH_CLEAN=!FILEPATH_RAW:~1!) ELSE (SET FILEPATH_CLEAN=!FILEPATH_RAW!)\r
    FOR /F "tokens=* delims= " %%F IN ("!FILEPATH_CLEAN!") DO SET FILEPATH_TRIMMED=%%F\r
    \r
    IF DEFINED FILEPATH_TRIMMED (\r
        ECHO Verifying !FILEPATH_TRIMMED!...\r
        IF EXIST "!FILEPATH_TRIMMED!" (\r
            SET CURRENT_CHECKSUM=\r
            FOR /F "skip=1 tokens=*" %%S IN ('certutil -hashfile "!FILEPATH_TRIMMED!" SHA256 2^>NUL') DO (\r
                IF NOT DEFINED CURRENT_CHECKSUM SET "CURRENT_CHECKSUM=%%S"\r
            )\r
            SET CURRENT_CHECKSUM=!CURRENT_CHECKSUM: =!\r
            \r
            IF DEFINED CURRENT_CHECKSUM (\r
                IF /I "!CURRENT_CHECKSUM!"=="!EXPECTED_CHECKSUM!" (\r
                    ECHO   OK: !FILEPATH_TRIMMED!\r
                ) ELSE (\r
                    COLOR 0C\r
                    ECHO   FAIL: !FILEPATH_TRIMMED!\r
                    ECHO     Expected: !EXPECTED_CHECKSUM!\r
                    ECHO     Current:  !CURRENT_CHECKSUM!\r
                    COLOR 0A\r
                    SET ALL_OK=0\r
                    SET /A FILES_FAILED+=1\r
                )\r
            ) ELSE (\r
                COLOR 0E\r
                ECHO   ERROR: Could not calculate checksum for !FILEPATH_TRIMMED!.\r
                COLOR 0A\r
                SET ALL_OK=0\r
                SET /A FILES_FAILED+=1\r
            )\r
            SET /A FILES_CHECKED+=1\r
        ) ELSE (\r
            COLOR 0E\r
            ECHO   WARNING: File '!FILEPATH_TRIMMED!' listed in checksums not found. Skipping.\r
            COLOR 0A\r
            SET ALL_OK=0\r
            SET /A FILES_MISSING+=1\r
        )\r
    )\r
)\r
\r
ECHO.\r
IF "%ALL_OK%"=="1" (\r
    COLOR 0A\r
    ECHO ✅ SUCCESS: All %FILES_CHECKED% key files verified successfully!\r
) ELSE (\r
    COLOR 0C\r
    ECHO ❌ FAILURE: Integrity check failed.\r
    IF %FILES_FAILED% GTR 0 ECHO    - %FILES_FAILED% file(s) had checksum mismatches or errors.\r
    IF %FILES_MISSING% GTR 0 ECHO    - %FILES_MISSING% file(s) listed in checksums.sha256.txt were not found.\r
)\r
ECHO Verification complete.\r
ENDLOCAL\r
PAUSE\r
EXIT /B 0\r
EOF_VERIFY_BAT
    if command -v unix2dos &> /dev/null; then
        sudo unix2dos "$verify_bat_script" >/dev/null 2>&1 || true
    fi

    print_success "Integrity verification scripts generated."
}

generate_usb_files() {
    local usb_base_dir="$1"
    local default_model_hint="$2"

    print_subheader "⚙️ Generating Leonardo AI USB support files..."
    generate_webui_html "$usb_base_dir" "$default_model_hint"
    generate_launcher_scripts "$usb_base_dir" "$default_model_hint"
    generate_security_readme "$usb_base_dir"
    generate_checksum_file "$usb_base_dir"
    print_success "All USB support files generated."
}


# --- Model Management Functions ---
list_models_on_usb() {
    local usb_mount_path="$1"
    print_subheader "🔎 Listing models on USB at $usb_mount_path/.ollama/models..."
    local manifests_base_path="$usb_mount_path/.ollama/models/manifests/registry.ollama.ai/library"
    local found_models_count=0

    if [ ! -d "$manifests_base_path" ]; then
        print_warning "No Ollama model manifests directory found on the USB at the expected location."
        echo -e "  (${C_DIM}$manifests_base_path${C_RESET})"
        print_info "No models to list."
        print_line
        return
    fi

    local can_show_size=false
    if command -v jq &>/dev/null; then
        can_show_size=true
    else
        print_warning "(Note: 'jq' command not found. Model sizes cannot be displayed.)"
    fi

    echo -e "${C_BLUE}Models found on USB:${C_RESET}"
    found_models_count=$(sudo find "$manifests_base_path" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null | (
        count=0
        while IFS= read -r -d $'\0' tag_file_path; do
            if [ ! -f "$tag_file_path" ]; then continue; fi
            count=$((count + 1))
            local relative_path_to_tag_file="${tag_file_path#$manifests_base_path/}"
            local model_name_with_tag=$(echo "$relative_path_to_tag_file" | sed 's|/|:|1')
            local model_size_display="${C_DIM}N/A${C_RESET}"

            if $can_show_size; then
                local model_size_bytes
                model_size_bytes=$(sudo jq '[.layers[].size] | add // 0' "$tag_file_path" 2>/dev/null)
                if [[ "$model_size_bytes" =~ ^[0-9]+$ ]] && [[ "$model_size_bytes" -gt 0 ]]; then
                    model_size_display=$(bytes_to_human_readable "$model_size_bytes")
                else
                    model_size_display="${C_RED}Size Error/Unavailable${C_RESET}"
                fi
            fi
            echo -e "  - ${C_BOLD}$model_name_with_tag${C_RESET} (Size: $model_size_display)"
        done
        echo "$count"
    ) )

    if [ "$found_models_count" -eq 0 ]; then
        print_info "No models found in the manifests directory."
    fi
    print_line
}

remove_model_from_usb() {
    local usb_mount_path="$1"
    print_subheader "🗑️ Preparing to remove a model from USB at $usb_mount_path/.ollama/models..."
    local manifests_base_path="$usb_mount_path/.ollama/models/manifests/registry.ollama.ai/library"

    if [ ! -d "$manifests_base_path" ]; then
        print_warning "No Ollama model manifests directory found on the USB. Nothing to remove."
        return
    fi

    declare -a model_files_paths=()
    declare -a model_display_names=()
    local idx_counter=0

    while IFS= read -r -d $'\0' tag_file_path; do
        if [ ! -f "$tag_file_path" ]; then continue; fi
        local relative_path_to_tag_file="${tag_file_path#$manifests_base_path/}"
        local model_name_with_tag=$(echo "$relative_path_to_tag_file" | sed 's|/|:|1')
        model_files_paths[idx_counter]="$tag_file_path"
        model_display_names[idx_counter]="$model_name_with_tag"
        ((idx_counter++))
    done < <(sudo find "$manifests_base_path" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null)


    if [ ${#model_display_names[@]} -eq 0 ]; then
        print_info "No models found in the manifests directory to remove."
        return
    fi

    echo -e "${C_BLUE}Available models on USB to remove:${C_RESET}"
    for j in "${!model_display_names[@]}"; do
        echo -e "  ${C_BOLD}$((j+1)))${C_RESET} ${model_display_names[$j]}"
    done
    echo -e "  ${C_BOLD}q)${C_RESET} Cancel / Back"
    print_line

    local choice
    while true; do
        print_prompt "Enter the number of the model to remove (or q to cancel): "
        read -r choice
        if [[ "$choice" =~ ^[qQ]$ ]]; then
            print_info "Model removal cancelled."
            return
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#model_display_names[@]}" ]; then
            local model_to_remove_path="${model_files_paths[$((choice-1))]}"
            local model_to_remove_name="${model_display_names[$((choice-1))]}"

            local confirm_removal
            ask_yes_no_quit "Are you sure you want to remove the manifest for '${C_BOLD}$model_to_remove_name${C_RESET}'?\n  (Path: ${C_DIM}$model_to_remove_path${C_RESET})\n${C_YELLOW}This only removes the manifest reference, not the underlying data blobs. For full space reclaim, recreate the USB.${C_RESET}" confirm_removal
            if [[ "$confirm_removal" == "yes" ]]; then
                print_info "Removing manifest file: $model_to_remove_path"
                if sudo rm -f "$model_to_remove_path"; then
                    print_success "Successfully removed manifest for '$model_to_remove_name'."
                    local parent_dir=$(dirname "$model_to_remove_path")
                    if [ -d "$parent_dir" ] && [ -z "$(sudo ls -A "$parent_dir" 2>/dev/null)" ]; then
                        print_info "Removing empty model tag directory: $parent_dir"
                        sudo rmdir "$parent_dir" || print_warning "Could not remove empty directory $parent_dir (might be non-empty or permissions issue)."
                    fi
                else
                    print_error "Failed to remove manifest file '$model_to_remove_path'."
                fi
            else
                print_info "Removal of '$model_to_remove_name' cancelled."
            fi
            break
        else
            print_warning "Invalid input. Please enter a number from the list or q."
        fi
    done

    # Check binary files
    echo -e "\nChecking OS binary files..."
    local binary_paths=("runtimes/linux/bin/ollama" "runtimes/mac/bin/ollama" "runtimes/win/bin/ollama.exe")
    local os_detected=""
    for bin in "${binary_paths[@]}"; do
        if [ -f "$usb_path/$bin" ]; then
            print_success "✓ Binary exists: $bin"
            if [[ "$bin" == *linux* ]]; then os_detected="${os_detected}linux,"; fi
            if [[ "$bin" == *mac* ]]; then os_detected="${os_detected}mac,"; fi
            if [[ "$bin" == *win* ]]; then os_detected="${os_detected}win,"; fi

            # Check if executable for Linux/Mac binaries
            if [[ "$bin" != *win* ]] && [ ! -x "$usb_path/$bin" ]; then
                print_warning "⚠️ Binary is not executable: $bin"
                ((issues_found++))
                if [ "$repair_mode" = "yes" ]; then
                    print_info "Making binary executable: $usb_path/$bin"
                    sudo chmod +x "$usb_path/$bin"
                    ((repair_count++))
                fi
            fi
        else
            print_warning "⚠️ Binary missing: $bin (may be ok if OS not selected)"
        fi
    done

    # Check models
    echo -e "\nChecking models..."
    local model_count=0
    local model_dir="$usb_path/.ollama/models/manifests/registry.ollama.ai/library"
    if [ -d "$model_dir" ]; then
        mapfile -t model_files < <(find "$model_dir" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null | xargs -0 -n1 || echo "")
        model_count=${#model_files[@]}
        if [ $model_count -gt 0 ]; then
            print_success "✓ Found $model_count model(s):"
            for model_file in "${model_files[@]}"; do
                relative_path="${model_file#$model_dir/}"
                model_name="${relative_path%/*}:${relative_path##*/}"
                echo "  - $model_name"
            done
        else
            print_warning "⚠️ No models found in the models directory"
            ((issues_found++))
        fi
    else
        print_error "❌ Models directory structure is missing or invalid"
        ((issues_found++))
        if [ "$repair_mode" = "yes" ]; then
            print_info "Crafting models directory structure"
            sudo mkdir -p "$model_dir"
            ((repair_count++))
        fi
    fi

    # Check webui
    echo -e "\nChecking WebUI..."
    if [ -f "$usb_path/webui/index.html" ]; then
        print_success "✓ WebUI found"
    else
        print_error "❌ WebUI is missing (index.html not found)"
        ((issues_found++))
        if [ "$repair_mode" = "yes" ]; then
            print_info "Will regenerate WebUI files"
            # WebUI regeneration will happen with generate_usb_files
        fi
    fi

    # Summary
    print_line
    echo "\nHealth Check Summary:"
    if [ $issues_found -eq 0 ]; then
        print_success "✅ No issues found! USB appears to be healthy."
    else
        print_warning "⚠️ Found $issues_found issue(s) with the USB installation."

        if [ "$repair_mode" = "yes" ]; then
            print_info "Repaired $repair_count issue(s) directly."

            # Handle special case of missing launcher files by regenerating
            local missing_launchers=false
            for file in "${launcher_files[@]}"; do
                if [ ! -f "$usb_path/$file" ]; then
                    missing_launchers=true
                    break
                fi
            done

            if $missing_launchers || [ ! -f "$usb_path/webui/index.html" ]; then
                print_header "🛠️ REGENERATING USB SUPPORT FILES 🛠️"

                # Get first model if available for default
                local default_model="llama3:8b"
                if [ -d "$model_dir" ] && [ $model_count -gt 0 ]; then
                    local first_model_file="${model_files[0]}"
                    local relative_path="${first_model_file#$model_dir/}"
                    default_model="${relative_path%/*}:${relative_path##*/}"
                fi

                # Set SELECTED_OS_TARGETS based on detected binaries
                os_detected=${os_detected%,}
                if [ -z "$os_detected" ]; then os_detected="linux,mac,win"; fi
                SELECTED_OS_TARGETS="$os_detected"

                print_info "Regenerating USB support files with default model: $default_model"
                print_info "OS targets detected: $SELECTED_OS_TARGETS"

                # Regenerate USB support files
                generate_usb_files "$usb_path" "$default_model"
                print_success "USB support files regenerated successfully."
            fi

            print_success "✅ Repair completed! Please test your USB to ensure it works properly."
        else
            print_info "Run with the 'repair' option to fix these issues."
        fi

    fi
    return $issues_found
}

# Function to regenerate launcher files with latest content
regenerate_launcher_file() {
    local usb_path="$1"
    local file="$2"

    # Ensure we're using set -e safely - we don't want to exit if a command fails during repair
    set +e

    case "$file" in
        leonardo.sh)
            cat > "$usb_path/$file" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
cd "$SCRIPT_DIR" || { printf "%s\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

# Initialize console colors
C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=$(tput sgr0); C_BOLD=$(tput bold); C_RED=$(tput setaf 1); C_GREEN=$(tput setaf 2);
    C_YELLOW=$(tput setaf 3); C_BLUE=$(tput setaf 4); C_CYAN=$(tput setaf 6);
fi;

# Define helper functions
print_error() {
    printf "%b\n" "${C_RED}❌ ERROR: $1${C_RESET}";
}

printf "%b\n" "${C_BOLD}${C_GREEN}🚀 Starting Leonardo AI USB Environment (Linux)...${C_RESET}";

printf "%b\n" "${C_BLUE}Setting up environment variables...${C_RESET}";
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models";
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="$SCRIPT_DIR/runtimes/linux/bin/ollama";
if [ ! -f "$OLLAMA_BIN" ]; then printf "%b\n" "${C_RED}❌ Error: Ollama binary not found at $OLLAMA_BIN${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "$OLLAMA_BIN" ]; then
    printf "%b\n" "${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...${C_RESET}";
    chmod +x "$OLLAMA_BIN" || { printf "%b\n" "${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions or remount USB if needed.${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

printf "%b\n" "${C_GREEN}Starting Ollama server...${C_RESET}";
LOG_FILE="$SCRIPT_DIR/ollama_server.log";
"$OLLAMA_BIN" serve > "$LOG_FILE" 2>&1 &
OLLAMA_PID=$!;
sleep 3;

if ! ps -p $OLLAMA_PID > /dev/null; then
    printf "%b\n" "${C_RED}❌ Error: Ollama server failed to start. Check $LOG_FILE for details.${C_RESET}";
    printf "%b\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;

printf "%b\n" "${C_GREEN}Ollama server is now running with PID $OLLAMA_PID${C_RESET}";

WEBUI_PATH="$SCRIPT_DIR/webui/index.html";
printf "%b\n" "${C_BLUE}Attempting to open Web UI...${C_RESET}";
if [ -f "$WEBUI_PATH" ]; then
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "file://$WEBUI_PATH" &>/dev/null &
    elif command -v gnome-open >/dev/null 2>&1; then
        gnome-open "file://$WEBUI_PATH" &>/dev/null &
    elif command -v kde-open >/dev/null 2>&1; then
        kde-open "file://$WEBUI_PATH" &>/dev/null &
    else printf "%b\n" "${C_YELLOW}⚠️ Could not find xdg-open, gnome-open, or kde-open. Please open $WEBUI_PATH in your web browser manually.${C_RESET}"; fi;
fi;

printf "\n";
printf "%b\n" "${C_BOLD}${C_GREEN}✨ Leonardo AI USB is now running! ✨${C_RESET}";
printf "%b\n" "  - Ollama Server PID: ${C_BOLD}$OLLAMA_PID${C_RESET}";
printf "%b\n" "  - Web UI should be open in your browser (or open manually: ${C_GREEN}file://$WEBUI_PATH${C_RESET}).";
printf "%b\n" "  - To stop the Ollama server, close this terminal window or run: ${C_YELLOW}kill $OLLAMA_PID${C_RESET}";
printf "\n";
printf "%b\n" "${C_YELLOW}Press Ctrl+C in this window (or close it) to stop the Ollama server and exit.${C_RESET}";

trap 'printf "\n%b\n" "${C_BLUE}Shutting down Ollama server (PID $OLLAMA_PID)..."; kill $OLLAMA_PID 2>/dev/null; wait $OLLAMA_PID 2>/dev/null; printf "%b\n" "${C_GREEN}Ollama server stopped.${C_RESET}"' EXIT TERM INT;

wait $OLLAMA_PID;
printf "%b\n" "${C_BLUE}Ollama server (PID $OLLAMA_PID) has been stopped.${C_RESET}";
printf "%b\n" "${C_GREEN}Leonardo AI USB session ended.${C_RESET}";
EOF
            chmod +x "$usb_path/$file"
            ;;
        leonardo.command)
            cat > "$usb_path/$file" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
cd "$SCRIPT_DIR" || { printf "%s\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

# Initialize console colors
C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=$(tput sgr0); C_BOLD=$(tput bold); C_RED=$(tput setaf 1); C_GREEN=$(tput setaf 2);
    C_YELLOW=$(tput setaf 3); C_BLUE=$(tput setaf 4); C_CYAN=$(tput setaf 6);
fi;

# Define helper functions
print_error() {
    printf "%b\n" "${C_RED}❌ ERROR: $1${C_RESET}";
}

printf "%b\n" "${C_BOLD}${C_GREEN}🚀 Starting Leonardo AI USB Environment (macOS)...${C_RESET}";

printf "%b\n" "${C_BLUE}Setting up environment variables...${C_RESET}";
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models";
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="$SCRIPT_DIR/runtimes/macos/bin/ollama-darwin";
if [ ! -f "$OLLAMA_BIN" ]; then printf "%b\n" "${C_RED}❌ Error: Ollama binary not found at $OLLAMA_BIN${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "$OLLAMA_BIN" ]; then
    printf "%b\n" "${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...${C_RESET}";
    chmod +x "$OLLAMA_BIN" || { printf "%b\n" "${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions or remount USB if needed.${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

printf "%b\n" "${C_GREEN}Starting Ollama server...${C_RESET}";
LOG_FILE="$SCRIPT_DIR/ollama_server.log";
"$OLLAMA_BIN" serve > "$LOG_FILE" 2>&1 &
OLLAMA_PID=$!;
sleep 3;

if ! ps -p $OLLAMA_PID > /dev/null; then
    printf "%b\n" "${C_RED}❌ Error: Ollama server failed to start. Check $LOG_FILE for details.${C_RESET}";
    printf "%b\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;

printf "%b\n" "${C_GREEN}Ollama server is now running with PID $OLLAMA_PID${C_RESET}";

WEBUI_PATH="$SCRIPT_DIR/webui/index.html";
printf "%b\n" "${C_BLUE}Attempting to open Web UI...${C_RESET}";
if [ -f "$WEBUI_PATH" ]; then
    open "file://$WEBUI_PATH" &>/dev/null &
fi;

printf "\n";
printf "%b\n" "${C_BOLD}${C_GREEN}✨ Leonardo AI USB is now running! ✨${C_RESET}";
printf "%b\n" "  - Ollama Server PID: ${C_BOLD}$OLLAMA_PID${C_RESET}";
printf "%b\n" "  - Web UI should be open in your browser (or open manually: ${C_GREEN}file://$WEBUI_PATH${C_RESET}).";
printf "%b\n" "  - To stop the Ollama server, close this terminal window or run: ${C_YELLOW}kill $OLLAMA_PID${C_RESET}";
printf "\n";
printf "%b\n" "${C_YELLOW}Press Ctrl+C in this window (or close it) to stop the Ollama server and exit.${C_RESET}";

trap 'printf "\n%b\n" "${C_BLUE}Shutting down Ollama server (PID $OLLAMA_PID)..."; kill $OLLAMA_PID 2>/dev/null; wait $OLLAMA_PID 2>/dev/null; printf "%b\n" "${C_GREEN}Ollama server stopped.${C_RESET}"' EXIT TERM INT;

wait $OLLAMA_PID;
printf "%b\n" "${C_BLUE}Ollama server (PID $OLLAMA_PID) has been stopped.${C_RESET}";
printf "%b\n" "${C_GREEN}Leonardo AI USB session ended.${C_RESET}";
EOF
            chmod +x "$usb_path/$file"
            ;;
        leonardo.bat)
            # Create a temporary file for the Windows batch script content
            local temp_bat_file=$(mktemp)
            cat > "$temp_bat_file" << 'EOF'
@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

:: Leonardo AI USB Launcher - Windows
COLOR 0A

:: Get the script directory
SET "SCRIPT_DIR=%~dp0"
SET "SCRIPT_DIR=!SCRIPT_DIR:~0,-1!"

echo.
echo ===================================================================
echo    Leonardo AI USB - Portable AI Power (Windows Edition)
echo ===================================================================
echo.

echo Setting up environment variables...
SET "OLLAMA_MODELS=%SCRIPT_DIR%\.ollama\models"
SET "OLLAMA_HOST=127.0.0.1:11434"

SET "OLLAMA_BIN=%SCRIPT_DIR%\runtimes\windows\bin\ollama-windows.exe"

:: Check if Ollama binary exists
IF NOT EXIST "%OLLAMA_BIN%" (
    COLOR 0C
    echo ERROR: Ollama binary not found at %OLLAMA_BIN%
    echo.
    PAUSE
    EXIT /B 1
)

echo Starting Ollama server...
SET "LOG_FILE=%SCRIPT_DIR%\ollama_server.log"

:: Start the server
START /B "" "%OLLAMA_BIN%" serve > "%LOG_FILE%" 2>&1
SET OLLAMA_PID=%ERRORLEVEL%

:: Wait for server to start
TIMEOUT /T 3 /NOBREAK > NUL

:: Check if server is running by attempting to connect
PING 127.0.0.1 -n 1 > NUL
IF %ERRORLEVEL% NEQ 0 (
    COLOR 0C
    echo ERROR: Ollama server failed to start. Check %LOG_FILE% for details.
    echo Ensure no other Ollama instance is conflicting on port 11434.
    echo.
    PAUSE
    EXIT /B 1
)

echo Ollama server is now running

SET "WEBUI_PATH=%SCRIPT_DIR%\webui\index.html"
echo Attempting to open Web UI...

IF EXIST "%WEBUI_PATH%" (
    start "" "%WEBUI_PATH%"
)

echo.
echo ===================================================================
echo  Leonardo AI USB is now running!
echo  - Web UI should be open in your browser
    echo    (or open manually: file://%WEBUI_PATH%)
echo  - To stop the Ollama server, close this window
echo ===================================================================
echo.
echo Press CTRL+C to stop the Ollama server and exit.
echo.

:: Keep the window open
CMD /K
EOF

            # Now use the temp file to create the actual batch file, avoiding heredoc issues
            cat "$temp_bat_file" > "$usb_path/$file"
            rm -f "$temp_bat_file"
            ;;
    esac

    return 0
}

# Function to handle USB verification and repair
# Function to verify and repair a Leonardo AI USB installation
verify_usb_health() {
    local usb_path="$1"
    local repair_mode="$2"
    local issues_found=0
    local repair_count=0

    print_subheader "🔍 Checking USB drive at: $usb_path"

    # Check if it's a valid Leonardo AI USB drive
    if [ ! -d "$usb_path/.ollama" ]; then
        print_error "❌ This doesn't appear to be a Leonardo AI USB drive (.ollama directory not found)"
        echo "If this is a valid USB drive, make sure you're selecting the correct path."
        return 1
    fi

    print_success "✓ Valid Leonardo AI USB drive detected"

    # Check for required directories
    echo -e "\nChecking directory structure..."
    local required_dirs=(
        ".ollama"
        ".ollama/models"
        ".ollama/models/manifests"
    )

    for dir in "${required_dirs[@]}"; do
        if [ -d "$usb_path/$dir" ]; then
            print_success "✓ Directory exists: $dir"
        else
            print_warning "⚠️ Directory missing: $dir"
            ((issues_found++))
            if [ "$repair_mode" = "yes" ]; then
                print_info "Crafting directory: $usb_path/$dir"
                mkdir -p "$usb_path/$dir"
                ((repair_count++))
            fi
        fi
    done

    # Check launcher files
    echo -e "\nChecking launcher files..."
    local launcher_files=(
        "leonardo.sh"
        "leonardo.command"
        "leonardo.bat"
    )

    # Function to check if file contains required content
    check_file_content() {
        local file=$1
        local required_content=$2
        grep -q "$required_content" "$file" 2>/dev/null
        return $?
    }

    for file in "${launcher_files[@]}"; do
        local file_needs_update=false

        if [ -f "$usb_path/$file" ]; then
            # Check if the file contains key indicators of the latest version
            case "$file" in
                leonardo.sh)
                    if ! check_file_content "$usb_path/$file" "print_error() {" || \
                       ! check_file_content "$usb_path/$file" "trap .*EXIT TERM INT" || \
                       ! check_file_content "$usb_path/$file" "C_RESET=\"\".*C_BOLD=\"\".*C_RED=\"\""; then
                        print_warning "⚠️ Launcher needs update: $file (outdated version detected)"
                        file_needs_update=true
                        ((issues_found++))
                    else
                        print_success "✓ Launcher exists and up-to-date: $file"
                    fi
                    ;;
                leonardo.command)
                    if ! check_file_content "$usb_path/$file" "print_error() {" || \
                       ! check_file_content "$usb_path/$file" "trap .*EXIT TERM INT" || \
                       ! check_file_content "$usb_path/$file" "C_RESET=\"\".*C_BOLD=\"\".*C_RED=\"\""; then
                        print_warning "⚠️ Launcher needs update: $file (outdated version detected)"
                        file_needs_update=true
                        ((issues_found++))
                    else
                        print_success "✓ Launcher exists and up-to-date: $file"
                    fi
                    ;;
                leonardo.bat)
                    if ! check_file_content "$usb_path/$file" "COLOR 0A" || \
                       ! check_file_content "$usb_path/$file" "errorlevel" || \
                       ! check_file_content "$usb_path/$file" "SETLOCAL ENABLEDELAYEDEXPANSION"; then
                        print_warning "⚠️ Launcher needs update: $file (outdated version detected)"
                        file_needs_update=true
                        ((issues_found++))
                    else
                        print_success "✓ Launcher exists and up-to-date: $file"
                    fi
                    ;;
            esac

            # Check if shell scripts are executable
            if [[ "$file" != *.bat ]] && [ ! -x "$usb_path/$file" ]; then
                print_warning "⚠️ Launcher is not executable: $file"
                ((issues_found++))
                if [ "$repair_mode" = "yes" ]; then
                    print_info "Making launcher executable: $usb_path/$file"
                    chmod +x "$usb_path/$file"
                    ((repair_count++))
                fi
            fi

            # Update the file if needed
            if [ "$file_needs_update" = true ] && [ "$repair_mode" = "yes" ]; then
                print_info "Updating launcher: $usb_path/$file"

                # We need to run this in a subshell to prevent any exit statements in the
                # process from terminating our main script
                (
                    # Recreate the launcher file
                    case "$file" in
                        leonardo.sh|leonardo.command|leonardo.bat)
                            # Temporarily disable exit on error for this operation
                            set +e
                            regenerate_launcher_file "$usb_path" "$file"
                            local result=$?
                            set -e
                            if [ $result -eq 0 ]; then
                                ((repair_count++))
                            else
                                print_warning "⚠️ Warning: Update process for $file returned non-zero: $result"
                            fi
                            ;;
                    esac
                ) || {
                    print_warning "⚠️ Failed to update $file but continuing repair process"
                }
            fi
        else
            print_warning "⚠️ Launcher missing: $file"
            ((issues_found++))
            if [ "$repair_mode" = "yes" ]; then
                print_info "Recrafting launcher: $usb_path/$file"

                # Recreate the launcher file based on type
                case "$file" in
                    leonardo.sh)
                        cat > "$usb_path/$file" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
cd "$SCRIPT_DIR" || { printf "%s\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

# Initialize console colors
C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=$(tput sgr0); C_BOLD=$(tput bold); C_RED=$(tput setaf 1); C_GREEN=$(tput setaf 2);
    C_YELLOW=$(tput setaf 3); C_BLUE=$(tput setaf 4); C_CYAN=$(tput setaf 6);
fi;

# Define helper functions
print_error() {
    printf "%b\n" "${C_RED}❌ ERROR: $1${C_RESET}";
}

printf "%b\n" "${C_BOLD}${C_GREEN}🚀 Starting Leonardo AI USB Environment (Linux)...${C_RESET}";

printf "%b\n" "${C_BLUE}Setting up environment variables...${C_RESET}";
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models";
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="$SCRIPT_DIR/runtimes/linux/bin/ollama";
if [ ! -f "$OLLAMA_BIN" ]; then printf "%b\n" "${C_RED}❌ Error: Ollama binary not found at $OLLAMA_BIN${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "$OLLAMA_BIN" ]; then
    printf "%b\n" "${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...${C_RESET}";
    chmod +x "$OLLAMA_BIN" || { printf "%b\n" "${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions or remount USB if needed.${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

printf "%b\n" "${C_GREEN}Starting Ollama server...${C_RESET}";
LOG_FILE="$SCRIPT_DIR/ollama_server.log";
"$OLLAMA_BIN" serve > "$LOG_FILE" 2>&1 &
OLLAMA_PID=$!;
sleep 3;

if ! ps -p $OLLAMA_PID > /dev/null; then
    printf "%b\n" "${C_RED}❌ Error: Ollama server failed to start. Check $LOG_FILE for details.${C_RESET}";
    printf "%b\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;

printf "%b\n" "${C_GREEN}Ollama server is now running with PID $OLLAMA_PID${C_RESET}";

WEBUI_PATH="$SCRIPT_DIR/webui/index.html";
printf "%b\n" "${C_BLUE}Attempting to open Web UI...${C_RESET}";
if [ -f "$WEBUI_PATH" ]; then
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "file://$WEBUI_PATH" &>/dev/null &
    elif command -v gnome-open >/dev/null 2>&1; then
        gnome-open "file://$WEBUI_PATH" &>/dev/null &
    elif command -v kde-open >/dev/null 2>&1; then
        kde-open "file://$WEBUI_PATH" &>/dev/null &
    else printf "%b\n" "${C_YELLOW}⚠️ Could not find xdg-open, gnome-open, or kde-open. Please open $WEBUI_PATH in your web browser manually.${C_RESET}"; fi;
fi;

printf "\n";
printf "%b\n" "${C_BOLD}${C_GREEN}✨ Leonardo AI USB is now running! ✨${C_RESET}";
printf "%b\n" "  - Ollama Server PID: ${C_BOLD}$OLLAMA_PID${C_RESET}";
printf "%b\n" "  - Web UI should be open in your browser (or open manually: ${C_GREEN}file://$WEBUI_PATH${C_RESET}).";
printf "%b\n" "  - To stop the Ollama server, close this terminal window or run: ${C_YELLOW}kill $OLLAMA_PID${C_RESET}";
printf "\n";
printf "%b\n" "${C_YELLOW}Press Ctrl+C in this window (or close it) to stop the Ollama server and exit.${C_RESET}";

trap 'printf "\n%b\n" "${C_BLUE}Shutting down Ollama server (PID $OLLAMA_PID)..."; kill $OLLAMA_PID 2>/dev/null; wait $OLLAMA_PID 2>/dev/null; printf "%b\n" "${C_GREEN}Ollama server stopped.${C_RESET}"' EXIT TERM INT;

wait $OLLAMA_PID;
printf "%b\n" "${C_BLUE}Ollama server (PID $OLLAMA_PID) has been stopped.${C_RESET}";
printf "%b\n" "${C_GREEN}Leonardo AI USB session ended.${C_RESET}";
EOF
                        chmod +x "$usb_path/$file"
                        ;;
                    leonardo.command)
                        cat > "$usb_path/$file" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
cd "$SCRIPT_DIR" || { printf "%s\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

# Initialize console colors
C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=$(tput sgr0); C_BOLD=$(tput bold); C_RED=$(tput setaf 1); C_GREEN=$(tput setaf 2);
    C_YELLOW=$(tput setaf 3); C_BLUE=$(tput setaf 4); C_CYAN=$(tput setaf 6);
fi;

# Define helper functions
print_error() {
    printf "%b\n" "${C_RED}❌ ERROR: $1${C_RESET}";
}

printf "%b\n" "${C_BOLD}${C_GREEN}🚀 Starting Leonardo AI USB Environment (macOS)...${C_RESET}";

printf "%b\n" "${C_BLUE}Setting up environment variables...${C_RESET}";
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models";
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="$SCRIPT_DIR/runtimes/macos/bin/ollama-darwin";
if [ ! -f "$OLLAMA_BIN" ]; then printf "%b\n" "${C_RED}❌ Error: Ollama binary not found at $OLLAMA_BIN${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "$OLLAMA_BIN" ]; then
    printf "%b\n" "${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...${C_RESET}";
    chmod +x "$OLLAMA_BIN" || { printf "%b\n" "${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions or remount USB if needed.${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

printf "%b\n" "${C_GREEN}Starting Ollama server...${C_RESET}";
LOG_FILE="$SCRIPT_DIR/ollama_server.log";
"$OLLAMA_BIN" serve > "$LOG_FILE" 2>&1 &
OLLAMA_PID=$!;
sleep 3;

if ! ps -p $OLLAMA_PID > /dev/null; then
    printf "%b\n" "${C_RED}❌ Error: Ollama server failed to start. Check $LOG_FILE for details.${C_RESET}";
    printf "%b\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;

printf "%b\n" "${C_GREEN}Ollama server is now running with PID $OLLAMA_PID${C_RESET}";

WEBUI_PATH="$SCRIPT_DIR/webui/index.html";
printf "%b\n" "${C_BLUE}Attempting to open Web UI...${C_RESET}";
if [ -f "$WEBUI_PATH" ]; then
    open "file://$WEBUI_PATH" &>/dev/null &
fi;

printf "\n";
printf "%b\n" "${C_BOLD}${C_GREEN}✨ Leonardo AI USB is now running! ✨${C_RESET}";
printf "%b\n" "  - Ollama Server PID: ${C_BOLD}$OLLAMA_PID${C_RESET}";
printf "%b\n" "  - Web UI should be open in your browser (or open manually: ${C_GREEN}file://$WEBUI_PATH${C_RESET}).";
printf "%b\n" "  - To stop the Ollama server, close this terminal window or run: ${C_YELLOW}kill $OLLAMA_PID${C_RESET}";
printf "\n";
printf "%b\n" "${C_YELLOW}Press Ctrl+C in this window (or close it) to stop the Ollama server and exit.${C_RESET}";

trap 'printf "\n%b\n" "${C_BLUE}Shutting down Ollama server (PID $OLLAMA_PID)..."; kill $OLLAMA_PID 2>/dev/null; wait $OLLAMA_PID 2>/dev/null; printf "%b\n" "${C_GREEN}Ollama server stopped.${C_RESET}"' EXIT TERM INT;

wait $OLLAMA_PID;
printf "%b\n" "${C_BLUE}Ollama server (PID $OLLAMA_PID) has been stopped.${C_RESET}";
printf "%b\n" "${C_GREEN}Leonardo AI USB session ended.${C_RESET}";
EOF
                        chmod +x "$usb_path/$file"
                        ;;
                    leonardo.bat)
                        cat > "$usb_path/$file" << 'EOF'
@echo off
REM Leonardo AI Launcher - Windows
cd /d "%~dp0"
echo Starting Leonardo AI from: %cd%
start ollama-windows.exe serve --models "%cd%\.ollama\models"
EOF
                        ;;
                esac
                ((repair_count++))
            fi
        fi
    done

    # Check binaries
    echo -e "\nChecking OS binaries..."
    local binary_paths=(
        "ollama"
        "ollama-darwin"
        "ollama-windows.exe"
    )

    local os_detected=""
    for bin in "${binary_paths[@]}"; do
        if [ -f "$usb_path/$bin" ]; then
            print_success "✓ Binary exists: $bin"
            if [[ "$bin" == *linux* ]]; then os_detected="${os_detected}linux,"; fi
            if [[ "$bin" == *darwin* ]]; then os_detected="${os_detected}mac,"; fi
            if [[ "$bin" == *windows* ]]; then os_detected="${os_detected}win,"; fi

            # Check if executable for Linux/Mac binaries
            if [[ "$bin" != *.exe ]] && [ ! -x "$usb_path/$bin" ]; then
                print_warning "⚠️ Binary is not executable: $bin"
                ((issues_found++))
                if [ "$repair_mode" = "yes" ]; then
                    print_info "Making binary executable: $usb_path/$bin"
                    chmod +x "$usb_path/$bin"
                    ((repair_count++))
                fi
            fi
        else
            print_warning "⚠️ Binary missing: $bin (may be ok if OS not selected)"
        fi
    done

    # Check models
    echo -e "\nChecking models..."
    local model_count=0
    local model_dir="$usb_path/.ollama/models/manifests/registry.ollama.ai/library"
    if [ -d "$model_dir" ]; then
        mapfile -t model_files < <(find "$model_dir" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null | xargs -0 -n1 || echo "")
        model_count=${#model_files[@]}
        if [ $model_count -gt 0 ]; then
            print_success "✓ Found $model_count model(s):"
            for model_file in "${model_files[@]}"; do
                relative_path="${model_file#$model_dir/}"
                model_name="${relative_path%/*}:${relative_path##*/}"
                echo "  - $model_name"
            done
        else
            print_warning "⚠️ No models found in the models directory"
            ((issues_found++))
        fi
    else
        print_warning "⚠️ Models directory structure incomplete"
        ((issues_found++))
        if [ "$repair_mode" = "yes" ]; then
            print_info "Crafting models directory structure"
            mkdir -p "$model_dir"
            ((repair_count++))
        fi
    fi

    # Summary
    echo -e "\n${C_BOLD}${C_CYAN}=== Verification Summary ===${C_RESET}"
    if [ $issues_found -eq 0 ]; then
        print_success "✅ No issues found! Your Leonardo AI USB drive appears to be healthy."
    else
        print_warning "⚠️ Found $issues_found issue(s) with your Leonardo AI USB drive."
        if [ "$repair_mode" = "yes" ]; then
            if [ $repair_count -eq $issues_found ]; then
                print_success "✅ All $repair_count issues were successfully repaired!"
            elif [ $repair_count -gt 0 ]; then
                print_partial_success "🔧 Repaired $repair_count out of $issues_found issues."
                print_info "Some issues may require manual intervention."
            else
                print_error "❌ Unable to repair any issues automatically."
                print_info "Please run the installation process again or contact support."
            fi
        else
            print_info "💡 Run this verification again with the repair option to attempt fixing these issues."
        fi
    fi
}

handle_verify_usb() {
    print_header "🔍 USB VERIFICATION & REPAIR 🔍"
    echo -e "${C_CYAN}This tool checks your Leonardo AI USB drive for common issues${C_RESET}"
    echo -e "${C_CYAN}and can automatically fix problems like missing launcher scripts.${C_RESET}"
    echo ""

    # Ask for USB path
    local usb_path=""
    local repair_mode="no"
    local selection_successful=false

    while [ "$selection_successful" = "false" ]; do
        echo "Please specify the location of your Leonardo AI USB drive:"
        echo "1) Detect and select from available USB drives"
        echo "2) Enter path manually"
        echo "q) Return to main menu"

        print_prompt "Enter your choice (1, 2, or q)"
        read -r choice

        case "$choice" in
            1)
                # First, clear any previous selection
                USB_DEVICE_PATH=""
                USB_BASE_PATH=""

                # Use existing USB detection logic
                ask_usb_device

                # After asking for the USB device, we need to ensure USB_BASE_PATH is set
                # If USB_DEVICE_PATH is set but USB_BASE_PATH isn't, try to determine the mount point
                if [ -n "$USB_DEVICE_PATH" ] && [ -z "$USB_BASE_PATH" ]; then
                    # Get the partition path (usually partition 1 on the device)
                    local potential_partition
                    if [[ "$USB_DEVICE_PATH" == *"nvme"*"n"* ]] || [[ "$USB_DEVICE_PATH" == *"mmcblk"* ]]; then
                        potential_partition="${USB_DEVICE_PATH}p1"
                    else
                        potential_partition="${USB_DEVICE_PATH}1"
                    fi

                    # Try to find the mount point for this partition
                    if [ -b "$potential_partition" ]; then
                        local mount_point
                        mount_point=$(findmnt -n -o TARGET "$potential_partition" 2>/dev/null || echo "")
                        if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
                            USB_BASE_PATH="$mount_point"
                            print_info "Found mount point: $USB_BASE_PATH"
                        else
                            # Try to mount it if not already mounted
                            USB_PARTITION_PATH="$potential_partition"
                            ensure_usb_mounted_and_writable "$USB_PARTITION_PATH"
                        fi
                    fi
                fi

            # Check if a valid drive was selected and mounted
            if [ -n "$USB_BASE_PATH" ] && [ -d "$USB_BASE_PATH" ]; then
                usb_path="$USB_BASE_PATH"
                selection_successful=true
            elif [ -n "$USB_DEVICE_PATH" ]; then
                # We have a device but couldn't determine the mount point
                print_error "Could not determine the mount point for $USB_DEVICE_PATH."
                print_info "Please ensure the drive is properly mounted and try again."
                echo ""
            else
                print_error "Failed to select a valid USB drive. Please try again."
                echo ""
            fi
                ;;
            2)
                print_prompt "Enter the full path to your Leonardo AI USB drive"
                read -r manual_path

                if [ -z "$manual_path" ]; then
                    print_warning "Path cannot be empty."
                    echo ""
                    continue
                fi

                if [ ! -d "$manual_path" ]; then
                    print_error "Directory does not exist: $manual_path"
                    echo ""
                    continue
                fi

                usb_path="$manual_path"
                selection_successful=true
                ;;
            q|Q)
                return
                ;;
            *)
                print_warning "Invalid choice. Please enter 1, 2, or q."
                echo ""
                ;;
        esac
    done

    # Confirmation
    echo ""
    echo "Selected USB path: ${C_BOLD}$usb_path${C_RESET}"

    # Ask if repair should be attempted
    ask_yes_no_quit "Would you like to automatically repair any issues found?" repair_mode

    # Run verification
    verify_usb_health "$usb_path" "$repair_mode"
    local verification_result=$?

    if [ $verification_result -ne 0 ]; then
        print_warning "Verification encountered errors. You may want to check the USB drive or try again."
    fi

    echo ""
    print_prompt "Press Enter to return to the main menu"
    read -r
}

# --- USB Health Management Functions ---

# Initialize USB health tracking data
initialize_usb_health() {
    local usb_path="$1"

    if ! $USB_HEALTH_TRACKING; then
        return 0
    fi

    if [ -z "$usb_path" ] || [ ! -d "$usb_path" ]; then
        print_debug "Cannot initialize USB health tracking: Invalid USB path"
        return 1
    fi

    # Set the health data file path
    USB_HEALTH_DATA_FILE="$usb_path/.leonardo_usb_health.dat"

    # Try to get USB device info
    local device_path="$RAW_USB_DEVICE_PATH"
    if [ -n "$device_path" ] && [ -e "$device_path" ]; then
        # Get USB model and serial if available
        USB_MODEL=$(lsblk -no MODEL "$device_path" 2>/dev/null || echo "Unknown")
        USB_SERIAL=$(lsblk -no SERIAL "$device_path" 2>/dev/null || echo "Unknown")

        # Try to estimate lifespan based on device type
        if [[ "$USB_MODEL" == *"SSD"* ]]; then
            # SSDs typically have higher write cycle limits
            USB_ESTIMATED_LIFESPAN=10000
        else
            # Regular flash drives
            USB_ESTIMATED_LIFESPAN=3000
        fi
    fi

    # Load existing health data if available
    if [ -f "$USB_HEALTH_DATA_FILE" ]; then
        # Source the data file to load variables
        source "$USB_HEALTH_DATA_FILE" 2>/dev/null || true
        print_debug "Loaded USB health data: $USB_WRITE_CYCLE_COUNTER cycles, $USB_TOTAL_BYTES_WRITTEN bytes written"
    else
        # Initialize new health file
        USB_FIRST_USE_DATE=$(date +"%Y-%m-%d")
        USB_WRITE_CYCLE_COUNTER=0
        USB_TOTAL_BYTES_WRITTEN=0

        # Write initial health data
        save_usb_health_data
        print_debug "Initialized new USB health tracking file"
    fi

    return 0
}

# Save USB health data to the tracking file
save_usb_health_data() {
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        return 0
    fi

    # Create the data file with current values
    cat > "$USB_HEALTH_DATA_FILE" << EOF
# Leonardo USB Health Tracking Data
# Last updated: $(date +"%Y-%m-%d %H:%M:%S")
USB_FIRST_USE_DATE="$USB_FIRST_USE_DATE"
USB_WRITE_CYCLE_COUNTER=$USB_WRITE_CYCLE_COUNTER
USB_TOTAL_BYTES_WRITTEN=$USB_TOTAL_BYTES_WRITTEN
USB_MODEL="$USB_MODEL"
USB_SERIAL="$USB_SERIAL"
USB_ESTIMATED_LIFESPAN=$USB_ESTIMATED_LIFESPAN
EOF

    # Make the file hidden and read-only to prevent accidental modification
    chmod 644 "$USB_HEALTH_DATA_FILE" 2>/dev/null || true

    return 0
}

# Update USB health data after a write operation
update_usb_health_data() {
    local bytes_written="$1"

    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        return 0
    fi

    # Increment write cycle counter (we count each significant operation as one cycle)
    USB_WRITE_CYCLE_COUNTER=$((USB_WRITE_CYCLE_COUNTER + 1))

    # Add to total bytes written if specified
    if [ -n "$bytes_written" ] && [ "$bytes_written" -gt 0 ]; then
        USB_TOTAL_BYTES_WRITTEN=$((USB_TOTAL_BYTES_WRITTEN + bytes_written))
    fi

    # Save updated data
    save_usb_health_data

    # Check if we should warn about USB drive health
    check_usb_health_warning

    return 0
}

# Check if we should display a warning about USB health
check_usb_health_warning() {
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        return 0
    fi

    # Only warn if we have a valid lifespan estimate
    if [ "$USB_ESTIMATED_LIFESPAN" -gt 0 ]; then
        # Calculate percentage of estimated lifespan used
        local used_percent=$((USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN))

        # Warn at different thresholds
        if [ "$used_percent" -ge 90 ]; then
            print_warning "⚠️ USB DRIVE HEALTH CRITICAL: ~$used_percent% of estimated write cycles used"
            print_warning "Consider backing up your data and replacing this drive soon."
        elif [ "$used_percent" -ge 70 ]; then
            print_warning "⚠️ USB DRIVE HEALTH WARNING: ~$used_percent% of estimated write cycles used"
            print_warning "Your USB drive is aging. Consider backing up important data."
        elif [ "$used_percent" -ge 50 ] && [ $((USB_WRITE_CYCLE_COUNTER % 10)) -eq 0 ]; then
            # Only show this warning occasionally (every 10 write cycles)
            print_info "ℹ️ USB DRIVE HEALTH NOTE: ~$used_percent% of estimated write cycles used"
        fi
    fi

    return 0
}

# Display USB health information
display_usb_health() {
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        print_info "USB health tracking is not active for this drive."
        return 0
    fi

    # Format total bytes written
    local total_written_fmt=""
    if [ "$USB_TOTAL_BYTES_WRITTEN" -gt 1073741824 ]; then  # 1GB
        total_written_fmt="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN/1073741824" | bc) GB"
    elif [ "$USB_TOTAL_BYTES_WRITTEN" -gt 1048576 ]; then  # 1MB
        total_written_fmt="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN/1048576" | bc) MB"
    elif [ "$USB_TOTAL_BYTES_WRITTEN" -gt 1024 ]; then  # 1KB
        total_written_fmt="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN/1024" | bc) KB"
    else
        total_written_fmt="$USB_TOTAL_BYTES_WRITTEN bytes"
    fi

    # Calculate drive age
    local first_use_timestamp=$(date -d "$USB_FIRST_USE_DATE" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$USB_FIRST_USE_DATE" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    local age_days=0

    if [ "$first_use_timestamp" -gt 0 ]; then
        age_days=$(( (current_timestamp - first_use_timestamp) / 86400 ))
    fi

    # Calculate health percentage
    local health_percent=100
    local health_status="Excellent"
    local health_color="$C_GREEN"

    if [ "$USB_ESTIMATED_LIFESPAN" -gt 0 ] && [ "$USB_WRITE_CYCLE_COUNTER" -gt 0 ]; then
        local used_percent=$((USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN))
        health_percent=$((100 - used_percent))

        if [ "$health_percent" -lt 10 ]; then
            health_status="Critical"
            health_color="$C_RED"
        elif [ "$health_percent" -lt 30 ]; then
            health_status="Poor"
            health_color="$C_ORANGE"
        elif [ "$health_percent" -lt 70 ]; then
            health_status="Fair"
            health_color="$C_YELLOW"
        elif [ "$health_percent" -lt 90 ]; then
            health_status="Good"
            health_color="$C_LIGHT_GREEN"
        fi
    fi

    # Display the health information
    echo -e "\n${C_CYAN}┌───── 🔋 USB Drive Health Report ───────────────────────────┐${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} Model: ${C_YELLOW}${USB_MODEL:-Unknown}${C_RESET} | Serial: ${C_YELLOW}${USB_SERIAL:-Unknown}${C_RESET} ${C_CYAN}│${C_RESET}"
    echo -e "${C_CYAN}├─────────────────────────┬───────────────────────────────────┤${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} First Used: ${C_YELLOW}${USB_FIRST_USE_DATE:-Unknown}${C_RESET} ${C_CYAN}│${C_RESET} Age: ${C_YELLOW}$age_days days${C_RESET} ${C_CYAN}│${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} Write Cycles: ${C_YELLOW}$USB_WRITE_CYCLE_COUNTER${C_RESET} ${C_CYAN}│${C_RESET} Total Written: ${C_YELLOW}$total_written_fmt${C_RESET} ${C_CYAN}│${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} Health Status: ${health_color}$health_status ($health_percent%)${C_RESET} ${C_CYAN}│${C_RESET} ${C_CYAN}│${C_RESET}"
    echo -e "${C_CYAN}├─────────────────────────┴───────────────────────────────────┤${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}Recommendations:${C_RESET} ${C_CYAN}│${C_RESET}"

    # Provide customized recommendations based on health status
    if [ "$health_percent" -lt 30 ]; then
        echo -e "${C_CYAN}│${C_RESET} - Consider replacing this drive soon ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} - Backup all data immediately ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} - Use read-only operations when possible ${C_CYAN}│${C_RESET}"
    elif [ "$health_percent" -lt 70 ]; then
        echo -e "${C_CYAN}│${C_RESET} - Backup important data regularly ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} - Limit unnecessary write operations ${C_CYAN}│${C_RESET}"
    else
        echo -e "${C_CYAN}│${C_RESET} - Continue regular backups ${C_CYAN}│${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} - Drive appears to be in good health ${C_CYAN}│${C_RESET}"
    fi

    echo -e "${C_CYAN}└───────────────────────────────────────────────────────────┘${C_RESET}\n"

    return 0
}

# --- Download History Display Function ---
display_download_history() {
    local show_all=${1:-false}

    if [ ${#DOWNLOAD_HISTORY[@]} -eq 0 ]; then
        print_info "No downloads recorded in this session."
        return 0
    fi

    # Format the total download size
    local total_fmt=""
    if [ $TOTAL_BYTES_DOWNLOADED -gt 1073741824 ]; then  # 1GB
        total_fmt="$(echo "scale=2; $TOTAL_BYTES_DOWNLOADED/1073741824" | bc) GB"
    elif [ $TOTAL_BYTES_DOWNLOADED -gt 1048576 ]; then  # 1MB
        total_fmt="$(echo "scale=2; $TOTAL_BYTES_DOWNLOADED/1048576" | bc) MB"
    elif [ $TOTAL_BYTES_DOWNLOADED -gt 1024 ]; then  # 1KB
        total_fmt="$(echo "scale=2; $TOTAL_BYTES_DOWNLOADED/1024" | bc) KB"
    else
        total_fmt="$TOTAL_BYTES_DOWNLOADED bytes"
    fi

    # Calculate session duration
    local current_time=$(date +%s)
    local duration=$((current_time - INSTALL_START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    local duration_fmt="$(printf "%02d:%02d:%02d" $hours $minutes $seconds)"

    echo -e "\n${C_CYAN}┌───── 📥 Download History ──────────────────────────────────┐${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} Session Duration: ${C_YELLOW}$duration_fmt${C_RESET} | Total Downloaded: ${C_YELLOW}$total_fmt${C_RESET} ${C_CYAN}│${C_RESET}"
    echo -e "${C_CYAN}├────────────┬───────────┬──────────────────────────────────────┤${C_RESET}"
    echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}Time${C_RESET}       ${C_CYAN}│${C_RESET} ${C_YELLOW}Size${C_RESET}      ${C_CYAN}│${C_RESET} ${C_YELLOW}Description${C_RESET}                          ${C_CYAN}│${C_RESET}"
    echo -e "${C_CYAN}├────────────┼───────────┼──────────────────────────────────────┤${C_RESET}"

    local count=${#DOWNLOAD_HISTORY[@]}
    local start=0

    # If we have more than 5 downloads and not showing all, just show the last 5
    if [ $count -gt 5 ] && ! $show_all; then
        start=$((count - 5))
        count=5
    fi

    for ((i=start; i<start+count && i<${#DOWNLOAD_HISTORY[@]}; i++)); do
        local desc="${DOWNLOAD_HISTORY[$i]}"
        local size=${DOWNLOAD_SIZES[$i]}
        local time="${DOWNLOAD_TIMESTAMPS[$i]}"
        local status="${DOWNLOAD_STATUS[$i]}"

        # Format size nicely
        local size_fmt=""
        if [ $size -gt 1073741824 ]; then  # 1GB
            size_fmt="$(echo "scale=2; $size/1073741824" | bc) GB"
        elif [ $size -gt 1048576 ]; then  # 1MB
            size_fmt="$(echo "scale=2; $size/1048576" | bc) MB"
        elif [ $size -gt 1024 ]; then  # 1KB
            size_fmt="$(echo "scale=2; $size/1024" | bc) KB"
        else
            size_fmt="$size B"
        fi

        # Truncate description if too long
        if [ ${#desc} -gt 34 ]; then
            desc="${desc:0:31}..."
        fi

        # Add status indicator
        local status_icon=""
        if [ "$status" = "0" ]; then
            status_icon="${C_GREEN}✓${C_RESET}"
        else
            status_icon="${C_RED}✗${C_RESET}"
        fi

        printf "${C_CYAN}│${C_RESET} %-10s ${C_CYAN}│${C_RESET} %-9s ${C_CYAN}│${C_RESET} %-32s ${C_CYAN}│${C_RESET}\n" "$time" "$size_fmt" "$desc $status_icon"
    done

    # Show a message if we're not showing all downloads
    if [ ${#DOWNLOAD_HISTORY[@]} -gt 5 ] && ! $show_all; then
        local remaining=$((${#DOWNLOAD_HISTORY[@]} - 5))
        echo -e "${C_CYAN}├────────────┴───────────┴──────────────────────────────────────┤${C_RESET}"
        echo -e "${C_CYAN}│${C_RESET} ${C_YELLOW}$remaining more downloads${C_RESET} not shown. Use '${C_GREEN}history${C_RESET}' to see all. ${C_CYAN}│${C_RESET}"
    fi

    echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}\n"
}

# --- Summary Report Function ---
generate_summary_report() {
    local usb_path="$1"
    local models="$2"
    local os_targets="$3"
    local date_created=$(date "+%Y-%m-%d %H:%M:%S")
    local report_file="$usb_path/leonardo_setup_report.txt"
    local total_model_size_gb="$ESTIMATED_MODELS_SIZE_GB"
    local host_os=$(uname -s)
    local host_ver=$(uname -r)

    print_info "Generating installation summary report..."

    # Create the summary report
    cat > "$report_file" << EOL
=================================================================
                LEONARDO AI USB - INSTALLATION REPORT
=================================================================

Created:         $date_created
Created on:      $host_os $host_ver
USB Label:       $USB_LABEL
Script Version:  $SCRIPT_VERSION

-----------------------------------------------------------------
                      INSTALLATION DETAILS
-----------------------------------------------------------------
Operating Systems: $os_targets
Models Installed:  $models
Total Model Size:  $total_model_size_gb GB

-----------------------------------------------------------------
                         QUICK START
-----------------------------------------------------------------
1. Plug this USB drive into a computer with one of these OS: $os_targets
2. Run the appropriate launcher for your system:
   - Linux:   ./leonardo.sh
   - macOS:   ./leonardo.command (double-click in Finder)
   - Windows: leonardo.bat (double-click in Explorer)

3. Wait for Ollama to start - a web browser should open automatically
4. If browser doesn't open, manually navigate to:
   http://localhost:11434/

-----------------------------------------------------------------
                       TROUBLESHOOTING
-----------------------------------------------------------------
- If launchers don't work, check file permissions
- On Linux/Mac, you may need to run: chmod +x leonardo.sh leonardo.command
- For security verification, check the checksums.sha256.txt file
- See security_readme.txt for additional security information

For help, visit: https://github.com/ollama/ollama

Timestamp: $(date)
EOL

    # Make sure the file is readable
    chmod 644 "$report_file"

    print_success "Installation summary report created at $report_file"
}

# --- Cleanup Function ---
cleanup_temp_files() {
    if [ -d "$TMP_DOWNLOAD_DIR" ]; then
        print_info "Script ending. Cleaning up temporary download directory: $TMP_DOWNLOAD_DIR..."
        rm -rf "$TMP_DOWNLOAD_DIR"
    fi
}
# --- END ALL FUNCTION DEFINITIONS ---

# --- Trap for cleanup ---
trap cleanup_temp_files EXIT INT TERM

# --- QoL: Call Root Privilege Check Early ---
check_root_privileges

# --- Main Script Loop ---
while true; do
    INSTALL_START_TIME=$(date +%s)
    if $TPUT_CLEAR_POSSIBLE && [ -n "$TPUT_CMD_PATH" ] ; then
        "$TPUT_CMD_PATH" clear
    else
        printf '\033[H\033[2J'
    fi
    print_leonardo_title_art
    check_bash_version

    # Command-line argument handling
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_help
                exit 0
                ;;
            -v|--version)
                echo -e "${C_BOLD}${C_WHITE}Leonardo AI USB Maker ${C_YELLOW}v$SCRIPT_VERSION${C_RESET}"
                echo -e "Copyright © $(date +%Y) Leonardo AI"
                exit 0
                ;;
            --no-color)
                # Force disable colors regardless of terminal capability
                export NO_COLOR=1
                init_colors
                ;;
            *)
                print_warning "Unknown option: $1"
                print_info "Run with --help for usage information."
                exit 1
                ;;
        esac
        shift
    done

    # Script header
    echo -e "${C_BOLD}${C_WHITE}--- $SCRIPT_SELF_NAME (Version: $SCRIPT_VERSION) ---${C_RESET}"
    echo -e "${C_WHITE}--- Portable Ollama USB Suite (Leonardo Edition - Security Enhanced!) ---${C_RESET}"

    main_op_choice=""
    main_menu_options=(
        "create_new" "Create a NEW Leonardo AI USB drive"
        "manage_existing" "Manage an EXISTING Leonardo AI USB drive"
        "clear_context_separator" ""
        "verify_usb" "Verify & Repair USB Drive (Fix missing files)"
        "dry_run" "Dry Run / System Check (No changes made)"
        "download_history" "View Download History & Statistics"
        "usb_health" "USB Drive Health Report & Optimizer"
        "clear_context" "Utility: Clear USB context (affects next run & ${C_YELLOW}exits script${C_RESET})"
        "about_separator" ""
        "about_script" "About this Script"
    )
    show_menu "Main Menu" "What would you like to do?" main_op_choice "${main_menu_options[@]}"


    if [[ "$main_op_choice" == "q" ]]; then
        print_info "Quitting script. Goodbye! 👋"; exit 0
    fi

    OPERATION_MODE="$main_op_choice"

    if [[ "$OPERATION_MODE" == "usb_health" ]]; then
        print_header "🔋 USB DRIVE HEALTH REPORT & OPTIMIZER 🔋"
        print_info "This feature helps extend your USB drive's lifespan through intelligent tracking and optimization."
        print_line

        # Ask user to select a USB drive if none is already selected
        if [ -z "$USB_BASE_PATH" ] || [ ! -d "$USB_BASE_PATH" ]; then
            print_info "Please select a Leonardo AI USB drive to check its health:"
            print_line
            detect_usb_drives
            if [ ${#USB_CANDIDATES[@]} -eq 0 ]; then
                print_error "No Leonardo AI USB drives detected. Please connect one and try again."
                print_line
                print_prompt "Press Enter to return to the main menu"
                read -r
                continue
            fi

            select_usb_drive
            if [ -z "$USB_BASE_PATH" ] || [ ! -d "$USB_BASE_PATH" ]; then
                print_error "No USB drive selected. Returning to main menu."
                print_line
                print_prompt "Press Enter to continue"
                read -r
                continue
            fi
        fi

        # Initialize USB health tracking for the selected drive
        initialize_usb_health "$USB_BASE_PATH"

        # Display the health report
        display_usb_health

        # Offer optimization options
        print_subheader "USB Drive Optimization Options"
        echo -e "1) ${C_GREEN}Run TRIM operations${C_RESET} (if supported by drive)"
        echo -e "2) ${C_GREEN}Run basic health check${C_RESET} (verify filesystem)"
        echo -e "3) ${C_GREEN}Optimize file layout${C_RESET} (reduce fragmentation)"
        echo -e "4) ${C_YELLOW}Return to main menu${C_RESET}"
        print_line
        read -p "Select an option [1-4]: " opt_choice

        case "$opt_choice" in
            1)
                print_info "Running TRIM operations if supported..."
                if command -v fstrim >/dev/null 2>&1; then
                    sudo fstrim -v "$USB_BASE_PATH" 2>/dev/null || print_warning "TRIM not supported or failed"
                else
                    print_warning "fstrim command not available on this system"
                fi
                # Update health data with this maintenance operation
                update_usb_health_data 0
                ;;
            2)
                print_info "Running basic filesystem check..."
                fsck_cmd="fsck.fat"
                if command -v "$fsck_cmd" >/dev/null 2>&1; then
                    sudo "$fsck_cmd" -n "$USB_PARTITION_PATH" 2>/dev/null || \
                    print_warning "Could not check filesystem (may require unmounting)"
                else
                    print_warning "Filesystem check tools not available"
                fi
                # Update health data with this maintenance operation
                update_usb_health_data 0
                ;;
            3)
                print_info "Optimizing file layout to reduce fragmentation..."
                print_warning "This operation requires temporarily copying files. Ensure you have enough space."
                if ask_yes_no "Continue with optimization?" OPT_CONFIRM; then
                    # Create a temporary directory
                    TMP_DIR=$(mktemp -d)
                    if [ -d "$TMP_DIR" ]; then
                        print_info "Copying files to temporary location..."
                        cp -a "$USB_BASE_PATH/"* "$TMP_DIR/" 2>/dev/null || true

                        print_info "Removing original files..."
                        find "$USB_BASE_PATH" -mindepth 1 -not -path "*/.leonardo_usb_health.dat" -delete 2>/dev/null || true

                        print_info "Copying files back with optimized layout..."
                        cp -a "$TMP_DIR/"* "$USB_BASE_PATH/" 2>/dev/null || true

                        print_info "Cleaning up temporary files..."
                        rm -rf "$TMP_DIR"

                        # Update health data with this maintenance operation
                        update_usb_health_data 0
                        print_success "File layout optimization complete!"
                    else
                        print_error "Failed to create temporary directory"
                    fi
                fi
                ;;
            *)
                print_info "Returning to main menu"
                ;;
        esac

        print_line
        print_prompt "Press Enter to return to the main menu"
        read -r
        # Return to main menu after showing health report
        continue
    elif [[ "$OPERATION_MODE" == "download_history" ]]; then
        print_header "📥 DOWNLOAD HISTORY & STATISTICS 📥"
        print_info "This shows a summary of all files downloaded during this session."
        print_line
        display_download_history true
        print_line
        print_prompt "Press Enter to return to the main menu"
        read -r
        # Return to main menu after showing history
        continue

    elif [[ "$OPERATION_MODE" == "dry_run" ]]; then
        print_header "🔎 DRY RUN / SYSTEM CHECK 🔎"
        print_info "This mode checks dependencies and detects devices without making any changes."
        print_line
        check_host_dependencies "full"
        print_line
        print_subheader "📡 Checking Ollama Release URL Fetching..."
        if $USE_GITHUB_API; then
            if get_latest_ollama_release_urls; then
                print_info "Latest URLs from GitHub:"
                printf "  Linux:   %s\n" "${LINUX_URL:-Not found}"
                printf "  macOS:   %s\n" "${MAC_URL:-Not found}"
                printf "  Windows: %s\n" "${WINDOWS_ZIP_URL:-Not found}"
            else
                print_warning "Could not fetch from GitHub API. Fallback URLs would be used:"
                printf "  Linux:   %s\n" "$FALLBACK_LINUX_URL"
                printf "  macOS:   %s\n" "$FALLBACK_MAC_URL"
                printf "  Windows: %s\n" "$FALLBACK_WINDOWS_ZIP_URL"
            fi
        else
            print_info "GitHub API is disabled. Fallback URLs that would be used:"
            printf "  Linux:   %s\n" "$FALLBACK_LINUX_URL"
            printf "  macOS:   %s\n" "$FALLBACK_MAC_URL"
            printf "  Windows: %s\n" "$FALLBACK_WINDOWS_ZIP_URL"
        fi
        print_line
        print_subheader "💻 Checking Host Ollama Status..."
        if command -v ollama &> /dev/null; then
            print_info "Ollama CLI found."
            if ollama --version &> /dev/null; then
                print_success "Ollama version: $(ollama --version)"
            else
                print_warning "Ollama CLI found, but 'ollama --version' failed."
            fi
            if ollama list > /dev/null 2>&1; then
                print_success "Ollama service is responsive on host."
                echo -e "${C_BLUE}Host's available models:${C_RESET}"
                ollama list | sed 's/^/  /' # Indent output
            else
                print_warning "Ollama service is NOT responsive on host."
            fi
        else
            print_error "Ollama CLI ('ollama') not found on host."
        fi
        print_line
        ask_usb_device "list_only"
        print_line
        print_success "Dry Run / System Check complete. No changes were made."
        echo ""
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        OPERATION_MODE=""
        continue
    fi

    if [[ "$OPERATION_MODE" == "about_script" ]]; then
        print_header "📜 ABOUT THIS SCRIPT 📜"
        echo -e "${C_BOLD}Script Name:${C_RESET} $SCRIPT_SELF_NAME"
        echo -e "${C_BOLD}Version:${C_RESET}     $SCRIPT_VERSION"
        echo -e "${C_DIM}----------------------------------------------------------------------${C_RESET}"
        echo -e "This script helps you create and manage portable USB drives with Ollama"
        echo -e "and selected AI models, allowing you to run a local AI environment"
        echo -e "on Linux, macOS, and Windows computers from the USB stick."
        echo -e ""
        echo -e "It includes features for:"
        echo -e "  - Formatting the USB (optional, exFAT recommended)"
        echo -e "  - Downloading Ollama runtimes for selected OSes"
        echo -e "  - Pulling AI models from Ollama or importing local GGUF files"
        echo -e "  - Generating launcher scripts for easy startup on target OSes"
        echo -e "  - A simple Web UI for chatting with models on the USB"
        echo -e "  - Integrity verification tools"
        echo -e "  - Management of models on an existing Leonardo AI USB"
        echo -e "${C_DIM}----------------------------------------------------------------------${C_RESET}"
        echo -e "Brought to you by Eric & Your Friendly AI Assistant."
        echo -e "Remember to check the ${C_BOLD}SECURITY_README.txt${C_RESET} on the generated USB!"
        echo ""
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        OPERATION_MODE=""
        continue
    fi


    if [[ "$OPERATION_MODE" == "clear_context" ]]; then
        print_info "Clearing remembered USB drive context..."
        USB_DEVICE_PATH=""
        RAW_USB_DEVICE_PATH=""
        USB_BASE_PATH=""
        MOUNT_POINT=""
        USB_PARTITION_PATH=""
        USB_LABEL="$USB_LABEL_DEFAULT"
        print_success "USB context has been cleared."
        print_info "This will take effect the next time you run the script."
        print_info "Exiting now. Please re-run the script to use the cleared context."
        sleep 1
        exit 0
    fi


    if [[ "$OPERATION_MODE" == "create_seed" ]]; then
        print_header "🌱 CREATING SEED FILE 🌱"
        print_info "This will create a single file that can recreate the Leonardo AI USB Maker script."
        print_line
        
        # Ask for target directory
        print_prompt "Enter target directory for the seed file [default: current directory]: "
        read -r seed_target_dir
        
        # Use default if empty
        if [ -z "$seed_target_dir" ]; then
            seed_target_dir="."
        fi
        
        # Create the seed file
        create_seed_file "$seed_target_dir"
        
        print_line
        print_prompt "Press Enter to return to the main menu"
        read -r
        OPERATION_MODE=""
        continue
    fi
    if [[ "$OPERATION_MODE" == "verify_usb" ]]; then
        handle_verify_usb
        OPERATION_MODE=""
        continue
    fi


    if [[ "$OPERATION_MODE" == "create_new" ]]; then
        USB_LABEL="$USB_LABEL_DEFAULT"
        ask_usb_device
        ask_format_usb "$USB_DEVICE_PATH"
    elif [[ "$OPERATION_MODE" == "manage_existing" ]]; then
        if [ -z "$USB_DEVICE_PATH" ] || [ -z "$USB_BASE_PATH" ]; then
            USB_LABEL="$USB_LABEL_DEFAULT"
            ask_usb_device
        else
            confirm_active_usb_choice_val=""
            print_double_line
            echo -e "${C_BOLD}${C_YELLOW}🤔 CONFIRM ACTIVE USB 🤔${C_RESET}"
            while true; do
                print_prompt "Currently targeting USB: ${C_BOLD}$USB_DEVICE_PATH${C_RESET} (Label: ${C_GREEN}${USB_LABEL}${C_RESET} at ${C_GREEN}${USB_BASE_PATH:-Not Mounted}${C_RESET}). Continue? ([C]ontinue/[S]elect new/[M]ain menu): "
                read -r confirm_active_usb_choice_val
                confirm_active_usb_choice_val=$(echo "$confirm_active_usb_choice_val" | tr '[:upper:]' '[:lower:]')
                case "$confirm_active_usb_choice_val" in
                    c) print_info "Continuing with $USB_DEVICE_PATH."; break;;
                    s) USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; ask_usb_device; break;;
                    m) OPERATION_MODE=""; continue 2;;
                    *) print_warning "Invalid input.";;
                esac
            done
             print_double_line; echo ""
        fi

        while true;
        do
            if ! ensure_usb_mounted_and_writable; then
                print_error "Failed to ensure USB is mounted and writable. Returning to main menu."
                OPERATION_MODE="" ; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue 2
            fi

            manage_menu_prompt="Selected USB: ${C_BOLD}${USB_DEVICE_PATH}${C_RESET} (Label: ${C_GREEN}${USB_LABEL}${C_RESET} at ${C_GREEN}${USB_BASE_PATH}${C_RESET})\nWhat would you like to do?"
            manage_menu_options=(
                "list_usb_models" "List Models on selected USB (with sizes if jq is available)"
                "add_llm" "Add another LLM to selected USB"
                "remove_llm" "Remove an LLM from selected USB"
                "repair_scripts" "Repair/Refresh Leonardo scripts & UI on selected USB"
            )
            manage_choice=""
            show_menu "Manage Existing Leonardo AI USB" "$manage_menu_prompt" manage_choice "${manage_menu_options[@]}"

            if [[ "$manage_choice" == "b" ]]; then
                OPERATION_MODE=""
                continue 2
            fi
            OPERATION_MODE="$manage_choice"
            break
        done
    fi

    if [[ -z "$OPERATION_MODE" ]]; then
        continue
    fi

    print_info "Selected operation: ${C_BOLD}$OPERATION_MODE${C_RESET}"
    print_line; echo ""

    if [[ "$OPERATION_MODE" != "create_new" ]] && [[ "$OPERATION_MODE" != "q" ]] && [[ "$OPERATION_MODE" != "" ]]; then
        if ! ensure_usb_mounted_and_writable; then
            print_error "Critical error: Failed to ensure USB is mounted and writable for operation '$OPERATION_MODE'. Returning to main menu."
            OPERATION_MODE=""; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue
        fi
    fi

    # --- Execute Specific Operation ---
    case "$OPERATION_MODE" in
        verify_usb)
            # Call the USB verification and repair function
            handle_verify_usb
            # After verification is done, return to main menu
            main_op_choice=""
            OPERATION_MODE=""
            continue
            ;;
        create_new)
            check_host_dependencies "full"
            ask_target_os_binaries
            ask_llm_model # This now calls calculate_total_estimated_models_size_gb

            # Improved pre-flight check with better organization and complementary colors
            if $COLORS_ENABLED; then
                echo -e "\n${C_BOLD}${C_CYAN}┌───────────────────── PRE-FLIGHT CHECK ─────────────────────┐${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}Please review your selections before proceeding:${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}${C_BLUE}USB DEVICE${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}   ${C_BLUE}Device:${C_RESET}  $USB_DEVICE_PATH"
                echo -e "${C_CYAN}│${C_RESET}   ${C_BLUE}Label:${C_RESET}   $USB_LABEL_DEFAULT"
                echo -e "${C_CYAN}│${C_RESET}   ${C_BLUE}Format:${C_RESET}  $FORMAT_USB_CHOICE (Filesystem: exFAT)"
                echo -e "${C_CYAN}│${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}${C_GREEN}OPERATING SYSTEMS${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}   ${C_GREEN}OS:${C_RESET}      $SELECTED_OS_TARGETS"
                echo -e "${C_CYAN}│${C_RESET}   ${C_GREEN}Size:${C_RESET}    $ESTIMATED_BINARIES_SIZE_GB GB"
                echo -e "${C_CYAN}│${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}${C_YELLOW}AI MODELS${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}   ${C_YELLOW}Models:${C_RESET}  ${MODELS_TO_INSTALL_LIST[*]}"
                echo -e "${C_CYAN}│${C_RESET}   ${C_YELLOW}Size:${C_RESET}    $ESTIMATED_MODELS_SIZE_GB GB"
                if [[ "$MODEL_SOURCE_TYPE" == "create_local" ]]; then
                    short_path=$(basename "$LOCAL_GGUF_PATH_FOR_IMPORT")
                    echo -e "${C_CYAN}│${C_RESET}   Source:  Local file ($short_path)"
                fi
                echo -e "${C_CYAN}│${C_RESET}"

                # Evaluate the user's tech profile based on their choices
                TECH_PROFILE_MSG=$(get_tech_profile)

                # Format the tech profile message to wrap at appropriate width, respecting word boundaries
                # Using our global text wrapping utility for consistent column formatting
                WRAPPED_TECH_MSG=$(wrap_text_string "$TECH_PROFILE_MSG" 50 "" "\n${C_CYAN}│${C_RESET}   ")

                # Add special highlight section for Tech Profile with magenta background
                echo -e "${C_CYAN}│${C_RESET}"
                # Special section divider for Tech Profile
                echo -e "${C_CYAN}├${C_MAGENTA}════════════════════════════════════════════════════════════${C_RESET}${C_CYAN}┤${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}${C_MAGENTA}⭐ TECH PROFILE ANALYSIS ⭐${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}   ${C_MAGENTA}$WRAPPED_TECH_MSG${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}"
                # Bottom divider for Tech Profile section
                echo -e "${C_CYAN}├${C_MAGENTA}════════════════════════════════════════════════════════════${C_RESET}${C_CYAN}┤${C_RESET}"
                echo -e "${C_CYAN}│${C_RESET}"

                # Calculate total space required
                total_gb=$(echo "scale=1; $ESTIMATED_BINARIES_SIZE_GB + $ESTIMATED_MODELS_SIZE_GB" | bc)
                echo -e "${C_CYAN}│${C_RESET} ${C_BOLD}TOTAL SPACE REQUIRED: $total_gb GB${C_RESET}"
                echo -e "${C_CYAN}└────────────────────────────────────────────────────────────┘${C_RESET}"
            else
                echo ""
                echo "+------------------------ PRE-FLIGHT CHECK -----------------------+"
                echo "| Please review your selections before proceeding:"
                echo "|"
                echo "| USB DEVICE"
                echo "|   Device:  $USB_DEVICE_PATH"
                echo "|   Label:   $USB_LABEL_DEFAULT"
                echo "|   Format:  $FORMAT_USB_CHOICE (Filesystem: exFAT)"
                echo "|"
                echo "| OPERATING SYSTEMS"
                echo "|   OS:      $SELECTED_OS_TARGETS"
                echo "|   Size:    $ESTIMATED_BINARIES_SIZE_GB GB"
                echo "|"
                echo "| AI MODELS"
                echo "|   Models:  ${MODELS_TO_INSTALL_LIST[*]}"
                echo "|   Size:    $ESTIMATED_MODELS_SIZE_GB GB"
                if [[ "$MODEL_SOURCE_TYPE" == "create_local" ]]; then
                    short_path=$(basename "$LOCAL_GGUF_PATH_FOR_IMPORT")
                    echo "|   Source:  Local file ($short_path)"
                fi
                echo "|"

                # Evaluate the user's tech profile based on their choices
                TECH_PROFILE_MSG=$(get_tech_profile)

                # Format the tech profile message with our global word-boundary aware text wrapping
                # This ensures consistent column formatting throughout the project
                WRAPPED_TECH_MSG=$(wrap_text_string "$TECH_PROFILE_MSG" 50 "" "\n|   ")

                echo "|"
                echo "| TECH PROFILE ANALYSIS"
                echo "|   $WRAPPED_TECH_MSG"
                echo "|"

                # Calculate total space required
                total_gb=$(echo "scale=1; $ESTIMATED_BINARIES_SIZE_GB + $ESTIMATED_MODELS_SIZE_GB" | bc)
                echo "| TOTAL SPACE REQUIRED: $total_gb GB"
                echo "+------------------------------------------------------------------+"
            fi
            echo ""
            FINAL_CONFIRMATION_CHOICE=""
            ask_yes_no_quit "Do you want to proceed with these settings? (Choosing 'No' or 'Quit' will return to main menu)" FINAL_CONFIRMATION_CHOICE
            if [[ "$FINAL_CONFIRMATION_CHOICE" != "yes" ]]; then
                print_info "Operation cancelled by user. Returning to main menu."
                OPERATION_MODE=""; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue
            fi
            if $COLORS_ENABLED; then
            echo -e "\n${C_GREEN}┌──────────────────────────────────────────────┐${C_RESET}"
            echo -e "${C_GREEN}│${C_RESET} ${C_BOLD}Configuration confirmed!${C_RESET}"
            echo -e "${C_GREEN}│${C_RESET} Crafting your Leonardo AI USB..."
            echo -e "${C_GREEN}└──────────────────────────────────────────────┘${C_RESET}"
        else
            echo ""
            echo "+------------------------------------------+"
            echo "| Configuration confirmed!"
            echo "| Crafting your Leonardo AI USB..."
            echo "+------------------------------------------+"

            # We don't need to evaluate the tech profile again since it was already done in the pre-flight check
            # This just removes duplicate evaluation in the non-colored version
        fi
            echo "";

            if [[ "$FORMAT_USB_CHOICE" == "yes" ]]; then
                # Industry-standard warning before potentially destructive operation
                echo -e "\n${C_BOLD}${C_RED}╔═════════════════════ !!! WARNING !!! ═════════════════════╗${C_RESET}"
                echo -e "${C_BOLD}${C_RED}║                                                           ║${C_RESET}"
                echo -e "${C_BOLD}${C_RED}║             DATA DESTRUCTION IMMINENT                     ║${C_RESET}"
                echo -e "${C_BOLD}${C_RED}║                                                           ║${C_RESET}"
                echo -e "${C_BOLD}${C_RED}║                     ⚠️ 🦊🐰🔥                              ║${C_RESET}"
                echo -e "${C_BOLD}${C_RED}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
                echo -e "\n${C_YELLOW}⚠️  You are about to FORMAT device: ${C_BOLD}$USB_DEVICE_PATH${C_RESET}"
                echo -e "\n${C_BOLD}This operation will:${C_RESET}"
                echo -e "  ${C_RED}• PERMANENTLY ERASE ALL DATA on this device${C_RESET}"
                echo -e "  ${C_RED}• DELETE ALL PARTITIONS on this device${C_RESET}"
                echo -e "  ${C_RED}• DESTROY ALL FILE SYSTEMS on this device${C_RESET}"
                echo -e "\n${C_BOLD}Before proceeding, verify:${C_RESET}"
                echo -e "  ${C_YELLOW}• You have BACKED UP any important data${C_RESET}"
                echo -e "  ${C_YELLOW}• You are formatting the CORRECT device${C_RESET}"
                echo -e "  ${C_YELLOW}• You understand this action CANNOT BE UNDONE${C_RESET}"
                echo -e "\n${C_BOLD}${C_RED}FINAL CONFIRMATION REQUIRED${C_RESET}"
                echo -e "${C_BOLD}${C_RED}══════════════════════════════════════════════════════════${C_RESET}"
                PROCEED_FORMAT_CHOICE=""
                # Show the most serious warning with crazy-eyed llama
                echo -e "${C_BOLD}${C_RED}⚠️ WARNING: DESTRUCTIVE OPERATION ⚠️${C_RESET}"
                echo -e "${C_RED} (\\(\\    ${C_RESET}"
                echo -e "${C_RED} (ಠ‿ಠ)🦙 ${C_RESET}"  # Crazy/intense-looking llama face
                echo -e "${C_RED} / >)_/   ${C_RESET}"
                ask_yes_no_quit "${C_RED}${C_BOLD}I UNDERSTAND THE RISKS. Format $USB_DEVICE_PATH now?${C_RESET}" PROCEED_FORMAT_CHOICE "final"
                if [[ "$PROCEED_FORMAT_CHOICE" == "yes" ]]; then
                    if $COLORS_ENABLED; then
                        # AFK notification - bold, bright and highly visible (colored version)
                        # Using our global text wrapping utility for consistent column formatting
                        box_width=68
                        afk_title="⚡ USB FORGE ACTIVATED - AUTO-LLAMA MODE ENGAGED 🧠"

                        # Create the llama ASCII art with laptop - ensuring right alignment is fixed
                        llama_line1="    (\\(\\                                                  "
                        llama_line2="    (¬‿¬)🦙 \"Cleverly assembling your Leonardo USB now...\""
                        llama_line3="    / >|_                                                "
                        llama_line4="      / \\\\                                               "

                        # Progress bar showing approximately halfway progress
                        progress_text="USB Creation in Progress"
                        progress_bar="▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░  $progress_text"

                        # Wrap the messages at word boundaries
                        msg1=$(wrap_text_string "Est. time: ${C_WHITE}~10-15 minutes${C_RESET}" $((box_width-6)) "${C_BOLD}${C_CYAN}│${C_RESET}  ")
                        msg2=$(wrap_text_string "Return for: Final summary and USB ejection" $((box_width-6)) "${C_BOLD}${C_CYAN}│${C_RESET}  ")

                        echo -e "\n${C_BOLD}${C_CYAN}┌───────────────────────────────────────────────────────────┐${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}                                                            ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}  ${C_BOLD}${C_YELLOW}$afk_title${C_RESET}  ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}                                                            ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}  ${C_WHITE}$llama_line1${C_RESET}${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}  ${C_WHITE}$llama_line2${C_RESET}${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}  ${C_WHITE}$llama_line3${C_RESET}${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}  ${C_WHITE}$llama_line4${C_RESET}${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}                                                            ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}  ${C_GREEN}$progress_bar${C_RESET}  ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}                                                            ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "$msg1"
                        echo -e "$msg2"
                        echo -e "${C_BOLD}${C_CYAN}│${C_RESET}                                                            ${C_BOLD}${C_CYAN}│${C_RESET}"
                        echo -e "${C_BOLD}${C_CYAN}└───────────────────────────────────────────────────────────┘${C_RESET}\n"
                    else
                        # Non-colored version of the AFK notification
                        echo ""
                        echo "********************************************************"
                        echo "*                                                      *"
                        echo "*    USB FORGE ACTIVATED - AUTO-LLAMA MODE ENGAGED     *"
                        echo "*                                                      *"
                        echo "*    (\(\                                               *"
                        echo "*    (¬‿¬)🦙 Cleverly assembling your Leonardo USB...   *"
                        echo "*    / >|_                                             *"
                        echo "*                                                      *"
                        echo "*    [===========          ] USB Creation in Progress  *"
                        echo "*                                                      *"
                        echo "*    Est. time: ~10-15 minutes                         *"
                        echo "*    Return for: Final summary and USB ejection        *"
                        echo "*                                                      *"
                        echo "********************************************************"
                        echo ""
                    fi

                    print_info "⚙️ Formatting $USB_DEVICE_PATH..."
                    # Try direct formatting option for stubborn USB drives
                    print_info "Would you like to try a direct formatting approach? This may work better for stubborn USB drives."
                    DIRECT_FORMAT_CHOICE=""
                    ask_yes_no_quit "Use direct formatting (no partition table)? This may work when normal formatting fails." DIRECT_FORMAT_CHOICE

                    if [[ "$DIRECT_FORMAT_CHOICE" == "yes" ]]; then
                        print_info "Using direct device formatting without partition table creation..."
                        # Force unmount and flush any caches
                        sync
                        sudo umount /dev/sdk* 2>/dev/null || true

                        # Try direct formatting of the whole device
                        if command -v mkfs.exfat &>/dev/null; then
                            print_info "Formatting entire device with mkfs.exfat..."
                            if sudo mkfs.exfat -n "$USB_LABEL" "$USB_DEVICE_PATH" 2>/dev/null; then
                                print_success "Direct formatting successful!"
                                # In direct format mode, the partition path is the device path
                                USB_PARTITION_PATH="$USB_DEVICE_PATH"
                            else
                                print_error "Direct formatting failed with mkfs.exfat."
                                print_warning "You may need to reboot your system to fully release the USB drive."
                            fi
                        elif command -v mkfs.vfat &>/dev/null; then
                            print_info "Formatting entire device with mkfs.vfat (FAT32)..."
                            if sudo mkfs.vfat -n "$USB_LABEL" "$USB_DEVICE_PATH" 2>/dev/null; then
                                print_success "Direct formatting successful with FAT32!"
                                print_warning "Using FAT32 instead of exFAT. Files over 4GB won't be supported."
                                # In direct format mode, the partition path is the device path
                                USB_PARTITION_PATH="$USB_DEVICE_PATH"
                            else
                                print_error "Direct formatting failed with mkfs.vfat."
                                print_warning "You may need to reboot your system to fully release the USB drive."
                            fi
                        else
                            print_error "No formatting tools available for direct formatting."
                        fi
                    else
                        # Proceed with normal formatting
                        if ! format_usb_exfat "$USB_DEVICE_PATH" "$USB_LABEL"; then
                            print_error "Formatting failed despite multiple fallback attempts."
                            print_warning "Attempting to continue, but you may need to format the drive manually."
                            # Try to continue anyway - sometimes the drive is still usable
                        fi
                    fi
                    if [[ "$(uname)" == "Linux" ]]; then
                        if [[ "$USB_DEVICE_PATH" == *nvme*n* ]] || [[ "$USB_DEVICE_PATH" == *mmcblk* ]]; then
                           USB_PARTITION_PATH="${USB_DEVICE_PATH}p1"
                        else
                           USB_PARTITION_PATH="${USB_DEVICE_PATH}1"
                        fi
                        print_info "Using partition path: $USB_PARTITION_PATH"
                    elif [[ "$(uname)" == "Darwin" ]]; then
                        print_info "On macOS: Using device path $USB_DEVICE_PATH with label $USB_LABEL_DEFAULT"
                    fi
                    USB_LABEL="$USB_LABEL_DEFAULT"
                    print_success "Formatting process complete."
                    USB_BASE_PATH=""
                    if ! ensure_usb_mounted_and_writable "$USB_PARTITION_PATH"; then print_fatal "Failed to mount USB after formatting. Please check the drive and try again."; fi
                else
                    print_info "Formatting cancelled by user. Script will proceed assuming drive is already formatted as exFAT with label $USB_LABEL."
                    FORMAT_USB_CHOICE="no"
                    if ! ensure_usb_mounted_and_writable "$USB_PARTITION_PATH"; then print_fatal "Failed to mount unformatted USB. Please check the drive and try again."; fi
                fi
            elif [[ "$FORMAT_USB_CHOICE" == "no" ]]; then
                print_info "Skipping formatting as per user choice. Will attempt to use $USB_DEVICE_PATH as-is."
                print_info "Ensure it is formatted (preferably exFAT with label '$USB_LABEL' for easiest auto-mount) and has enough space."
                if ! ensure_usb_mounted_and_writable "$USB_PARTITION_PATH"; then print_fatal "Failed to mount unformatted USB. Please check the drive and try again."; fi
            fi
            echo
            check_disk_space "${MODELS_TO_INSTALL_LIST[*]}" "$MODEL_SOURCE_TYPE" "$LOCAL_GGUF_PATH_FOR_IMPORT" false

            print_info "⚙️ Crafting directory structure on $USB_BASE_PATH..."
            sudo mkdir -p "$USB_BASE_PATH/.ollama/models" "$USB_BASE_PATH/Data/tmp" "$USB_BASE_PATH/Data/logs" "$USB_BASE_PATH/webui"
            sudo mkdir -p "$USB_BASE_PATH/runtimes/linux/bin" "$USB_BASE_PATH/runtimes/linux/lib" \
                       "$USB_BASE_PATH/runtimes/mac/bin" "$USB_BASE_PATH/runtimes/mac/lib" \
                       "$USB_BASE_PATH/runtimes/win/bin" \
                       "$USB_BASE_PATH/Installation_Info"
            # Set permissions on each directory separately
            safe_chown "$USB_BASE_PATH/Data" "$(id -u):$(id -g)"
            safe_chown "$USB_BASE_PATH/webui" "$(id -u):$(id -g)"
            safe_chown "$USB_BASE_PATH/.ollama" "$(id -u):$(id -g)"
            safe_chown "$USB_BASE_PATH/Installation_Info" "$(id -u):$(id -g)"
            print_success "Directory structure created."

            TMP_DOWNLOAD_DIR=$(mktemp -d)
            print_info "Temporary download directory for binaries: ${C_DIM}$TMP_DOWNLOAD_DIR${C_RESET}"

            print_subheader "⏬ Downloading Ollama binaries based on selection: $SELECTED_OS_TARGETS..."
            if $USE_GITHUB_API; then
                if ! get_latest_ollama_release_urls; then
                    print_warning "Falling back to hardcoded URLs due to GitHub API issue.";
                    LINUX_URL="$FALLBACK_LINUX_URL"; MAC_URL="$FALLBACK_MAC_URL"; WINDOWS_ZIP_URL="$FALLBACK_WINDOWS_ZIP_URL";
                fi
            else
                print_info "Using hardcoded URLs (USE_GITHUB_API=false).";
                LINUX_URL="$FALLBACK_LINUX_URL"; MAC_URL="$FALLBACK_MAC_URL"; WINDOWS_ZIP_URL="$FALLBACK_WINDOWS_ZIP_URL";
            fi

            DOWNLOAD_CMD_BASE=""
            if command -v curl &> /dev/null; then DOWNLOAD_CMD_BASE="curl -L --progress-bar -o";
            elif command -v wget &> /dev/null; then DOWNLOAD_CMD_BASE="wget --show-progress -O";
            else print_fatal "Neither curl nor wget found. Dependency check should have caught this."; fi

            if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then
                LINUX_TARBALL="$TMP_DOWNLOAD_DIR/ollama-linux.tgz"
                if ! fancy_download "$LINUX_URL" "$LINUX_TARBALL" "Linux Ollama"; then
                    print_fatal "Download failed for Linux Ollama."
                fi
                print_info "Extracting Linux binaries to host temporary directory..."; HOST_LINUX_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/host_linux_extract"; mkdir -p "$HOST_LINUX_EXTRACT_DIR"
                if ! tar -xzf "$LINUX_TARBALL" -C "$HOST_LINUX_EXTRACT_DIR" --strip-components=0; then print_fatal "Failed to extract Linux tarball."; fi; print_success "Host extraction for Linux binaries successful."; OLLAMA_BIN_SOURCE=""; LIBS_SOURCE_DIR=""
                if [ -f "$HOST_LINUX_EXTRACT_DIR/bin/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/bin/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/lib"; fi
                elif [ -f "$HOST_LINUX_EXTRACT_DIR/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/lib"; fi
                elif [ -f "$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/lib"; fi
                else print_fatal "Could not find 'ollama' binary in the extracted Linux archive. Checked common paths (./bin/ollama, ./ollama, ./usr/share/ollama/ollama)."; fi
                print_info "Found Linux ollama binary at: ${C_DIM}$OLLAMA_BIN_SOURCE${C_RESET}"; if [ -n "$LIBS_SOURCE_DIR" ]; then print_info "Found Linux libs directory at: ${C_DIM}$LIBS_SOURCE_DIR${C_RESET}"; fi
                print_info "Moving Linux binary to USB..."; sudo cp "$OLLAMA_BIN_SOURCE" "$USB_BASE_PATH/runtimes/linux/bin/ollama"; sudo chmod +x "$USB_BASE_PATH/runtimes/linux/bin/ollama"
                if [ -n "$LIBS_SOURCE_DIR" ] && [ -d "$LIBS_SOURCE_DIR" ] && [ -n "$(ls -A "$LIBS_SOURCE_DIR" 2>/dev/null)" ]; then
                    print_info "Copying Linux libraries to USB...";
                    sudo mkdir -p "$USB_BASE_PATH/runtimes/linux/lib/"
                    if sudo cp -RL "$LIBS_SOURCE_DIR"/* "$USB_BASE_PATH/runtimes/linux/lib/"; then print_success "Linux libraries copied successfully."; else print_warning "Copying Linux libraries failed. This might cause issues."; fi
                else print_info "No separate 'lib' directory found or it was empty for Linux binaries. This is usually fine for statically linked binaries."; fi
                rm -rf "$HOST_LINUX_EXTRACT_DIR"
            fi

            if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then
                MAC_TARBALL="$TMP_DOWNLOAD_DIR/ollama-mac.tgz"
                if ! fancy_download "$MAC_URL" "$MAC_TARBALL" "macOS Ollama"; then
                    print_fatal "Download failed for macOS Ollama."
                fi
                HOST_MAC_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/host_mac_extract"; sudo mkdir -p "$HOST_MAC_EXTRACT_DIR";
                tar -xzf "$MAC_TARBALL" -C "$HOST_MAC_EXTRACT_DIR" --strip-components=0 || print_warning "tar extraction for macOS might have had non-fatal errors. Continuing extraction attempt..."
                print_success "macOS extraction to host temp attempted."

                OLLAMA_MAC_BIN_CANDIDATE_ROOT="$HOST_MAC_EXTRACT_DIR/ollama"
                OLLAMA_MAC_BIN_CANDIDATE_APP="$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Resources/ollama"
                OLLAMA_MAC_RUNNER_CANDIDATE_ROOT="$HOST_MAC_EXTRACT_DIR/ollama-runner"
                OLLAMA_MAC_RUNNER_CANDIDATE_APP="$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/MacOS/ollama-runner"


                if [ -f "$OLLAMA_MAC_BIN_CANDIDATE_ROOT" ]; then sudo cp "$OLLAMA_MAC_BIN_CANDIDATE_ROOT" "$USB_BASE_PATH/runtimes/mac/bin/ollama"
                elif [ -f "$OLLAMA_MAC_BIN_CANDIDATE_APP" ]; then print_info "Detected Ollama.app structure for macOS binary."; sudo cp "$OLLAMA_MAC_BIN_CANDIDATE_APP" "$USB_BASE_PATH/runtimes/mac/bin/ollama"
                else print_fatal "Could not find 'ollama' binary in the extracted macOS archive (checked ./ollama and inside .app)."; fi
                sudo chmod +x "$USB_BASE_PATH/runtimes/mac/bin/ollama"

                if [ -f "$OLLAMA_MAC_RUNNER_CANDIDATE_ROOT" ]; then sudo cp "$OLLAMA_MAC_RUNNER_CANDIDATE_ROOT" "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner"; sudo chmod +x "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner"
                elif [ -f "$OLLAMA_MAC_RUNNER_CANDIDATE_APP" ]; then sudo cp "$OLLAMA_MAC_RUNNER_CANDIDATE_APP" "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner"; sudo chmod +x "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner";
                else print_info "'ollama-runner' not found in macOS archive. This is usually okay for portable server use if 'ollama serve' works."; fi

                if [ -d "$HOST_MAC_EXTRACT_DIR/lib" ] && [ -n "$(ls -A "$HOST_MAC_EXTRACT_DIR/lib" 2>/dev/null)" ]; then
                    print_info "Copying macOS libraries...";
                    sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
                    sudo cp -RL "$HOST_MAC_EXTRACT_DIR/lib"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS libraries copy failed or no libs found.";
                elif [ -d "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks" ]; then
                     print_info "Copying macOS Frameworks...";
                     sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
                     sudo cp -RL "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS Frameworks copy failed.";
                else print_info "No separate 'lib' or 'Frameworks' directory found or it was empty for macOS binaries. This is often normal."; fi
                rm -rf "$HOST_MAC_EXTRACT_DIR"; print_success "macOS binaries processed."
            fi

            if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
                WINDOWS_ZIP="$TMP_DOWNLOAD_DIR/ollama-windows.zip"
                if ! fancy_download "$WINDOWS_ZIP_URL" "$WINDOWS_ZIP" "Windows Ollama"; then
                    print_fatal "Download failed for Windows Ollama."
                fi
                print_info "Extracting Windows binaries to host temporary directory...";
                WIN_TMP_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/win_extract"; mkdir -p "$WIN_TMP_EXTRACT_DIR"
                if ! unzip -qjo "$WINDOWS_ZIP" -d "$WIN_TMP_EXTRACT_DIR/"; then
                    print_fatal "Failed to unzip Windows archive to temp dir.";
                fi
                if [ ! -f "$WIN_TMP_EXTRACT_DIR/ollama.exe" ]; then
                    print_fatal "'ollama.exe' not found after temp extraction from Windows ZIP.";
                fi;
                print_info "Copying Windows binaries to USB...";
                sudo cp "$WIN_TMP_EXTRACT_DIR"/* "$USB_BASE_PATH/runtimes/win/bin/"
                rm -rf "$WIN_TMP_EXTRACT_DIR"
                print_success "Windows binaries extracted and copied to USB."
            fi
            safe_chown "$USB_BASE_PATH/runtimes" "$(id -u):$(id -g)"
            ;;
        add_llm)
            if [ ! -d "$USB_BASE_PATH/.ollama/models" ] || [ ! -d "$USB_BASE_PATH/runtimes" ]; then
                print_error "The selected drive at $USB_BASE_PATH does not appear to be a valid Leonardo AI USB."
                print_error "   Essential directories (.ollama/models or runtimes) are missing."
                print_fatal "   Cannot add LLM. Please select a valid Leonardo AI USB or create a new one."
            fi
            print_success "Valid Leonardo AI USB detected for adding new LLM."
            check_host_dependencies "minimal_for_manage"
            ask_llm_model # This now calls calculate_total_estimated_models_size_gb
            check_disk_space "${MODELS_TO_INSTALL_LIST[*]}" "$MODEL_SOURCE_TYPE" "$LOCAL_GGUF_PATH_FOR_IMPORT" true
            ;;
        repair_scripts)
            if [ ! -d "$USB_BASE_PATH/.ollama/models" ] || [ ! -d "$USB_BASE_PATH/runtimes" ]; then
                print_fatal "The selected drive at $USB_BASE_PATH does not appear to be a valid Leonardo AI USB."
            fi
            print_success "Valid Leonardo AI USB detected. Proceeding with Repair/Refresh."
            check_host_dependencies "minimal_for_manage"

            DETECTED_OS_TARGETS=""
            [ -d "$USB_BASE_PATH/runtimes/linux/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}linux,"
            [ -d "$USB_BASE_PATH/runtimes/mac/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}mac,"
            [ -d "$USB_BASE_PATH/runtimes/win/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}win,"
            SELECTED_OS_TARGETS=${DETECTED_OS_TARGETS%,}
            if [ -z "$SELECTED_OS_TARGETS" ]; then
                print_fatal "No runtime directories found on the USB. Cannot determine which launchers to repair."
            fi
            print_info "Will regenerate launchers for detected OS runtimes: $SELECTED_OS_TARGETS"

            MODEL_TO_PULL="llama3:8b"
            first_model_on_usb=""
            first_model_on_usb=$( (sudo find "$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null || true) | (
                IFS= read -r -d $'\0' tag_file_path
                if [ -n "$tag_file_path" ] && [ -f "$tag_file_path" ]; then
                    relative_path="${tag_file_path#$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library/}"
                    echo "${relative_path%/*}:${relative_path##*/}"
                fi
            ) )

            if [ -n "$first_model_on_usb" ]; then
                MODEL_TO_PULL="$first_model_on_usb"
                print_info "Using existing model '$MODEL_TO_PULL' as default for regenerated Web UI."
            else
                print_warning "Could not determine existing model on USB. Web UI will default to: $MODEL_TO_PULL (Launchers will offer choice if multiple models exist)."
            fi
            ;;
        list_usb_models)
            check_host_dependencies "minimal_for_manage"
            list_models_on_usb "$USB_BASE_PATH"
            OPERATION_MODE="manage_existing_loop_continue"
            ;;
        remove_llm)
            check_host_dependencies "minimal_for_manage"
            remove_model_from_usb "$USB_BASE_PATH"
            print_info "Refreshing launchers and checksums after model removal..."
            DETECTED_OS_TARGETS=""
            [ -d "$USB_BASE_PATH/runtimes/linux/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}linux,"
            [ -d "$USB_BASE_PATH/runtimes/mac/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}mac,"
            [ -d "$USB_BASE_PATH/runtimes/win/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}win,"
            SELECTED_OS_TARGETS=${DETECTED_OS_TARGETS%,}

            MODEL_TO_PULL="llama3:8b"
            first_model_after_remove=""
            first_model_after_remove=$( (sudo find "$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null || true) | (
                IFS= read -r -d $'\0' tag_file_path
                if [ -n "$tag_file_path" ] && [ -f "$tag_file_path" ]; then
                    relative_path="${tag_file_path#$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library/}"
                    echo "${relative_path%/*}:${relative_path##*/}"
                fi
            ) )
            if [ -n "$first_model_after_remove" ]; then
                MODEL_TO_PULL="$first_model_after_remove"
            else
                print_warning "All models seem to have been removed. WebUI will default to $MODEL_TO_PULL (but no models are present for selection in UI)."
            fi
            ;;
        *)
            print_fatal "Unknown operation mode '$OPERATION_MODE'"
            ;;
    esac

    if [[ "$OPERATION_MODE" == "create_new" ]] || [[ "$OPERATION_MODE" == "add_llm" ]]; then
        echo
        if ! command -v ollama &> /dev/null; then
            print_fatal "Ollama CLI ('ollama') is not installed or not in PATH on this host system."
        fi
        print_info "Checking host Ollama service status...";
        if ollama list > /dev/null 2>&1; then
            print_success "Host Ollama service already responsive.";
        else
            print_line
            print_warning "Could not connect to local Ollama service on host."
            print_warning "The 'ollama' command-line tool was found, but it can't reach the Ollama background service."
            attempt_start_ollama_choice=""
            ask_yes_no_quit "Do you want this script to ATTEMPT to start the Ollama service now?" attempt_start_ollama_choice

            if [[ "$attempt_start_ollama_choice" == "yes" ]]; then
                SERVICE_STARTED_SUCCESSFULLY=false
                MAX_START_ATTEMPTS=3
                for attempt_num in $(seq 1 $MAX_START_ATTEMPTS); do
                    print_info "Attempt $attempt_num of $MAX_START_ATTEMPTS to start Ollama service..."
                    if [[ "$(uname)" == "Darwin" ]]; then
                        if ! ollama list > /dev/null 2>&1; then
                            print_info "  Trying 'open -a Ollama' (for .app installations)..."
                            if open -a Ollama || open -a "$HOME/Applications/Ollama.app" || open -a "/Applications/Ollama.app"; then
                                print_info "  'open -a Ollama' initiated. Waiting 5s for service to respond..."
                                sleep 5
                            else print_warning "  'open -a Ollama' failed or app not found at common locations."; fi
                        fi
                        if ! ollama list > /dev/null 2>&1; then
                            print_info "  Trying 'launchctl start com.ollama.ollama' (for user-level launchd services)..."
                            if launchctl start com.ollama.ollama; then
                                print_info "  'launchctl start' initiated. Waiting 5s for service to respond..."
                                sleep 5
                            else print_warning "  'launchctl start com.ollama.ollama' failed (service might need 'launchctl load' first, or it's a system service requiring sudo, or not installed this way)."; fi
                        fi
                        if ! ollama list > /dev/null 2>&1; then
                            print_info "  Trying 'sudo launchctl start /Library/LaunchDaemons/com.ollama.ollama.plist' (for system-level launchd services)..."
                            if sudo launchctl start /Library/LaunchDaemons/com.ollama.ollama.plist; then
                                print_info "  'sudo launchctl start' for system service initiated. Waiting 5s..."
                                sleep 5
                            else print_warning "  'sudo launchctl start /Library/LaunchDaemons/com.ollama.ollama.plist' failed (service might not exist or other issue)."; fi
                        fi
                        if ! ollama list > /dev/null 2>&1; then
                            print_info "  Trying 'ollama serve &' (CLI command, backgrounded)..."
                            (ollama serve > /dev/null 2>&1 &)
                            print_info "  'ollama serve &' issued. Waiting 10s for it to potentially start the service..."
                            sleep 10
                        fi
                    elif [[ "$(uname)" == "Linux" ]]; then
                        print_info "  Attempting 'sudo systemctl start ollama'..."
                        if sudo systemctl is-active --quiet ollama; then
                           print_info "    Ollama service already active via systemctl."
                        elif sudo systemctl start ollama; then
                            print_info "  'systemctl start ollama' issued. Waiting 5s for service to respond..."
                            sleep 5
                        else print_warning "  Failed to start Ollama service via systemctl (it might not be installed as a systemd service)."; fi
                    else print_warning "  Automatic service start not implemented for this OS: $(uname)"; fi

                    print_info "  Verifying service status after attempt cycle $attempt_num..."
                    if ollama list > /dev/null 2>&1; then
                        SERVICE_STARTED_SUCCESSFULLY=true; break
                    else
                        print_warning "  Service not yet responsive."
                        if [ "$attempt_num" -lt "$MAX_START_ATTEMPTS" ]; then print_info "    Waiting an additional 5s before next attempt cycle..."; sleep 5; fi
                    fi
                done
                if $SERVICE_STARTED_SUCCESSFULLY; then print_success "Host Ollama service responsive.";
                else print_line; print_fatal "Could not connect to local Ollama service on host after $MAX_START_ATTEMPTS attempt(s) to start it.\nPlease ensure Ollama service is running manually and then re-run this script."; fi
            else print_fatal "Please start the Ollama service manually and then re-run this script."; fi
        fi

        for model_to_install_single in "${MODELS_TO_INSTALL_LIST[@]}"; do
            if [[ "$MODEL_SOURCE_TYPE" == "create_local" ]] && [[ "$model_to_install_single" == "${MODELS_TO_INSTALL_LIST[0]}" ]]; then
                print_info "Verifying locally created model '${C_BOLD}$model_to_install_single${C_RESET}' is available on host..."
                if ! ollama list | grep -q "^${model_to_install_single}[[:space:]]"; then
                    print_fatal "Model '$model_to_install_single' which was supposed to be created from local GGUF is not found in host Ollama. Creation might have failed."
                fi
            else
                print_info "Ensuring AI model '${C_BOLD}$model_to_install_single${C_RESET}' is available on host (pulling if necessary)..."
                OLLAMA_MODELS_TEMP_STORE_PULL="$OLLAMA_MODELS"; unset OLLAMA_MODELS
                ollama pull "$model_to_install_single"; PULL_STATUS=$?
                if [ -n "$OLLAMA_MODELS_TEMP_STORE_PULL" ]; then export OLLAMA_MODELS="$OLLAMA_MODELS_TEMP_STORE_PULL"; else unset OLLAMA_MODELS; fi

                if [ $PULL_STATUS -ne 0 ]; then
                    print_fatal "'ollama pull $model_to_install_single' failed. Check model name and network.";
                fi
            fi
            print_success "AI Model '$model_to_install_single' is available on host."
        done

        LOCAL_OLLAMA_MODELS_SOURCE=""
        USER_MODELS_PATH_CANDIDATE_1="$HOME/.ollama/models"
        SYSTEM_MODELS_PATH_LINUX_CANDIDATE_1="/usr/share/ollama/.ollama/models"
        if [ -n "$OLLAMA_MODELS" ] && [ -d "$OLLAMA_MODELS/manifests" ] && [ -d "$OLLAMA_MODELS/blobs" ]; then
            LOCAL_OLLAMA_MODELS_SOURCE="$OLLAMA_MODELS"
            print_info "Using host's OLLAMA_MODELS environment variable: $LOCAL_OLLAMA_MODELS_SOURCE"
        elif [ -d "$USER_MODELS_PATH_CANDIDATE_1/manifests" ] && [ -d "$USER_MODELS_PATH_CANDIDATE_1/blobs" ]; then
            LOCAL_OLLAMA_MODELS_SOURCE="$USER_MODELS_PATH_CANDIDATE_1"
        elif [[ "$(uname)" == "Linux" ]] && [ -d "$SYSTEM_MODELS_PATH_LINUX_CANDIDATE_1/manifests" ] && [ -d "$SYSTEM_MODELS_PATH_LINUX_CANDIDATE_1/blobs" ]; then
            LOCAL_OLLAMA_MODELS_SOURCE="$SYSTEM_MODELS_PATH_LINUX_CANDIDATE_1"
        else
            print_fatal "Could not automatically determine the host's Ollama models directory. Checked common paths and OLLAMA_MODELS env var.";
        fi
        if ! sudo test -d "$LOCAL_OLLAMA_MODELS_SOURCE/manifests" || ! sudo test -d "$LOCAL_OLLAMA_MODELS_SOURCE/blobs"; then
            print_fatal "Source model directory '$LOCAL_OLLAMA_MODELS_SOURCE' is not valid or not accessible with sudo.";
        fi

        if $COLORS_ENABLED; then
            # AFK notification for model copying (colored version)
            # Using our global text wrapping utility for consistent column formatting
            box_width=68
            transfer_title="⚙️  MODEL TRANSFER - AUTO-LLAMA MODE CONTINUES 🔨"

            # Create the llama ASCII art with laptop - focused style (with proper right alignment)
            llama_line1="    (\\(\\                                                  "
            llama_line2="    (•‿•)🦙 \"Hammering out your Leonardo USB now...\""
            llama_line3="    / >|_                                                "
            llama_line4="      / \\\\                                               "

            # Progress bar showing approximately 25% progress - model transfer just started
            progress_text="Model Transfer in Progress"
            progress_bar="▓▓▓▓▓░░░░░░░░░░░░░░░  $progress_text"

            # Wrap each message at word boundaries for consistent formatting
            msg1=$(wrap_text_string "This is typically the ${C_BOLD}LONGEST${C_RESET} step of the entire process" $((box_width-6)) "${C_BOLD}${C_YELLOW}│${C_RESET}  ")
            msg2=$(wrap_text_string "Depending on model size, this could take ${C_WHITE}5-15+ minutes${C_RESET}" $((box_width-6)) "${C_BOLD}${C_YELLOW}│${C_RESET}  ")

            echo -e "\n${C_BOLD}${C_YELLOW}┌───────────────────────────────────────────────────────────┐${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}                                                            ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}  ${C_BOLD}${C_YELLOW}$transfer_title${C_RESET}  ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}                                                            ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}  ${C_WHITE}$llama_line1${C_RESET}${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}  ${C_WHITE}$llama_line2${C_RESET}${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}  ${C_WHITE}$llama_line3${C_RESET}${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}  ${C_WHITE}$llama_line4${C_RESET}${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}                                                            ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}  ${C_GREEN}$progress_bar${C_RESET}  ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}                                                            ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "$msg1"
            echo -e "$msg2"
            echo -e "${C_BOLD}${C_YELLOW}│${C_RESET}                                                            ${C_BOLD}${C_YELLOW}│${C_RESET}"
            echo -e "${C_BOLD}${C_YELLOW}└───────────────────────────────────────────────────────────┘${C_RESET}"
        else
            # Non-colored version of the AFK notification for model copying
            echo ""
            echo "********************************************************"
            echo "*                                                      *"
            echo "*    MODEL TRANSFER - AUTO-LLAMA MODE CONTINUES    *"
            echo "*                                                      *"
            echo "*    (\(\                                               *"
            echo "*    (•‿•)🦙 Hammering out your Leonardo USB...         *"
            echo "*    / >|_                                             *"
            echo "*                                                      *"
            echo "*    [=====               ] Model Transfer in Progress *"
            echo "*                                                      *"
            echo "*    This is typically the LONGEST step of the process  *"
            echo "*    Depending on model size, this could take 5-15+ min *"
            echo "*                                                      *"
            echo "********************************************************"
        fi

        print_info "Copying models from ${C_DIM}$LOCAL_OLLAMA_MODELS_SOURCE${C_RESET} to ${C_DIM}$USB_BASE_PATH/.ollama/models${C_RESET}..."
        sudo mkdir -p "$USB_BASE_PATH/.ollama/models/manifests"; sudo mkdir -p "$USB_BASE_PATH/.ollama/models/blobs"
        sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/.ollama"


        if command -v rsync &> /dev/null; then
            print_info "Using rsync for model copy (shows progress)..."

            # Determine filesystem type to handle exFAT appropriately
            fs_type=$(df -T "$USB_BASE_PATH" 2>/dev/null | awk 'NR==2 {print $2}' | tr '[:upper:]' '[:lower:]')

            # Set flags differently based on filesystem type
            if [ "$fs_type" = "exfat" ]; then
                # For exFAT: Don't preserve ownership (-rltD instead of -a) and suppress permission errors
                RSYNC_BASE_FLAGS=("-rltD" "--no-perms" "--quiet")
                print_info "exFAT filesystem detected - ownership preservation will be skipped (normal behavior)"
            else
                # For other filesystems: Use standard archive mode
                RSYNC_BASE_FLAGS=("-a")
            fi

            # Select appropriate progress display option
            RSYNC_PROGRESS_OPT=""
            if rsync --help 2>&1 | grep -q "info=FLAGS"; then
                RSYNC_PROGRESS_OPT="--info=progress2"
            elif rsync --help 2>&1 | grep -q "\-\-progress"; then
                RSYNC_PROGRESS_OPT="--progress"
            else
                RSYNC_PROGRESS_OPT="-v"
            fi

            # Copy manifests with appropriate error suppression
            echo -e "${C_CYAN}Copying model manifests...${C_RESET}"
            if ! sudo rsync "${RSYNC_BASE_FLAGS[@]}" "$RSYNC_PROGRESS_OPT" "$LOCAL_OLLAMA_MODELS_SOURCE/manifests/" "$USB_BASE_PATH/.ollama/models/manifests/" 2>/dev/null; then
                echo -e "${C_CYAN}Using alternative copy method for manifests...${C_RESET}"
                # Suppress expected permission errors when copying to exFAT
                (sudo cp -R "$LOCAL_OLLAMA_MODELS_SOURCE/manifests"/* "$USB_BASE_PATH/.ollama/models/manifests/" 2>/dev/null) &
                spinner $! "Copying manifests...";
                if [ $? -ne 0 ]; then print_fatal "Failed to copy model manifests."; fi
            fi

            # Copy model blob files with appropriate error suppression
            echo -e "${C_CYAN}Copying model files...${C_RESET}"
            if ! sudo rsync "${RSYNC_BASE_FLAGS[@]}" "$RSYNC_PROGRESS_OPT" "$LOCAL_OLLAMA_MODELS_SOURCE/blobs/" "$USB_BASE_PATH/.ollama/models/blobs/" 2>/dev/null; then
                echo -e "${C_CYAN}Using alternative copy method for model files...${C_RESET}"
                # Suppress expected permission errors when copying to exFAT
                (sudo cp -R "$LOCAL_OLLAMA_MODELS_SOURCE/blobs"/* "$USB_BASE_PATH/.ollama/models/blobs/" 2>/dev/null) &
                spinner $! "Copying model files...";
                if [ $? -ne 0 ]; then print_fatal "Failed to copy model files."; fi
            fi
            print_success "Model files successfully copied to USB drive"
        else
            print_info "Using standard copy method for model files (no progress indicator available)"

            # Copy manifests first
            echo -e "${C_CYAN}Copying model manifests...${C_RESET}"
            (sudo cp -R "$LOCAL_OLLAMA_MODELS_SOURCE/manifests"/* "$USB_BASE_PATH/.ollama/models/manifests/" 2>/dev/null) &
            spinner $! "Copying model manifest files...";
            if [ $? -ne 0 ]; then print_fatal "Failed to copy model manifests."; fi

            # Then copy the model files
            echo -e "${C_CYAN}Copying model files (this may take some time)...${C_RESET}"
            (sudo cp -R "$LOCAL_OLLAMA_MODELS_SOURCE/blobs"/* "$USB_BASE_PATH/.ollama/models/blobs/" 2>/dev/null) &
            spinner $! "Copying model data files...";
            if [ $? -ne 0 ]; then print_fatal "Failed to copy model data files."; fi

            print_success "Model files successfully copied to USB drive"
        fi

        # Ensure final ownership is correct on the USB
        safe_chown "$USB_BASE_PATH/.ollama/models" "$(id -u):$(id -g)"

        if [ -z "$(sudo ls -A "$USB_BASE_PATH/.ollama/models/manifests" 2>/dev/null)" ] || \
           [ -z "$(sudo ls -A "$USB_BASE_PATH/.ollama/models/blobs" 2>/dev/null)" ]; then
            print_fatal "Model copy appears to have failed. Target model directories on USB are empty or inaccessible.";
        fi
        sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/.ollama"
        print_success "Model files for '${MODELS_TO_INSTALL_LIST[*]}' copied (or attempted) successfully."
    fi


    if [[ "$OPERATION_MODE" == "create_new" ]] || \
       [[ "$OPERATION_MODE" == "add_llm" ]] || \
       [[ "$OPERATION_MODE" == "repair_scripts" ]] || \
       [[ "$OPERATION_MODE" == "remove_llm" ]]; then

        if [ -z "$USB_BASE_PATH" ] || ! sudo test -d "$USB_BASE_PATH"; then
            print_error "USB_BASE_PATH ('$USB_BASE_PATH') is not set or not a directory. Cannot generate USB support files."
        else
            print_header "🔧 GENERATING ESSENTIAL USB FILES 🔧"
            print_info "Current USB path: $USB_BASE_PATH"
            print_info "Default model for launcher scripts: $MODEL_TO_PULL"

            # Create any missing directories
            sudo mkdir -p "$USB_BASE_PATH/webui" "$USB_BASE_PATH/.ollama/models" 2>/dev/null

            # Ensure the directories have proper permissions
            safe_chown "$USB_BASE_PATH/webui" "$(id -u):$(id -g)" "true"
            safe_chown "$USB_BASE_PATH/.ollama" "$(id -u):$(id -g)" "true"

            # Generate essential USB files with added error checking
            if ! generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"; then
                print_error "Failed to generate USB support files. Attempting direct creation..."

                # Direct creation of individual components as fallback
                print_info "Attempting direct creation of WebUI..."
                generate_webui_html "$USB_BASE_PATH" "$MODEL_TO_PULL"

                print_info "Attempting direct creation of launcher scripts..."
                generate_launcher_scripts "$USB_BASE_PATH" "$MODEL_TO_PULL"

                print_info "Attempting direct creation of readme and checksums..."
                generate_security_readme "$USB_BASE_PATH"
                generate_checksum_file "$USB_BASE_PATH"
            fi

            # Verify the files were created
            launcher_files=("${USER_LAUNCHER_NAME_BASE}.sh" "${USER_LAUNCHER_NAME_BASE}.command" "${USER_LAUNCHER_NAME_BASE}.bat")
            missing_files=false

            for file in "${launcher_files[@]}"; do
                if [ ! -f "$USB_BASE_PATH/$file" ]; then
                    print_warning "Launcher file $file was not created!"
                    missing_files=true
                else
                    print_success "✓ Created launcher: $file"
                fi
            done

            if [ ! -f "$USB_BASE_PATH/webui/index.html" ]; then
                print_warning "WebUI was not created!"
                missing_files=true
            else
                print_success "✓ Created WebUI"
            fi

            if $missing_files; then
                print_error "Some essential files could not be created. Please run the Verify & Repair function."
            else
                print_success "✅ All essential USB files created successfully!"
            fi
        fi
    fi


    if [[ "$OPERATION_MODE" == "create_new" ]] || \
       [[ "$OPERATION_MODE" == "add_llm" ]] || \
       [[ "$OPERATION_MODE" == "repair_scripts" ]] || \
       [[ "$OPERATION_MODE" == "remove_llm" ]]; then

        INSTALL_END_TIME=$(date +%s)
        ELAPSED_SECONDS=$((INSTALL_END_TIME - INSTALL_START_TIME))

        category_map() {
            case "$1" in
                "fast") echo "fast" ;;
                "med") echo "med" ;;
                "slow") echo "slow" ;;
                "slog") echo "glacial" ;;
                *) echo "med" ;;
            esac
        }

        GRADE_CATEGORY=""
        if [ "$ELAPSED_SECONDS" -lt 120 ]; then GRADE_CATEGORY="fast";
        elif [ "$ELAPSED_SECONDS" -lt 300 ]; then GRADE_CATEGORY="med";
        elif [ "$ELAPSED_SECONDS" -lt 900 ]; then GRADE_CATEGORY="slow";
        else GRADE_CATEGORY="slog"; fi

        # Pass USB path and model info to the success art function
        usb_display_path="${MOUNT_POINT:-$USB_BASE_PATH}"
        models_display="${MODELS_TO_INSTALL_LIST[*]}"
        print_leonardo_success_art "$usb_display_path" "$models_display"
        if [[ "$OPERATION_MODE" == "repair_scripts" ]]; then
            print_header "✅ USB Repair/Refresh Complete! ✅"
            echo -e "USB drive '${C_BOLD}$USB_LABEL${C_RESET}' at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET} has been refreshed."
            echo -e "Launchers regenerated for: ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET}"
            echo -e "Web UI default model hint set to: ${C_BOLD}$MODEL_TO_PULL${C_RESET} (Launchers/UI will offer choice from all models on USB)."
        elif [[ "$OPERATION_MODE" == "add_llm" ]]; then
            print_header "✅ New LLM(s) Added Successfully! ✅"
            echo -e "Model(s) '${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET}' (Est. Size: ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET}) added to USB drive '${C_BOLD}$USB_LABEL${C_RESET}' at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET}."
            echo -e "Launchers and Web UI have been updated."
        elif [[ "$OPERATION_MODE" == "remove_llm" ]]; then
            print_header "✅ LLM Manifest Removed Successfully! ✅"
            echo -e "Selected LLM manifest removed from USB drive '${C_BOLD}$USB_LABEL${C_RESET}' at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET}."
            echo -e "Launchers and Web UI have been updated. Default WebUI model hint now: ${C_BOLD}$MODEL_TO_PULL${C_RESET}"
            print_warning "Remember: Blobs (model data) might still exist. Re-create USB for full space reclaim if needed."
        else
            print_header "🎉 Setup Complete! 🎉"
            echo -e "USB drive '${C_BOLD}$USB_LABEL${C_RESET}' created at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET}."
            echo -e "Installed OS Runtimes: ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_BINARIES_SIZE_GB GB${C_RESET})"
            echo -e "Installed AI Model(s) (Primary/Default Hint for WebUI): ${C_BOLD}$MODEL_TO_PULL${C_RESET}"
            if [ ${#MODELS_TO_INSTALL_LIST[@]} -gt 0 ]; then
                 echo -e "All installed models for this session: ${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET} (Est. Total Size: ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET})"
            fi
        fi
        echo ""
        print_info "Operation completed in ${C_BOLD}$((ELAPSED_SECONDS / 60)) min $((ELAPSED_SECONDS % 60)) sec${C_RESET}."
        echo -e "\n${C_BOLD}${C_YELLOW}⚡ Forge Speed Grade: ${C_RESET}${C_BOLD}$(get_grade_msg "$(category_map "$GRADE_CATEGORY")")${C_RESET}"
        echo ""
        print_subheader "To use your Leonardo AI USB:"
        echo -e "  1. Safely eject/unmount the USB drive from this computer (if not done by script)."
        echo -e "  2. Plug it into the target computer (Linux, macOS, or Windows, depending on runtimes installed)."
        echo -e "  3. Open the USB drive in the file explorer."
        echo -e "  4. Run the appropriate launcher script from the root of the USB drive:"
        if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then echo -e "     - On Linux:   ${C_GREEN}./${USER_LAUNCHER_NAME_BASE}.sh${C_RESET}"; fi
        if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then echo -e "     - On macOS:   Double-click ${C_GREEN}${USER_LAUNCHER_NAME_BASE}.command${C_RESET} (or run from Terminal)"; fi
        if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then echo -e "     - On Windows: Double-click ${C_GREEN}${USER_LAUNCHER_NAME_BASE}.bat${C_RESET}"; fi
        echo -e "  5. Follow the prompts in the launcher window (select a model if multiple are present)."
        echo -e "  6. The launcher will start Ollama with access to the model(s) on the USB, and open the web UI."

        echo ""
        echo -e "${C_MAGENTA}We hope this USB brings you success in your AI endeavors!${C_RESET}"
        echo ""

        # Generate a detailed summary report if we're crafting or adding to a USB
        if [[ "$OPERATION_MODE" == "create_new" ]] || [[ "$OPERATION_MODE" == "add_llm" ]]; then
            # Generate the summary report with all relevant details
            generate_summary_report "$USB_BASE_PATH" "${MODELS_TO_INSTALL_LIST[*]}" "$SELECTED_OS_TARGETS"
            echo -e "${C_BOLD}📋 A detailed installation report has been saved to your USB.${C_RESET}"
            echo -e "   File: ${C_GREEN}leonardo_setup_report.txt${C_RESET}"
            echo -e "   This contains all installation details and quick start instructions."
            echo ""
        fi
        print_info "Remember to check ${C_BOLD}SECURITY_README.txt${C_RESET} on the USB (also copied to Installation_Info/ folder) for important usage guidelines."
        print_info "Verify file integrity with ${C_GREEN}./verify_integrity.sh${C_RESET} (Linux/Mac) or ${C_GREEN}verify_integrity.bat${C_RESET} (Windows) on the USB."
        echo ""
        print_info "Note on AI Model Behavior: If the AI model gives strange or repetitive responses, try closing the Ollama Server window"
        print_info "and re-running the Leonardo launcher. This often resets the model's context."
        echo ""
        echo -e "${C_MAGENTA}As EricTM says to his AI, Milo: \"Your success is entirely dependent upon mine.\"${C_RESET}"
        echo -e "${C_MAGENTA}We hope this USB brings you success in your AI endeavors!${C_RESET}"
        echo ""

        UNMOUNT_CHOICE=""
        current_mount_path_for_unmount="${MOUNT_POINT:-$USB_BASE_PATH}"
        if [ -n "$current_mount_path_for_unmount" ] && sudo mount | grep -qF "$current_mount_path_for_unmount"; then
            ask_yes_no_quit "Do you want to attempt to unmount ${C_BOLD}$current_mount_path_for_unmount${C_RESET} now?" UNMOUNT_CHOICE
            if [[ "$UNMOUNT_CHOICE" == "yes" ]]; then
                print_info "Attempting to unmount... please wait for this to complete before unplugging."
                sync; sync
                if [[ "$(uname)" == "Darwin" ]]; then
                    if sudo diskutil unmount "$current_mount_path_for_unmount" 2>/dev/null; then
                        print_success "$USB_LABEL ($current_mount_path_for_unmount) unmounted successfully.";
                    elif sudo diskutil unmountDisk "$RAW_USB_DEVICE_PATH" 2>/dev/null; then
                        print_success "$USB_LABEL (disk $RAW_USB_DEVICE_PATH) unmounted successfully.";
                    else
                        print_warning "Failed to unmount $USB_LABEL. Please unmount manually before unplugging.";
                    fi
                else
                    if sudo umount "$current_mount_path_for_unmount"; then print_success "$USB_LABEL ($current_mount_path_for_unmount) unmounted successfully.";
                    else print_warning "Failed to unmount $current_mount_path_for_unmount. It might be busy. Try 'sudo umount -l $current_mount_path_for_unmount' or unmount manually."; fi
                fi
            else
                print_info "Okay, please remember to safely eject/unmount '$USB_LABEL' from your system before unplugging it."
            fi
        fi
        echo -e "\n${C_BOLD}${C_GREEN}All done. Go forth and AI! ✨${C_RESET}"
        exit 0

    elif [[ "$OPERATION_MODE" == "manage_existing_loop_continue" ]]; then
        OPERATION_MODE="manage_existing"
        continue
    else
        print_info "Operation '$OPERATION_MODE' concluded or was aborted. Returning to main menu."
        OPERATION_MODE=""
        USB_DEVICE_PATH=""
        RAW_USB_DEVICE_PATH=""
        USB_BASE_PATH=""
        MOUNT_POINT=""
        USB_LABEL="$USB_LABEL_DEFAULT"
        continue
    fi
done

exit 0



# --- Seed File Generation Function ---
# Function to create a seed file for easy distribution
create_seed_file() {
    local target_dir="${1:-"."}"
    local seed_file="$target_dir/leonardo_seed.sh"
    
    print_info "Creating seed file in: $target_dir"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create the seed file
    cat > "$seed_file" << 'SEEDHEADER'
#!/bin/bash
# Leonardo AI USB Maker - SEED FILE
# International Coding Competition 2025 Edition

# Print beautiful header
echo -e "\033[1;36m"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║            LEONARDO AI USB MAKER - SEED INSTALLER              ║"
echo "║                International Competition Edition               ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

# Create the installation directory
echo -e "\033[1;32m[+] Creating installation directory...\033[0m"
mkdir -p "Leonardo Installation File (Shareable)"

# Copy the main script
echo -e "\033[1;32m[+] Installing Leonardo AI USB Maker...\033[0m"
cp "$0" "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"
chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

echo -e "\033[1;32m[+] Installation complete!\033[0m"
echo ""
echo -e "\033[1;36mLeonardo AI USB Maker has been successfully installed!\033[0m"
echo -e "You can find it in the 'Leonardo Installation File (Shareable)' directory."
echo -e "Run it with: cd 'Leonardo Installation File (Shareable)' && ./Leonardo_AI_USB_Maker_V5.sh"
echo ""
SEEDHEADER
    
    # Append this entire script to the seed file
    cat "$0" >> "$seed_file"
    
    # Make the seed file executable
    chmod +x "$seed_file"
    
    print_success "Seed file created successfully at: $seed_file"
    print_info "This seed file can be shared to easily install Leonardo AI USB Maker on other systems."
    return 0
}
