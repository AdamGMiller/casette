#!/bin/bash

# Casette USB Monitor - Live Monitoring Script
# This script provides real-time monitoring of the USB service

PROJECT_DIR="/home/Adam/repos/casette"
SERVICE_NAME="casette-usb-monitor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Casette USB Monitor - Live View                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_service_status() {
    echo -e "${BLUE}[SERVICE STATUS]${NC}"
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "Status: ${GREEN}●${NC} Running"
        local pid=$(sudo systemctl show -p MainPID --value "$SERVICE_NAME")
        echo -e "PID: $pid"
        local memory=$(ps -p "$pid" -o rss= 2>/dev/null | awk '{print $1/1024 " MB"}' 2>/dev/null || echo "N/A")
        echo -e "Memory: $memory"
    else
        echo -e "Status: ${RED}●${NC} Not Running"
    fi
    
    echo -e "Uptime: $(sudo systemctl show -p ActiveEnterTimestamp --value "$SERVICE_NAME" | cut -d' ' -f2-)"
    echo
}

print_mount_points() {
    echo -e "${BLUE}[MOUNT POINTS]${NC}"
    local mounts=$(mount | grep "/mnt/casette" | wc -l)
    echo -e "Active USB mounts: $mounts"
    
    if [[ $mounts -gt 0 ]]; then
        mount | grep "/mnt/casette" | while read line; do
            echo -e "  ${GREEN}→${NC} $line"
        done
    else
        echo -e "  ${YELLOW}No USB drives currently mounted${NC}"
    fi
    echo
}

print_recent_logs() {
    echo -e "${BLUE}[RECENT ACTIVITY - Last 10 entries]${NC}"
    if [[ -f "$PROJECT_DIR/logs/usb_monitor.log" ]]; then
        tail -10 "$PROJECT_DIR/logs/usb_monitor.log" | while read line; do
            if echo "$line" | grep -q "ERROR"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "${YELLOW}$line${NC}"
            elif echo "$line" | grep -q "INFO.*USB device"; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${YELLOW}No log file found${NC}"
    fi
    echo
}

print_usb_devices() {
    echo -e "${BLUE}[AVAILABLE BLOCK DEVICES]${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "(NAME|disk|part)" | head -10
    echo
}

print_commands() {
    echo -e "${BLUE}[MONITORING COMMANDS]${NC}"
    echo -e "Live logs:        ${GREEN}tail -f $PROJECT_DIR/logs/usb_monitor.log${NC}"
    echo -e "Service logs:     ${GREEN}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "Restart service:  ${GREEN}sudo systemctl restart $SERVICE_NAME${NC}"
    echo -e "udev monitor:     ${GREEN}udevadm monitor --subsystem-match=block${NC}"
    echo
}

monitor_mode() {
    echo -e "${GREEN}Starting live monitoring mode...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo
    
    # Start monitoring in background
    tail -f "$PROJECT_DIR/logs/usb_monitor.log" | while read line; do
        timestamp=$(date '+%H:%M:%S')
        if echo "$line" | grep -q "ERROR"; then
            echo -e "${RED}[$timestamp] $line${NC}"
        elif echo "$line" | grep -q "WARNING"; then
            echo -e "${YELLOW}[$timestamp] $line${NC}"
        elif echo "$line" | grep -q "USB device inserted"; then
            echo -e "${GREEN}[$timestamp] 🔌 $line${NC}"
        elif echo "$line" | grep -q "Successfully mounted"; then
            echo -e "${GREEN}[$timestamp] 💾 $line${NC}"
        elif echo "$line" | grep -q "Found index.html"; then
            echo -e "${GREEN}[$timestamp] 🌐 $line${NC}"
        elif echo "$line" | grep -q "Launched Chromium"; then
            echo -e "${GREEN}[$timestamp] 🚀 $line${NC}"
        elif echo "$line" | grep -q "USB device removed"; then
            echo -e "${BLUE}[$timestamp] 🔌 $line${NC}"
        else
            echo -e "[$timestamp] $line"
        fi
    done
}

show_dashboard() {
    print_header
    print_service_status
    print_mount_points
    print_recent_logs
    print_usb_devices
    print_commands
}

test_usb_simulation() {
    echo -e "${GREEN}Testing USB simulation...${NC}"
    
    # Create a test mount point
    local test_dir="/mnt/casette/test_simulation"
    sudo mkdir -p "$test_dir"
    
    # Create a test index.html
    cat << 'EOF' | sudo tee "$test_dir/index.html" > /dev/null
<!DOCTYPE html>
<html>
<head><title>USB Test</title></head>
<body>
    <h1>🧪 USB Simulation Test</h1>
    <p>This is a test of the Casette USB Monitor system.</p>
    <p>Time: <span id="time"></span></p>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
    
    echo -e "Created test USB simulation at: ${GREEN}$test_dir${NC}"
    echo -e "Test launching Chromium..."
    
    # Test the mount helper
    "$PROJECT_DIR/scripts/mount_helper.sh" kiosk "$test_dir/index.html"
    
    echo -e "${YELLOW}Chromium should have opened. Press any key to clean up...${NC}"
    read -n 1
    
    # Clean up
    "$PROJECT_DIR/scripts/mount_helper.sh" stop
    sudo rm -rf "$test_dir"
    echo -e "${GREEN}Test cleanup completed.${NC}"
}

# Parse command line arguments
case "${1:-dashboard}" in
    dashboard|status)
        show_dashboard
        ;;
    monitor|watch|live)
        print_header
        monitor_mode
        ;;
    test)
        test_usb_simulation
        ;;
    help|--help|-h)
        echo "Casette USB Monitor - Monitoring Script"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  dashboard    Show status dashboard (default)"
        echo "  monitor      Start live log monitoring"
        echo "  test         Test USB simulation"
        echo "  help         Show this help"
        echo
        echo "Examples:"
        echo "  $0           # Show dashboard"
        echo "  $0 monitor   # Watch live logs"
        echo "  $0 test      # Test the system"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac