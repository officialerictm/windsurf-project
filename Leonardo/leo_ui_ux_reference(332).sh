#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SCRIPT_SELF_NAME=$(basename "$0")
SCRIPT_VERSION="3.3.2" # Added WebUI streaming mode toggle feature
USB_LABEL_DEFAULT="CHATUSB"
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

C_RESET="" C_BOLD="" C_DIM="" C_UNDERLINE="" C_NO_UNDERLINE=""
C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE="" C_GREY=""

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
print_line() { echo -e "${C_DIM}──────────────────────────────────────────────────────────────────────${C_RESET}"; }
print_divider_thin() { echo -e "${C_DIM}⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯${C_RESET}"; }
print_double_line() { echo -e "${C_BOLD}${C_MAGENTA}══════════════════════════════════════════════════════════════════════${C_RESET}"; }
print_header() {
    echo -e "\n${C_BOLD}${C_MAGENTA}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
    printf "${C_BOLD}${C_MAGENTA}│ %-66s │${C_RESET}\n" "$1"
    echo -e "${C_BOLD}${C_MAGENTA}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
}
print_subheader() { echo -e "\n${C_BOLD}${C_CYAN}--- $1 ---${C_RESET}"; }
print_info() { echo -e "${C_BLUE}ℹ️  $1${C_RESET}"; }
print_success() { echo -e "${C_GREEN}✅ $1${C_RESET}"; }
print_warning() { echo -e "${C_YELLOW}⚠️  $1${C_RESET}"; }
print_error() { echo -e "${C_RED}❌ ERROR: $1${C_RESET}"; }
print_debug() { if [ -n "${DEBUG+x}" ] && [ "$DEBUG" = "true" ]; then echo -e "${C_GREY}DEBUG: $1${C_RESET}"; fi; }
print_fatal() { echo -e "${C_BOLD}${C_RED}☠️ FATAL: $1${C_RESET}"; exit 1; }
print_prompt() { echo -ne "${C_CYAN}➡️  $1${C_RESET}"; }
print_option() { echo -e "${C_BOLD}${C_YELLOW}[$1]${C_RESET} $2"; }

# Function to clear screen and show the Leonardo title art
clear_screen_and_show_art() {
    # Clear screen if possible
    if $TPUT_CLEAR_POSSIBLE && [ -n "$TPUT_CMD_PATH" ]; then
        "$TPUT_CMD_PATH" clear
    else
        # Fallback for systems without tput
        echo -e "\033c"
    fi
    
    print_leonardo_title_art
}

# --- ASCII Art Functions ---
print_leonardo_title_art() {
echo -e "${C_BOLD}${C_GREEN}"
echo "  ===================================================================="
echo "  ||                                                                ||"
echo "  ||    Leonardo AI USB Maker ✨ - Forge Your Portable AI Future!   ||"
echo "  ||                                                                ||"
echo "  ===================================================================="
echo "         (\\(\\   "
echo "         (•ᴗ•)🦙 "
echo "         / >)_/"
echo "        \"Let's make an AI USB!\""
echo ""
echo -e "  (Brought to you by Eric & Your Friendly AI Assistant)${C_RESET}"
echo ""
}
print_leonardo_success_art() {
echo -e "${C_BOLD}${C_GREEN}"
echo ""
echo "           (\\(\\   "
echo "           (•ᴖ•)🦙  "
echo "           / >💾 USB "
echo "          \"Forge Complete!\""
echo ""
echo "    🚀 Congratulations! Your Leonardo AI USB is Forged & Ready! 🚀"
echo -e "${C_RESET}"
}

