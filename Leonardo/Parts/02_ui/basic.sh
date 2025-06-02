# ==============================================================================
# Basic UI Components
# ==============================================================================

# Repeat a character N times (Unicode-safe)
repeat_char() {
    local char="$1"
    local count="$2"
    local result=""
    for ((i=0; i<count; i++)); do
        result+="$char"
    done
    echo -n "$result"
}

# Global UI width for all boxes and headers
UI_WIDTH=71

# Print a horizontal line with consistent styling
print_hr() {
    local char="${1:-$UI_BORDER_CHAR}"
    local width=${2:-$UI_WIDTH}
    local color="${3:-$COLOR_DIM}"
    if [[ "$char" =~ [═╔╗╚╝║] ]]; then
        echo -e "${color}$(repeat_char "$char" "$width")${COLOR_RESET}"
    else
        echo -e "${color}$(printf "%${width}s" | tr ' ' "$char")${COLOR_RESET}"
    fi
}

# Print a decorative line
print_line() { 
    local width=${1:-$UI_WIDTH}
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        echo -e "${COLOR_DIM}$(printf '%*s' "$width" | tr ' ' '=')${COLOR_RESET}"
    else
        echo -e "${COLOR_DIM}$(repeat_char "═" "$((width))")${COLOR_RESET}"
    fi
}

# Print a thin divider line for subtle section breaks
print_divider_thin() { 
    echo -e "${COLOR_DIM}⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯${COLOR_RESET}"; 
}

# Print a double line for major section divisions
print_double_line() { 
    local width=${1:-$UI_WIDTH}
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        echo -e "${COLOR_BOLD}${COLOR_MAGENTA}$(printf '%*s' "$width" | tr ' ' '=')${COLOR_RESET}"
    else
        echo -e "${COLOR_BOLD}${COLOR_MAGENTA}╔$(repeat_char "═" "$((width-2))")╗${COLOR_RESET}"
    fi
}

# Print a centered text with optional color
print_centered() {
    local text="$1"
    local width=${2:-$UI_WIDTH}
    local color="${3:-}"
    local padding=$(( (width - ${#text}) / 2 ))
    if [[ $padding -lt 0 ]]; then padding=0; fi
    if [[ -n "$color" ]]; then
        printf "%${padding}s%s%${padding}s\n" "" "${color}${text}${COLOR_RESET}" ""
    else
        printf "%${padding}s%s%${padding}s\n" "" "$text" ""
    fi
}

# Print a main section header with decorative box
print_section_header() {
    local title="$1"
    local width=${2:-$UI_WIDTH} # Argument index adjusted as char arg is removed for simplicity
    local ascii_char="="
    local unicode_char="─"
    local h_line_segment

    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        h_line_segment="$(printf '%*s' "$((width-2))" | tr ' ' "$ascii_char")"
    else
        h_line_segment="$(repeat_char "$unicode_char" "$((width-2))")"
    fi
    
    echo
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}╭${h_line_segment}╮${COLOR_RESET}"
    local visible_len=$(strip_ansi "$title" | awk '{print length}')
    local pad_len=$((width-4-visible_len))
    if [ $pad_len -lt 0 ]; then pad_len=0; fi
    printf "${COLOR_BOLD}${COLOR_MAGENTA}│ %s%*s │${COLOR_RESET}\n" "$title" $pad_len ""
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}╰${h_line_segment}╯${COLOR_RESET}"
    echo
}

# Print a secondary header with subtle styling
print_section_subheader() {
    local title="$1"
    local width=${2:-$UI_WIDTH}
    local prefix="─── "
    local suffix=" "
    local visible_len=$(strip_ansi "$title" | awk '{print length}')
    local pad_len=$((width - 4 - ${#prefix} - visible_len - ${#suffix}))
    if [ $pad_len -lt 0 ]; then pad_len=0; fi
    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╭${prefix}${title}${suffix}$(repeat_char "─" $pad_len)╮${COLOR_RESET}"
    echo -e "${COLOR_DIM}╰$(repeat_char "─" $((width-2)))╯${COLOR_RESET}"
}

# Strip ANSI escape codes for visible length calculation
strip_ansi() {
    # Usage: strip_ansi "$string"
    echo -e "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

# Print a stylized message box with proper formatting
print_message_box() {
    local title_param="$1"
    local message="$2"
    local width=${3:-$UI_WIDTH}
    local color=${4:-$COLOR_BLUE}

    local h_char_unicode="─"
    local h_char_ascii="="
    local h_char=$h_char_unicode
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        h_char=$h_char_ascii
    fi

    local horizontal_line_len=$((width - 2))
    local content_area_width=$((width - 4))

    local top_h_segment
    local bottom_h_segment=$(repeat_char "$h_char" "$horizontal_line_len")

    echo # Top margin

    # Top border
    if [ -n "$title_param" ]; then
        local visible_title_len=$(strip_ansi "$title_param" | awk '{print length}')
        # Line is: ╭─ Title ─...─╮. Chars for segment: width - ╭╮ - ─<space> - <space>─ - Title
        local title_segment_len=$((horizontal_line_len - 2 - 1 - visible_title_len))
        if [ $title_segment_len -lt 0 ]; then title_segment_len=0; fi
        top_h_segment=$(repeat_char "$h_char" "$title_segment_len")
        echo -e "${color}╭─ ${COLOR_BOLD}${title_param}${COLOR_RESET}${color} ${top_h_segment}╮${COLOR_RESET}"
    else
        echo -e "${color}╭${bottom_h_segment}╮${COLOR_RESET}"
    fi

    # Message content
    local line_start=0
    local message_len=${#message}
    if [ $message_len -eq 0 ]; then # Handle empty message: print one empty content line
        print_box_row "" "$color" "$width"
    else
        while [ $line_start -lt $message_len ]; do
            # Extract a chunk that visually fits, then get its actual character length for substringing
            local current_chunk=""
            local current_visible_len=0
            local actual_char_count=0
            
            # Greedily build line_text up to content_area_width visible characters
            local temp_line_start=$line_start
            while [ $temp_line_start -lt $message_len ] && [ $current_visible_len -lt $content_area_width ]; do
                # Add one character at a time to handle ANSI codes correctly
                char_and_ansi="${message:$temp_line_start}" # Get rest of string
                # Find the next character or ANSI sequence
                if [[ $char_and_ansi =~ ^(\\[0-9]{3} | \\e\[[0-9;]*[mK] | . ) ]]; then # regex for char or ansi
                    next_segment="${BASH_REMATCH[1]}"
                else # fallback for unusual characters, take one byte
                    next_segment="${message:$temp_line_start:1}"
                fi
                
                current_chunk+="$next_segment"
                current_visible_len=$(strip_ansi "$current_chunk" | awk '{print length}')
                temp_line_start=$((temp_line_start + ${#next_segment}))
                actual_char_count=$((actual_char_count + ${#next_segment}))

                if [ $current_visible_len -gt $content_area_width ]; then # Overshot
                    current_chunk=${current_chunk::$((${#current_chunk} - ${#next_segment}))} # Remove last segment
                    actual_char_count=$((actual_char_count - ${#next_segment}))
                    break
                fi
            done
            local text_to_print="${message:$line_start:$actual_char_count}"
            line_start=$((line_start + actual_char_count))

            local visible_text_len=$(strip_ansi "$text_to_print" | awk '{print length}')
            local padding_needed=$((content_area_width - visible_text_len))
            if [ $padding_needed -lt 0 ]; then padding_needed=0; fi
            local line_padding_spaces=$(printf '%*s' "$padding_needed" '')
            
            echo -e "${color}│ ${text_to_print}${line_padding_spaces} ${color}│${COLOR_RESET}"
        done
    fi

    # Bottom border
    echo -e "${color}╰${bottom_h_segment}╯${COLOR_RESET}"
    echo # Bottom margin
}

# Enhanced print functions with emojis and colors

# Print an info message
print_info() { 
    echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_RESET}"; 
}

# Print a success message
print_success() { 
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"; 
}

# Print a warning message
print_warning() { 
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"; 
}

# Print an error message
print_error() { 
    echo -e "${COLOR_RED}❌ ERROR: $1${COLOR_RESET}"; 
}

# Print a debug message (only shown when DEBUG=true)
print_debug() { 
    if [ -n "${DEBUG+x}" ] && [ "$DEBUG" = "true" ]; then 
        echo -e "${COLOR_GREY}DEBUG: $1${COLOR_RESET}"; 
    fi; 
}

# Print a fatal error message and exit
print_fatal() { 
    echo -e "${COLOR_BOLD}${COLOR_RED}☠️ FATAL: $1${COLOR_RESET}"; 
    exit 1; 
}

# Print a prompt for user input
print_prompt() { 
    echo -ne "${COLOR_CYAN}➡️  $1${COLOR_RESET}"; 
}

# Print a perfectly padded row inside a box
# Usage: print_box_row <content> <box_color> <width>
print_box_row() {
    local content="$1"
    local color="$2"
    local width="${3:-$UI_WIDTH}"
    local content_width=$((width - 4))
    local visible_len=$(strip_ansi "$content" | awk '{print length}')
    local pad_len=$((content_width - visible_len))
    if [ $pad_len -lt 0 ]; then pad_len=0; fi
    local padding_spaces=$(printf '%*s' "$pad_len" '')
    echo -e "${color}║ ${content}${padding_spaces} ║${COLOR_RESET}"
}

# Print a selectable option
print_option() { 
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}[$1]${COLOR_RESET} $2"; 
}

# Print the Leonardo title art with friendly llama mascot
print_leonardo_title_art() {
    local title_text="Leonardo AI USB Maker ✨ - Forge Your Portable AI Future!"
    local box_color="${COLOR_BOLD}${COLOR_GREEN}"
    local internal_border_char_unicode="║"
    local internal_border_char_ascii="||"
    local internal_border_char=$internal_border_char_unicode

    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        internal_border_char=$internal_border_char_ascii
    fi

    # Content width is UI_WIDTH minus 2 for side borders and 2 for internal padding spaces
    local content_width=$((UI_WIDTH - 4))

    # Calculate padding for the title text
    local visible_title_len=$(strip_ansi "$title_text" | awk '{print length}')
    local title_padding_total=$((content_width - visible_title_len))
    local title_padding_left=$((title_padding_total / 2))
    local title_padding_right=$((title_padding_total - title_padding_left))
    if [ $title_padding_total -lt 0 ]; then # text is wider than content area
        title_padding_left=0
        title_padding_right=0
        # Optionally truncate title_text here if it's too long
    fi
    local title_pad_left_spaces=$(printf '%*s' "$title_padding_left" '')
    local title_pad_right_spaces=$(printf '%*s' "$title_padding_right" '')

    # Calculate padding for empty lines
    local empty_line_padding=$(printf '%*s' "$content_width" '')

    echo -e "${box_color}"
    # Top border - print_double_line already handles UI_WIDTH and ASCII/Unicode
    # It prints ╔════...══╗. We need to ensure its color matches.
    # However, print_double_line has its own color (MAGENTA). We'll use print_hr for top/bottom.
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        echo -e "${box_color}$(repeat_char "=" "$UI_WIDTH")${COLOR_RESET}"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        print_box_row "${title_pad_left_spaces}${title_text}${title_pad_right_spaces}    " "$box_color" "$UI_WIDTH"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        echo -e "${box_color}$(repeat_char "=" "$UI_WIDTH")${COLOR_RESET}"
    else
        echo -e "${box_color}╔$(repeat_char "═" "$((UI_WIDTH-1))")╗${COLOR_RESET}"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        print_box_row "${title_pad_left_spaces}${title_text}${title_pad_right_spaces}    " "$box_color" "$UI_WIDTH"
        print_box_row "${empty_line_padding}  " "$box_color" "$UI_WIDTH"
        echo -e "${box_color}╚$(repeat_char "═" "$((UI_WIDTH-1))")╝${COLOR_RESET}"
    fi

    echo -e "${COLOR_RESET}" # Reset color from box_color just in case
    echo "         (\\(\\   "
    echo "         (•ᴗ•)🦙 "
    echo "         / >)_/"
    echo "        \"Let's make an AI USB!\""
    echo ""
    echo -e "  (Brought to you by the Leonardo team)${COLOR_RESET}"
    echo ""
}

# Print success art when an operation completes successfully
print_leonardo_success_art() {
    echo -e "${COLOR_BOLD}${COLOR_GREEN}"
    echo ""
    echo "           (\\(\\   "
    echo "           (•ᴖ•)🦙  "
    echo "           / >💾 USB "
    echo "          \"Forge Complete!\""
    echo ""
    echo "    🚀 Congratulations! Your Leonardo AI USB is Forged & Ready! 🚀"
    echo -e "${COLOR_RESET}"
}

# Print an animated notification box with different styles
print_notification_box() {
    local message="$1"
    local type="${2:-info}"  # info, success, warning, error
    local width=${3:-$UI_WIDTH}
    local box_width=$((width - 8))
    local color
    local icon
    local title
    local h_char_unicode="─"
    local h_char_ascii="="
    local top_line_segment
    local bottom_line_segment

    # Set color and icon based on notification type
    case "$type" in
        success)
            color="$COLOR_GREEN"
            icon="✅"
            title="SUCCESS"
            ;;
        warning)
            color="$COLOR_YELLOW"
            icon="⚠️"
            title="WARNING"
            ;;
        error)
            color="$COLOR_RED"
            icon="❌"
            title="ERROR"
            ;;
        *) # Default is info
            color="$COLOR_BLUE"
            icon="ℹ️"
            title="INFO"
            ;;
    esac

    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        top_line_segment="$(printf '%*s' $((box_width - ${#title} - 6)) | tr ' ' "$h_char_ascii")"
        bottom_line_segment="$(printf '%*s' $((box_width)) | tr ' ' "$h_char_ascii")"
    else
        top_line_segment="$(repeat_char "$h_char_unicode" "$((box_width - ${#title} - 6))")"
        bottom_line_segment="$(repeat_char "$h_char_unicode" "$((box_width))")"
    fi
    
    # Print the notification box
    echo
    # Top border with title
    echo -e "${color}╭──── ${COLOR_BOLD}$title${COLOR_RESET} ${color}${top_line_segment}╮${COLOR_RESET}"
    
    # Message line with icon
    local msg_line="${icon} ${message}"
    print_box_row "$msg_line" "$color" "$width"
    
    # Bottom border
    echo -e "${color}╰${bottom_line_segment}╯${COLOR_RESET}"
    echo
}

# Print a fancy gradient divider
print_gradient_divider() {
    local width=${1:-$UI_WIDTH}
    local char
    if [ "${LEONARDO_ASCII_UI}" = true ]; then
        char="="
        # ASCII fallback is single-byte, safe for printf/tr
        echo -e "${COLOR_GRADIENT_1}$(printf '%*s' $((width/4)) | tr ' ' "$char")${COLOR_GRADIENT_2}$(printf '%*s' $((width/4)) | tr ' ' "$char")${COLOR_GRADIENT_3}$(printf '%*s' $((width/4)) | tr ' ' "$char")${COLOR_GRADIENT_4}$(printf '%*s' $((width/4 + width%4)) | tr ' ' "$char")${COLOR_RESET}"
    else
        char="═"
        # Unicode: use repeat_char for each segment
        local q1=$((width/4))
        local q2=$((width/4))
        local q3=$((width/4))
        local q4=$((width/4 + width%4))
        echo -e "${COLOR_GRADIENT_1}$(repeat_char "$char" "$q1")${COLOR_GRADIENT_2}$(repeat_char "$char" "$q2")${COLOR_GRADIENT_3}$(repeat_char "$char" "$q3")${COLOR_GRADIENT_4}$(repeat_char "$char" "$q4")${COLOR_RESET}"
    fi
}

# Print a task completion status box
print_task_status() {
    local task="$1"
    local status="$2" # success, warning, error, pending
    local width=${3:-$UI_WIDTH}
    local box_width=$((width - 4))
    local status_color
    local status_icon
    local status_text
    
    # Set color and icon based on status
    case "$status" in
        success)
            status_color="$COLOR_GREEN"
            status_icon="✅"
            status_text="COMPLETED"
            ;;
        warning)
            status_color="$COLOR_YELLOW"
            status_icon="⚠️"
            status_text="WARNING"
            ;;
        error)
            status_color="$COLOR_RED"
            status_icon="❌"
            status_text="FAILED"
            ;;
        pending)
            status_color="$COLOR_CYAN"
            status_icon="⏳"
            status_text="PENDING"
            ;;
        *) # Default is pending
            status_color="$COLOR_CYAN"
            status_icon="⏳"
            status_text="PENDING"
            ;;
    esac
    
    # Print the status box
    echo -e "${COLOR_DIM}┌$(printf '%*s' $((box_width)) | tr ' ' '─')┐${COLOR_RESET}"
    printf "${COLOR_DIM}│ %-$((box_width - 15))s${COLOR_RESET} ${status_color}$status_icon $status_text${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET}\n" "$task"
    echo -e "${COLOR_DIM}└$(printf '%*s' $((box_width)) | tr ' ' '─')┘${COLOR_RESET}"
}

# Clear the screen and show the Leonardo title art
clear_screen_and_show_art() {
    # Use tput if available, otherwise use clear command
    if [ -n "$TPUT_CMD_PATH" ] && [ "$TPUT_CLEAR_POSSIBLE" = true ]; then
        "$TPUT_CMD_PATH" clear
    else
        clear
    fi
    print_leonardo_title_art
}

# Display a data destruction warning screen with intense llama warning
show_data_destruction_warning() {
    local device="$1"
    local operation="${2:-format}"
    
    clear_screen_and_show_art
    
    # Show the warning box with red border and intense llama
    echo -e "${COLOR_RED}╭───────────────── ${COLOR_BOLD}⚠️ DATA DESTRUCTION WARNING ⚠️${COLOR_RESET} ${COLOR_RED}────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  ${COLOR_BOLD}${COLOR_RED}(ಠ‿ಠ)🦙 ALL DATA ON THIS DEVICE WILL BE DESTROYED!${COLOR_RESET}  ${COLOR_RED}│${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  Device: ${COLOR_BOLD}$device${COLOR_RESET}                               ${COLOR_RED}│${COLOR_RESET}"
    echo -e "${COLOR_RED}│  Operation: ${COLOR_BOLD}$operation${COLOR_RESET}                         ${COLOR_RED}│${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  This operation cannot be undone. All data on the selected   │${COLOR_RESET}"
    echo -e "${COLOR_RED}│  device will be permanently erased.                           │${COLOR_RESET}"
    echo -e "${COLOR_RED}│                                                              │${COLOR_RESET}"
    echo -e "${COLOR_RED}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo
    print_warning "Please make sure you have selected the correct device!"
    echo
}

# Show script header with version information
show_header() {
    if [ "$QUIET" != true ]; then
        clear_screen_and_show_art
        print_info "Version: $SCRIPT_VERSION"
        print_info "Log file: $LOG_FILE"
        [ "$DRY_RUN" = true ] && print_warning "DRY RUN MODE: No changes will be made"
        echo
    fi
}

# Show help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help       Show this help message and exit
  -v, --verbose    Enable verbose output
  -q, --quiet      Suppress non-error output
  --dry-run        Don't make any changes, just show what would be done
  --force          Skip confirmation prompts
  --no-color       Disable colored output

Examples:
  # Run in interactive mode
  sudo ./$(basename "$0")
  
  # Run with verbose output
  sudo ./$(basename "$0") -v
  
  # Perform a dry run
  sudo ./$(basename "$0") --dry-run
EOF
}
