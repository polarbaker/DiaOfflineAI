#!/bin/bash
#
# Setup for Dia Visual Speech Test
# Installs dependencies and prepares the visual feedback tool

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
fi

echo -e "${BLUE}===== Setting up Dia Visual Speech Test Tool =====${NC}"
echo ""
echo "This will install the necessary dependencies for the visual speech test tool."
echo ""

# Ensure Python 3 and pip are installed
echo "Checking for Python 3..."
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install it first."
fi
print_success "Python 3 is installed"

# Ensure pip is installed
echo "Checking for pip..."
if ! command -v pip3 &> /dev/null; then
    echo "Installing pip..."
    apt-get update
    apt-get install -y python3-pip
fi
print_success "pip is installed"

# Install Python dependencies
echo "Installing required Python packages..."
pip3 install vosk pyaudio tkinter

# Install system dependencies
echo "Installing system dependencies..."
apt-get install -y python3-tk portaudio19-dev

# Copy the visual test script to the correct location
echo "Installing the visual test script..."
cp /home/thomasbaker/dia-assistant/scripts/dia-visual-test.py /opt/dia/scripts/
chmod +x /opt/dia/scripts/dia-visual-test.py

# Create a desktop shortcut
echo "Creating desktop shortcut..."
cat > /home/thomasbaker/Desktop/DiaVisualTest.desktop << EOF
[Desktop Entry]
Name=Dia Visual Test
Comment=Visual Speech Test for Dia Assistant
Exec=sudo /opt/dia/scripts/dia-visual-test.py
Icon=/opt/dia/assets/dia-icon.png
Terminal=false
Type=Application
Categories=Utility;
EOF

chown thomasbaker:thomasbaker /home/thomasbaker/Desktop/DiaVisualTest.desktop
chmod +x /home/thomasbaker/Desktop/DiaVisualTest.desktop

# Create an alias
echo "Creating command alias..."
if grep -q "alias dia-visual" /home/thomasbaker/.bashrc; then
    echo "Alias already exists."
else
    echo 'alias dia-visual="sudo /opt/dia/scripts/dia-visual-test.py"' >> /home/thomasbaker/.bashrc
    echo 'alias dia-visual="sudo /opt/dia/scripts/dia-visual-test.py"' >> /home/thomasbaker/.zshrc
fi

print_success "Setup complete!"
echo ""
echo "You can now run the visual test tool by:"
echo "1. Typing 'dia-visual' in the terminal"
echo "2. Clicking on the 'Dia Visual Test' icon on your desktop"
echo ""
echo "Enjoy testing your Dia Assistant with visual feedback!"
