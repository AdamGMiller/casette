#!/bin/bash

# Casette USB Monitor - Installation Script
# This script sets up the USB monitoring service

set -e  # Exit on any error

PROJECT_DIR="/home/Adam/repos/casette"
SERVICE_NAME="casette-usb-monitor"
SERVICE_FILE="$PROJECT_DIR/$SERVICE_NAME.service"
SYSTEMD_DIR="/etc/systemd/system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root for system operations
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root directly."
        print_error "It will use sudo when needed for system operations."
        exit 1
    fi
}

# Function to check if required commands exist
check_dependencies() {
    print_status "Checking system dependencies..."
    
    local missing_deps=()
    
    # Check for required commands
    for cmd in python3 pip3 systemctl sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install them and run this script again."
        exit 1
    fi
    
    print_status "All system dependencies found."
}

# Function to install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    local venv_dir="$PROJECT_DIR/venv"
    
    # Create requirements.txt if it doesn't exist
    if [[ ! -f "$PROJECT_DIR/requirements.txt" ]]; then
        cat > "$PROJECT_DIR/requirements.txt" << EOF
pyudev>=0.23.2
EOF
    fi
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "$venv_dir" ]]; then
        print_status "Creating Python virtual environment..."
        if ! python3 -m venv "$venv_dir"; then
            print_error "Failed to create virtual environment. Make sure python3-venv is installed."
            print_error "Try: sudo apt install python3-venv python$(python3 -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")')-venv"
            exit 1
        fi
    fi
    
    # Activate virtual environment and install dependencies
    print_status "Installing Python dependencies in virtual environment..."
    source "$venv_dir/bin/activate"
    pip install --upgrade pip
    pip install -r "$PROJECT_DIR/requirements.txt"
    deactivate
    
    print_status "Python dependencies installed in virtual environment."
}

# Function to install system packages
install_system_packages() {
    print_status "Checking for required system packages..."
    
    local packages_to_install=()
    
    # Check for Chromium
    if ! command -v chromium &> /dev/null && ! command -v chromium-browser &> /dev/null; then
        packages_to_install+=("chromium")
    fi
    
    # Check for udisks2 (for USB device management)
    if ! dpkg -l | grep -q udisks2; then
        packages_to_install+=("udisks2")
    fi
    
    # Check for python3-venv (for virtual environment support)
    # Use version-specific package name for newer Python versions
    local python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local venv_package="python${python_version}-venv"
    
    if ! dpkg -l | grep -q -E "(python3-venv|${venv_package})"; then
        packages_to_install+=("$venv_package")
    fi
    
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        print_status "Installing system packages: ${packages_to_install[*]}"
        sudo apt update
        sudo apt install -y "${packages_to_install[@]}"
    else
        print_status "All required system packages are already installed."
    fi
}

# Function to create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    # Create mount base directory
    sudo mkdir -p /mnt/casette
    sudo chown Adam:Adam /mnt/casette
    
    # Ensure log directory exists and is writable
    mkdir -p "$PROJECT_DIR/logs"
    
    print_status "Directories created."
}

# Function to configure sudoers for mounting
configure_sudoers() {
    print_status "Configuring sudoers for USB mounting..."
    
    local sudoers_file="/etc/sudoers.d/casette-usb-monitor"
    
    # Create sudoers rule to allow mounting without password
    sudo tee "$sudoers_file" > /dev/null << EOF
# Allow Adam to mount/unmount USB devices without password for Casette service
Adam ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount
EOF
    
    # Set correct permissions
    sudo chmod 440 "$sudoers_file"
    
    print_status "Sudoers configuration completed."
}

# Function to install systemd service
install_service() {
    print_status "Installing systemd service..."
    
    # Copy service file to systemd directory
    sudo cp "$SERVICE_FILE" "$SYSTEMD_DIR/"
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    print_status "Systemd service installed."
}

# Function to start and enable the service
enable_service() {
    print_status "Enabling and starting the service..."
    
    # Enable the service to start on boot
    sudo systemctl enable "$SERVICE_NAME"
    
    # Start the service
    sudo systemctl start "$SERVICE_NAME"
    
    print_status "Service enabled and started."
}

# Function to check service status
check_service_status() {
    print_status "Checking service status..."
    
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_status "Service is running successfully!"
        echo
        echo "You can check the service status with:"
        echo "  sudo systemctl status $SERVICE_NAME"
        echo
        echo "View logs with:"
        echo "  tail -f $PROJECT_DIR/logs/usb_monitor.log"
        echo "  sudo journalctl -u $SERVICE_NAME -f"
    else
        print_warning "Service is not running. Check the logs for details:"
        echo "  sudo systemctl status $SERVICE_NAME"
        echo "  sudo journalctl -u $SERVICE_NAME"
    fi
}

# Function to uninstall the service
uninstall_service() {
    print_status "Uninstalling Casette USB Monitor service..."
    
    # Stop and disable the service
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service file
    sudo rm -f "$SYSTEMD_DIR/$SERVICE_NAME.service"
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Remove sudoers file
    sudo rm -f "/etc/sudoers.d/casette-usb-monitor"
    
    # Clean up any mounted devices
    "$PROJECT_DIR/scripts/mount_helper.sh" cleanup 2>/dev/null || true
    
    # Remove virtual environment
    if [[ -d "$PROJECT_DIR/venv" ]]; then
        print_status "Removing Python virtual environment..."
        rm -rf "$PROJECT_DIR/venv"
    fi
    
    print_status "Service uninstalled successfully."
}

# Function to show usage
usage() {
    cat << EOF
Casette USB Monitor - Installation Script

Usage: $0 [command]

Commands:
    install     Install and start the service (default)
    uninstall   Stop and remove the service
    start       Start the service
    stop        Stop the service
    restart     Restart the service
    status      Show service status
    logs        Show service logs
    help        Show this help message

Examples:
    $0 install      # Install and start the service
    $0 status       # Check if service is running
    $0 logs         # View recent log entries
EOF
}

# Main installation function
install_casette() {
    print_status "Starting Casette USB Monitor installation..."
    
    check_root
    check_dependencies
    install_system_packages
    install_python_deps
    create_directories
    configure_sudoers
    install_service
    enable_service
    check_service_status
    
    echo
    print_status "Installation completed successfully!"
    echo
    echo "The Casette USB Monitor service is now running and will:"
    echo "1. Automatically start when the system boots"
    echo "2. Monitor for USB drive insertions"
    echo "3. Mount USB drives and look for index.html files"
    echo "4. Launch Chromium in kiosk mode when index.html is found"
    echo
    echo "To test, insert a USB drive with an index.html file in the root directory."
}

# Parse command line arguments
case "${1:-install}" in
    install)
        install_casette
        ;;
    uninstall)
        uninstall_service
        ;;
    start)
        print_status "Starting service..."
        sudo systemctl start "$SERVICE_NAME"
        check_service_status
        ;;
    stop)
        print_status "Stopping service..."
        sudo systemctl stop "$SERVICE_NAME"
        "$PROJECT_DIR/scripts/mount_helper.sh" cleanup
        ;;
    restart)
        print_status "Restarting service..."
        sudo systemctl restart "$SERVICE_NAME"
        check_service_status
        ;;
    status)
        sudo systemctl status "$SERVICE_NAME"
        ;;
    logs)
        echo "=== Service Logs ==="
        sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
        echo
        echo "=== Application Logs ==="
        tail -20 "$PROJECT_DIR/logs/usb_monitor.log" 2>/dev/null || echo "No application logs found."
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac