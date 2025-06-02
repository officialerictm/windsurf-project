#!/bin/bash
# Script to properly fix the Leonardo AI USB Maker without changing functionality

echo "Starting proper fix of Leonardo AI USB Maker script..."

# Reset to a clean starting point using the V4 version
cd "/home/officialerictm/CascadeProjects/vibecoding/CascadeProjects/windsurf-project"
cp -f "Leonardo/Leonardo_AI_USB_Maker_V4.sh" "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"
cd "Leonardo Installation File (Shareable)"

# Fix 1: Update version numbers for competition
sed -i 's/# Version 4.0.0/# Version 5.0.0 - International Coding Competition 2025 Edition/' "Leonardo_AI_USB_Maker_V5.sh"
sed -i 's/SCRIPT_VERSION="4.0.0"/SCRIPT_VERSION="5.0.0"/' "Leonardo_AI_USB_Maker_V5.sh"
sed -i 's/USB_LABEL_DEFAULT="CHATUSB"/USB_LABEL_DEFAULT="LEONARDO"/' "Leonardo_AI_USB_Maker_V5.sh"

# Fix 2: Fix 'local' keyword usage outside functions
sed -i 's/^local \([A-Za-z_][A-Za-z0-9_]*\)=/\1=/' "Leonardo_AI_USB_Maker_V5.sh"

# Fix 3: Replace the problematic fancy_download function with our fixed version
FUNC_START=$(grep -n "^fancy_download()" "Leonardo_AI_USB_Maker_V5.sh" | cut -d':' -f1)
FUNC_END=$(grep -n "^}" "Leonardo_AI_USB_Maker_V5.sh" | awk -v start="$FUNC_START" '$1 > start {print $1; exit}')

# Replace the function if we found it
if [ -n "$FUNC_START" ] && [ -n "$FUNC_END" ]; then
    echo "Replacing fancy_download function (lines $FUNC_START-$FUNC_END)..."
    sed -i "${FUNC_START},${FUNC_END}d" "Leonardo_AI_USB_Maker_V5.sh"
    sed -i "${FUNC_START}r fixed_fancy_download.sh" "Leonardo_AI_USB_Maker_V5.sh"
else
    echo "ERROR: Could not locate fancy_download function."
    exit 1
fi

# Fix 4: Add seed file functionality
cat << 'SEEDFUNCTION' > seed_function.sh
# Function to create a seed file for easy distribution
create_seed_file() {
    local target_dir="${1:-"."}"
    local seed_file="$target_dir/leonardo_seed.sh"
    
    print_info "Creating seed file in: $target_dir"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create the seed file
    cat > "$seed_file" << 'SEEDHEADER'
#!/bin/bash
# Leonardo AI USB Maker - SEED FILE
# International Coding Competition 2025 Edition

# Print beautiful header
echo -e "\033[1;36m"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║            LEONARDO AI USB MAKER - SEED INSTALLER              ║"
echo "║                International Competition Edition               ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

# Create the installation directory
echo -e "\033[1;32m[+] Creating installation directory...\033[0m"
mkdir -p "Leonardo Installation File (Shareable)"

# Copy the main script
echo -e "\033[1;32m[+] Installing Leonardo AI USB Maker...\033[0m"
cp "$0" "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"
chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

echo -e "\033[1;32m[+] Installation complete!\033[0m"
echo ""
echo -e "\033[1;36mLeonardo AI USB Maker has been successfully installed!\033[0m"
echo -e "You can find it in the 'Leonardo Installation File (Shareable)' directory."
echo -e "Run it with: cd 'Leonardo Installation File (Shareable)' && ./Leonardo_AI_USB_Maker_V5.sh"
echo ""
SEEDHEADER
    
    # Append this entire script to the seed file
    cat "$0" >> "$seed_file"
    
    # Make the seed file executable
    chmod +x "$seed_file"
    
    print_success "Seed file created successfully at: $seed_file"
    print_info "This seed file can be shared to easily install Leonardo AI USB Maker on other systems."
    return 0
}
SEEDFUNCTION

# Add the seed file creation function to the script
echo "" >> "Leonardo_AI_USB_Maker_V5.sh"
echo "# --- Seed File Generation Function ---" >> "Leonardo_AI_USB_Maker_V5.sh"
cat seed_function.sh >> "Leonardo_AI_USB_Maker_V5.sh"
rm -f seed_function.sh

# Fix 5: Add seed file menu option
sed -i '/^main_menu_options=(/a\    "create_seed_separator" ""\n    "create_seed" "Create Shareable Seed File (Competition Feature)"' "Leonardo_AI_USB_Maker_V5.sh"

# Fix 6: Add handler for the seed creation operation
cat << 'SEEDHANDLER' > seed_handler.sh

    if [[ "$OPERATION_MODE" == "create_seed" ]]; then
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
        OPERATION_MODE=""
        continue
    fi
SEEDHANDLER

# Find a good place to insert the seed handler (after "clear_context" section)
INSERTION_POINT=$(grep -n "if \[\[ \"\$OPERATION_MODE\" == \"clear_context\" \]\]" "Leonardo_AI_USB_Maker_V5.sh" | cut -d':' -f1)
if [ -n "$INSERTION_POINT" ]; then
    # Find the end of that if block
    END_OF_BLOCK=$(tail -n +$INSERTION_POINT "Leonardo_AI_USB_Maker_V5.sh" | grep -n "^    fi$" | head -1 | cut -d':' -f1)
    if [ -n "$END_OF_BLOCK" ]; then
        INSERTION_POINT=$((INSERTION_POINT + END_OF_BLOCK))
        sed -i "${INSERTION_POINT}r seed_handler.sh" "Leonardo_AI_USB_Maker_V5.sh"
    else
        # Fallback insertion before the case statement
        CASE_POINT=$(grep -n "^    case \"\$OPERATION_MODE\" in$" "Leonardo_AI_USB_Maker_V5.sh" | cut -d':' -f1)
        if [ -n "$CASE_POINT" ]; then
            sed -i "${CASE_POINT}r seed_handler.sh" "Leonardo_AI_USB_Maker_V5.sh"
        fi
    fi
fi
rm -f seed_handler.sh

# Fix 7: Remove any duplicate 'fi' statements that might cause syntax errors
while grep -q "fi\s*fi" "Leonardo_AI_USB_Maker_V5.sh"; do
    sed -i 's/fi\s*fi/fi/' "Leonardo_AI_USB_Maker_V5.sh"
done

# Fix 8: Fix any duplicate return statements
sed -i 's/return \$exit_code\s*return 0/return $exit_code/' "Leonardo_AI_USB_Maker_V5.sh" 

# Test the script for syntax errors
echo "Testing for syntax errors..."
bash -n "Leonardo_AI_USB_Maker_V5.sh"

if [ $? -eq 0 ]; then
    echo "✅ Syntax check passed! The script has been fixed successfully."
    chmod +x "Leonardo_AI_USB_Maker_V5.sh"
    
    # Create a seed file as requested
    echo "Creating seed file..."
    cp "Leonardo_AI_USB_Maker_V5.sh" "leonardo_seed.sh"
    chmod +x "leonardo_seed.sh"
    
    echo "All fixes applied! The script should now run without syntax errors."
    echo "You can run it with: ./Leonardo_AI_USB_Maker_V5.sh"
else
    echo "❌ Syntax errors still exist. Further debugging required."
fi
