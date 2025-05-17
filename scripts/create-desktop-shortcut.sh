#!/bin/bash
#
# Create a desktop shortcut for Dia Assistant
# This script creates an easy-to-use desktop icon for Dia

set -e

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Create desktop directory if it doesn't exist
mkdir -p ~/Desktop

# Create desktop shortcut file
cat > ~/Desktop/Dia.desktop << EOF
[Desktop Entry]
Name=Dia Assistant
Comment=Your Offline AI Voice Assistant
Exec=sudo /opt/dia/scripts/dia-easy.sh
Icon=/opt/dia/assets/dia-icon.png
Terminal=true
Type=Application
Categories=Utility;
EOF

# Make it executable
chmod +x ~/Desktop/Dia.desktop

# Create a simple icon if it doesn't exist
if [ ! -f "/opt/dia/assets/dia-icon.png" ]; then
    sudo mkdir -p /opt/dia/assets
    
    # Create a simple colored circle icon with "Dia" text
    # This uses ImageMagick if available, otherwise creates a simple placeholder
    if command -v convert &> /dev/null; then
        convert -size 256x256 xc:none -fill "#E91E63" -draw "circle 128,128 128,10" \
        -pointsize 72 -fill white -gravity center -annotate 0 "Dia" \
        /tmp/dia-icon.png
        sudo mv /tmp/dia-icon.png /opt/dia/assets/dia-icon.png
    else
        # Simple placeholder - a colored square
        sudo bash -c 'cat > /opt/dia/assets/dia-icon.png << EOF
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
AAAASUVORK5CYII=
EOF'
    fi
fi

echo -e "${GREEN}Desktop shortcut for Dia Assistant created!${NC}"
echo "You can now launch Dia by double-clicking the icon on your desktop."
