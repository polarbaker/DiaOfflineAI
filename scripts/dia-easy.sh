#!/bin/bash
#
# Dia Assistant Easy Launcher
# A simple, user-friendly interface for managing your Dia Assistant

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
SCRIPTS_PATH="$DIA_PATH/scripts"

# Function to check if we're running as root
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

# Function to display main menu
show_main_menu() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "  ____  _         _         _     _              _    "
    echo " |  _ \\(_) __ _  | |   __ _| |__ | |__   ___ ___| |_  "
    echo " | | | | |/ _\` | | |  / _\` | '_ \\| '_ \\ / __/ _ \\ __| "
    echo " | |_| | | (_| | | | | (_| | |_) | |_) | (_|  __/ |_  "
    echo " |____/|_|\\__,_| |_|  \\__,_|_.__/|_.__/ \\___\\___|\\__| "
    echo -e "${NOBOLD}${NC}"
    echo -e "${CYAN}${BOLD}Your Offline AI Voice Assistant${NOBOLD}${NC}"
    echo ""
    
    # Check service status
    if systemctl is-active --quiet dia.service; then
        echo -e "${GREEN}● Dia Assistant is currently RUNNING${NC}"
    else
        echo -e "${RED}● Dia Assistant is currently STOPPED${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}What would you like to do?${NOBOLD}"
    echo ""
    echo -e "  ${CYAN}${BOLD}BASIC CONTROLS${NOBOLD}${NC}"
    echo "  1) Start Dia Assistant"
    echo "  2) Stop Dia Assistant"
    echo "  3) Restart Dia Assistant"
    echo "  4) Check Dia Status"
    echo ""
    echo -e "  ${CYAN}${BOLD}VOICE SETTINGS${NOBOLD}${NC}"
    echo "  5) Change Voice Settings"
    echo "  6) Create Custom Voice"
    echo ""
    echo -e "  ${CYAN}${BOLD}KNOWLEDGE & INTELLIGENCE${NOBOLD}${NC}"
    echo "  7) Setup Wikipedia Knowledge Base"
    echo "  8) Update AI Language Model"
    echo "  9) Add Documents to Knowledge Base"
    echo ""
    echo -e "  ${CYAN}${BOLD}SYSTEM${NOBOLD}${NC}"
    echo "  10) View Dashboard in Browser"
    echo "  11) System Management"
    echo "  12) Exit"
    echo ""
    read -p "Enter your choice [1-12]: " choice
    
    case $choice in
        1) start_dia ;;
        2) stop_dia ;;
        3) restart_dia ;;
        4) show_status ;;
        5) change_voice ;;
        6) create_voice ;;
        7) setup_wikipedia ;;
        8) update_llm ;;
        9) update_knowledge ;;
        10) open_dashboard ;;
        11) system_management ;;
        12) exit 0 ;;
        *) print_warning "Invalid choice. Please try again."; sleep 2; show_main_menu ;;
    esac
}

