#!/bin/bash

# ============================================
# LEONARDO AI USB MAKER - SIMPLE UI COMPONENTS
# ============================================

# Use this file when terminal compatibility is an issue

# Prevent multiple sourcing
if [ -n "${LEONARDO_SIMPLE_UI_LOADED}" ]; then
    return 0
fi

export LEONARDO_SIMPLE_UI_LOADED=1

# =====================
# LLAMA CHARACTER SYSTEM - ASCII Version
# =====================
LLAMA_NORMAL="(*_*)<llama>"
LLAMA_EXCITED="(^o^)<llama>"
LLAMA_CAUTION="(>_>)<llama>"
LLAMA_WARNING="(o_O)<llama>"
LLAMA_ERROR="(x_x)<llama>"
LLAMA_SUCCESS="(^_^)<llama>"

# Display the main header
show_header() {
    clear
    echo "========================================"
    echo "   LEONARDO AI USB MAKER - VERSION 1.2.2"
    echo "========================================"
    echo ""
}

# Display a message with a llama character
llama_speak() {
  local mood=$1
  local message=$2
  
  case $mood in
    normal)   echo "${LLAMA_NORMAL} $message" ;;
    excited)  echo "${LLAMA_EXCITED} $message" ;;
    caution)  echo "${LLAMA_CAUTION} $message" ;;
    warning)  echo "${LLAMA_WARNING} $message" ;;
    error)    echo "${LLAMA_ERROR} $message" ;;
    success)  echo "${LLAMA_SUCCESS} $message" ;;
    *)        echo "${LLAMA_NORMAL} $message" ;;
  esac
}

# Draw a box with optional title
draw_box() {
  local width=${1:-80}
  local style=${2:-single}
  local title="$3"
  
  # Use simple ASCII characters for better compatibility
  local horizontal='-'
  local vertical='|'
  local corner_tl='+'
  local corner_tr='+'
  
  # Top border
  echo -n "$corner_tl"
  for ((i=0; i<width-2; i++)); do echo -n "$horizontal"; done
  echo "$corner_tr"
  
  # Title line (if provided)
  if [[ -n "$title" ]]; then
    local title_length=${#title}
    local padding_left=$(( (width - 2 - title_length) / 2 ))
    local padding_right=$(( width - 2 - title_length - padding_left ))
    
    echo -n "$vertical"
    for ((i=0; i<padding_left; i++)); do echo -n " "; done
    echo -n "$title"
    for ((i=0; i<padding_right; i++)); do echo -n " "; done
    echo "$vertical"
  fi
  
  # Bottom border
  echo -n "+"
  for ((i=0; i<width-2; i++)); do echo -n "$horizontal"; done
  echo "+"
}

# Display a section with title
show_section() {
    local title="$1"
    local width=${2:-60}
    
    echo ""
    echo "$title"
    echo "$(printf '%*s' "$width" | tr ' ' '-')"
}

# Display a table with headers and rows
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
        echo ""
        echo "$title"
        echo ""
    fi
    
    # Print top border
    echo -n "+"
    for ((i=0; i<num_columns; i++)); do
        for ((j=0; j<col_widths[i]; j++)); do echo -n "-"; done
        echo -n "+"
    done
    echo ""
    
    # Print headers
    echo -n "|"
    for ((i=0; i<num_columns; i++)); do
        printf " %-*s |" "${col_widths[i]}" "${header_array[i]}"
    done
    echo ""
    
    # Print header separator
    echo -n "+"
    for ((i=0; i<num_columns; i++)); do
        for ((j=0; j<col_widths[i]; j++)); do echo -n "-"; done
        echo -n "+"
    done
    echo ""
    
    # Print rows
    for row in "${rows[@]}"; do
        IFS=',' read -r -a row_array <<< "$row"
        echo -n "|"
        for ((i=0; i<num_columns; i++)); do
            printf " %-*s |" "${col_widths[i]}" "${row_array[i]}"
        done
        echo ""
    done
    
    # Print bottom border
    echo -n "+"
    for ((i=0; i<num_columns; i++)); do
        for ((j=0; j<col_widths[i]; j++)); do echo -n "-"; done
        echo -n "+"
    done
    echo ""
}

# Show a message
show_message() {
    local message="$1"
    echo "$message"
}

# Show an error message
show_error() {
    local message="$1"
    echo "ERROR: $message"
}

# Show a warning message
show_warning() {
    local message="$1"
    echo "WARNING: $message"
}

# Show a success message
show_success() {
    local message="$1"
    echo "SUCCESS: $message"
}

# Display an information box with multiple lines
show_info_box() {
    local title="$1"
    shift
    local lines=("$@")
    local max_width=0
    
    # Find the longest line for proper sizing
    for line in "${lines[@]}"; do
        # Strip any potential color codes for proper length calculation
        local stripped_line=$(echo "$line" | sed 's/\\033\[[0-9;]*m//g')
        if [ ${#stripped_line} -gt $max_width ]; then
            max_width=${#stripped_line}
        fi
    done
    
    # Add padding
    max_width=$((max_width + 4))
    
    # Top border
    echo "+$(printf '%*s' "$max_width" | tr ' ' '-')+"
    
    # Title (if provided)
    if [ -n "$title" ]; then
        echo "| $title $(printf '%*s' "$((max_width - ${#title} - 2))" "") |"
        echo "+$(printf '%*s' "$max_width" | tr ' ' '-')+"
    fi
    
    # Content lines
    for line in "${lines[@]}"; do
        # Strip ANSI codes for display in simple UI
        local clean_line=$(echo "$line" | sed 's/\\033\[[0-9;]*m//g')
        echo "| $clean_line $(printf '%*s' "$((max_width - ${#clean_line} - 1))" "") |"
    done
    
    # Bottom border
    echo "+$(printf '%*s' "$max_width" | tr ' ' '-')+"
}

# Export all functions for use in subshells
export_functions() {
    local funcs=$(declare -F | cut -d' ' -f3)
    for func in $funcs; do
        export -f "$func" 2>/dev/null || true
    done
}

# Export all functions
export_functions