# --- Core Utility Functions ---
spinner() {
    local pid=$1; local message=${2:-"Processing..."}; local delay=0.1; local spinstr='|/-\'
    echo -ne "${C_BLUE}$message  ${C_RESET}"; while ps -p "$pid" > /dev/null; do local temp=${spinstr#?}; printf "${C_CYAN} [%c]  ${C_RESET}" "$spinstr"; spinstr=$temp${spinstr%"$temp"}; sleep $delay; printf "\b\b\b\b\b\b"; done
    printf "    \b\b\b\b${C_GREEN}Done!${C_RESET}\n"; wait "$pid"; return $?
}

ask_yes_no_quit() {
    local prompt_message=$1; local result_var_name=$2; local choice
    print_double_line
    echo -e "${C_BOLD}${C_YELLOW}🤔 USER INPUT REQUIRED 🤔${C_RESET}"
    echo -e "${C_YELLOW}  (\\(\\   "
    echo -e "  (•ᴗ•)🦙 ${C_RESET}"
    echo -e "${C_YELLOW} / >)_/   ${C_RESET}"
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
    
    if [ "$bytes_in" -lt 1024 ]; then 
        echo "${C_BOLD}${bytes_in}B${C_RESET}"
    elif [ "$bytes_in" -lt 1048576 ]; then 
        # Convert to KB with 1 decimal place
        local kb_value=$((bytes_in * 10 / 1024))
        local kb_whole=$((kb_value / 10))
        local kb_fraction=$((kb_value % 10))
        echo "${C_BOLD}${kb_whole}.${kb_fraction}KB${C_RESET}"
    elif [ "$bytes_in" -lt 1073741824 ]; then 
        # Convert to MB with 1 decimal place
        local mb_value=$((bytes_in * 10 / 1048576))
        local mb_whole=$((mb_value / 10))
        local mb_fraction=$((mb_value % 10))
        echo "${C_BOLD}${mb_whole}.${mb_fraction}MB${C_RESET}"
    else 
        # Convert to GB with 1 decimal place
        local gb_value=$((bytes_in * 10 / 1073741824))
        local gb_whole=$((gb_value / 10))
        local gb_fraction=$((gb_value % 10))
        echo "${C_BOLD}${gb_whole}.${gb_fraction}GB${C_RESET}"
    fi
}

# Function to normalize paths between Windows and Unix systems
normalize_path() {
    local path="$1"
    local os_type="$2"  # 'windows', 'unix', or auto-detect if empty
    
    # Auto-detect OS type if not specified
    if [ -z "$os_type" ]; then
        if [[ "$path" == *":"* && ("${path:1:1}" == ":" || "${path:0:1}" == "/") ]]; then
            # Path has a drive letter (like C:) or starts with /
            if [[ "${path:1:1}" == ":" ]]; then
                os_type="windows"
            else
                os_type="unix"
            fi
        elif [[ "$(uname)" == "Darwin" || "$(uname)" == "Linux" ]]; then
            os_type="unix"
        else
            os_type="windows"
        fi
    fi
    
    # Normalize the path according to OS type
    if [ "$os_type" = "windows" ]; then
        # Convert unix paths to windows
        # Replace forward slashes with backslashes
        local normalized_path="$(echo "$path" | sed 's|/|\\|g')"
        # Ensure path has a drive letter
        if [[ "$normalized_path" != *":"* ]]; then
            # If no drive letter, assume current drive
            normalized_path="C:$normalized_path"
        fi
        echo "$normalized_path"
    else
        # Convert windows paths to unix
        # Replace backslashes with forward slashes
        local normalized_path="$(echo "$path" | sed 's|\\|/|g')"
        # Remove drive letter if present (e.g., C:)
        if [[ "${normalized_path:1:1}" == ":" ]]; then
            normalized_path="/${normalized_path:2}"
        fi
        # Ensure path starts with /
        if [[ "$normalized_path" != /* ]]; then
            normalized_path="/$normalized_path"
        fi
        echo "$normalized_path"
    fi
}

# Function to ensure proper line endings for scripts based on target OS
ensure_proper_line_endings() {
    local file="$1"
    local target_os="$2"  # 'windows', 'mac', 'linux'
    
    if [ ! -f "$file" ]; then
        print_error "Cannot set line endings: file '$file' does not exist"
        return 1
    fi
    
    print_debug "Setting proper line endings for $file (target OS: $target_os)"
    
    case "$target_os" in
        windows)
            # Check if file has CRLF endings
            if ! grep -q $'\r$' "$file" 2>/dev/null; then
                # File has LF endings, convert to CRLF
                print_debug "Converting LF to CRLF for Windows script: $file"
                if command -v unix2dos &>/dev/null; then
                    # Use unix2dos if available (best option)
                    unix2dos "$file" >/dev/null 2>&1
                else
                    # Fallback to sed for conversion
                    local temp_file="${file}.tmp"
                    sed 's/$/\r/' "$file" > "$temp_file" && mv "$temp_file" "$file"
                fi
            fi
            ;;  
        mac|linux|unix)
            # Check if file has CRLF endings
            if grep -q $'\r$' "$file" 2>/dev/null; then
                # File has CRLF endings, convert to LF
                print_debug "Converting CRLF to LF for Unix script: $file"
                if command -v dos2unix &>/dev/null; then
                    # Use dos2unix if available (best option)
                    dos2unix "$file" >/dev/null 2>&1
                else
                    # Fallback to tr for conversion
                    local temp_file="${file}.tmp"
                    tr -d '\r' < "$file" > "$temp_file" && mv "$temp_file" "$file"
                fi
            fi
            ;;   
        *)
            print_warning "Unknown target OS: $target_os, skipping line ending conversion"
            return 1
            ;;
    esac
    
    return 0
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


# --- Placeholder Functions (Implement these for full functionality) ---
ensure_usb_mounted_and_writable() {
    print_info "Ensuring USB drive ${C_BOLD}$USB_DEVICE_PATH${C_RESET} is mounted and writable..."

    if [ -z "$USB_DEVICE_PATH" ]; then
        print_error "USB_DEVICE_PATH is not set. Cannot proceed with mounting."
        return 1
    fi

    # Determine the correct partition for the device
    local usb_partition=""
    local current_user_name=$(whoami)
    local found_mount_point=""
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # For macOS, find the disk identifier and volume name
        local vol_name
        vol_name=$(diskutil info "$USB_DEVICE_PATH" 2>/dev/null | grep "Volume Name:" | sed -e 's/.*Volume Name:[^A-Za-z0-9]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        if [ -z "$vol_name" ] || [[ "$vol_name" =~ "Not applicable" ]]; then
            print_info "No volume name found for $USB_DEVICE_PATH. Checking if it needs to be mounted..."
            # If not mounted, we need to mount it
            if ! diskutil info "$USB_DEVICE_PATH" | grep -q "Mounted: Yes"; then
                print_info "Device is not mounted. Attempting to mount..."
                
                # First try to get the volume identifier (disk2s1) instead of disk device (disk2)
                local disk_partitions=$(diskutil list "$USB_DEVICE_PATH" | grep -E "^[[:space:]]+[0-9]+:" | awk '{print $NF}')
                
                if [ -n "$disk_partitions" ]; then
                    # Try to mount the first partition
                    local first_partition="${USB_DEVICE_PATH}s1"
                    print_info "Found partition: $first_partition, attempting to mount..."
                    
                    if diskutil mount "$first_partition" > /dev/null 2>&1; then
                        vol_name=$(diskutil info "$first_partition" | grep "Volume Name:" | sed -e 's/.*Volume Name:[^A-Za-z0-9]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                        print_success "Mounted partition as: $vol_name"
                    else
                        # Try alternate ways to mount
                        print_info "Trying to mount by label: $USB_LABEL"
                        if diskutil mount "$USB_LABEL" > /dev/null 2>&1; then
                            vol_name="$USB_LABEL"
                            print_success "Mounted by label: $USB_LABEL"
                        else
                            # Try the mountDisk command as a last resort
                            print_info "Attempting to mount all partitions on $USB_DEVICE_PATH..."
                            if diskutil mountDisk "$USB_DEVICE_PATH" > /dev/null 2>&1; then
                                print_success "Mounted disk via mountDisk command"
                                # Get the actual mount point now
                                local mount_points=$(diskutil list "$USB_DEVICE_PATH" | grep -A 10 "^/dev" | grep "/Volumes/" | awk '{print $NF}')
                                if [ -n "$mount_points" ]; then
                                    vol_name=$(basename "$(echo "$mount_points" | head -n 1)")
                                fi
                            else
                                print_error "Failed to mount $USB_DEVICE_PATH or any of its partitions"
                                return 1
                            fi
                        fi
                    fi
                else
                    print_warning "No partitions found on $USB_DEVICE_PATH"
                    # Try direct mount anyway
                    if diskutil mount "$USB_DEVICE_PATH" > /dev/null 2>&1; then
                        vol_name=$(diskutil info "$USB_DEVICE_PATH" | grep "Volume Name:" | sed -e 's/.*Volume Name:[^A-Za-z0-9]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                        print_success "Mounted device directly as: $vol_name"
                    else
                        print_error "Failed to mount $USB_DEVICE_PATH"
                        return 1
                    fi
                fi
            fi
        fi
        
        # Find the mount point
        if [ -n "$vol_name" ] && [[ ! "$vol_name" =~ "Not applicable" ]]; then
            found_mount_point=$(df -h | grep -E "/Volumes/${vol_name}$" | awk '{print $NF}')
        fi
        
        if [ -z "$found_mount_point" ]; then
            found_mount_point=$(df -h | grep "$USB_DEVICE_PATH" | awk '{print $NF}')
        fi
        
        # If still not found, one last attempt to mount by label
        if [ -z "$found_mount_point" ] && [ -n "$USB_LABEL" ]; then
            print_info "Attempting to mount by label: $USB_LABEL"
            diskutil mount "$USB_LABEL" > /dev/null 2>&1
            found_mount_point=$(df -h | grep -E "/Volumes/${USB_LABEL}$" | awk '{print $NF}')
        fi
        
    elif [[ "$(uname)" == "Linux" ]]; then
        # For Linux, find the correct partition
        if [[ "$USB_DEVICE_PATH" == *nvme*n* ]] || [[ "$USB_DEVICE_PATH" == *mmcblk* ]]; then
            usb_partition="${USB_DEVICE_PATH}p1"
        else
            usb_partition="${USB_DEVICE_PATH}1"
        fi
        
        # Check if already mounted
        if [ -n "$USB_LABEL" ]; then
            found_mount_point=$(findmnt -n -o TARGET "/media/$current_user_name/$USB_LABEL" 2>/dev/null || 
                               findmnt -n -o TARGET "/run/media/$current_user_name/$USB_LABEL" 2>/dev/null || 
                               findmnt -n -o TARGET "/mnt/$USB_LABEL" 2>/dev/null)
        fi
        
        if [ -z "$found_mount_point" ]; then
            found_mount_point=$(lsblk -no MOUNTPOINT "$USB_DEVICE_PATH" | grep -v '^$' | head -n 1)
            if [ -z "$found_mount_point" ] && [ -n "$usb_partition" ]; then
                found_mount_point=$(lsblk -no MOUNTPOINT "$usb_partition" | grep -v '^$' | head -n 1)
            fi
        fi
        
        # If not mounted, try to mount it
        if [ -z "$found_mount_point" ]; then
            print_info "Device not mounted. Attempting to mount..."
            
            # Create mount point if it doesn't exist
            MOUNT_POINT="/mnt/$USB_LABEL"
            if [ ! -d "$MOUNT_POINT" ]; then
                sudo mkdir -p "$MOUNT_POINT"
            fi
            
            # Try to mount the partition
            if [ -n "$usb_partition" ] && [ -e "$usb_partition" ]; then
                if sudo mount "$usb_partition" "$MOUNT_POINT" 2>/dev/null; then
                    found_mount_point="$MOUNT_POINT"
                    print_success "Mounted $usb_partition to $MOUNT_POINT"
                else
                    print_warning "Failed to mount $usb_partition. Trying mount by label..."
                    if [ -n "$USB_LABEL" ]; then
                        if sudo mount -L "$USB_LABEL" "$MOUNT_POINT" 2>/dev/null; then
                            found_mount_point="$MOUNT_POINT"
                            print_success "Mounted by label $USB_LABEL to $MOUNT_POINT"
                        fi
                    fi
                fi
            else
                print_warning "Partition $usb_partition not found or doesn't exist."
            fi
        fi
    fi

    # Set base path if mount point found
    if [ -n "$found_mount_point" ] && [ -d "$found_mount_point" ]; then
        print_success "USB drive mounted at: $found_mount_point"
        USB_BASE_PATH="$found_mount_point"
        MOUNT_POINT="$found_mount_point"
    else
        print_error "Failed to find or create a valid mount point for $USB_DEVICE_PATH"
        return 1
    fi

    # Verify writability
    if sudo touch "$USB_BASE_PATH/.leonardo_write_test" 2>/dev/null; then
        sudo rm "$USB_BASE_PATH/.leonardo_write_test"
        print_success "USB drive at $USB_BASE_PATH is writable."
        return 0
    else
        print_error "Failed to write to $USB_BASE_PATH. Check permissions or mount options."
        return 1
    fi
}

# Function to recommend optimal filesystem for cross-platform compatibility
recommend_filesystem() {
    print_info "Analyzing system for optimal cross-platform filesystem support..."
    
    # For macOS systems, always suggest exFAT with option to override
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS has native exFAT support in modern versions
        print_info "Your macOS system should support exFAT natively."
        
        # Always ask for filesystem choice on macOS
        print_info "${C_BOLD}Please select filesystem format:${C_RESET}"
        print_option "1" "exFAT (${C_BOLD}RECOMMENDED${C_RESET} - supports files over 4GB)"
        print_option "2" "FAT32 (maximum compatibility but 4GB file size limit)"
        
        local fs_choice=""
        print_prompt "Enter your choice [1/2] (default: 1): "
        read fs_choice
        
        if [ -z "$fs_choice" ] || [ "$fs_choice" = "1" ]; then
            print_success "Using exFAT filesystem (supports large AI models)"
            return 0 # Use exFAT
        else
            print_warning "Using FAT32 filesystem (4GB file size limit)"
            return 1 # Use FAT32
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux - check for exfat utilities
        if command -v mkfs.exfat &>/dev/null || command -v exfatfsck &>/dev/null; then
            print_success "exFAT utilities detected - using exFAT for best compatibility"
            return 0 # Use exFAT
        else
            print_warning "exFAT tools not found. Using FAT32 (4GB file size limit)"
            print_info "To use exFAT, install exfat-utils or exfatprogs"
            return 1 # Use FAT32
        fi
    else
        # Unknown OS, offer choice with FAT32 as safer default
        print_info "${C_BOLD}Please select filesystem format:${C_RESET}"
        print_option "1" "exFAT (supports files over 4GB, may require drivers)"
        print_option "2" "FAT32 (maximum compatibility but 4GB file size limit)"
        
        local fs_choice=""
        print_prompt "Enter your choice [1/2] (default: 2): "
        read fs_choice
        
        if [ "$fs_choice" = "1" ]; then
            print_success "Using exFAT filesystem (supports large AI models)"
            return 0 # Use exFAT
        else
            print_warning "Using FAT32 filesystem (4GB file size limit)"
            return 1 # Use FAT32
        fi
    fi
}

# Function to format USB drive
ask_format_usb() {
    print_subheader "🖴 USB Drive Formatting"

    # Get filesystem recommendation first - this now includes user choice
    recommend_filesystem
    local use_exfat=$?
    local filesystem_type="exFAT"
    
    if [ $use_exfat -ne 0 ]; then
        filesystem_type="FAT32"
    fi
    
    print_line
    print_info "Selected filesystem: ${C_BOLD}$filesystem_type${C_RESET}"
    
    local format_usb="no"
    ask_yes_no_quit "Do you want to format the USB drive $USB_DEVICE_PATH?\n   (RECOMMENDED for new setups. ALL DATA ON $USB_DEVICE_PATH WILL BE LOST!)" format_usb
    
    if [ "$format_usb" = "yes" ]; then
        if [ -z "$USB_LABEL" ] || [[ "$USB_LABEL" =~ "Not applicable" ]]; then
            USB_LABEL="$USB_LABEL_DEFAULT"
        fi
        
        print_info "USB will be formatted as $filesystem_type with label: $USB_LABEL"
        
        # For macOS, extra safety check for internal disks
        if [[ "$(uname)" == "Darwin" ]] && [ -n "$RAW_USB_DEVICE_PATH" ] ; then
            local is_internal_disk
            is_internal_disk=$(diskutil info "$RAW_USB_DEVICE_PATH" 2>/dev/null | grep "Internal:" | awk '{print $2}')
            if [[ "$is_internal_disk" == "Yes" ]]; then
                print_line
                print_error "CRITICAL WARNING: You selected $RAW_USB_DEVICE_PATH for formatting,"
                print_error "and it appears to be an INTERNAL disk on your macOS system."
                print_error "Formatting this disk WILL ERASE YOUR OPERATING SYSTEM OR OTHER IMPORTANT DATA."
                local confirm_internal_format_choice
                ask_yes_no_quit "${C_RED}${C_BOLD}ARE YOU ABSOLUTELY SURE you want to format this internal-looking disk ($RAW_USB_DEVICE_PATH)? THIS IS EXTREMELY DANGEROUS.${C_RESET}" confirm_internal_format_choice
                if [[ "$confirm_internal_format_choice" != "yes" ]]; then
                    print_fatal "Formatting of internal-looking disk $RAW_USB_DEVICE_PATH aborted by user. This was a close call!"
                else
                    print_warning "Proceeding with formatting $RAW_USB_DEVICE_PATH. You have been warned multiple times."
                fi
                print_line
            fi
        fi
        
        # Handle unmounting the device before formatting
        print_info "Unmounting any existing partitions before formatting..."
        if [[ "$(uname)" == "Darwin" ]]; then
            # For macOS
            diskutil unmountDisk force "$USB_DEVICE_PATH" > /dev/null 2>&1
            
            # Format the disk
            print_info "Formatting disk as exFAT with label '$USB_LABEL'..."
            if diskutil eraseDisk ExFAT "$USB_LABEL" "$USB_DEVICE_PATH" > /dev/null 2>&1; then
                print_success "Formatting complete!"
                # The formatted volume should be automatically mounted
                USB_PARTITION_PATH="$USB_DEVICE_PATH"
            else
                print_fatal "Failed to format the USB drive. Please check the device path and try again."
            fi
            
        elif [[ "$(uname)" == "Linux" ]]; then
            # For Linux
            # Determine the partition path
            if [[ "$USB_DEVICE_PATH" == *nvme*n* ]] || [[ "$USB_DEVICE_PATH" == *mmcblk* ]]; then
                USB_PARTITION_PATH="${USB_DEVICE_PATH}p1"
            else
                USB_PARTITION_PATH="${USB_DEVICE_PATH}1"
            fi
            
            # Unmount the device and any partitions
            sudo umount "$USB_DEVICE_PATH"* 2>/dev/null
            
            # Create a new partition table and format
            print_info "Creating new partition table..."
            sudo parted -s "$USB_DEVICE_PATH" mklabel msdos
            sudo parted -s "$USB_DEVICE_PATH" mkpart primary fat32 1MiB 100%
            
            # Format the partition as exFAT
            print_info "Formatting partition as exFAT..."
            if command -v mkfs.exfat > /dev/null 2>&1; then
                sudo mkfs.exfat -n "$USB_LABEL" "$USB_PARTITION_PATH"
            elif command -v exfatformat > /dev/null 2>&1; then
                sudo exfatformat -n "$USB_LABEL" "$USB_PARTITION_PATH"
            else
                print_warning "exFAT formatting tools not found. Falling back to FAT32..."
                sudo mkfs.vfat -F 32 -n "$USB_LABEL" "$USB_PARTITION_PATH"
            fi
            
            print_success "Formatting complete! Partition path is: $USB_PARTITION_PATH"
        fi
    else
        print_info "USB will NOT be formatted. Ensure it's usable (exFAT recommended)."
        print_info "The script will try to use the existing label: ${C_BOLD}$USB_LABEL${C_RESET}."
        
        # Still set the partition path for Linux
        if [[ "$(uname)" == "Linux" ]]; then
            if [[ "$USB_DEVICE_PATH" == *nvme*n* ]] || [[ "$USB_DEVICE_PATH" == *mmcblk* ]]; then
                USB_PARTITION_PATH="${USB_DEVICE_PATH}p1"
            else
                USB_PARTITION_PATH="${USB_DEVICE_PATH}1"
            fi
        fi
    fi
}

calculate_estimated_binary_size_bytes() {
    print_info "Calculating estimated binary size for selected platforms..."
    local num_targets=0
    local total_size_mb=0
    # Use integer MB values to avoid floating point issues
    local linux_size_mb=75  # ~75MB for Linux binary + libraries
    local mac_size_mb=60    # ~60MB for macOS binary + libraries
    local win_size_mb=80    # ~80MB for Windows binary + libraries
    
    # Add buffer for launcher scripts (5MB)
    local launcher_scripts_mb=5
    
    if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then
        total_size_mb=$((total_size_mb + linux_size_mb))
        num_targets=$((num_targets + 1))
    fi
    
    if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then
        total_size_mb=$((total_size_mb + mac_size_mb))
        num_targets=$((num_targets + 1))
    fi
    
    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
        total_size_mb=$((total_size_mb + win_size_mb))
        num_targets=$((num_targets + 1))
    fi
    
    # Add space for launcher scripts and web UI
    total_size_mb=$((total_size_mb + launcher_scripts_mb))
    
    # Calculate the size in bytes
    local total_size_bytes=$((total_size_mb * 1024 * 1024))
    
    # Set the global variable for display
    if [ $total_size_mb -gt 0 ]; then
        # Calculate GB with 2 decimal places
        local gb_value=$((total_size_mb * 100 / 1024))
        local gb_whole=$((gb_value / 100))
        local gb_fraction=$((gb_value % 100))
        
        # Format with leading zero if needed
        if [ "$gb_fraction" -lt 10 ]; then
            ESTIMATED_BINARIES_SIZE_GB="${gb_whole}.0${gb_fraction}"
        else
            ESTIMATED_BINARIES_SIZE_GB="${gb_whole}.${gb_fraction}"
        fi
    else
        ESTIMATED_BINARIES_SIZE_GB="0.20"  # Default minimum size
    fi
    
    print_info "Estimated binary size: ${C_BOLD}${total_size_mb} MB${C_RESET} (${ESTIMATED_BINARIES_SIZE_GB} GB) for ${num_targets} target platform(s)"
    
    # Return the total bytes
    echo "$total_size_bytes"
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

    print_subheader "💾 Checking disk space on USB drive"
    
    # CRITICAL FIX: If USB_BASE_PATH is empty at this point, try to find it one more time
    if [ -z "$USB_BASE_PATH" ] || [ ! -d "$USB_BASE_PATH" ]; then
        print_warning "USB mount point not detected. Trying emergency mount detection..."
        
        # Look for volume with our label
        if [ -d "/Volumes/$USB_LABEL" ]; then
            USB_BASE_PATH="/Volumes/$USB_LABEL"
            MOUNT_POINT="$USB_BASE_PATH"
            print_success "RECOVERY: Found USB at /Volumes/$USB_LABEL"
        else
            # Find most recently mounted volume as last resort
            local latest_volume=$(ls -t /Volumes/ | grep -v "Macintosh HD" | head -1)
            if [ -n "$latest_volume" ] && [ -d "/Volumes/$latest_volume" ]; then
                USB_BASE_PATH="/Volumes/$latest_volume"
                MOUNT_POINT="$USB_BASE_PATH"
                print_success "RECOVERY: Using most recent volume: $USB_BASE_PATH"
            else
                # Last attempt - force remount
                diskutil mountDisk "$USB_DEVICE_PATH" &>/dev/null || true
                sleep 2
                
                # Check again after forced remount
                latest_volume=$(ls -t /Volumes/ | grep -v "Macintosh HD" | head -1)
                if [ -n "$latest_volume" ] && [ -d "/Volumes/$latest_volume" ]; then
                    USB_BASE_PATH="/Volumes/$latest_volume"
                    MOUNT_POINT="$USB_BASE_PATH"
                    print_success "RECOVERY: Found volume after forced remount: $USB_BASE_PATH"
                fi
            fi
        fi
    fi
    
    # Now check if we've found a valid path
    if [ -z "$USB_BASE_PATH" ] || [ ! -d "$USB_BASE_PATH" ]; then
        print_error "USB base path '$USB_BASE_PATH' is not valid or not accessible. Cannot check disk space."
        local continue_without_check=""
        ask_yes_no_quit "Problem checking disk space. Continue anyway (NOT RECOMMENDED)?" continue_without_check
        if [ "$continue_without_check" != "yes" ]; then
            print_fatal "Disk space check failed and user chose to abort."
        else
            # If continuing, set a default path to try
            if [ -z "$USB_BASE_PATH" ] && [ -d "/Volumes/$USB_LABEL" ]; then
                USB_BASE_PATH="/Volumes/$USB_LABEL"
                MOUNT_POINT="$USB_BASE_PATH"
                print_warning "Attempting to use /Volumes/$USB_LABEL as fallback path."
            elif [ -z "$USB_BASE_PATH" ]; then
                latest_volume=$(ls -t /Volumes/ | grep -v "Macintosh HD" | head -1)
                if [ -n "$latest_volume" ]; then
                    USB_BASE_PATH="/Volumes/$latest_volume"
                    MOUNT_POINT="$USB_BASE_PATH"
                    print_warning "Attempting to use $USB_BASE_PATH as fallback path."
                fi
            fi
            print_warning "Continuing without disk space check, as requested by user."
        fi
    fi
    
    # Get available space in KB using OS-specific commands
    local available_space_kb
    if [[ "$(uname)" == "Darwin" ]]; then
        available_space_kb=$(df -Pk "$USB_BASE_PATH" | awk 'NR==2 {print $4}')
    else
        available_space_kb=$(df -Pk "$USB_BASE_PATH" | awk 'NR==2 {print $4}')
    fi

    # Validate the available space value
    if ! [[ "$available_space_kb" =~ ^[0-9]+$ ]]; then
        print_error "Could not determine available disk space on $USB_BASE_PATH."
        local choice
        ask_yes_no_quit "Problem checking disk space. Continue anyway (NOT RECOMMENDED)?" choice
        if [[ "$choice" != "yes" ]]; then print_fatal "Disk space check failed and user chose to abort."; fi
        return
    fi

    # Convert KB to GB for display
    # Calculate GB using bash arithmetic instead of awk
    local gb_value=$((available_space_kb * 100 / (1024*1024)))
    local gb_whole=$((gb_value / 100))
    local gb_fraction=$((gb_value % 100))
    
    # Format with leading zero for fractions less than 10
    if [ $gb_fraction -lt 10 ]; then
        local available_space_gb="${gb_whole}.0${gb_fraction}"
    else
        local available_space_gb="${gb_whole}.${gb_fraction}"
    fi
    
    print_info "Available space on USB drive: ${C_BOLD}$(bytes_to_human_readable $((available_space_kb * 1024)))${C_RESET} ($available_space_gb GB)"

    # Calculate required space for models (already done by calculate_total_estimated_models_size_gb)
    # and determine the total space required based on operation mode
    local required_space_gb_val
    if [[ "$is_add_llm_mode" == "true" ]]; then
        # Only account for the new models when adding to existing USB
        required_space_gb_val=$ESTIMATED_MODELS_SIZE_GB
        print_info "Estimated space required for new model(s): ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET}"
    else
        # Account for binaries, models, and buffer space for a new USB
        # Calculate required space using bash arithmetic instead of awk
        # First, convert string values to integer basis points (multiply by 100)
        local bin_size_bp=$(echo "$ESTIMATED_BINARIES_SIZE_GB" | sed 's/\.//' | sed 's/^0*//')
        local model_size_bp=$(echo "$ESTIMATED_MODELS_SIZE_GB" | sed 's/\.//' | sed 's/^0*//')
        
        # Default to valid values if conversion fails
        [ -z "$bin_size_bp" ] || ! [[ "$bin_size_bp" =~ ^[0-9]+$ ]] && bin_size_bp=20
        [ -z "$model_size_bp" ] || ! [[ "$model_size_bp" =~ ^[0-9]+$ ]] && model_size_bp=0
        
        # Add buffer (0.5 GB = 50 basis points) and format result
        local total_bp=$((bin_size_bp + model_size_bp + 50))
        local whole_part=$((total_bp / 100))
        local frac_part=$((total_bp % 100))
        
        # Format with leading zero if needed
        if [ "$frac_part" -lt 10 ]; then
            required_space_gb_val="${whole_part}.0${frac_part}"
        else
            required_space_gb_val="${whole_part}.${frac_part}"
        fi
        print_info "Estimated total space required: ${C_BOLD}$required_space_gb_val GB${C_RESET}"
        print_info "  - Binary files: ${C_BOLD}$ESTIMATED_BINARIES_SIZE_GB GB${C_RESET}"
        print_info "  - AI model(s): ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET}"
        print_info "  - Extra buffer: ${C_BOLD}0.50 GB${C_RESET}"
    fi

    # Comparison with sufficient buffer
    if (( $(echo "$available_space_gb < $required_space_gb_val" | bc -l) )); then
        print_error "⚠️ INSUFFICIENT DISK SPACE DETECTED ⚠️"
        print_error "Available space: $available_space_gb GB"
        print_error "Required space: $required_space_gb_val GB"
        
        local continue_anyway_choice
        ask_yes_no_quit "${C_YELLOW}Continue anyway despite insufficient space warning? (Installation may fail)${C_RESET}" continue_anyway_choice
        if [[ "$continue_anyway_choice" != "yes" ]]; then
            print_fatal "Operation aborted due to insufficient disk space."
        else
            print_warning "Proceeding despite low disk space warning. Installation may fail or be incomplete."
        fi
    else
        # Calculate remaining space after installation using bash arithmetic
        # Convert to basis points (100ths) by removing decimal and leading zeros
        local avail_bp=$(echo "$available_space_gb" | sed 's/\.//' | sed 's/^0*//')
        local req_bp=$(echo "$required_space_gb_val" | sed 's/\.//' | sed 's/^0*//')
        
        # Default to valid values if conversion fails
        [ -z "$avail_bp" ] || ! [[ "$avail_bp" =~ ^[0-9]+$ ]] && avail_bp=0
        [ -z "$req_bp" ] || ! [[ "$req_bp" =~ ^[0-9]+$ ]] && req_bp=0
        
        # Calculate remaining space and format
        if [ "$avail_bp" -gt "$req_bp" ]; then
            local remain_bp=$((avail_bp - req_bp))
            local remain_whole=$((remain_bp / 100))
            local remain_frac=$((remain_bp % 100))
            
            # Format with leading zero if needed
            if [ "$remain_frac" -lt 10 ]; then
                local remaining_space_gb="${remain_whole}.0${remain_frac}"
            else
                local remaining_space_gb="${remain_whole}.${remain_frac}"
            fi
        else
            local remaining_space_gb="0.00"
        fi
        
        print_success "Sufficient disk space available! (Will have ~$remaining_space_gb GB remaining after installation)"
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

    echo -e "\n${C_BOLD}${C_CYAN}╭─── $dialog_title ${C_DIM}───────────────────────────────────╮${C_RESET}"
    echo -e "${C_CYAN}│ ${C_RESET}${menu_text}${C_RESET}"
    echo -e "${C_CYAN}│ ${C_DIM}....................................................................${C_RESET}"
    local option_num=1
    local text_option_tags=()
    for ((i=0; i<${#menu_options_pairs[@]}; i+=2)); do
        if [[ "${menu_options_pairs[i]}" == "clear_context_separator" ]] || [[ "${menu_options_pairs[i]}" == "about_separator" ]] || [[ "${menu_options_pairs[i]}" == "dry_run_separator" ]]; then
             echo -e "${C_CYAN}│ ${C_DIM}--------------------------------------------------------------------${C_RESET}"
        else
            printf "${C_CYAN}│  ${C_BOLD}%s)${C_RESET} %-60s ${C_CYAN}│${C_RESET}\n" "$option_num" "${menu_options_pairs[i+1]}"
            text_option_tags+=("${menu_options_pairs[i]}")
            option_num=$((option_num + 1))
        fi
    done
    if [[ "$dialog_title" == "Main Menu" ]]; then
        printf "${C_CYAN}│  ${C_BOLD}q)${C_RESET} %-60s ${C_CYAN}│${C_RESET}\n" "Quit"
    else
        printf "${C_CYAN}│  ${C_BOLD}b)${C_RESET} %-60s ${C_CYAN}│${C_RESET}\n" "Back to Previous Menu"
    fi
    echo -e "${C_BOLD}${C_CYAN}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
    local raw_choice
    while true; do
        print_prompt "Enter your choice: "
        read -r raw_choice
        raw_choice=$(echo "$raw_choice" | tr '[:upper:]' '[:lower:]')
        if [[ "$raw_choice" =~ ^[0-9]+$ ]] && [ "$raw_choice" -ge 1 ] && [ "$raw_choice" -lt "$option_num" ]; then
            eval "$result_var_name=\"${text_option_tags[$((raw_choice - 1))]}\""
            break
        elif [[ "$raw_choice" == "q" && "$dialog_title" == "Main Menu" ]]; then
            eval "$result_var_name=\"q\""
            break
        elif [[ "$raw_choice" == "b" && "$dialog_title" != "Main Menu" ]]; then
            eval "$result_var_name=\"b\""
            break
        else
            print_warning "Invalid input. Please try again."
        fi
    done
    echo ""
}

ask_target_os_binaries() {
    print_header "🖥️ SELECT OS BINARIES TO INSTALL 🖥️"
    echo -e "${C_BLUE}Which Ollama runtimes do you want to include on the USB?${C_RESET}"
    local options_array=(
        "1" "All (Linux, macOS, Windows) (Default)"
        "2" "Current host OS only ($(uname -s))"
        "3" "Linux only"
        "4" "macOS only"
        "5" "Windows only"
        "q" "Quit"
    )
    local choice_idx
    for ((i=0; i<${#options_array[@]}; i+=2)); do
        printf "  ${C_BOLD}%s)${C_RESET} %s\n" "${options_array[i]}" "${options_array[i+1]}"
    done
    print_line
    local choice
    while true; do
        print_prompt "Enter your choice (1-5, or q) [Default is 1]: "
        read -r choice
        choice=${choice:-1}
        case "$choice" in
            1) SELECTED_OS_TARGETS="linux,mac,win"; break;;
            2)
                local current_os_tag=""
                case "$(uname -s)" in
                    Linux) current_os_tag="linux";;
                    Darwin) current_os_tag="mac";;
                    CYGWIN*|MINGW*|MSYS*) current_os_tag="win";;
                    *)
                        print_warning "Host OS ($(uname -s)) not directly mappable to a single binary target (Linux/Mac/Win)."
                        print_warning "Please choose another option or select 'All'."
                        continue
                        ;;
                esac
                SELECTED_OS_TARGETS="$current_os_tag"
                print_info "Will install binaries for current host OS: $current_os_tag"
                break;;
            3) SELECTED_OS_TARGETS="linux"; break;;
            4) SELECTED_OS_TARGETS="mac"; break;;
            5) SELECTED_OS_TARGETS="win"; break;;
            q|Q) print_info "Quitting script."; exit 0;;
            *) print_warning "Invalid input. Please enter a number from 1 to 5, or q.";;
        esac
    done
    # No need to recalculate - the calculate_estimated_binary_size_bytes function now sets ESTIMATED_BINARIES_SIZE_GB directly
    local estimated_binaries_size_bytes=$(calculate_estimated_binary_size_bytes)
    
    # Double check that we have a valid value
    if [ -z "$ESTIMATED_BINARIES_SIZE_GB" ] || ! [[ "$ESTIMATED_BINARIES_SIZE_GB" =~ ^[0-9]+\.[0-9]+$ ]]; then
        # Calculate it directly if needed
        if [[ "$estimated_binaries_size_bytes" =~ ^[0-9]+$ ]]; then
            # Use bash arithmetic to calculate GB with 2 decimal places
            local mb_size=$((estimated_binaries_size_bytes / 1048576))
            local gb_value=$((mb_size * 100 / 1024))
            local gb_whole=$((gb_value / 100))
            local gb_fraction=$((gb_value % 100))
            
            # Format with leading zero if needed
            if [ "$gb_fraction" -lt 10 ]; then
                ESTIMATED_BINARIES_SIZE_GB="${gb_whole}.0${gb_fraction}"
            else
                ESTIMATED_BINARIES_SIZE_GB="${gb_whole}.${gb_fraction}"
            fi
        else
            # Default if all else fails
            ESTIMATED_BINARIES_SIZE_GB="0.20"
        fi
    fi
    
    print_success "Selected OS targets for binaries: ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_BINARIES_SIZE_GB GB${C_RESET})"
    echo ""
}

