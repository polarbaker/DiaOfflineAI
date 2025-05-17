#!/bin/bash
#
# Dia Personality Customizer
# Customize how Dia speaks and responds to you

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
CONFIG_PATH="$DIA_PATH/config"
PERSONALITY_PATH="$CONFIG_PATH/personalities"

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

# Ensure personality directory exists
ensure_directories() {
    mkdir -p "$PERSONALITY_PATH"
}

# Create default personalities if they don't exist
create_default_personalities() {
    # Professional personality
    if [ ! -f "$PERSONALITY_PATH/professional.yaml" ]; then
        cat > "$PERSONALITY_PATH/professional.yaml" << EOF
name: Professional
description: Formal, direct, and informative
formality: 9
verbosity: 7
humor: 2
style: direct
system_prompt: |
  You are Dia, a professional voice assistant. 
  Provide formal, accurate, and concise responses.
  Focus on facts and clear explanations.
  Use professional language and avoid casual expressions.
  Be respectful, logical, and straight to the point.
date_created: "$(date -Iseconds)"
EOF
    fi

    # Friendly personality
    if [ ! -f "$PERSONALITY_PATH/friendly.yaml" ]; then
        cat > "$PERSONALITY_PATH/friendly.yaml" << EOF
name: Friendly
description: Casual, warm, and approachable
formality: 4
verbosity: 6
humor: 6
style: conversational
system_prompt: |
  You are Dia, a friendly and helpful voice assistant.
  Be warm, personable, and conversational in your responses.
  It's good to add a touch of humor when appropriate.
  Use casual language and be encouraging.
  Feel free to use simple expressions of emotion.
date_created: "$(date -Iseconds)"
EOF
    fi

    # Concise personality
    if [ ! -f "$PERSONALITY_PATH/concise.yaml" ]; then
        cat > "$PERSONALITY_PATH/concise.yaml" << EOF
name: Concise
description: Brief, direct, and to-the-point
formality: 5
verbosity: 2
humor: 3
style: direct
system_prompt: |
  You are Dia, a concise voice assistant.
  Keep all responses as brief as possible while maintaining clarity.
  Use short sentences and simple language.
  Avoid unnecessary details or elaboration.
  Focus on delivering key information quickly.
date_created: "$(date -Iseconds)"
EOF
    fi

    # Detailed personality
    if [ ! -f "$PERSONALITY_PATH/detailed.yaml" ]; then
        cat > "$PERSONALITY_PATH/detailed.yaml" << EOF
name: Detailed
description: Thorough, informative, and educational
formality: 7
verbosity: 9
humor: 4
style: conversational
system_prompt: |
  You are Dia, a detailed and thorough voice assistant.
  Provide comprehensive, in-depth responses.
  Include relevant background information and context.
  Explain concepts thoroughly and connect ideas.
  Organize information logically with examples when helpful.
date_created: "$(date -Iseconds)"
EOF
    fi

    # Playful personality
    if [ ! -f "$PERSONALITY_PATH/playful.yaml" ]; then
        cat > "$PERSONALITY_PATH/playful.yaml" << EOF
name: Playful
description: Fun, humorous, and lighthearted
formality: 2
verbosity: 5
humor: 9
style: conversational
system_prompt: |
  You are Dia, a playful and fun voice assistant.
  Keep your tone light, energetic, and entertaining.
  Use humor, wit, and playful expressions frequently.
  Be conversational and personable.
  It's okay to be a bit silly or use casual language.
date_created: "$(date -Iseconds)"
EOF
    fi
}

