#!/bin/bash
# ==============================================================================
# Leonardo AI Universal - Assembly Tool
# ==============================================================================
# Description: Assembles modular script components into a single executable seed file
# Author: Leonardo AI Team
# Version: 6.0.0
# License: MIT
# ==============================================================================

# Set strict mode
set -euo pipefail
IFS=$'\n\t'

# Configuration
SCRIPT_NAME="leonardo_universal_seed.sh"
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
COMPRESS_OUTPUT=false
VERIFY_COMPONENT_DEPENDENCIES=true

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Print usage information
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Assembles modular script components into a single executable seed file.

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
  --compress            Compress the output file by removing comments and extra whitespace
  --no-dependency-check Skip verification of component dependencies
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
        "SUCCESS") color="$CYAN" ;;
        "ALERT") color="$MAGENTA" ;;
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
            --compress)
                COMPRESS_OUTPUT=true
                shift
                ;;
            --no-dependency-check)
                VERIFY_COMPONENT_DEPENDENCIES=false
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
# Leonardo AI Universal - Multi-Environment LLM Deployment System
# ==============================================================================
# AUTOMATICALLY ASSEMBLED SCRIPT - DO NOT EDIT DIRECTLY
# Generated on: $timestamp
# Generator: $(basename "$0") v6.0.0
# ==============================================================================

# Enable strict mode
set -euo pipefail
IFS=\$'\n\t'

EOF
}

# Extract and validate dependencies specified in component headers
check_component_dependencies() {
    local component_path="$1"
    local component_name="$2"
    
    # Extract dependencies from header comments
    local dependencies
    dependencies=$(grep -i "# Depends:" "$component_path" | sed 's/# Depends://i' | tr ',' '\n' | tr -d ' ')
    
    if [[ -n "$dependencies" ]]; then
        log "DEBUG" "Checking dependencies for $component_name: $dependencies"
        
        while IFS= read -r dependency || [[ -n "$dependency" ]]; do
            if [[ -z "$dependency" ]]; then
                continue
            fi
            
            # Check if dependency file exists
            local dependency_path="$PARTS_DIR/$dependency"
            if [[ ! -f "$dependency_path" ]]; then
                log "WARN" "Dependency not found for $component_name: $dependency_path"
                if [[ "$FORCE" != "true" ]]; then
                    return 1
                fi
            fi
        done <<< "$dependencies"
    fi
    
    return 0
}

# Process components according to the manifest
process_manifest() {
    log "INFO" "Using manifest file: $MANIFEST_FILE"
    
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log "WARN" "Manifest file not found. Using default assembly order."
        process_directory "$PARTS_DIR"
        return 0
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
        
        # Check dependencies if enabled
        if [[ "$VERIFY_COMPONENT_DEPENDENCIES" == "true" ]]; then
            if ! check_component_dependencies "$component_path" "$component"; then
                log "ERROR" "Failed dependency check for $component"
                if [[ "$FORCE" != "true" ]]; then
                    exit 1
                fi
            fi
        fi
        
        # Add component to output with appropriate formatting
        add_component "$component_path" "$component" "$flags"
    done < "$MANIFEST_FILE"
    
    return 0
}

# Process components recursively, ordered by name
process_directory() {
    local dir="$1"
    
    find "$dir" -type f -name "*.sh" | sort | while read -r file; do
        local rel_path
        rel_path=$(realpath --relative-to="$PARTS_DIR" "$file")
        
        # Check dependencies if enabled
        if [[ "$VERIFY_COMPONENT_DEPENDENCIES" == "true" ]]; then
            if ! check_component_dependencies "$file" "$rel_path"; then
                log "ERROR" "Failed dependency check for $rel_path"
                if [[ "$FORCE" != "true" ]]; then
                    exit 1
                fi
            fi
        fi
        
        add_component "$file" "$rel_path"
    done
}

# Add a component to the assembled script
add_component() {
    local component_path="$1"
    local component_name="$2"
    local flags="${3:-}"
    
    log "INFO" "Adding component: $component_name"
    
    # Check syntax if not skipped
    if [[ "$SKIP_SYNTAX_CHECK" != "true" ]]; then
        if ! check_component_syntax "$component_path" "$component_name"; then
            log "ERROR" "Syntax check failed for: $component_name"
            if [[ "$FORCE" != "true" ]]; then
                exit 1
            fi
        fi
    fi
    
    # Add component header comment if enabled
    if [[ "$ADD_COMMENTS" == "true" ]]; then
        echo -e "\n\n# ==============================================================================\n# Component: $component_name\n# ==============================================================================" >> "$TEMP_FILE"
    fi
    
    # Handle compression if enabled
    if [[ "$COMPRESS_OUTPUT" == "true" ]]; then
        # Remove comments and blank lines, except for interpreter line
        if grep -q "^#!/" "$component_path"; then
            # Preserve shebang line for executable components
            head -1 "$component_path" >> "$TEMP_FILE"
            tail -n +2 "$component_path" | grep -v "^#" | grep -v "^\s*$" >> "$TEMP_FILE"
        else
            grep -v "^#" "$component_path" | grep -v "^\s*$" >> "$TEMP_FILE"
        fi
    else
        # Add component content as-is
        cat "$component_path" >> "$TEMP_FILE"
    fi
    
    # Add empty line after component
    echo "" >> "$TEMP_FILE"
}

