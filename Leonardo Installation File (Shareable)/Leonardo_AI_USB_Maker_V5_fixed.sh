#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Leonardo AI USB Maker - Create portable Ollama AI environments
# Version 5.0.0 - International Coding Competition 2025 Edition
# Authors: Eric & Friendly AI Assistant
# License: MIT
# ═══════════════════════════════════════════════════════════════════════════

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SCRIPT_SELF_NAME=$(basename "$0")
SCRIPT_VERSION="5.0.0" # Competition Edition
USB_LABEL_DEFAULT="LEONARDO"
USB_LABEL="$USB_LABEL_DEFAULT"
USE_GITHUB_API=false
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

# ANSI color codes
COLORS_ENABLED=true
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_ITALIC="\033[3m"
C_UNDERLINE="\033[4m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_MAGENTA="\033[35m"
C_CYAN="\033[36m"
C_WHITE="\033[37m"
C_BG_RED="\033[41m"
C_BG_GREEN="\033[42m"
C_BG_YELLOW="\033[43m"

# --- Utility Functions ---

# Print information with proper formatting
print_info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $1"
}

print_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

print_warning() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

print_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1"
}

print_fatal() {
    echo -e "${C_BG_RED}${C_BOLD}[FATAL ERROR]${C_RESET} $1"
    exit 1
}

print_header() {
    echo -e "\n${C_BOLD}${C_CYAN}$1${C_RESET}\n"
}

print_line() {
    echo -e "${C_DIM}──────────────────────────────────────────────────────────────────${C_RESET}"
}

print_prompt() {
    echo -en "${C_GREEN}${C_BOLD}$1${C_RESET}"
}

# Enhanced download function with progress visualization
fancy_download() {
    local url="$1"
    local output_file="$2"
    local description="$3"
    local quiet="${4:-false}"
    local temp_file="$(mktemp)"
    
    # Display download information
    if ! $quiet; then
        print_info "Downloading $description from $url"
    fi
    
    # Start download using curl or wget
    if command -v curl &> /dev/null; then
        curl -L -s -o "$output_file" "$url" 2>"$temp_file"
    elif command -v wget &> /dev/null; then
        wget -q -O "$output_file" "$url" 2>"$temp_file"
    else
        rm -f "$temp_file"
        print_fatal "Neither curl nor wget found for downloading."
        return 1
    fi
    
    local exit_code=$?
    
    # Report result
    if [ $exit_code -eq 0 ]; then
        if ! $quiet; then
            print_success "Download complete: $description"
        fi
    else
        print_error "Download failed: $description"
        print_error "Error: $(cat "$temp_file")"
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
    
    # Cleanup
    rm -f "$temp_file" 2>/dev/null || true
    
    return $exit_code
}

# Function to create a seed file for easy distribution
create_seed_file() {
    local target_dir="$1"
    local seed_file="$target_dir/leonardo_seed.sh"
    
    print_info "Creating seed file in: $target_dir"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create the seed file with a header
    echo '#!/bin/bash' > "$seed_file"
    echo '# Leonardo AI USB Maker - SEED FILE' >> "$seed_file"
    echo '# International Coding Competition 2025 Edition' >> "$seed_file"
    echo '' >> "$seed_file"
    
    # Add installation instructions
    echo 'echo "Creating installation directory..."' >> "$seed_file"
    echo 'mkdir -p "Leonardo Installation File (Shareable)"' >> "$seed_file"
    echo '' >> "$seed_file"
    
    # Add script content section
    echo 'echo "Generating Leonardo AI USB Maker script..."' >> "$seed_file"
    echo 'cat > "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh" << '\''EOFSCRIPT'\''' >> "$seed_file"
    
    # Append the entire script content
    cat "$0" >> "$seed_file"
    
    # Close the heredoc and add final instructions
    echo 'EOFSCRIPT' >> "$seed_file"
    echo '' >> "$seed_file"
    echo 'chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"' >> "$seed_file"
    echo 'echo "Leonardo AI USB Maker has been successfully installed!"' >> "$seed_file"
    echo 'echo "You can find it in the '\''Leonardo Installation File (Shareable)'\'' directory."' >> "$seed_file"
    
    # Make the seed file executable
    chmod +x "$seed_file"
    
    print_success "Seed file created successfully at: $seed_file"
    print_info "This seed file can be shared to easily install Leonardo AI USB Maker on other systems."
    return 0
}

