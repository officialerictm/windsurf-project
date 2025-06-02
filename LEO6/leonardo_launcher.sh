#!/bin/bash
# Leonardo AI Universal Seed Launcher
# This script executes the Leonardo Universal Seed script properly with required privileges

# Ensure environment is properly set
export TERM=xterm-256color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_SCRIPT="$SCRIPT_DIR/leonardo_universal_seed.sh"

# Check for root privileges
check_root() {
    # If LEONARDO_SKIP_ROOT_CHECK is set, skip the root check
    if [[ -n "${LEONARDO_SKIP_ROOT_CHECK:-}" ]]; then
        echo -e "\n\033[1;33mWarning: Root check skipped due to LEONARDO_SKIP_ROOT_CHECK=1\033[0m"
        echo "Will continue without root. USB operations will be in test mode only."
        export LEONARDO_NO_ROOT=1
        export LEONARDO_TEST_MODE=1
        sleep 2
        return 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "\n\033[1;33mWarning: Not running as root.\033[0m"
        echo "USB creation and some other features require root privileges."
        echo -e "\nWould you like to:"
        echo "  1. Restart with sudo (recommended for USB operations)"
        echo "  2. Continue without root (limited functionality)"
        echo "  3. Exit"
        echo -e "\n(Default: 2 - Continue without root in this testing environment)"
        echo -en "Enter your choice [1-3]: "
        
        # For automated testing, just use a variable to capture input
        # This allows us to use printf to pipe in choices
        choice=${REPLY:-""}
        
        # If no input or empty, default to option 2 in this testing environment
        if [[ -z "$choice" ]]; then
            echo "\nNo input - defaulting to option 2 (Continue without root)"
            choice=2
        fi
        
        case $choice in
            1)
                if [[ -n "${LEONARDO_NO_SUDO:-}" ]]; then
                    echo -e "\nSudo not available in this environment."
                    echo "Continuing without root in test mode...\n"
                    export LEONARDO_NO_ROOT=1
                    export LEONARDO_TEST_MODE=1
                    sleep 1
                    return 1
                else
                    echo -e "\nRestarting with sudo...\n"
                    exec sudo "$0" "$@"
                    # If exec fails, we'll see this message
                    echo -e "\033[1;31m[ERROR] Failed to execute sudo command!\033[0m"
                    echo "Please run this script with sudo manually:"
                    echo "sudo $0"
                    echo "\nContinuing without root in test mode...\n"
                    export LEONARDO_NO_ROOT=1
                    export LEONARDO_TEST_MODE=1
                    return 1
                fi
                ;;
            2|"")
                echo -e "\nContinuing without root. USB operations will be in test mode only.\n"
                export LEONARDO_NO_ROOT=1
                export LEONARDO_TEST_MODE=1
                sleep 2
                return 1
                ;;
            *)
                echo -e "\nExiting.\n"
                exit 0
                ;;
        esac
    fi
    return 0
}

# Source the script to make its functions available
source "$SEED_SCRIPT"

# Clear screen
clear

# Display banner
echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m              Leonardo AI Universal Launcher               \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo -e "\033[1;32mLaunching Leonardo AI Universal Seed version $SCRIPT_VERSION\033[0m\n"

# Check for root privileges before proceeding
HAS_ROOT=true
if ! check_root "$@"; then
    HAS_ROOT=false
fi

# Call the main function with all arguments
if [[ "$HAS_ROOT" == "true" ]]; then
    main "$@"
else
    # Set a special environment variable to indicate we're running without root
    # This will be used by the script to disable USB creation operations
    export LEONARDO_NO_ROOT=true
    main "$@"
fi

# Exit with the return code from main
exit $?
