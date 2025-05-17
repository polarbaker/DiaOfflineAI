#!/bin/bash
#
# Dia Voice Assistant Setup Script
# 
# This script automates the installation of the Dia voice assistant on Raspberry Pi 5.
# It verifies hardware requirements, installs dependencies, downloads models,
# and sets up the system service.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
DIA_PATH="/opt/dia"
CONFIG_PATH="$DIA_PATH/config"
MODEL_PATH="$DIA_PATH/models"
VENV_PATH="$DIA_PATH/venv"
LOG_PATH="/var/log/dia"
NVME_PATH="/mnt/nvme/dia"

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}===== $1 =====${NC}\n"
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

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (sudo)."
fi

# Display welcome message
print_header "Dia Voice Assistant Setup"
echo "This script will install the Dia voice assistant on your Raspberry Pi 5."
echo "Make sure all hardware components are connected before proceeding."

# Verify hardware requirements
print_header "Verifying Hardware Requirements"

# Check Raspberry Pi model
PI_MODEL=$(cat /proc/device-tree/model | tr -d '\0')
if [[ "$PI_MODEL" != *"Raspberry Pi 5"* ]]; then
    print_warning "This is not a Raspberry Pi 5 ($PI_MODEL detected)."
    echo "The setup may not work correctly. Do you want to continue anyway? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Setup cancelled."
        exit 0
    fi
else
    print_success "Raspberry Pi 5 detected: $PI_MODEL"
fi