# Function to initialize USB health tracking
initialize_usb_health() {
    local usb_path="$1"
    
    if ! $USB_HEALTH_TRACKING; then
        return 0
    fi
    
    USB_HEALTH_DATA_FILE="$usb_path/.leonardo_usb_health"
    
    # Check if health data file exists and load it
    if [ -f "$USB_HEALTH_DATA_FILE" ]; then
        print_info "Loading USB health data..."
        source "$USB_HEALTH_DATA_FILE"
    else
        # Initialize with default values
        USB_WRITE_CYCLE_COUNTER=0
        USB_FIRST_USE_DATE=$(date +"%Y-%m-%d")
        USB_TOTAL_BYTES_WRITTEN=0
        
        # Try to detect USB drive information
        if command -v lsblk &> /dev/null && command -v udevadm &> /dev/null; then
            local device_name=$(echo "$usb_path" | sed -E 's|/dev/([^/]+).*|\1|')
            if [ -n "$device_name" ]; then
                USB_MODEL=$(lsblk -no model "/dev/$device_name" 2>/dev/null || echo "Unknown")
                USB_SERIAL=$(udevadm info --query=property --name="/dev/$device_name" 2>/dev/null | grep ID_SERIAL= | cut -d= -f2 || echo "Unknown")
            fi
        fi
        
        # Estimate lifespan based on drive model (default values)
        USB_ESTIMATED_LIFESPAN=3000 # Default for standard USB drives
        
        # Save initial health data
        save_usb_health_data
    fi
    
    print_info "USB health tracking initialized."
    return 0
}

# Function to save USB health data
save_usb_health_data() {
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        return 0
    fi
    
    # Create or update the health data file
    cat > "$USB_HEALTH_DATA_FILE" << EOF
# Leonardo AI USB Maker - USB Health Data
# Last updated: $(date)
USB_WRITE_CYCLE_COUNTER=$USB_WRITE_CYCLE_COUNTER
USB_FIRST_USE_DATE="$USB_FIRST_USE_DATE"
USB_TOTAL_BYTES_WRITTEN=$USB_TOTAL_BYTES_WRITTEN
USB_MODEL="$USB_MODEL"
USB_SERIAL="$USB_SERIAL"
USB_ESTIMATED_LIFESPAN=$USB_ESTIMATED_LIFESPAN
EOF
    
    chmod 600 "$USB_HEALTH_DATA_FILE" # Secure permissions
    return 0
}

# Function to update USB health data after a write operation
update_usb_health_data() {
    local bytes_written="$1"
    
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        return 0
    fi
    
    # Increment write cycle counter
    USB_WRITE_CYCLE_COUNTER=$((USB_WRITE_CYCLE_COUNTER + 1))
    
    # Add bytes written
    if [ -n "$bytes_written" ] && [ "$bytes_written" -gt 0 ]; then
        USB_TOTAL_BYTES_WRITTEN=$((USB_TOTAL_BYTES_WRITTEN + bytes_written))
    fi
    
    # Save updated data
    save_usb_health_data
    
    # Check if we should display a warning
    check_usb_health_warning
    
    return 0
}

# Function to check USB health and display warnings if needed
check_usb_health_warning() {
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        return 0
    fi
    
    # Calculate percentage of estimated life used
    local percent_used=0
    if [ $USB_ESTIMATED_LIFESPAN -gt 0 ]; then
        percent_used=$((USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN))
    fi
    
    # Display appropriate warnings based on usage
    if [ $percent_used -ge 90 ]; then
        print_warning "(ಠ‿ಠ)🦙 CRITICAL: This USB drive has used approximately ${percent_used}% of its estimated lifespan!"
        print_warning "Data loss is imminent. Please create a backup immediately and replace this drive."
    elif [ $percent_used -ge 75 ]; then
        print_warning "(>‿-)🦙 WARNING: This USB drive has used approximately ${percent_used}% of its estimated lifespan."
        print_warning "Consider creating a backup and preparing a replacement drive."
    elif [ $percent_used -ge 50 ]; then
        print_info "(•ᴗ•)🦙 NOTICE: This USB drive has used approximately ${percent_used}% of its estimated lifespan."
    fi
    
    return 0
}

