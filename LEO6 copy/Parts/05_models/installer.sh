# ==============================================================================
# Model Installation
# ==============================================================================
# Description: Handles installation of AI models to USB devices
# Author: Leonardo AI Team
# Version: 6.0.0
# Depends: 00_core/config.sh,00_core/logging.sh,02_ui/basic.sh,04_network/download.sh,05_models/registry.sh
# ==============================================================================

# Install a model to the USB device
install_model() {
    local model_id="$1"
    local usb_path="$2"
    local partition_number="${3:-1}"
    
    # Get model information
    local model_name=$(get_model_info "$model_id" "name")
    local model_url=$(get_model_info "$model_id" "url")
    local model_checksum=$(get_model_info "$model_id" "checksum")
    local model_size=$(get_model_info "$model_id" "size")
    local model_reqs=$(get_model_info "$model_id" "requirements")
    
    log_message "INFO" "Installing model: $model_id ($model_name) to $usb_path"
    
    # Check if model exists
    if ! model_exists "$model_id"; then
        show_error "Model $model_id not found in registry"
        return 1
    fi
    
    # Check if URL is available
    if [[ -z "$model_url" ]]; then
        show_error "No download URL available for $model_name"
        return 1
    fi
    
    # Verify USB device
    if [[ ! -b "$usb_path" ]]; then
        show_error "Invalid USB device path: $usb_path"
        return 1
    fi
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    if [[ ! -b "$partition" ]]; then
        show_error "Partition ${partition} not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_install_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    show_step_header "Mounting USB Device" "$UI_WIDTH"
    echo -e "Mounting ${CYAN}$partition${NC} to ${CYAN}$mount_point${NC}..."
    
    if ! mount "$partition" "$mount_point"; then
        show_error "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Create the model directory structure
    local models_dir="$mount_point/leonardo/models"
    local model_dir="$models_dir/$model_id"
    
    mkdir -p "$model_dir"
    
    # Show download information
    show_step_header "Downloading $model_name" "$UI_WIDTH"
    
    # Format model size for display
    local display_size
    if [[ "$model_size" -gt 1024 ]]; then
        display_size="$(echo "scale=2; $model_size / 1024" | bc) GB"
    else
        display_size="$model_size MB"
    fi
    
    # Show download info with friendly llama
    echo -e "${YELLOW}(•ᴗ•)🦙${NC} Downloading ${GREEN}$model_name${NC}"
    echo -e "     Size: ${CYAN}$display_size${NC}"
    echo -e "     Destination: ${CYAN}$model_dir${NC}"
    echo ""
    
    # Check available space
    local available_space
    available_space=$(df -m "$mount_point" | awk 'NR==2 {print $4}')
    
    log_message "DEBUG" "Available space: ${available_space}MB, Required: ${model_size}MB"
    
    if [[ "$available_space" -lt "$model_size" ]]; then
        show_error "Not enough space on USB device. Available: ${available_space}MB, Required: ${model_size}MB"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Calculate filename from URL
    local filename=$(basename "$model_url")
    
    # Download the model
    if ! download_file "$model_url" "$model_dir/$filename" true true; then
        show_error "Failed to download $model_name"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Verify checksum if available
    if [[ -n "$model_checksum" ]]; then
        show_step_header "Verifying $model_name" "$UI_WIDTH"
        echo -e "Verifying file integrity..."
        
        if ! verify_checksum "$model_dir/$filename" "$model_checksum" "sha256"; then
            show_warning "Checksum verification failed for $model_name" "caution"
            echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}The downloaded file may be corrupted or incomplete.${NC}"
            echo -e "     Do you want to keep the downloaded file anyway?"
            
            if ! confirm_action "Keep the downloaded file?"; then
                echo -e "Removing downloaded file..."
                rm -f "$model_dir/$filename"
                umount "$mount_point"
                rmdir "$mount_point"
                return 1
            fi
        else
            show_success "Checksum verification passed"
        fi
    fi
    
    # Create the model metadata file
    local metadata_file="$model_dir/metadata.json"
    
    cat > "$metadata_file" << EOF
{
  "id": "$model_id",
  "name": "$model_name",
  "description": "$(get_model_info "$model_id" "description")",
  "version": "1.0.0",
  "size": $model_size,
  "files": [
    "$filename"
  ],
  "requirements": "$model_reqs",
  "installation_date": "$(date +%Y-%m-%d)",
  "download_url": "$model_url",
  "checksum": "$model_checksum"
}
EOF
    
    # Create an info.txt file with basic usage instructions
    local info_file="$model_dir/info.txt"
    
    cat > "$info_file" << EOF
