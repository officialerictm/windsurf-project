# ==============================================================================
# Filesystem Operations
# ==============================================================================

# Safely mount a device
safe_mount() {
    local device="$1"
    local mount_point="$2"
    local fs_type="${3:-}"
    local options="${4:-rw,noatime}"
    local result
    
    # Create mount point if it doesn't exist
    mkdir -p "$mount_point" 2>/dev/null || {
        print_error "Failed to create mount point: $mount_point"
        return 1
    }
    
    # Build mount command
    local mount_cmd="mount"
    [ -n "$fs_type" ] && mount_cmd="$mount_cmd -t $fs_type"
    mount_cmd="$mount_cmd -o $options $device $mount_point"
    
    # Execute mount command
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run: $mount_cmd"
        return 0
    fi
    
    print_debug "Mounting: $mount_cmd"
    eval "$mount_cmd" 2>/dev/null
    result=$?
    
    if [ $result -ne 0 ]; then
        print_error "Failed to mount $device at $mount_point"
        return $result
    fi
    
    return 0
}

# Enhanced unmount function to handle stubborn devices
# Based on memory: Added aggressive unmounting to handle the "partition in use" error
safe_umount() {
    local target="$1"
    local max_retries=${2:-5}
    local retry_delay=${3:-1}
    local attempt=1
    local result
    
    # Check if target is a block device or a mount point
    if ! is_block_device "$target" && ! mountpoint -q "$target" 2>/dev/null; then
        print_debug "Not mounted: $target"
        return 0
    fi
    
    print_debug "Attempting to unmount: $target (max $max_retries attempts)"
    
    # Try different unmount methods with increasing aggressiveness
    while [ $attempt -le $max_retries ]; do
        print_debug "Unmount attempt $attempt of $max_retries"
        
        case $attempt in
            1)
                # First try a normal unmount
                print_debug "Trying normal unmount"
                umount "$target" 2>/dev/null
                ;;
            2)
                # Try lazy unmount
                print_debug "Trying lazy unmount"
                umount -l "$target" 2>/dev/null
                ;;
            3)
                # Kill processes using the target
                print_debug "Killing processes using $target"
                fuser -km "$target" 2>/dev/null
                sleep 1
                umount -f "$target" 2>/dev/null
                ;;
            4)
                # Force lazy unmount
                print_debug "Force lazy unmount"
                umount -lf "$target" 2>/dev/null
                ;;
            5)
                # Last resort: try to reload partition table
                print_debug "Reloading partition table as last resort"
                sync
                blockdev --rereadpt "$target" 2>/dev/null || true
                partprobe "$target" 2>/dev/null || true
                hdparm -z "$target" 2>/dev/null || true
                # Try to write directly to sysfs to force re-read
                local dev_name=$(basename "$target")
                echo 1 > "/sys/block/$dev_name/device/rescan" 2>/dev/null || true
                sleep 2
                umount -lf "$target" 2>/dev/null
                ;;
        esac
        
        # Verify if unmount was successful
        if ! is_block_device "$target" || ! mountpoint -q "$target" 2>/dev/null; then
            print_debug "Successfully unmounted: $target (attempt $attempt)"
            return 0
        fi
        
        # Wait before retrying
        sleep $retry_delay
        attempt=$((attempt + 1))
    done
    
    # If we're here, all retries failed
    print_error "Failed to unmount $target after $max_retries attempts"
    return 1
}