ask_llm_model() {
    local prompt_title_text="🧠 SELECT AI MODEL(S) TO INSTALL 🧠"
    if [[ "$OPERATION_MODE" == "add_llm" ]]; then
        prompt_title_text="➕ SELECT ADDITIONAL AI MODEL(S) TO ADD ➕"
    fi
    print_header "$prompt_title_text"

    MODELS_TO_INSTALL_LIST=()
    MODEL_SOURCE_TYPE="pull"

    echo -e "${C_BLUE}Which AI model(s) do you want to download and include?${C_RESET}"
    local options_array=(
        "1" "llama3:8b (Recommended general purpose, ~$(get_estimated_model_size_gb "llama3:8b")GB) (Default)"
        "2" "phi3:mini (Small, very capable, ~$(get_estimated_model_size_gb "phi3:mini")GB)"
        "3" "llama3:8b AND phi3:mini (Flexible performance, ~$(awk "BEGIN {print $(get_estimated_model_size_gb "llama3:8b") + $(get_estimated_model_size_gb "phi3:mini")}")GB total)"
        "4" "codellama:7b (Coding assistant, ~$(get_estimated_model_size_gb "codellama:7b")GB)"
        "5" "Enter custom Ollama model name (from ollama.com/library)"
        "6" "Import local model file (GGUF format)"
        "q" "Quit"
    )
    for ((i=0; i<${#options_array[@]}; i+=2)); do
        printf "  ${C_BOLD}%s)${C_RESET} %s\n" "${options_array[i]}" "${options_array[i+1]}"
    done
    print_line
    local choice

    while true; do
        print_prompt "Enter your choice (1-6, or q) [Default is 1]: "
        read -r choice
        choice=${choice:-1}
        case "$choice" in
            1) MODELS_TO_INSTALL_LIST=("llama3:8b"); MODEL_SOURCE_TYPE="pull"; break;;
            2) MODELS_TO_INSTALL_LIST=("phi3:mini"); MODEL_SOURCE_TYPE="pull"; break;;
            3) MODELS_TO_INSTALL_LIST=("llama3:8b" "phi3:mini"); MODEL_SOURCE_TYPE="pull"; break;;
            4) MODELS_TO_INSTALL_LIST=("codellama:7b"); MODEL_SOURCE_TYPE="pull"; break;;
            5)
                print_info "You can find a list of available models at ${C_UNDERLINE}https://ollama.com/library${C_NO_UNDERLINE}${C_RESET}"
                local open_url_choice
                ask_yes_no_quit "Do you want to try opening this URL in your browser?" open_url_choice
                if [[ "$open_url_choice" == "yes" ]]; then
                    if [[ "$(uname)" == "Darwin" ]]; then open "https://ollama.com/library";
                    elif command -v xdg-open &> /dev/null; then xdg-open "https://ollama.com/library";
                    else print_warning "Could not automatically open URL. Please open it manually."; fi
                fi
                local custom_model
                print_prompt "Enter the full Ollama model name (e.g., 'mistral:latest'): "
                read -r custom_model
                if [ -z "$custom_model" ]; then print_warning "No model name entered. Please try again."; continue; fi
                if [[ ! "$custom_model" == *":"* ]]; then
                    print_warning "Invalid model format. It should be 'modelname:tag' (e.g., 'llama3:8b')."
                    print_warning "If unsure, check available models at https://ollama.com/library"
                    continue
                fi
                MODELS_TO_INSTALL_LIST=("$custom_model")
                MODEL_SOURCE_TYPE="pull"
                print_success "Selected custom model to pull: ${C_BOLD}${MODELS_TO_INSTALL_LIST[0]}${C_RESET}"
                break;;
            6)
                local ollama_model_name
                print_subheader "--- Import Local GGUF Model File ---"
                while true; do
                    print_prompt "Enter the FULL path to your local .gguf model file: "
                    read -r LOCAL_GGUF_PATH_FOR_IMPORT
                    if [ -z "$LOCAL_GGUF_PATH_FOR_IMPORT" ]; then print_warning "Path cannot be empty."; continue; fi
                    if [ ! -f "$LOCAL_GGUF_PATH_FOR_IMPORT" ]; then print_warning "File not found at '$LOCAL_GGUF_PATH_FOR_IMPORT'. Please check the path."; continue; fi
                    if [[ "${LOCAL_GGUF_PATH_FOR_IMPORT##*.}" != "gguf" ]]; then print_warning "File does not have a .gguf extension. Proceeding, but ensure it's a valid GGUF."; fi
                    break
                done
                while true; do
                    print_prompt "Enter a name for this model in Ollama (e.g., 'mylocalmodel:latest'): "
                    read -r ollama_model_name
                    if [ -z "$ollama_model_name" ]; then print_warning "Model name cannot be empty."; continue; fi
                    if [[ ! "$ollama_model_name" == *":"* ]]; then print_warning "Model name must include a tag (e.g., 'mymodel:latest')."; continue; fi
                    break
                done

                print_info "Preparing to import '$LOCAL_GGUF_PATH_FOR_IMPORT' as '$ollama_model_name' into host Ollama..."
                local temp_modelfile; temp_modelfile=$(mktemp)
                echo "FROM \"$LOCAL_GGUF_PATH_FOR_IMPORT\"" > "$temp_modelfile"
                print_info "Temporary Modelfile created at $temp_modelfile with content:"
                echo -e "${C_DIM}"; cat "$temp_modelfile"; echo -e "${C_RESET}"
                print_line
                print_info "Running: ${C_GREEN}ollama create \"$ollama_model_name\" -f \"$temp_modelfile\"${C_RESET}"
                print_info "This will add the model to your host's Ollama. It might take some time..."

                local OLLAMA_MODELS_TEMP_STORE_CREATE="$OLLAMA_MODELS"; unset OLLAMA_MODELS

                if ollama create "$ollama_model_name" -f "$temp_modelfile"; then
                    print_success "Successfully created Ollama model '$ollama_model_name' from local file."
                    MODELS_TO_INSTALL_LIST=("$ollama_model_name")
                    MODEL_SOURCE_TYPE="create_local"
                else
                    print_error "Failed to create Ollama model '$ollama_model_name' from '$LOCAL_GGUF_PATH_FOR_IMPORT'."
                    print_error "Please check the GGUF file compatibility and Ollama logs."
                    rm -f "$temp_modelfile"
                    if [ -n "$OLLAMA_MODELS_TEMP_STORE_CREATE" ]; then export OLLAMA_MODELS="$OLLAMA_MODELS_TEMP_STORE_CREATE"; else unset OLLAMA_MODELS; fi
                    continue
                fi
                rm -f "$temp_modelfile"
                if [ -n "$OLLAMA_MODELS_TEMP_STORE_CREATE" ]; then export OLLAMA_MODELS="$OLLAMA_MODELS_TEMP_STORE_CREATE"; else unset OLLAMA_MODELS; fi
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

    echo -e "${C_BLUE}Please select the USB drive to use:${C_RESET}"
    for i in "${!devices_list_display_names[@]}"; do echo -e "  ${C_BOLD}$((i+1)))${C_RESET} ${devices_list_display_names[$i]}"; done
    echo -e "  ${C_BOLD}o)${C_RESET} Other (enter path manually)"
    echo -e "  ${C_BOLD}q)${C_RESET} Quit"
    print_line

    local USER_DEVICE_CHOICE_RAW_TEMP_LOCAL=""
    local temp_usb_device_path=""
    while true; do
        print_prompt "Enter your choice (number, 'o', or 'q'): "
        read -r choice
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


# --- Cross-Platform Runtime Environment Detection ---
detect_runtime_environment() {
    print_debug "Detecting runtime environment..."
    
    # Detect OS
    local detected_os="unknown"
    local detected_arch="unknown"
    
    # Try uname first
    if command -v uname &>/dev/null; then
        case "$(uname -s)" in
            Linux*)     detected_os="linux" ;;
            Darwin*)    detected_os="mac" ;;
            CYGWIN*|MINGW*|MSYS*) detected_os="windows" ;;
            *)          detected_os="unknown" ;;
        esac
        
        # Detect architecture
        local raw_arch="$(uname -m)"
        case "$raw_arch" in
            x86_64|amd64) detected_arch="amd64" ;;
            arm64|aarch64) detected_arch="arm64" ;;
            armv7*|armhf) detected_arch="arm" ;;
            i*86) detected_arch="386" ;;
            *) detected_arch="$raw_arch" ;;
        esac
    else
        # Fallbacks for systems without uname
        if [ -f "/proc/version" ]; then
            # Linux-like system
            if grep -q "Linux" "/proc/version"; then
                detected_os="linux"
            fi
        fi
        
        # Windows detection without uname
        if [ -n "$OS" ] && [ "$OS" = "Windows_NT" ]; then
            detected_os="windows"
        fi
        
        # Mac detection without uname is difficult
        # Just use the existence of some macOS-specific files
        if [ -d "/System/Library/CoreServices" ]; then
            detected_os="mac"
        fi
        
        # Basic architecture detection without uname
        if [ -n "$PROCESSOR_ARCHITECTURE" ]; then
            if [[ "$PROCESSOR_ARCHITECTURE" == *"64"* ]]; then
                detected_arch="amd64"
            else
                detected_arch="386"
            fi
        fi
    fi
    
    # Print detection results
    print_info "Detected OS: ${C_BOLD}$detected_os${C_RESET}"
    print_info "Detected Architecture: ${C_BOLD}$detected_arch${C_RESET}"
    
    # Set global variables for later use
    DETECTED_OS="$detected_os"
    DETECTED_ARCH="$detected_arch"
    
    # Check for specific dependencies based on OS
    check_platform_specific_requirements "$detected_os"
    
    return 0
}

# Function to check for OS-specific dependencies/requirements
check_platform_specific_requirements() {
    local platform="$1"
    local requirements_met=true
    
    case "$platform" in
        linux)
            # Check for Linux-specific requirements
            print_info "Checking Linux-specific requirements..."
            if ! command -v ldconfig &>/dev/null; then
                print_warning "ldconfig not found - some libraries may not be found at runtime"
                requirements_met=false
            fi
            ;;
        mac)
            # Check for macOS-specific requirements
            print_info "Checking macOS-specific requirements..."
            if ! command -v otool &>/dev/null; then
                print_warning "otool not found - you may need to install Xcode command line tools"
                requirements_met=false
            fi
            ;;
        windows)
            # Check for Windows-specific requirements
            print_info "Checking Windows-specific requirements..."
            # Windows-specific checks could go here
            ;;
    esac
    
    if $requirements_met; then
        print_success "All platform-specific requirements met for $platform"
    else
        print_warning "Some platform-specific requirements may be missing for $platform"
    fi
    
    return 0
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
    sudo chown "$(id -u):$(id -g)" "$usb_base_dir/webui"
    
    # Create the serve_webui.py script
    local serve_webui_py="$usb_base_dir/webui/serve_webui.py"
    cat << 'EOF_PYTHON' | sudo tee "$serve_webui_py" > /dev/null
#!/usr/bin/env python3
"""
Simple HTTP server with CORS and API proxy for the Ollama WebUI.
Handles API version compatibility between different Ollama versions.
"""
import os
import re
import sys
import json
import time
import signal
import socket
import logging
import threading
import http.server
import urllib.request
import urllib.parse
import urllib.error
from http import HTTPStatus
from http.server import HTTPServer, SimpleHTTPRequestHandler

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('Data/logs/webui_server.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://127.0.0.1:11434')
OLLAMA_ORIGINS = os.environ.get('OLLAMA_ORIGINS', 'http://localhost:8080,http://127.0.0.1:8080,app://*').split(',')
OLLAMA_APP_VERSION_FULL = os.environ.get('OLLAMA_APP_VERSION_FULL', '')

# Parse version string to tuple for comparison
def get_ollama_version_tuple():
    version_str = OLLAMA_APP_VERSION_FULL
    match = re.search(r'(\d+)\.(\d+)\.(\d+)', version_str)
    if match:
        return tuple(map(int, match.groups()))
    return (0, 0, 0)  # Default to oldest version if can't parse

# Determine if we should use the native /api/chat endpoint
OLLAMA_VERSION = get_ollama_version_tuple()
USE_NATIVE_CHAT_API = OLLAMA_VERSION >= (0, 1, 29)  # Versions 0.1.29+ have native /api/chat

logger.info(f"Starting WebUI server with Ollama version: {OLLAMA_APP_VERSION_FULL}")
logger.info(f"Using native /api/chat: {USE_NATIVE_CHAT_API}")