Model: $model_name ($model_id)
Installed: $(date +%Y-%m-%d)
Size: $display_size

Requirements:
$(echo "$model_reqs" | sed 's/,/\n/g' | sed 's/:/: /g')

Usage Instructions:
- This model is ready to use with Leonardo AI Universal
- For API-based models, ensure you have the necessary API keys configured
- Refer to the documentation for specific usage examples
- Do not delete or modify any files in this directory

For support, visit: https://windsurf.io/leonardo
EOF
    
    # Update the main models index
    local index_file="$models_dir/index.json"
    
    # Create the directory structure if it doesn't exist
    mkdir -p "$(dirname "$index_file")"
    
    # Create or update the index file
    if [[ -f "$index_file" ]]; then
        # Check if jq is available for proper JSON manipulation
        if command -v jq &>/dev/null; then
            # Use jq to add model to array without parsing the whole file
            jq --arg id "$model_id" --arg name "$model_name" \
               '.models += [{"id": $id, "name": $name, "path": "'$model_id'"}]' \
               "$index_file" > "$index_file.tmp" && mv "$index_file.tmp" "$index_file"
        else
            # Simple append (not ideal but works without jq)
            # First remove the last two lines (closing brackets)
            head -n -2 "$index_file" > "$index_file.tmp"
            
            # Check if we need to add a comma
            if grep -q "\"id\":" "$index_file.tmp"; then
                echo "  }," >> "$index_file.tmp"
            else
                echo "  }" >> "$index_file.tmp"
            fi
            
            # Add the new model entry
            cat >> "$index_file.tmp" << EOF
  {
    "id": "$model_id",
    "name": "$model_name",
    "path": "$model_id"
  }
]
}
EOF
            # Replace the original file
            mv "$index_file.tmp" "$index_file"
        fi
    else
        # Create new index file
        cat > "$index_file" << EOF
{
  "last_updated": "$(date +%Y-%m-%d)",
  "models": [
    {
      "id": "$model_id",
      "name": "$model_name",
      "path": "$model_id"
    }
  ]
}
EOF
    fi
    
    # Update USB health data
    if [[ "$USB_HEALTH_TRACKING" == "true" ]]; then
        # Convert model size to bytes
        local size_bytes=$(( model_size * 1024 * 1024 ))
        update_usb_health_data "$partition" "$size_bytes"
    fi
    
    # Unmount the partition
    echo -e "Unmounting USB device..."
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Show success message
    show_success "$model_name has been installed successfully"
    
    return 0
}

