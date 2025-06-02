#!/bin/bash
# ==============================================================================
# Goodbye Screen for Leonardo AI USB Maker
# ==============================================================================

# Display a friendly goodbye screen with llama mascot
show_goodbye_screen() {
    clear_screen_and_show_art
    
    # Print gradient divider
    print_gradient_divider
    
    # Goodbye box with farewell message
    echo -e "${COLOR_CYAN}╭──────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│  ${COLOR_BOLD}${COLOR_GRADIENT_2}Thank you for using Leonardo AI USB Maker!${COLOR_RESET}                 ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│  We hope you enjoyed forging your portable AI future with us.    │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│  If you found this tool helpful, please consider:                │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   • Starring our repository on GitHub                            │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   • Reporting any issues you encountered                         │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   • Sharing with fellow AI enthusiasts                           │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                                                                  │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    
    # Show happy llama mascot waving goodbye
    echo ""
    echo -e "           ${COLOR_YELLOW}(•ᴗ•)/ 🦙${COLOR_RESET}"
    echo -e "           ${COLOR_DIM}Farewell, AI explorer!${COLOR_RESET}"
    echo ""
    
    # Final message with a touch of humor
    echo -e "${COLOR_GRADIENT_1}May your AI models run smoothly and your USB drives remain uncorrupted!${COLOR_RESET}"
    echo ""
    
    # Pause briefly to allow reading the message
    sleep 2
}

# Exit the application gracefully
exit_application() {
    show_goodbye_screen
    log "User exited the application"
    exit 0
}
