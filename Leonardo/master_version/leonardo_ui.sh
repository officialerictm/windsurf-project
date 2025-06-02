#!/bin/bash

# ============================================
# LEONARDO AI USB MAKER - UI COMPONENTS
# ============================================

#!/bin/bash

# ============================================
# LEONARDO AI USB MAKER - UI COMPONENTS
# ============================================

# Prevent multiple sourcing
if [ -n "${LEONARDO_UI_LOADED}" ]; then
    return 0
fi

export LEONARDO_UI_LOADED=1

# Debug function to list all available functions
debug_functions() {
    echo "Debug: Available functions:" >&2
    declare -F | cut -d' ' -f3 | sort >&2
}

# Export all functions for use in subshells
export_functions() {
    local funcs=$(declare -F | cut -d' ' -f3)
    for func in $funcs; do
        export -f "$func" 2>/dev/null || true
    done
}

# =================
# COLOR DEFINITIONS
# =================
# Only define colors if they're not already defined
if [ -z "${C_RESET+x}" ]; then
    # Text colors - using $'...' syntax for proper escape sequence interpretation
    C_RESET=$'\e[0m'
    C_BLACK=$'\e[0;30m'
    C_RED=$'\e[0;31m'
    C_GREEN=$'\e[0;32m'
    C_YELLOW=$'\e[0;33m'
    C_BLUE=$'\e[0;34m'
    C_PURPLE=$'\e[0;35m'
    C_CYAN=$'\e[0;36m'
    C_WHITE=$'\e[0;37m'
    
    # Bold text colors
    C_BLACK_BOLD=$'\e[1;30m'
    C_RED_BOLD=$'\e[1;31m'
    C_GREEN_BOLD=$'\e[1;32m'
    C_YELLOW_BOLD=$'\e[1;33m'
    C_BLUE_BOLD=$'\e[1;34m'
    C_PURPLE_BOLD=$'\e[1;35m'
    C_CYAN_BOLD=$'\e[1;36m'
    C_WHITE_BOLD=$'\e[1;37m'
    
    # Background colors
    C_BG_BLACK=$'\e[40m'
    C_BG_RED=$'\e[41m'
    C_BG_GREEN=$'\e[42m'
    C_BG_YELLOW=$'\e[43m'
    C_BG_BLUE=$'\e[44m'
    C_BG_PURPLE=$'\e[45m'
    C_BG_CYAN=$'\e[46m'
    C_BG_WHITE=$'\e[47m'
    
    # Check if we should disable colors
    if [ -t 1 ]; then
        ncolors=$(tput colors 2>/dev/null || echo 0)
        if [ -n "$ncolors" ] && [ "$ncolors" -lt 8 ]; then
            # Terminal doesn't support enough colors, disable them
            for c in C_RESET C_BLACK C_RED C_GREEN C_YELLOW C_BLUE C_PURPLE C_CYAN C_WHITE \
                    C_BLACK_BOLD C_RED_BOLD C_GREEN_BOLD C_YELLOW_BOLD C_BLUE_BOLD C_PURPLE_BOLD C_CYAN_BOLD C_WHITE_BOLD \
                    C_BG_BLACK C_BG_RED C_BG_GREEN C_BG_YELLOW C_BG_BLUE C_BG_PURPLE C_BG_CYAN C_BG_WHITE; do
                export "$c="
            done
        fi
    else
        # Not a terminal, disable colors
        for c in C_RESET C_BLACK C_RED C_GREEN C_YELLOW C_BLUE C_PURPLE C_CYAN C_WHITE \
                C_BLACK_BOLD C_RED_BOLD C_GREEN_BOLD C_YELLOW_BOLD C_BLUE_BOLD C_PURPLE_BOLD C_CYAN_BOLD C_WHITE_BOLD \
                C_BG_BLACK C_BG_RED C_BG_GREEN C_BG_YELLOW C_BG_BLUE C_BG_PURPLE C_BG_CYAN C_BG_WHITE; do
            export "$c="
        done
    fi