# Create a filesystem on a device
create_filesystem() {
    local device="$1"
    local fs_type="${2:-ext4}"
    local label="${3:-}"
    local force="${4:-false}"
    local mkfs_cmd=""
    local result=0
    
    # Validate device
    if ! is_block_device "$device"; then
        print_error "Not a block device: $device"
        return 1
    fi
    
    # Unmount any mounted partitions
    safe_umount "$device" 5 2 || {
        print_error "Failed to unmount device: $device"
        return 1
    }
    
    # Build filesystem creation command
    case "$fs_type" in
        vfat|fat16|fat32)
            mkfs_cmd="mkfs.vfat -F32"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -n '${label:0:11}'"
            ;;
        ext2|ext3|ext4)
            mkfs_cmd="mkfs.$fs_type -F"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -L '$label'"
            [ "$fs_type" = "ext4" ] && mkfs_cmd="$mkfs_cmd -O ^64bit,^metadata_csum"
            ;;
        ntfs)
            mkfs_cmd="mkfs.ntfs -F"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -L '$label'"
            ;;
        exfat)
            mkfs_cmd="mkfs.exfat"
            [ -n "$label" ] && mkfs_cmd="$mkfs_cmd -n '$label'"
            ;;
        *)
            print_error "Unsupported filesystem type: $fs_type"
            return 1
            ;;
    esac
    
    # Add force flag if requested
    [ "$force" = "true" ] && [ "$fs_type" != "exfat" ] && mkfs_cmd="$mkfs_cmd -F"
    
    # Execute filesystem creation
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run: $mkfs_cmd $device"
        return 0
    fi
    
    print_info "Creating $fs_type filesystem on $device..."
    
    # Wait for device to settle
    wait_for_device_settle "$device"
    
    # Create filesystem
    eval "$mkfs_cmd $device" 2>&1 | while IFS= read -r line; do
        print_debug "$line"
    done
    
    result=${PIPESTATUS[0]}
    
    if [ $result -ne 0 ]; then
        print_error "Failed to create $fs_type filesystem on $device"
        return $result
    fi
    
    # Wait for device to settle after filesystem creation
    wait_for_device_settle "$device"
    
    print_success "Created $fs_type filesystem on $device"
    return 0
}

# Create a partition table on a device
create_partition_table() {
    local device="$1"
    local table_type="${2:-gpt}"
    local result=0
    
    # Validate device
    if ! is_block_device "$device"; then
        print_error "Not a block device: $device"
        return 1
    fi
    
    # Unmount any mounted partitions
    safe_umount "$device" || {
        print_error "Failed to unmount device: $device"
        return 1
    }
    
    # Create partition table
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would create $table_type partition table on $device"
        return 0
    fi
    
    print_info "Creating $table_type partition table on $device..."
    
    # Wait for device to settle
    wait_for_device_settle "$device"
    
    # Clear existing partition table - wipe first few MB
    print_debug "Wiping existing partition table..."
    dd if=/dev/zero of="$device" bs=1M count=16 conv=fsync 2>/dev/null
    
    # Create new partition table
    print_debug "Creating new partition table of type $table_type..."
    case "$table_type" in
        gpt)
            parted -s "$device" mklabel gpt 2>&1 | while IFS= read -r line; do
                print_debug "$line"
            done
            result=${PIPESTATUS[0]}
            ;;
        msdos|mbr)
            parted -s "$device" mklabel msdos 2>&1 | while IFS= read -r line; do
                print_debug "$line"
            done
            result=${PIPESTATUS[0]}
            ;;
        *)
            print_error "Unsupported partition table type: $table_type"
            return 1
            ;;
    esac
    
    if [ $result -ne 0 ]; then
        print_error "Failed to create $table_type partition table on $device"
        return $result
    fi
    
    # Use multiple methods to ensure partition table is reread
    # Based on memory about improving partition table reload techniques
    sync
    blockdev --rereadpt "$device" 2>/dev/null || true
    partprobe "$device" 2>/dev/null || true
    hdparm -z "$device" 2>/dev/null || true
    sfdisk -R "$device" 2>/dev/null || true
    
    # Wait for device to settle
    wait_for_device_settle "$device" 3
    
    print_success "Created $table_type partition table on $device"
    return 0
}