# Check bash syntax for a file
check_syntax() {
    local file="$1"
    
    # Use bash to check syntax with -n flag
    bash -n "$file" 2>/dev/null
    return $?
}

# Check component syntax before adding it
check_component_syntax() {
    local component_path="$1"
    local component_name="$2"
    
    # Skip for non-scripts or if explicitly told to
    if [[ "$SKIP_SYNTAX_CHECK" == "true" ]]; then
        return 0
    fi
    
    # First line could be a shebang
    local first_line
    first_line=$(head -n 1 "$component_path")
    local has_shebang=false
    
    if [[ "$first_line" =~ ^#!/ ]]; then
        has_shebang=true
    fi
    
    # Create a temporary file for syntax checking
    local syntax_temp
    syntax_temp=$(mktemp)
    
    # Add a shebang if it doesn't have one, so bash knows how to interpret it
    if [[ "$has_shebang" != "true" ]]; then
        echo "#!/bin/bash" > "$syntax_temp"
    fi
    
    # Add the component content
    cat "$component_path" >> "$syntax_temp"
    
    # Check syntax
    if ! check_syntax "$syntax_temp"; then
        log "ERROR" "Syntax error in component: $component_name"
        # If verbose, show the actual error by running the check again
        if [[ "$VERBOSE" == "true" ]]; then
            bash -n "$syntax_temp"
        fi
        rm -f "$syntax_temp"
        return 1
    fi
    
    rm -f "$syntax_temp"
    return 0
}

# Validate final script syntax
validate_final_script() {
    log "INFO" "Validating final script syntax"
    
    # Skip if requested
    if [[ "$SKIP_SYNTAX_CHECK" == "true" ]]; then
        log "WARN" "Syntax validation skipped as requested"
        return 0
    fi
    
    # Check syntax of the assembled script
    if ! check_syntax "$TEMP_FILE"; then
        log "ERROR" "Syntax error in assembled script"
        # If verbose, show the actual error by running the check again
        if [[ "$VERBOSE" == "true" ]]; then
            bash -n "$TEMP_FILE"
        fi
        return 1
    fi
    
    log "SUCCESS" "Final script syntax validation passed"
    return 0
}

# Measure script size
measure_script_size() {
    local file_to_measure="$1"
    log "INFO" "DEBUG: measure_script_size: Measuring file: '$file_to_measure'"
    if [[ -f "$file_to_measure" ]]; then
        log "INFO" "DEBUG: measure_script_size: File '$file_to_measure' exists."
        local size_bytes
        log "INFO" "DEBUG: measure_script_size: About to run: stat -c%s \"$file_to_measure\""
        size_bytes=$(stat -c%s "$file_to_measure")
        local stat_exit_code=$?
        log "INFO" "DEBUG: measure_script_size: stat exit code: $stat_exit_code, size_bytes: '$size_bytes'"
        
        if [[ $stat_exit_code -ne 0 ]]; then
            log "ERROR" "measure_script_size: stat command failed for '$file_to_measure' with exit code $stat_exit_code."
            return 1 
        fi
        
        if ! [[ "$size_bytes" =~ ^[0-9]+$ ]]; then # Check if size_bytes is a valid number
            log "ERROR" "measure_script_size: stat command returned non-numeric size '$size_bytes' for '$file_to_measure'."
            return 1
        fi

        local size_kb
        log "INFO" "DEBUG: measure_script_size: About to run: awk 'BEGIN {printf \"%.2f\", $size_bytes / 1024}'"
        size_kb=$(awk "BEGIN {printf \"%.2f\", $size_bytes / 1024}")
        local awk_exit_code=$?
        log "INFO" "DEBUG: measure_script_size: awk exit code: $awk_exit_code, size_kb: '$size_kb'"

        if [[ $awk_exit_code -ne 0 ]]; then
            log "ERROR" "measure_script_size: awk command failed for '$file_to_measure' with size_bytes '$size_bytes' and exit code $awk_exit_code."
            return 1
        fi
        
        log "INFO" "Final script size: $size_kb KB ($size_bytes bytes)"
    else
        log "WARN" "Could not measure size, file not found: $file_to_measure"
        return 1 # Also an error condition for the caller
    fi
    return 0 
}

# Set executable permissions on the final script
set_permissions() {
    local file_to_set="$1"
    log "INFO" "Attempting to set executable permissions on: '$file_to_set'"
    if [[ -z "$file_to_set" ]]; then
        log "ERROR" "set_permissions: file_to_set is empty!"
        return 1
    fi
    # Use -e to check for existence, could be symlink. -f checks for regular file.
    if [[ ! -e "$file_to_set" ]]; then
        log "ERROR" "set_permissions: Target path does not exist: '$file_to_set'"
        ls -ld "$file_to_set" 2>/dev/null || log "INFO" "set_permissions: ls also failed for '$file_to_set'"
        return 1
    elif [[ ! -f "$file_to_set" && ! -L "$file_to_set" ]]; then # Allow regular files or symlinks to regular files
        log "ERROR" "set_permissions: Target is not a regular file or symlink: '$file_to_set'"
        ls -ld "$file_to_set"
        return 1
    fi
    
    chmod +x "$file_to_set"
    local chmod_exit_code=$?
    
    if [[ $chmod_exit_code -ne 0 ]]; then
        log "ERROR" "chmod +x \"$file_to_set\" FAILED with exit code $chmod_exit_code."
        return 1
    else
        log "INFO" "chmod +x \"$file_to_set\" SUCCEEDED."
    fi
    return 0
}

# Main assembly process
assemble_script() {
    log "INFO" "Starting assembly process"
    
    # Add header if enabled
    if [[ "$ADD_HEADER" == "true" ]]; then
        add_header
    else
        # Create an empty file
        : > "$TEMP_FILE"
    fi
    
    # Process components according to manifest or directory
    process_manifest
    
    # Validate syntax of the assembled script
    if ! validate_final_script; then
        log "ERROR" "Final script validation failed"
        if [[ "$FORCE" != "true" ]]; then
            exit 1
        fi
    fi
    
    # Move the assembled script to the output location
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    
    # Set executable permissions
    if ! set_permissions "$OUTPUT_FILE"; then
        log "ERROR" "set_permissions returned an error. Assembly process cannot complete successfully."
        exit 1
    fi
    
    # Measure and report script size
    if ! measure_script_size "$OUTPUT_FILE"; then
        log "ERROR" "measure_script_size returned an error. Assembly process cannot complete successfully."
        exit 1
    fi
    
    log "SUCCESS" "Assembly complete: $OUTPUT_FILE"
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
    local total=0
    local passed=0
    local failed=0
    
    log "INFO" "Checking syntax of all components"
    
    # Process components according to manifest if available
    if [[ -f "$MANIFEST_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
                continue
            fi
            
            # Extract component path
            component="${line%%|*}"
            component_path="$PARTS_DIR/$component"
            
            if [[ ! -f "$component_path" ]]; then
                log "WARN" "Component not found: $component_path"
                continue
            fi
            
            total=$((total + 1))
            
            if check_component_syntax "$component_path" "$component"; then
                passed=$((passed + 1))
                log "DEBUG" "Syntax check passed: $component"
            else
                failed=$((failed + 1))
                log "ERROR" "Syntax check failed: $component"
            fi
        done < "$MANIFEST_FILE"
    else
        # Process all .sh files in parts directory
        while IFS= read -r file; do
            local rel_path
            rel_path=$(realpath --relative-to="$PARTS_DIR" "$file")
            
            total=$((total + 1))
            
            if check_component_syntax "$file" "$rel_path"; then
                passed=$((passed + 1))
                log "DEBUG" "Syntax check passed: $rel_path"
            else
                failed=$((failed + 1))
                log "ERROR" "Syntax check failed: $rel_path"
            fi
        done < <(find "$PARTS_DIR" -type f -name "*.sh" | sort)
    fi
    
    # Report results
    log "INFO" "Syntax check results: $passed/$total passed, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        log "ERROR" "Some components failed syntax check"
        return 1
    else
        log "SUCCESS" "All components passed syntax check"
        return 0
    fi
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Validate configuration
    validate_config
    
    # If only checking syntax, do that and exit
    if [[ "$SYNTAX_CHECK_ONLY" == "true" ]]; then
        check_all_components
        exit $?
    fi
    
    # Otherwise, assemble the script
    assemble_script
}

# Run the script
main "$@"