fi

# =====================
# CORE UI FUNCTIONS
# =====================

# Display the main header
show_header() {
    clear
    printf "%s========================================%s\n" "${C_CYAN_BOLD}" "${C_RESET}"
    printf "%s   LEONARDO AI USB MAKER - VERSION 1.2.2%s\n" "${C_CYAN_BOLD}" "${C_RESET}"
    printf "%s========================================%s\n\n" "${C_CYAN_BOLD}" "${C_RESET}"
}

# Display a message with a llama character
llama_speak() {
  local mood=$1
  local message=$2
  local face=""
  local color=""
  local text_color=""
  
  # Set llama face and colors based on mood
  case $mood in
    normal)   face="${LLAMA_NORMAL}"; color="${C_CYAN}"; text_color="${C_WHITE_BOLD}" ;;
    excited)  face="${LLAMA_EXCITED}"; color="${C_GREEN}"; text_color="${C_GREEN_BOLD}" ;;
    caution)  face="${LLAMA_CAUTION}"; color="${C_YELLOW}"; text_color="${C_YELLOW_BOLD}" ;;
    warning)  face="${LLAMA_WARNING}"; color="${C_RED}"; text_color="${C_RED_BOLD}" ;;
    error)    face="${LLAMA_ERROR}"; color="${C_RED}"; text_color="${C_RED_BOLD}" ;;
    success)  face="${LLAMA_SUCCESS}"; color="${C_GREEN}"; text_color="${C_GREEN_BOLD}" ;;
    *)        face="${LLAMA_NORMAL}"; color="${C_CYAN}"; text_color="${C_RESET}" ;;
  esac
  
  # Print llama face with color
  printf "%s%s%s " "${color}" "${face}" "${C_RESET}"
  
  # Print message - if it already has color codes, they'll be preserved
  # Otherwise, apply the default text color
  if [[ "$message" == *"\033"* ]] || [[ "$message" == *"\e"* ]]; then
    # Message already has color codes, print as is
    printf "%s%s\n" "$message" "${C_RESET}"
  else
    # Apply default text color
    printf "%s%s%s\n" "${text_color}" "$message" "${C_RESET}"
  fi
}

# =====================
# LLAMA CHARACTER SYSTEM
# =====================
LLAMA_NORMAL="(•ᴗ•)🦙"
LLAMA_EXCITED="(^ᴗ^)🦙"
LLAMA_CAUTION="(>‿-)🦙"
LLAMA_WARNING="(ಠ‿ಠ)🦙"
LLAMA_ERROR="(°□°)🦙"
LLAMA_SUCCESS="(⌐■‿■)🦙"

# ==================
# UI COMPONENTS
# ==================

