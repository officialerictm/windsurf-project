#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker - Assembly Tool
# ==============================================================================
# Description: Assembles modular script components into a single executable file
# Author: Leonardo AI Team
# Version: 1.0.0
# License: MIT
# ==============================================================================

# Set strict mode
set -euo pipefail
IFS=$'\n\t'

# Configuration
SCRIPT_NAME="leonardo.sh"
OUTPUT_DIR="$(pwd)"
PARTS_DIR="$(pwd)/Parts"
MANIFEST_FILE="assembly.manifest"
TEMP_FILE="$(mktemp)"
VERBOSE=false
FORCE=false
ADD_HEADER=true
ADD_COMMENTS=true
SKIP_SYNTAX_CHECK=false
SYNTAX_CHECK_ONLY=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Assembles modular script components into a single executable file.

Options:
  -o, --output FILE     Set output filename (default: $SCRIPT_NAME)
  -d, --dir DIR         Set parts directory (default: $PARTS_DIR)
  -m, --manifest FILE   Use custom manifest file (default: $MANIFEST_FILE)
  --no-header           Don't add auto-generated header comment
  --no-comments         Don't add component source comments
  -f, --force           Overwrite output file if it exists and ignore syntax errors
  -v, --verbose         Show verbose output
  --skip-syntax-check   Skip syntax checking of components and final script
  --syntax-check-only   Only check syntax without assembling
  -h, --help            Show this help message

Examples:
  $(basename "$0") --output custom_name.sh
  $(basename "$0") --dir ./MyComponents --manifest custom.manifest
  $(basename "$0") --syntax-check-only  # Check syntax of all components
EOF
}

# Log messages with color and level
log() {
    local level="$1"
    local message="$2"
    local color="$NC"
    
    case "$level" in
        "INFO") color="$GREEN" ;;
        "WARN") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        "DEBUG") color="$BLUE" ;;
    esac
    
    if [[ "$level" != "DEBUG" || "$VERBOSE" == "true" ]]; then
        echo -e "${color}[$level] $message${NC}" >&2
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                SCRIPT_NAME="$2"
                shift 2
                ;;
            -d|--dir)
                PARTS_DIR="$2"
                shift 2
                ;;
            -m|--manifest)
                MANIFEST_FILE="$2"
                shift 2
                ;;
            --no-header)
                ADD_HEADER=false
                shift
                ;;
            --no-comments)
                ADD_COMMENTS=false
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --skip-syntax-check)
                SKIP_SYNTAX_CHECK=true
                shift
                ;;
            --syntax-check-only)
                SYNTAX_CHECK_ONLY=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Validate the configuration
validate_config() {
    # Check if parts directory exists
    if [[ ! -d "$PARTS_DIR" ]]; then
        log "ERROR" "Parts directory does not exist: $PARTS_DIR"
        exit 1
    fi
    
    # Check if output file already exists
    OUTPUT_FILE="$OUTPUT_DIR/$SCRIPT_NAME"
    if [[ -f "$OUTPUT_FILE" && "$FORCE" != "true" ]]; then
        log "ERROR" "Output file already exists: $OUTPUT_FILE. Use --force to overwrite."
        exit 1
    fi
}

# Add a header to the assembled script
add_header() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    cat << EOF > "$TEMP_FILE"
#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker
# ==============================================================================
# AUTOMATICALLY ASSEMBLED SCRIPT - DO NOT EDIT DIRECTLY
# Generated on: $timestamp
# Generator: $(basename "$0") v1.0.0
# ==============================================================================

# Enable strict mode
set -euo pipefail
IFS=\$'\n\t'

EOF
}

# Process components according to the manifest
process_manifest() {
    log "INFO" "Using manifest file: $MANIFEST_FILE"
    
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log "WARN" "Manifest file not found. Using default assembly order."
        return 1
    fi
    
    # Read each line from manifest and process the component
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
            continue
        fi
        
        # Extract component path and optional flags
        component="$line"
        flags=""
        if [[ "$line" == *"|"* ]]; then
            component="${line%%|*}"
            flags="${line#*|}"
        fi
        
        # Check if component exists
        component_path="$PARTS_DIR/$component"
        if [[ ! -f "$component_path" ]]; then
            log "WARN" "Component not found: $component_path"
            continue
        fi
        
        # Add component to output with appropriate formatting
        add_component "$component_path" "$component" "$flags"
    done < "$MANIFEST_FILE"
    
    return 0
}

# Process components recursively, ordered by name
process_directory() {
    local dir="$1"
    
    # First, process numeric-prefixed directories in order
    find "$dir" -mindepth 1 -maxdepth 1 -type d -name "[0-9]*" | sort | while read -r subdir; do
        process_directory "$subdir"
    done
    
    # Then, process non-numeric directories in alphabetical order
    find "$dir" -mindepth 1 -maxdepth 1 -type d -not -path "*/\.*" -not -name "[0-9]*" | sort | while read -r subdir; do
        process_directory "$subdir"
    done
    
    # Finally, process files directly in this directory
    find "$dir" -mindepth 1 -maxdepth 1 -type f -name "*.sh" | sort | while read -r file; do
        local component="${file#$PARTS_DIR/}"
        add_component "$file" "$component"
    done
}

