#!/home/Adam/repos/casette/venv/bin/python
"""
USB Monitor Service for Casette Project

This service monitors for USB drive insertions using udev and automatically:
1. Mounts the USB drive
2. Checks for an index.html file in the root
3. Opens it in Chromium in fullscreen kiosk mode
"""

import os
import sys
import time
import logging
import subprocess
import threading
from pathlib import Path
import pyudev

# Configuration
MOUNT_BASE = "/mnt/casette"
LOG_FILE = "/home/Adam/repos/casette/logs/usb_monitor.log"
DISPLAY = ":0"  # Default X display

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class USBMonitor:
    def __init__(self):
        self.context = pyudev.Context()
        self.monitor = pyudev.Monitor.from_netlink(self.context)
        self.monitor.filter_by(subsystem='block', device_type='partition')
        self.mounted_devices = set()
        
        # Ensure mount base directory exists
        os.makedirs(MOUNT_BASE, exist_ok=True)
        
    def is_usb_device(self, device):
        """Check if the device is a USB storage device"""
        try:
            # Walk up the device tree to find USB subsystem
            current = device
            while current:
                if current.subsystem == 'usb':
                    return True
                current = current.parent
            return False
        except Exception:
            return False
    
    def get_device_info(self, device):
        """Extract device information"""
        device_name = device.get('DEVNAME', '')
        device_label = device.get('ID_FS_LABEL', '')
        device_uuid = device.get('ID_FS_UUID', '')
        
        return {
            'name': device_name,
            'label': device_label or f"usb_{device_name.split('/')[-1]}",
            'uuid': device_uuid,
            'filesystem': device.get('ID_FS_TYPE', 'unknown')
        }
    
    def mount_device(self, device_info):
        """Mount the USB device"""
        device_name = device_info['name']
        mount_point = os.path.join(MOUNT_BASE, device_info['label'])
        
        try:
            # Create mount point
            os.makedirs(mount_point, exist_ok=True)
            
            # Mount the device
            cmd = ['sudo', 'mount', device_name, mount_point]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"Successfully mounted {device_name} to {mount_point}")
                return mount_point
            else:
                logger.error(f"Failed to mount {device_name}: {result.stderr}")
                return None
                
        except Exception as e:
            logger.error(f"Error mounting device {device_name}: {e}")
            return None
    
    def unmount_device(self, device_info):
        """Unmount the USB device"""
        mount_point = os.path.join(MOUNT_BASE, device_info['label'])
        
        try:
            # Kill any Chromium processes that might be using the mount point
            self.kill_chromium()
            
            # Wait a moment for processes to clean up
            time.sleep(2)
            
            # Unmount the device
            cmd = ['sudo', 'umount', mount_point]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"Successfully unmounted {mount_point}")
                # Remove the mount point directory
                try:
                    os.rmdir(mount_point)
                except OSError:
                    logger.warning(f"Could not remove mount point directory {mount_point}")
            else:
                logger.error(f"Failed to unmount {mount_point}: {result.stderr}")
                
        except Exception as e:
            logger.error(f"Error unmounting device: {e}")
    
    def kill_chromium(self):
        """Kill any running Chromium processes"""
        try:
            subprocess.run(['pkill', '-f', 'chromium'], capture_output=True)
            logger.info("Killed existing Chromium processes")
        except Exception as e:
            logger.warning(f"Could not kill Chromium processes: {e}")
    
    def launch_chromium(self, html_path):
        """Launch Chromium in kiosk mode with the HTML file"""
        try:
            # Set environment variables for X display
            env = os.environ.copy()
            env['DISPLAY'] = DISPLAY
            
            # Kill any existing Chromium processes first
            self.kill_chromium()
            time.sleep(1)
            
            # Determine Chromium executable (Debian uses 'chromium', Ubuntu uses 'chromium-browser')
            chromium_cmd = 'chromium' if subprocess.run(['which', 'chromium'], 
                                                       capture_output=True).returncode == 0 else 'chromium-browser'
            
            # Chromium kiosk mode command
            cmd = [
                chromium_cmd,
                '--kiosk',
                '--no-sandbox',
                '--disable-web-security',
                '--disable-features=TranslateUI',
                '--disable-ipc-flooding-protection',
                '--start-fullscreen',
                f'file://{html_path}'
            ]
            
            # Launch Chromium in background
            process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            logger.info(f"Launched Chromium in kiosk mode with {html_path}")
            return process
            
        except Exception as e:
            logger.error(f"Error launching Chromium: {e}")
            return None
    
    def handle_device_add(self, device):
        """Handle USB device insertion"""
        if not self.is_usb_device(device):
            return
            
        device_info = self.get_device_info(device)
        logger.info(f"USB device inserted: {device_info}")
        
        # Wait a moment for the device to be ready
        time.sleep(2)
        
        # Mount the device
        mount_point = self.mount_device(device_info)
        if not mount_point:
            return
            
        self.mounted_devices.add(device_info['name'])
        
        # Look for index.html in the root of the mounted device
        index_path = os.path.join(mount_point, 'index.html')
        if os.path.exists(index_path):
            logger.info(f"Found index.html at {index_path}")
            # Launch Chromium in a separate thread to avoid blocking
            threading.Thread(
                target=self.launch_chromium,
                args=(index_path,),
                daemon=True
            ).start()
        else:
            logger.info(f"No index.html found in {mount_point}")
    
    def handle_device_remove(self, device):
        """Handle USB device removal"""
        if not self.is_usb_device(device):
            return
            
        device_info = self.get_device_info(device)
        device_name = device_info['name']
        
        if device_name in self.mounted_devices:
            logger.info(f"USB device removed: {device_info}")
            self.unmount_device(device_info)
            self.mounted_devices.discard(device_name)
    
    def start_monitoring(self):
        """Start monitoring for USB device events"""
        logger.info("Starting USB device monitoring...")
        
        try:
            # Start the udev monitor
            observer = pyudev.MonitorObserver(self.monitor, self.handle_udev_event)
            observer.start()
            
            logger.info("USB monitor started successfully. Press Ctrl+C to stop.")
            
            # Keep the main thread alive
            while True:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Received interrupt signal, stopping monitor...")
            observer.stop()
        except Exception as e:
            logger.error(f"Error in USB monitor: {e}")
        finally:
            # Clean up any mounted devices
            self.cleanup()
    
    def handle_udev_event(self, device):
        """Handle udev events"""
        action = device.action
        
        if action == 'add':
            self.handle_device_add(device)
        elif action == 'remove':
            self.handle_device_remove(device)
    
    def cleanup(self):
        """Clean up mounted devices on shutdown"""
        logger.info("Cleaning up mounted devices...")
        for device_name in list(self.mounted_devices):
            # This is a simplified cleanup - in a real scenario,
            # we'd need to track mount points properly
            try:
                subprocess.run(['sudo', 'umount', device_name], 
                             capture_output=True, timeout=10)
            except Exception:
                pass


def main():
    """Main entry point"""
    logger.info("Starting Casette USB Monitor Service")
    
    try:
        monitor = USBMonitor()
        monitor.start_monitoring()
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()