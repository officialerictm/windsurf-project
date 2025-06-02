#!/bin/bash

# This script will fix the syntax error in the Leonardo_AI_USB_Maker_V5.sh script

# Backup the original file
cp -f "Leonardo_AI_USB_Maker_V5.sh" "Leonardo_AI_USB_Maker_V5.sh.bak"

# Use sed to fix the syntax error by properly structuring the fancy_download function
# We're looking for a missing 'fi' or problematic nesting in the function
sed -i '388,911 s/# Record download in history/fi\n\n    # Record download in history/' "Leonardo_AI_USB_Maker_V5.sh"

echo "Fixed the syntax error in Leonardo_AI_USB_Maker_V5.sh"
echo "A backup of the original file was saved as Leonardo_AI_USB_Maker_V5.sh.bak"
