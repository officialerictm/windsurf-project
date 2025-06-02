# ==============================================================================
# Terminal Color Initialization and Management
# ==============================================================================
# Description: Handle color output with graceful fallbacks
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh
# ==============================================================================

# Initialize color variables
init_colors() {
    # Check if colors should be disabled
    if [[ "$NO_COLOR" == "true" || "$TERM" == "dumb" ]]; then
        HAS_COLORS=false
    fi
    
    # Reset all color variables
    NC=""            # No color (reset)
    BLACK=""         # Black
    RED=""           # Red
    GREEN=""         # Green
    YELLOW=""        # Yellow
    BLUE=""          # Blue
    MAGENTA=""       # Magenta
    CYAN=""          # Cyan
    WHITE=""         # White
    BOLD=""          # Bold
    DIM=""           # Dim
    UNDERLINE=""     # Underline
    BLINK=""         # Blink
    INVERT=""        # Invert
    RESET_BOLD=""    # Reset bold
    RESET_DIM=""     # Reset dim
    RESET_UNDERLINE="" # Reset underline
    RESET_BLINK=""   # Reset blink
    RESET_INVERT=""  # Reset invert
    
    # Background colors
    BG_BLACK=""      # Background Black
    BG_RED=""        # Background Red
    BG_GREEN=""      # Background Green
    BG_YELLOW=""     # Background Yellow
    BG_BLUE=""       # Background Blue
    BG_MAGENTA=""    # Background Magenta
    BG_CYAN=""       # Background Cyan
    BG_WHITE=""      # Background White
    
    # Only set colors if terminal supports them
    if [[ "$HAS_COLORS" == "true" ]]; then
        # Basic colors
        NC="\e[0m"              # No color (reset)
        BLACK="\e[30m"          # Black
        RED="\e[31m"            # Red
        GREEN="\e[32m"          # Green
        YELLOW="\e[33m"         # Yellow
        BLUE="\e[34m"           # Blue
        MAGENTA="\e[35m"        # Magenta
        CYAN="\e[36m"           # Cyan
        WHITE="\e[37m"          # White
        
        # Text formatting
        BOLD="\e[1m"            # Bold
        DIM="\e[2m"             # Dim
        UNDERLINE="\e[4m"       # Underline
        BLINK="\e[5m"           # Blink
        INVERT="\e[7m"          # Invert
        RESET_BOLD="\e[21m"     # Reset bold
        RESET_DIM="\e[22m"      # Reset dim
        RESET_UNDERLINE="\e[24m" # Reset underline
        RESET_BLINK="\e[25m"    # Reset blink
        RESET_INVERT="\e[27m"   # Reset invert
        
        # Background colors
        BG_BLACK="\e[40m"       # Background Black
        BG_RED="\e[41m"         # Background Red
        BG_GREEN="\e[42m"       # Background Green
        BG_YELLOW="\e[43m"      # Background Yellow
        BG_BLUE="\e[44m"        # Background Blue
        BG_MAGENTA="\e[45m"     # Background Magenta
        BG_CYAN="\e[46m"        # Background Cyan
        BG_WHITE="\e[47m"       # Background White
        
        # Set the llama warning colors
        LLAMA_COLOR_NORMAL="$YELLOW"
        LLAMA_COLOR_CAUTION="\e[38;5;208m"  # Orange (using 256-color)
        LLAMA_COLOR_DANGER="$RED"
    fi
    
    # Export color variables for use in other scripts
    export NC BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
    export BOLD DIM UNDERLINE BLINK INVERT
    export RESET_BOLD RESET_DIM RESET_UNDERLINE RESET_BLINK RESET_INVERT
    export BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
    export LLAMA_COLOR_NORMAL LLAMA_COLOR_CAUTION LLAMA_COLOR_DANGER
}

# Function to colorize text with graceful degradation
colorize() {
    local color_code="$1"
    local text="$2"
    
    if [[ "$HAS_COLORS" == "true" ]]; then
        echo -e "${color_code}${text}${NC}"
    else
        echo "$text"
    fi
}

# Function to get box drawing characters with UTF-8 or ASCII fallback
get_box_chars() {
    if [[ "$LEONARDO_ASCII_UI" == "true" ]]; then
        # ASCII fallbacks for box drawing
        BOX_H="-"        # Horizontal line
        BOX_V="|"        # Vertical line
        BOX_TL="+"       # Top left corner
        BOX_TR="+"       # Top right corner
        BOX_BL="+"       # Bottom left corner
        BOX_BR="+"       # Bottom right corner
        BOX_LT="+"       # Left T-junction
        BOX_RT="+"       # Right T-junction
        BOX_TT="+"       # Top T-junction
        BOX_BT="+"       # Bottom T-junction
        BOX_CROSS="+"    # Cross junction
    else
        # UTF-8 box drawing characters
        BOX_H="─"        # Horizontal line
        BOX_V="│"        # Vertical line
        BOX_TL="┌"       # Top left corner
        BOX_TR="┐"       # Top right corner
        BOX_BL="└"       # Bottom left corner
        BOX_BR="┘"       # Bottom right corner
        BOX_LT="├"       # Left T-junction
        BOX_RT="┤"       # Right T-junction
        BOX_TT="┬"       # Top T-junction
        BOX_BT="┴"       # Bottom T-junction
        BOX_CROSS="┼"    # Cross junction
    fi
    
    # Export box drawing characters
    export BOX_H BOX_V BOX_TL BOX_TR BOX_BL BOX_BR BOX_LT BOX_RT BOX_TT BOX_BT BOX_CROSS
}

# Initialize colors
init_colors

# Get box characters
get_box_chars