# Create a partition on a device
create_partition() {
    local device="$1"
    local part_num="${2:-1}"
    local part_type="${3:-primary}"
    local fs_type="${4:-}"
    local start="${5:-0%}"
    local end="${6:-100%}"
    local part_label="${7:-}"
    local part_guid="${8:-}"
    local result=0
    
    # Validate device
    if ! is_block_device "$device"; then
        print_error "Not a block device: $device"
        return 1
    fi
    
    local parted_executable="parted"
    local common_parted_opts=(-s --align optimal "$device")
    local mkpart_subcommand_args=()
    
    # Detect partition table type
    local table_type
    table_type=$("$parted_executable" -s "$device" print 2>/dev/null | grep "Partition Table:" | awk '{print $3}')

    if [ "$table_type" = "gpt" ]; then
        # For GPT, mkpart takes: name start end
        local gpt_part_name="${part_label:-LeonardoP1}"
        mkpart_subcommand_args+=("$gpt_part_name")
        mkpart_subcommand_args+=("$start")
        mkpart_subcommand_args+=("$end")
    else
        # For MBR (msdos), mkpart takes: type [fs-type] start end
        mkpart_subcommand_args+=("$part_type") # primary, logical, extended
        [ -n "$fs_type" ] && mkpart_subcommand_args+=("$fs_type") # Optional fs-type for MBR partition ID
        mkpart_subcommand_args+=("$start")
        mkpart_subcommand_args+=("$end")
    fi

    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would run: $parted_executable ${common_parted_opts[*]} mkpart ${mkpart_subcommand_args[*]}"
    else
        print_info "Creating partition $part_num on $device..."
        wait_for_device_settle "$device"
        print_info "Executing parted mkpart: $parted_executable ${common_parted_opts[*]} mkpart ${mkpart_subcommand_args[*]}"
        
        "$parted_executable" "${common_parted_opts[@]}" mkpart "${mkpart_subcommand_args[@]}" 2>&1 | while IFS= read -r line; do
            print_info "parted output: $line"
        done
        result=${PIPESTATUS[0]}
    fi

    # --- SET Operations (name, guid) if mkpart succeeded --- 
    if [ "$DRY_RUN" != true ] && [ $result -eq 0 ]; then
        # Set name/label if specified
        if [ -n "$part_label" ]; then
            local name_subcommand_args=("$part_num" "$part_label")
            print_info "Executing parted name: $parted_executable ${common_parted_opts[*]} name ${name_subcommand_args[*]}"
            "$parted_executable" "${common_parted_opts[@]}" name "${name_subcommand_args[@]}" 2>&1 | while IFS= read -r line; do
                print_info "parted output: $line"
            done
            result=${PIPESTATUS[0]}
            if [ $result -ne 0 ]; then 
                print_warning "parted set name failed. Continuing..."
                result=0 # Reset result so GUID set can be attempted if needed
            fi 
        fi

        # Set GUID if specified (for GPT) and previous set (name) was okay or not done
        if [ $result -eq 0 ] && [ -n "$part_guid" ]; then
            local guid_subcommand_args=("$part_num" "$part_guid" "on")
            print_info "Executing parted set guid: $parted_executable ${common_parted_opts[*]} set ${guid_subcommand_args[*]}"
            "$parted_executable" "${common_parted_opts[@]}" set "${guid_subcommand_args[@]}" 2>&1 | while IFS= read -r line; do
                print_info "parted output: $line"
            done
            result=${PIPESTATUS[0]}
            if [ $result -ne 0 ]; then print_warning "parted set guid failed. Continuing..."; fi
        fi
    elif [ "$DRY_RUN" = true ]; then # Handle DRY_RUN for set operations
        if [ -n "$part_label" ]; then
             print_info "DRY RUN: Would run: $parted_executable ${common_parted_opts[*]} name $part_num '$part_label'"
        fi
        if [ -n "$part_guid" ]; then
            print_info "DRY RUN: Would run: $parted_executable ${common_parted_opts[*]} set $part_num $part_guid on"
        fi
    fi
    
    # Use multiple methods to ensure partition table is reread
    if [ $result -eq 0 ]; then
        sync
        blockdev --rereadpt "$device" 2>/dev/null || true
        partprobe "$device" 2>/dev/null || true
        hdparm -z "$device" 2>/dev/null || true
        wait_for_device_settle "$device" 3
    else
        print_error "Failed to create partition on $device"
        return $result
    fi
    
    print_success "Created partition $part_num on $device"
    return 0
}

