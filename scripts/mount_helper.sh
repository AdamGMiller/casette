#!/bin/bash

# Casette Mount Helper Script
# This script provides utilities for mounting/unmounting USB devices
# and managing Chromium kiosk sessions

MOUNT_BASE="/mnt/casette"
LOG_FILE="/home/Adam/repos/casette/logs/mount_helper.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check if a device is mounted
is_mounted() {
    local device="$1"
    mount | grep -q "$device"
}

# Function to safely mount a USB device
mount_usb() {
    local device="$1"
    local label="$2"
    
    if [[ -z "$device" ]]; then
        log_message "ERROR: No device specified"
        return 1
    fi
    
    if [[ -z "$label" ]]; then
        label="usb_$(basename "$device")"
    fi
    
    local mount_point="$MOUNT_BASE/$label"
    
    # Check if already mounted
    if is_mounted "$device"; then
        log_message "Device $device is already mounted"
        echo "$mount_point"
        return 0
    fi
    
    # Create mount point
    mkdir -p "$mount_point"
    
    # Mount the device
    if mount "$device" "$mount_point"; then
        log_message "Successfully mounted $device to $mount_point"
        echo "$mount_point"
        return 0
    else
        log_message "ERROR: Failed to mount $device to $mount_point"
        rmdir "$mount_point" 2>/dev/null
        return 1
    fi
}

# Function to safely unmount a USB device
unmount_usb() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        log_message "ERROR: No mount point specified"
        return 1
    fi
    
    # Kill any processes using the mount point
    log_message "Killing processes using $mount_point"
    fuser -km "$mount_point" 2>/dev/null || true
    
    # Wait a moment
    sleep 2
    
    # Unmount
    if umount "$mount_point"; then
        log_message "Successfully unmounted $mount_point"
        rmdir "$mount_point" 2>/dev/null || true
        return 0
    else
        log_message "ERROR: Failed to unmount $mount_point"
        return 1
    fi
}

# Function to launch Chromium in kiosk mode
launch_kiosk() {
    local html_file="$1"
    
    if [[ -z "$html_file" ]]; then
        log_message "ERROR: No HTML file specified"
        return 1
    fi
    
    if [[ ! -f "$html_file" ]]; then
        log_message "ERROR: HTML file $html_file does not exist"
        return 1
    fi
    
    log_message "Launching Chromium kiosk mode with $html_file"
    
    # Kill existing Chromium processes
    pkill -f chromium 2>/dev/null || true
    sleep 1
    
    # Set display
    export DISPLAY=${DISPLAY:-:0}
    
    # Determine Chromium executable (Debian uses 'chromium', Ubuntu uses 'chromium-browser')
    local chromium_cmd="chromium"
    if ! command -v chromium &> /dev/null && command -v chromium-browser &> /dev/null; then
        chromium_cmd="chromium-browser"
    fi
    
    # Launch Chromium in kiosk mode
    nohup "$chromium_cmd" \
        --kiosk \
        --no-sandbox \
        --disable-web-security \
        --disable-features=TranslateUI \
        --disable-ipc-flooding-protection \
        --start-fullscreen \
        --no-first-run \
        --disable-default-apps \
        --disable-infobars \
        --disable-translate \
        --disable-suggestions-service \
        --disable-save-password-bubble \
        "file://$html_file" \
        > /dev/null 2>&1 &
    
    local chromium_pid=$!
    log_message "Chromium launched with PID $chromium_pid"
    
    return 0
}

# Function to stop kiosk mode
stop_kiosk() {
    log_message "Stopping Chromium kiosk mode"
    pkill -f chromium 2>/dev/null || true
}

# Function to clean up all mounts
cleanup_all() {
    log_message "Cleaning up all casette mounts"
    
    # Stop kiosk mode first
    stop_kiosk
    
    # Unmount all casette mount points
    for mount_point in "$MOUNT_BASE"/*; do
        if [[ -d "$mount_point" ]] && mountpoint -q "$mount_point"; then
            unmount_usb "$mount_point"
        fi
    done
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Commands:
    mount <device> [label]     Mount a USB device
    unmount <mount_point>      Unmount a USB device
    kiosk <html_file>          Launch Chromium in kiosk mode
    stop                       Stop kiosk mode
    cleanup                    Clean up all mounts and stop kiosk
    help                       Show this help message

Examples:
    $0 mount /dev/sdb1 my_usb
    $0 kiosk /mnt/casette/my_usb/index.html
    $0 unmount /mnt/casette/my_usb
    $0 cleanup
EOF
}

# Main script logic
case "$1" in
    mount)
        mount_usb "$2" "$3"
        ;;
    unmount)
        unmount_usb "$2"
        ;;
    kiosk)
        launch_kiosk "$2"
        ;;
    stop)
        stop_kiosk
        ;;
    cleanup)
        cleanup_all
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "ERROR: Unknown command '$1'"
        usage
        exit 1
        ;;
esac