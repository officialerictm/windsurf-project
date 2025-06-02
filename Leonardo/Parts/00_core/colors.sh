# ==============================================================================
# Color Definitions
# ==============================================================================

# Force all echo commands to use -e to interpret escape sequences
alias echo='echo -e'

# Only define colors when connected to a terminal and colors aren't disabled
if [ -t 1 ] && [ "$NO_COLOR" != "true" ]; then
    # Use more compatible escape sequence format
    # Colors for terminal - using \e instead of \033 for better compatibility
    COLOR_RESET="\e[0m"
    COLOR_BOLD="\e[1m"
    COLOR_DIM="\e[2m"
    COLOR_UNDERLINE="\e[4m"
    COLOR_BLINK="\e[5m"
    COLOR_INVERT="\e[7m"
    
    # Foreground colors
    COLOR_BLACK="\e[30m"
    COLOR_RED="\e[31m"
    COLOR_GREEN="\e[32m"
    COLOR_YELLOW="\e[33m"
    COLOR_BLUE="\e[34m"
    COLOR_MAGENTA="\e[35m"
    COLOR_CYAN="\e[36m"
    COLOR_WHITE="\e[37m"
    
    # Background colors
    COLOR_BG_BLACK="\e[40m"
    COLOR_BG_RED="\e[41m"
    COLOR_BG_GREEN="\e[42m"
    COLOR_BG_YELLOW="\e[43m"
    COLOR_BG_BLUE="\e[44m"
    COLOR_BG_MAGENTA="\e[45m"
    COLOR_BG_CYAN="\e[46m"
    COLOR_BG_WHITE="\e[47m"
    # Custom dark background (256-color dark gray, fallback to black)
    COLOR_BG_DARK="\e[48;5;236m"
    
    # Bright colors
    COLOR_BRIGHT_BLACK="\e[90m"
    COLOR_BRIGHT_RED="\e[91m"
    COLOR_BRIGHT_GREEN="\e[92m"
    COLOR_BRIGHT_YELLOW="\e[93m"
    COLOR_BRIGHT_BLUE="\e[94m"
    COLOR_BRIGHT_MAGENTA="\e[95m"
    COLOR_BRIGHT_CYAN="\e[96m"
    COLOR_BRIGHT_WHITE="\e[97m"
    
    # Custom colors
    # Orange (color between yellow and red for our warning severity system)
    COLOR_ORANGE="\e[38;2;255;140;0m"
    
    # Bright background colors
    COLOR_BG_BRIGHT_BLACK="\e[100m"
    COLOR_BG_BRIGHT_RED="\e[101m"
    COLOR_BG_BRIGHT_GREEN="\e[102m"
    COLOR_BG_BRIGHT_YELLOW="\e[103m"
    COLOR_BG_BRIGHT_BLUE="\e[104m"
    COLOR_BG_BRIGHT_MAGENTA="\e[105m"
    COLOR_BG_BRIGHT_CYAN="\e[106m"
    COLOR_BG_BRIGHT_WHITE="\e[107m"
else
    # No colors for non-terminal output
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_UNDERLINE=""
    COLOR_BLINK=""
    COLOR_INVERT=""
    COLOR_BLACK=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_WHITE=""
    COLOR_BG_BLACK=""
    COLOR_BG_RED=""
    COLOR_BG_GREEN=""
    COLOR_BG_YELLOW=""
    COLOR_BG_BLUE=""
    COLOR_BG_MAGENTA=""
    COLOR_BG_CYAN=""
    COLOR_BG_WHITE=""
    COLOR_BRIGHT_BLACK=""
    COLOR_BRIGHT_RED=""
    COLOR_BRIGHT_GREEN=""
    COLOR_BRIGHT_YELLOW=""
    COLOR_BRIGHT_BLUE=""
    COLOR_BRIGHT_MAGENTA=""
    COLOR_BRIGHT_CYAN=""
    COLOR_BRIGHT_WHITE=""
    COLOR_BG_BRIGHT_BLACK=""
    COLOR_BG_BRIGHT_RED=""
    COLOR_BG_BRIGHT_GREEN=""
    COLOR_BG_BRIGHT_YELLOW=""
    COLOR_BG_BRIGHT_BLUE=""
    COLOR_BG_BRIGHT_MAGENTA=""
    COLOR_BG_BRIGHT_CYAN=""
    COLOR_BG_BRIGHT_WHITE=""
fi

# Extended color palette for enhanced UI
COLOR_ORANGE="\e[38;5;208m"  # Orange color for caution level warnings
COLOR_PURPLE="\e[38;5;135m"  # Purple for special highlights
COLOR_TEAL="\e[38;5;37m"    # Teal for alternative info highlights
COLOR_PINK="\e[38;5;205m"   # Pink for special features

# Gradient colors for progress bars and specialized UI elements
COLOR_GRADIENT_1="\e[38;5;39m"  # Light blue
COLOR_GRADIENT_2="\e[38;5;45m"  # Cyan
COLOR_GRADIENT_3="\e[38;5;51m"  # Light cyan
COLOR_GRADIENT_4="\e[38;5;87m"  # Sky blue

# Define llama warning levels for different severities
# From user memory: Implemented a progression of warning severities
LLAMA_NORMAL="(•ᴗ•)🦙"  # Friendly llama for normal operations
LLAMA_CAUTION="(>‿-)🦙"  # Mischievous winking llama for first level caution
LLAMA_WARNING="(ಠ‿ಠ)🦙"  # Intense/crazy-eyed llama for serious warnings
LLAMA_WARNING_SERIOUS="(ಠ‿ಠ)🦙"  # Alias for backward compatibility
