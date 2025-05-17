#!/bin/bash
#
# Dia Control Center Installer
# This script installs the Dia Control Center and creates desktop shortcuts
#

# Text colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}"
echo "┌─────────────────────────────────────────────┐"
echo "│                                             │"
echo "│           Dia Control Center                │"
echo "│               Installer                     │"
echo "│                                             │"
echo "└─────────────────────────────────────────────┘"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

echo -e "${BLUE}Installing Dia Control Center...${NC}"

# Install required packages
echo -e "${GREEN}Installing dependencies...${NC}"
apt-get update
apt-get install -y python3-tk python3-pil python3-pil.imagetk

# Make sure the scripts directory exists
SCRIPTS_DIR="/opt/dia/scripts"
mkdir -p "$SCRIPTS_DIR"

# Copy the control center script
echo -e "${GREEN}Installing Control Center...${NC}"
cp "$(dirname "$0")/dia-control-center.py" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR/dia-control-center.py"

# Create desktop shortcut
echo -e "${GREEN}Creating desktop shortcut...${NC}"
cat > /usr/share/applications/dia-control-center.desktop << EOL
[Desktop Entry]
Name=Dia Control Center
Comment=Manage your Dia Assistant
Exec=sudo /opt/dia/scripts/dia-control-center.py
Icon=/opt/dia/icons/dia.png
Terminal=false
Type=Application
Categories=Utility;
EOL

# Create icon directory and default icon if it doesn't exist
ICON_DIR="/opt/dia/icons"
mkdir -p "$ICON_DIR"

# Create a simple icon if it doesn't exist
if [ ! -f "$ICON_DIR/dia.png" ]; then
    echo -e "${GREEN}Creating default icon...${NC}"
    cat > "$ICON_DIR/dia.png" << EOL
iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAE
tElEQVRogdWabXLbNhCGH9JO4iZxZtLMdKY9Qo+QI/QIPUKPkCP0CDlCj9Aj9AjJTDt1k8avROgP
YSEJS7REUm6bZ4YjkQQWwLuLXYDE5cuXGHlPfE98xbP2AcQ3ECvgc/zsoCP3/O4qyF3B7+GCF8Ai
+n/AdQQSaC9oDbFkWlAs+Q7iZRxzF0HcK4AG8V30f0QcZCYN4s/4/S/QBk+9Q8Q8ZJ6Yh8y/ETPm
JDXwDdhGXwBfce4w4WgCGiF+jH9uGWfeIEW2cV1nI5AhNGXOMo+/Y0CLOME7xiG2d1a5V0ZV+AiR
KCCr6ApJoJcZf5ghlLklrCCcLIQ0AidTYQfnOgIXFrCDcLKtqk5lgdtpV20tIDBogUcTaEqkAOw2
ExEYtMAjCLSSC8QVxCJxgbJt9WbHfuFUwRgCLXJ/r0VagAfIrTuFQAdTt7dZvCQwYAE3GqcWuXrp
NR2RLXLb7d+FWgI9FrhJRpojFyhbZrBF9jkXgSFnbSTRnKIhMGCBtkScbSoIeOSO0iZWlHRdCFQs
cBfUlX25DJdz6w8iw9V9dxHQFrhLc5UyXM7dtXVMpZfjuyNQWOAuoUteRa9l2GUu1JcFNj0EijW/
S64i8DX6T1POMjSBGvtxc+YidnkHCQ97ILMb1ArG5YzdQlsBb6fIiUDJ2nWxhfgs+hrZwXQyTvmY
c4eU4E2JuCAwsKJlMXkCOXOLk2r7n0b/mhQH+o/Jz4uYhL1yVzG58TfIGdYEvpNV35o4qjPcxbQZ
7LLexPkGqbZvSUmcRz8jBXmDJHI2Myd1DzxCnN08OokDyAnOYvKlYxV9iYB8HX0B+YDyRmvIGAGo
s4AvH/TzbTLulpQjDdLwHxgggLkBaAb6AmO9g2QLOZM9UsLvTdxVzI9IvXGfSQRcB242Rj9vkQs0
xLzZIL+1JpZrSFwTx++Q2LJjrHn+RN6qInFFQEPPsO0kLdIrPCP7Ow3xPOkNqbN0JmAzcdUUzCSZ
HmPiEMc3SH9gD2yI1RgiYGHvTr5cWhiX5I4wlkRWKQEL/eRNci+R6jQjWyavLwlcX0JJFu6Qmm3v
K8xIzd+B9BZJNBDTIFUgRzd/xUzALi4FIFsF45mAC0Cf/Cm5RqpWkzHKCLx8QLJkYeWqseBJBH5M
JOBKYRyR/wG+iIQnEQCpuYqAvY/ZGGnHGD+l/ygiPa0ERiTzAWm6NcSA9vH/gdRJXpP21y+RRCcD
ZlqsrJI6Mg3ySLBEdpsXcewzkmyfkUDuSffNtkYOLJ/0h7gASRJoZNVoAv6kfV+ikSR6BakV3kf/
QNrvbpBnsG2cZ4lY0tnNkK4mI6/Cx8SejbUCkoR9dJrAFgnCDnk8+BPJiS1SuT4BH4E3cayd9wVZ
hB2jw3IToYXlTg9ICXoW/Ub5V4SXRJKGlSXRRebPkefvScC7zxnSNrND1uAKKZlH5LHhC1LFLNKu
9D76XxtXv9tVHjwVgVIL3SM7yavodUPbI+VxB9nzE/K0zJDQb1n1S0K6J7LELlmsnEA5OgIfMr9B
tshHJHZCXgn6kmzqZ+AKvRGBEvZJh12F7D2ubQV0x6j58QQKGHsNXvtKvCRajG2RwP0DstEwADGS
/G0AAAAASUVORK5CYII=
EOL
    base64 -d > "$ICON_DIR/dia.png" < "$ICON_DIR/dia.png"
fi

# Create a convenient command
echo -e "${GREEN}Creating command alias...${NC}"
cat > /usr/local/bin/dia-control << EOL
#!/bin/bash
sudo /opt/dia/scripts/dia-control-center.py
EOL
chmod +x /usr/local/bin/dia-control

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}You can now launch Dia Control Center from your applications menu"
echo -e "or by running 'sudo dia-control' from the terminal${NC}"

exit 0
