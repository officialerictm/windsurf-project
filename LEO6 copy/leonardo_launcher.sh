#!/bin/bash
# Leonardo AI Universal Seed Launcher
# This script executes the Leonardo Universal Seed script properly

# Ensure environment is properly set
export TERM=xterm-256color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_SCRIPT="$SCRIPT_DIR/leonardo_universal_seed.sh"

# Source the script to make its functions available
source "$SEED_SCRIPT"

# Clear screen
clear

# Display banner
echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m              Leonardo AI Universal Launcher               \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo -e "\033[1;32mLaunching Leonardo AI Universal Seed version $SCRIPT_VERSION\033[0m\n"

# Call the main function with all arguments
main "$@"

# Exit with the return code from main
exit $?