# Function to display USB health report
display_usb_health() {
    if ! $USB_HEALTH_TRACKING || [ -z "$USB_HEALTH_DATA_FILE" ]; then
        print_error "USB health tracking is not enabled or initialized."
        return 1
    fi
    
    print_header "USB DRIVE HEALTH REPORT"
    
    echo -e "${C_BOLD}Drive Model:${C_RESET}      $USB_MODEL"
    echo -e "${C_BOLD}Serial Number:${C_RESET}    $USB_SERIAL"
    echo -e "${C_BOLD}First Used:${C_RESET}       $USB_FIRST_USE_DATE"
    
    # Calculate days in use
    local days_used=0
    local today=$(date +%s)
    local first_use=$(date -d "$USB_FIRST_USE_DATE" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$USB_FIRST_USE_DATE" +%s 2>/dev/null || echo "0")
    if [ $first_use -gt 0 ]; then
        days_used=$(( (today - first_use) / 86400 ))
    fi
    echo -e "${C_BOLD}Days in Use:${C_RESET}      $days_used days"
    
    # Format total bytes written
    local formatted_bytes=""
    if [ $USB_TOTAL_BYTES_WRITTEN -gt 1073741824 ]; then # 1GB
        formatted_bytes="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN/1073741824" | bc) GB"
    elif [ $USB_TOTAL_BYTES_WRITTEN -gt 1048576 ]; then # 1MB
        formatted_bytes="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN/1048576" | bc) MB"
    elif [ $USB_TOTAL_BYTES_WRITTEN -gt 1024 ]; then # 1KB
        formatted_bytes="$(echo "scale=2; $USB_TOTAL_BYTES_WRITTEN/1024" | bc) KB"
    else
        formatted_bytes="$USB_TOTAL_BYTES_WRITTEN bytes"
    fi
    
    echo -e "${C_BOLD}Write Cycles:${C_RESET}     $USB_WRITE_CYCLE_COUNTER cycles"
    echo -e "${C_BOLD}Data Written:${C_RESET}     $formatted_bytes"
    
    # Calculate percentage of estimated life used
    local percent_used=0
    if [ $USB_ESTIMATED_LIFESPAN -gt 0 ]; then
        percent_used=$((USB_WRITE_CYCLE_COUNTER * 100 / USB_ESTIMATED_LIFESPAN))
    fi
    
    # Display health status with color coding
    echo -ne "${C_BOLD}Health Status:${C_RESET}    "
    if [ $percent_used -ge 90 ]; then
        echo -e "${C_BG_RED}${C_BOLD} CRITICAL ${C_RESET} (${percent_used}% of estimated lifespan used)"
    elif [ $percent_used -ge 75 ]; then
        echo -e "${C_BG_YELLOW}${C_BOLD} WARNING ${C_RESET} (${percent_used}% of estimated lifespan used)"
    elif [ $percent_used -ge 50 ]; then
        echo -e "${C_YELLOW}${C_BOLD} MODERATE ${C_RESET} (${percent_used}% of estimated lifespan used)"
    else
        echo -e "${C_GREEN}${C_BOLD} GOOD ${C_RESET} (${percent_used}% of estimated lifespan used)"
    fi
    
    print_line
    return 0
}

