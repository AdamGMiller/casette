# Casette USB Monitor Service

A Linux service that automatically monitors for USB drive insertions, mounts them, and opens any `index.html` file found in the root directory using Chromium in fullscreen kiosk mode.

## Features

- 🔌 Automatic USB device detection using udev
- 💾 Safe mounting and unmounting of USB drives
- 🌐 Automatic launch of Chromium in kiosk mode for `index.html` files
- 🖥️ Full-screen presentation mode
- 🔄 Automatic cleanup on USB removal
- 📝 Comprehensive logging
- ⚙️ Systemd service integration for auto-start

## Requirements

- Linux system with systemd
- Python 3.x
- Chromium browser
- X11 display server
- Root access for initial setup

## Installation

1. **Clone or navigate to the project directory:**
   ```bash
   cd /home/Adam/repos/casette
   ```

2. **Run the installation script:**
   ```bash
   ./install.sh
   ```

   The installation script will:
   - Install required system packages (Chromium, udisks2, python3-venv)
   - Create a Python virtual environment in the project directory
   - Install Python dependencies (pyudev) in the virtual environment
   - Create necessary directories
   - Configure sudo permissions for mounting
   - Install and start the systemd service

3. **Verify the service is running:**
   ```bash
   ./install.sh status
   ```

## Usage

### Basic Operation

Once installed, the service runs automatically and:

1. **Monitors** for USB device insertions
2. **Mounts** USB drives to `/mnt/casette/<device_label>`
3. **Searches** for `index.html` in the root of the mounted drive
4. **Launches** Chromium in kiosk mode if `index.html` is found
5. **Cleans up** when the USB drive is removed

### Testing

1. Create a USB drive with an `index.html` file in the root:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
       <title>Casette Demo</title>
       <style>
           body { 
               margin: 0; 
               padding: 50px; 
               background: #2c3e50; 
               color: white; 
               font-family: Arial, sans-serif;
               text-align: center;
           }
           h1 { font-size: 4em; }
           p { font-size: 2em; }
       </style>
   </head>
   <body>
       <h1>🎵 Welcome to Casette!</h1>
       <p>Your USB drive has been automatically detected and mounted.</p>
       <p>This page opened in fullscreen kiosk mode.</p>
   </body>
   </html>
   ```

2. Insert the USB drive
3. Chromium should automatically open in fullscreen kiosk mode
4. Remove the USB drive to close Chromium and unmount

### Manual Control

The installation script provides several management commands:

```bash
# Start the service
./install.sh start

# Stop the service
./install.sh stop

# Restart the service
./install.sh restart

# Check service status
./install.sh status

# View logs
./install.sh logs

# Uninstall completely
./install.sh uninstall
```

### Mount Helper Script

The `scripts/mount_helper.sh` script can be used manually:

```bash
# Mount a USB device
./scripts/mount_helper.sh mount /dev/sdb1 my_usb

# Launch kiosk mode manually
./scripts/mount_helper.sh kiosk /mnt/casette/my_usb/index.html

# Unmount a device
./scripts/mount_helper.sh unmount /mnt/casette/my_usb

# Stop kiosk and cleanup all mounts
./scripts/mount_helper.sh cleanup
```

## Configuration

### File Structure

```
/home/Adam/repos/casette/
├── scripts/
│   ├── usb_monitor.py          # Main monitoring service
│   └── mount_helper.sh         # Mount/unmount utilities
├── logs/                       # Log files
├── venv/                       # Python virtual environment
├── casette-usb-monitor.service # Systemd service file
├── install.sh                  # Installation script
├── requirements.txt            # Python dependencies
└── README.md                  # This file
```

### Service Configuration

The systemd service is configured in `casette-usb-monitor.service`:

- **User**: Adam
- **Environment**: DISPLAY=:0 for X11 access
- **Auto-restart**: Yes, with 10-second delay
- **Logs**: Written to `logs/` directory

### Mount Points

USB drives are mounted under `/mnt/casette/` with the following naming:
- If the drive has a label: `/mnt/casette/<label>`
- If no label: `/mnt/casette/usb_<device_name>`

### Logging

Logs are written to multiple locations:

- **Service logs**: `sudo journalctl -u casette-usb-monitor -f`
- **Application logs**: `tail -f logs/usb_monitor.log`
- **Mount helper logs**: `logs/mount_helper.log`

## Troubleshooting

### Service Won't Start

```bash
# Check service status
sudo systemctl status casette-usb-monitor

# Check logs
sudo journalctl -u casette-usb-monitor -n 50
```

### USB Drive Not Mounting

1. Check if the drive appears in system logs:
   ```bash
   dmesg | tail -20
   ```

2. Verify the drive is detected:
   ```bash
   lsblk
   ```

3. Check mount permissions:
   ```bash
   ls -la /mnt/casette/
   ```

### Chromium Not Opening

1. Verify DISPLAY environment variable:
   ```bash
   echo $DISPLAY
   ```

2. Test Chromium manually:
   ```bash
   DISPLAY=:0 chromium-browser --kiosk file:///path/to/index.html
   ```

3. Check X11 permissions:
   ```bash
   xhost +local:
   ```

### Permission Issues

The service requires specific sudo permissions. If mounting fails:

```bash
# Check sudoers configuration
sudo visudo -f /etc/sudoers.d/casette-usb-monitor

# The file should contain:
# Adam ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount
```

## Security Considerations

- The service runs with limited sudo privileges for mounting only
- Chromium runs in a sandboxed environment
- USB drives are mounted with standard permissions
- Only `index.html` files in the root directory are automatically opened

## Uninstallation

To completely remove the service:

```bash
./install.sh uninstall
```

This will:
- Stop and disable the systemd service
- Remove service files
- Clean up sudoers configuration
- Unmount any active USB drives

## Development

### Dependencies

- **pyudev**: Python bindings for udev device management
- **chromium-browser**: Web browser for kiosk mode
- **udisks2**: USB device management utilities

### Architecture

1. **USB Monitor** (`usb_monitor.py`): Main service using pyudev to monitor device events
2. **Mount Helper** (`mount_helper.sh`): Utilities for mounting and Chromium management  
3. **Systemd Service**: Integration with Linux service management
4. **Installation Script**: Automated setup and configuration

### Customization

To modify the service behavior, edit:

- `scripts/usb_monitor.py`: Change monitoring logic, file detection
- `scripts/mount_helper.sh`: Modify mounting behavior, Chromium options
- `casette-usb-monitor.service`: Adjust service configuration

## License

This project is provided as-is for educational and personal use.

## Support

Check the logs for detailed error messages:

```bash
# View all logs
./install.sh logs

# Monitor live logs
sudo journalctl -u casette-usb-monitor -f
tail -f logs/usb_monitor.log
```