# ==============================================================================
# Basic UI Components
# ==============================================================================
# Description: Basic UI components for Leonardo AI Universal
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/colors.sh
# ==============================================================================

# Clear the screen if possible
clear_screen() {
    if [[ "$TPUT_CLEAR_POSSIBLE" == "true" ]]; then
        "$TPUT_CMD_PATH" clear
    else
        echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
    fi
}

# Create a horizontal line of specified length and character
print_line() {
    local length="$1"
    local char="${2:-$BOX_H}"
    local color="${3:-$NC}"
    
    # Print the line
    printf "${color}%*s${NC}\n" "$length" | tr ' ' "$char"
}

# Print a string centered in a box of specified width
print_centered() {
    local text="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$NC}"
    
    # Remove ANSI color codes for length calculation
    local plain_text
    plain_text=$(echo -e "$text" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    
    # Calculate padding
    local padding=$(( (width - ${#plain_text}) / 2 ))
    
    # If padding is negative, truncate the text
    if [[ $padding -lt 0 ]]; then
        text="${text:0:$width-3}..."
        padding=0
    fi
    
    # Print the centered text
    printf "%*s${color}%s${NC}%*s\n" $padding "" "$text" $padding ""
}

# Print a box line with the given character
print_box_line() {
    local char="$1"
    local width="${2:-$UI_WIDTH}"
    local left_char="${3:-$char}"
    local right_char="${4:-$char}"
    local color="${5:-$NC}"
    
    # Calculate the inner width
    local inner_width=$((width - 2))
    
    # Print the box line
    printf "${color}%s%*s%s${NC}\n" "$left_char" "$inner_width" | tr ' ' "$char" | tr -d '\n'
    printf "%s\n" "$right_char"
}

# Print a box with a title
print_box_header() {
    local title="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$CYAN}"
    
    # Print the top border
    print_box_line "$BOX_H" "$width" "$BOX_TL" "$BOX_TR" "$color"
    
    # Print the title if provided
    if [[ -n "$title" ]]; then
        printf "${color}${BOX_V}${NC} %-$((width-4))s ${color}${BOX_V}${NC}\n" "$title"
        print_box_line "$BOX_H" "$width" "$BOX_LT" "$BOX_RT" "$color"
    fi
}

# Print a box footer
print_box_footer() {
    local width="${1:-$UI_WIDTH}"
    local color="${2:-$CYAN}"
    
    # Print the bottom border
    print_box_line "$BOX_H" "$width" "$BOX_BL" "$BOX_BR" "$color"
}

# Print box content with left and right borders
print_box_content() {
    local text="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$CYAN}"
    local left_pad="${4:-1}"
    local right_pad="${5:-1}"
    
    # Calculate content width (accounting for borders and padding)
    local content_width=$((width - 2 - left_pad - right_pad))
    
    # Wrap text to content width and add borders
    echo -e "$text" | fold -s -w "$content_width" | while IFS= read -r line; do
        printf "${color}${BOX_V}${NC}%*s%-*s${color}${BOX_V}${NC}\n" "$left_pad" "" "$((content_width + right_pad))" "$line"
    done
}

# Print a complete box with title and content
print_box() {
    local title="$1"
    local content="$2"
    local width="${3:-$UI_WIDTH}"
    local color="${4:-$CYAN}"
    
    print_box_header "$title" "$width" "$color"
    print_box_content "$content" "$width" "$color"
    print_box_footer "$width" "$color"
}

# Print a title for a section
print_section_title() {
    local title="$1"
    local width="${2:-$UI_WIDTH}"
    local color="${3:-$YELLOW}"
    
    echo ""
    print_line "$width" "$UI_SECTION_CHAR" "$color"
    print_centered "${BOLD}${color}${title}${NC}" "$width"
    print_line "$width" "$UI_SECTION_CHAR" "$color"
    echo ""
}

# Print a banner for the application
print_banner() {
    clear_screen
    
    # Calculate banner width
    local banner_width="$UI_WIDTH"
    
    # Colors for the banner
    local banner_color="$CYAN"
    local version_color="$GREEN"
    
    cat << EOF

$banner_color
  _                                    _          _    ___ 
 | |    ___  ___  _ __   __ _ _ __ __| | ___    / \  |_ _|
 | |   / _ \/ _ \| '_ \ / _\` | '__/ _\` |/ _ \  / _ \  | | 
 | |__|  __/ (_) | | | | (_| | | | (_| | (_) |/ ___ \ | | 
 |_____\___|\___/|_| |_|\__,_|_|  \__,_|\___/_/   \_\___|
                                                          
 ${version_color}Universal - Multi-Environment LLM Deployment System${NC}
 
EOF
    
    print_line "$banner_width" "$UI_BORDER_CHAR" "$banner_color"
    print_centered "${banner_color}Version ${SCRIPT_VERSION} | ${SCRIPT_LICENSE} License${NC}" "$banner_width"
    print_line "$banner_width" "$UI_BORDER_CHAR" "$banner_color"
    echo ""
}

# Print a step banner for longer operations
print_step_banner() {
    local step_number="$1"
    local step_title="$2"
    local total_steps="${3:-4}"
    local width="${4:-$UI_WIDTH}"
    local step_color="${5:-$CYAN}"
    
    # Clear the screen
    clear_screen
    
    # Print the main banner in compact form
    echo -e "${step_color}Leonardo AI Universal ${NC}${BOLD}|${NC} ${GREEN}Version ${SCRIPT_VERSION}${NC}"
    print_line "$width" "$UI_HEADER_CHAR" "$step_color"
    
    # Calculate progress percentage
    local progress=$((step_number * 100 / total_steps))
    
    # Print step information
    echo -e "${BOLD}Step ${step_number} of ${total_steps}:${NC} ${step_title} ${DIM}(${progress}% complete)${NC}"
    
    # Print a visual progress bar
    local bar_width=$((width - 10))
    local filled_width=$((bar_width * step_number / total_steps))
    local empty_width=$((bar_width - filled_width))
    
    printf "${step_color}[${NC}"
    printf "%${filled_width}s" | tr ' ' '#'
    printf "%${empty_width}s" | tr ' ' '-'
    printf "${step_color}]${NC}\n"
    
    print_line "$width" "$UI_HEADER_CHAR" "$step_color"
    echo ""
}

# Print a success message
print_success() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    echo ""
    print_box_header "SUCCESS" "$width" "$GREEN"
    print_box_content "$message" "$width" "$GREEN"
    print_box_footer "$width" "$GREEN"
    echo ""
}

# Print an error message
print_error() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    echo ""
    print_box_header "ERROR" "$width" "$RED"
    print_box_content "$message" "$width" "$RED"
    print_box_footer "$width" "$RED"
    echo ""
}

# Print a hint message
print_hint() {
    local message="$1"
    local width="${2:-$UI_WIDTH}"
    
    echo -e "${BLUE}${BOLD}Hint:${NC} $message"
}

# Print a spinner for long-running operations
start_spinner() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spinstr='|/-\'
    
    # Don't show spinner in quiet mode
    if [[ "$QUIET" == "true" ]]; then
        return
    fi
    
    # Start the spinner in background
    echo -e -n "${CYAN}${message}${NC} "
    
    # If we're not in a terminal, don't use the spinner
    if ! [[ -t 1 ]]; then
        echo -n "..."
        return
    fi
    
    # Run the spinner
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    
    # Clear the spinner
    printf "   \b\b\b"
    echo -e "${GREEN}[Done]${NC}"
}

# Wait for a keypress
wait_for_key() {
    local message="${1:-Press any key to continue...}"
    
    echo -e "$message"
    read -r -n 1 -s
    echo ""
}

# Show a welcome message
show_welcome() {
    print_banner
    
    # Print welcome message
    print_box_header "Welcome" "$UI_WIDTH" "$GREEN"
    print_box_content "$WELCOME_MESSAGE" "$UI_WIDTH" "$GREEN"
    print_box_footer "$UI_WIDTH" "$GREEN"
    
    # Show UTF-8 warning if needed
    if [[ -n "$LEONARDO_UTF8_WARNING" ]]; then
        echo -e "$LEONARDO_UTF8_WARNING"
    fi
    
    echo ""
    wait_for_key
}