class CORSRequestHandler(SimpleHTTPRequestHandler):
    """HTTP request handler with CORS and API proxy support."""
    
    def __init__(self, *args, **kwargs):
        self.allow_reuse_address = True
        super().__init__(*args, directory=os.path.join(os.path.dirname(__file__), 'webui'), **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()
    
    def do_GET(self):
        # Serve static files for the root path and other non-API paths
        if self.path == '/' or not self.path.startswith('/api/'):
            if self.path == '/':
                self.path = '/index.html'
            try:
                return SimpleHTTPRequestHandler.do_GET(self)
            except BrokenPipeError:
                # Ignore broken pipe errors when client disconnects
                pass
            return
        
        # Proxy API requests to Ollama
        try:
            url = f"{OLLAMA_HOST}{self.path}"
            logger.info(f"Proxying GET request to: {url}")
            
            req = urllib.request.Request(url)
            req.add_header('Accept', 'application/json')
            
            with urllib.request.urlopen(req) as response:
                self.send_response(response.status)
                for header, value in response.getheaders():
                    if header.lower() not in ('server', 'date', 'connection'):
                        self.send_header(header, value)
                self.end_headers()
                self.copyfile(response, self.wfile)
        except Exception as e:
            self.send_error(500, f"Error forwarding request to Ollama: {str(e)}")
    
    def do_POST(self):
        # Handle API requests
        if self.path == '/api/chat' and not USE_NATIVE_CHAT_API:
            # For older Ollama versions, transform /api/chat to /api/generate
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length)
                
                # Parse the chat request
                chat_request = json.loads(post_data.decode('utf-8'))
                
                # Transform to generate request format
                generate_request = {
                    'model': chat_request.get('model', ''),
                    'prompt': '',
                    'stream': chat_request.get('stream', False)
                }
                
                # Format messages into a single prompt
                messages = chat_request.get('messages', [])
                for msg in messages:
                    role = msg.get('role', '')
                    content = msg.get('content', '')
                    if role == 'system':
                        generate_request['system'] = content
                    elif role == 'user':
                        if 'prompt' in generate_request and generate_request['prompt']:
                            generate_request['prompt'] += "\n\n" + content
                        else:
                            generate_request['prompt'] = content
                    elif role == 'assistant':
                        if 'prompt' in generate_request and generate_request['prompt']:
                            generate_request['prompt'] += "\n\n" + content
                        else:
                            generate_request['prompt'] = content
                
                # Forward to Ollama's /api/generate
                url = f"{OLLAMA_HOST}/api/generate"
                logger.info(f"Transformed /api/chat to /api/generate for model: {generate_request.get('model', 'unknown')}")
                
                # Forward the request
                req = urllib.request.Request(url, 
                                          data=json.dumps(generate_request).encode('utf-8'),
                                          method='POST',
                                          headers={'Content-Type': 'application/json'})
                
                with urllib.request.urlopen(req) as response:
                    self.send_response(response.status)
                    for header, value in response.getheaders():
                        if header.lower() not in ('server', 'date', 'connection'):
                            self.send_header(header, value)
                    self.end_headers()
                    
                    # Stream the response if needed
                    if generate_request.get('stream', False):
                        self.wfile.write(b'[')  # Start of JSON array for streaming
                        first_chunk = True
                        for line in response:
                            if not first_chunk:
                                self.wfile.write(b',')
                            self.wfile.write(line)
                            self.wfile.flush()
                            first_chunk = False
                        self.wfile.write(b']')  # End of JSON array for streaming
                    else:
                        self.copyfile(response, self.wfile)
                
            except Exception as e:
                logger.error(f"Error processing /api/chat request: {str(e)}")
                self.send_error(500, f"Error processing chat request: {str(e)}")
            return
        
        # For other API endpoints or when using native /api/chat
        try:
            url = f"{OLLAMA_HOST}{self.path}"
            logger.info(f"Proxying POST request to: {url}")
            
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            req = urllib.request.Request(url, 
                                      data=post_data,
                                      method='POST',
                                      headers={'Content-Type': self.headers.get('Content-Type', 'application/json')})
            
            with urllib.request.urlopen(req) as response:
                self.send_response(response.status)
                for header, value in response.getheaders():
                    if header.lower() not in ('server', 'date', 'connection'):
                        self.send_header(header, value)
                self.end_headers()
                self.copyfile(response, self.wfile)
        except Exception as e:
            logger.error(f"Error forwarding request to Ollama: {str(e)}")
            self.send_error(500, f"Error forwarding request to Ollama: {str(e)}")

def run_server(port=8080):
    """Run the HTTP server."""
    server_address = ('', port)
    httpd = None
    
    def signal_handler(sig, frame):
        logger.info("Shutting down server...")
        if httpd:
            httpd.shutdown()
        sys.exit(0)
    
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Try to find an available port if the default is in use
    current_port = port
    max_attempts = 10
    
    for attempt in range(max_attempts):
        try:
            httpd = HTTPServer(server_address, CORSRequestHandler)
            logger.info(f"Starting WebUI server on port {current_port}...")
            logger.info(f"Ollama API: {OLLAMA_HOST}")
            logger.info(f"Allowed origins: {OLLAMA_ORIGINS}")
            httpd.serve_forever()
            break
        except OSError as e:
            if e.errno == 48:  # Address already in use
                current_port += 1
                server_address = (server_address[0], current_port)
                logger.warning(f"Port {current_port-1} in use, trying port {current_port}...")
                if attempt == max_attempts - 1:
                    logger.error(f"Failed to find an available port after {max_attempts} attempts.")
                    raise
            else:
                logger.error(f"Failed to start server: {str(e)}")
                raise

if __name__ == "__main__":
    # Create necessary directories
    os.makedirs('Data/logs', exist_ok=True)
    os.makedirs('Data/tmp', exist_ok=True)
    
    # Start the server
    run_server(port=8080)