# Install the Leonardo system files to a formatted USB drive
install_leonardo_system() {
    local device="$1"          # Device path (e.g., /dev/sdc1)
    local fs_type="$2"         # Filesystem type (e.g., exfat)
    local label="$3"           # Volume label
    
    # Create a temporary mount point
    local temp_mount_point
    temp_mount_point=$(mktemp -d -p "${TMP_DIR:-/tmp}" leonardo_mount_XXXXXX)
    
    if [ -z "$temp_mount_point" ] || [ ! -d "$temp_mount_point" ]; then
        print_error "Failed to create temporary mount point."
        return 1
    fi
    
    # Mount the device
    print_info "Mounting $device to $temp_mount_point..."
    if ! safe_mount "$device" "$temp_mount_point" "$fs_type"; then
        print_error "Failed to mount $device. Cannot install Leonardo system."
        rmdir "$temp_mount_point" 2>/dev/null
        return 1
    fi
    
    # Create the basic directory structure
    print_info "Creating Leonardo system directory structure..."
    mkdir -p "$temp_mount_point/models" "$temp_mount_point/config" "$temp_mount_point/data" "$temp_mount_point/system"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create directories on USB drive."
        safe_umount "$temp_mount_point"
        rmdir "$temp_mount_point" 2>/dev/null
        return 1
    fi
    
    # Create a simple README file
    print_info "Creating system files..."
    cat > "$temp_mount_point/README.txt" << EOF
Leonardo AI System
==================

This USB drive contains the Leonardo AI system.

Directory Structure:
- models/: Contains AI models
- config/: Configuration files
- data/: User data
- system/: System files

Created: $(date)
Version: 5.0.0
EOF
    
    # Create a simple startup script
    cat > "$temp_mount_point/start_leonardo.sh" << 'EOF'
#!/bin/bash

echo "Starting Leonardo AI System..."
echo "This is a placeholder for the actual Leonardo startup script."
echo "In a real deployment, this would launch the Leonardo AI interface."

echo "\nLeonardo AI is ready to use!"
EOF
    
    # Make the startup script executable
    chmod +x "$temp_mount_point/start_leonardo.sh"
    
    # Create a system info file
    cat > "$temp_mount_point/system/info.json" << EOF
{
  "version": "5.0.0",
  "build_date": "$(date +%Y-%m-%d)",
  "filesystem": "$fs_type",
  "label": "$label"
}
EOF
    
    # Create a sample config file
    cat > "$temp_mount_point/config/system.conf" << EOF
# Leonardo AI System Configuration

# Model settings
DEFAULT_MODEL=llama3-8b
MODEL_PRECISION=f16

# System settings
THREADS=4
CONTEXT_SIZE=4096
MEMORY_LIMIT=8G
EOF
    
    # Verify the files were created successfully
    if [ ! -f "$temp_mount_point/README.txt" ] || 
       [ ! -f "$temp_mount_point/start_leonardo.sh" ] || 
       [ ! -f "$temp_mount_point/system/info.json" ] || 
       [ ! -f "$temp_mount_point/config/system.conf" ]; then
        print_error "Failed to create system files."
        safe_umount "$temp_mount_point"
        rmdir "$temp_mount_point" 2>/dev/null
        return 1
    fi
    
    print_success "Successfully installed Leonardo system files."
    
    # Unmount the device
    print_info "Unmounting $temp_mount_point..."
    if ! safe_umount "$temp_mount_point"; then
        print_error "Failed to unmount $temp_mount_point. The drive may not be safely removed."
        # Don't return error here, as the installation succeeded
    fi
    
    # Remove the temporary mount point
    rmdir "$temp_mount_point" 2>/dev/null
    
    return 0
}