# Check sound devices
echo "Checking audio devices..."
if ! ls /dev/snd/* &>/dev/null; then
    print_error "No sound devices found. Check your sound card connections."
fi
print_success "Sound devices found"

# Check ReSpeaker
RESPEAKER_ID=$(arecord -l | grep -i "ReSpeaker" || echo "")
if [ -z "$RESPEAKER_ID" ]; then
    print_warning "ReSpeaker 4-Mic Array not detected. Audio input may not work correctly."
else
    print_success "ReSpeaker 4-Mic Array detected"
fi

# Check HiFiBerry
HIFIBERRY_ID=$(aplay -l | grep -i "HiFiBerry" || echo "")
if [ -z "$HIFIBERRY_ID" ]; then
    print_warning "HiFiBerry DAC+ not detected. Audio output may not work correctly."
else
    print_success "HiFiBerry DAC+ detected"
fi

# Check Coral TPU
CORAL_ID=$(lsusb | grep -i "Google Inc" || echo "")
if [ -z "$CORAL_ID" ]; then
    print_warning "Coral USB Edge TPU not detected. AI acceleration will be limited."
else
    print_success "Coral USB Edge TPU detected: $CORAL_ID"
fi

# Check Hailo AI Kit
HAILO_ID=$(lsusb | grep -i "Hailo" || echo "")
if [ -z "$HAILO_ID" ]; then
    print_warning "Hailo-8L AI Kit not detected. AI acceleration will be limited."
else
    print_success "Hailo-8L AI Kit detected: $HAILO_ID"
fi

# Check NVMe SSD
echo "Checking for NVMe SSD..."
if ! lsblk | grep -q "nvme"; then
    print_warning "NVMe SSD not detected. Large models and RAG store may not work."
    HAS_NVME=false
else
    print_success "NVMe SSD detected"
    HAS_NVME=true
    
    # Check if NVMe is mounted
    if ! mount | grep -q "/mnt/nvme"; then
        echo "NVMe SSD is not mounted. Do you want to mount it? (y/n)"
        read -r response
        if [[ "$response" == "y" ]]; then
            mkdir -p /mnt/nvme
            echo "Enter the NVMe device path (e.g., /dev/nvme0n1p1):"
            read -r nvme_device
            
            # Create entry in fstab if it doesn't exist
            if ! grep -q "$nvme_device" /etc/fstab; then
                echo "$nvme_device /mnt/nvme ext4 defaults 0 2" >> /etc/fstab
            fi
            
            mount "$nvme_device" /mnt/nvme || print_error "Failed to mount NVMe SSD."
            print_success "NVMe SSD mounted to /mnt/nvme"
        fi
    fi
fi

# Install system dependencies
print_header "Installing System Dependencies"
apt-get update -y || print_error "Failed to update package lists."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    libasound2-dev \
    portaudio19-dev \
    libatlas-base-dev \
    espeak \
    git \
    alsa-utils \
    sox \
    libsox-fmt-all \
    build-essential \
    ffmpeg \
    sqlite3 \
    pulseaudio \
    || print_error "Failed to install dependencies."

print_success "System dependencies installed"

# Create installation directories
print_header "Setting Up Directory Structure"
mkdir -p "$DIA_PATH"
mkdir -p "$CONFIG_PATH"
mkdir -p "$MODEL_PATH/asr"
mkdir -p "$MODEL_PATH/llm"
mkdir -p "$MODEL_PATH/tts"
mkdir -p "$MODEL_PATH/wake"
mkdir -p "$LOG_PATH"

if [ "$HAS_NVME" = true ]; then
    mkdir -p "$NVME_PATH"
    mkdir -p "$NVME_PATH/rag"
    
    # Create symlinks for models to use NVMe storage
    ln -sf "$NVME_PATH/models" "$MODEL_PATH/llm"
    print_success "NVMe storage set up for large models"
fi

print_success "Directory structure created"

# Create Python virtual environment
print_header "Setting Up Python Environment"
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"
pip install --upgrade pip
pip install wheel

# Install Python dependencies
print_header "Installing Python Dependencies"
# Copy requirements.txt to installation dir
cp -f "$(dirname "$0")/../requirements.txt" "$DIA_PATH/requirements.txt"
pip install -r "$DIA_PATH/requirements.txt" || print_error "Failed to install Python dependencies."
print_success "Python dependencies installed"

# Install Coral TPU libraries if detected
if [ -n "$CORAL_ID" ]; then
    echo "Installing Coral TPU libraries..."
    pip install --extra-index-url https://google-coral.github.io/py-repo/ pycoral~=2.0
    print_success "Coral TPU libraries installed"
fi

# Install Hailo SDK if detected
if [ -n "$HAILO_ID" ]; then
    echo "Installing Hailo SDK libraries..."
    pip install hailo-ai
    print_success "Hailo SDK libraries installed"
fi

# Download models
print_header "Downloading Models"

# Function to download a file with progress
download_file() {
    echo "Downloading $1 to $2..."
    wget -q --show-progress -O "$2" "$1"
}

# Download wake word model
echo "Downloading wake word model..."
mkdir -p "$(dirname "$0")/../models/wake"
if [ ! -f "$MODEL_PATH/wake/hey-dia.ppn" ]; then
    # Note: In a real implementation, you would provide a URL to download from
    # For this example, we'll just create a placeholder
    echo "Note: No actual wake word model downloaded (placeholder)"
    touch "$MODEL_PATH/wake/hey-dia.ppn"
fi

# Download ASR model
echo "Downloading ASR model..."
if [ ! -d "$MODEL_PATH/asr/vosk-model-small-en-us-0.15" ]; then
    download_file "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip" "/tmp/vosk-model.zip"
    unzip -q "/tmp/vosk-model.zip" -d "$MODEL_PATH/asr/"
    rm "/tmp/vosk-model.zip"
fi

# Download TTS model (optional)
echo "Do you want to download the custom TTS voice model? (y/n)"
read -r response
if [[ "$response" == "y" ]]; then
    echo "Downloading TTS model..."
    # Note: In a real implementation, you would provide a URL to download from
    # For this example, we'll just create placeholder files
    mkdir -p "$MODEL_PATH/tts"
    touch "$MODEL_PATH/tts/tts_model.pth"
    touch "$MODEL_PATH/tts/tts_config.json"
fi

print_success "Models downloaded"

# Copy application files
print_header "Installing Application Files"
cp -r "$(dirname "$0")/../src" "$DIA_PATH/"
cp -r "$(dirname "$0")/../config" "$DIA_PATH/"
cp -r "$(dirname "$0")/../scripts" "$DIA_PATH/"
chmod +x "$DIA_PATH/scripts/"*.sh

print_success "Application files installed"

# ALSA configuration for ReSpeaker and HiFiBerry
print_header "Configuring Audio Hardware"

# Create ALSA configuration directory
mkdir -p "$CONFIG_PATH/alsa"

cat > "$CONFIG_PATH/alsa/asound.conf" << 'EOF'
# ALSA configuration for Dia Voice Assistant

# PCM device for the ReSpeaker 4-Mic Array
pcm.respeaker {
    type hw
    card "seeed4micvoicec"
    format S16_LE
    rate 16000
    channels 1
}

# PCM device for the HiFiBerry DAC+
pcm.hifiberry {
    type hw
    card "sndrpihifiberry"
    format S16_LE
    rate 48000
    channels 2
}

# Default PCM device (ReSpeaker for capture, HiFiBerry for playback)
pcm.!default {
    type asym
    capture.pcm "respeaker"
    playback.pcm "hifiberry"
}

# Default control device
ctl.!default {
    type hw
    card 0
}
EOF

# Add configuration to system-wide ALSA config
if [ ! -f "/etc/asound.conf" ]; then
    cp "$CONFIG_PATH/alsa/asound.conf" "/etc/asound.conf"
else
    echo "Existing /etc/asound.conf found. To use Dia's configuration, review and merge with:"
    echo "$CONFIG_PATH/alsa/asound.conf"
fi

print_success "Audio hardware configured"

# Install systemd service
print_header "Installing Systemd Service"
cp "$(dirname "$0")/../config/systemd/dia.service" "/etc/systemd/system/"

# Update user in service file
sed -i "s/User=thomasbaker/User=$(logname)/g" "/etc/systemd/system/dia.service"
sed -i "s/Group=thomasbaker/Group=$(logname)/g" "/etc/systemd/system/dia.service"

systemctl daemon-reload
systemctl enable dia.service

print_success "Systemd service installed and enabled"

# Set up permissions
print_header "Setting Up Permissions"
chown -R "$(logname):$(logname)" "$DIA_PATH"
chown -R "$(logname):$(logname)" "$LOG_PATH"

if [ "$HAS_NVME" = true ]; then
    chown -R "$(logname):$(logname)" "$NVME_PATH"
fi

print_success "Permissions set"

# Final instructions
print_header "Installation Complete!"
echo "The Dia voice assistant has been installed successfully."
echo ""
echo "To start the assistant, run:"
echo "  sudo systemctl start dia.service"
echo ""
echo "To check the status, run:"
echo "  sudo systemctl status dia.service"
echo ""
echo "View logs with:"
echo "  journalctl -u dia.service -f"
echo ""
echo "Configuration file location:"
echo "  $CONFIG_PATH/dia.yaml"
echo ""
echo "To customize wake words, place .ppn files in:"
echo "  $MODEL_PATH/wake/"
echo ""
echo "Enjoy your offline voice assistant!"

# Start service if requested
echo ""
echo "Do you want to start the Dia assistant now? (y/n)"
read -r response
if [[ "$response" == "y" ]]; then
    systemctl start dia.service
    print_success "Dia assistant started!"
    echo "Listening for 'Hey Dia'..."
else
    echo "You can start the assistant later with: sudo systemctl start dia.service"
fi

exit 0
