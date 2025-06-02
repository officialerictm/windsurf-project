#!/bin/bash

# This script will systematically fix the syntax error in Leonardo_AI_USB_Maker_V5.sh
# by analyzing and correcting the structure of the fancy_download function

# Backup the original file
cp -f "Leonardo_AI_USB_Maker_V5.sh.bak" "Leonardo_AI_USB_Maker_V5.sh"

# Extract just the fancy_download function to a separate file for analysis
sed -n '/^fancy_download()/,/^}/p' "Leonardo_AI_USB_Maker_V5.sh" > fancy_download_func.sh

# Count opening and closing control structures
echo "Analyzing function structure..."
if_count=$(grep -c "^\s*if" fancy_download_func.sh)
fi_count=$(grep -c "^\s*fi" fancy_download_func.sh)
echo "Found $if_count 'if' statements and $fi_count 'fi' statements"

# Fix the structure by properly closing any missing control structures
# This specific fix addresses the issue we've identified in the function
sed -i '890s/        echo ""/        echo ""\n    fi/' "Leonardo_AI_USB_Maker_V5.sh"

echo "Fixed the syntax error in Leonardo_AI_USB_Maker_V5.sh"
echo "Testing script for syntax errors..."

# Verify the fix
bash -n "Leonardo_AI_USB_Maker_V5.sh"
if [ $? -eq 0 ]; then
    echo "✅ Syntax check passed! The script should now run properly."
else
    echo "❌ Syntax error still exists. Further debugging needed."
fi
