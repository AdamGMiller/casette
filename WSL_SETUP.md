# WSL Setup and Troubleshooting Guide

## WSL-Specific Configuration for Casette USB Monitor

### Prerequisites for WSL

1. **Install WSL2 USB Support** (Windows 11 22H2+ or Windows 10 with updates)
   ```powershell
   # In Windows PowerShell (as Administrator)
   winget install --interactive --exact dorssel.usbipd-win
   ```

2. **Install X11 Server** (for Chromium display)
   ```bash
   # Install VcXsrv or similar X11 server on Windows
   # Or use WSLg (built into recent WSL versions)
   ```

3. **Configure Display Environment**
   ```bash
   # Add to ~/.bashrc or ~/.profile
   export DISPLAY=:0
   # Or for WSLg:
   export DISPLAY=:0.0
   ```

### USB Device Setup in WSL

#### Method 1: Using usbipd-win (Recommended)

1. **List USB devices in Windows PowerShell:**
   ```powershell
   usbipd list
   ```

2. **Bind and attach USB device:**
   ```powershell
   # Replace <BUSID> with your USB device's bus ID
   usbipd bind --busid <BUSID>
   usbipd attach --wsl --busid <BUSID>
   ```

3. **Verify in WSL:**
   ```bash
   lsblk
   dmesg | tail -10
   ```

#### Method 2: Using Windows Mount Points

Alternatively, you can monitor Windows-mounted drives:

```bash
# Windows drives are accessible at /mnt/c/, /mnt/d/, etc.
ls /mnt/
```

### Monitoring Commands

#### Real-time USB Monitoring
```bash
# Terminal 1: Monitor application logs
tail -f /home/Adam/repos/casette/logs/usb_monitor.log

# Terminal 2: Monitor system events  
sudo journalctl -u casette-usb-monitor -f

# Terminal 3: Monitor udev events
udevadm monitor --subsystem-match=block
```

#### Check Service Health
```bash
# Service status
sudo systemctl status casette-usb-monitor

# Recent logs
sudo journalctl -u casette-usb-monitor -n 50

# Application logs with timestamps
cat /home/Adam/repos/casette/logs/usb_monitor.log
```

### Expected Log Messages

#### Normal Operation
```
2025-09-26 10:11:39,583 - INFO - Starting Casette USB Monitor Service
2025-09-26 10:11:39,585 - INFO - Starting USB device monitoring...
2025-09-26 10:11:39,585 - INFO - USB monitor started successfully. Press Ctrl+C to stop.
```

#### USB Device Insertion
```
2025-09-26 10:15:20,123 - INFO - USB device inserted: {'name': '/dev/sde1', 'label': 'MY_USB', 'uuid': '1234-5678', 'filesystem': 'vfat'}
2025-09-26 10:15:22,456 - INFO - Successfully mounted /dev/sde1 to /mnt/casette/MY_USB
2025-09-26 10:15:22,789 - INFO - Found index.html at /mnt/casette/MY_USB/index.html
2025-09-26 10:15:23,012 - INFO - Launched Chromium in kiosk mode with /mnt/casette/MY_USB/index.html
```

#### USB Device Removal
```
2025-09-26 10:20:15,345 - INFO - USB device removed: {'name': '/dev/sde1', 'label': 'MY_USB'}
2025-09-26 10:20:15,678 - INFO - Killed existing Chromium processes
2025-09-26 10:20:17,901 - INFO - Successfully unmounted /mnt/casette/MY_USB
```

### WSL-Specific Issues and Solutions

#### Issue: No USB devices detected
**Solution:**
1. Verify usbipd-win setup
2. Check if USB device is attached to WSL:
   ```bash
   lsusb
   lsblk
   ```

#### Issue: Chromium won't start
**Solution:**
1. Install X11 server (VcXsrv or use WSLg)
2. Set correct DISPLAY variable:
   ```bash
   export DISPLAY=:0
   # Test with:
   chromium --version
   ```

#### Issue: Permission denied for mounting
**Solution:**
1. Verify sudoers configuration:
   ```bash
   sudo cat /etc/sudoers.d/casette-usb-monitor
   ```
2. Test manual mount:
   ```bash
   sudo mount /dev/sdb1 /tmp/test_mount
   ```

### Testing the Service

#### Manual Test with Virtual USB
```bash
# Create a test directory that simulates a USB mount
sudo mkdir -p /mnt/casette/test_usb
echo "<html><body><h1>Test</h1></body></html>" | sudo tee /mnt/casette/test_usb/index.html

# Test Chromium launch manually
/home/Adam/repos/casette/scripts/mount_helper.sh kiosk /mnt/casette/test_usb/index.html

# Clean up
sudo rm -rf /mnt/casette/test_usb
```

#### Simulate USB Events
```bash
# Monitor what happens when we create a block device event
# This requires root access to trigger udev events
sudo udevadm trigger --subsystem-match=block
```

### Performance Monitoring

```bash
# Monitor system resources
top -p $(pgrep -f usb_monitor.py)

# Check mount points
mount | grep casette

# Monitor disk usage
df -h /mnt/casette/
```

### Troubleshooting Commands

```bash
# Restart the service
sudo systemctl restart casette-usb-monitor

# Check for Python errors
python3 /home/Adam/repos/casette/scripts/usb_monitor.py

# Test mount permissions
sudo mount --bind /tmp /mnt/casette/test
sudo umount /mnt/casette/test

# Check udev rules
udevadm info --query=all --name=/dev/sdb1
```

### WSL Configuration Files

Add these to your WSL configuration:

#### ~/.bashrc
```bash
# Casette USB Monitor environment
export DISPLAY=:0
alias casette-logs='tail -f /home/Adam/repos/casette/logs/usb_monitor.log'
alias casette-status='sudo systemctl status casette-usb-monitor'
```

#### /etc/wsl.conf
```ini
[boot]
systemd=true

[automount]
enabled=true
mountFsTab=false
```

### Alternative: File System Monitoring

If USB detection doesn't work reliably in WSL, consider monitoring mounted drives:

```bash
# Monitor /mnt/ for new directories (Windows drives)
inotifywait -m /mnt/ -e create -e moved_to --format '%w%f'
```