# List installed models on USB device
list_installed_models() {
    local usb_path="$1"
    local partition_number="${2:-1}"
    local format="${3:-table}"  # table, list, or json
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    
    log_message "INFO" "Listing installed models on $partition in format: $format"
    
    # Check if device exists
    if [[ ! -b "$partition" ]]; then
        log_message "ERROR" "Partition $partition not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_list_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "$partition" "$mount_point"; then
        log_message "ERROR" "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if models directory exists
    local models_dir="$mount_point/leonardo/models"
    if [[ ! -d "$models_dir" ]]; then
        log_message "WARNING" "No models directory found on $partition"
        umount "$mount_point"
        rmdir "$mount_point"
        
        if [[ "$format" == "json" ]]; then
            echo '{"models": []}'
        else
            echo "No models installed on this device."
        fi
        return 0
    fi
    
    # Read models from index file or scan directories
    local index_file="$models_dir/index.json"
    local installed_models=()
    local model_names=()
    local model_sizes=()
    
    if [[ -f "$index_file" ]]; then
        # Read from index file if available
        if command -v jq &>/dev/null; then
            # Use jq to parse JSON if available
            while IFS= read -r line; do
                installed_models+=("$line")
            done < <(jq -r '.models[].id' "$index_file" 2>/dev/null)
            
            while IFS= read -r line; do
                model_names+=("$line")
            done < <(jq -r '.models[].name' "$index_file" 2>/dev/null)
        else
            # Simple grep parsing without jq
            while IFS= read -r line; do
                if [[ "$line" =~ \"id\":\ *\"([^\"]+)\" ]]; then
                    installed_models+=("${BASH_REMATCH[1]}")
                fi
                
                if [[ "$line" =~ \"name\":\ *\"([^\"]+)\" ]]; then
                    model_names+=("${BASH_REMATCH[1]}")
                fi
            done < "$index_file"
        fi
    else
        # Scan directories if no index file
        for model_dir in "$models_dir"/*; do
            if [[ -d "$model_dir" ]]; then
                local model_id=$(basename "$model_dir")
                installed_models+=("$model_id")
                
                # Try to get name from metadata
                local metadata_file="$model_dir/metadata.json"
                if [[ -f "$metadata_file" ]]; then
                    local name
                    if command -v jq &>/dev/null; then
                        name=$(jq -r '.name' "$metadata_file" 2>/dev/null)
                    else
                        name=$(grep -o '"name": *"[^"]*"' "$metadata_file" | sed 's/"name": *"\(.*\)"/\1/')
                    fi
                    model_names+=("$name")
                else
                    model_names+=("$model_id")
                fi
            fi
        done
    fi
    
    # Get model sizes
    for i in "${!installed_models[@]}"; do
        local model_dir="$models_dir/${installed_models[$i]}"
        local size_mb=0
        
        # Try to get size from metadata
        local metadata_file="$model_dir/metadata.json"
        if [[ -f "$metadata_file" ]]; then
            if command -v jq &>/dev/null; then
                size_mb=$(jq -r '.size' "$metadata_file" 2>/dev/null)
            else
                size_mb=$(grep -o '"size": *[0-9]*' "$metadata_file" | sed 's/"size": *\([0-9]*\)/\1/')
            fi
        fi
        
        # If metadata doesn't have size, calculate from files
        if [[ -z "$size_mb" || "$size_mb" == "null" || "$size_mb" -eq 0 ]]; then
            local size_bytes=$(du -sb "$model_dir" | cut -f1)
            size_mb=$(( size_bytes / 1024 / 1024 ))
        fi
        
        model_sizes+=("$size_mb")
    done
    
    # Output based on format
    case "$format" in
        table)
            # Print header
            printf "%-15s %-30s %-10s\n" "ID" "NAME" "SIZE"
            printf "%-15s %-30s %-10s\n" "---------------" "------------------------------" "----------"
            
            # Print each model
            for i in "${!installed_models[@]}"; do
                local id="${installed_models[$i]}"
                local name="${model_names[$i]}"
                local size="${model_sizes[$i]}"
                
                # Format size
                if [[ $size -ge 1024 ]]; then
                    size="$(echo "scale=1; $size / 1024" | bc) GB"
                else
                    size="$size MB"
                fi
                
                printf "%-15s %-30s %-10s\n" "$id" "$name" "$size"
            done
            ;;
        
        list)
            # Print each model on a line
            for i in "${!installed_models[@]}"; do
                local id="${installed_models[$i]}"
                local name="${model_names[$i]}"
                local size="${model_sizes[$i]}"
                
                # Format size
                if [[ $size -ge 1024 ]]; then
                    size="$(echo "scale=1; $size / 1024" | bc) GB"
                else
                    size="$size MB"
                fi
                
                echo "$id: $name ($size)"
            done
            ;;
        
        json)
            # Print as JSON
            echo "{"
            echo "  \"models\": ["
            
            local first=true
            for i in "${!installed_models[@]}"; do
                if [[ "$first" != "true" ]]; then
                    echo ","
                fi
                first=false
                
                local id="${installed_models[$i]}"
                local name="${model_names[$i]}"
                local size="${model_sizes[$i]}"
                
                echo -n "    {"
                echo -n "\"id\":\"$id\","
                echo -n "\"name\":\"$name\","
                echo -n "\"size\":$size"
                echo -n "}"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        
        *)
            log_message "WARNING" "Unknown format: $format"
            ;;
    esac
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    return 0
}

# Remove a model from USB device
remove_model() {
    local model_id="$1"
    local usb_path="$2"
    local partition_number="${3:-1}"
    
    log_message "INFO" "Removing model $model_id from $usb_path"
    
    # Get partition path
    local partition="${usb_path}${partition_number}"
    
    # Check if device exists
    if [[ ! -b "$partition" ]]; then
        show_error "Partition $partition not found"
        return 1
    fi
    
    # Create temporary mount point
    local mount_point="$TMP_DIR/model_remove_mount"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "$partition" "$mount_point"; then
        show_error "Failed to mount $partition"
        rmdir "$mount_point"
        return 1
    fi
    
    # Check if model exists
    local model_dir="$mount_point/leonardo/models/$model_id"
    if [[ ! -d "$model_dir" ]]; then
        show_error "Model $model_id not found on USB device"
        umount "$mount_point"
        rmdir "$mount_point"
        return 1
    fi
    
    # Get model name and size
    local model_name="$model_id"
    local model_size=0
    
    # Try to get name and size from metadata
    local metadata_file="$model_dir/metadata.json"
    if [[ -f "$metadata_file" ]]; then
        if command -v jq &>/dev/null; then
            model_name=$(jq -r '.name' "$metadata_file" 2>/dev/null)
            model_size=$(jq -r '.size' "$metadata_file" 2>/dev/null)
        else
            model_name=$(grep -o '"name": *"[^"]*"' "$metadata_file" | sed 's/"name": *"\(.*\)"/\1/')
            model_size=$(grep -o '"size": *[0-9]*' "$metadata_file" | sed 's/"size": *\([0-9]*\)/\1/')
        fi
    fi
    
    # If metadata doesn't have size, calculate from files
    if [[ -z "$model_size" || "$model_size" == "null" || "$model_size" -eq 0 ]]; then
        local size_bytes=$(du -sb "$model_dir" | cut -f1)
        model_size=$(( size_bytes / 1024 / 1024 ))
    fi
    
    # Format size for display
    local display_size
    if [[ "$model_size" -gt 1024 ]]; then
        display_size="$(echo "scale=2; $model_size / 1024" | bc) GB"
    else
        display_size="$model_size MB"
    fi
    
    # Show warning with mischievous llama
    show_warning "You are about to remove $model_name ($model_id)" "caution"
    echo -e "${ORANGE}(>‿-)🦙${NC} ${ORANGE}This will free up ${CYAN}$display_size${ORANGE} of space.${NC}"
    echo -e "     All model files will be permanently deleted."
    echo ""
    
    # Confirm deletion
    if ! confirm_action "Remove this model?"; then
        echo -e "Operation cancelled."
        umount "$mount_point"
        rmdir "$mount_point"
        return 0
    fi
    
    # Remove the model directory
    rm -rf "$model_dir"
    
    # Update the index file if it exists
    local index_file="$mount_point/leonardo/models/index.json"
    if [[ -f "$index_file" ]]; then
        if command -v jq &>/dev/null; then
            # Use jq to remove model from array
            jq --arg id "$model_id" '.models = [.models[] | select(.id != $id)]' \
               "$index_file" > "$index_file.tmp" && mv "$index_file.tmp" "$index_file"
        else
            # Simple grep/sed based removal (not as reliable)
            grep -v "\"id\": *\"$model_id\"" "$index_file" > "$index_file.tmp"
            mv "$index_file.tmp" "$index_file"
        fi
    fi
    
    # Update USB health data
    if [[ "$USB_HEALTH_TRACKING" == "true" ]]; then
        # We don't track removals in write cycles, but it's a good idea to update the timestamp
        update_usb_health_data "$partition" 0
    fi
    
    # Unmount the partition
    umount "$mount_point"
    rmdir "$mount_point"
    
    # Show success message
    show_success "$model_name has been removed successfully"
    
    return 0
}
