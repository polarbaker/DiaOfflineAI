#!/bin/bash
#
# Dia Knowledge Pack Manager
# Install and manage specialized knowledge packs for Dia Assistant

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

# Paths
DIA_PATH="/opt/dia"
KNOWLEDGE_PATH="/mnt/nvme/dia/knowledge_packs"
FALLBACK_PATH="$DIA_PATH/models/knowledge_packs"
VENV_PATH="$DIA_PATH/venv"

# Knowledge packs metadata
declare -A PACKS_INFO
PACKS_INFO["medical"]="Medical and health information (10GB) - First aid, common conditions, medications"
PACKS_INFO["science"]="Science and technology concepts (8GB) - Physics, chemistry, biology, astronomy"
PACKS_INFO["cooking"]="Cooking and recipes database (5GB) - Ingredients, techniques, world cuisines"
PACKS_INFO["programming"]="Programming and code references (12GB) - Languages, frameworks, algorithms"
PACKS_INFO["literature"]="Literature and humanities (7GB) - Books, history, philosophy, arts"
PACKS_INFO["diy"]="DIY and home improvement (3GB) - Repairs, crafts, woodworking, gardening"
PACKS_INFO["geography"]="Geography and world knowledge (6GB) - Countries, cities, landmarks, cultures"
PACKS_INFO["math"]="Mathematics and statistics (4GB) - Formulas, concepts, practical applications"

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

# Determine knowledge path
determine_path() {
    if [ -d "/mnt/nvme" ]; then
        mkdir -p "$KNOWLEDGE_PATH"
        return 0
    else
        print_warning "NVMe drive not detected, using internal storage"
        KNOWLEDGE_PATH="$FALLBACK_PATH"
        mkdir -p "$KNOWLEDGE_PATH"
        return 1
    fi
}

# Check available space
check_space() {
    local required_space=$1
    local available_space
    
    if [ -d "/mnt/nvme" ]; then
        available_space=$(df -BG /mnt/nvme | awk 'NR==2 {print $4}' | sed 's/G//')
    else
        available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_warning "Not enough space: $available_space GB available, $required_space GB required"
        return 1
    else
        return 0
    fi
}

