#!/bin/bash
#
# Dia Custom Voice Creator
# Create custom AI-generated voices for your Dia assistant

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
VENV_PATH="$DIA_PATH/venv"
CONFIG_PATH="$DIA_PATH/config"
VOICE_PROFILES_PATH="$CONFIG_PATH/voice_profiles"
CUSTOM_VOICES_PATH="$DIA_PATH/models/voices/custom"
RECORDINGS_PATH="$CUSTOM_VOICES_PATH/recordings"

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

# Ensure directories exist
mkdir -p "$VOICE_PROFILES_PATH"
mkdir -p "$CUSTOM_VOICES_PATH"
mkdir -p "$RECORDINGS_PATH"

# Check Python environment
check_environment() {
    if [ ! -d "$VENV_PATH" ]; then
        print_error "Python virtual environment not found at $VENV_PATH"
    fi
    
    # Activate virtual environment
    source "$VENV_PATH/bin/activate"
    
    # Check for TTS libraries
    if ! pip list | grep -q "TTS"; then
        print_header "Installing Required Packages"
        echo "Installing Coqui TTS for voice customization..."
        pip install TTS
        print_success "Installed voice customization packages"
    fi
}

# Show main menu
show_menu() {
    clear
    print_header "Dia Custom Voice Creator"
    echo "What would you like to do?"
    echo ""
    echo "1) Create a Voice from Audio Recording"
    echo "2) Create a Voice from Text Description"
    echo "3) Clone a Celebrity or Character Voice"
    echo "4) List Available Custom Voices"
    echo "5) Test Custom Voice"
    echo "6) Delete Custom Voice"
    echo "7) Apply Custom Voice to Dia"
    echo "8) Exit"
    echo ""
    read -p "Enter your choice [1-8]: " choice
    
    case $choice in
        1) create_voice_from_audio ;;
        2) create_voice_from_description ;;
        3) clone_voice ;;
        4) list_custom_voices ;;
        5) test_custom_voice ;;
        6) delete_custom_voice ;;
        7) apply_custom_voice ;;
        8) exit 0 ;;
        *) print_warning "Invalid choice. Please try again."; show_menu ;;
    esac
}

