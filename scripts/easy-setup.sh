#!/bin/bash
#
# Dia Assistant Easy Setup
# One-click setup for non-technical users

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
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Welcome message
clear
echo -e "${PURPLE}${BOLD}"
echo "  ____  _         _                _     _              _    "
echo " |  _ \\(_) __ _  / \\   ___ ___  __(_)___| |_ __ _ _ __ | |_  "
echo " | | | | |/ _\` |/ _ \\ / __/ __|/ _\` / __| __/ _\` | '_ \\| __| "
echo " | |_| | | (_| / ___ \\\\__ \\__ \\ (_| \\__ \\ || (_| | | | | |_  "
echo " |____/|_|\\__,_/_/   \\_\\___/___/\\__,_|___/\\__\\__,_|_| |_|\\__| "
echo -e "${NOBOLD}${NC}"
echo -e "${CYAN}${BOLD}Your Personal Offline AI Voice Assistant${NOBOLD}${NC}"
echo ""
echo -e "${BOLD}Welcome to the Dia Assistant Easy Setup!${NOBOLD}"
echo ""
echo "This script will set up everything you need to start using Dia."
echo "Just sit back and relax while we get everything ready for you."
echo ""
read -p "Press Enter to begin setup..."

print_header "Checking System Requirements"

# Check if Dia is already installed
if [ -d "/opt/dia" ]; then
    print_success "Dia Assistant is already installed"
else
    print_error "Dia Assistant is not installed. Please run the main installation script first."
    exit 1
fi

# Check for a connected microphone
echo "Checking for audio devices..."
if arecord -l | grep -q "card"; then
    print_success "Microphone detected"
else
    print_warning "No microphone detected. You'll need to connect one to use voice commands."
fi

# Check for speakers
if aplay -l | grep -q "card"; then
    print_success "Speakers detected"
else
    print_warning "No speakers detected. You'll need to connect speakers to hear Dia's responses."
fi

# Check for NVMe drive
if [ -d "/mnt/nvme" ]; then
    print_success "NVMe drive detected"
    
    # Check available space
    available=$(df -h /mnt/nvme | awk 'NR==2 {print $4}')
    echo "Available space: $available"
else
    print_warning "NVMe drive not detected. Using internal storage instead."
fi

print_header "Creating Desktop Shortcut"
# Create a desktop shortcut for easy access
if [ -f "/opt/dia/scripts/create-desktop-shortcut.sh" ]; then
    cd ~
    /opt/dia/scripts/create-desktop-shortcut.sh
else
    print_warning "Desktop shortcut script not found. Skipping this step."
fi

print_header "Setting Up Command Aliases"
# Add convenient aliases to the user's shell configuration
username=$(logname)
user_home=$(getent passwd $username | cut -d: -f6)

if [ -f "$user_home/.bashrc" ]; then
    if ! grep -q "alias dia=" "$user_home/.bashrc"; then
        echo 'alias dia="sudo /opt/dia/scripts/dia-easy.sh"' >> "$user_home/.bashrc"
    fi
fi

if [ -f "$user_home/.zshrc" ]; then
    if ! grep -q "alias dia=" "$user_home/.zshrc"; then
        echo 'alias dia="sudo /opt/dia/scripts/dia-easy.sh"' >> "$user_home/.zshrc"
    fi
fi

print_success "Command alias 'dia' created"

print_header "Configuring Auto-Start"
# Set up Dia to start automatically on boot
systemctl enable dia.service
print_success "Dia will now start automatically when you turn on your Raspberry Pi"

print_header "Setting Up Default Voice"
# Create a friendly default voice
if [ -f "/opt/dia/scripts/dia-voice.sh" ]; then
    cd /opt/dia/config/voice_profiles
    
    # Create a friendly default voice if it doesn't exist
    if [ ! -f "friendly.yaml" ]; then
        cat > "friendly.yaml" << EOF
voice_type: espeak
voice_id: en+f3
speed: 1.0
pitch: 1.2
volume: 1.0
description: "Friendly, welcoming voice"
date_created: "$(date)"
EOF
        
        # Update main config to use this voice
        cd /opt/dia/config
        python3 -c "
import yaml

# Load config
with open('dia.yaml', 'r') as f:
    config = yaml.safe_load(f) or {}

# Ensure TTS section exists
if 'tts' not in config:
    config['tts'] = {}

# Update TTS settings
config['tts']['voice_profile'] = 'friendly'
config['tts']['engine'] = 'espeak'
config['tts']['voice_id'] = 'en+f3'
config['tts']['speed'] = 1.0
config['tts']['pitch'] = 1.2
config['tts']['volume'] = 1.0

# Save config
with open('dia.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
        print_success "Set up a friendly default voice"
    else
        print_success "Voice profiles already set up"
    fi
else
    print_warning "Voice configuration tool not found. Skipping voice setup."
fi

print_header "Creating Quick Start User Guide"
# Create a simple user guide in the user's home directory
guide_file="$user_home/DIA_QUICK_START.txt"

cat > "$guide_file" << 'EOF'
=====================================================
            DIA ASSISTANT QUICK START GUIDE
=====================================================

Welcome to Dia, your personal AI voice assistant!

GETTING STARTED:
---------------
1. Just say "Hey Dia" to wake up your assistant
2. Ask any question or give a command
3. Dia will respond with its friendly voice

EASY COMMANDS:
-------------
* "Hey Dia, what time is it?"
* "Hey Dia, tell me about elephants"
* "Hey Dia, what's the capital of France?"
* "Hey Dia, tell me a joke"

MANAGING DIA:
-----------
Type "dia" in the terminal or click the Dia icon on your desktop
to access the easy management menu where you can:
  - Change Dia's voice
  - Add knowledge to Dia's database
  - Check system status
  - And much more!

NEED HELP?
---------
If you need assistance, just ask:
"Hey Dia, I need help" or "Hey Dia, what can you do?"

Enjoy your personal AI assistant!
=====================================================
EOF

chown $username:$username "$guide_file"
print_success "Created quick start guide at $guide_file"

print_header "Setup Complete!"
echo ""
echo -e "${GREEN}${BOLD}Dia Assistant is now set up and ready to use!${NOBOLD}${NC}"
echo ""
echo "You can start using Dia in these ways:"
echo ""
echo -e "1. Say ${CYAN}\"Hey Dia\"${NC} to wake it up and ask a question"
echo -e "2. Type ${CYAN}dia${NC} in the terminal to access the management menu"
echo -e "3. Click the ${CYAN}Dia Assistant${NC} icon on your desktop"
echo ""
echo -e "Check the ${CYAN}DIA_QUICK_START.txt${NC} file in your home directory for more tips."
echo ""
echo -e "${YELLOW}Note: If you've just connected your microphone and speakers, you might need to restart once.${NC}"
echo ""
echo -e "Would you like to start Dia now? (y/n)"
read -p "> " start_now

if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
    systemctl start dia.service
    print_success "Dia Assistant started!"
    echo ""
    echo "Try saying \"Hey Dia\" followed by a question."
else
    echo ""
    echo "You can start Dia later by saying \"Hey Dia\" or by typing \"dia\" in the terminal."
fi

echo ""
echo -e "${BLUE}${BOLD}Enjoy your personal AI assistant!${NOBOLD}${NC}"