# Function to start Dia Assistant
start_dia() {
    print_header "Starting Dia Assistant"
    
    echo "Starting the Dia Assistant service..."
    systemctl start dia.service
    
    if systemctl is-active --quiet dia.service; then
        print_success "Dia Assistant started successfully"
    else
        print_warning "Failed to start Dia Assistant"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

# Function to stop Dia Assistant
stop_dia() {
    print_header "Stopping Dia Assistant"
    
    echo "Stopping the Dia Assistant service..."
    systemctl stop dia.service
    
    if ! systemctl is-active --quiet dia.service; then
        print_success "Dia Assistant stopped successfully"
    else
        print_warning "Failed to stop Dia Assistant"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

# Function to restart Dia Assistant
restart_dia() {
    print_header "Restarting Dia Assistant"
    
    echo "Restarting the Dia Assistant service..."
    systemctl restart dia.service
    
    if systemctl is-active --quiet dia.service; then
        print_success "Dia Assistant restarted successfully"
    else
        print_warning "Failed to restart Dia Assistant"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

# Function to show Dia status
show_status() {
    print_header "Dia Assistant Status"
    
    # Run the status script if it exists
    if [ -f "$SCRIPTS_PATH/dia-status.sh" ]; then
        $SCRIPTS_PATH/dia-status.sh
    else
        # Fallback status check
        echo -e "${BOLD}Service Status:${NOBOLD}"
        if systemctl is-active --quiet dia.service; then
            echo -e "${GREEN}● Dia Assistant is RUNNING${NC}"
        else
            echo -e "${RED}● Dia Assistant is STOPPED${NC}"
        fi
        
        echo ""
        echo -e "${BOLD}Recent Logs:${NOBOLD}"
        journalctl -u dia.service -n 10 --no-pager
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

# Function to launch voice settings
change_voice() {
    print_header "Change Voice Settings"
    
    if [ -f "$SCRIPTS_PATH/dia-voice.sh" ]; then
        $SCRIPTS_PATH/dia-voice.sh
    else
        print_warning "Voice settings tool not found"
    fi
    
    show_main_menu
}

# Function to create custom voice
create_voice() {
    print_header "Create Custom Voice"
    
    if [ -f "$SCRIPTS_PATH/dia-custom-voice.sh" ]; then
        $SCRIPTS_PATH/dia-custom-voice.sh
    else
        print_warning "Custom voice tool not found"
    fi
    
    show_main_menu
}

# Function to set up Wikipedia
setup_wikipedia() {
    print_header "Setup Wikipedia Knowledge Base"
    
    # Check for required space
    available_space=$(df -h /mnt/nvme | awk 'NR==2 {print $4}')
    
    echo -e "${BOLD}This will download and process Wikipedia data for offline use.${NOBOLD}"
    echo ""
    echo -e "Available space: ${CYAN}$available_space${NC}"
    echo -e "Minimum required: ${YELLOW}10GB${NC} (small subset), ${YELLOW}80GB${NC} (full Wikipedia)"
    echo ""
    echo "Processing may take several hours depending on the size you choose."
    echo ""
    
    read -p "Do you want to continue? (y/n): " continue_setup
    
    if [[ "$continue_setup" == "y" || "$continue_setup" == "Y" ]]; then
        if [ -f "$SCRIPTS_PATH/setup-wikipedia.sh" ]; then
            $SCRIPTS_PATH/setup-wikipedia.sh
        else
            print_warning "Wikipedia setup tool not found"
        fi
    fi
    
    show_main_menu
}

# Function to update LLM
update_llm() {
    print_header "Update AI Language Model"
    
    echo -e "${BOLD}This will download a new AI language model for Dia.${NOBOLD}"
    echo ""
    echo "A larger model will provide better responses but may run slower."
    echo "Downloading a model requires a good internet connection and may take some time."
    echo ""
    
    read -p "Do you want to continue? (y/n): " continue_setup
    
    if [[ "$continue_setup" == "y" || "$continue_setup" == "Y" ]]; then
        if [ -f "$SCRIPTS_PATH/setup-llm.sh" ]; then
            $SCRIPTS_PATH/setup-llm.sh
        else
            print_warning "LLM setup tool not found"
        fi
    fi
    
    show_main_menu
}

# Function to update knowledge base
update_knowledge() {
    print_header "Add Documents to Knowledge Base"
    
    echo -e "${BOLD}This will add documents to Dia's knowledge base.${NOBOLD}"
    echo ""
    echo "You can add documents from a USB drive or local folder."
    echo "Supported formats: PDF, TXT, Markdown, etc."
    echo ""
    
    read -p "Do you want to continue? (y/n): " continue_update
    
    if [[ "$continue_update" == "y" || "$continue_update" == "Y" ]]; then
        if [ -f "$SCRIPTS_PATH/update_rag.sh" ]; then
            # Ask for source path
            read -p "Enter path to document folder: " doc_path
            
            if [ -z "$doc_path" ]; then
                print_warning "No path specified"
            elif [ ! -d "$doc_path" ]; then
                print_warning "Directory not found: $doc_path"
            else
                $SCRIPTS_PATH/update_rag.sh --source "$doc_path" --format all --recursive
            fi
        else
            print_warning "Knowledge base update tool not found"
        fi
    fi
    
    show_main_menu
}

# Function to open dashboard
open_dashboard() {
    print_header "Open Dashboard"
    
    echo "Opening Dia Assistant dashboard in browser..."
    
    # Try to use xdg-open if available
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost" &
    # Try to use lynx if available
    elif command -v lynx &> /dev/null; then
        lynx "http://localhost"
    else
        echo ""
        echo -e "${BOLD}To view the dashboard, open this address in a browser:${NOBOLD}"
        echo -e "${CYAN}http://localhost${NC}" 
        echo ""
        echo "Or access from another computer using:"
        hostname=$(hostname)
        echo -e "${CYAN}http://$hostname.local${NC}"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

# Function for system management
system_management() {
    print_header "System Management"
    
    echo -e "${BOLD}Choose a system management option:${NOBOLD}"
    echo ""
    echo "1) Check Disk Usage"
    echo "2) Check Memory Usage"
    echo "3) View System Temperature"
    echo "4) View System Logs"
    echo "5) Open Web Management Console"
    echo "6) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-6]: " sys_choice
    
    case $sys_choice in
        1) 
            echo ""
            df -h
            ;;
        2)
            echo ""
            free -h
            ;;
        3)
            echo ""
            vcgencmd measure_temp
            ;;
        4)
            echo ""
            journalctl -u dia.service -n 50 --no-pager
            ;;
        5)
            echo "Opening web management console in browser..."
            # Try to use xdg-open if available
            if command -v xdg-open &> /dev/null; then
                xdg-open "https://localhost:9090" &
            else
                echo ""
                echo -e "${BOLD}To access the web management console, open this address in a browser:${NOBOLD}"
                echo -e "${CYAN}https://localhost:9090${NC}"
                echo ""
                hostname=$(hostname)
                echo "Or access from another computer using:"
                echo -e "${CYAN}https://$hostname.local:9090${NC}"
            fi
            ;;
        6)
            show_main_menu
            return
            ;;
        *)
            print_warning "Invalid choice"
            ;;
    esac
    
    read -p "Press Enter to continue..."
    system_management
}

# Check if running as root
check_root

# Show the main menu
show_main_menu
