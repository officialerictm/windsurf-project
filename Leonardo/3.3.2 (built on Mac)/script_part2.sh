# --- Trap for cleanup ---
trap cleanup_temp_files EXIT INT TERM

# --- QoL: Call Root Privilege Check Early ---
check_root_privileges

# --- Main Script Loop ---
while true; do
    INSTALL_START_TIME=$(date +%s)
    if $TPUT_CLEAR_POSSIBLE && [ -n "$TPUT_CMD_PATH" ] ; then
        "$TPUT_CMD_PATH" clear
    else
        printf '\033[H\033[2J'
    fi
    print_leonardo_title_art
    check_bash_version
    echo -e "${C_BOLD}${C_WHITE}--- $SCRIPT_SELF_NAME (Version: $SCRIPT_VERSION) ---${C_RESET}"
    echo -e "${C_WHITE}--- Portable Ollama USB Suite (Leonardo Edition - Security Enhanced!) ---${C_RESET}"

    print_info "What would you like to do?"
    print_divider_thin
    print_option "1" "Create a NEW Leonardo AI USB drive"
    print_option "2" "Manage an EXISTING Leonardo AI USB drive"
    print_divider_thin
    print_option "3" "Upgrade/Patch Existing USB to Latest Version"
    print_option "4" "Dry Run / System Check (No changes made)"
    print_option "5" "Utility: Clear USB context (affects next run & exits script)"
    print_divider_thin
    print_option "6" "About this Script"
    print_option "q" "Quit"
    
    # Read user input directly rather than using show_menu
    print_prompt "Enter your choice: "
    read main_op_choice
    
    # Map numeric choices to operation modes
    case "$main_op_choice" in
        1) main_op_choice="create_new" ;;
        2) main_op_choice="manage_existing" ;;
        3) main_op_choice="upgrade_usb" ;;
        4) main_op_choice="dry_run" ;;
        5) main_op_choice="clear_context" ;;
        6) main_op_choice="about_script" ;;
        q|Q) main_op_choice="q" ;;
        *) print_error "Invalid choice. Please try again."; sleep 2; continue ;;
    esac


    if [[ "$main_op_choice" == "q" ]]; then
        print_info "Quitting script. Goodbye! 👋"; exit 0
    fi

    OPERATION_MODE="$main_op_choice"

    # Process the menu selection
    case "$OPERATION_MODE" in
        create_new)
            clear_screen_and_show_art
            print_header "Creating NEW Leonardo AI USB Drive"
            check_host_dependencies "full"
            ;;
        manage_existing)
            clear_screen_and_show_art
            print_header "Managing EXISTING Leonardo AI USB Drive"
            ;;
        upgrade_usb)
            clear_screen_and_show_art
            print_header "Upgrading Existing Leonardo AI USB"
            check_host_dependencies "full"
            # Will implement the upgrade logic
            ;;
        clear_context)
            clear_usb_context
            clear_screen_and_show_art
            print_success "USB context cleared. Changes will take effect on next run."
            exit 0
            ;;
        about_script)
            clear_screen_and_show_art
            print_header "📜 ABOUT THIS SCRIPT 📜"
            echo -e "${C_BOLD}Script Name:${C_RESET} $SCRIPT_SELF_NAME"
            echo -e "${C_BOLD}Version:${C_RESET}     $SCRIPT_VERSION"
            echo -e "${C_DIM}----------------------------------------------------------------------${C_RESET}"
            echo -e "This script helps you create and manage portable USB drives with Ollama"
            echo -e "and selected AI models, allowing you to run a local AI environment"
            echo -e "on Linux, macOS, and Windows computers from the USB stick."
            echo -e ""
            echo -e "It includes features for:"
            echo -e "  - Formatting the USB (optional, exFAT recommended)"
            echo -e "  - Downloading Ollama runtimes for selected OSes"
            echo -e "  - Pulling AI models from Ollama or importing local GGUF files"
            echo -e "  - Generating launcher scripts for easy startup on target OSes"
            echo -e "  - A simple Web UI for chatting with models on the USB"
            echo -e "  - Integrity verification tools"
            echo -e "  - Management of models on an existing Leonardo AI USB"
            echo -e "${C_DIM}----------------------------------------------------------------------${C_RESET}"
            echo -e "Brought to you by Eric & Your Friendly AI Assistant."
            echo -e "Remember to check the ${C_BOLD}SECURITY_README.txt${C_RESET} on the generated USB!"
            echo ""
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            OPERATION_MODE=""
            continue
            ;;
        upgrade_usb)
            clear_screen_and_show_art
            print_header "Upgrading Existing Leonardo AI USB"
            check_host_dependencies "full"
            upgrade_existing_usb
            ;;
        *)
            if [[ "$OPERATION_MODE" != "dry_run" ]]; then
                print_fatal "Invalid selection. Please try again."
            fi
{{ ... }}
            ;;
    esac

    # Handle dry run separately to maintain existing logic
    if [[ "$OPERATION_MODE" == "dry_run" ]]; then
        print_header "🔎 DRY RUN / SYSTEM CHECK 🔎"
        print_info "This mode checks dependencies and detects devices without making any changes."
        print_line
        check_host_dependencies "full"
        print_line
        print_subheader "📡 Checking Ollama Release URL Fetching..."
        if $USE_GITHUB_API; then
            if get_latest_ollama_release_urls; then
                print_info "Latest URLs from GitHub:"
                printf "  Linux:   %s\n" "${LINUX_URL:-Not found}"
                printf "  macOS:   %s\n" "${MAC_URL:-Not found}"
                printf "  Windows: %s\n" "${WINDOWS_ZIP_URL:-Not found}"
            else
                print_warning "Could not fetch from GitHub API. Fallback URLs would be used:"
                printf "  Linux:   %s\n" "$FALLBACK_LINUX_URL"
                printf "  macOS:   %s\n" "$FALLBACK_MAC_URL"
                printf "  Windows: %s\n" "$FALLBACK_WINDOWS_ZIP_URL"
            fi
        else
            print_info "GitHub API is disabled. Fallback URLs that would be used:"
            printf "  Linux:   %s\n" "$FALLBACK_LINUX_URL"
            printf "  macOS:   %s\n" "$FALLBACK_MAC_URL"
            printf "  Windows: %s\n" "$FALLBACK_WINDOWS_ZIP_URL"
        fi
        print_line
        print_subheader "💻 Checking Host Ollama Status..."
        if command -v ollama &> /dev/null; then
            print_info "Ollama CLI found."
            if ollama --version &> /dev/null; then
                print_success "Ollama version: $(ollama --version)"
            else
                print_warning "Ollama CLI found, but 'ollama --version' failed."
            fi
            if ollama list > /dev/null 2>&1; then
                print_success "Ollama service is responsive on host."
                echo -e "${C_BLUE}Host's available models:${C_RESET}"
                ollama list | sed 's/^/  /' # Indent output
            else
                print_warning "Ollama service is NOT responsive on host."
            fi
        else
            print_error "Ollama CLI ('ollama') not found on host."
        fi
        print_line
        ask_usb_device "list_only"
        print_line
        print_success "Dry Run / System Check complete. No changes were made."
        echo ""
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        OPERATION_MODE="" 
        continue
    fi

    if [[ "$OPERATION_MODE" == "about_script" ]]; then
        print_header "📜 ABOUT THIS SCRIPT 📜"
        echo -e "${C_BOLD}Script Name:${C_RESET} $SCRIPT_SELF_NAME"
        echo -e "${C_BOLD}Version:${C_RESET}     $SCRIPT_VERSION"
        echo -e "${C_DIM}----------------------------------------------------------------------${C_RESET}"
        echo -e "This script helps you create and manage portable USB drives with Ollama"
        echo -e "and selected AI models, allowing you to run a local AI environment"
        echo -e "on Linux, macOS, and Windows computers from the USB stick."
        echo -e ""
        echo -e "It includes features for:"
        echo -e "  - Formatting the USB (optional, exFAT recommended)"
        echo -e "  - Downloading Ollama runtimes for selected OSes"
        echo -e "  - Pulling AI models from Ollama or importing local GGUF files"
        echo -e "  - Generating launcher scripts for easy startup on target OSes"
        echo -e "  - A simple Web UI for chatting with models on the USB"
        echo -e "  - Integrity verification tools"
        echo -e "  - Management of models on an existing Leonardo AI USB"
        echo -e "${C_DIM}----------------------------------------------------------------------${C_RESET}"
        echo -e "Brought to you by Eric & Your Friendly AI Assistant."
        echo -e "Remember to check the ${C_BOLD}SECURITY_README.txt${C_RESET} on the generated USB!"
        echo ""
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        OPERATION_MODE=""
        continue
    fi


    if [[ "$OPERATION_MODE" == "clear_context" ]]; then
        print_info "Clearing remembered USB drive context..."
        USB_DEVICE_PATH=""
        RAW_USB_DEVICE_PATH=""
        USB_BASE_PATH=""
        MOUNT_POINT=""
        USB_LABEL="$USB_LABEL_DEFAULT"
        print_success "USB context has been cleared."
        print_info "This will take effect the next time you run the script."
        print_info "Exiting now. Please re-run the script to use the cleared context."
        sleep 1
        exit 0
    fi


    if [[ "$OPERATION_MODE" == "create_new" ]]; then
        USB_LABEL="$USB_LABEL_DEFAULT"
        ask_usb_device
        ask_format_usb
    elif [[ "$OPERATION_MODE" == "manage_existing" ]]; then
        if [ -z "$USB_DEVICE_PATH" ] || [ -z "$USB_BASE_PATH" ]; then
            USB_LABEL="$USB_LABEL_DEFAULT"
            ask_usb_device
        else
            confirm_active_usb_choice_val=""
            print_double_line
            echo -e "${C_BOLD}${C_YELLOW}🤔 CONFIRM ACTIVE USB 🤔${C_RESET}"
            while true; do
                print_prompt "Currently targeting USB: ${C_BOLD}$USB_DEVICE_PATH${C_RESET} (Label: ${C_GREEN}${USB_LABEL}${C_RESET} at ${C_GREEN}${USB_BASE_PATH:-Not Mounted}${C_RESET}). Continue? ([C]ontinue/[S]elect new/[M]ain menu): "
                read -r confirm_active_usb_choice_val
                confirm_active_usb_choice_val=$(echo "$confirm_active_usb_choice_val" | tr '[:upper:]' '[:lower:]')
                case "$confirm_active_usb_choice_val" in
                    c) print_info "Continuing with $USB_DEVICE_PATH."; break;;
                    s) USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; ask_usb_device; break;;
                    m) OPERATION_MODE=""; continue 2;;
                    *) print_warning "Invalid input.";;
                esac
            done
             print_double_line; echo ""
        fi

        while true;
        do
            if ! ensure_usb_mounted_and_writable; then
                print_error "Failed to ensure USB is mounted and writable. Returning to main menu."
                OPERATION_MODE="" ; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue 2
            fi

            manage_menu_prompt="Selected USB: ${C_BOLD}${USB_DEVICE_PATH}${C_RESET} (Label: ${C_GREEN}${USB_LABEL}${C_RESET} at ${C_GREEN}${USB_BASE_PATH}${C_RESET})\nWhat would you like to do?"
            manage_menu_options=(
                "list_usb_models" "List Models on selected USB (with sizes if jq is available)"
                "add_llm" "Add another LLM to selected USB"
                "remove_llm" "Remove an LLM from selected USB"
                "repair_scripts" "Repair/Refresh Leonardo scripts & UI on selected USB"
            )
            manage_choice=""
            show_menu "Manage Existing Leonardo AI USB" "$manage_menu_prompt" manage_choice "${manage_menu_options[@]}"

            if [[ "$manage_choice" == "b" ]]; then
                OPERATION_MODE=""
                continue 2
            fi
            OPERATION_MODE="$manage_choice"
            break
        done
    fi

    print_info "Selected operation: ${C_BOLD}$OPERATION_MODE${C_RESET}"
    print_line; echo ""

    if [[ "$OPERATION_MODE" != "create_new" ]] && [[ "$OPERATION_MODE" != "q" ]] && [[ "$OPERATION_MODE" != "" ]]; then
        if ! ensure_usb_mounted_and_writable; then
            print_error "Critical error: Failed to ensure USB is mounted and writable for operation '$OPERATION_MODE'. Returning to main menu."
            OPERATION_MODE=""; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue
        fi
    fi

    # --- Execute Specific Operation ---
    case "$OPERATION_MODE" in
        create_new)
            check_host_dependencies "full"
            ask_target_os_binaries
            ask_llm_model # This now calls calculate_total_estimated_models_size_gb

            print_header "📝 PRE-FLIGHT CHECK (NEW USB) 📝"
            echo -e "${C_BLUE}Please review your selections before proceeding:${C_RESET}"
            echo -e "  - Target USB Drive:          ${C_BOLD}$USB_DEVICE_PATH${C_RESET} (Target Label after format: ${C_BOLD}$USB_LABEL_DEFAULT${C_RESET})"
            echo -e "  - Format USB Drive:          ${C_BOLD}$FORMAT_USB_CHOICE${C_RESET}"
            if [[ "$FORMAT_USB_CHOICE" == "yes" ]]; then
                 echo -e "    (Filesystem: exFAT, Label to be set: ${C_BOLD}$USB_LABEL_DEFAULT${C_RESET})"
            else
                 echo -e "    (Using existing format. Current detected label for operations: ${C_BOLD}$USB_LABEL${C_RESET})"
            fi
            echo -e "  - Ollama Runtimes for:       ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_BINARIES_SIZE_GB GB${C_RESET})"
            echo -e "  - AI Model(s) to Install:    ${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET})"
            if [[ "$MODEL_SOURCE_TYPE" == "create_local" ]]; then
                echo -e "    (Source for '${MODELS_TO_INSTALL_LIST[0]}': Local GGUF file '${C_DIM}$LOCAL_GGUF_PATH_FOR_IMPORT${C_RESET}')"
            fi
            print_line; echo ""
            FINAL_CONFIRMATION_CHOICE=""
            ask_yes_no_quit "Do you want to proceed with these settings? (Choosing 'No' or 'Quit' will return to main menu)" FINAL_CONFIRMATION_CHOICE
            if [[ "$FINAL_CONFIRMATION_CHOICE" != "yes" ]]; then
                print_info "Operation cancelled by user. Returning to main menu."
                OPERATION_MODE=""; USB_DEVICE_PATH=""; RAW_USB_DEVICE_PATH=""; USB_BASE_PATH=""; MOUNT_POINT=""; USB_LABEL="$USB_LABEL_DEFAULT"; continue
            fi
            print_success "Configuration confirmed. Proceeding with USB creation... Hold on to your Llama! 🦙💨"
            echo "";

            if [[ "$FORMAT_USB_CHOICE" == "yes" ]]; then
                echo -e "\n${C_BOLD}${C_RED}**********************************************************************${C_RESET}"
                echo -e "${C_BOLD}${C_RED}** 💣 ATTENTION: Formatting ${USB_DEVICE_PATH} is about to begin.       **${C_RESET}";
                echo -e "${C_BOLD}${C_RED}** This is the ABSOLUTE LAST CHANCE to cancel before data loss.     **${C_RESET}"
                echo -e "${C_BOLD}${C_RED}**********************************************************************${C_RESET}"; PROCEED_FORMAT_CHOICE=""
                ask_yes_no_quit "${C_RED}${C_BOLD}LAST CHANCE: Really proceed with formatting $USB_DEVICE_PATH?${C_RESET}" PROCEED_FORMAT_CHOICE
                if [[ "$PROCEED_FORMAT_CHOICE" == "yes" ]]; then
                    print_info "⚙️ Formatting $USB_DEVICE_PATH..."
                    
                    if [[ "$(uname)" == "Linux" ]]; then
                        # For Linux
                        # Determine the partition path
                        if [[ "$USB_DEVICE_PATH" == *nvme*n* ]] || [[ "$USB_DEVICE_PATH" == *mmcblk* ]]; then
                           USB_PARTITION_PATH="${USB_DEVICE_PATH}p1"
                        else
                           USB_PARTITION_PATH="${USB_DEVICE_PATH}1"
                        fi
                        
                        # Unmount all partitions from the device
                        print_info "Unmounting any existing partitions..."
                        sudo umount "$USB_DEVICE_PATH"* 2>/dev/null
                        
                        # Create a new partition table and exFAT partition
                        print_info "Creating new partition table on $USB_DEVICE_PATH..."
                        sudo parted -s "$USB_DEVICE_PATH" mklabel msdos
                        sudo parted -s "$USB_DEVICE_PATH" mkpart primary fat32 1MiB 100%
                        
                        # Format as exFAT (or fallback to FAT32 if exFAT tools not available)
                        print_info "Formatting partition as exFAT with label $USB_LABEL_DEFAULT..."
                        if command -v mkfs.exfat > /dev/null 2>&1; then
                            sudo mkfs.exfat -n "$USB_LABEL_DEFAULT" "$USB_PARTITION_PATH"
                        elif command -v exfatformat > /dev/null 2>&1; then
                            sudo exfatformat -n "$USB_LABEL_DEFAULT" "$USB_PARTITION_PATH"
                        else
                            print_warning "exFAT formatting tools not found. Falling back to FAT32 (4GB file size limit)..."
                            sudo mkfs.vfat -F 32 -n "$USB_LABEL_DEFAULT" "$USB_PARTITION_PATH"
                        fi
                        
                    elif [[ "$(uname)" == "Darwin" ]]; then
                        # For macOS
                        print_info "Unmounting disk before formatting..."
                        diskutil unmountDisk force "$USB_DEVICE_PATH" > /dev/null 2>&1
                        
                        print_info "Formatting disk as exFAT with label '$USB_LABEL'..."
                        if ! diskutil eraseDisk ExFAT "$USB_LABEL" "$RAW_USB_DEVICE_PATH"; then
                            print_fatal "Disk format operation failed. Please check the device and try again."
                        fi
                        print_success "Formatting complete!"
                        
                        # After formatting, explicitly find and set the mount point
                        print_info "Locating newly formatted volume..."
                        sleep 2  # Give the system a moment to register the new volume
                        
                        # Find the new mount point directly
                        # First identify the partition
                        formatted_partition="${USB_DEVICE_PATH}s1"
                        if ! diskutil list | grep -q "$formatted_partition"; then
                            print_warning "Could not identify partition after formatting. Will try mountDisk instead."
                            if ! diskutil mountDisk "$USB_DEVICE_PATH"; then
                                print_warning "mountDisk failed. Will attempt to proceed anyway."
                            fi
                        else
                            print_info "Found partition $formatted_partition, mounting..."
                            if ! diskutil mount "$formatted_partition"; then
                                print_warning "Mount failed. Will attempt one more method."
                                diskutil mountDisk "$USB_DEVICE_PATH"
                            fi
                        fi
                    fi
                    
                    USB_LABEL="$USB_LABEL_DEFAULT"
                    print_success "Formatting complete!"
                    
                    # For macOS we should already be mounted from the formatting steps
                    # For Linux we need to mount the drive
                    print_info "Finding mount point for the newly formatted USB drive..."
                    
                    # Reset the base path
                    USB_BASE_PATH=""
                    sleep 3 # Give the system a moment to recognize the new filesystem
                    
                    if [[ "$(uname)" == "Darwin" ]]; then
                        # Extensive macOS mount point detection
                        print_info "Searching for mounted USB drive..."
                        
                        # Method 1: Direct check using the label we set
                        if [ -d "/Volumes/$USB_LABEL" ]; then
                            USB_BASE_PATH="/Volumes/$USB_LABEL"
                            MOUNT_POINT="$USB_BASE_PATH"
                            print_success "Found mounted USB with matching label at $USB_BASE_PATH"
                        else
                            # Method 2: Check using diskutil info
                            local disk_info=$(diskutil info "$USB_DEVICE_PATH" 2>/dev/null)
                            local mount_point=$(echo "$disk_info" | grep -i "Mount Point" | sed -e 's/.*Mount Point:[[:space:]]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                            
                            if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
                                USB_BASE_PATH="$mount_point"
                                MOUNT_POINT="$mount_point"
                                print_success "Found mounted USB using diskutil at $USB_BASE_PATH"
                            else
                                # Method 3: Try individual disk slice
                                for slice in "${USB_DEVICE_PATH}s1" "${USB_DEVICE_PATH}s2"; do
                                    print_info "Checking slice $slice..."
                                    local slice_info=$(diskutil info "$slice" 2>/dev/null)
                                    local slice_mount=$(echo "$slice_info" | grep -i "Mount Point" | sed -e 's/.*Mount Point:[[:space:]]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                                    
                                    if [ -n "$slice_mount" ] && [ -d "$slice_mount" ]; then
                                        USB_BASE_PATH="$slice_mount"
                                        MOUNT_POINT="$slice_mount"
                                        print_success "Found mounted USB on slice $slice at $USB_BASE_PATH"
                                        break
                                    fi
                                done
                                
                                # Method 4: Try to mount explicitly if still not found
                                if [ -z "$USB_BASE_PATH" ] || [ ! -d "$USB_BASE_PATH" ]; then
                                    print_info "Mount point still not found. Trying explicit mount..."
                                    
                                    # Get the most recently mounted volume as a fallback
                                    local volumes_before=$(ls -1 /Volumes/)
                                    
                                    # Try to mount explicitly
                                    diskutil mountDisk "$USB_DEVICE_PATH" &>/dev/null || true
                                    sleep 2
                                    
                                    # Look for any new volumes that appeared
                                    local volumes_after=$(ls -1 /Volumes/)
                                    local new_volume=$(comm -13 <(echo "$volumes_before" | sort) <(echo "$volumes_after" | sort) | head -1)
                                    
                                    if [ -n "$new_volume" ] && [ -d "/Volumes/$new_volume" ]; then
                                        USB_BASE_PATH="/Volumes/$new_volume"
                                        MOUNT_POINT="$USB_BASE_PATH"
                                        print_success "Found newly mounted USB at $USB_BASE_PATH"
                                    else
                                        # Method 5: Last resort - just pick the most recently modified volume
                                        local latest_volume=$(ls -t /Volumes/ | grep -v "Macintosh HD" | head -1)
                                        if [ -n "$latest_volume" ] && [ -d "/Volumes/$latest_volume" ]; then
                                            USB_BASE_PATH="/Volumes/$latest_volume"
                                            MOUNT_POINT="$USB_BASE_PATH"
                                            print_warning "Using best guess for USB mount: $USB_BASE_PATH"
                                        else
                                            # If we still don't have a mount point, try one last mounting method
                                            print_info "All detection methods failed. Using ensure_usb_mounted_and_writable as last resort..."
                                            if ! ensure_usb_mounted_and_writable; then
                                                print_fatal "Failed to mount USB after formatting. Please check the drive and try again.";
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    else
                        # For Linux, use ensure_usb_mounted_and_writable
                        print_info "Attempting to mount the newly formatted drive..."
                        if ! ensure_usb_mounted_and_writable; then 
                            print_fatal "Failed to mount USB after formatting. Please check the drive and try again."; 
                        fi
                    fi
                    
                    # Verify that we have a valid mount point
                    if [ -z "$USB_BASE_PATH" ] || ! [ -d "$USB_BASE_PATH" ]; then
                        print_fatal "Could not determine mount point for the formatted USB drive."
                    fi
                    
                    # Verify we can write to it
                    if ! sudo touch "$USB_BASE_PATH/.write_test" 2>/dev/null; then
                        print_fatal "The mounted USB drive is not writable. Check permissions or remount."
                    else
                        sudo rm "$USB_BASE_PATH/.write_test"
                    fi
                else
                    print_info "Formatting cancelled by user. Script will proceed assuming drive is already formatted as exFAT with label $USB_LABEL."
                    FORMAT_USB_CHOICE="no"
                    if ! ensure_usb_mounted_and_writable; then print_fatal "Failed to mount unformatted USB. Please check the drive and try again."; fi
                fi
            elif [[ "$FORMAT_USB_CHOICE" == "no" ]]; then
                print_info "Skipping formatting as per user choice. Will attempt to use $USB_DEVICE_PATH as-is."
                print_info "Ensure it is formatted (preferably exFAT with label '$USB_LABEL' for easiest auto-mount) and has enough space."
                if ! ensure_usb_mounted_and_writable; then print_fatal "Failed to mount unformatted USB. Please check the drive and try again."; fi
            fi
            echo
            check_disk_space "${MODELS_TO_INSTALL_LIST[*]}" "$MODEL_SOURCE_TYPE" "$LOCAL_GGUF_PATH_FOR_IMPORT" false

            print_info "⚙️ Creating directory structure on $USB_BASE_PATH..."
            sudo mkdir -p "$USB_BASE_PATH/.ollama/models" "$USB_BASE_PATH/Data/tmp" "$USB_BASE_PATH/Data/logs" "$USB_BASE_PATH/webui"
            sudo mkdir -p "$USB_BASE_PATH/runtimes/linux/bin" "$USB_BASE_PATH/runtimes/linux/lib" \
                       "$USB_BASE_PATH/runtimes/mac/bin" "$USB_BASE_PATH/runtimes/mac/lib" \
                       "$USB_BASE_PATH/runtimes/win/bin" \
                       "$USB_BASE_PATH/Installation_Info"
            sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/Data" "$USB_BASE_PATH/webui" "$USB_BASE_PATH/.ollama" "$USB_BASE_PATH/Installation_Info"
            print_success "Directory structure created."

            TMP_DOWNLOAD_DIR=$(mktemp -d)
            print_info "Temporary download directory for binaries: ${C_DIM}$TMP_DOWNLOAD_DIR${C_RESET}"

            print_subheader "⏬ Downloading Ollama binaries based on selection: $SELECTED_OS_TARGETS..."
            if $USE_GITHUB_API; then
                if ! get_latest_ollama_release_urls; then
                    print_warning "Falling back to hardcoded URLs due to GitHub API issue.";
                    LINUX_URL="$FALLBACK_LINUX_URL"; MAC_URL="$FALLBACK_MAC_URL"; WINDOWS_ZIP_URL="$FALLBACK_WINDOWS_ZIP_URL";
                fi
            else
                print_info "Using hardcoded URLs (USE_GITHUB_API=false).";
                LINUX_URL="$FALLBACK_LINUX_URL"; MAC_URL="$FALLBACK_MAC_URL"; WINDOWS_ZIP_URL="$FALLBACK_WINDOWS_ZIP_URL";
            fi

            DOWNLOAD_CMD_BASE=""
            if command -v curl &> /dev/null; then DOWNLOAD_CMD_BASE="curl -L --progress-bar -o";
            elif command -v wget &> /dev/null; then DOWNLOAD_CMD_BASE="wget --show-progress -O";
            else print_fatal "Neither curl nor wget found. Dependency check should have caught this."; fi

            if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then
                print_info "--- Downloading Linux Ollama ---"; echo -e "  URL: ${C_DIM}$LINUX_URL${C_RESET}"
                LINUX_TARBALL="$TMP_DOWNLOAD_DIR/ollama-linux.tgz"
                if ! $DOWNLOAD_CMD_BASE "$LINUX_TARBALL" "$LINUX_URL"; then print_fatal "Download failed for Linux Ollama."; fi
                if [ ! -s "$LINUX_TARBALL" ]; then print_fatal "Linux tarball is empty after download attempt."; fi; print_success "Linux binaries downloaded."
                print_info "Extracting Linux binaries to host temporary directory..."; HOST_LINUX_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/host_linux_extract"; mkdir -p "$HOST_LINUX_EXTRACT_DIR"
                if ! tar -xzf "$LINUX_TARBALL" -C "$HOST_LINUX_EXTRACT_DIR" --strip-components=0; then print_fatal "Failed to extract Linux tarball."; fi; print_success "Host extraction for Linux binaries successful."; OLLAMA_BIN_SOURCE=""; LIBS_SOURCE_DIR=""
                if [ -f "$HOST_LINUX_EXTRACT_DIR/bin/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/bin/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/lib"; fi
                elif [ -f "$HOST_LINUX_EXTRACT_DIR/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/lib"; fi
                elif [ -f "$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/ollama" ]; then OLLAMA_BIN_SOURCE="$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/ollama"; if [ -d "$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/lib" ]; then LIBS_SOURCE_DIR="$HOST_LINUX_EXTRACT_DIR/usr/share/ollama/lib"; fi
                else print_fatal "Could not find 'ollama' binary in the extracted Linux archive (checked common paths (./bin/ollama, ./ollama, ./usr/share/ollama/ollama))."; fi
                print_info "Found Linux ollama binary at: ${C_DIM}$OLLAMA_BIN_SOURCE${C_RESET}"; if [ -n "$LIBS_SOURCE_DIR" ]; then print_info "Found Linux libs directory at: ${C_DIM}$LIBS_SOURCE_DIR${C_RESET}"; fi
                print_info "Moving Linux binary to USB..."; sudo cp "$OLLAMA_BIN_SOURCE" "$USB_BASE_PATH/runtimes/linux/bin/ollama"; sudo chmod +x "$USB_BASE_PATH/runtimes/linux/bin/ollama"
                if [ -n "$LIBS_SOURCE_DIR" ] && [ -d "$LIBS_SOURCE_DIR" ] && [ -n "$(ls -A "$LIBS_SOURCE_DIR" 2>/dev/null)" ]; then
                    print_info "Copying Linux libraries to USB...";
                    sudo mkdir -p "$USB_BASE_PATH/runtimes/linux/lib/"
                    if sudo cp -RL "$LIBS_SOURCE_DIR"/* "$USB_BASE_PATH/runtimes/linux/lib/"; then print_success "Linux libraries copied successfully."; else print_warning "Copying Linux libraries failed. This might cause issues."; fi
                else print_info "No separate 'lib' directory found or it was empty for Linux binaries. This is usually fine for statically linked binaries."; fi
                rm -rf "$HOST_LINUX_EXTRACT_DIR"
            fi

            if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then
                print_info "--- Downloading macOS Ollama ---"; echo -e "  URL: ${C_DIM}$MAC_URL${C_RESET}"
                MAC_TARBALL="$TMP_DOWNLOAD_DIR/ollama-mac.tgz"
                if ! $DOWNLOAD_CMD_BASE "$MAC_TARBALL" "$MAC_URL"; then print_fatal "Download failed for macOS Ollama."; fi
                if [ ! -s "$MAC_TARBALL" ]; then print_fatal "macOS tarball is empty after download attempt."; fi; print_success "macOS binaries downloaded."
                HOST_MAC_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/host_mac_extract"; sudo mkdir -p "$HOST_MAC_EXTRACT_DIR";
                tar -xzf "$MAC_TARBALL" -C "$HOST_MAC_EXTRACT_DIR" --strip-components=0 || print_warning "tar extraction for macOS might have had non-fatal errors. Continuing extraction attempt..."
                print_success "macOS extraction to host temp attempted."

                OLLAMA_MAC_BIN_CANDIDATE_ROOT="$HOST_MAC_EXTRACT_DIR/ollama"
                OLLAMA_MAC_BIN_CANDIDATE_APP="$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Resources/ollama"
                OLLAMA_MAC_RUNNER_CANDIDATE_ROOT="$HOST_MAC_EXTRACT_DIR/ollama-runner"
                OLLAMA_MAC_RUNNER_CANDIDATE_APP="$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/MacOS/ollama-runner"


                if [ -f "$OLLAMA_MAC_BIN_CANDIDATE_ROOT" ]; then sudo cp "$OLLAMA_MAC_BIN_CANDIDATE_ROOT" "$USB_BASE_PATH/runtimes/mac/bin/ollama"
                elif [ -f "$OLLAMA_MAC_BIN_CANDIDATE_APP" ]; then print_info "Detected Ollama.app structure for macOS binary."; sudo cp "$OLLAMA_MAC_BIN_CANDIDATE_APP" "$USB_BASE_PATH/runtimes/mac/bin/ollama"
                else print_fatal "Could not find 'ollama' binary in the extracted macOS archive (checked ./ollama and inside .app)."; fi
                sudo chmod +x "$USB_BASE_PATH/runtimes/mac/bin/ollama"

                if [ -f "$OLLAMA_MAC_RUNNER_CANDIDATE_ROOT" ]; then sudo cp "$OLLAMA_MAC_RUNNER_CANDIDATE_ROOT" "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner"; sudo chmod +x "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner"
                elif [ -f "$OLLAMA_MAC_RUNNER_CANDIDATE_APP" ]; then sudo cp "$OLLAMA_MAC_RUNNER_CANDIDATE_APP" "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner"; sudo chmod +x "$USB_BASE_PATH/runtimes/mac/bin/ollama-runner";
                else print_info "'ollama-runner' not found in macOS archive. This is usually okay for portable server use if 'ollama serve' works."; fi

                if [ -d "$HOST_MAC_EXTRACT_DIR/lib" ] && [ -n "$(ls -A "$HOST_MAC_EXTRACT_DIR/lib" 2>/dev/null)" ]; then
                    print_info "Copying macOS libraries...";
                    sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
                    sudo cp -RL "$HOST_MAC_EXTRACT_DIR/lib"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS libraries copy failed or no libs found.";
                elif [ -d "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks" ]; then
                     print_info "Copying macOS Frameworks...";
                     sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
                     sudo cp -RL "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS Frameworks copy failed.";
                else print_info "No separate 'lib' or 'Frameworks' directory found or it was empty for macOS binaries. This is often normal."; fi
                rm -rf "$HOST_MAC_EXTRACT_DIR"; print_success "macOS binaries processed."
            fi

            if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
                print_info "--- Downloading Windows Ollama ---"; echo -e "  URL: ${C_DIM}$WINDOWS_ZIP_URL${C_RESET}"
                WINDOWS_ZIP="$TMP_DOWNLOAD_DIR/ollama-windows.zip"
                if ! $DOWNLOAD_CMD_BASE "$WINDOWS_ZIP" "$WINDOWS_ZIP_URL"; then print_fatal "Download failed for Windows Ollama."; fi
                if [ ! -s "$WINDOWS_ZIP" ]; then print_fatal "Windows ZIP is empty after download attempt."; fi; print_success "Windows binaries downloaded."
                print_info "Extracting Windows binaries to host temporary directory...";
                WIN_TMP_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/win_extract"; mkdir -p "$WIN_TMP_EXTRACT_DIR"
                if ! unzip -qjo "$WINDOWS_ZIP" -d "$WIN_TMP_EXTRACT_DIR/"; then
                    print_fatal "Failed to unzip Windows archive to temp dir.";
                fi
                if [ ! -f "$WIN_TMP_EXTRACT_DIR/ollama.exe" ]; then
                    print_fatal "'ollama.exe' not found after temp extraction from Windows ZIP.";
                fi;
                print_info "Copying Windows binaries to USB...";
                sudo cp "$WIN_TMP_EXTRACT_DIR"/* "$USB_BASE_PATH/runtimes/win/bin/"
                rm -rf "$WIN_TMP_EXTRACT_DIR"
                print_success "Windows binaries extracted and copied to USB."
            fi
            sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/runtimes"
            
            # Generate all necessary launcher files and support files
            generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"
            ;;
        add_llm)
            if [ ! -d "$USB_BASE_PATH/.ollama/models" ] || [ ! -d "$USB_BASE_PATH/runtimes" ]; then
                print_error "The selected drive at $USB_BASE_PATH does not appear to be a valid Leonardo AI USB."
                print_error "   Essential directories (.ollama/models or runtimes) are missing."
                print_fatal "   Cannot add LLM. Please select a valid Leonardo AI USB or create a new one."
            fi
            print_success "Valid Leonardo AI USB detected for adding new LLM."
            check_host_dependencies "minimal_for_manage"
            ask_llm_model # This now calls calculate_total_estimated_models_size_gb
            check_disk_space "${MODELS_TO_INSTALL_LIST[*]}" "$MODEL_SOURCE_TYPE" "$LOCAL_GGUF_PATH_FOR_IMPORT" true
            ;;
        repair_scripts)
            if [ ! -d "$USB_BASE_PATH/.ollama/models" ] || [ ! -d "$USB_BASE_PATH/runtimes" ]; then
                print_fatal "The selected drive at $USB_BASE_PATH does not appear to be a valid Leonardo AI USB."
            fi
            print_success "Valid Leonardo AI USB detected. Proceeding with Repair/Refresh."
            check_host_dependencies "minimal_for_manage"

            DETECTED_OS_TARGETS=""
            [ -d "$USB_BASE_PATH/runtimes/linux/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}linux,"
            [ -d "$USB_BASE_PATH/runtimes/mac/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}mac,"
            [ -d "$USB_BASE_PATH/runtimes/win/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}win,"
            SELECTED_OS_TARGETS=${DETECTED_OS_TARGETS%,}
            if [ -z "$SELECTED_OS_TARGETS" ]; then
                print_fatal "No runtime directories found on the USB. Cannot determine which launchers to repair."
            fi
            print_info "Will regenerate launchers for detected OS runtimes: $SELECTED_OS_TARGETS"

            MODEL_TO_PULL="llama3:8b"
            first_model_on_usb=""
            first_model_on_usb=$( (sudo find "$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null || true) | (
                IFS= read -r -d $'\0' tag_file_path
                if [ -n "$tag_file_path" ] && [ -f "$tag_file_path" ]; then
                    relative_path="${tag_file_path#$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library/}"
                    echo "${relative_path%/*}:${relative_path##*/}"
                fi
            ) )

            if [ -n "$first_model_on_usb" ]; then
                MODEL_TO_PULL="$first_model_on_usb"
                print_info "Using existing model '$MODEL_TO_PULL' as default for regenerated Web UI."
            else
                print_warning "Could not determine existing model on USB. Web UI will default to: $MODEL_TO_PULL (Launchers/UI will offer choice if multiple models exist)."
            fi
            ;;
        list_usb_models)
            check_host_dependencies "minimal_for_manage"
            list_models_on_usb "$USB_BASE_PATH"
            OPERATION_MODE="manage_existing_loop_continue"
            ;;
        remove_llm)
            check_host_dependencies "minimal_for_manage"
            remove_model_from_usb "$USB_BASE_PATH"
            print_info "Refreshing launchers and checksums after model removal..."
            DETECTED_OS_TARGETS=""
            [ -d "$USB_BASE_PATH/runtimes/linux/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}linux,"
            [ -d "$USB_BASE_PATH/runtimes/mac/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}mac,"
            [ -d "$USB_BASE_PATH/runtimes/win/bin" ] && DETECTED_OS_TARGETS="${DETECTED_OS_TARGETS}win,"
            SELECTED_OS_TARGETS=${DETECTED_OS_TARGETS%,}

            MODEL_TO_PULL="llama3:8b"
            first_model_after_remove=""
            first_model_after_remove=$( (sudo find "$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library" -mindepth 2 -maxdepth 2 -type f ! -name '.*' -print0 2>/dev/null || true) | (
                IFS= read -r -d $'\0' tag_file_path
                if [ -n "$tag_file_path" ] && [ -f "$tag_file_path" ]; then
                    relative_path="${tag_file_path#$USB_BASE_PATH/.ollama/models/manifests/registry.ollama.ai/library/}"
                    echo "${relative_path%/*}:${relative_path##*/}"
                fi
            ) )
            if [ -n "$first_model_after_remove" ]; then
                MODEL_TO_PULL="$first_model_after_remove"
            else
                print_warning "All models seem to have been removed. WebUI will default to $MODEL_TO_PULL (but no models are present for selection in UI)."
            fi
            ;;
        *)
            print_fatal "Unknown operation mode '$OPERATION_MODE'"
            ;;
    esac

    if [[ "$OPERATION_MODE" == "create_new" ]] || [[ "$OPERATION_MODE" == "add_llm" ]] || [[ "$OPERATION_MODE" == "repair_scripts" ]] || [[ "$OPERATION_MODE" == "remove_llm" ]]; then
        if [ -z "$USB_BASE_PATH" ] || ! sudo test -d "$USB_BASE_PATH"; then
            print_error "USB_BASE_PATH ('$USB_BASE_PATH') is not set or not a directory. Cannot generate USB support files."
        else
            generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"
        fi
    fi
    
    # Process macOS libraries if they exist
    if [ -d "$HOST_MAC_EXTRACT_DIR/lib" ] && [ -n "$(ls -A "$HOST_MAC_EXTRACT_DIR/lib" 2>/dev/null)" ]; then
        print_info "Copying macOS libraries...";
        sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
        sudo cp -RL "$HOST_MAC_EXTRACT_DIR/lib"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS libraries copy failed or no libs found.";
    elif [ -d "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks" ]; then
        print_info "Copying macOS Frameworks...";
        sudo mkdir -p "$USB_BASE_PATH/runtimes/mac/lib/"
        sudo cp -RL "$HOST_MAC_EXTRACT_DIR/Ollama.app/Contents/Frameworks"/* "$USB_BASE_PATH/runtimes/mac/lib/" 2>/dev/null || print_warning "macOS Frameworks copy failed.";
    else 
        print_info "No separate 'lib' or 'Frameworks' directory found or it was empty for macOS binaries. This is often normal."; 
    fi
    
    if [ -d "$HOST_MAC_EXTRACT_DIR" ]; then
        rm -rf "$HOST_MAC_EXTRACT_DIR"; 
        print_success "macOS binaries processed."
    fi

    # Process Windows binaries if needed
    if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then
        print_info "--- Downloading Windows Ollama ---"; echo -e "  URL: ${C_DIM}$WINDOWS_ZIP_URL${C_RESET}"
        WINDOWS_ZIP="$TMP_DOWNLOAD_DIR/ollama-windows.zip"
        if ! $DOWNLOAD_CMD_BASE "$WINDOWS_ZIP" "$WINDOWS_ZIP_URL"; then print_fatal "Download failed for Windows Ollama."; fi
        if [ ! -s "$WINDOWS_ZIP" ]; then print_fatal "Windows ZIP is empty after download attempt."; fi; print_success "Windows binaries downloaded."
        print_info "Extracting Windows binaries to host temporary directory...";
        WIN_TMP_EXTRACT_DIR="$TMP_DOWNLOAD_DIR/win_extract"; mkdir -p "$WIN_TMP_EXTRACT_DIR"
        if ! unzip -qjo "$WINDOWS_ZIP" -d "$WIN_TMP_EXTRACT_DIR/"; then
            print_fatal "Failed to unzip Windows archive to temp dir.";
        fi
        if [ ! -f "$WIN_TMP_EXTRACT_DIR/ollama.exe" ]; then
            print_fatal "'ollama.exe' not found after temp extraction from Windows ZIP.";
        fi;
        print_info "Copying Windows binaries to USB...";
        sudo cp "$WIN_TMP_EXTRACT_DIR"/* "$USB_BASE_PATH/runtimes/win/bin/"
        rm -rf "$WIN_TMP_EXTRACT_DIR"
        print_success "Windows binaries extracted and copied to USB."
    fi
    # Ensure proper permissions and generate launcher files
    if [ -d "$USB_BASE_PATH/runtimes" ]; then
        sudo chown -R "$(id -u):$(id -g)" "$USB_BASE_PATH/runtimes"
    fi
    
    # This call was moved to the main conditional block above, but we're keeping it here 
    # as a fallback in case it wasn't executed in the proper place
    if [ -d "$USB_BASE_PATH" ] && [ -n "$MODEL_TO_PULL" ]; then
        print_info "Ensuring launcher files and support files are generated..."
        generate_usb_files "$USB_BASE_PATH" "$MODEL_TO_PULL"
    fi
    
    # End of the initial setup code - original code continues below

    # Here we'll ensure that if we're in any of these operation modes and we've reached this point,
    # the operation has been completed successfully
    if [[ "$OPERATION_MODE" == "create_new" ]] || [[ "$OPERATION_MODE" == "add_llm" ]] || \
       [[ "$OPERATION_MODE" == "repair_scripts" ]] || [[ "$OPERATION_MODE" == "remove_llm" ]]; then
        print_info "Operation $OPERATION_MODE completed successfully."
    fi
    
    # Clear any temporary variables
    unset HOST_MAC_EXTRACT_DIR
    unset WIN_TMP_EXTRACT_DIR
    
    # This is a simplified case statement for post-processing steps if needed
    case "$OPERATION_MODE" in
        add_llm)
            # Any additional add_llm specific cleanup steps would go here
            print_info "LLM added successfully to USB drive."
            ;;
        repair_scripts)
            # Any additional repair_scripts specific cleanup steps would go here
            print_info "Scripts repaired successfully."
            ;;
        remove_llm)
            # Any additional remove_llm specific cleanup steps would go here
            print_info "LLM removed successfully from USB drive."
            ;;
        create_new)
            # Any additional create_new specific cleanup steps would go here
            print_info "New Leonardo AI USB created successfully."
            ;;
        *)
            # Default case - nothing to do
            ;;
    esac

    # Calculate installation time
    INSTALL_END_TIME=$(date +%s)
    ELAPSED_SECONDS=$((INSTALL_END_TIME - INSTALL_START_TIME))

    get_grade_msg() {
        local category="$1"; local idx=$((RANDOM % 3))
        local fast=("Blink and you missed it. ⚡️" "Faster than a Llama on espresso! 🚀" "AI booted before you blinked. 🦾")
        local med=("Efficient, like a well-oiled Llama. 🚆" "Quick, but not showing off. 🏎️" "Solid pace—no wasted cycles. 🤖")
        local slow=("Had a snack mid-install? 🍔 Your Llama took a nap. 😴" "USB took the scenic route. 🐢" "Slow dance with the bits. 🪩")
        local epic=("Watched a movie while waiting? 📽️" "Is your USB drive a glacier? ❄️" "Time for a CPU upgrade... 🛠️")

        case "$category" in
            fast) echo "${fast[$idx]}";;
            med) echo "${med[$idx]}";;
            slow) echo "${slow[$idx]}";;
            epic) echo "${epic[$idx]}";;
            *) echo "Done! 🎉";;
        esac
    }
    
    # Set grade category based on elapsed time
    GRADE_CATEGORY=""
    if [ "$ELAPSED_SECONDS" -lt 120 ]; then 
        GRADE_CATEGORY="fast"
    elif [ "$ELAPSED_SECONDS" -lt 300 ]; then 
        GRADE_CATEGORY="med"
    elif [ "$ELAPSED_SECONDS" -lt 900 ]; then 
        GRADE_CATEGORY="slow"
    else 
        GRADE_CATEGORY="epic"
    fi

    print_leonardo_success_art
    if [[ "$OPERATION_MODE" == "repair_scripts" ]]; then
        print_header "✅ USB Repair/Refresh Complete! ✅"
        echo -e "USB drive '${C_BOLD}$USB_LABEL${C_RESET}' at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET} has been refreshed."
        echo -e "Launchers regenerated for: ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET}"
        echo -e "Web UI default model hint set to: ${C_BOLD}$MODEL_TO_PULL${C_RESET} (Launchers/UI will offer choice from all models on USB)."
    elif [[ "$OPERATION_MODE" == "add_llm" ]]; then
        print_header "✅ New LLM(s) Added Successfully! ✅"
        echo -e "Model(s) '${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET}' (Est. Size: ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET}) added to USB drive '${C_BOLD}$USB_LABEL${C_RESET}' at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET}."
        echo -e "Launchers and Web UI have been updated."
        elif [[ "$OPERATION_MODE" == "remove_llm" ]]; then
            print_header "✅ LLM Manifest Removed Successfully! ✅"
            echo -e "Selected LLM manifest removed from USB drive '${C_BOLD}$USB_LABEL${C_RESET}' at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET}."
            echo -e "Launchers and Web UI have been updated. Default WebUI model hint now: ${C_BOLD}$MODEL_TO_PULL${C_RESET}"
            print_warning "Remember: Blobs (model data) might still exist. Re-create USB for full space reclaim if needed."
        else
            print_header "🎉 Setup Complete! 🎉"
            echo -e "USB drive '${C_BOLD}$USB_LABEL${C_RESET}' created at ${C_GREEN}${MOUNT_POINT:-$USB_BASE_PATH}${C_RESET}."
            echo -e "Installed OS Runtimes: ${C_BOLD}$SELECTED_OS_TARGETS${C_RESET} (Est. Size: ${C_BOLD}$ESTIMATED_BINARIES_SIZE_GB GB${C_RESET})"
            echo -e "Installed AI Model(s) (Primary/Default Hint for WebUI): ${C_BOLD}$MODEL_TO_PULL${C_RESET}"
            if [ ${#MODELS_TO_INSTALL_LIST[@]} -gt 0 ]; then
                 echo -e "All installed models for this session: ${C_BOLD}${MODELS_TO_INSTALL_LIST[*]}${C_RESET} (Est. Total Size: ${C_BOLD}$ESTIMATED_MODELS_SIZE_GB GB${C_RESET})"
            fi
        fi
        echo ""
        print_info "Operation completed in ${C_BOLD}$((ELAPSED_SECONDS / 60)) min $((ELAPSED_SECONDS % 60)) sec${C_RESET}."
        echo -e "${C_CYAN}Forge Speed Grade: $(get_grade_msg "$GRADE_CATEGORY")${C_RESET}"
        echo ""
        print_subheader "To use your Leonardo AI USB:"
        echo -e "  1. Safely eject/unmount the USB drive from this computer (if not done by script)."
        echo -e "  2. Plug it into the target computer (Linux, macOS, or Windows, depending on runtimes installed)."
        echo -e "  3. Open the USB drive in the file explorer."
        echo -e "  4. Run the appropriate launcher script from the root of the USB drive:"
        if [[ "$SELECTED_OS_TARGETS" == *"linux"* ]]; then echo -e "     - On Linux:   ${C_GREEN}./${USER_LAUNCHER_NAME_BASE}.sh${C_RESET}"; fi
        if [[ "$SELECTED_OS_TARGETS" == *"mac"* ]]; then echo -e "     - On macOS:   Double-click ${C_GREEN}${USER_LAUNCHER_NAME_BASE}.command${C_RESET} (or run from Terminal)"; fi
        if [[ "$SELECTED_OS_TARGETS" == *"win"* ]]; then echo -e "     - On Windows: Double-click ${C_GREEN}${USER_LAUNCHER_NAME_BASE}.bat${C_RESET}"; fi
        echo -e "  5. Follow the prompts in the launcher window (select a model if multiple are present)."
        echo -e "  6. The Web UI will open in your browser, allowing you to select any available model."
        echo ""
        print_info "Remember to check ${C_BOLD}SECURITY_README.txt${C_RESET} on the USB (also copied to Installation_Info/ folder) for important usage guidelines."
        print_info "Verify file integrity with ${C_GREEN}./verify_integrity.sh${C_RESET} (Linux/Mac) or ${C_GREEN}verify_integrity.bat${C_RESET} (Windows) on the USB."
        echo ""
        print_info "Note on AI Model Behavior: If the AI model gives strange or repetitive responses, try closing the Ollama Server window"
        print_info "and re-running the Leonardo launcher. This often resets the model's context."
        echo ""
        echo -e "${C_MAGENTA}As EricTM says to his AI, Milo: \"Your success is entirely dependent upon mine.\"${C_RESET}"
        echo -e "${C_MAGENTA}We hope this USB brings you success in your AI endeavors!${C_RESET}"
        echo ""

        UNMOUNT_CHOICE=""
        current_mount_path_for_unmount="${MOUNT_POINT:-$USB_BASE_PATH}"
        if [ -n "$current_mount_path_for_unmount" ] && sudo mount | grep -qF "$current_mount_path_for_unmount"; then
            ask_yes_no_quit "Do you want to attempt to unmount ${C_BOLD}$current_mount_path_for_unmount${C_RESET} now?" UNMOUNT_CHOICE
            if [[ "$UNMOUNT_CHOICE" == "yes" ]]; then
                print_info "Attempting to unmount... please wait for this to complete before unplugging."
                sync; sync
                if [[ "$(uname)" == "Darwin" ]]; then
                    if sudo diskutil unmount "$current_mount_path_for_unmount" 2>/dev/null; then
                        print_success "$USB_LABEL ($current_mount_path_for_unmount) unmounted successfully.";
                    elif sudo diskutil unmountDisk "$RAW_USB_DEVICE_PATH" 2>/dev/null; then
                        print_success "$USB_LABEL (disk $RAW_USB_DEVICE_PATH) unmounted successfully.";
                    else
                        print_warning "Failed to unmount $USB_LABEL. Please unmount manually before unplugging.";
                    fi
                else
                    if sudo umount "$current_mount_path_for_unmount"; then print_success "$USB_LABEL ($current_mount_path_for_unmount) unmounted successfully.";
                    else print_warning "Failed to unmount $current_mount_path_for_unmount. It might be busy. Try 'sudo umount -l $current_mount_path_for_unmount' or unmount manually."; fi
                fi
            else
                print_info "Okay, please remember to safely eject/unmount '$USB_LABEL' from your system before unplugging it."
            fi
        fi
        echo -e "\n${C_BOLD}${C_GREEN}All done. Go forth and AI! ✨${C_RESET}"
        exit 0
    if [[ "$OPERATION_MODE" == "manage_existing_loop_continue" ]]; then
        OPERATION_MODE="manage_existing"
        continue
    else
        print_info "Operation '$OPERATION_MODE' concluded or was aborted. Returning to main menu."
        OPERATION_MODE=""
        USB_DEVICE_PATH=""
        RAW_USB_DEVICE_PATH=""
        USB_BASE_PATH=""
        MOUNT_POINT=""
        USB_LABEL="$USB_LABEL_DEFAULT"
        continue
    fi

done
exit 0