# List installed knowledge packs
list_knowledge_packs() {
    print_header "Installed Knowledge Packs"
    
    found=false
    
    for pack in "$KNOWLEDGE_PATH"/*; do
        if [ -d "$pack" ] && [ -f "$pack/metadata.json" ]; then
            found=true
            pack_name=$(basename "$pack")
            
            # Get pack details
            size=$(du -sh "$pack" | awk '{print $1}')
            count=$(find "$pack" -type f -name "*.jsonl" | wc -l)
            date_added=$(stat -c %y "$pack/metadata.json" | cut -d' ' -f1)
            
            echo -e "${BOLD}$pack_name${NOBOLD}"
            echo "  Size: $size"
            echo "  Documents: $count"
            echo "  Added: $date_added"
            
            # Check if enabled
            if [ -L "$DIA_PATH/models/rag/packs/$pack_name" ]; then
                echo -e "  Status: ${GREEN}Enabled${NC}"
            else
                echo -e "  Status: ${YELLOW}Disabled${NC}"
            fi
            
            echo ""
        fi
    done
    
    if [ "$found" = false ]; then
        echo "No knowledge packs installed yet."
        echo "Use the install option to add specialized knowledge packs."
    fi
}

# Show available knowledge packs
show_available_packs() {
    print_header "Available Knowledge Packs"
    
    echo -e "${BOLD}ID        Size   Description${NOBOLD}"
    echo "--------------------------------------------------------"
    
    for pack in "${!PACKS_INFO[@]}"; do
        size=$(echo "${PACKS_INFO[$pack]}" | grep -o '[0-9]\+GB')
        desc=$(echo "${PACKS_INFO[$pack]}" | sed "s/$size//")
        
        # Check if already installed
        if [ -d "$KNOWLEDGE_PATH/$pack" ]; then
            echo -e "${CYAN}$pack${NC}    $size   $desc ${GREEN}[Installed]${NC}"
        else
            echo -e "$pack    $size   $desc"
        fi
    done
}

# Install knowledge pack
install_knowledge_pack() {
    local pack_id=$1
    
    # Check if pack exists in our metadata
    if [ -z "${PACKS_INFO[$pack_id]}" ]; then
        print_error "Unknown knowledge pack: $pack_id"
    fi
    
    # Check if already installed
    if [ -d "$KNOWLEDGE_PATH/$pack_id" ]; then
        print_warning "Knowledge pack '$pack_id' is already installed"
        read -p "Do you want to reinstall it? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            return
        fi
        
        # Remove existing pack
        rm -rf "$KNOWLEDGE_PATH/$pack_id"
    fi
    
    # Extract size and create folder
    size=$(echo "${PACKS_INFO[$pack_id]}" | grep -o '[0-9]\+' | head -1)
    
    # Check available space
    if ! check_space "$size"; then
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
            return
        fi
    fi
    
    print_header "Installing $pack_id Knowledge Pack"
    
    # Create directory
    mkdir -p "$KNOWLEDGE_PATH/$pack_id"
    
    # Create metadata file
    cat > "$KNOWLEDGE_PATH/$pack_id/metadata.json" << EOF
{
    "id": "$pack_id",
    "name": "$pack_id",
    "description": "${PACKS_INFO[$pack_id]}",
    "version": "1.0",
    "date_installed": "$(date -Iseconds)",
    "size": "${size}GB",
    "source": "dia-knowledge-pack"
}
EOF
    
    # Download pack (simulated)
    echo "Downloading $pack_id knowledge pack..."
    echo "This would normally download from our servers, but"
    echo "for this demonstration, we'll create sample content."
    
    # Activate Python environment
    source "$VENV_PATH/bin/activate"
    
    # Generate sample content
    python3 -c "
import os
import json
import time
from pathlib import Path
from tqdm import tqdm

# Create sample documents based on pack type
pack_id = '$pack_id'
pack_path = Path('$KNOWLEDGE_PATH') / pack_id

# Define document counts based on pack type
doc_counts = {
    'medical': 1000,
    'science': 800,
    'cooking': 500,
    'programming': 1200,
    'literature': 700,
    'diy': 300,
    'geography': 600,
    'math': 400
}

doc_count = doc_counts.get(pack_id, 500)
chunk_size = 50  # Documents per file

# Create directory structure
os.makedirs(pack_path / 'chunks', exist_ok=True)

print(f'Generating {doc_count} sample documents for {pack_id}...')

# Generate sample content files
for i in tqdm(range(0, doc_count, chunk_size)):
    file_path = pack_path / 'chunks' / f'{i:05d}.jsonl'
    
    with open(file_path, 'w') as f:
        # Generate chunk_size documents or remaining ones
        for j in range(i, min(i + chunk_size, doc_count)):
            doc = {
                'id': f'{pack_id}_{j:05d}',
                'title': f'Sample {pack_id.title()} Document {j}',
                'content': f'This is sample content for {pack_id} document {j}. In a real implementation, this would contain valuable information about {pack_id}.',
                'metadata': {
                    'source': f'{pack_id}_knowledge_base',
                    'date': '2025-01-01',
                    'keywords': [f'{pack_id}', 'sample', 'knowledge']
                }
            }
            f.write(json.dumps(doc) + '\\n')
    
    # Simulate download time
    time.sleep(0.1)

# Create embeddings file (placeholder)
with open(pack_path / 'embeddings.bin', 'wb') as f:
    f.write(b'PLACEHOLDER FOR VECTOR EMBEDDINGS')

print(f'Generated {doc_count} sample documents in {(doc_count + chunk_size - 1) // chunk_size} files')
"
    
    print_success "Knowledge pack '$pack_id' installed successfully"
    
    # Enable the pack
    enable_knowledge_pack "$pack_id"
}

# Enable knowledge pack
enable_knowledge_pack() {
    local pack_id=$1
    
    # Check if pack is installed
    if [ ! -d "$KNOWLEDGE_PATH/$pack_id" ]; then
        print_error "Knowledge pack '$pack_id' is not installed"
    fi
    
    print_header "Enabling $pack_id Knowledge Pack"
    
    # Create symlink directory if it doesn't exist
    mkdir -p "$DIA_PATH/models/rag/packs"
    
    # Create symlink
    if [ -L "$DIA_PATH/models/rag/packs/$pack_id" ]; then
        rm "$DIA_PATH/models/rag/packs/$pack_id"
    fi
    
    ln -sf "$KNOWLEDGE_PATH/$pack_id" "$DIA_PATH/models/rag/packs/$pack_id"
    
    # Update configuration
    source "$VENV_PATH/bin/activate"
    
    python3 -c "
import yaml
import os

# Load configuration
config_path = os.path.join('$DIA_PATH', 'config', 'dia.yaml')

try:
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f) or {}
except FileNotFoundError:
    config = {}

# Ensure RAG section exists
if 'rag' not in config:
    config['rag'] = {}

# Ensure knowledge_packs section exists
if 'knowledge_packs' not in config['rag']:
    config['rag']['knowledge_packs'] = []

# Add pack if not already in list
pack_id = '$pack_id'
if pack_id not in config['rag']['knowledge_packs']:
    config['rag']['knowledge_packs'].append(pack_id)

# Enable RAG
config['rag']['enabled'] = True

# Save configuration
with open(config_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print(f'Knowledge pack {pack_id} enabled in configuration')
"
    
    print_success "Knowledge pack '$pack_id' enabled"
    
    # Note about restarting Dia
    if systemctl is-active --quiet dia.service; then
        echo ""
        echo "Dia Assistant is currently running."
        read -p "Would you like to restart it to apply changes? (y/n): " restart
        
        if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
            systemctl restart dia.service
            print_success "Dia Assistant restarted with new knowledge pack"
        else
            print_warning "You'll need to restart Dia Assistant for changes to take effect"
        fi
    fi
}

# Disable knowledge pack
disable_knowledge_pack() {
    local pack_id=$1
    
    # Check if pack is installed
    if [ ! -d "$KNOWLEDGE_PATH/$pack_id" ]; then
        print_error "Knowledge pack '$pack_id' is not installed"
    fi
    
    print_header "Disabling $pack_id Knowledge Pack"
    
    # Remove symlink if it exists
    if [ -L "$DIA_PATH/models/rag/packs/$pack_id" ]; then
        rm "$DIA_PATH/models/rag/packs/$pack_id"
    fi
    
    # Update configuration
    source "$VENV_PATH/bin/activate"
    
    python3 -c "
import yaml
import os

# Load configuration
config_path = os.path.join('$DIA_PATH', 'config', 'dia.yaml')

try:
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f) or {}
except FileNotFoundError:
    config = {}

# Ensure RAG section exists
if 'rag' not in config:
    config['rag'] = {}

# Ensure knowledge_packs section exists
if 'knowledge_packs' not in config['rag']:
    config['rag']['knowledge_packs'] = []

# Remove pack if in list
pack_id = '$pack_id'
if pack_id in config['rag']['knowledge_packs']:
    config['rag']['knowledge_packs'].remove(pack_id)

# Save configuration
with open(config_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print(f'Knowledge pack {pack_id} disabled in configuration')
"
    
    print_success "Knowledge pack '$pack_id' disabled"
    
    # Note about restarting Dia
    if systemctl is-active --quiet dia.service; then
        echo ""
        echo "Dia Assistant is currently running."
        read -p "Would you like to restart it to apply changes? (y/n): " restart
        
        if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
            systemctl restart dia.service
            print_success "Dia Assistant restarted without knowledge pack"
        else
            print_warning "You'll need to restart Dia Assistant for changes to take effect"
        fi
    fi
}

# Remove knowledge pack
remove_knowledge_pack() {
    local pack_id=$1
    
    # Check if pack is installed
    if [ ! -d "$KNOWLEDGE_PATH/$pack_id" ]; then
        print_error "Knowledge pack '$pack_id' is not installed"
    fi
    
    print_header "Removing $pack_id Knowledge Pack"
    
    # Confirm removal
    read -p "Are you sure you want to remove the '$pack_id' knowledge pack? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_warning "Removal cancelled"
        return
    fi
    
    # Disable pack first
    if [ -L "$DIA_PATH/models/rag/packs/$pack_id" ]; then
        disable_knowledge_pack "$pack_id"
    fi
    
    # Remove pack directory
    rm -rf "$KNOWLEDGE_PATH/$pack_id"
    
    print_success "Knowledge pack '$pack_id' removed"
}

# Show menu for managing knowledge packs
show_menu() {
    while true; do
        clear
        print_header "Dia Knowledge Pack Manager"
        echo -e "${BOLD}What would you like to do?${NOBOLD}"
        echo ""
        echo "1) View Installed Knowledge Packs"
        echo "2) Browse Available Knowledge Packs"
        echo "3) Install Knowledge Pack"
        echo "4) Enable Knowledge Pack"
        echo "5) Disable Knowledge Pack"
        echo "6) Remove Knowledge Pack"
        echo "7) Exit"
        echo ""
        read -p "Enter your choice [1-7]: " choice
        
        case $choice in
            1)
                list_knowledge_packs
                read -p "Press Enter to continue..."
                ;;
            2)
                show_available_packs
                read -p "Press Enter to continue..."
                ;;
            3)
                show_available_packs
                echo ""
                read -p "Enter the ID of the knowledge pack to install: " pack_id
                if [ -n "$pack_id" ]; then
                    install_knowledge_pack "$pack_id"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                list_knowledge_packs
                echo ""
                read -p "Enter the ID of the knowledge pack to enable: " pack_id
                if [ -n "$pack_id" ]; then
                    enable_knowledge_pack "$pack_id"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                list_knowledge_packs
                echo ""
                read -p "Enter the ID of the knowledge pack to disable: " pack_id
                if [ -n "$pack_id" ]; then
                    disable_knowledge_pack "$pack_id"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                list_knowledge_packs
                echo ""
                read -p "Enter the ID of the knowledge pack to remove: " pack_id
                if [ -n "$pack_id" ]; then
                    remove_knowledge_pack "$pack_id"
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                exit 0
                ;;
            *)
                print_warning "Invalid choice. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Process command line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        list)
            check_root
            determine_path
            list_knowledge_packs
            ;;
        available)
            show_available_packs
            ;;
        install)
            check_root
            determine_path
            if [ -z "$2" ]; then
                print_error "Please specify a knowledge pack to install"
            fi
            install_knowledge_pack "$2"
            ;;
        enable)
            check_root
            determine_path
            if [ -z "$2" ]; then
                print_error "Please specify a knowledge pack to enable"
            fi
            enable_knowledge_pack "$2"
            ;;
        disable)
            check_root
            determine_path
            if [ -z "$2" ]; then
                print_error "Please specify a knowledge pack to disable"
            fi
            disable_knowledge_pack "$2"
            ;;
        remove)
            check_root
            determine_path
            if [ -z "$2" ]; then
                print_error "Please specify a knowledge pack to remove"
            fi
            remove_knowledge_pack "$2"
            ;;
        help)
            echo "Usage: $0 [command] [pack_id]"
            echo ""
            echo "Commands:"
            echo "  list                  List installed knowledge packs"
            echo "  available             Show available knowledge packs"
            echo "  install <pack_id>     Install a knowledge pack"
            echo "  enable <pack_id>      Enable a knowledge pack"
            echo "  disable <pack_id>     Disable a knowledge pack"
            echo "  remove <pack_id>      Remove a knowledge pack"
            echo "  help                  Show this help message"
            echo "  (no command)          Show interactive menu"
            echo ""
            echo "Available knowledge pack IDs:"
            for pack in "${!PACKS_INFO[@]}"; do
                echo "  $pack"
            done
            ;;
        *)
            print_error "Unknown command: $1. Use 'help' for usage information."
            ;;
    esac
else
    # No command line args, show interactive menu
    check_root
    determine_path
    show_menu
fi
