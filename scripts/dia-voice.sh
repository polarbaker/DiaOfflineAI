#!/bin/bash
#
# Dia Voice Configuration Tool
# Easily manage and switch between different voice profiles for Dia

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
DIA_PATH="/opt/dia"
CONFIG_PATH="$DIA_PATH/config"
VOICE_PROFILES_PATH="$CONFIG_PATH/voice_profiles"
MAIN_CONFIG="$CONFIG_PATH/dia.yaml"

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

# Ensure voice profiles directory exists
mkdir -p "$VOICE_PROFILES_PATH"

# Show menu
show_menu() {
    clear
    print_header "Dia Voice Configuration Tool"
    echo "What would you like to do?"
    echo ""
    echo "1) List Available Voice Profiles"
    echo "2) Create New Voice Profile"
    echo "3) Edit Existing Voice Profile"
    echo "4) Switch Active Voice Profile"
    echo "5) Test Voice Profile (Say a sample phrase)"
    echo "6) Delete Voice Profile"
    echo "7) Exit"
    echo ""
    read -p "Enter your choice [1-7]: " choice
    
    case $choice in
        1) list_profiles ;;
        2) create_profile ;;
        3) edit_profile ;;
        4) switch_profile ;;
        5) test_voice ;;
        6) delete_profile ;;
        7) exit 0 ;;
        *) print_warning "Invalid choice. Please try again."; show_menu ;;
    esac
}