# Format a USB device for Leonardo AI with enhanced reliability
format_usb_device() {
    local device="$1"
    local fs_type="${2:-exfat}"
    local label="${3:-LEONARDO}"
    local max_retries=3
    local retry_count=0
    
    print_info "Preparing to format USB device: $device"
    
    # Aggressively unmount any existing partitions on the device
    print_debug "Ensuring all partitions are unmounted..."
    
    # Find all partitions for this device
    local partitions=()
    while read -r part; do
        if [ -n "$part" ]; then
            partitions+=("$part")
            print_debug "Found partition: $part"
        fi
    done < <(lsblk -nlo NAME "$device" | grep -v "^$(basename "$device")$" || echo "")
    
    # Unmount all found partitions
    for part in "${partitions[@]}"; do
        print_debug "Attempting to unmount: /dev/$part"
        safe_umount "/dev/$part" 5 2
    done
    
    # Kill any processes that might be using the device
    print_debug "Terminating processes using the device..."
    fuser -k "$device" 2>/dev/null || true
    for part in "${partitions[@]}"; do
        fuser -k "/dev/$part" 2>/dev/null || true
    done
    
    # Force the kernel to forget about the device
    print_debug "Resetting device state..."
    sync
    blockdev --flushbufs "$device" 2>/dev/null || true
    
    # Use multiple methods to ensure the device is properly recognized
    print_debug "Refreshing device recognition..."
    udevadm settle --timeout=10
    blockdev --rereadpt "$device" 2>/dev/null || true
    partprobe "$device" 2>/dev/null || true
    hdparm -z "$device" 2>/dev/null || true
    
    # Try direct sysfs method
    local dev_name=$(basename "$device")
    if [ -e "/sys/block/$dev_name/device/rescan" ]; then
        print_debug "Using sysfs to rescan device"
        echo 1 > "/sys/block/$dev_name/device/rescan" 2>/dev/null || true
    fi
    
    # Validate device with retry mechanism
    while [ $retry_count -lt $max_retries ]; do
        # Verify the device exists and is accessible
        if verify_usb_device "$device"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Device verification failed. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to verify device after $max_retries attempts."
            return 1
        fi
    done
    
    # Reset retry counter
    retry_count=0
    
    # Create partition table with retry mechanism
    while [ $retry_count -lt $max_retries ]; do
        if create_partition_table "$device" "gpt"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Failed to create partition table. Retrying ($retry_count/$max_retries)..."
            sleep 2
            
            # Try more aggressive device refresh
            sync
            udevadm settle --timeout=10
            blockdev --rereadpt "$device" 2>/dev/null || true
            partprobe -s "$device" 2>/dev/null || true
        else
            print_error "Failed to create partition table after $max_retries attempts."
            return 1
        fi
    done
    
    # Reset retry counter
    retry_count=0
    
    # Create a single partition spanning the whole device
    while [ $retry_count -lt $max_retries ]; do
        if create_partition "$device" 1 "primary" "$fs_type" "0%" "100%" "$label"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Failed to create partition. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to create partition after $max_retries attempts."
            return 1
        fi
    done
    
    # Wait for device to settle with proper partition recognition
    print_info "Waiting for partition to be recognized..."
    udevadm settle --timeout=10
    sleep 3  # Additional wait time for slow USB devices
    
    # Determine the partition device path
    local part_device
    
    # Check if the partition is detected
    if [[ "$device" =~ [0-9]+$ ]]; then
        # Device name already ends with a number, use p1 suffix
        part_device="${device}p1"
    else
        # Device name doesn't end with a number, use 1 suffix
        part_device="${device}1"
    fi
    
    # Verify partition exists with retry
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if [ -b "$part_device" ]; then
            break
        fi
        
        # Alternative check using lsblk
        if lsblk "$part_device" >/dev/null 2>&1; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Partition not detected yet. Waiting... ($retry_count/$max_retries)"
            sleep 2
            
            # Refresh partition table again
            partprobe "$device" 2>/dev/null || true
            udevadm settle --timeout=5
        else
            print_error "Failed to detect partition: $part_device"
            return 1
        fi
    done
    
    # Create filesystem on the partition with retry mechanism
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if create_filesystem "$part_device" "$fs_type" "$label"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Failed to create filesystem. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to create filesystem after $max_retries attempts."
            return 1
        fi
    done
    
    print_success "USB device $device has been successfully formatted with $fs_type."
    return 0
}
