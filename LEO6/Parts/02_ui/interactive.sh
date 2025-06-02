# ==============================================================================
# Interactive UI Components

# UI helpers are sourced by the main assembly script
# ==============================================================================

# Show a beautiful progress bar with gradient colors
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-}"
    local width=40
    local percent=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    # Build the progress bar with gradient colors
    local progress_bar="${COLOR_BOLD}["
    
    # Use different gradient colors based on completion percentage
    if [ $percent -lt 25 ]; then
        progress_bar+="${COLOR_GRADIENT_1}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    elif [ $percent -lt 50 ]; then
        progress_bar+="${COLOR_GRADIENT_2}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    elif [ $percent -lt 75 ]; then
        progress_bar+="${COLOR_GRADIENT_3}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    else
        progress_bar+="${COLOR_GRADIENT_4}$(printf '%*s' $completed | tr ' ' '■')${COLOR_RESET}"
    fi
    
    progress_bar+="${COLOR_DIM}$(printf '%*s' $remaining | tr ' ' '□')${COLOR_RESET}"
    progress_bar+="${COLOR_BOLD}]${COLOR_RESET} ${COLOR_BOLD}${COLOR_CYAN}$percent%${COLOR_RESET}"
    
    # Add message if provided
    if [ -n "$message" ]; then
        progress_bar+=" $message"
    fi
    
    # Print the progress bar
    printf "\r%-80s" "$progress_bar"
    
    # If complete, print a newline
    if [ $current -ge $total ]; then
        echo
    fi
}

# Show an animated spinner with enhanced visuals
show_spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local colors=("${COLOR_GRADIENT_1}" "${COLOR_GRADIENT_2}" "${COLOR_GRADIENT_3}" "${COLOR_GRADIENT_4}")
    local color_index=0
    
    # Hide the cursor if tput is available
    if [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" civis 2>/dev/null || true
    fi
    
    # Start the spinner
    while ps -p $pid >/dev/null 2>&1; do
        for frame in "${frames[@]}"; do
            # Rotate through colors for a gradient effect
            local current_color="${colors[$color_index]}"
            color_index=$(( (color_index + 1) % ${#colors[@]} ))
            
            # Display the spinner with current color and message
            printf "\r${current_color}%s${COLOR_RESET} %s" "$frame" "$message"
            sleep $delay
        done
    done
    
    # Show the cursor again if tput is available
    if [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" cnorm 2>/dev/null || true
    fi
    
    # Clear the spinner line
    printf "\r%-80s\r" " "
}

# Run a command with a spinner
run_with_spinner() {
    local cmd="$1"
    local message="${2:-Running command...}"
    
    # Start the command in the background
    eval "$cmd" &
    local cmd_pid=$!
    
    # Show spinner while command runs
    show_spinner "$cmd_pid" "$message"
    
    # Wait for command to finish and get its exit code
    wait "$cmd_pid"
    local exit_code=$?
    
    echo ""
    return "$exit_code"
}

# Ask user a yes/no/quit question with styling
ask_yes_no_quit() {
    local message="$1"
    local result_var_name="$2"
    local default_choice="${3:-no}"
    local show_quit="${4:-false}"
    local choice
    
    # Format prompt based on default
    local prompt_options
    if [[ "$default_choice" == "yes" ]]; then
        prompt_options="[${COLOR_GREEN}Y${COLOR_RESET}/n${show_quit:+/q}]"
    elif [[ "$default_choice" == "no" ]]; then
        prompt_options="[y/${COLOR_RED}N${COLOR_RESET}${show_quit:+/q}]"
    else
        prompt_options="[y/n${show_quit:+/${COLOR_MAGENTA}Q${COLOR_RESET}}]"
    fi
    
    while true; do
        echo -ne "${COLOR_YELLOW}$message $prompt_options ${COLOR_RESET}"
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        
        # Use default if empty input
        if [ -z "$choice" ]; then choice="$default_choice"; fi
        
        case "$choice" in
            y|yes) 
                eval "$result_var_name=\"yes\""
                return 0 ;;
            n|no) 
                eval "$result_var_name=\"no\""
                return 0 ;;
            q|quit)
                if [ "$show_quit" = "true" ]; then
                    eval "$result_var_name=\"quit\""
                    return 0
                else
                    echo -e "${COLOR_YELLOW}Please answer with 'y' or 'n'.${COLOR_RESET}"
                fi ;;
            *) echo -e "${COLOR_YELLOW}Please answer with 'y' or 'n'.${COLOR_RESET}" ;;
        esac
    done
}