# Add a component to the assembled script
add_component() {
    local file="$1"
    local component="$2"
    local flags="${3:-}"
    
    log "DEBUG" "Adding component: $component"
    
    # Check component syntax first if not forced
    if [[ "$FORCE" != "true" ]]; then
        if ! check_component_syntax "$file" "$component"; then
            log "ERROR" "Skipping component due to syntax errors: $component"
            return 1
        fi
    fi
    
    # Add component separator and info
    if [[ "$ADD_COMMENTS" == "true" ]]; then
        echo -e "\n# ==============================================================================\n# Component: $component\n# ==============================================================================" >> "$TEMP_FILE"
    fi
    
    # Check if component is executable and contains a shebang
    if [[ -x "$file" && "$(head -n 1 "$file")" == "#!/bin/bash" ]]; then
        # Skip the shebang line for executable files (avoid duplicate shebangs)
        tail -n +2 "$file" >> "$TEMP_FILE"
    else
        # Use the entire file for non-executable components
        cat "$file" >> "$TEMP_FILE"
    fi
    
    # Add empty line after component
    echo -e "\n" >> "$TEMP_FILE"
    
    log "DEBUG" "Added component: $component"
    return 0
}

# Check bash syntax for a file
check_syntax() {
    local file="$1"
    local component="${2:-}"
    
    if [[ -f "$file" ]]; then
        bash -n "$file" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            # Get the specific error message
            local error_msg=$(bash -n "$file" 2>&1)
            log "ERROR" "Syntax error in ${component:-$file}: $error_msg"
            return 1
        fi
    else
        log "ERROR" "File not found: $file"
        return 1
    fi
    
    return 0
}

# Check component syntax before adding it
check_component_syntax() {
    local file="$1"
    local component="$2"
    local temp_syntax_file="$(mktemp)"
    
    # First, just check basic syntax without sourcing
    bash -n "$file" 2>/dev/null
    local basic_syntax_result=$?
    
    if [[ $basic_syntax_result -ne 0 ]]; then
        local error_detail=$(bash -n "$file" 2>&1)
        log "ERROR" "Component $component has syntax errors: $error_detail"
        rm -f "$temp_syntax_file"
        return 1
    fi
    
    # If it's main.sh or has specific indicators of being a "main" module, skip the sourcing test
    # since it likely depends on other modules
    if [[ "$component" == "main.sh" || $(grep -c "main()" "$file") -gt 0 || $(grep -c "main \"\$@\"" "$file") -gt 0 ]]; then
        log "DEBUG" "Component $component passed basic syntax check (skipping source test for main module)"
        rm -f "$temp_syntax_file"
        return 0
    fi
    
    # Create a temporary wrapper to check component syntax
    cat > "$temp_syntax_file" << EOF
#!/bin/bash
# Syntax test wrapper
set -euo pipefail

# Mock required functions/variables to avoid undefined errors
function print_debug() { echo "\$@"; }
function print_error() { echo "\$@"; }
function print_info() { echo "\$@"; }
function print_warning() { echo "\$@"; }
function print_success() { echo "\$@"; }
function initialize_script() { :; }
function parse_arguments() { :; }
function show_header() { :; }
function show_main_menu() { :; }
function check_root() { :; }
function check_dependencies() { :; }
function human_readable_size() { echo "1KB"; }
function is_block_device() { return 0; }
function command_exists() { return 0; }
function wait_for_device_settle() { :; }
function verify_usb_device() { return 0; }
function create_filesystem() { return 0; }
function safe_umount() { return 0; }
function create_partition_table() { return 0; }
function calculate_checksum() { echo "checksum"; }
function fancy_download() { return 0; }
function save_checksum() { return 0; }
DRY_RUN=false
VERBOSE=false
QUIET=false
FORCE=false
NO_COLOR=false
UI_WIDTH=80
UI_PADDING=2
UI_BORDER_CHAR="-"
UI_SECTION_CHAR="-"
UI_HEADER_CHAR="-"
UI_FOOTER_CHAR="-"
TMP_DIR="/tmp"
LOG_FILE="/tmp/log"
LOG_LEVEL=1
MOUNT_POINTS=()
LLAMA_NORMAL="llama"
LLAMA_CAUTION="llama"
LLAMA_WARNING="llama"
COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_CYAN=""
COLOR_RESET=""
COLOR_WHITE=""
COLOR_BG_RED=""
SCRIPT_VERSION="5.0.0"
SCRIPT_NAME="leonardo.sh"
SUPPORTED_MODELS=("llama3-8b:Meta LLaMA 3 8B")
LOG_DIR="/tmp"

# Source the component
source "$file" 2>/dev/null

# Exit successfully if no syntax errors
exit 0
EOF
    
    # Make it executable
    chmod +x "$temp_syntax_file"
    
    # Check syntax
    "$temp_syntax_file" >/dev/null 2>&1
    local result=$?
    
    # Clean up
    rm -f "$temp_syntax_file"
    
    # Report result
    if [[ $result -ne 0 ]]; then
        # Get specific error by running direct syntax check
        local error_detail=$(bash -n "$file" 2>&1 || echo "Unknown syntax error")
        log "ERROR" "Component $component has syntax errors: $error_detail"
        return 1
    fi
    
    log "DEBUG" "Component $component passed syntax check"
    return 0
}

