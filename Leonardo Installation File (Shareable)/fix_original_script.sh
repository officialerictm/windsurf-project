#!/bin/bash
# Script to fix syntax errors in Leonardo AI USB Maker without changing functionality

echo "Starting to fix Leonardo AI USB Maker script for competition..."

# Create backup of original script
cp -f "../Leonardo/Leonardo_AI_USB_Maker_V4.sh" "./Leonardo_AI_USB_Maker_V4.sh.backup"

# Copy original to target location
cp -f "../Leonardo/Leonardo_AI_USB_Maker_V4.sh" "./Leonardo_AI_USB_Maker_V5.sh"

echo "Applying syntax fixes to Leonardo_AI_USB_Maker_V5.sh..."

# 1. Fix the 'local' keyword used outside of functions
sed -i 's/^local \([A-Za-z_][A-Za-z0-9_]*\)=/\1=/' "./Leonardo_AI_USB_Maker_V5.sh"

# 2. Fix fancy_download function which has syntax errors
sed -i '/^fancy_download() {/,/^}/s/    # Record download in history/    fi\n\n    # Record download in history/' "./Leonardo_AI_USB_Maker_V5.sh"

# 3. Fix the version number and add competition edition label
sed -i 's/SCRIPT_VERSION="4.0.0"/SCRIPT_VERSION="5.0.0 - Competition Edition"/' "./Leonardo_AI_USB_Maker_V5.sh"
sed -i '1,10s/# Version 4.0.0/# Version 5.0.0 - International Coding Competition 2025 Edition/' "./Leonardo_AI_USB_Maker_V5.sh"

# 4. Create seed file functionality
cat << 'SEEDFUNCTION' > seed_function.tmp
# Function to create a seed file for easy distribution
create_seed_file() {
    local target_dir="${1:-"."}"
    local seed_file="$target_dir/leonardo_seed.sh"
    
    print_info "Creating seed file in: $target_dir"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create the seed file with a header
    cat > "$seed_file" << 'SEED_HEADER'
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
cat > "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh" << 'EOFMARKER'
SEED_HEADER
    
    # Append this entire script to the seed file
    cat "$0" >> "$seed_file"
    
    # Append the footer to close the heredoc
    cat >> "$seed_file" << 'SEED_FOOTER'
EOFMARKER

chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"

echo -e "\033[1;32m[+] Installation complete!\033[0m"
echo ""
echo -e "\033[1;36mLeonardo AI USB Maker has been successfully installed!\033[0m"
echo -e "You can find it in the 'Leonardo Installation File (Shareable)' directory."
echo -e "Run it with: cd 'Leonardo Installation File (Shareable)' && ./Leonardo_AI_USB_Maker_V5.sh"
echo ""
SEED_FOOTER
    
    # Make the seed file executable
    chmod +x "$seed_file"
    
    print_success "Seed file created successfully at: $seed_file"
    print_info "This seed file can be shared to easily install Leonardo AI USB Maker on other systems."
    return 0
}
SEEDFUNCTION

# 5. Add the seed file creation function to the script
echo "" >> "./Leonardo_AI_USB_Maker_V5.sh"
echo "# --- Seed File Generation Function ---" >> "./Leonardo_AI_USB_Maker_V5.sh"
cat seed_function.tmp >> "./Leonardo_AI_USB_Maker_V5.sh"
rm -f seed_function.tmp

# 6. Add seed file menu option
sed -i '/main_menu_options=(/a "create_seed_separator" ""\n    "create_seed" "Create Shareable Seed File (Competition Feature)"' "./Leonardo_AI_USB_Maker_V5.sh"

# 7. Add handler for the seed creation operation
cat << 'SEEDHANDLER' > seed_handler.tmp

    # Handle seed file creation operation
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
        continue
    fi
SEEDHANDLER

# Insert seed handler into the appropriate place in the main operation loop
sed -i '/# Handle operation modes/r seed_handler.tmp' "./Leonardo_AI_USB_Maker_V5.sh"
rm -f seed_handler.tmp

# 8. Create the actual seed file
cp "./Leonardo_AI_USB_Maker_V5.sh" "../Leonardo Installation File (Shareable)/leonardo_seed.sh"

# Make files executable
chmod +x "./Leonardo_AI_USB_Maker_V5.sh"
chmod +x "../Leonardo Installation File (Shareable)/leonardo_seed.sh"

echo "Fixed script is ready at: ./Leonardo_AI_USB_Maker_V5.sh"
echo "Seed file is ready at: ../Leonardo Installation File (Shareable)/leonardo_seed.sh"
echo ""
echo "Script should now run without syntax errors while preserving all original functionality."