# List available voice profiles
list_profiles() {
    print_header "Available Voice Profiles"
    
    # Get current profile
    current_profile=$(get_current_profile)
    
    echo -e "${CYAN}ID | Profile Name | Voice Type | Speed | Pitch${NC}"
    echo "----|-------------|------------|-------|------"
    
    count=1
    found_profiles=false
    
    # List all profile files
    for profile in "$VOICE_PROFILES_PATH"/*.yaml; do
        if [ -f "$profile" ]; then
            found_profiles=true
            profile_name=$(basename "$profile" .yaml)
            
            # Extract profile details
            voice_type=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile'))['voice_type'])")
            speed=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile'))['speed'])")
            pitch=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile'))['pitch'])")
            
            # Mark active profile
            if [ "$profile_name" == "$current_profile" ]; then
                echo -e "${GREEN}$count  | $profile_name * | $voice_type | $speed | $pitch${NC}"
            else
                echo "$count  | $profile_name | $voice_type | $speed | $pitch"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ "$found_profiles" = false ]; then
        echo "No voice profiles found. Create one first!"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Create a new voice profile
create_profile() {
    print_header "Create New Voice Profile"
    
    # Get available TTS engines
    tts_types=("espeak" "pyttsx3" "mimic" "coqui")
    
    echo "Available voice types:"
    for ((i=0; i<${#tts_types[@]}; i++)); do
        echo "$((i+1))) ${tts_types[$i]}"
    done
    
    # Get profile name
    read -p "Enter profile name (no spaces, use underscores): " profile_name
    
    if [ -z "$profile_name" ]; then
        print_error "Profile name cannot be empty"
    fi
    
    if [ -f "$VOICE_PROFILES_PATH/$profile_name.yaml" ]; then
        print_error "Profile with that name already exists"
    fi
    
    # Get voice type
    read -p "Select voice type [1-${#tts_types[@]}]: " voice_type_idx
    voice_type="${tts_types[$((voice_type_idx-1))]}"
    
    # Get voice parameters
    read -p "Enter voice ID/name (e.g., 'en-us' for espeak, 'en' for others): " voice_id
    read -p "Enter speed (0.5-2.0, default 1.0): " speed
    read -p "Enter pitch (0.5-2.0, default 1.0): " pitch
    read -p "Enter volume (0.0-1.0, default 1.0): " volume
    
    # Set defaults if empty
    voice_id=${voice_id:-"en-us"}
    speed=${speed:-"1.0"}
    pitch=${pitch:-"1.0"}
    volume=${volume:-"1.0"}
    
    # Create profile file
    cat > "$VOICE_PROFILES_PATH/$profile_name.yaml" << EOF
voice_type: $voice_type
voice_id: $voice_id
speed: $speed
pitch: $pitch
volume: $volume
description: "Custom voice profile - $profile_name"
date_created: "$(date)"
EOF
    
    print_success "Created voice profile: $profile_name"
    read -p "Would you like to set this as the active profile? (y/n): " set_active
    
    if [[ "$set_active" == "y" || "$set_active" == "Y" ]]; then
        set_profile "$profile_name"
        print_success "Switched to new profile: $profile_name"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Edit an existing profile
edit_profile() {
    print_header "Edit Voice Profile"
    
    # List profiles for selection
    profiles=()
    echo "Available profiles:"
    count=1
    
    for profile in "$VOICE_PROFILES_PATH"/*.yaml; do
        if [ -f "$profile" ]; then
            profile_name=$(basename "$profile" .yaml)
            profiles+=("$profile_name")
            echo "$count) $profile_name"
            count=$((count+1))
        fi
    done
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_warning "No profiles found. Create one first!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select profile to edit [1-${#profiles[@]}]: " profile_idx
    
    if ! [[ "$profile_idx" =~ ^[0-9]+$ ]] || [ "$profile_idx" -lt 1 ] || [ "$profile_idx" -gt ${#profiles[@]} ]; then
        print_error "Invalid selection"
    fi
    
    profile_name="${profiles[$((profile_idx-1))]}"
    profile_file="$VOICE_PROFILES_PATH/$profile_name.yaml"
    
    # Load current values
    voice_type=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['voice_type'])")
    voice_id=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['voice_id'])")
    speed=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['speed'])")
    pitch=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['pitch'])")
    volume=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['volume'])")
    
    echo ""
    echo "Current values for $profile_name:"
    echo "Voice type: $voice_type"
    echo "Voice ID: $voice_id"
    echo "Speed: $speed"
    echo "Pitch: $pitch"
    echo "Volume: $volume"
    echo ""
    echo "Enter new values (leave blank to keep current value)"
    
    # Get new values
    read -p "New voice ID/name [$voice_id]: " new_voice_id
    read -p "New speed [$speed]: " new_speed
    read -p "New pitch [$pitch]: " new_pitch
    read -p "New volume [$volume]: " new_volume
    
    # Update with non-empty values
    new_voice_id=${new_voice_id:-"$voice_id"}
    new_speed=${new_speed:-"$speed"}
    new_pitch=${new_pitch:-"$pitch"}
    new_volume=${new_volume:-"$volume"}
    
    # Update profile file
    cat > "$profile_file" << EOF
voice_type: $voice_type
voice_id: $new_voice_id
speed: $new_speed
pitch: $new_pitch
volume: $new_volume
description: "Custom voice profile - $profile_name"
date_modified: "$(date)"
EOF
    
    print_success "Updated profile: $profile_name"
    
    read -p "Would you like to set this as the active profile? (y/n): " set_active
    
    if [[ "$set_active" == "y" || "$set_active" == "Y" ]]; then
        set_profile "$profile_name"
        print_success "Switched to profile: $profile_name"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Switch active profile
switch_profile() {
    print_header "Switch Active Voice Profile"
    
    # List profiles for selection
    profiles=()
    echo "Available profiles:"
    count=1
    
    for profile in "$VOICE_PROFILES_PATH"/*.yaml; do
        if [ -f "$profile" ]; then
            profile_name=$(basename "$profile" .yaml)
            profiles+=("$profile_name")
            echo "$count) $profile_name"
            count=$((count+1))
        fi
    done
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_warning "No profiles found. Create one first!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select profile to activate [1-${#profiles[@]}]: " profile_idx
    
    if ! [[ "$profile_idx" =~ ^[0-9]+$ ]] || [ "$profile_idx" -lt 1 ] || [ "$profile_idx" -gt ${#profiles[@]} ]; then
        print_error "Invalid selection"
    fi
    
    profile_name="${profiles[$((profile_idx-1))]}"
    
    set_profile "$profile_name"
    print_success "Switched to profile: $profile_name"
    
    read -p "Press Enter to continue..."
    show_menu
}

# Delete a profile
delete_profile() {
    print_header "Delete Voice Profile"
    
    # List profiles for selection
    profiles=()
    echo "Available profiles:"
    count=1
    
    for profile in "$VOICE_PROFILES_PATH"/*.yaml; do
        if [ -f "$profile" ]; then
            profile_name=$(basename "$profile" .yaml)
            current=$(get_current_profile)
            
            profiles+=("$profile_name")
            
            if [ "$profile_name" == "$current" ]; then
                echo "$count) $profile_name (active)"
            else
                echo "$count) $profile_name"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_warning "No profiles found. Nothing to delete!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select profile to delete [1-${#profiles[@]}]: " profile_idx
    
    if ! [[ "$profile_idx" =~ ^[0-9]+$ ]] || [ "$profile_idx" -lt 1 ] || [ "$profile_idx" -gt ${#profiles[@]} ]; then
        print_error "Invalid selection"
    fi
    
    profile_name="${profiles[$((profile_idx-1))]}"
    current=$(get_current_profile)
    
    # Confirm deletion
    if [ "$profile_name" == "$current" ]; then
        print_warning "You are about to delete the ACTIVE profile. This is not recommended."
        read -p "Are you REALLY sure? (type 'yes' to confirm): " confirm
        if [ "$confirm" != "yes" ]; then
            print_warning "Deletion cancelled"
            read -p "Press Enter to continue..."
            show_menu
            return
        fi
    else
        read -p "Are you sure you want to delete '$profile_name'? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            print_warning "Deletion cancelled"
            read -p "Press Enter to continue..."
            show_menu
            return
        fi
    fi
    
    # Delete the profile
    rm "$VOICE_PROFILES_PATH/$profile_name.yaml"
    
    print_success "Deleted profile: $profile_name"
    
    # If we deleted the active profile, warn user
    if [ "$profile_name" == "$current" ]; then
        print_warning "You deleted the active profile. Please select a new one."
        
        # If there are other profiles, suggest switching
        if [ ${#profiles[@]} -gt 1 ]; then
            read -p "Would you like to select a new active profile? (y/n): " switch
            if [[ "$switch" == "y" || "$switch" == "Y" ]]; then
                switch_profile
                return
            fi
        fi
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Test a voice with a sample phrase
test_voice() {
    print_header "Test Voice Profile"
    
    # List profiles for selection
    profiles=()
    echo "Available profiles:"
    count=1
    
    for profile in "$VOICE_PROFILES_PATH"/*.yaml; do
        if [ -f "$profile" ]; then
            profile_name=$(basename "$profile" .yaml)
            current=$(get_current_profile)
            
            profiles+=("$profile_name")
            
            if [ "$profile_name" == "$current" ]; then
                echo "$count) $profile_name (active)"
            else
                echo "$count) $profile_name"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_warning "No profiles found. Create one first!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select profile to test [1-${#profiles[@]}]: " profile_idx
    
    if ! [[ "$profile_idx" =~ ^[0-9]+$ ]] || [ "$profile_idx" -lt 1 ] || [ "$profile_idx" -gt ${#profiles[@]} ]; then
        print_error "Invalid selection"
    fi
    
    profile_name="${profiles[$((profile_idx-1))]}"
    profile_file="$VOICE_PROFILES_PATH/$profile_name.yaml"
    
    # Get profile settings
    voice_type=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['voice_type'])")
    voice_id=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['voice_id'])")
    speed=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['speed'])")
    pitch=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['pitch'])")
    volume=$(python3 -c "import yaml; print(yaml.safe_load(open('$profile_file'))['volume'])")
    
    # Get test phrase
    read -p "Enter a phrase to speak (or press Enter for default): " phrase
    phrase=${phrase:-"Hello, I am Dia, your voice assistant. How can I help you today?"}
    
    echo "Testing voice profile: $profile_name"
    echo "Phrase: \"$phrase\""
    
    # Test based on voice type
    case "$voice_type" in
        "espeak")
            espeak -v "$voice_id" -s "$(echo "$speed * 150" | bc)" -p "$(echo "$pitch * 50" | bc)" -a "$(echo "$volume * 100" | bc)" "$phrase"
            ;;
        "pyttsx3")
            python3 -c "
import pyttsx3
engine = pyttsx3.init()
engine.setProperty('voice', '$voice_id')
engine.setProperty('rate', int(engine.getProperty('rate') * $speed))
engine.setProperty('volume', $volume)
engine.say('$phrase')
engine.runAndWait()
"
            ;;
        *)
            print_warning "Direct testing not supported for $voice_type. Using espeak as fallback."
            espeak "$phrase"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Get current profile name
get_current_profile() {
    if [ ! -f "$MAIN_CONFIG" ]; then
        echo "default"
        return
    fi
    
    python3 -c "
import yaml
try:
    config = yaml.safe_load(open('$MAIN_CONFIG'))
    print(config.get('tts', {}).get('voice_profile', 'default'))
except:
    print('default')
"
}

# Set active profile
set_profile() {
    local profile_name=$1
    
    if [ ! -f "$VOICE_PROFILES_PATH/$profile_name.yaml" ]; then
        print_error "Profile not found: $profile_name"
    fi
    
    # Load profile settings
    voice_type=$(python3 -c "import yaml; print(yaml.safe_load(open('$VOICE_PROFILES_PATH/$profile_name.yaml'))['voice_type'])")
    voice_id=$(python3 -c "import yaml; print(yaml.safe_load(open('$VOICE_PROFILES_PATH/$profile_name.yaml'))['voice_id'])")
    speed=$(python3 -c "import yaml; print(yaml.safe_load(open('$VOICE_PROFILES_PATH/$profile_name.yaml'))['speed'])")
    pitch=$(python3 -c "import yaml; print(yaml.safe_load(open('$VOICE_PROFILES_PATH/$profile_name.yaml'))['pitch'])")
    volume=$(python3 -c "import yaml; print(yaml.safe_load(open('$VOICE_PROFILES_PATH/$profile_name.yaml'))['volume'])")
    
    # Update main config
    python3 -c "
import yaml

# Load config
with open('$MAIN_CONFIG', 'r') as f:
    config = yaml.safe_load(f) or {}

# Ensure TTS section exists
if 'tts' not in config:
    config['tts'] = {}

# Update TTS settings
config['tts']['voice_profile'] = '$profile_name'
config['tts']['engine'] = '$voice_type'
config['tts']['voice_id'] = '$voice_id'
config['tts']['speed'] = float('$speed')
config['tts']['pitch'] = float('$pitch')
config['tts']['volume'] = float('$volume')

# Save config
with open('$MAIN_CONFIG', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
    
    # If service is running, restart it to apply changes
    if systemctl is-active --quiet dia.service; then
        read -p "Dia service is running. Restart to apply changes? (y/n): " restart
        if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
            systemctl restart dia.service
            print_success "Restarted Dia service with new voice profile"
        else
            print_warning "Changes will apply next time Dia starts"
        fi
    fi
}

# Create default profiles if none exist
check_default_profiles() {
    if [ ! -d "$VOICE_PROFILES_PATH" ] || [ ! "$(ls -A "$VOICE_PROFILES_PATH")" ]; then
        print_warning "No voice profiles found. Creating defaults..."
        
        # Create default profile directory
        mkdir -p "$VOICE_PROFILES_PATH"
        
        # Default profile (neutral)
        cat > "$VOICE_PROFILES_PATH/default.yaml" << EOF
voice_type: espeak
voice_id: en-us
speed: 1.0
pitch: 1.0
volume: 1.0
description: "Default voice profile"
date_created: "$(date)"
EOF
        
        # British male profile
        cat > "$VOICE_PROFILES_PATH/british_male.yaml" << EOF
voice_type: espeak
voice_id: en-gb
speed: 0.9
pitch: 0.8
volume: 1.0
description: "British male voice profile"
date_created: "$(date)"
EOF
        
        # Female profile
        cat > "$VOICE_PROFILES_PATH/female.yaml" << EOF
voice_type: espeak
voice_id: en+f3
speed: 1.1
pitch: 1.5
volume: 1.0
description: "Female voice profile"
date_created: "$(date)"
EOF
        
        # Slow and clear profile
        cat > "$VOICE_PROFILES_PATH/slow_clear.yaml" << EOF
voice_type: espeak
voice_id: en-us
speed: 0.8
pitch: 1.0
volume: 1.0
description: "Slow and clear voice profile for better comprehension"
date_created: "$(date)"
EOF
        
        print_success "Created default voice profiles"
    fi
}

# Set up command-line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        list|ls)
            check_default_profiles
            list_profiles
            exit 0
            ;;
        set|switch)
            if [ -z "$2" ]; then
                print_error "Profile name required"
            fi
            check_default_profiles
            set_profile "$2"
            print_success "Switched to profile: $2"
            exit 0
            ;;
        test)
            profile_name=${2:-$(get_current_profile)}
            check_default_profiles
            # Test code would go here
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  list, ls             List all voice profiles"
            echo "  set, switch <name>   Switch to specified profile"
            echo "  test [name]          Test a profile (or current if none specified)"
            echo "  (no arguments)       Launch interactive menu"
            exit 0
            ;;
        *)
            print_error "Unknown command: $1"
            ;;
    esac
fi

# Check for default profiles
check_default_profiles

# No arguments, show interactive menu
show_menu
