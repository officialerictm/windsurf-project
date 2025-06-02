create_seed_file() {
    local target_dir="$1"
    local seed_file="$target_dir/leonardo_seed.sh"
    
    print_info "Creating seed file in: $target_dir"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create the seed file - using echo statements instead of nested heredocs
    # to avoid syntax issues
    
    # Create header
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
    echo 'cat > "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh" << \'EOFSCRIPT\'' >> "$seed_file"
    
    # Append the entire script content
    cat "$0" >> "$seed_file"
    
    # Close the heredoc and add final instructions
    echo 'EOFSCRIPT' >> "$seed_file"
    echo '' >> "$seed_file"
    echo 'chmod +x "Leonardo Installation File (Shareable)/Leonardo_AI_USB_Maker_V5.sh"' >> "$seed_file"
    echo 'echo "Leonardo AI USB Maker has been successfully installed!"' >> "$seed_file"
    echo 'echo "You can find it in the \'Leonardo Installation File (Shareable)\' directory."' >> "$seed_file"
    
    # Make the seed file executable
    chmod +x "$seed_file"
    
    print_success "Seed file created successfully at: $seed_file"
    print_info "This seed file can be shared to easily install Leonardo AI USB Maker on other systems."
    return 0
}