# Get user input directly from /dev/tty
get_user_input() {
    local prompt_message="$1"
    local result_var_name="$2"
    local input_value

    echo -n "$prompt_message" >&2 # Print prompt to stderr
    read -r input_value          # Read from stdin
    
    # Trim leading/trailing whitespace (optional, but good practice)
    input_value=$(echo "$input_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    eval "$result_var_name=\"$input_value\""
}

# Get confirmation from user with improved styling and llama progression
confirm() {
    local message="$1"
    local default="${2:-n}"
    local severity="${3:-normal}"
    local choice
    local llama_emoji
    
    # Force mode - skip confirmation
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    # Use the appropriate llama based on severity level as per memory
    case "$severity" in
        normal)
            # Friendly llama for normal operations
            llama_emoji="${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET}"
            ;;
        caution)
            # Mischievous winking llama for first level caution
            llama_emoji="${COLOR_YELLOW}(>‿-)🦙${COLOR_RESET}"
            ;;
        warning)
            # Intense/crazy-eyed llama for serious warnings
            llama_emoji="${COLOR_RED}(ಠ‿ಠ)🦙${COLOR_RESET}"
            ;;
        *)
            llama_emoji="${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET}"
            ;;
    esac
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -ne "$llama_emoji $message [${COLOR_GREEN}Y${COLOR_RESET}/n] " >&2
            read -r choice
            choice=${choice:-y}
        else
            echo -ne "$llama_emoji $message [y/${COLOR_RED}N${COLOR_RESET}] " >&2
            read -r choice
            choice=${choice:-n}
        fi
        
        case "${choice,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo -e "${COLOR_YELLOW}Please answer with 'yes' or 'no'.${COLOR_RESET}" >&2 ;;
        esac
    done
}

# Show a menu of options with enhanced styling
show_menu() {
    local dialog_title="$1"
    local menu_text="$2"
    shift 2
    local menu_options=("$@")
    local choice
    local result_var_name="_menu_choice"
    
    echo -e "\n${COLOR_BOLD}${COLOR_CYAN}╭─── $dialog_title ${COLOR_DIM}─────────────────────────────────────────────╮${COLOR_RESET}"
    if [ -n "$menu_text" ]; then
        echo -e "${COLOR_CYAN}│ ${COLOR_RESET}${menu_text}${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│ ${COLOR_DIM}....................................................................${COLOR_RESET}"
    fi
    
    local option_num=1
    for option in "${menu_options[@]}"; do
        printf "${COLOR_CYAN}│  ${COLOR_BOLD}%s)${COLOR_RESET} %-60s ${COLOR_CYAN}│${COLOR_RESET}\n" "$option_num" "$option"
        option_num=$((option_num + 1))
    done
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╰────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    
    # Get user choice
    while true; do
        print_prompt "Enter your choice (1-$((option_num-1))): "
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((option_num-1)) ]; then
            return $((choice - 1))
        else
            print_warning "Invalid input. Please try again."
        fi
    done
}

# Show a help screen with useful information
show_help_screen() {
    clear_screen_and_show_art
    
    print_section_header "Leonardo AI USB Maker - Help" $UI_WIDTH
    
    # Print the help content in a nicely formatted box
    echo -e "${COLOR_CYAN}╭$(repeat_char "─" $((UI_WIDTH-2)))╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_BOLD}GETTING STARTED:${COLOR_RESET}                                           ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• To create a new Leonardo AI USB, select option 1 from menu.   ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• You'll need an empty USB drive (min. 8GB recommended).       ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• All data on the selected USB will be erased during setup.    ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                 │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_BOLD}ADDING AI MODELS:${COLOR_RESET}                                         ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• Select option 2 to add AI models to an existing Leonardo USB. ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• The USB must be formatted with the Leonardo file structure.  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                 │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_BOLD}USB HEALTH:${COLOR_RESET}                                                ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• Option 3 scans your USB for errors and performance issues.  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${COLOR_RESET}• Regular health checks ensure optimal AI model performance.   ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰$(repeat_char "─" $((UI_WIDTH-2)))╯${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}(>‿-)🦙${COLOR_RESET} ${COLOR_DIM}Pro tip: Using exFAT filesystem provides the best cross-platform compatibility.${COLOR_RESET}"
    
    echo -e "\nPress any key to return to the main menu..."
    read -n 1 -s
}