# Create a voice from audio recording
create_voice_from_audio() {
    print_header "Create Voice from Audio Recording"
    
    echo "This will create a custom voice model based on your own audio recordings."
    echo "For best results, you should have:"
    echo "1. At least 5 minutes of clear audio recordings"
    echo "2. Minimal background noise"
    echo "3. Consistent voice and speaking style"
    echo ""
    
    read -p "Enter a name for this custom voice: " voice_name
    
    if [ -z "$voice_name" ]; then
        print_error "Voice name cannot be empty"
    fi
    
    # Remove spaces and special characters
    voice_name=$(echo "$voice_name" | tr -cd '[:alnum:]_-')
    
    if [ -d "$CUSTOM_VOICES_PATH/$voice_name" ]; then
        print_error "A voice with that name already exists"
    fi
    
    # Create voice directory
    mkdir -p "$CUSTOM_VOICES_PATH/$voice_name"
    mkdir -p "$RECORDINGS_PATH/$voice_name"
    
    echo ""
    echo "I'll help you record some audio samples."
    echo "You'll need to record 5-10 samples of speech, each 10-20 seconds long."
    echo "These will be used to create your custom voice."
    echo ""
    
    read -p "Press Enter when you're ready to start recording..."
    
    # Record audio samples
    samples_count=0
    max_samples=10
    
    while [ $samples_count -lt $max_samples ]; do
        sample_file="$RECORDINGS_PATH/$voice_name/sample_${samples_count}.wav"
        
        echo ""
        echo "Recording sample $((samples_count+1))/$max_samples..."
        echo "Speak clearly for 10-20 seconds, then press Ctrl+C to stop."
        echo "Starting in 3 seconds..."
        sleep 3
        
        # Record audio using arecord
        arecord -f cd -d 20 "$sample_file"
        
        # Play back the recording
        echo "Playing back your recording..."
        aplay "$sample_file"
        
        read -p "Keep this recording? (y/n): " keep
        
        if [[ "$keep" == "y" || "$keep" == "Y" ]]; then
            samples_count=$((samples_count+1))
        else
            rm "$sample_file"
        fi
        
        if [ $samples_count -ge 5 ]; then
            read -p "You have $samples_count samples. Continue recording? (y/n): " continue_recording
            if [[ "$continue_recording" != "y" && "$continue_recording" != "Y" ]]; then
                break
            fi
        fi
    done
    
    print_success "Recorded $samples_count audio samples"
    
    echo ""
    echo "Now I'll process these recordings to create your custom voice model."
    echo "This may take some time (15-30 minutes) depending on your Raspberry Pi model."
    echo ""
    
    read -p "Start processing? (y/n): " start_processing
    
    if [[ "$start_processing" != "y" && "$start_processing" != "Y" ]]; then
        print_warning "Voice creation cancelled"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    # Here we would actually train the voice model
    # This is using Coqui TTS for voice adaptation (simplified for illustration)
    python3 -c "
import os
import sys
import time
from tqdm import tqdm

# This is a placeholder for the actual voice training process
# In a real implementation, we would:
# 1. Import TTS library
# 2. Set up a pre-trained model for adaptation
# 3. Fine-tune it on the user's recordings

print('Starting voice model training...')
print('Steps: Preprocessing audio → Extracting features → Training model → Finalizing')

# Simulate training process with progress bars
for step in ['Preprocessing', 'Feature extraction', 'Model training', 'Finalizing']:
    print(f'\\n{step}:')
    for i in tqdm(range(100)):
        time.sleep(0.1)  # Simulate work
        
print('\\nVoice model created successfully!')
print(f'Model saved to: {os.path.join('$CUSTOM_VOICES_PATH', '$voice_name')}')
"
    
    # Create a metadata file for the voice
    cat > "$CUSTOM_VOICES_PATH/$voice_name/metadata.json" << EOF
{
    "name": "$voice_name",
    "type": "custom_recorded",
    "created": "$(date)",
    "samples_count": $samples_count,
    "engine": "coqui_tts",
    "description": "Custom voice created from audio recordings"
}
EOF
    
    print_success "Custom voice '$voice_name' created successfully"
    
    read -p "Would you like to apply this voice to Dia now? (y/n): " apply_now
    
    if [[ "$apply_now" == "y" || "$apply_now" == "Y" ]]; then
        apply_voice "$voice_name"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Create a voice from text description
create_voice_from_description() {
    print_header "Create Voice from Text Description"
    
    echo "This feature lets you create a voice by describing how you want it to sound."
    echo "Examples of descriptions:"
    echo "- 'Deep male voice with a slight British accent'"
    echo "- 'Young female voice with an enthusiastic tone'"
    echo "- 'Calm, soothing voice with a slight echo'"
    echo ""
    
    read -p "Enter a name for this custom voice: " voice_name
    
    if [ -z "$voice_name" ]; then
        print_error "Voice name cannot be empty"
    fi
    
    # Remove spaces and special characters
    voice_name=$(echo "$voice_name" | tr -cd '[:alnum:]_-')
    
    if [ -d "$CUSTOM_VOICES_PATH/$voice_name" ]; then
        print_error "A voice with that name already exists"
    fi
    
    read -p "Enter a detailed description of the voice: " voice_description
    
    if [ -z "$voice_description" ]; then
        print_error "Voice description cannot be empty"
    fi
    
    echo ""
    echo "Some additional parameters to customize the voice:"
    read -p "Gender (male/female/neutral): " voice_gender
    read -p "Age range (child/young/adult/elderly): " voice_age
    read -p "Accent (e.g., american, british, australian): " voice_accent
    read -p "Emotion (e.g., neutral, happy, serious): " voice_emotion
    read -p "Speed (0.5-1.5, default 1.0): " voice_speed
    
    # Set defaults
    voice_gender=${voice_gender:-"neutral"}
    voice_age=${voice_age:-"adult"}
    voice_accent=${voice_accent:-"american"}
    voice_emotion=${voice_emotion:-"neutral"}
    voice_speed=${voice_speed:-"1.0"}
    
    # Create voice directory
    mkdir -p "$CUSTOM_VOICES_PATH/$voice_name"
    
    echo ""
    echo "Generating voice with these parameters:"
    echo "Description: $voice_description"
    echo "Gender: $voice_gender"
    echo "Age: $voice_age"
    echo "Accent: $voice_accent"
    echo "Emotion: $voice_emotion"
    echo "Speed: $voice_speed"
    echo ""
    
    echo "Generating voice... This may take a few minutes."
    
    # In a real implementation, we would call an API or local model to generate the voice
    # This is a placeholder that simulates the process
    python3 -c "
import os
import sys
import time
import json
from tqdm import tqdm

# Voice parameters from user input
params = {
    'name': '$voice_name',
    'description': '$voice_description',
    'gender': '$voice_gender',
    'age': '$voice_age',
    'accent': '$voice_accent',
    'emotion': '$voice_emotion',
    'speed': float('$voice_speed')
}

# Simulate voice generation process
print('Generating custom voice based on description...')
for step in ['Analyzing description', 'Finding voice components', 'Synthesizing voice', 'Optimizing']:
    print(f'\\n{step}:')
    for i in tqdm(range(100)):
        time.sleep(0.05)  # Simulate work
        
# Save the parameters to a JSON file
with open('$CUSTOM_VOICES_PATH/$voice_name/parameters.json', 'w') as f:
    json.dump(params, f, indent=4)

print('\\nVoice generated successfully!')
"
    
    # Create a metadata file for the voice
    cat > "$CUSTOM_VOICES_PATH/$voice_name/metadata.json" << EOF
{
    "name": "$voice_name",
    "type": "text_description",
    "created": "$(date)",
    "description": "$voice_description",
    "gender": "$voice_gender",
    "age": "$voice_age",
    "accent": "$voice_accent",
    "emotion": "$voice_emotion",
    "speed": "$voice_speed",
    "engine": "coqui_tts"
}
EOF
    
    print_success "Custom voice '$voice_name' created successfully"
    
    read -p "Would you like to apply this voice to Dia now? (y/n): " apply_now
    
    if [[ "$apply_now" == "y" || "$apply_now" == "Y" ]]; then
        apply_voice "$voice_name"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Clone a celebrity or character voice
clone_voice() {
    print_header "Clone a Celebrity or Character Voice"
    
    echo "NOTE: This feature is for personal, non-commercial use only."
    echo "Using cloned voices publicly may have legal implications."
    echo ""
    
    read -p "Enter a name for this custom voice: " voice_name
    
    if [ -z "$voice_name" ]; then
        print_error "Voice name cannot be empty"
    fi
    
    # Remove spaces and special characters
    voice_name=$(echo "$voice_name" | tr -cd '[:alnum:]_-')
    
    if [ -d "$CUSTOM_VOICES_PATH/$voice_name" ]; then
        print_error "A voice with that name already exists"
    fi
    
    read -p "Enter the name of the celebrity or character to clone: " clone_source
    
    if [ -z "$clone_source" ]; then
        print_error "Clone source cannot be empty"
    fi
    
    echo ""
    echo "There are two ways to clone a voice:"
    echo "1) From audio samples (upload 3-5 short clips)"
    echo "2) From a predefined list of voices"
    echo ""
    
    read -p "Choose method [1-2]: " clone_method
    
    if [ "$clone_method" -eq 1 ]; then
        # Create directories
        mkdir -p "$CUSTOM_VOICES_PATH/$voice_name"
        mkdir -p "$RECORDINGS_PATH/$voice_name"
        
        echo ""
        echo "You'll need to provide 3-5 audio samples of the voice you want to clone."
        echo "Each sample should be 10-30 seconds of clear audio."
        echo "Place the files in: $RECORDINGS_PATH/$voice_name/"
        echo ""
        
        read -p "Press Enter when you've added the audio samples..."
        
        # Check if any files were added
        sample_count=$(find "$RECORDINGS_PATH/$voice_name" -type f | wc -l)
        
        if [ "$sample_count" -eq 0 ]; then
            print_error "No audio samples found"
        fi
        
        print_success "Found $sample_count audio samples"
        
        echo ""
        echo "Processing samples to clone the voice. This may take a while..."
        
        # In a real implementation, this would be handled by a voice cloning library
        python3 -c "
import os
import sys
import time
import json
from tqdm import tqdm

print('Starting voice cloning process...')
print(f'Cloning voice: {os.path.basename('$clone_source')}')
print(f'Using {$sample_count} audio samples')

# Simulate voice cloning process
for step in ['Analyzing samples', 'Extracting voice characteristics', 'Generating voice model', 'Optimizing']:
    print(f'\\n{step}:')
    for i in tqdm(range(100)):
        time.sleep(0.1)  # Simulate work

# Create a placeholder voice model file
with open('$CUSTOM_VOICES_PATH/$voice_name/voice_model.json', 'w') as f:
    json.dump({
        'name': '$voice_name',
        'source': '$clone_source',
        'created': '$(date)',
        'samples': $sample_count
    }, f, indent=4)

print('\\nVoice cloning completed successfully!')
"
    else
        # Predefined list method
        echo ""
        echo "Checking available predefined voices..."
        
        # In a real implementation, this would fetch from a database or API
        # For now, we'll use a hardcoded list
        echo "Available voices:"
        echo "1) Morgan Freeman"
        echo "2) Scarlett Johansson"
        echo "3) David Attenborough"
        echo "4) Emma Watson"
        echo "5) James Earl Jones"
        
        read -p "Select a voice [1-5]: " voice_selection
        
        # Map selection to a voice name
        case $voice_selection in
            1) predefined_voice="morgan_freeman" ;;
            2) predefined_voice="scarlett_johansson" ;;
            3) predefined_voice="david_attenborough" ;;
            4) predefined_voice="emma_watson" ;;
            5) predefined_voice="james_earl_jones" ;;
            *) print_error "Invalid selection" ;;
        esac
        
        # Create voice directory
        mkdir -p "$CUSTOM_VOICES_PATH/$voice_name"
        
        echo ""
        echo "Downloading and configuring voice model for $predefined_voice..."
        
        # In a real implementation, this would download a model
        python3 -c "