# Display an information box with multiple lines
show_info_box() {
    local title="$1"
    shift
    local lines=("$@")
    local max_width=0
    
    # Find the longest line for proper sizing
    for line in "${lines[@]}"; do
        # Strip color codes for proper length calculation
        local stripped_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
        if [ ${#stripped_line} -gt $max_width ]; then
            max_width=${#stripped_line}
        fi
    done
    
    # Add padding
    max_width=$((max_width + 4))
    
    # Top border
    printf "%s" "${C_BLUE_BOLD}"
    printf "+%s+\n" "$(printf '%*s' "$max_width" | tr ' ' '-')"
    printf "%s" "${C_RESET}"
    
    # Title (if provided)
    if [ -n "$title" ]; then
        printf "%s|%s" "${C_BLUE_BOLD}" "${C_RESET}"
        printf " %s " "$title"
        printf "%*s" "$((max_width - ${#title} - 2))" ""
        printf "%s|%s\n" "${C_BLUE_BOLD}" "${C_RESET}"
        
        # Separator after title
        printf "%s+%s+%s\n" "${C_BLUE_BOLD}" "$(printf '%*s' "$max_width" | tr ' ' '-')" "${C_RESET}"
    fi
    
    # Content lines
    for line in "${lines[@]}"; do
        printf "%s|%s " "${C_BLUE_BOLD}" "${C_RESET}"
        printf "%s" "$line"
        
        # Calculate padding (accounting for color codes)
        local stripped_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local padding=$((max_width - ${#stripped_line} - 1))
        printf "%*s" "$padding" ""
        
        printf "%s|%s\n" "${C_BLUE_BOLD}" "${C_RESET}"
    done
    
    # Bottom border
    printf "%s" "${C_BLUE_BOLD}"
    printf "+%s+\n" "$(printf '%*s' "$max_width" | tr ' ' '-')"
    printf "%s" "${C_RESET}"
}

draw_box() {
  local width=${1:-80}
  local style=${2:-single} # style is not used currently but kept for potential future use
  local title="$3"
  
  # Use simple ASCII characters for better compatibility
  local horizontal='-'
  local vertical='|'
  local corner_tl='+'
  local corner_tr='+'
  local corner_bl='+'
  local corner_br='+'
  
  # Top border
  printf "%s%s" "${C_BLUE_BOLD}" "${corner_tl}"
  printf "%*s" "$((width - 2))" "" | tr ' ' "${horizontal}"
  printf "%s%s\n" "${corner_tr}" "${C_RESET}"
  
  # Title line (if provided)
  if [[ -n "$title" ]]; then
    local title_length=${#title}
    # Ensure padding calculation doesn't result in negative numbers for printf
    local padding_left=$(( (width - 2 - title_length) / 2 ))
    local padding_right=$(( width - 2 - title_length - padding_left ))
    
    if [ $padding_left -lt 0 ]; then padding_left=0; fi
    if [ $padding_right -lt 0 ]; then padding_right=0; fi

    printf "%s%s%s" "${C_BLUE_BOLD}" "${vertical}" "${C_RESET}"
    printf "%*s" "$padding_left" ""
    printf "%s%s%s" "${C_WHITE_BOLD}" "${title}" "${C_RESET}"
    printf "%*s" "$padding_right" ""
    printf "%s%s%s\n" "${C_BLUE_BOLD}" "${vertical}" "${C_RESET}"
  else
    # Empty line if no title
    printf "%s%s%s" "${C_BLUE_BOLD}" "${vertical}" "${C_RESET}"
    printf "%*s" "$((width - 2))" ""
    printf "%s%s%s\n" "${C_BLUE_BOLD}" "${vertical}" "${C_RESET}"
  fi
  
  # Bottom border
  printf "%s%s" "${C_BLUE_BOLD}" "${corner_bl}"
  printf "%*s" "$((width - 2))" "" | tr ' ' "${horizontal}"
  printf "%s%s\n" "${corner_br}" "${C_RESET}"
}

draw_box_bottom() {
  local width=${1:-60}
  local style=${2:-single}
  
  # Use simple ASCII characters for better compatibility
  local horizontal='-'
  local corner_bl='+'
  local corner_br='+'
  
  # Bottom border
  printf "%s%s" "${C_BLUE_BOLD}" "${corner_bl}"
  printf "%*s" "$((width - 2))" "" | tr ' ' "${horizontal}"
  printf "%s%s\n" "${corner_br}" "${C_RESET}"
}

show_header() {
  clear
  draw_box 80 double
  draw_box 80 double "           🦙 LEONARDO AI USB MAKER v${SCRIPT_VERSION} 🦙"
  echo
}

show_main_menu() {
  show_header
  llama_speak "normal" "What would you like to do today?"
  echo
  
  local menu_items=(
    "💿 Create New AI USB Drive"
    "🔄 Update Existing AI USB Drive"
    "📋 List Available AI Models"
    "🖥️  Show System Information"
    "ℹ️  About This Tool"
    "👋 Quit"
  )
  
  for i in "${!menu_items[@]}"; do
    local num=$((i+1))
    if [ $num -eq ${#menu_items[@]} ]; then
      echo -e "  [${C_YELLOW}q${C_RESET}] ${menu_items[$i]}"
    else
      echo -e "  [${C_YELLOW}${num}${C_RESET}] ${menu_items[$i]}"
    fi
  done
  
  echo -e "\n${C_WHITE_BOLD}Enter your choice (1-${#menu_items[@]}, q to quit): ${C_RESET}"
}

# ==================
# INTERACTIVE ELEMENTS
# ==================

show_spinner() {
  local pid=$1
  local message=$2
  local delay=0.1
  local spinstr='|/\-'
  
  # Hide cursor
  tput civis
  
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf "\r[%c] %s" "$spinstr" "$message"
    local spinstr=$temp${spinstr%$temp}
    sleep $delay
  done
  
  # Clear line and show cursor
  printf "\r\033[K"
  tput cnorm
}

progress_bar() {
  local current=$1
  local total=$2
  local width=${3:-50}
  local title=${4:-"Progress"}
  
  local percent=$((current*100/total))
  local completed=$((width*current/total))
  local remaining=$((width-completed))
  
  # Draw the progress bar
  printf "${C_CYAN_BOLD}%s${C_RESET} [" "$title"
  printf "${C_GREEN}%${completed}s" | tr ' ' '■'
  printf "${C_BLACK}%${remaining}s" | tr ' ' '·'
  printf "] ${C_YELLOW}%3d%%${C_RESET}\r" "$percent"
}

# ==================
# SPECIAL SCREENS
# ==================

show_splash() {
  clear
  echo -e "${C_CYAN_BOLD}"
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  echo "┃                                                                          ┃"
  echo "┃   ██╗     ███████╗ ██████╗ ███╗   ██╗ █████╗ ██████╗ ██████╗  ██████╗   ┃"
  echo "┃   ██║     ██╔════╝██╔═══██╗████╗  ██║██╔══██╗██╔══██╗██╔══██╗██╔═══██╗  ┃"
  echo "┃   ██║     █████╗  ██║   ██║██╔██╗ ██║███████║██████╔╝██║  ██║██║   ██║  ┃"
  echo "┃   ██║     ██╔══╝  ██║   ██║██║╚██╗██║██╔══██║██╔══██╗██║  ██║██║   ██║  ┃"
  echo "┃   ███████╗███████╗╚██████╔╝██║ ╚████║██║  ██║██║  ██║██████╔╝╚██████╔╝  ┃"
  echo "┃   ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝   ┃"
  echo "┃                                                                          ┃"
  echo "┃                    🦙 AI USB MAKER v${SCRIPT_VERSION} 🦙                             ┃"
  echo "┃                                                                          ┃"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo -e "${C_RESET}"
  
  llama_speak "normal" "Initializing systems..."
  sleep 1
}

# ==================
# UI UTILITIES
# ==================

# Display a section header
show_section() {
    local title="$1"
    local title_length=${#title}
    local width=$((title_length + 8))
    
    # Use simple ASCII characters for better compatibility
    local horizontal='='
    local vertical='|'
    local corner_tl='+'
    local corner_tr='+'
    local corner_bl='+'
    local corner_br='+'
    
    echo -e "\n${C_BLUE_BOLD}${corner_tl}"$(printf '=%.0s' $(seq 1 $width))"${corner_tr}${C_RESET}"
    echo -e "${C_BLUE_BOLD}${vertical}    ${C_WHITE_BOLD}${title}${C_BLUE_BOLD}    ${vertical}${C_RESET}"
    echo -e "${C_BLUE_BOLD}${corner_bl}"$(printf '=%.0s' $(seq 1 $width))"${corner_br}${C_RESET}\n"
}

# Display a table with headers and rows using simple ASCII characters
show_table() {
    local title="$1"
    local headers="$2"
    shift 2
    local rows=("$@")
    
    # Define simple ASCII characters for borders
    local h_line='-'
    local v_line='|'
    local cross='+'
    
    # Parse headers
    IFS=',' read -r -a header_array <<< "$headers"
    local num_columns=${#header_array[@]}
    
    # Calculate column widths
    local -a col_widths
    for ((i=0; i<num_columns; i++)); do
        col_widths[i]=${#header_array[i]}
    done
    
    # Process each row to find max column widths
    for row in "${rows[@]}"; do
        IFS=',' read -r -a row_array <<< "$row"
        for ((i=0; i<num_columns; i++)); do
            if [ ${#row_array[i]} -gt ${col_widths[i]} ]; then
                col_widths[i]=${#row_array[i]}
            fi
        done
    done
    
    # Add padding
    local total_width=0
    for ((i=0; i<num_columns; i++)); do
        col_widths[i]=$((col_widths[i] + 2))
        total_width=$((total_width + col_widths[i] + 3))
    done
    
    # Print title if provided
    if [ -n "$title" ]; then
        printf "\n%s%*s%s\n\n" "${C_CYAN_BOLD}" $(( (total_width + ${#title}) / 2 )) "$title" "${C_RESET}"
    fi
    
    # Print top border
    printf "%s%s%s" "${C_BLUE_BOLD}" "$cross" "${C_RESET}"
    for ((i=0; i<num_columns; i++)); do
        printf "%s" "$(printf "%${col_widths[i]}s" | tr ' ' "${h_line}")"
        printf "%s%s%s" "${C_BLUE_BOLD}" "$cross" "${C_RESET}"
    done
    printf "\n"
    
    # Print headers
    printf "%s%s%s " "${C_BLUE_BOLD}" "$v_line" "${C_RESET}"
    for ((i=0; i<num_columns; i++)); do
        printf "%s%-*s%s" "${C_WHITE_BOLD}" "${col_widths[i]}" " ${header_array[i]}" "${C_RESET}"
        printf " %s%s%s " "${C_BLUE_BOLD}" "$v_line" "${C_RESET}"
    done
    printf "\n"
    
    # Print header separator
    printf "%s%s%s" "${C_BLUE_BOLD}" "$cross" "${C_RESET}"
    for ((i=0; i<num_columns; i++)); do
        printf "%s" "$(printf "%${col_widths[i]}s" | tr ' ' "${h_line}")"
        printf "%s%s%s" "${C_BLUE_BOLD}" "$cross" "${C_RESET}"
    done
    printf "\n"
    
    # Print rows
    for row in "${rows[@]}"; do
        IFS=',' read -r -a row_array <<< "$row"
        printf "%s%s%s " "${C_BLUE_BOLD}" "$v_line" "${C_RESET}"
        for ((i=0; i<num_columns; i++)); do
            printf "%-${col_widths[i]}s" " ${row_array[i]}"
            printf " %s%s%s " "${C_BLUE_BOLD}" "$v_line" "${C_RESET}"
        done
        printf "\n"
    done
    
    # Print bottom border
    printf "%s%s%s" "${C_BLUE_BOLD}" "$cross" "${C_RESET}"
    for ((i=0; i<num_columns; i++)); do
        printf "%s" "$(printf "%${col_widths[i]}s" | tr ' ' "${h_line}")"
        printf "%s%s%s" "${C_BLUE_BOLD}" "$cross" "${C_RESET}"
    done
    printf "\n"
}

# ==================
# MODEL SELECTION
# ==================


# ==================
# DEVICE SELECTION
# ==================


# ==================
# HELPER FUNCTIONS
# ==================

typewriter_print() {
  local text="$1"
  local speed=${2:-0.03}
  
  for (( i=0; i<${#text}; i++ )); do
    echo -n "${text:$i:1}"
    sleep $speed
  done
  echo
}

# Load this file only when sourced, not when executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Show demo if run directly
  show_splash
  sleep 1
  show_main_menu
fi