# List available personalities
list_personalities() {
    print_header "Available Personalities"
    
    # Get current personality
    current_personality=$(get_current_personality)
    
    echo -e "${CYAN}${BOLD}ID | Name | Description | Style${NOBOLD}${NC}"
    echo "----------------------------------------"
    
    count=1
    found=false
    
    # List all personality files
    for personality in "$PERSONALITY_PATH"/*.yaml; do
        if [ -f "$personality" ]; then
            found=true
            name=$(basename "$personality" .yaml)
            display_name=$(python3 -c "import yaml; print(yaml.safe_load(open('$personality'))['name'])")
            description=$(python3 -c "import yaml; print(yaml.safe_load(open('$personality'))['description'])")
            style=$(python3 -c "import yaml; print(yaml.safe_load(open('$personality'))['style'])")
            
            # Truncate description if too long
            if [ ${#description} -gt 30 ]; then
                description="${description:0:27}..."
            fi
            
            # Mark active personality
            if [ "$name" == "$current_personality" ]; then
                echo -e "${GREEN}$count  | $display_name * | $description | $style${NC}"
            else
                echo "$count  | $display_name | $description | $style"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ "$found" = false ]; then
        echo "No personalities found."
    fi
}

# Get current personality
get_current_personality() {
    python3 -c "
import yaml
import os

try:
    with open('$CONFIG_PATH/dia.yaml', 'r') as f:
        config = yaml.safe_load(f) or {}
    
    personality = config.get('personality', {}).get('profile', 'friendly')
    print(personality)
except Exception:
    print('friendly')
"
}

# Apply a personality
apply_personality() {
    local personality=$1
    
    # Check if personality exists
    if [ ! -f "$PERSONALITY_PATH/$personality.yaml" ]; then
        print_error "Personality '$personality' not found"
    fi
    
    print_header "Applying $personality Personality"
    
    # Read personality details
    name=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$personality.yaml'))['name'])")
    formality=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$personality.yaml'))['formality'])")
    verbosity=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$personality.yaml'))['verbosity'])")
    humor=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$personality.yaml'))['humor'])")
    style=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$personality.yaml'))['style'])")
    system_prompt=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$personality.yaml'))['system_prompt'])")
    
    # Update configuration
    python3 -c "
import yaml
import os

# Load config
with open('$CONFIG_PATH/dia.yaml', 'r') as f:
    config = yaml.safe_load(f) or {}

# Ensure personality section exists
if 'personality' not in config:
    config['personality'] = {}

# Update personality settings
config['personality']['profile'] = '$personality'
config['personality']['name'] = '$name'
config['personality']['formality'] = $formality
config['personality']['verbosity'] = $verbosity
config['personality']['humor'] = $humor
config['personality']['style'] = '$style'
config['personality']['system_prompt'] = '''$system_prompt'''

# Save config
with open('$CONFIG_PATH/dia.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
"
    
    print_success "Applied '$name' personality to Dia"
    
    # Note about restarting Dia
    if systemctl is-active --quiet dia.service; then
        echo ""
        echo "Dia Assistant is currently running."
        read -p "Would you like to restart it to apply changes? (y/n): " restart
        
        if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
            systemctl restart dia.service
            print_success "Dia Assistant restarted with new personality"
        else
            print_warning "You'll need to restart Dia Assistant for changes to take effect"
        fi
    fi
}

# Create a new personality
create_personality() {
    print_header "Create New Personality"
    
    # Get personality name
    read -p "Enter a name for this personality: " display_name
    
    if [ -z "$display_name" ]; then
        print_error "Personality name cannot be empty"
    fi
    
    # Create file name (lowercase with underscores)
    name=$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    
    if [ -f "$PERSONALITY_PATH/$name.yaml" ]; then
        print_warning "A personality with this name already exists"
        read -p "Would you like to overwrite it? (y/n): " overwrite
        
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            print_warning "Creation cancelled"
            return
        fi
    fi
    
    # Get personality details
    read -p "Enter a short description: " description
    
    echo ""
    echo "Formality level determines how formal or casual Dia will be."
    echo "1 = Very casual, 10 = Very formal"
    read -p "Enter formality level (1-10): " formality
    
    echo ""
    echo "Verbosity level determines how detailed Dia's responses will be."
    echo "1 = Very concise, 10 = Very detailed"
    read -p "Enter verbosity level (1-10): " verbosity
    
    echo ""
    echo "Humor level determines how much humor Dia will use."
    echo "1 = Very serious, 10 = Very humorous"
    read -p "Enter humor level (1-10): " humor
    
    echo ""
    echo "Speaking style determines how Dia structures responses."
    echo "Options: direct, conversational"
    read -p "Enter speaking style: " style
    
    echo ""
    echo "System prompt is instructions for how Dia should behave."
    echo "Enter a system prompt (end with a single '.' on a new line):"
    system_prompt=""
    while IFS= read -r line; do
        if [ "$line" = "." ]; then
            break
        fi
        system_prompt+="$line"$'\n'
    done
    
    # Set defaults if empty
    description=${description:-"Custom personality"}
    formality=${formality:-5}
    verbosity=${verbosity:-5}
    humor=${humor:-5}
    style=${style:-"conversational"}
    system_prompt=${system_prompt:-"You are Dia, a voice assistant with a custom personality."}
    
    # Validate inputs
    if ! [[ "$formality" =~ ^[0-9]+$ ]] || [ "$formality" -lt 1 ] || [ "$formality" -gt 10 ]; then
        formality=5
    fi
    
    if ! [[ "$verbosity" =~ ^[0-9]+$ ]] || [ "$verbosity" -lt 1 ] || [ "$verbosity" -gt 10 ]; then
        verbosity=5
    fi
    
    if ! [[ "$humor" =~ ^[0-9]+$ ]] || [ "$humor" -lt 1 ] || [ "$humor" -gt 10 ]; then
        humor=5
    fi
    
    if [[ "$style" != "direct" && "$style" != "conversational" ]]; then
        style="conversational"
    fi
    
    # Create personality file
    cat > "$PERSONALITY_PATH/$name.yaml" << EOF
name: $display_name
description: $description
formality: $formality
verbosity: $verbosity
humor: $humor
style: $style
system_prompt: |
$system_prompt
date_created: "$(date -Iseconds)"
EOF
    
    print_success "Created personality: $display_name"
    
    # Ask to apply
    read -p "Would you like to apply this personality now? (y/n): " apply
    
    if [[ "$apply" == "y" || "$apply" == "Y" ]]; then
        apply_personality "$name"
    fi
}

# Edit an existing personality
edit_personality() {
    print_header "Edit Personality"
    
    # List personalities for selection
    personalities=()
    names=()
    echo "Available personalities:"
    count=1
    
    for personality in "$PERSONALITY_PATH"/*.yaml; do
        if [ -f "$personality" ]; then
            name=$(basename "$personality" .yaml)
            display_name=$(python3 -c "import yaml; print(yaml.safe_load(open('$personality'))['name'])")
            personalities+=("$name")
            names+=("$display_name")
            echo "$count) $display_name"
            count=$((count+1))
        fi
    done
    
    if [ ${#personalities[@]} -eq 0 ]; then
        print_warning "No personalities found. Create one first!"
        return
    fi
    
    read -p "Select personality to edit [1-${#personalities[@]}]: " personality_idx
    
    if ! [[ "$personality_idx" =~ ^[0-9]+$ ]] || [ "$personality_idx" -lt 1 ] || [ "$personality_idx" -gt ${#personalities[@]} ]; then
        print_error "Invalid selection"
    fi
    
    name="${personalities[$((personality_idx-1))]}"
    display_name="${names[$((personality_idx-1))]}"
    
    # Load current values
    description=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['description'])")
    formality=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['formality'])")
    verbosity=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['verbosity'])")
    humor=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['humor'])")
    style=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['style'])")
    system_prompt=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['system_prompt'])")
    
    echo ""
    echo "Current values for $display_name:"
    echo "Description: $description"
    echo "Formality: $formality"
    echo "Verbosity: $verbosity"
    echo "Humor: $humor"
    echo "Style: $style"
    echo "System Prompt: (too long to display)"
    echo ""
    
    echo "Enter new values (leave blank to keep current value)"
    
    # Get new values
    read -p "New description [$description]: " new_description
    read -p "New formality level (1-10) [$formality]: " new_formality
    read -p "New verbosity level (1-10) [$verbosity]: " new_verbosity
    read -p "New humor level (1-10) [$humor]: " new_humor
    read -p "New style (direct/conversational) [$style]: " new_style
    
    echo ""
    echo "Enter new system prompt (end with a single '.' on a new line, leave empty to keep current):"
    new_system_prompt=""
    while IFS= read -r line; do
        if [ "$line" = "." ]; then
            break
        fi
        if [ -z "$line" ]; then
            # Empty line means keep current prompt
            new_system_prompt=""
            break
        fi
        new_system_prompt+="$line"$'\n'
    done
    
    # Use current values if new ones are empty
    new_description=${new_description:-"$description"}
    new_formality=${new_formality:-"$formality"}
    new_verbosity=${new_verbosity:-"$verbosity"}
    new_humor=${new_humor:-"$humor"}
    new_style=${new_style:-"$style"}
    new_system_prompt=${new_system_prompt:-"$system_prompt"}
    
    # Validate inputs
    if ! [[ "$new_formality" =~ ^[0-9]+$ ]] || [ "$new_formality" -lt 1 ] || [ "$new_formality" -gt 10 ]; then
        new_formality=$formality
    fi
    
    if ! [[ "$new_verbosity" =~ ^[0-9]+$ ]] || [ "$new_verbosity" -lt 1 ] || [ "$new_verbosity" -gt 10 ]; then
        new_verbosity=$verbosity
    fi
    
    if ! [[ "$new_humor" =~ ^[0-9]+$ ]] || [ "$new_humor" -lt 1 ] || [ "$new_humor" -gt 10 ]; then
        new_humor=$humor
    fi
    
    if [[ "$new_style" != "direct" && "$new_style" != "conversational" ]]; then
        new_style=$style
    fi
    
    # Update personality file
    cat > "$PERSONALITY_PATH/$name.yaml" << EOF
name: $display_name
description: $new_description
formality: $new_formality
verbosity: $new_verbosity
humor: $new_humor
style: $new_style
system_prompt: |
$new_system_prompt
date_modified: "$(date -Iseconds)"
EOF
    
    print_success "Updated personality: $display_name"
    
    # Ask to apply
    read -p "Would you like to apply this personality now? (y/n): " apply
    
    if [[ "$apply" == "y" || "$apply" == "Y" ]]; then
        apply_personality "$name"
    fi
}

# Delete a personality
delete_personality() {
    print_header "Delete Personality"
    
    # Get current personality
    current_personality=$(get_current_personality)
    
    # List personalities for selection
    personalities=()
    names=()
    echo "Available personalities:"
    count=1
    
    for personality in "$PERSONALITY_PATH"/*.yaml; do
        if [ -f "$personality" ]; then
            name=$(basename "$personality" .yaml)
            display_name=$(python3 -c "import yaml; print(yaml.safe_load(open('$personality'))['name'])")
            personalities+=("$name")
            names+=("$display_name")
            
            if [ "$name" == "$current_personality" ]; then
                echo "$count) $display_name (active)"
            else
                echo "$count) $display_name"
            fi
            
            count=$((count+1))
        fi
    done
    
    if [ ${#personalities[@]} -eq 0 ]; then
        print_warning "No personalities found. Nothing to delete!"
        return
    fi
    
    read -p "Select personality to delete [1-${#personalities[@]}]: " personality_idx
    
    if ! [[ "$personality_idx" =~ ^[0-9]+$ ]] || [ "$personality_idx" -lt 1 ] || [ "$personality_idx" -gt ${#personalities[@]} ]; then
        print_error "Invalid selection"
    fi
    
    name="${personalities[$((personality_idx-1))]}"
    display_name="${names[$((personality_idx-1))]}"
    
    # Confirm deletion
    if [ "$name" == "$current_personality" ]; then
        print_warning "You are about to delete the ACTIVE personality. This is not recommended."
        read -p "Are you REALLY sure? (type 'yes' to confirm): " confirm
        if [ "$confirm" != "yes" ]; then
            print_warning "Deletion cancelled"
            return
        fi
    else
        read -p "Are you sure you want to delete '$display_name'? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            print_warning "Deletion cancelled"
            return
        fi
    fi
    
    # Delete the personality
    rm "$PERSONALITY_PATH/$name.yaml"
    
    print_success "Deleted personality: $display_name"
    
    # If we deleted the active personality, reset to friendly
    if [ "$name" == "$current_personality" ]; then
        print_warning "You deleted the active personality. Resetting to 'friendly'."
        apply_personality "friendly"
    fi
}

# Test a personality
test_personality() {
    print_header "Test Personality"
    
    # List personalities for selection
    personalities=()
    names=()
    echo "Available personalities:"
    count=1
    
    for personality in "$PERSONALITY_PATH"/*.yaml; do
        if [ -f "$personality" ]; then
            name=$(basename "$personality" .yaml)
            display_name=$(python3 -c "import yaml; print(yaml.safe_load(open('$personality'))['name'])")
            personalities+=("$name")
            names+=("$display_name")
            echo "$count) $display_name"
            count=$((count+1))
        fi
    done
    
    if [ ${#personalities[@]} -eq 0 ]; then
        print_warning "No personalities found. Create one first!"
        return
    fi
    
    read -p "Select personality to test [1-${#personalities[@]}]: " personality_idx
    
    if ! [[ "$personality_idx" =~ ^[0-9]+$ ]] || [ "$personality_idx" -lt 1 ] || [ "$personality_idx" -gt ${#personalities[@]} ]; then
        print_error "Invalid selection"
    fi
    
    name="${personalities[$((personality_idx-1))]}"
    display_name="${names[$((personality_idx-1))]}"
    
    # Get sample questions
    print_header "Testing $display_name Personality"
    echo "Enter sample questions to see how Dia would respond with this personality."
    echo "Type 'exit' when you're done."
    echo ""
    
    # Load personality details
    formality=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['formality'])")
    verbosity=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['verbosity'])")
    humor=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['humor'])")
    style=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['style'])")
    system_prompt=$(python3 -c "import yaml; print(yaml.safe_load(open('$PERSONALITY_PATH/$name.yaml'))['system_prompt'])")
    
    while true; do
        read -p "> " question
        
        if [ "$question" = "exit" ]; then
            break
        fi
        
        if [ -z "$question" ]; then
            continue
        fi
        
        echo ""
        echo "Processing..."
        
        # Generate a response based on personality
        # This simulates how Dia would respond with the selected personality
        python3 -c "
import time
import sys
import random

# Load personality parameters
formality = $formality
verbosity = $verbosity
humor = $humor
style = '$style'
question = '$question'

# Define personality-based response templates
def get_formal_start():
    options = [
        'I would like to inform you that ',
        'I must point out that ',
        'It is important to note that ',
        'According to my information, ',
        'I can tell you that '
    ]
    return random.choice(options)

def get_casual_start():
    options = [
        'Hey! ',
        'Well, ',
        'So, ',
        'Hmm, ',
        'OK, '
    ]
    return random.choice(options)

def get_humor_element():
    options = [
        ' (that's a fun one!)',
        ' (isn't that interesting?)',
        ' (I think that's pretty cool)',
        ' (that's my favorite topic!)',
        ' (I could talk about this all day)'
    ]
    return random.choice(options)

# Simulate thinking
print('Thinking', end='')
for _ in range(3):
    sys.stdout.flush()
    time.sleep(0.5)
    print('.', end='')
print()

# Generate a response based on personality
response = ''

# Add starter phrase based on formality
if formality > 7:
    response += get_formal_start()
elif formality < 4:
    response += get_casual_start()

# Core response based on the question
if 'time' in question.lower():
    core_response = 'it is currently 5:39 PM'
elif 'weather' in question.lower():
    core_response = 'I don't have access to real-time weather information without internet'
elif 'name' in question.lower():
    core_response = 'my name is Dia'
elif 'joke' in question.lower():
    core_response = 'Why don't scientists trust atoms? Because they make up everything!'
elif 'help' in question.lower():
    core_response = 'I can answer questions, provide information, and assist with various tasks'
else:
    core_response = f'regarding \"{question}\", I would need more information to give a complete answer'

response += core_response

# Add detail based on verbosity
if verbosity > 7:
    if 'time' in question.lower():
        response += '. The current date is May 16, 2025. If you would like, I can also tell you about upcoming appointments or set a reminder for you.'
    elif 'name' in question.lower():
        response += '. I am your offline voice assistant, designed to help you with various tasks even without an internet connection.'
    elif 'weather' in question.lower():
        response += '. To get weather information, you would need to connect me to a weather service or use a weather API.'
    else:
        response += '. I can provide more detailed information if you could specify what exactly you would like to know about this topic.'
elif verbosity > 4:
    if 'time' in question.lower():
        response += '. Is there anything specific you need to know about today\'s schedule?'
    elif 'name' in question.lower():
        response += ', your offline voice assistant.'
    elif 'weather' in question.lower():
        response += ' as I operate fully offline.'
    else:
        response += '. Would you like more specific information about this?'

# Add humor based on humor level
if humor > 7:
    response += get_humor_element()
elif humor > 5:
    if 'joke' not in question.lower():
        if random.random() > 0.5:  # 50% chance to add humor
            response += get_humor_element()

# Adjust for conversational style
if style == 'conversational':
    response += ' Is there anything else you would like to know?'

print(response)
"
        
        echo ""
    done
}

# Display the main menu
show_menu() {
    while true; do
        clear
        print_header "Dia Personality Customizer"
        
        echo -e "${BOLD}Current Personality:${NOBOLD} $(get_current_personality)"
        echo ""
        
        echo -e "${BOLD}What would you like to do?${NOBOLD}"
        echo ""
        echo "1) View Available Personalities"
        echo "2) Apply a Personality"
        echo "3) Create New Personality"
        echo "4) Edit Existing Personality"
        echo "5) Test a Personality"
        echo "6) Delete a Personality"
        echo "7) Exit"
        echo ""
        read -p "Enter your choice [1-7]: " choice
        
        case $choice in
            1)
                list_personalities
                read -p "Press Enter to continue..."
                ;;
            2)
                list_personalities
                echo ""
                read -p "Enter the name of the personality to apply: " personality
                if [ -n "$personality" ]; then
                    apply_personality "$personality"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                create_personality
                read -p "Press Enter to continue..."
                ;;
            4)
                edit_personality
                read -p "Press Enter to continue..."
                ;;
            5)
                test_personality
                read -p "Press Enter to continue..."
                ;;
            6)
                delete_personality
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

# Check if running as root
check_root

# Ensure directories exist
ensure_directories

# Create default personalities
create_default_personalities

# Run menu
show_menu