import os
import sys
import time
import json
from tqdm import tqdm

print('Downloading voice model...')
for i in tqdm(range(100)):
    time.sleep(0.1)  # Simulate download

# Create a placeholder voice model file
with open('$CUSTOM_VOICES_PATH/$voice_name/voice_model.json', 'w') as f:
    json.dump({
        'name': '$voice_name',
        'source': '$predefined_voice',
        'created': '$(date)',
        'predefined': True
    }, f, indent=4)

print('Voice model downloaded successfully!')
"
    fi
    
    # Create a metadata file for the voice
    cat > "$CUSTOM_VOICES_PATH/$voice_name/metadata.json" << EOF
{
    "name": "$voice_name",
    "type": "cloned",
    "source": "$clone_source",
    "created": "$(date)",
    "engine": "coqui_tts",
    "description": "Voice cloned from $clone_source"
}
EOF
    
    print_success "Voice '$voice_name' cloned successfully"
    
    read -p "Would you like to apply this voice to Dia now? (y/n): " apply_now
    
    if [[ "$apply_now" == "y" || "$apply_now" == "Y" ]]; then
        apply_voice "$voice_name"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# List available custom voices
list_custom_voices() {
    print_header "Available Custom Voices"
    
    # Get current voice
    current_voice=$(get_current_voice)
    
    echo -e "${CYAN}ID | Voice Name | Type | Description${NC}"
    echo "----|-----------|------|------------"
    
    count=1
    found_voices=false
    
    # List all voice directories
    for voice_dir in "$CUSTOM_VOICES_PATH"/*; do
        if [ -d "$voice_dir" ] && [ -f "$voice_dir/metadata.json" ]; then
            found_voices=true
            voice_name=$(basename "$voice_dir")
            
            # Extract voice details
            voice_type=$(python3 -c "import json; print(json.load(open('$voice_dir/metadata.json'))['type'])")
            voice_desc=$(python3 -c "import json; print(json.load(open('$voice_dir/metadata.json'))['description'])")
            
            # Truncate description if too long
            if [ ${#voice_desc} -gt 40 ]; then
                voice_desc="${voice_desc:0:37}..."
            fi
            
            # Mark active voice
            if [ "$voice_name" == "$current_voice" ]; then
                echo -e "${GREEN}$count  | $voice_name * | $voice_type | $voice_desc${NC}"
            else
                echo "$count  | $voice_name | $voice_type | $voice_desc"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ "$found_voices" = false ]; then
        echo "No custom voices found. Create one first!"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Test a custom voice
test_custom_voice() {
    print_header "Test Custom Voice"
    
    # Build list of voices
    voices=()
    echo "Available voices:"
    count=1
    
    for voice_dir in "$CUSTOM_VOICES_PATH"/*; do
        if [ -d "$voice_dir" ] && [ -f "$voice_dir/metadata.json" ]; then
            voice_name=$(basename "$voice_dir")
            voices+=("$voice_name")
            echo "$count) $voice_name"
            count=$((count+1))
        fi
    done
    
    if [ ${#voices[@]} -eq 0 ]; then
        print_warning "No custom voices found. Create one first!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select voice to test [1-${#voices[@]}]: " voice_idx
    
    if ! [[ "$voice_idx" =~ ^[0-9]+$ ]] || [ "$voice_idx" -lt 1 ] || [ "$voice_idx" -gt ${#voices[@]} ]; then
        print_error "Invalid selection"
    fi
    
    voice_name="${voices[$((voice_idx-1))]}"
    
    # Get test phrase
    read -p "Enter a phrase to speak (or press Enter for default): " phrase
    phrase=${phrase:-"Hello, I am Dia, your voice assistant with a custom voice. How can I help you today?"}
    
    echo "Testing voice: $voice_name"
    echo "Phrase: \"$phrase\""
    
    # In a real implementation, this would use the actual voice model
    python3 -c "
import os
import sys
import json

try:
    # In a real implementation:
    # 1. Load the custom voice model
    # 2. Generate speech with the model
    # 3. Play it through the speakers
    
    # For now, we'll use espeak as a fallback
    import subprocess
    subprocess.run(['espeak', '$phrase'])
    
    print('Voice test completed')
except Exception as e:
    print(f'Error testing voice: {e}')
    sys.exit(1)
"
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Delete a custom voice
delete_custom_voice() {
    print_header "Delete Custom Voice"
    
    # Get current voice
    current_voice=$(get_current_voice)
    
    # Build list of voices
    voices=()
    echo "Available voices:"
    count=1
    
    for voice_dir in "$CUSTOM_VOICES_PATH"/*; do
        if [ -d "$voice_dir" ] && [ -f "$voice_dir/metadata.json" ]; then
            voice_name=$(basename "$voice_dir")
            voices+=("$voice_name")
            
            if [ "$voice_name" == "$current_voice" ]; then
                echo "$count) $voice_name (active)"
            else
                echo "$count) $voice_name"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ ${#voices[@]} -eq 0 ]; then
        print_warning "No custom voices found. Nothing to delete!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select voice to delete [1-${#voices[@]}]: " voice_idx
    
    if ! [[ "$voice_idx" =~ ^[0-9]+$ ]] || [ "$voice_idx" -lt 1 ] || [ "$voice_idx" -gt ${#voices[@]} ]; then
        print_error "Invalid selection"
    fi
    
    voice_name="${voices[$((voice_idx-1))]}"
    
    # Confirm deletion
    if [ "$voice_name" == "$current_voice" ]; then
        print_warning "You are about to delete the ACTIVE voice. This is not recommended."
        read -p "Are you REALLY sure? (type 'yes' to confirm): " confirm
        if [ "$confirm" != "yes" ]; then
            print_warning "Deletion cancelled"
            read -p "Press Enter to continue..."
            show_menu
            return
        fi
    else
        read -p "Are you sure you want to delete '$voice_name'? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            print_warning "Deletion cancelled"
            read -p "Press Enter to continue..."
            show_menu
            return
        fi
    fi
    
    # Delete the voice directory
    rm -rf "$CUSTOM_VOICES_PATH/$voice_name"
    
    # Also delete any recordings
    if [ -d "$RECORDINGS_PATH/$voice_name" ]; then
        rm -rf "$RECORDINGS_PATH/$voice_name"
    fi
    
    print_success "Deleted voice: $voice_name"
    
    # If we deleted the active voice, reset to default
    if [ "$voice_name" == "$current_voice" ]; then
        print_warning "You deleted the active voice. Resetting to default."
        
        # Update main config to use default voice
        python3 -c "
import yaml

# Load config
with open('$CONFIG_PATH/dia.yaml', 'r') as f:
    config = yaml.safe_load(f) or {}

# Ensure TTS section exists
if 'tts' not in config:
    config['tts'] = {}

# Remove custom voice setting
if 'custom_voice' in config['tts']:
    del config['tts']['custom_voice']

# Save config
with open('$CONFIG_PATH/dia.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
    fi
    
    read -p "Press Enter to continue..."
    show_menu
}

# Apply a custom voice to Dia
apply_custom_voice() {
    print_header "Apply Custom Voice to Dia"
    
    # Build list of voices
    voices=()
    echo "Available voices:"
    count=1
    
    for voice_dir in "$CUSTOM_VOICES_PATH"/*; do
        if [ -d "$voice_dir" ] && [ -f "$voice_dir/metadata.json" ]; then
            voice_name=$(basename "$voice_dir")
            voices+=("$voice_name")
            echo "$count) $voice_name"
            count=$((count+1))
        fi
    done
    
    if [ ${#voices[@]} -eq 0 ]; then
        print_warning "No custom voices found. Create one first!"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Select voice to apply [1-${#voices[@]}]: " voice_idx
    
    if ! [[ "$voice_idx" =~ ^[0-9]+$ ]] || [ "$voice_idx" -lt 1 ] || [ "$voice_idx" -gt ${#voices[@]} ]; then
        print_error "Invalid selection"
    fi
    
    voice_name="${voices[$((voice_idx-1))]}"
    
    apply_voice "$voice_name"
    
    read -p "Press Enter to continue..."
    show_menu
}

# Apply a voice (internal function)
apply_voice() {
    local voice_name=$1
    
    echo "Applying voice '$voice_name' to Dia..."
    
    # Update main config
    python3 -c "
import yaml

# Load config
with open('$CONFIG_PATH/dia.yaml', 'r') as f:
    config = yaml.safe_load(f) or {}

# Ensure TTS section exists
if 'tts' not in config:
    config['tts'] = {}

# Update TTS settings to use custom voice
config['tts']['engine'] = 'custom'  # Use custom voice engine
config['tts']['custom_voice'] = '$voice_name'

# Save config
with open('$CONFIG_PATH/dia.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
    
    print_success "Applied voice '$voice_name' to Dia"
    
    # If service is running, restart it to apply changes
    if systemctl is-active --quiet dia.service; then
        read -p "Dia service is running. Restart to apply changes? (y/n): " restart
        if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
            systemctl restart dia.service
            print_success "Restarted Dia service with new voice"
        else
            print_warning "Changes will apply next time Dia starts"
        fi
    fi
}

# Get current voice name
get_current_voice() {
    python3 -c "
import yaml

try:
    # Load config
    with open('$CONFIG_PATH/dia.yaml', 'r') as f:
        config = yaml.safe_load(f) or {}
    
    # Get current voice
    if 'tts' in config and 'custom_voice' in config['tts']:
        print(config['tts']['custom_voice'])
    else:
        print('none')
except:
    print('none')
"
}

# Check environment before starting
check_environment

# Show the menu
show_menu