# Function to display download history
display_download_history() {
    local count=${#DOWNLOAD_HISTORY[@]}
    
    if [ $count -eq 0 ]; then
        print_info "No downloads have been performed yet."
        return 0
    fi
    
    print_header "DOWNLOAD HISTORY"
    
    echo -e "${C_BOLD}Total Downloads:${C_RESET} $count"
    
    # Format total bytes downloaded
    local formatted_total=""
    if [ $TOTAL_BYTES_DOWNLOADED -gt 1073741824 ]; then # 1GB
        formatted_total="$(echo "scale=2; $TOTAL_BYTES_DOWNLOADED/1073741824" | bc) GB"
    elif [ $TOTAL_BYTES_DOWNLOADED -gt 1048576 ]; then # 1MB
        formatted_total="$(echo "scale=2; $TOTAL_BYTES_DOWNLOADED/1048576" | bc) MB"
    elif [ $TOTAL_BYTES_DOWNLOADED -gt 1024 ]; then # 1KB
        formatted_total="$(echo "scale=2; $TOTAL_BYTES_DOWNLOADED/1024" | bc) KB"
    else
        formatted_total="$TOTAL_BYTES_DOWNLOADED bytes"
    fi
    
    echo -e "${C_BOLD}Total Data:${C_RESET}    $formatted_total"
    print_line
    
    # Display header
    echo -e "${C_BOLD}Time     | Size      | Status | Description${C_RESET}"
    print_line
    
    # Display each download
    for ((i=0; i<count; i++)); do
        local timestamp="${DOWNLOAD_TIMESTAMPS[$i]}"
        local size="${DOWNLOAD_SIZES[$i]}"
        local status="${DOWNLOAD_STATUS[$i]}"
        local description="${DOWNLOAD_HISTORY[$i]}"
        local destination="${DOWNLOAD_DESTINATIONS[$i]}"
        
        # Format file size
        local formatted_size=""
        if [ $size -gt 1073741824 ]; then # 1GB
            formatted_size="$(echo "scale=2; $size/1073741824" | bc) GB"
        elif [ $size -gt 1048576 ]; then # 1MB
            formatted_size="$(echo "scale=2; $size/1048576" | bc) MB"
        elif [ $size -gt 1024 ]; then # 1KB
            formatted_size="$(echo "scale=2; $size/1024" | bc) KB"
        else
            formatted_size="${size} B"
        fi
        
        # Pad size to 10 characters
        formatted_size=$(printf "%-10s" "$formatted_size")
        
        # Format status
        local status_text=""
        if [ "$status" -eq 0 ]; then
            status_text="${C_GREEN}OK${C_RESET}   "
        else
            status_text="${C_RED}FAIL${C_RESET} "
        fi
        
        # Print the line
        echo -e "$timestamp | $formatted_size | $status_text | $description"
        echo -e "         | ${C_DIM}Path: $destination${C_RESET}"
    done
    
    print_line
    return 0
}

# --- Main Menu Options ---
declare -a main_menu_options
main_menu_options=(
    "create_seed" "Create Shareable Seed File (Competition Feature)"
    "display_health" "Display USB Drive Health Report"
    "display_downloads" "Display Download History"
    "quit" "Exit the Application"
)

# --- Main Application Logic ---

# Handle seed file creation operation
handle_seed_file_creation() {
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
}

# Handle USB health display operation
handle_usb_health_display() {
    # Initialize USB health with current directory (for demo purposes)
    initialize_usb_health "$(pwd)"
    
    # Display health report
    display_usb_health
    
    print_line
    print_prompt "Press Enter to return to the main menu"
    read -r
}

# Handle download history display operation
handle_download_history_display() {
    # Display download history
    display_download_history
    
    print_line
    print_prompt "Press Enter to return to the main menu"
    read -r
}

# Main function to run the application
main() {
    while true; do
        print_header "LEONARDO AI USB MAKER v${SCRIPT_VERSION}"
        print_info "Competition Edition is ready!"
        print_line
        
        echo "Please select an operation:"
        echo ""
        
        # Display menu options
        local idx=0
        while [ $idx -lt ${#main_menu_options[@]} ]; do
            local option="${main_menu_options[$idx]}"
            local description="${main_menu_options[$((idx+1))]}"
            
            # Skip separator entries
            if [[ "$option" != *"_separator" ]]; then
                echo -e "  ${C_BOLD}$((idx/2+1))${C_RESET}) $description"
            else
                echo ""
            fi
            
            idx=$((idx+2))
        done
        
        echo ""
        print_prompt "Enter your choice (or 'q' to quit): "
        read -r choice
        
        # Handle quit options
        if [[ "$choice" == "q" || "$choice" == "Q" || "$choice" == "quit" ]]; then
            print_info "Thank you for using Leonardo AI USB Maker. Goodbye!"
            break
        fi
        
        # Convert choice to numeric index
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            choice=$((choice-1))
            
            # Get the corresponding operation
            local idx=$((choice*2))
            if [ $idx -ge 0 ] && [ $idx -lt ${#main_menu_options[@]} ]; then
                local operation="${main_menu_options[$idx]}"
                
                # Execute the selected operation
                case "$operation" in
                    "create_seed")
                        handle_seed_file_creation
                        ;;
                    "display_health")
                        handle_usb_health_display
                        ;;
                    "display_downloads")
                        handle_download_history_display
                        ;;
                    "quit")
                        print_info "Thank you for using Leonardo AI USB Maker. Goodbye!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid operation: $operation"
                        ;;
                esac
            else
                print_error "Invalid choice: $((choice+1))"
            fi
        else
            print_error "Invalid input. Please enter a number."
        fi
    done
}

# Run the main function
main

exit 0