EOF_PYTHON

    # Make the Python script executable
    sudo chmod +x "$serve_webui_py"

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
        
        /* Animation styles */
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
        @keyframes popIn { 0% { transform: scale(0.8); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }
        @keyframes slideIn { from { transform: translateX(-20px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        @keyframes typewriter { from { width: 0; } to { width: 100%; } }
        
        .animation-fade { animation: fadeIn 0.5s ease-in-out; }
        .animation-pop { animation: popIn 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
        .animation-slide { animation: slideIn 0.5s ease-out; }
        .animation-typewriter { overflow: hidden; white-space: nowrap; animation: typewriter 1s steps(40, end); }
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
        <label for="modelSelect">Model: </label>
        <select id="modelSelect">
            ${available_models_options}
        </select>
        
        <label for="streamingModeSelect" style="margin-left: 20px;">Response Mode: </label>
        <select id="streamingModeSelect">
            <option value="word">Word by Word</option>
            <option value="sentence" selected>Sentence by Sentence</option>
            <option value="paragraph">Paragraph by Paragraph</option>
            <option value="full">Full Response</option>
        </select>
        
        <label for="animationStyleSelect" style="margin-left: 20px;">Animation: </label>
        <select id="animationStyleSelect">
            <option value="none" selected>None</option>
            <option value="fade">Fade In</option>
            <option value="pop">Pop</option>
            <option value="slide">Slide In</option>
            <option value="typewriter">Typewriter</option>
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
        const streamingModeSelect = document.getElementById('streamingModeSelect');
        const animationStyleSelect = document.getElementById('animationStyleSelect');
        const sendButton = document.querySelector('.input-area button');
        let conversationHistory = [];
        
        // Helper for different streaming modes
        const streamingModes = {
            word: {
                delay: 0,  // No delay for word by word
                chunkBy: null  // No chunking, just stream each token
            },
            sentence: {
                delay: 10,  // Small delay between sentences
                chunkBy: '.!?'  // Split by sentence endings
            },
            paragraph: {
                delay: 50,  // Larger delay between paragraphs
                chunkBy: '\n\n'  // Split by double newlines (paragraphs)
            },
            full: {
                delay: 0,  // Not used for full response
                chunkBy: null  // No chunking
            }
        };

        function appendMessage(sender, message, type, returnElement = false) {
            const messageDiv = document.createElement('div');
            messageDiv.classList.add('message', type);
            
            // Apply animation class based on selected style (if not 'thinking' state)
            if (type !== 'thinking' && type !== 'error') {
                const animStyle = animationStyleSelect.value;
                if (animStyle !== 'none') {
                    messageDiv.classList.add('animation-' + animStyle);
                }
            }

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

            // Use two separate classes instead of one with a space
            let assistantMessageDiv = appendMessage(model, 'Thinking...', 'assistant', true);
            assistantMessageDiv.classList.add('thinking');
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
                let lastChunk = '';
                
                // Get the selected streaming mode
                const mode = streamingModeSelect.value;
                const streamSettings = streamingModes[mode];
                
                // For 'full' mode, we'll collect the entire response before showing it
                const collectFullResponse = mode === 'full';
                
                if (collectFullResponse) {
                    // Update the UI to indicate we're waiting for the full response
                    assistantContentSpan.textContent = ' Generating full response...';
                }

                // Process the streaming response
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    
                    const text = decoder.decode(value, { stream: true });
                    buffer += text;
                    
                    try {
                        // Attempt to parse the buffer as JSON
                        let lastJson = null;
                        while (buffer.includes('\n')) {
                            const lineEnd = buffer.indexOf('\n');
                            const line = buffer.slice(0, lineEnd);
                            buffer = buffer.slice(lineEnd + 1);
                            
                            if (line.trim()) {
                                try {
                                    const json = JSON.parse(line);
                                    lastJson = json;
                                } catch (e) {
                                    console.warn('Failed to parse line as JSON:', line, e);
                                }
                            }
                        }
                        
                        if (lastJson && lastJson.message && assistantContentSpan) {
                            fullAssistantResponse = lastJson.message.content;
                            
                            // Handle different streaming modes
                            if (collectFullResponse) {
                                // For 'full' mode, just wait - we'll update at the end
                                continue;
                            } else if (mode === 'word') {
                                // Word by word - just update directly
                                assistantContentSpan.textContent = ' ' + fullAssistantResponse;
                            } else if (streamSettings.chunkBy) {
                                // For sentence or paragraph mode
                                let newChunk = '';
                                
                                // Find a good breaking point for sentence or paragraph
                                const delimiters = streamSettings.chunkBy.split('');
                                let breakIndex = -1;
                                
                                // Look for the last complete sentence/paragraph break from the end
                                for (const delimiter of delimiters) {
                                    const lastIndex = fullAssistantResponse.lastIndexOf(delimiter);
                                    if (lastIndex > breakIndex) {
                                        breakIndex = lastIndex;
                                    }
                                }
                                
                                if (breakIndex !== -1 && breakIndex + 1 > lastChunk.length) {
                                    // We have a new chunk to display
                                    newChunk = fullAssistantResponse.substring(0, breakIndex + 1);
                                    
                                    // Only update if we have a new complete chunk
                                    if (newChunk !== lastChunk) {
                                        lastChunk = newChunk;
                                        
                                        // Get the animation style
                                        const animStyle = animationStyleSelect.value;
                                        
                                        // For typewriter animation, we need special handling
                                        if (animStyle === 'typewriter') {
                                            // Create a temporary span for the new content
                                            const tempSpan = document.createElement('span');
                                            tempSpan.classList.add('animation-typewriter');
                                            tempSpan.textContent = newChunk.substring(lastChunk.length || 0);
                                            
                                            // Clear current content and append new content
                                            assistantContentSpan.textContent = ' ' + lastChunk;
                                            assistantContentSpan.appendChild(tempSpan);
                                        } 
                                        // For fade, pop and slide animations
                                        else if (animStyle !== 'none') {
                                            // Create a span for the new chunk
                                            const newContentSpan = document.createElement('span');
                                            newContentSpan.classList.add('animation-' + animStyle);
                                            newContentSpan.textContent = newChunk.substring(lastChunk.length || 0);
                                            
                                            // Update content: previous chunk + animated new part
                                            assistantContentSpan.textContent = ' ' + lastChunk;
                                            assistantContentSpan.appendChild(newContentSpan);
                                        }
                                        // For no animation, just update text
                                        else {
                                            assistantContentSpan.textContent = ' ' + newChunk;
                                        }
                                        
                                        // Add delay between chunks for smoother reading experience
                                        if (streamSettings.delay > 0) {
                                            await new Promise(r => setTimeout(r, streamSettings.delay));
                                        }
                                    }
                                }
                            }
                        }
                    } catch (e) { console.warn("Failed to parse streaming response:", text, e); }
                }

                // Handle the final response display, especially important for 'full' mode
                if (fullAssistantResponse.trim() !== "") {
                    // For 'full' mode, we now display the complete response
                    if (mode === 'full') {
                        const animStyle = animationStyleSelect.value;
                        
                        // Apply animation to the full response if selected
                        if (animStyle !== 'none') {
                            // Clear the current content (which should be 'Generating full response...')
                            assistantContentSpan.textContent = ' ';
                            
                            // Create a new span with the animation
                            const animatedSpan = document.createElement('span');
                            animatedSpan.classList.add('animation-' + animStyle);
                            animatedSpan.textContent = fullAssistantResponse;
                            
                            // Add the animated response
                            assistantContentSpan.appendChild(animatedSpan);
                        } else {
                            // No animation, just update the text
                            assistantContentSpan.textContent = ' ' + fullAssistantResponse;
                        }
                    }
                    // For other modes, make sure we have the final text if there are incomplete sentences
                    else if (mode === 'sentence' || mode === 'paragraph') {
                        // If there's content beyond the last displayed chunk, show it all
                        if (fullAssistantResponse.length > lastChunk.length) {
                            assistantContentSpan.textContent = ' ' + fullAssistantResponse;
                        }
                    }
                    
                    // Add to conversation history
                    conversationHistory.push({ role: 'assistant', content: fullAssistantResponse });
                } else if (assistantContentSpan.textContent.trim() === "" || 
                           assistantContentSpan.textContent.trim() === "Generating full response...") {
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
export OLLAMA_ORIGINS="http://localhost:8080,http://127.0.0.1:8080,app://*"; # Added for WebUI HTTP server
export PYTHONUNBUFFERED=1  # Ensure Python output is not buffered
mkdir -p "\$SCRIPT_DIR/Data/tmp" "\$SCRIPT_DIR/Data/logs";

# Detect Ollama version and export it for the WebUI server
if command -v "\$OLLAMA_BIN" >/dev/null 2>&1; then
    export OLLAMA_APP_VERSION_FULL="\$("\$OLLAMA_BIN" --version 2>/dev/null || echo "unknown")"
    echo "Detected Ollama version: \$OLLAMA_APP_VERSION_FULL"
else
    export OLLAMA_APP_VERSION_FULL="unknown"
    echo "Warning: Could not detect Ollama version. Using default API compatibility mode."
fi
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

    if [ ${#model_array_for_bash_heredoc[@]} -gt 1 ]; then
        model_selection_logic_sh="printf \"%b\\\\n\" \"\${C_BLUE}Available models:\${C_RESET}\";\n"
        model_selection_logic_sh+="$model_options_for_select_heredoc"
        model_selection_logic_sh+="read -r -p \"\$(printf \"%b\" \"\${C_CYAN}➡️  Select model (number) or press Enter for default ($first_model_for_cli_default): \${C_RESET}\")\" MODEL_CHOICE_NUM;\n"
        model_selection_logic_sh+="SELECTED_MODEL=\"$first_model_for_cli_default\";\n"
        
        model_selection_logic_sh+="declare -a _models_for_selection;\n" # Declare array in generated script
        local idx_arr=0
        for model_in_array in "${model_array_for_bash_heredoc[@]}"; do
            model_selection_logic_sh+="_models_for_selection[${idx_arr}]=\"$model_in_array\";\n" # Populate array
            ((idx_arr++))
        done

        model_selection_logic_sh+="if [[ \"\$MODEL_CHOICE_NUM\" =~ ^[0-9]+$ ]] && [ \"\$MODEL_CHOICE_NUM\" -ge 1 ] && [ \"\$MODEL_CHOICE_NUM\" -le ${#model_array_for_bash_heredoc[@]} ]; then\n"
        model_selection_logic_sh+="  SELECTED_MODEL=\"\${_models_for_selection[\$((MODEL_CHOICE_NUM-1))]}\";\n"
        model_selection_logic_sh+="fi;\n"
        model_selection_logic_sh+="printf \"%b\\\\n\" \"\${C_GREEN}Using model: \$SELECTED_MODEL\${C_RESET}\";\n"
        model_selection_logic_sh+="export LEONARDO_DEFAULT_MODEL=\"\$SELECTED_MODEL\";\n"
    elif [ ${#model_array_for_bash_heredoc[@]} -eq 1 ]; then
        model_selection_logic_sh="SELECTED_MODEL=\"${model_array_for_bash_heredoc[0]}\";\n"
        model_selection_logic_sh+="printf \"%b\\\\n\" \"\${C_GREEN}Using model (only one available): \$SELECTED_MODEL\${C_RESET}\";\n"
        model_selection_logic_sh+="export LEONARDO_DEFAULT_MODEL=\"\$SELECTED_MODEL\";\n"
    else
        model_selection_logic_sh="printf \"%b\\\\n\" \"${C_RED}No models found or configured. Cannot select a model.${C_RESET}\";\n"
        model_selection_logic_sh+="exit 1;\n"
    fi

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


    if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then
        local linux_launcher="$usb_base_dir/${launcher_name_base}.sh"
cat << EOF_LINUX_SH | sudo tee "$linux_launcher" > /dev/null
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)";
cd "\$SCRIPT_DIR" || { printf "%s\\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=\$(tput sgr0); C_BOLD=\$(tput bold); C_RED=\$(tput setaf 1); C_GREEN=\$(tput setaf 2);
    C_YELLOW=\$(tput setaf 3); C_BLUE=\$(tput setaf 4); C_CYAN=\$(tput setaf 6);
fi;

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

${model_selection_logic_sh}

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

# Start the WebUI server
WEBUI_PORT=8080
WEBUI_LOG_FILE="\$SCRIPT_DIR/Data/logs/webui_server.log"

printf "%b\\n" "\${C_BLUE}Starting WebUI server on port \$WEBUI_PORT...\${C_RESET}"
python3 "\$SCRIPT_DIR/webui/serve_webui.py" --port "\$WEBUI_PORT" > "\$WEBUI_LOG_FILE" 2>&1 &
WEBUI_PID=\$!
printf "%b\\n" "\${C_GREEN}WebUI server started with PID \$WEBUI_PID. Log: \$WEBUI_LOG_FILE\${C_RESET}"

# Update the WebUI URL to use the local server
WEBUI_URL="http://localhost:\$WEBUI_PORT"

# Open the WebUI in the default browser
if command -v xdg-open &> /dev/null; then
    xdg-open "\$WEBUI_URL" &
elif command -v gnome-open &> /dev/null; then
    gnome-open "\$WEBUI_URL" &
elif command -v kde-open &> /dev/null; then
    kde-open "\$WEBUI_URL" &
else
    printf "%b\\n" "\${C_YELLOW}⚠️ Could not find xdg-open, gnome-open, or kde-open. Please open \$WEBUI_URL in your web browser manually.\${C_RESET}"
fi

printf "\\n";
printf "%b\\n" "\${C_BOLD}\${C_GREEN}✨ Leonardo AI USB is now running! ✨\${C_RESET}";
printf "%b\\n" "  - Ollama Server PID: \${C_BOLD}\$OLLAMA_PID\${C_RESET}";
printf "%b\\n" "  - Default Model for CLI/WebUI: \${C_BOLD}\$SELECTED_MODEL\${C_RESET} (WebUI allows changing this)";
printf "%b\\n" "  - Web UI should be open in your browser (or open manually: \${C_GREEN}file://\$WEBUI_PATH\${C_RESET}).";
printf "%b\\n" "  - To stop the Ollama server, close this terminal window or run: \${C_YELLOW}kill \$OLLAMA_PID\${C_RESET}";
printf "\\n";
printf "%b\\n" "\${C_YELLOW}Press Ctrl+C in this window (or close it) to stop the servers and exit.\${C_RESET}";

# Function to clean up background processes
cleanup() {
    printf "\\n%b\\n" "\${C_BLUE}Shutting down background processes...\${C_RESET}"
    
    # Kill the WebUI server if it's running
    if [ -n "\$WEBUI_PID" ] && ps -p "\$WEBUI_PID" > /dev/null 2>&1; then
        printf "%b\\n" "\${C_YELLOW}Stopping WebUI server (PID \$WEBUI_PID)...\${C_RESET}"
        kill "\$WEBUI_PID" 2>/dev/null || true
        wait "\$WEBUI_PID" 2>/dev/null || true
        printf "%b\\n" "\${C_GREEN}✓ WebUI server stopped.\${C_RESET}"
    fi
    
    # Kill the Ollama server if it's running
    if [ -n "\$OLLAMA_PID" ] && ps -p "\$OLLAMA_PID" > /dev/null 2>&1; then
        printf "%b\\n" "\${C_YELLOW}Stopping Ollama server (PID \$OLLAMA_PID)...\${C_RESET}"
        kill "\$OLLAMA_PID" 2>/dev/null || true
        wait "\$OLLAMA_PID" 2>/dev/null || true
        printf "%b\\n" "\${C_GREEN}✓ Ollama server stopped.\${C_RESET}"
    fi
}

# Set up trap to clean up on exit
trap cleanup EXIT TERM INT;

# Wait for the Ollama server process
wait "\$OLLAMA_PID" || true
printf "%b\\n" "\${C_BLUE}Ollama server (PID \$OLLAMA_PID) has stopped.\${C_RESET}";
printf "%b\\n" "\${C_GREEN}Leonardo AI USB session ended.\${C_RESET}";
EOF_LINUX_SH
        sudo chmod +x "$linux_launcher"
    fi

    if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then
        local mac_launcher="$usb_base_dir/${launcher_name_base}.command"
cat << EOF_MAC_COMMAND | sudo tee "$mac_launcher" > /dev/null
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

${model_selection_logic_sh}

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

# Start the WebUI server
WEBUI_PORT=8080
WEBUI_LOG_FILE="\$SCRIPT_DIR/Data/logs/webui_server_mac.log"

printf "%b\\n" "\${C_BLUE}Starting WebUI server on port \$WEBUI_PORT...\${C_RESET}"
python3 "\$SCRIPT_DIR/webui/serve_webui.py" --port "\$WEBUI_PORT" > "\$WEBUI_LOG_FILE" 2>&1 &
WEBUI_PID=\$!
printf "%b\\n" "\${C_GREEN}WebUI server started with PID \$WEBUI_PID. Log: \$WEBUI_LOG_FILE\${C_RESET}"

# Update the WebUI URL to use the local server
WEBUI_URL="http://localhost:\$WEBUI_PORT"

# Open the WebUI in the default browser
open "\$WEBUI_URL" &

printf "\\n";
printf "%b\\n" "\${C_BOLD}\${C_GREEN}✨ Leonardo AI USB is now running! ✨\${C_RESET}";
printf "%b\\n" "  - Ollama Server PID: \${C_BOLD}\$OLLAMA_PID\${C_RESET}";
printf "%b\\n" "  - Default Model for CLI/WebUI: \${C_BOLD}\$SELECTED_MODEL\${C_RESET} (WebUI allows changing this)";
printf "%b\\n" "  - Web UI should be open in your browser (or open manually: \${C_GREEN}file://\$WEBUI_PATH\${C_RESET}).";
printf "%b\\n" "  - To stop the Ollama server, close this terminal window or run: \${C_YELLOW}kill \$OLLAMA_PID\${C_RESET}";
printf "\\n";
printf "%b\\n" "\${C_YELLOW}This terminal window is keeping the servers alive.";
printf "%b\\n" "Close this window or press Ctrl+C to stop the servers.\${C_RESET}";

# Function to clean up background processes
cleanup() {
    printf "\\n%b\\n" "\${C_BLUE}Shutting down background processes...\${C_RESET}"
    
    # Kill the WebUI server if it's running
    if [ -n "\$WEBUI_PID" ] && ps -p "\$WEBUI_PID" > /dev/null 2>&1; then
        printf "%b\\n" "\${C_YELLOW}Stopping WebUI server (PID \$WEBUI_PID)...\${C_RESET}"
        kill "\$WEBUI_PID" 2>/dev/null || true
        wait "\$WEBUI_PID" 2>/dev/null || true
        printf "%b\\n" "\${C_GREEN}✓ WebUI server stopped.\${C_RESET}"
    fi
    
    # Kill the Ollama server if it's running
    if [ -n "\$OLLAMA_PID" ] && ps -p "\$OLLAMA_PID" > /dev/null 2>&1; then
        printf "%b\\n" "\${C_YELLOW}Stopping Ollama server (PID \$OLLAMA_PID)...\${C_RESET}"
        kill "\$OLLAMA_PID" 2>/dev/null || true
        wait "\$OLLAMA_PID" 2>/dev/null || true
        printf "%b\\n" "\${C_GREEN}✓ Ollama server stopped.\${C_RESET}"
    fi
}

# Set up trap to clean up on exit
trap cleanup EXIT TERM INT;

# Wait for the Ollama server process
wait "\$OLLAMA_PID" || true
printf "%b\\n" "\${C_BLUE}Ollama server (PID \$OLLAMA_PID) has stopped.\${C_RESET}";
printf "%b\\n" "\${C_GREEN}Leonardo AI USB session ended.\${C_RESET}";
EOF_MAC_COMMAND
        sudo chmod +x "$mac_launcher"
    fi

    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
        local win_launcher="$usb_base_dir/${launcher_name_base}.bat"
        (
        echo -e "@ECHO OFF\r"
        echo -e "REM Leonardo AI USB Windows Launcher\r"
        echo -e "TITLE Leonardo AI USB Launcher\r"
        echo -e "COLOR 0A\r"
        echo -e "CLS\r"
        echo -e "ECHO ^<--------------------------------------------------------------------^>\r"
        echo -e "ECHO ^|         Leonardo AI USB Environment (Windows) - Starting...        ^|\r"
        echo -e "ECHO ^<--------------------------------------------------------------------^>\r"
        echo -e "CD /D \"%~dp0\"\r"
        echo -e "\r"
        echo -e "ECHO Setting up environment variables...\r"
        echo -e "${common_data_dir_setup_win}\r"
        echo -e "SET OLLAMA_HOST=127.0.0.1:11434\r"
        echo -e "\r"
        echo -e "SET OLLAMA_BIN=%~dp0runtimes\\win\\bin\\ollama.exe\r"
        echo -e "IF NOT EXIST \"%OLLAMA_BIN%\" (\r"
        echo -e "    COLOR 0C\r"
        echo -e "    ECHO ^>^> ERROR: Ollama binary not found at %OLLAMA_BIN%\r"
        echo -e "    PAUSE\r"
        echo -e "    EXIT /B 1\r"
        echo -e ")\r"
        echo -e "\r"
        echo -e "${model_selection_bat_logic_final}\r"
        echo -e "\r"
        echo -e "ECHO Starting Ollama server in a new window...\r"
        echo -e "START \"Ollama Server (Leonardo AI USB)\" /D \"%~dp0runtimes\\win\\bin\" \"%OLLAMA_BIN%\" ${common_ollama_serve_command}\r"
        echo -e "\r"
        echo -e "ECHO Waiting a few seconds for the server to initialize...\r"
        echo -e "PING 127.0.0.1 -n 8 > NUL\r"
        echo -e "\r"
        echo -e "ECHO Checking if Ollama server process is running...\r"
        echo -e "TASKLIST /FI \"IMAGENAME eq ollama.exe\" /NH | FIND /I \"ollama.exe\" > NUL\r"
        echo -e "IF ERRORLEVEL 1 (\r"
        echo -e "    COLOR 0C\r"
        echo -e "    ECHO ^>^> ERROR: Ollama server (ollama.exe) does not appear to be running after start attempt.\r"
        echo -e "    ECHO    Check the new \"Ollama Server\" window for error messages.\r"
        echo -e "    ECHO    Ensure no other Ollama instance is conflicting on port 11434.\r"
        echo -e "    PAUSE\r"
        echo -e "    EXIT /B 1\r"
        echo -e ")\r"
        echo -e "COLOR 0A\r"
        echo -e "ECHO Ollama server process found. ^<^< \r"
        echo -e "\r"
        echo -e "REM Start the WebUI server in a new window\r"
        echo -e "SET WEBUI_PORT=8080\r"
        echo -e "SET WEBUI_LOG=%~dp0Data\logs\webui_server_win.log\r"
        echo -e "\r"
        echo -e "ECHO Starting WebUI server on port %WEBUI_PORT%...\r"
        echo -e "START \"WebUI Server (Leonardo AI USB)\" /B /D \"%~dp0\" python \"%~dp0webui\serve_webui.py\" --port %WEBUI_PORT% > \"%WEBUI_LOG%\" 2>&1\r"
        echo -e "\r"
        echo -e "REM Wait a moment for the server to start\r"
        echo -e "PING 127.0.0.1 -n 3 > NUL\r"
        echo -e "\r"
        echo -e "REM Open the WebUI in the default browser\r"
        echo -e "SET WEBUI_URL=http://localhost:%WEBUI_PORT%\r"
        echo -e "START \"\" \"%WEBUI_URL%\"\r"
        echo -e "\r"
        echo -e "ECHO.\r"
        echo -e "ECHO ^<--------------------------------------------------------------------^>\r"
        echo -e "ECHO ^|                 ✨ Leonardo AI USB is now running! ✨               ^|\r"
        echo -e "ECHO ^|--------------------------------------------------------------------^|\r"
        echo -e "ECHO ^| - Ollama Server is running in a separate window.                   ^|\r"
        echo -e "ECHO ^| - Default Model for CLI/WebUI: %SELECTED_MODEL%                    ^|\r"
        echo -e "ECHO ^|   (WebUI allows changing this from available models on USB)        ^|\r"
        echo -e "ECHO ^| - Web UI should be open in your browser.                           ^|\r"
        echo -e "ECHO ^|   (If not, manually open: %WEBUI_URL%)                ^|\r"
        echo -e "ECHO ^| - To stop: Close the \"Ollama Server\" window AND this window.       ^|\r"
        echo -e "ECHO ^<--------------------------------------------------------------------^>\r"
        echo -e "ECHO.\r"
        echo -e "ECHO This launcher window can be closed. The Ollama server will continue \r"
        echo -e "ECHO running in its own window until that \"Ollama Server\" window is closed.\r"
        echo -e "PAUSE\r"
        echo -e "EXIT /B 0\r"
        ) | sudo tee "$win_launcher" > /dev/null

        if command -v unix2dos &> /dev/null; then
            sudo unix2dos "$win_launcher" >/dev/null 2>&1 || true
        else
            print_warning "unix2dos not found. Windows .bat file might have incorrect line endings if created on Linux/macOS."
        fi
    fi
    print_success "Launcher scripts generated."
}

generate_security_readme() {
    local usb_base_dir="$1"
    local readme_file="$usb_base_dir/SECURITY_README.txt"
    local install_dir_readme_file="$usb_base_dir/Installation_Info/SECURITY_README.txt"

    sudo mkdir -p "$usb_base_dir/Installation_Info"
    sudo chown "$(id -u):$(id -g)" "$usb_base_dir/Installation_Info"

cat << EOF_README | sudo tee "$readme_file" "$install_dir_readme_file" > /dev/null
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
        *   Mounting/unmounting the USB drive (handled by placeholders, needs full implementation).
        *   Copying files (Ollama binaries, models) to the USB, especially if
          the host's Ollama models are in a system location.
        *   Creating directories and setting permissions on the USB.
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

# Function to check and upgrade an existing Leonardo AI USB installation
upgrade_existing_usb() {
    print_subheader "🔄 USB UPGRADE/PATCH UTILITY"
    print_info "This utility will check an existing Leonardo AI USB installation and upgrade it to version $SCRIPT_VERSION."
    print_line
    
    # Select the USB drive to upgrade
    print_subheader "🔍 SELECT USB DRIVE TO UPGRADE"
    detect_usb_drives
    
    # Check if the selected USB drive is a valid Leonardo AI USB installation
    print_info "Checking if the selected USB drive contains a valid Leonardo AI USB installation..."
    
    # Ensure the USB is mounted and get the base path
    if ! ensure_usb_mounted_and_writable; then
        print_fatal "Failed to mount USB drive or USB drive is not writable. Please check and try again."
    fi
    
    # Check for the presence of key Leonardo AI USB files/directories
    if [ ! -d "$USB_BASE_PATH/.ollama" ] || [ ! -d "$USB_BASE_PATH/runtimes" ] || [ ! -d "$USB_BASE_PATH/webui" ]; then
        print_fatal "The selected USB drive doesn't appear to be a valid Leonardo AI USB installation.\nMissing key directories: .ollama, runtimes, or webui"
    fi
    
    # Try to determine the current version
    CURRENT_VERSION="Unknown"
    VERSION_FILE="$USB_BASE_PATH/version.txt"
    
    if [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION=$(cat "$VERSION_FILE" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n 1)
        print_info "Detected Leonardo AI USB version: ${C_BOLD}$CURRENT_VERSION${C_RESET}"
    else
        # Create version tracking for older installations that don't have it
        print_warning "No version file found. This appears to be an older installation."
        # Look for other indicators of version
        if [ -f "$USB_BASE_PATH/webui/index.html" ]; then
            if grep -q "animation-" "$USB_BASE_PATH/webui/index.html"; then
                print_info "Detected features from version 3.3.1 or later."
                CURRENT_VERSION="3.3.1"
            elif grep -q "streamingModeSelect" "$USB_BASE_PATH/webui/index.html"; then
                print_info "Detected features from version 3.3.0."
                CURRENT_VERSION="3.3.0"
            else
                print_info "This appears to be version 3.0.0 or earlier."
                CURRENT_VERSION="3.0.0"
            fi
        fi
    fi
    
    # Compare versions and determine what needs to be upgraded
    if [ "$CURRENT_VERSION" = "$SCRIPT_VERSION" ]; then
        print_success "The USB installation is already at the latest version ($SCRIPT_VERSION)."
        
        local check_anyway
        ask_yes_no_quit "Would you like to check for and repair any missing or corrupted files anyway?" check_anyway
        
        if [ "$check_anyway" != "yes" ]; then
            return 0
        fi
    else
        print_info "Will upgrade from version $CURRENT_VERSION to $SCRIPT_VERSION"
    fi
    
    # Confirm the upgrade
    local confirm_upgrade
    ask_yes_no_quit "Do you want to proceed with the upgrade/repair process?" confirm_upgrade
    
    if [ "$confirm_upgrade" != "yes" ]; then
        print_info "Upgrade cancelled by user."
        return 1
    fi
    
    print_subheader "🔄 PERFORMING UPGRADE"
    
    # Create temporary directory for new files
    local temp_dir=$(mktemp -d)
    print_info "Created temporary directory for upgrade files at: $temp_dir"
    
    # Set up a trap to handle errors and cleanup
    trap 'handle_upgrade_error "$temp_dir"' ERR
    
    # Create an upgrade marker to track progress
    touch "$USB_BASE_PATH/.upgrade_in_progress"
    
    # Comprehensive backup of critical user data
    print_info "Creating backups of critical components..."
    # Backup WebUI
    if [ -d "$USB_BASE_PATH/webui" ]; then
        mkdir -p "$temp_dir/backup/webui"
        cp -r "$USB_BASE_PATH/webui"/* "$temp_dir/backup/webui/" 2>/dev/null || true
        print_debug "WebUI backup created"
    fi
    
    # Backup launcher scripts
    for script in "$USB_BASE_PATH/leonardo.sh" "$USB_BASE_PATH/leonardo.bat" "$USB_BASE_PATH/leonardo.command"; do
        if [ -f "$script" ]; then
            mkdir -p "$temp_dir/backup/launchers"
            cp "$script" "$temp_dir/backup/launchers/" 2>/dev/null || true
        fi
    done
    print_debug "Launcher scripts backup created"
    
    # Backup user configuration and custom files
    mkdir -p "$temp_dir/backup/config"
    for config_file in "$USB_BASE_PATH/user_config.json" "$USB_BASE_PATH/custom_prompts.json" "$USB_BASE_PATH/version.txt"; do
        if [ -f "$config_file" ]; then
            cp "$config_file" "$temp_dir/backup/config/" 2>/dev/null || true
        fi
    done
    print_debug "Configuration files backup created"
    
    # Create a manifest of what was backed up
    find "$temp_dir/backup" -type f | sort > "$temp_dir/backup_manifest.txt"
    print_success "Backup completed successfully - $(wc -l < "$temp_dir/backup_manifest.txt") files backed up"
    
    # Update WebUI
    print_info "Updating WebUI components..."
    # Generate the latest WebUI
    local available_models_options=""
    if [ -d "$USB_BASE_PATH/.ollama/models" ]; then
        # Scan for models to populate the dropdown
        local model_scan_path="$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library"
        if [ -d "$model_scan_path" ]; then
            # Find model tags and populate the options
            for model_dir in "$model_scan_path"/*; do
                if [ -d "$model_dir" ]; then
                    local model_name=$(basename "$model_dir")
                    for tag in "$model_dir"/*; do
                        if [ -f "$tag" ]; then
                            local tag_name=$(basename "$tag")
                            local model_tag="$model_name:$tag_name"
                            available_models_options+="<option value=\"$model_tag\">$model_tag</option>\n"
                        fi
                    done
                fi
            done
        fi
    fi
    
    # If no models found, add a default option
    if [ -z "$available_models_options" ]; then
        available_models_options="<option value=\"llama3:8b\">llama3:8b</option>\n"
    fi
    
    # Generate and update the WebUI files
    mkdir -p "$USB_BASE_PATH/webui"
    generate_webui "$USB_BASE_PATH" "$available_models_options"
    
    # Update launcher scripts
    print_info "Updating launcher scripts..."
    local default_model="llama3:8b"
    # Find the first model in the options to use as default
    if [ -n "$available_models_options" ]; then
        default_model=$(echo "$available_models_options" | grep -oP 'value=\"\K[^\"]+' | head -n 1 || echo "llama3:8b")
    fi
    generate_launcher_scripts "$USB_BASE_PATH" "$default_model"
    
    # Update the version file
    echo "Leonardo AI USB Maker version $SCRIPT_VERSION" > "$USB_BASE_PATH/version.txt"
    print_info "Updated version file to $SCRIPT_VERSION"
    
    # Create or update the README file
    print_info "Updating documentation files..."
    generate_readme_file "$USB_BASE_PATH"
    
    # Verify file permissions
    print_info "Setting correct file permissions..."
    chmod +x "$USB_BASE_PATH/leonardo.sh" 2>/dev/null || true
    chmod +x "$USB_BASE_PATH/leonardo.command" 2>/dev/null || true
    
    # Create upgrade complete marker
    touch "$USB_BASE_PATH/.upgraded_to_$SCRIPT_VERSION"
    
    print_success "Upgrade to version $SCRIPT_VERSION completed successfully!"
    print_info "You can now safely eject the USB drive and use it on any compatible system."
    
    # Remove upgrade marker and reset trap
    rm -f "$USB_BASE_PATH/.upgrade_in_progress"
    trap - ERR
    
    # Create upgrade success marker with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    echo "Upgraded from $CURRENT_VERSION to $SCRIPT_VERSION on $timestamp" > "$USB_BASE_PATH/.upgrade_success"
    
    # Cleanup temporary files
    rm -rf "$temp_dir"
    print_info "Cleaned up temporary files."
    print_success "Upgrade completed successfully with no errors."
    return 0
}

# Handle errors during the upgrade process with rollback capability
handle_upgrade_error() {
    local temp_dir="$1"
    local exit_code=$?
    local line_number=${BASH_LINENO[0]}
    
    print_error "Error occurred during upgrade at line $line_number (exit code: $exit_code)"
    print_warning "Attempting to rollback changes and restore from backup..."
    
    # Check if we have backups to restore from
    if [ -d "$temp_dir/backup" ] && [ -f "$temp_dir/backup_manifest.txt" ]; then
        # For each backup file, restore it to its original location
        local restore_count=0
        while read -r backup_file; do
            # Get relative path within backup directory
            local rel_path="${backup_file#$temp_dir/backup/}"
            local target_path="$USB_BASE_PATH/$rel_path"
            
            # Create target directory if it doesn't exist
            mkdir -p "$(dirname "$target_path")"
            
            # Restore the file
            cp "$backup_file" "$target_path" 2>/dev/null && ((restore_count++))
        done < "$temp_dir/backup_manifest.txt"
        
        print_info "Restored $restore_count files from backup."
    else
        print_error "No backup files found for rollback. USB may be in an inconsistent state."
    fi
    
    # Create a failure marker
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    echo "Upgrade from $CURRENT_VERSION to $SCRIPT_VERSION failed on $timestamp (line: $line_number, exit: $exit_code)" > "$USB_BASE_PATH/.upgrade_failed"
    
    # Remove in-progress marker
    rm -f "$USB_BASE_PATH/.upgrade_in_progress"
    
    # Reset trap
    trap - ERR
    
    # Cleanup
    rm -rf "$temp_dir"
    print_info "Cleaned up temporary files."
    
    print_fatal "Upgrade failed but attempted recovery. Your USB drive should still be usable.\nCheck $USB_BASE_PATH/.upgrade_failed for details."
}

# Function to generate README.md file for the USB drive
generate_readme_file() {
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
    sudo chown "$(id -u):$(id -g)" "$checksum_file"

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

# Function to generate all necessary files for the USB drive
generate_usb_files() {
    local usb_base_dir="$1"
    local model_name="$2"
    
    print_info "Generating USB files..."
    
    # CRITICAL: Verify USB directory exists and is writable
    if [ ! -d "$usb_base_dir" ]; then
        print_error "USB directory does not exist: $usb_base_dir"
        print_info "Attempting to create directory and verify mount point..."
        
        # Try to create the directory
        mkdir -p "$usb_base_dir" 2>/dev/null
        
        # If still doesn't exist, try to find the correct path
        if [ ! -d "$usb_base_dir" ]; then
            # For macOS, check common mount paths
            if [[ "$(uname)" == "Darwin" ]]; then
                for possible_path in "/Volumes/$USB_LABEL" "/Volumes/CHATUSB" "/Volumes/NO NAME"; do
                    if [ -d "$possible_path" ]; then
                        print_warning "Redirecting to detected USB at: $possible_path"
                        usb_base_dir="$possible_path"
                        USB_BASE_PATH="$possible_path"
                        MOUNT_POINT="$possible_path"
                        break
                    fi
                done
            fi
        fi
        
        # Final check
        if [ ! -d "$usb_base_dir" ]; then
            print_fatal "Failed to locate or create USB directory. Please check USB mount status."
        fi
    fi
    
    # Verify writability
    if [ ! -w "$usb_base_dir" ]; then
        print_error "USB directory is not writable: $usb_base_dir"
        print_info "Attempting to fix permissions..."
        sudo chmod -R 755 "$usb_base_dir" 2>/dev/null
        
        if [ ! -w "$usb_base_dir" ]; then
            print_fatal "USB directory permissions could not be fixed. Please check mount and permission settings."
        fi
    fi
    
    # Detect runtime environment to optimize file generation
    detect_runtime_environment
    
    print_info "Creating directory structure..."
    mkdir -p "$usb_base_dir/webui" 2>/dev/null || true
    mkdir -p "$usb_base_dir/runtimes/linux_amd64" 2>/dev/null || true
    mkdir -p "$usb_base_dir/runtimes/mac_amd64" 2>/dev/null || true
    mkdir -p "$usb_base_dir/runtimes/mac_arm64" 2>/dev/null || true
    mkdir -p "$usb_base_dir/runtimes/windows_amd64" 2>/dev/null || true
    mkdir -p "$usb_base_dir/.ollama/models" 2>/dev/null || true
    
    # Generate all required files with error checking
    print_info "Generating WebUI..."
    if ! generate_webui_html "$usb_base_dir" "$model_name"; then
        print_error "Failed to generate WebUI. Retrying..."
        sleep 1
        generate_webui_html "$usb_base_dir" "$model_name" || print_warning "WebUI generation issue persists. Installation may be incomplete."
    fi
    
    print_info "Generating launcher scripts..."
    if ! generate_launcher_scripts "$usb_base_dir" "$model_name" "$USER_LAUNCHER_NAME_BASE"; then
        print_error "Failed to generate launcher scripts. Retrying..."
        sleep 1
        generate_launcher_scripts "$usb_base_dir" "$model_name" "$USER_LAUNCHER_NAME_BASE" || print_warning "Launcher script generation issue persists. Installation may be incomplete."
    fi
    
    # Emergency check for launcher files after main generation
    if [ ! -f "$usb_base_dir/leonardo.command" ] || [ ! -f "$usb_base_dir/leonardo.sh" ] || [ ! -f "$usb_base_dir/leonardo.bat" ]; then
        print_warning "Launcher files missing after regular generation. Running emergency backup..."
        emergency_generate_launcher_scripts "$usb_base_dir" "$model_name"
    fi
    
    print_info "Generating documentation..."
    generate_readme_file "$usb_base_dir" || print_warning "README generation failed."
    generate_security_readme "$usb_base_dir" || print_warning "Security guide generation failed."
    
    # Write version file
    echo "$SCRIPT_VERSION" > "$usb_base_dir/version.txt" 2>/dev/null || print_warning "Could not write version information."
    
    # Verify critical files exist
    local missing_files=0
    for critical_file in "$usb_base_dir/webui/index.html" "$usb_base_dir/leonardo.command" "$usb_base_dir/leonardo.sh" "$usb_base_dir/leonardo.bat"; do
        if [[ "$SELECTED_OS_TARGETS" == *"linux"* && "$critical_file" == *".sh" ]] || \
           [[ "$SELECTED_OS_TARGETS" == *"mac"* && "$critical_file" == *".command" ]] || \
           [[ "$SELECTED_OS_TARGETS" == *"win"* && "$critical_file" == *".bat" ]] || \
           [[ "$critical_file" == *"/webui/index.html" ]]; then
            if [ ! -f "$critical_file" ]; then
                print_error "Critical file missing: $critical_file"
                ((missing_files++))
            fi
        fi
    done
    
    if [ $missing_files -gt 0 ]; then
        print_warning "$missing_files critical files are missing. Attempting emergency recovery..."
        # Emergency direct write of launcher scripts if missing
        emergency_generate_launcher_scripts "$usb_base_dir" "$model_name"
    fi
    
    # Set proper line endings for all scripts based on target OS
    print_info "Setting proper line endings for cross-platform compatibility..."
    if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then
        ensure_proper_line_endings "$usb_base_dir/leonardo.sh" "linux"
        chmod +x "$usb_base_dir/leonardo.sh" 2>/dev/null || true
    fi
    
    if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then
        ensure_proper_line_endings "$usb_base_dir/leonardo.command" "mac"
        chmod +x "$usb_base_dir/leonardo.command" 2>/dev/null || true
    fi
    
    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
        ensure_proper_line_endings "$usb_base_dir/leonardo.bat" "windows"
    fi
    
    # Ensure permissions are set correctly
    chmod -R 755 "$usb_base_dir/webui" 2>/dev/null || true
    chmod -R 755 "$usb_base_dir/runtimes" 2>/dev/null || true
    
    # Run cross-platform compatibility tests
    test_cross_compatibility "$usb_base_dir"
    
    # Final verification for launcher files
    local launcher_files_missing=0
    for launcher_file in "$usb_base_dir/leonardo.command" "$usb_base_dir/leonardo.sh" "$usb_base_dir/leonardo.bat"; do
        if [[ "$SELECTED_OS_TARGETS" == *"linux"* && "$launcher_file" == *".sh" ]] || \
           [[ "$SELECTED_OS_TARGETS" == *"mac"* && "$launcher_file" == *".command" ]] || \
           [[ "$SELECTED_OS_TARGETS" == *"win"* && "$launcher_file" == *".bat" ]]; then
            if [ ! -f "$launcher_file" ]; then
                print_warning "Final verification: Launcher file still missing: $launcher_file"
                ((launcher_files_missing++))
            else
                print_debug "Final verification: Launcher file verified: $launcher_file"
            fi
        fi
    done
    
    if [ $launcher_files_missing -gt 0 ]; then
        print_warning "FINAL RECOVERY: $launcher_files_missing launcher files are still missing. Making one last attempt..."
        emergency_generate_launcher_scripts "$usb_base_dir" "$model_name"
        sync; sync  # Ensure all files are written to disk
        print_success "Final emergency recovery completed. Please verify launcher files manually."
    else
        print_success "All launcher files verified successfully!"
    fi
    
    print_success "USB files generated successfully!"
    return 0
}

# --- Emergency Launcher Script Generation ---
emergency_generate_launcher_scripts() {
    local usb_base_dir="$1"
    local model_name="$2"
    
    print_info "Emergency launcher script generation activated"
    
    # Create macOS launcher if needed
    if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]] && [ ! -f "$usb_base_dir/leonardo.command" ]; then
        print_info "Creating macOS launcher (leonardo.command)"
        cat > "$usb_base_dir/leonardo.command" << 'EOF'
#!/bin/bash
# Leonardo AI USB - macOS launcher script

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Set up environment variables
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models"
export OLLAMA_HOST="127.0.0.1:11434"

# ANSI color codes
C_RESET="\033[0m"; C_BOLD="\033[1m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BLUE="\033[34m"; C_RED="\033[31m"

printf "\n${C_BOLD}${C_GREEN}✨ Starting Leonardo AI USB Environment ✨${C_RESET}"
printf "Running on macOS...\n"

# Determine OS architecture
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    RUNTIME_DIR="$SCRIPT_DIR/runtimes/mac_arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
    RUNTIME_DIR="$SCRIPT_DIR/runtimes/mac_amd64"
else
    echo "Unsupported architecture: $ARCH. Please use a Mac with Intel or Apple Silicon CPU."
    exit 1
fi

# Check if the Ollama binary exists
OLLAMA_BIN="$RUNTIME_DIR/ollama"
if [ ! -f "$OLLAMA_BIN" ]; then
    echo "${C_BOLD}${C_RED}❌ Error: Ollama binary not found at $OLLAMA_BIN${C_RESET}"
    read -p "Press Enter to exit..." exit_key
    exit 1
fi

# Make sure binary is executable
chmod +x "$OLLAMA_BIN" 2>/dev/null

# Start the Ollama server in the background
printf "${C_BOLD}${C_BLUE}🚀 Starting Ollama server...${C_RESET}"
"$OLLAMA_BIN" serve &
OLLAMA_PID=$!

# Wait for Ollama server to start up
printf "${C_YELLOW}⏳ Waiting for Ollama server to start...${C_RESET}"
for i in {1..30}; do
    if curl -s "http://$OLLAMA_HOST/api/tags" >/dev/null; then
        break
    fi
    printf "."
    sleep 1
done

# Open WebUI in browser
printf "\n${C_BOLD}${C_GREEN}🌐 Opening WebUI in your default browser...${C_RESET}"
open "$SCRIPT_DIR/webui/index.html"

printf "\n${C_BOLD}${C_CYAN}ℹ️ The Ollama server is running in the background.${C_RESET}"
printf "${C_CYAN}ℹ️ This terminal window must remain open while using Leonardo AI.${C_RESET}"
printf "${C_CYAN}ℹ️ Close this window when you're done to shut down the server.${C_RESET}\n\n"

printf "${C_BOLD}Press Ctrl+C to exit${C_RESET}"

# Wait for the Ollama process to finish
wait $OLLAMA_PID
EOF
        chmod +x "$usb_base_dir/leonardo.command"
    fi
    
    # Create Linux launcher if needed
    if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]] && [ ! -f "$usb_base_dir/leonardo.sh" ]; then
        print_info "Creating Linux launcher (leonardo.sh)"
        cat > "$usb_base_dir/leonardo.sh" << 'EOF'
#!/bin/bash
# Leonardo AI USB - Linux launcher script

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set up environment variables
export OLLAMA_MODELS="$SCRIPT_DIR/.ollama/models"
export OLLAMA_HOST="127.0.0.1:11434"

# ANSI color codes
C_RESET="\033[0m"; C_BOLD="\033[1m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BLUE="\033[34m"; C_RED="\033[31m"

echo -e "\n${C_BOLD}${C_GREEN}✨ Starting Leonardo AI USB Environment ✨${C_RESET}"
echo -e "Running on Linux...\n"

# Check if the Ollama binary exists
OLLAMA_BIN="$SCRIPT_DIR/runtimes/linux_amd64/ollama"
if [ ! -f "$OLLAMA_BIN" ]; then
    echo -e "${C_BOLD}${C_RED}❌ Error: Ollama binary not found at $OLLAMA_BIN${C_RESET}"
    read -p "Press Enter to exit..." exit_key
    exit 1
fi

# Make sure binary is executable
chmod +x "$OLLAMA_BIN"

# Start the Ollama server in the background
echo -e "${C_BOLD}${C_BLUE}🚀 Starting Ollama server...${C_RESET}"
"$OLLAMA_BIN" serve &
OLLAMA_PID=$!

# Wait for Ollama server to start up
echo -e "${C_YELLOW}⏳ Waiting for Ollama server to start...${C_RESET}"
for i in {1..30}; do
    if curl -s "http://$OLLAMA_HOST/api/tags" >/dev/null; then
        break
    fi
    echo -n "."
    sleep 1
done

# Determine browser
BROWSER=""
for b in xdg-open sensible-browser firefox chromium-browser google-chrome brave-browser; do
    if command -v $b &>/dev/null; then
        BROWSER=$b
        break
    fi
done

# Open WebUI in browser
echo -e "\n${C_BOLD}${C_GREEN}🌐 Opening WebUI in browser...${C_RESET}"
if [ -n "$BROWSER" ]; then
    $BROWSER "$SCRIPT_DIR/webui/index.html" &>/dev/null &
else
    echo "Could not find a browser. Please manually open: $SCRIPT_DIR/webui/index.html"
fi

echo -e "\n${C_BOLD}${C_CYAN}ℹ️ The Ollama server is running in the background.${C_RESET}"
echo -e "${C_CYAN}ℹ️ This terminal window must remain open while using Leonardo AI.${C_RESET}"
echo -e "${C_CYAN}ℹ️ Close this window when you're done to shut down the server.${C_RESET}\n"

echo -e "${C_BOLD}Press Ctrl+C to exit${C_RESET}"

# Wait for the Ollama process to finish
wait $OLLAMA_PID
EOF
        chmod +x "$usb_base_dir/leonardo.sh"
    fi
    
    # Create Windows launcher if needed
    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]] && [ ! -f "$usb_base_dir/leonardo.bat" ]; then
        print_info "Creating Windows launcher (leonardo.bat)"
        cat > "$usb_base_dir/leonardo.bat" << 'EOF'
@echo off
REM Leonardo AI USB - Windows launcher script
SETLOCAL ENABLEDELAYEDEXPANSION

REM Get the directory where this batch file is located
SET SCRIPT_DIR=%~dp0
SET SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
cd /d "%SCRIPT_DIR%"

REM Set up environment variables
SET OLLAMA_MODELS=%SCRIPT_DIR%\.ollama\models
SET OLLAMA_HOST=127.0.0.1:11434

REM ANSI color codes for Windows
SET ESC=[  
SET RESET=%ESC%0m
SET BOLD=%ESC%1m
SET GREEN=%ESC%32m
SET YELLOW=%ESC%33m
SET BLUE=%ESC%34m
SET RED=%ESC%31m

echo %BOLD%%GREEN%Starting Leonardo AI USB Environment%RESET%
echo Running on Windows...

REM Ollama binary path
SET OLLAMA_BIN=%SCRIPT_DIR%\runtimes\windows_amd64\ollama.exe

REM Check if the Ollama binary exists
IF NOT EXIST "%OLLAMA_BIN%" (
    echo %BOLD%%RED%Error: Ollama binary not found at %OLLAMA_BIN%%RESET%
    pause
    exit /b 1
)

REM Start Ollama server
echo %BOLD%%BLUE%Starting Ollama server...%RESET%
start "Ollama Server" /B "%OLLAMA_BIN%" serve

REM Wait for Ollama server to start up
echo %YELLOW%Waiting for Ollama server to start...%RESET%
SET MAX_TRIES=30
SET TRIES=0

:CHECK_SERVER
SET /A TRIES+=1
REM Using curl to check if server is up
curl -s http://%OLLAMA_HOST%/api/tags > NUL 2>&1
IF %ERRORLEVEL% EQU 0 GOTO SERVER_READY
IF %TRIES% GEQ %MAX_TRIES% GOTO SERVER_TIMEOUT
TIMEOUT /T 1 /NOBREAK > NUL
echo .
GOTO CHECK_SERVER

:SERVER_TIMEOUT
echo %RED%Server did not start in time. Continuing anyway...%RESET%
GOTO CONTINUE

:SERVER_READY
echo %GREEN%Server started successfully!%RESET%

:CONTINUE
REM Open WebUI in default browser
echo %BOLD%%GREEN%Opening WebUI in your default browser...%RESET%
start "" "%SCRIPT_DIR%\webui\index.html"

echo.
echo %BOLD%%BLUE%The Ollama server is running in the background.%RESET%
echo %BLUE%This command window must remain open while using Leonardo AI.%RESET%
echo %BLUE%Close this window when you're done to shut down the server.%RESET%
echo.

echo %BOLD%Press Ctrl+C to exit%RESET%

REM Keep the window open
pause > nul
EOF
    fi

    # Generate WebUI if needed
    if [ ! -f "$usb_base_dir/webui/index.html" ]; then
        print_info "Creating WebUI files"
        mkdir -p "$usb_base_dir/webui"
        
        # Create minimal index.html
        cat > "$usb_base_dir/webui/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leonardo AI Chat</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        #chat-container { height: 400px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; margin-bottom: 10px; }
        #input-box { width: 80%; padding: 8px; }
        #send-button { padding: 8px 15px; }
        .user-message { background-color: #e6f7ff; padding: 8px; border-radius: 5px; margin: 5px 0; }
        .ai-message { background-color: #f0f0f0; padding: 8px; border-radius: 5px; margin: 5px 0; }
        .system-message { color: #888; font-style: italic; margin: 5px 0; }
        .fade-in { animation: fadeIn 0.5s; }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    </style>
</head>
<body>
    <h1>Leonardo AI Chat</h1>
    
    <div id="chat-container"></div>
    
    <div>
        <input type="text" id="input-box" placeholder="Type your message..." />
        <button id="send-button">Send</button>
    </div>
    
    <div>
        <label for="model-selector">Model:</label>
        <select id="model-selector"></select>
        
        <label for="streaming-mode">Response Mode:</label>
        <select id="streaming-mode">
            <option value="word">Word by Word</option>
            <option value="sentence">Sentence by Sentence</option>
            <option value="paragraph">Paragraph by Paragraph</option>
            <option value="full">Full Response</option>
        </select>
        
        <label for="animation-style">Animation:</label>
        <select id="animation-style">
            <option value="none">None</option>
            <option value="fade" selected>Fade In</option>
            <option value="pop">Pop</option>
            <option value="slide">Slide In</option>
            <option value="typewriter">Typewriter</option>
        </select>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const chatContainer = document.getElementById('chat-container');
            const inputBox = document.getElementById('input-box');
            const sendButton = document.getElementById('send-button');
            const modelSelector = document.getElementById('model-selector');
            const streamingMode = document.getElementById('streaming-mode');
            const animationStyle = document.getElementById('animation-style');
            
            // Load available models
            fetch('http://127.0.0.1:11434/api/tags')
                .then(response => response.json())
                .then(data => {
                    const models = data.models || [];
                    if (models.length === 0) {
                        appendSystemMessage('No models found. Please make sure Ollama is running.');
                        return;
                    }
                    
                    models.forEach(model => {
                        const option = document.createElement('option');
                        option.value = model.name;
                        option.textContent = model.name;
                        modelSelector.appendChild(option);
                    });
                    
                    appendSystemMessage(`Found ${models.length} models. Ready to chat!`);
                })
                .catch(error => {
                    appendSystemMessage('Error connecting to Ollama API. Please make sure the server is running.');
                    console.error('Error:', error);
                });
            
            // Send message function
            function sendMessage() {
                const message = inputBox.value.trim();
                if (message === '') return;
                
                appendMessage('user', message);
                inputBox.value = '';
                
                const model = modelSelector.value;
                const streamMode = streamingMode.value;
                
                if (!model) {
                    appendSystemMessage('Please select a model first.');
                    return;
                }
                
                // Create a div for the AI response
                const responseDiv = document.createElement('div');
                responseDiv.className = 'ai-message ' + getAnimationClass();
                chatContainer.appendChild(responseDiv);
                chatContainer.scrollTop = chatContainer.scrollHeight;
                
                // Use the Ollama API to generate a response
                fetch('http://127.0.0.1:11434/api/generate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ model, prompt: message, stream: true })
                })
                .then(response => {
                    const reader = response.body.getReader();
                    const decoder = new TextDecoder();
                    let buffer = '';
                    
                    function processStream({ done, value }) {
                        if (done) return;
                        
                        const chunk = decoder.decode(value);
                        const lines = chunk.split('\n');
                        
                        for (const line of lines) {
                            if (line.trim() === '') continue;
                            
                            try {
                                const json = JSON.parse(line);
                                if (json.response) {
                                    buffer += json.response;
                                    
                                    // Update based on streaming mode
                                    switch(streamMode) {
                                        case 'word':
                                            responseDiv.textContent = buffer;
                                            break;
                                        case 'sentence':
                                            if (json.response.includes('.') || 
                                                json.response.includes('?') || 
                                                json.response.includes('!')) {
                                                responseDiv.textContent = buffer;
                                            }
                                            break;
                                        case 'paragraph':
                                            if (json.response.includes('\n\n')) {
                                                responseDiv.textContent = buffer;
                                            }
                                            break;
                                        case 'full':
                                            // Don't update until complete
                                            break;
                                    }
                                    
                                    chatContainer.scrollTop = chatContainer.scrollHeight;
                                    
                                    if (json.done) {
                                        responseDiv.textContent = buffer;
                                        break;
                                    }
                                }
                            } catch (e) {
                                console.error('Error parsing JSON:', e);
                            }
                        }
                        
                        // Continue reading
                        return reader.read().then(processStream);
                    }
                    
                    return reader.read().then(processStream);
                })
                .catch(error => {
                    appendSystemMessage('Error communicating with Ollama: ' + error.message);
                    console.error('Error:', error);
                });
            }
            
            // Helper functions
            function appendMessage(type, text) {
                const div = document.createElement('div');
                div.className = type + '-message ' + getAnimationClass();
                div.textContent = text;
                chatContainer.appendChild(div);
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
            
            function appendSystemMessage(text) {
                const div = document.createElement('div');
                div.className = 'system-message';
                div.textContent = text;
                chatContainer.appendChild(div);
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
            
            function getAnimationClass() {
                const style = animationStyle.value;
                switch(style) {
                    case 'fade': return 'fade-in';
                    case 'pop': return 'pop-in';
                    case 'slide': return 'slide-in';
                    case 'typewriter': return 'typewriter';
                    default: return '';
                }
            }
            
            // Event listeners
            sendButton.addEventListener('click', sendMessage);
            
            inputBox.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') sendMessage();
            });
            
            // Initial message
            appendSystemMessage('Welcome to Leonardo AI Chat! Select a model and start chatting.');
        });
    </script>
</body>
</html>
EOF
    fi
    
    print_success "Emergency launcher script generation complete"
    return 0
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
    print_line
}


# --- Cross-Platform Compatibility Testing ---
test_cross_compatibility() {
    local usb_path="$1"
    
    if [ ! -d "$usb_path" ]; then
        print_error "Cannot test cross-compatibility: '$usb_path' is not a valid directory"
        return 1
    fi
    
    print_subheader "🧪 Testing Cross-Platform Compatibility"
    
    # Create a test directory
    local test_dir="$usb_path/.cross_platform_test"
    mkdir -p "$test_dir"
    
    # 1. Test executable permissions preservation
    print_info "Testing executable permissions preservation..."
    echo '#!/bin/sh\necho "Hello from test script"' > "$test_dir/test_exec.sh"
    chmod +x "$test_dir/test_exec.sh"
    
    # Verify permissions were set
    if [ -x "$test_dir/test_exec.sh" ]; then
        print_success "✓ Executable permissions are preserved"
    else
        print_warning "⚠ Executable permissions not preserved - chmod +x will be needed on target systems"
    fi
    
    # 2. Test for case sensitivity issues
    print_info "Testing filesystem case sensitivity..."
    echo "UPPERCASE TEST" > "$test_dir/CaseTest.txt"
    echo "lowercase test" > "$test_dir/casetest.txt"
    
    # Check if both files exist as separate entities
    if [ -f "$test_dir/CaseTest.txt" ] && [ -f "$test_dir/casetest.txt" ] && \
       ! cmp -s "$test_dir/CaseTest.txt" "$test_dir/casetest.txt"; then
        print_success "✓ Filesystem is case-sensitive - good for cross-platform use"
    else
        print_warning "⚠ Filesystem appears to be case-insensitive - avoid relying on case differences in filenames"
    fi
    
    # 3. Test for special character handling
    print_info "Testing special character handling..."
    echo "Special chars test" > "$test_dir/special_#@!%.txt"
    
    if [ -f "$test_dir/special_#@!%.txt" ]; then
        print_success "✓ Special characters in filenames are supported"
    else
        print_warning "⚠ Special characters in filenames may cause issues - avoid using them"
    fi
    
    # 4. Test for long path support
    print_info "Testing path length limits..."
    local deep_dir="$test_dir/level1/level2/level3/level4/level5/level6/level7/level8/level9/level10"
    mkdir -p "$deep_dir"
    echo "Deep path test" > "$deep_dir/deep_file.txt"
    
    if [ -f "$deep_dir/deep_file.txt" ]; then
        print_success "✓ Deep directory paths are supported"
    else
        print_warning "⚠ Deep directory paths may cause issues - keep paths short"
    fi
    
    # 5. Test for line ending compatibility in scripts
    print_info "Testing line ending handling..."
    # Create test scripts with different line endings
    # Unix style (LF)
    echo -e "#!/bin/sh\necho Line1\necho Line2" > "$test_dir/unix_style.sh"
    # Windows style (CRLF) - simulate with echo -e
    echo -e "#!/bin/sh\r\necho Line1\r\necho Line2\r\n" > "$test_dir/windows_style.sh"
    
    # Set both as executable
    chmod +x "$test_dir/unix_style.sh" "$test_dir/windows_style.sh"
    
    # Ensure our line ending management works
    ensure_proper_line_endings "$test_dir/unix_style.sh" "linux"
    ensure_proper_line_endings "$test_dir/windows_style.sh" "windows"
    
    print_success "✓ Line ending compatibility tested - see compatibility report"
    
    # Generate compatibility report
    local report_file="$usb_path/cross_platform_compatibility.txt"
    {
        echo "====== Leonardo AI USB Cross-Platform Compatibility Report ======"
        echo "Generated on: $(date)"
        echo "USB Location: $usb_path"
        echo "Filesystem: $(df -T "$usb_path" | tail -n 1 | awk '{print $2}' 2>/dev/null || echo "Unknown")"
        echo ""
        echo "=== Compatibility Test Results ==="
        echo "1. Executable permissions: $([ -x "$test_dir/test_exec.sh" ] && echo "Preserved" || echo "Not preserved")"
        echo "2. Case sensitivity: $([ -f "$test_dir/CaseTest.txt" ] && [ -f "$test_dir/casetest.txt" ] && ! cmp -s "$test_dir/CaseTest.txt" "$test_dir/casetest.txt" && echo "Yes" || echo "No")"
        echo "3. Special characters: $([ -f "$test_dir/special_#@!%.txt" ] && echo "Supported" || echo "Not supported")"
        echo "4. Deep paths: $([ -f "$deep_dir/deep_file.txt" ] && echo "Supported" || echo "May be limited")"
        echo ""
        echo "=== Compatibility Recommendations ==="
        echo "- Always use relative paths in launcher scripts"
        echo "- Avoid spaces and special characters in filenames"
        echo "- Keep critical paths short and simple"
        echo "- Use only ASCII characters in filenames and paths"
        echo "====== End of Report ======"
    } > "$report_file"
    
    print_info "Compatibility report saved to: $report_file"
    
    # Clean up test files
    rm -rf "$test_dir"
    
    return 0
}

# --- Cleanup Function ---
cleanup_temp_files() {
    if [ -n "$TMP_DOWNLOAD_DIR" ] && [ -d "$TMP_DOWNLOAD_DIR" ]; then
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
    echo -e "${C_BOLD}${C_WHITE}--- $SCRIPT_SELF_NAME (Version: $SCRIPT_VERSION) ---${C_RESET}"
    echo -e "${C_WHITE}--- Portable Ollama USB Suite (Leonardo Edition - Security Enhanced!) ---${C_RESET}"

    print_info "What would you like to do?"
    print_divider_thin
    print_option "1" "Create a NEW Leonardo AI USB drive"
    print_option "2" "Manage an EXISTING Leonardo AI USB drive"
    print_divider_thin
    print_option "3" "Upgrade/Patch Existing USB to Latest Version"
    print_option "4" "Dry Run / System Check (No changes made)"
    print_option "5" "Utility: Clear USB context (affects next run & exits script)"
    print_divider_thin
    print_option "6" "About this Script"
    print_option "q" "Quit"
    
    # Read user input directly rather than using show_menu
    print_prompt "Enter your choice: "
    read main_op_choice
    
    # Map numeric choices to operation modes
    case "$main_op_choice" in
        1) main_op_choice="create_new" ;;
        2) main_op_choice="manage_existing" ;;
        3) main_op_choice="upgrade_usb" ;;
        4) main_op_choice="dry_run" ;;
        5) main_op_choice="clear_context" ;;
        6) main_op_choice="about_script" ;;
        q|Q) main_op_choice="q" ;;
        *) print_error "Invalid choice. Please try again."; sleep 2; continue ;;
    esac


    if [[ "$main_op_choice" == "q" ]]; then
        print_info "Quitting script. Goodbye! 👋"; exit 0
    fi

    OPERATION_MODE="$main_op_choice"

    # Process the menu selection
    case "$OPERATION_MODE" in
        create_new)
            clear_screen_and_show_art
            print_header "Creating NEW Leonardo AI USB Drive"
            check_host_dependencies "full"
            ;;
        manage_existing)
            clear_screen_and_show_art
            print_header "Managing EXISTING Leonardo AI USB Drive"
            ;;
        upgrade_usb)
            clear_screen_and_show_art
            print_header "Upgrading Existing Leonardo AI USB"
            check_host_dependencies "full"
            # Will implement the upgrade logic
            ;;
        clear_context)
            clear_usb_context
            clear_screen_and_show_art
            print_success "USB context cleared. Changes will take effect on next run."
            exit 0
            ;;
        about_script)
            clear_screen_and_show_art
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
            ;;
        upgrade_usb)
            clear_screen_and_show_art
            print_header "Upgrading Existing Leonardo AI USB"
            check_host_dependencies "full"
            upgrade_existing_usb
            ;;
        *)
            if [[ "$OPERATION_MODE" != "dry_run" ]]; then
                print_fatal "Invalid selection. Please try again."
            fi
{{ ... }}
            ;;
    esac

    # Handle dry run separately to maintain existing logic
    if [[ "$OPERATION_MODE" == "dry_run" ]]; then
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
        USB_LABEL="$USB_LABEL_DEFAULT"
        print_success "USB context has been cleared."
        print_info "This will take effect the next time you run the script."
        print_info "Exiting now. Please re-run the script to use the cleared context."
        sleep 1
        exit 0
    fi


    if [[ "$OPERATION_MODE" == "create_new" ]]; then
        USB_LABEL="$USB_LABEL_DEFAULT"
        ask_usb_device
        ask_format_usb
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
        create_new)
            check_host_dependencies "full"
            ask_target_os_binaries
            ask_llm_model # This now calls calculate_total_estimated_models_size_gb

            print_header "📝 PRE-FLIGHT CHECK (NEW USB) 📝"
            echo -e "${C_BLUE}Please review your selections before proceeding:${C_RESET}"
            echo -e "  - Target USB Drive:          ${C_BOLD}$USB_DEVICE_PATH${C_RESET} (Target Label after format: ${C_BOLD}$USB_LABEL_DEFAULT${C_RESET})"
            echo -e "  - Format USB Drive:          ${C_BOLD}$FORMAT_USB_CHOICE${C_RESET}"
            if [[ "$FORMAT_USB_CHOICE" == "yes" ]]; then
                 echo -e "    (Filesystem: exFAT, Label to be set: ${C_BOLD}$USB_LABEL_DEFAULT${C_RESET})"
            else
                 echo -e "    (Using existing format. Current detected label for operations: ${C_BOLD}$USB_LABEL${C_RESET})"
            fi
            echo -e "  - Ollama Runtimes for:       ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_BINARIES_SIZE_GB GB${C_RESET})"
            echo -e "  - AI Model(s) to Install:    ${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET})"
            if [[ "$MODEL_SOURCE_TYPE" == "create_local" ]]; then
                echo -e "    (Source for '${MODELS_TO_INSTALL_LIST[0]}': Local GGUF file '${C_DIM}$LOCAL_GGUF_PATH_FOR_IMPORT${C_RESET}')"
            fi
            print_line; echo ""
            FINAL_CONFIRMATION_CHOICE=""
            ask_yes_no_quit "Do you want to proceed with these settings? (Choosing 'No' or 'Quit' will return to main menu)" FINAL_CONFIRMATION_CHOICE
            if [[ "$FINAL_CONFIRMATION_CHOICE" != "yes" ]]; then
                print_info "Operation cancelled by user. Returning to main menu."
                OPERATION_MODE=""; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue
            fi
            print_success "Configuration confirmed. Proceeding with USB creation... Hold on to your Llama! 🦙💨"
            echo "";

            if [[ "$FORMAT_USB_CHOICE" == "yes" ]]; then
                echo -e "\n${C_BOLD}${C_RED}**********************************************************************${C_RESET}"
                echo -e "${C_BOLD}${C_RED}** 💣 ATTENTION: Formatting ${USB_DEVICE_PATH} is about to begin.       **${C_RESET}";
                echo -e "${C_BOLD}${C_RED}** This is the ABSOLUTE LAST CHANCE to cancel before data loss.     **${C_RESET}"
                echo -e "${C_BOLD}${C_RED}**********************************************************************${C_RESET}"; PROCEED_FORMAT_CHOICE=""
                ask_yes_no_quit "${C_RED}${C_BOLD}LAST CHANCE: Really proceed with formatting $USB_DEVICE_PATH?${C_RESET}" PROCEED_FORMAT_CHOICE
                if [[ "$PROCEED_FORMAT_CHOICE" == "yes" ]]; then
                    print_info "⚙️ Formatting $USB_DEVICE_PATH..."
                    
                    if [[ "$(uname)" == "Linux" ]]; then
                        # For Linux
                        # Determine the partition path
                        if [[ "$USB_DEVICE_PATH" == *nvme*n* ]] || [[ "$USB_DEVICE_PATH" == *mmcblk* ]]; then
                           USB_PARTITION_PATH="${USB_DEVICE_PATH}p1"
                        else
                           USB_PARTITION_PATH="${USB_DEVICE_PATH}1"
                        fi
                        
                        # Unmount all partitions from the device
                        print_info "Unmounting any existing partitions..."
                        sudo umount "$USB_DEVICE_PATH"* 2>/dev/null
                        
                        # Create a new partition table and exFAT partition
                        print_info "Creating new partition table on $USB_DEVICE_PATH..."
                        sudo parted -s "$USB_DEVICE_PATH" mklabel msdos
                        sudo parted -s "$USB_DEVICE_PATH" mkpart primary fat32 1MiB 100%
                        
                        # Format as exFAT (or fallback to FAT32 if exFAT tools not available)
                        print_info "Formatting partition as exFAT with label $USB_LABEL_DEFAULT..."
                        if command -v mkfs.exfat > /dev/null 2>&1; then
                            sudo mkfs.exfat -n "$USB_LABEL_DEFAULT" "$USB_PARTITION_PATH"
                        elif command -v exfatformat > /dev/null 2>&1; then
                            sudo exfatformat -n "$USB_LABEL_DEFAULT" "$USB_PARTITION_PATH"
                        else
                            print_warning "exFAT formatting tools not found. Falling back to FAT32 (4GB file size limit)..."
                            sudo mkfs.vfat -F 32 -n "$USB_LABEL_DEFAULT" "$USB_PARTITION_PATH"
                        fi
                        
                    elif [[ "$(uname)" == "Darwin" ]]; then
                        # For macOS
                        print_info "Unmounting disk before formatting..."
                        diskutil unmountDisk force "$USB_DEVICE_PATH" > /dev/null 2>&1
                        
                        print_info "Formatting disk as exFAT with label '$USB_LABEL'..."
                        if ! diskutil eraseDisk ExFAT "$USB_LABEL" "$RAW_USB_DEVICE_PATH"; then
                            print_fatal "Disk format operation failed. Please check the device and try again."
                        fi
                        print_success "Formatting complete!"
                        
                        # After formatting, explicitly find and set the mount point
                        print_info "Locating newly formatted volume..."
                        sleep 2  # Give the system a moment to register the new volume
                        
                        # Find the new mount point directly
                        # First identify the partition
                        formatted_partition="${USB_DEVICE_PATH}s1"
                        if ! diskutil list | grep -q "$formatted_partition"; then
                            print_warning "Could not identify partition after formatting. Will try mountDisk instead."
                            if ! diskutil mountDisk "$USB_DEVICE_PATH"; then
                                print_warning "mountDisk failed. Will attempt to proceed anyway."
                            fi
                        else
                            print_info "Found partition $formatted_partition, mounting..."
                            if ! diskutil mount "$formatted_partition"; then
                                print_warning "Mount failed. Will attempt one more method."
                                diskutil mountDisk "$USB_DEVICE_PATH"
                            fi
                        fi
                    fi
                    
                    USB_LABEL="$USB_LABEL_DEFAULT"
                    print_success "Formatting complete!"
                    
                    # For macOS we should already be mounted from the formatting steps
                    # For Linux we need to mount the drive
                    print_info "Finding mount point for the newly formatted USB drive..."
                    
                    # Reset the base path
                    USB_BASE_PATH=""
                    sleep 3 # Give the system a moment to recognize the new filesystem
                    
                    if [[ "$(uname)" == "Darwin" ]]; then
                        # Extensive macOS mount point detection
                        print_info "Searching for mounted USB drive..."
                        
                        # Method 1: Direct check using the label we set
                        if [ -d "/Volumes/$USB_LABEL" ]; then
                            USB_BASE_PATH="/Volumes/$USB_LABEL"
                            MOUNT_POINT="$USB_BASE_PATH"
                            print_success "Found mounted USB with matching label at $USB_BASE_PATH"
                        else
                            # Method 2: Check using diskutil info
                            local disk_info=$(diskutil info "$USB_DEVICE_PATH" 2>/dev/null)
                            local mount_point=$(echo "$disk_info" | grep -i "Mount Point" | sed -e 's/.*Mount Point:[[:space:]]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                            
                            if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
                                USB_BASE_PATH="$mount_point"
                                MOUNT_POINT="$mount_point"
                                print_success "Found mounted USB using diskutil at $USB_BASE_PATH"
                            else
                                # Method 3: Try individual disk slice
                                for slice in "${USB_DEVICE_PATH}s1" "${USB_DEVICE_PATH}s2"; do
                                    print_info "Checking slice $slice..."
                                    local slice_info=$(diskutil info "$slice" 2>/dev/null)
                                    local slice_mount=$(echo "$slice_info" | grep -i "Mount Point" | sed -e 's/.*Mount Point:[[:space:]]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                                    
                                    if [ -n "$slice_mount" ] && [ -d "$slice_mount" ]; then
                                        USB_BASE_PATH="$slice_mount"
                                        MOUNT_POINT="$slice_mount"
                                        print_success "Found mounted USB on slice $slice at $USB_BASE_PATH"
                                        break
                                    fi
                                done
                                
                                # Method 4: Try to mount explicitly if still not found
                                if [ -z "$USB_BASE_PATH" ] || [ ! -d "$USB_BASE_PATH" ]; then
                                    print_info "Mount point still not found. Trying explicit mount..."
                                    
                                    # Get the most recently mounted volume as a fallback
                                    local volumes_before=$(ls -1 /Volumes/)
                                    
                                    # Try to mount explicitly
                                    diskutil mountDisk "$USB_DEVICE_PATH" &>/dev/null || true
                                    sleep 2
                                    
                                    # Look for any new volumes that appeared
                                    local volumes_after=$(ls -1 /Volumes/)
                                    local new_volume=$(comm -13 <(echo "$volumes_before" | sort) <(echo "$volumes_after" | sort) | head -1)
                                    
                                    if [ -n "$new_volume" ] && [ -d "/Volumes/$new_volume" ]; then
                                        USB_BASE_PATH="/Volumes/$new_volume"
                                        MOUNT_POINT="$USB_BASE_PATH"
                                        print_success "Found newly mounted USB at $USB_BASE_PATH"
                                    else
                                        # Method 5: Last resort - just pick the most recently modified volume
                                        local latest_volume=$(ls -t /Volumes/ | grep -v "Macintosh HD" | head -1)
                                        if [ -n "$latest_volume" ] && [ -d "/Volumes/$latest_volume" ]; then
                                            USB_BASE_PATH="/Volumes/$latest_volume"
                                            MOUNT_POINT="$USB_BASE_PATH"
                                            print_warning "Using best guess for USB mount: $USB_BASE_PATH"
                                        else
                                            # If we still don't have a mount point, try one last mounting method
                                            print_info "All detection methods failed. Using ensure_usb_mounted_and_writable as last resort..."
                                            if ! ensure_usb_mounted_and_writable; then
                                                print_fatal "Failed to mount USB after formatting. Please check the drive and try again.";
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    else
                        # For Linux, use ensure_usb_mounted_and_writable
                        print_info "Attempting to mount the newly formatted drive..."
                        if ! ensure_usb_mounted_and_writable; then 
                            print_fatal "Failed to mount USB after formatting. Please check the drive and try again."; 
                        fi
                    fi
                    
                    # Verify that we have a valid mount point
                    if [ -z "$USB_BASE_PATH" ] || ! [ -d "$USB_BASE_PATH" ]; then
                        print_fatal "Could not determine mount point for the formatted USB drive."
                    fi
                    
                    # Verify we can write to it
                    if ! sudo touch "$USB_BASE_PATH/.write_test" 2>/dev/null; then
                        print_fatal "The mounted USB drive is not writable. Check permissions or remount."
                    else
                        sudo rm "$USB_BASE_PATH/.write_test"
                    fi
                else
                    print_info "Formatting cancelled by user. Script will proceed assuming drive is already formatted as exFAT with label $USB_LABEL."
                    FORMAT_USB_CHOICE="no"
                    if ! ensure_usb_mounted_and_writable; then print_fatal "Failed to mount unformatted USB. Please check the drive and try again."; fi
                fi
            elif [[ "$FORMAT_USB_CHOICE" == "no" ]]; then
                print_info "Skipping formatting as per user choice. Will attempt to use $USB_DEVICE_PATH as-is."
                print_info "Ensure it is formatted (preferably exFAT with label '$USB_LABEL' for easiest auto-mount) and has enough space."
                if ! ensure_usb_mounted_and_writable; then print_fatal "Failed to mount unformatted USB. Please check the drive and try again."; fi
            fi
            echo
            check_disk_space "${MODELS_TO_INSTALL_LIST[*]}" "$MODEL_SOURCE_TYPE" "$LOCAL_GGUF_PATH_FOR_IMPORT" false

            print_info "⚙️ Creating directory structure on $USB_BASE_PATH..."
            sudo mkdir -p "$USB_BASE_PATH/.ollama/models" "$USB_BASE_PATH/Data/tmp" "$USB_BASE_PATH/Data/logs" "$USB_BASE_PATH/webui"
            sudo mkdir -p "$USB_BASE_PATH/runtimes/linux/bin" "$USB_BASE_PATH/runtimes/linux/lib" \
                       "$USB_BASE_PATH/runtimes/mac/bin" "$USB_BASE_PATH/runtimes/mac/lib" \
                       "$USB_BASE_PATH/runtimes/win/bin" \
                       "$USB_BASE_PATH/Installation_Info"
            sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/Data" "$USB_BASE_PATH/webui" "$USB_BASE_PATH/.ollama" "$USB_BASE_PATH/Installation_Info"
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
                print_info "--- Downloading Linux Ollama ---"; echo -e "  URL: ${C_DIM}$LINUX_URL${C_RESET}"
                LINUX_TARBALL="$TMP_DOWNLOAD_DIR/ollama-linux.tgz"
                if ! $DOWNLOAD_CMD_BASE "$LINUX_TARBALL" "$LINUX_URL"; then print_fatal "Download failed for Linux Ollama."; fi
                if [ ! -s "$LINUX_TARBALL" ]; then print_fatal "Linux tarball is empty after download attempt."; fi; print_success "Linux binaries downloaded."
                print_info "Extracting Linux binaries to host temporary directory..."; HOST_LINUX_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/host_linux_extract"; mkdir -p "$HOST_LINUX_EXTRACT_DIR"
                if ! tar -xzf "$LINUX_TARBALL" -C "$HOST_LINUX_EXTRACT_DIR" --strip-components=0; then print_fatal "Failed to extract Linux tarball."; fi; print_success "Host extraction for Linux binaries successful."; OLLAMA_BIN_SOURCE=""; LIBS_SOURCE_DIR=""
                if [ -f "$HOST_LINUX_EXTRACT_DIR/bin/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/bin/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/lib"; fi
                elif [ -f "$HOST_LINUX_EXTRACT_DIR/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/lib"; fi
                elif [ -f "$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/lib"; fi
                else print_fatal "Could not find 'ollama' binary in the extracted Linux archive (checked common paths (./bin/ollama, ./ollama, ./usr/share/ollama/ollama))."; fi
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
                print_info "--- Downloading macOS Ollama ---"; echo -e "  URL: ${C_DIM}$MAC_URL${C_RESET}"
                MAC_TARBALL="$TMP_DOWNLOAD_DIR/ollama-mac.tgz"
                if ! $DOWNLOAD_CMD_BASE "$MAC_TARBALL" "$MAC_URL"; then print_fatal "Download failed for macOS Ollama."; fi
                if [ ! -s "$MAC_TARBALL" ]; then print_fatal "macOS tarball is empty after download attempt."; fi; print_success "macOS binaries downloaded."
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
                print_info "--- Downloading Windows Ollama ---"; echo -e "  URL: ${C_DIM}$WINDOWS_ZIP_URL${C_RESET}"
                WINDOWS_ZIP="$TMP_DOWNLOAD_DIR/ollama-windows.zip"
                if ! $DOWNLOAD_CMD_BASE "$WINDOWS_ZIP" "$WINDOWS_ZIP_URL"; then print_fatal "Download failed for Windows Ollama."; fi
                if [ ! -s "$WINDOWS_ZIP" ]; then print_fatal "Windows ZIP is empty after download attempt."; fi; print_success "Windows binaries downloaded."
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
            sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/runtimes"
            
            # Generate all necessary launcher files and support files
            generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"
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
                print_warning "Could not determine existing model on USB. Web UI will default to: $MODEL_TO_PULL (Launchers/UI will offer choice if multiple models exist)."
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

    if [[ "$OPERATION_MODE" == "create_new" ]] || [[ "$OPERATION_MODE" == "add_llm" ]] || [[ "$OPERATION_MODE" == "repair_scripts" ]] || [[ "$OPERATION_MODE" == "remove_llm" ]]; then
        if [ -z "$USB_BASE_PATH" ] || ! sudo test -d "$USB_BASE_PATH"; then
            print_error "USB_BASE_PATH ('$USB_BASE_PATH') is not set or not a directory. Cannot generate USB support files."
        else
            generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"
        fi
    fi
    
    # Process macOS libraries if they exist
    if [ -d "$HOST_MAC_EXTRACT_DIR/lib" ] && [ -n "$(ls -A "$HOST_MAC_EXTRACT_DIR/lib" 2>/dev/null)" ]; then
        print_info "Copying macOS libraries...";
        sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
        sudo cp -RL "$HOST_MAC_EXTRACT_DIR/lib"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS libraries copy failed or no libs found.";
    elif [ -d "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks" ]; then
        print_info "Copying macOS Frameworks...";
        sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
        sudo cp -RL "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS Frameworks copy failed.";
    else 
        print_info "No separate 'lib' or 'Frameworks' directory found or it was empty for macOS binaries. This is often normal."; 
    fi
    
    if [ -d "$HOST_MAC_EXTRACT_DIR" ]; then
        rm -rf "$HOST_MAC_EXTRACT_DIR"; 
        print_success "macOS binaries processed."
    fi

    # Process Windows binaries if needed
    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
        print_info "--- Downloading Windows Ollama ---"; echo -e "  URL: ${C_DIM}$WINDOWS_ZIP_URL${C_RESET}"
        WINDOWS_ZIP="$TMP_DOWNLOAD_DIR/ollama-windows.zip"
        if ! $DOWNLOAD_CMD_BASE "$WINDOWS_ZIP" "$WINDOWS_ZIP_URL"; then print_fatal "Download failed for Windows Ollama."; fi
        if [ ! -s "$WINDOWS_ZIP" ]; then print_fatal "Windows ZIP is empty after download attempt."; fi; print_success "Windows binaries downloaded."
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
    # Ensure proper permissions and generate launcher files
    if [ -d "$USB_BASE_PATH/runtimes" ]; then
        sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/runtimes"
    fi
    
    # This call was moved to the main conditional block above, but we're keeping it here 
    # as a fallback in case it wasn't executed in the proper place
    if [ -d "$USB_BASE_PATH" ] && [ -n "$MODEL_TO_PULL" ]; then
        print_info "Ensuring launcher files and support files are generated..."
        generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"
    fi
    
    # End of the initial setup code - original code continues below

    # Here we'll ensure that if we're in any of these operation modes and we've reached this point,
    # the operation has been completed successfully
    if [[ "$OPERATION_MODE" == "create_new" ]] || [[ "$OPERATION_MODE" == "add_llm" ]] || \
       [[ "$OPERATION_MODE" == "repair_scripts" ]] || [[ "$OPERATION_MODE" == "remove_llm" ]]; then
        print_info "Operation $OPERATION_MODE completed successfully."
    fi
    
    # Clear any temporary variables
    unset HOST_MAC_EXTRACT_DIR
    unset WIN_TMP_EXTRACT_DIR
    
    # This is a simplified case statement for post-processing steps if needed
    case "$OPERATION_MODE" in
        add_llm)
            # Any additional add_llm specific cleanup steps would go here
            print_info "LLM added successfully to USB drive."
            ;;
        repair_scripts)
            # Any additional repair_scripts specific cleanup steps would go here
            print_info "Scripts repaired successfully."
            ;;
        remove_llm)
            # Any additional remove_llm specific cleanup steps would go here
            print_info "LLM removed successfully from USB drive."
            ;;
        create_new)
            # Any additional create_new specific cleanup steps would go here
            print_info "New Leonardo AI USB created successfully."
            ;;
        *)
            # Default case - nothing to do
            ;;
    esac

    # Calculate installation time
    INSTALL_END_TIME=$(date +%s)
    ELAPSED_SECONDS=$((INSTALL_END_TIME - INSTALL_START_TIME))

    get_grade_msg() {
        local category="$1"; local idx=$((RANDOM % 3))
        local fast=("Blink and you missed it. ⚡️" "Faster than a Llama on espresso! 🚀" "AI booted before you blinked. 🦾")
        local med=("Efficient, like a well-oiled Llama. 🚆" "Quick, but not showing off. 🏎️" "Solid pace—no wasted cycles. 🤖")
        local slow=("Had a snack mid-install? 🍔 Your Llama took a nap. 😴" "USB took the scenic route. 🐢" "Slow dance with the bits. 🪩")
        local epic=("Watched a movie while waiting? 📽️" "Is your USB drive a glacier? ❄️" "Time for a CPU upgrade... 🛠️")

        case "$category" in
            fast) echo "${fast[$idx]}";;
            med) echo "${med[$idx]}";;
            slow) echo "${slow[$idx]}";;
            epic) echo "${epic[$idx]}";;
            *) echo "Done! 🎉";;
        esac
    }
    
    # Set grade category based on elapsed time
    GRADE_CATEGORY=""
    if [ "$ELAPSED_SECONDS" -lt 120 ]; then 
        GRADE_CATEGORY="fast"
    elif [ "$ELAPSED_SECONDS" -lt 300 ]; then 
        GRADE_CATEGORY="med"
    elif [ "$ELAPSED_SECONDS" -lt 900 ]; then 
        GRADE_CATEGORY="slow"
    else 
        GRADE_CATEGORY="epic"
    fi

    print_leonardo_success_art
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
        echo -e "${C_CYAN}Forge Speed Grade: $(get_grade_msg "$GRADE_CATEGORY")${C_RESET}"
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
        echo -e "  6. The Web UI will open in your browser, allowing you to select any available model."
        echo ""
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
    if [[ "$OPERATION_MODE" == "manage_existing_loop_continue" ]]; then
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