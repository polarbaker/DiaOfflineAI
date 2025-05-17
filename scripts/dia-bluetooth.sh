#!/bin/bash
#
# Dia Bluetooth Audio Setup
# Simple tool to connect Bluetooth audio devices to your Dia Assistant

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Bold text
BOLD='\033[1m'
NOBOLD='\033[0m'

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}${BOLD}===== $1 =====${NOBOLD}${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

# Install required packages
install_bluetooth_packages() {
    print_header "Installing Bluetooth Audio Packages"
    
    echo "Installing required packages. This may take a few minutes..."
    apt-get update
    apt-get install -y bluetooth bluez bluez-tools pulseaudio pulseaudio-module-bluetooth pavucontrol
    
    # Restart Bluetooth service
    systemctl enable bluetooth
    systemctl restart bluetooth
    
    # Add user to Bluetooth group
    username=$(logname)
    usermod -a -G bluetooth $username
    
    print_success "Bluetooth packages installed"
}

# Check if packages are installed
check_bluetooth_packages() {
    if ! dpkg -s bluetooth bluez pulseaudio-module-bluetooth &> /dev/null; then
        print_warning "Bluetooth audio packages not installed"
        echo -e "Would you like to install them now? (y/n)"
        read -p "> " install_now
        
        if [[ "$install_now" == "y" || "$install_now" == "Y" ]]; then
            install_bluetooth_packages
        else
            print_error "Required packages not installed. Cannot continue."
        fi
    else
        print_success "Bluetooth audio packages already installed"
    fi
}

# Connect to a Bluetooth device
connect_bluetooth_device() {
    print_header "Connect to Bluetooth Device"
    
    echo "Please follow these steps to connect your Bluetooth headset:"
    echo ""
    echo -e "${BOLD}Step 1:${NOBOLD} Put your headset in pairing mode"
    echo "  • Usually this means holding the power or pairing button"
    echo "  • Check your headset manual for exact instructions"
    echo "  • The headset's light should be blinking rapidly when in pairing mode"
    echo ""
    echo -e "${BOLD}Step 2:${NOBOLD} I'll now scan for available devices..."
    echo ""
    
    # Make sure Bluetooth is powered on
    echo "Turning on Bluetooth..."
    bluetoothctl power on
    
    # Start scanning
    echo "Scanning for devices... (this will take about 10 seconds)"
    bluetoothctl scan on &
    scan_pid=$!
    sleep 10
    kill $scan_pid &>/dev/null || true
    
    # List available devices
    devices=$(bluetoothctl devices | cut -d ' ' -f 2-)
    
    # Check if any devices were found
    if [ -z "$devices" ]; then
        print_warning "No Bluetooth devices found. Make sure your headset is in pairing mode."
        echo "Would you like to try scanning again? (y/n)"
        read -p "> " scan_again
        
        if [[ "$scan_again" == "y" || "$scan_again" == "Y" ]]; then
            connect_bluetooth_device
            return
        else
            print_error "No devices found. Cannot continue."
        fi
    fi
    
    # Display available devices
    echo ""
    echo -e "${BOLD}Available Devices:${NOBOLD}"
    echo ""
    
    # Create an array to store device MAC addresses
    declare -a device_macs
    declare -a device_names
    
    # Parse devices output
    i=1
    while IFS= read -r line; do
        if [[ $line =~ Device\ ([0-9A-F:]+)\ (.*) ]]; then
            mac="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            device_macs+=("$mac")
            device_names+=("$name")
            echo "$i) $name ($mac)"
            ((i++))
        fi
    done <<< "$(bluetoothctl devices)"
    
    # Let user select a device
    echo ""
    echo -e "${BOLD}Step 3:${NOBOLD} Select your headset from the list above"
    read -p "Enter the number [1-$((i-1))]: " device_num
    
    # Validate input
    if ! [[ "$device_num" =~ ^[0-9]+$ ]] || [ "$device_num" -lt 1 ] || [ "$device_num" -gt $((i-1)) ]; then
        print_error "Invalid selection"
    fi
    
    # Get selected device
    selected_mac=${device_macs[$((device_num-1))]}
    selected_name=${device_names[$((device_num-1))]}
    
    echo ""
    echo -e "${BOLD}Step 4:${NOBOLD} Connecting to $selected_name..."
    
    # Pair and connect to the device
    echo "Pairing with device..."
    bluetoothctl pair $selected_mac
    
    echo "Trusting device for future connections..."
    bluetoothctl trust $selected_mac
    
    echo "Connecting to device..."
    bluetoothctl connect $selected_mac
    
    # Check if connection was successful
    if bluetoothctl info $selected_mac | grep -q "Connected: yes"; then
        print_success "Successfully connected to $selected_name"
        
        # Save device to config
        save_bluetooth_config "$selected_mac" "$selected_name"
    else
        print_warning "Failed to connect to $selected_name"
        echo "Would you like to try again? (y/n)"
        read -p "> " try_again
        
        if [[ "$try_again" == "y" || "$try_again" == "Y" ]]; then
            connect_bluetooth_device
            return
        fi
    fi
}

# Save Bluetooth configuration
save_bluetooth_config() {
    local device_mac=$1
    local device_name=$2
    
    print_header "Configuring Audio"
    
    # Set as default audio output and input
    echo "Setting $device_name as default audio device..."
    
    # Create a PulseAudio configuration file
    mkdir -p /etc/pulse/default.pa.d/
    cat > /etc/pulse/default.pa.d/dia-bluetooth.pa << EOF
# Automatically connect to the Bluetooth headset when available
load-module module-switch-on-connect

# Set Bluetooth device as default when connected
set-default-sink bluez_sink.${device_mac//:/_}.a2dp_sink
set-default-source bluez_source.${device_mac//:/_}.headset_head_unit
EOF
    
    # Update Dia configuration
    if [ -f "/opt/dia/config/dia.yaml" ]; then
        # Update audio configuration in Dia's config file
        python3 -c "
import yaml

# Load config
with open('/opt/dia/config/dia.yaml', 'r') as f:
    config = yaml.safe_load(f) or {}

# Ensure audio section exists
if 'audio' not in config:
    config['audio'] = {}

# Update audio settings
config['audio']['input_device'] = 'bluez_source.${device_mac//:/_}.headset_head_unit'
config['audio']['output_device'] = 'bluez_sink.${device_mac//:/_}.a2dp_sink'
config['audio']['use_bluetooth'] = True

# Save config
with open('/opt/dia/config/dia.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
        print_success "Updated Dia Assistant configuration to use Bluetooth audio"
    else
        print_warning "Dia configuration file not found. Audio settings not updated."
    fi
    
    # Create a script to automatically reconnect the device
    cat > /opt/dia/scripts/bluetooth-reconnect.sh << EOF
#!/bin/bash
# Automatically reconnect to the Bluetooth headset
bluetoothctl connect ${device_mac}
EOF
    
    chmod +x /opt/dia/scripts/bluetooth-reconnect.sh
    
    # Set up a udev rule to run the script when the device is detected
    cat > /etc/udev/rules.d/99-bluetooth-headset.rules << EOF
ACTION=="add", SUBSYSTEM=="bluetooth", ATTR{address}=="${device_mac}", RUN+="/opt/dia/scripts/bluetooth-reconnect.sh"
EOF
    
    # Reload udev rules
    udevadm control --reload-rules
    
    print_success "Bluetooth headset configured for automatic connection"
    
    # Restart PulseAudio
    echo "Restarting audio service..."
    systemctl --user restart pulseaudio
    
    # Restart Dia if running
    if systemctl is-active --quiet dia.service; then
        echo "Restarting Dia Assistant to apply new audio settings..."
        systemctl restart dia.service
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}Bluetooth headset setup complete!${NOBOLD}${NC}"
    echo ""
    echo "Your Bluetooth headset is now configured for use with Dia Assistant."
    echo "The headset will automatically connect when turned on and in range."
    echo ""
    echo "To test your setup:"
    echo "1. Make sure your headset is connected and turned on"
    echo "2. Say \"Hey Dia\" followed by a question"
    echo "3. You should hear Dia's response through your headset"
}

# List connected devices
list_devices() {
    print_header "Connected Bluetooth Devices"
    
    connected_devices=$(bluetoothctl devices Connected)
    
    if [ -z "$connected_devices" ]; then
        echo "No devices currently connected."
    else
        echo -e "${BOLD}Currently Connected Devices:${NOBOLD}"
        echo ""
        
        while IFS= read -r line; do
            if [[ $line =~ Device\ ([0-9A-F:]+)\ (.*) ]]; then
                mac="${BASH_REMATCH[1]}"
                name="${BASH_REMATCH[2]}"
                echo "• $name ($mac)"
            fi
        done <<< "$connected_devices"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Test audio
test_audio() {
    print_header "Test Bluetooth Audio"
    
    echo "This will test your Bluetooth headset with Dia Assistant."
    echo ""
    echo "Make sure your headset is connected and turned on."
    echo ""
    read -p "Press Enter to begin the test..."
    
    # Check if headset is connected
    if ! bluetoothctl devices Connected | grep -q "Device"; then
        print_warning "No Bluetooth devices connected. Please connect your headset first."
        read -p "Would you like to connect a device now? (y/n) " connect_now
        
        if [[ "$connect_now" == "y" || "$connect_now" == "Y" ]]; then
            connect_bluetooth_device
        else
            read -p "Press Enter to continue..."
            show_menu
            return
        fi
    fi
    
    # Test output
    echo "Testing audio output to your headset..."
    echo "You should hear a test message in 3 seconds..."
    sleep 3
    
    espeak "This is a test of your Bluetooth headset with Dia Assistant. If you can hear this message, your output is working correctly."
    
    echo ""
    read -p "Did you hear the test message through your headset? (y/n) " heard_message
    
    if [[ "$heard_message" == "y" || "$heard_message" == "Y" ]]; then
        print_success "Audio output is working correctly!"
    else
        print_warning "Audio output test failed. Let's troubleshoot:"
        echo "1. Make sure your headset is turned on and connected"
        echo "2. Check that your headset volume is turned up"
        echo "3. Try reconnecting your headset"
        echo ""
        read -p "Would you like to reconnect your headset now? (y/n) " reconnect
        
        if [[ "$reconnect" == "y" || "$reconnect" == "Y" ]]; then
            connect_bluetooth_device
        fi
    fi
    
    # Test input
    echo ""
    echo "Now let's test the microphone on your headset."
    echo "I'll record 5 seconds of audio and play it back to you."
    echo ""
    read -p "Press Enter when you're ready to begin recording..."
    
    echo "Recording will start in 3 seconds. Please say something..."
    sleep 3
    
    # Record audio
    arecord -d 5 -f cd /tmp/bluetooth_test.wav
    
    echo "Recording complete. Playing back what you said..."
    sleep 1
    
    # Play back recording
    aplay /tmp/bluetooth_test.wav
    
    echo ""
    read -p "Did you hear your voice played back? (y/n) " heard_voice
    
    if [[ "$heard_voice" == "y" || "$heard_voice" == "Y" ]]; then
        print_success "Audio input is working correctly!"
    else
        print_warning "Audio input test failed. Let's troubleshoot:"
        echo "1. Make sure your headset microphone is not muted"
        echo "2. Some headsets have a separate button to enable the microphone"
        echo "3. Try reconnecting your headset"
        echo ""
        read -p "Would you like to reconnect your headset now? (y/n) " reconnect
        
        if [[ "$reconnect" == "y" || "$reconnect" == "Y" ]]; then
            connect_bluetooth_device
        fi
    fi
    
    # Clean up
    rm -f /tmp/bluetooth_test.wav
    
    # Final result
    if [[ "$heard_message" == "y" && "$heard_voice" == "y" ]]; then
        echo ""
        print_success "Bluetooth headset test completed successfully!"
        echo "Your headset is now configured for use with Dia Assistant."
    else
        echo ""
        print_warning "Bluetooth headset test completed with issues."
        echo "You may need to adjust your headset settings or reconnect it."
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Show menu
show_menu() {
    clear
    print_header "Dia Bluetooth Audio Setup"
    
    echo -e "${BOLD}What would you like to do?${NOBOLD}"
    echo ""
    echo "1) Connect a Bluetooth Headset"
    echo "2) List Connected Devices"
    echo "3) Test Bluetooth Audio"
    echo "4) Exit"
    echo ""
    read -p "Enter your choice [1-4]: " choice
    
    case $choice in
        1) connect_bluetooth_device ;;
        2) list_devices ;;
        3) test_audio ;;
        4) exit 0 ;;
        *) print_warning "Invalid choice. Please try again."; sleep 2; show_menu ;;
    esac
}

# Check if running as root
check_root

# Check if Bluetooth packages are installed
check_bluetooth_packages

# Show menu
show_menu
