#!/bin/bash
# Leonardo AI USB Maker - Script Assembler
# This script combines all the parts into a single executable script

set -e

# Configuration
SCRIPT_NAME="__Leonardo.sh"
PARTS_DIR="Parts"
OUTPUT_FILE="$SCRIPT_NAME"
TEMP_FILE=".temp_assembled_script"

# Header
echo "=== Leonardo AI USB Maker - Script Assembler ==="
echo "Combining script parts into: $OUTPUT_FILE"
echo

# Check if parts directory exists
if [ ! -d "$PARTS_DIR" ]; then
    echo "Error: Parts directory '$PARTS_DIR' not found."
    exit 1
fi

# Create temporary output file
> "$TEMP_FILE"

# Function to add a part
add_part() {
    local part_file="$1"
    if [ -f "$part_file" ]; then
        echo "Adding: $(basename "$part_file")"
        cat "$part_file" >> "$TEMP_FILE"
        echo -e "\n" >> "$TEMP_FILE"  # Add some spacing between parts
    else
        echo "Warning: Part file not found: $part_file"
        return 1
    fi
}

# Add parts in order
add_part "${PARTS_DIR}/00_script_header.sh"
add_part "${PARTS_DIR}/01_global_config.sh"
add_part "${PARTS_DIR}/02_core_utils.sh"
add_part "${PARTS_DIR}/03_ui_components.sh"
add_part "${PARTS_DIR}/04_fs_operations.sh"
add_part "${PARTS_DIR}/05_network_ops.sh"

# Make the script executable
chmod +x "$TEMP_FILE"

# Move the temporary file to the final output
mv -f "$TEMP_FILE" "$OUTPUT_FILE"

echo
echo "=== Assembly Complete ==="
echo "Successfully created: $OUTPUT_FILE"
echo "You can now run: ./$OUTPUT_FILE"