# Show main menu with enhanced visual design
show_main_menu() {
    show_header
    
    # Print fancy gradient divider
    print_gradient_divider
    
    # Menu title with visual styling
    echo -e "\n${COLOR_BOLD}${COLOR_GRADIENT_2}⚡ Leonardo AI USB Maker - Main Menu ⚡${COLOR_RESET}\n"
    
    # Box containing the menu options with icons and visual styling
    local menu_box_width=$((UI_WIDTH - 2))
    echo -e "${COLOR_CYAN}╭$(repeat_char "─" $menu_box_width)╮${COLOR_RESET}"

    # Data-driven menu items: (number, icon, label, description, color)
    local menu_items=(
        "1|💾|Create New USB|Format and set up a new USB drive|${COLOR_BOLD}${COLOR_GREEN}"
        "2|🧠|Add AI Model to USB|Install AI models to existing USB|${COLOR_BOLD}${COLOR_GREEN}"
        "3|🔍|Verify USB Health|Check USB drive for issues|${COLOR_BOLD}${COLOR_GREEN}"
        "4|📜|Download History|View your download history|${COLOR_BOLD}${COLOR_GREEN}"
        "5|ℹ️ |About|About this script and usage guide|${COLOR_BOLD}${COLOR_GREEN}"
        "6|🚪|Exit|Exit the program|${COLOR_BOLD}${COLOR_RED}"
    )

    # Calculate max left segment width (number, icon, label)
    local max_left_len=0
    local left_segments=()
    for item in "${menu_items[@]}"; do
        IFS='|' read -r num icon label desc color <<< "$item"
        local left="  ${color}${num})${COLOR_RESET} ${icon} ${color}${label}${COLOR_RESET}"
        left_segments+=("$left")
        local plain_left=$(strip_ansi "$left")
        local len=${#plain_left}
        if [ $len -gt $max_left_len ]; then max_left_len=$len; fi
    done

    # Helper to print padded menu lines
    print_menu_line() {
        local left="$1"
        local desc="$2"
        local width="$((menu_box_width+2))"
        local content_width=$((width - 4))
        local plain_left=$(strip_ansi "$left")
        local pad_len=$((max_left_len - ${#plain_left}))
        if [ $pad_len -lt 0 ]; then pad_len=0; fi
        local left_padded="$left$(printf '%*s' "$pad_len" '')"
        # Add a consistent gap between left segment and dash
        local content="$left_padded  -  $desc"
        local visible_len=$(strip_ansi "$content" | awk '{print length}')
        local right_pad=$((content_width - visible_len))
        if [ $right_pad -lt 0 ]; then right_pad=0; fi
        local padding_spaces=$(printf '%*s' "$right_pad" '')
        echo -e "${COLOR_CYAN}│ ${COLOR_RESET}${content}${padding_spaces}${COLOR_CYAN} │${COLOR_RESET}"
    }

    # Render menu
    for i in "${!menu_items[@]}"; do
        IFS='|' read -r num icon label desc color <<< "${menu_items[$i]}"
        print_menu_line "${left_segments[$i]}" "$desc"
    done


    echo -e "${COLOR_CYAN}╰$(repeat_char "─" $menu_box_width)╯${COLOR_RESET}"
    
    # Friendly llama mascot offering help
    echo -e "\n${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET} ${COLOR_DIM}Need help? Type 'help' or '?' for more information.${COLOR_RESET}\n"
    
    # Get user choice
    local choice
    while true; do
        print_prompt "Enter your selection (1-6): "
        read choice
        
        # Handle special inputs
        if [[ "$choice" == "help" ]] || [[ "$choice" == "?" ]]; then
            show_help_screen
            show_main_menu
            return $?
        fi
        
        # Process regular menu choices
        case "$choice" in
            1) return 0 ;; # Create New USB Drive
            2) return 1 ;; # Add AI Model to USB
            3) return 2 ;; # Verify USB Health
            4) return 3 ;; # View Download History
            5) return 4 ;; # About
            6) return 5 ;; # Exit
            *) print_warning "Invalid selection. Please enter a number between 1 and 6." ;;
        esac
    done
}
# Show about screen with enhanced visual styling
show_about() {
    clear_screen_and_show_art
    
    # Print fancy gradient divider
    print_gradient_divider
    
    # About title with visual styling
    print_section_header "About Leonardo AI USB Maker" $UI_WIDTH
    
    # Show the about content in a stylized box
    echo -e "${COLOR_GRADIENT_1}╭$(repeat_char "─" $((UI_WIDTH-2)))╮${COLOR_RESET}"
    
    # About content with beautiful formatting
    echo -e "${COLOR_GRADIENT_1}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_1}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_1}│${COLOR_RESET}  ${COLOR_BOLD}Leonardo AI USB Maker${COLOR_RESET} - Forge Your Portable AI Future!      ${COLOR_GRADIENT_1}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_1}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_1}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_2}│${COLOR_RESET}  Version: ${COLOR_BOLD}$SCRIPT_VERSION${COLOR_RESET}                                     ${COLOR_GRADIENT_2}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_2}│${COLOR_RESET}  Build Date: ${COLOR_BOLD}$(date +"%B %Y")${COLOR_RESET}                                ${COLOR_GRADIENT_2}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_2}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_2}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}  A powerful tool for creating bootable USB drives with AI models  ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}  and tools. Easily setup a portable AI environment that works     ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}  across multiple operating systems.                              ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_3}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_3}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}  Supported Models: ${COLOR_BOLD}Leonardo GPT, NexusAI, AstroLLM${COLOR_RESET}             ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}  Supported Filesystems: ${COLOR_BOLD}exFAT, NTFS, EXT4${COLOR_RESET}                    ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}  ${COLOR_BOLD}© $(date +%Y) Leonardo AI Team${COLOR_RESET}                                ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}│${COLOR_RESET}                                                                 ${COLOR_GRADIENT_4}│${COLOR_RESET}"
    echo -e "${COLOR_GRADIENT_4}╰$(repeat_char "─" $((UI_WIDTH-2)))╯${COLOR_RESET}"
    
    # Show friendly llama mascot
    echo -e "\n${COLOR_YELLOW}(•ᴗ•)🦙${COLOR_RESET} ${COLOR_DIM}Thank you for using Leonardo AI USB Maker!${COLOR_RESET}"
    
    echo -e "\n${COLOR_BOLD}${COLOR_CYAN}Press any key to return to the main menu...${COLOR_RESET}"
    read -n 1 -s
}