# Validate final script syntax
validate_final_script() {
    local script="$1"
    
    log "INFO" "Validating syntax of $script"
    
    if bash -n "$script" 2>/dev/null; then
        log "INFO" "Syntax validation passed for $script"
        return 0
    else
        local error_msg=$(bash -n "$script" 2>&1)
        log "ERROR" "Final script has syntax errors: $error_msg"
        
        # Try to identify which component caused the error
        local line_num=$(echo "$error_msg" | grep -oP 'line \K[0-9]+')
        if [[ -n "$line_num" ]]; then
            local component=$(grep -A 1 -B 1 "Component:" "$script" | grep -B 3 -A 1 -n "" | 
                           awk -v line="$line_num" '$1 ~ /^[0-9]+:/ {
                               split($1, a, ":");
                               if (a[1] <= line) {
                                   last = $0;
                               } else {
                                   if (found != 1) print last;
                                   found = 1;
                               }
                           }' | grep "Component:" | sed 's/.*Component: *//')
            
            if [[ -n "$component" ]]; then
                log "ERROR" "Error likely in component: $component"
            fi
        fi
        
        return 1
    fi
}

# Main assembly process
assemble_script() {
    # Initialize output file
    if [[ "$ADD_HEADER" == "true" ]]; then
        add_header
    fi
    
    # First try to use the manifest if it exists
    if ! process_manifest; then
        log "INFO" "Using default assembly order."
        process_directory "$PARTS_DIR"
    fi
    
    # Move temporary file to final output location
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    chmod +x "$OUTPUT_FILE"
    
    # Validate the final script
    if ! validate_final_script "$OUTPUT_FILE"; then
        log "WARNING" "The assembled script contains syntax errors."
        if [[ "$FORCE" != "true" ]]; then
            log "ERROR" "Assembly failed due to syntax errors. Use --force to ignore."
            exit 1
        else
            log "WARNING" "Ignoring syntax errors due to --force flag."
        fi
    fi
    
    log "INFO" "Assembly complete: $OUTPUT_FILE"
}

# Cleanup function
cleanup() {
    if [[ -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi
}

# Set up trap for cleanup on exit
trap cleanup EXIT

# Check syntax of all components
check_all_components() {
    log "INFO" "Checking syntax of all components in $PARTS_DIR"
    local error_count=0
    local component_count=0
    
    # Process components according to manifest if it exists
    if [[ -f "$MANIFEST_FILE" ]]; then
        log "INFO" "Using manifest file for syntax check: $MANIFEST_FILE"
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
                continue
            fi
            
            # Extract component path
            component="$line"
            if [[ "$line" == *"|"* ]]; then
                component="${line%%|*}"
            fi
            
            # Check if component exists
            component_path="$PARTS_DIR/$component"
            if [[ ! -f "$component_path" ]]; then
                log "WARN" "Component not found: $component_path"
                continue
            fi
            
            # Check component syntax
            component_count=$((component_count + 1))
            if ! check_component_syntax "$component_path" "$component"; then
                error_count=$((error_count + 1))
            fi
        done < "$MANIFEST_FILE"
    else
        # Fall back to checking all .sh files recursively
        log "INFO" "No manifest file found, checking all .sh files recursively"
        
        find "$PARTS_DIR" -name "*.sh" -type f | while read -r file; do
            local rel_path="${file#$PARTS_DIR/}"
            component_count=$((component_count + 1))
            
            if ! check_component_syntax "$file" "$rel_path"; then
                error_count=$((error_count + 1))
            fi
        done
    fi
    
    # Report results
    if [[ $error_count -eq 0 ]]; then
        log "INFO" "Syntax check completed successfully for all $component_count components"
        return 0
    else
        log "ERROR" "Syntax check failed: $error_count/$component_count components have errors"
        return 1
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Handle syntax-check-only mode
    if [[ "$SYNTAX_CHECK_ONLY" == "true" ]]; then
        check_all_components
        exit $?
    fi
    
    validate_config
    
    # Only proceed with assembly if not in syntax-check-only mode
    assemble_script
}

# Run the script
main "$@"
