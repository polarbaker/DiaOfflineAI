#!/bin/bash
#
# Dia Assistant LLM Setup Script
# Downloads and configures a Large Language Model for the Dia assistant

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
DIA_PATH="/opt/dia"
VENV_PATH="$DIA_PATH/venv"
LLM_PATH="/mnt/nvme/dia/llm"
FALLBACK_LLM_PATH="$DIA_PATH/models/llm"

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

# Display welcome message
print_header "Dia Voice Assistant LLM Setup"
echo "This script will download and configure a Large Language Model for Dia."
echo "Choose your preferred LLM model:"
echo "1) Llama 3 8B (Recommended for most Raspberry Pi 5 setups)"
echo "2) Llama 3.1 8B (Latest, better performance but may run slower)"
echo "3) Phi-3 Mini (Microsoft's smaller, efficient model for RPi)"
echo "4) Mistral 7B Instruct (Good instruction following, alternative option)"
echo "5) Deepseek Coder V2 (Optimized for code understanding, not general QA)"
echo "6) Custom model (specify a HuggingFace model ID)"
echo "7) Quit"
read -p "Enter option [1-7]: " option

# Check if we have an NVMe mounted
if [ -d "/mnt/nvme" ]; then
    LLM_PATH="/mnt/nvme/dia/llm"
else
    print_warning "NVMe not detected, using fallback storage path"
    LLM_PATH="$FALLBACK_LLM_PATH"
fi

# Create directories
mkdir -p "$LLM_PATH"

# Check for Python virtual environment
if [ ! -d "$VENV_PATH" ]; then
    print_error "Python virtual environment not found at $VENV_PATH"
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Install required packages if not already installed
pip install --quiet huggingface_hub transformers torch optimum ctranslate2

# Function to download model
download_model() {
    local model_id=$1
    local model_name=$2
    
    print_header "Downloading $model_name"
    echo "Model ID: $model_id"
    echo "This may take a while depending on your internet connection..."
    
    # Create model directory
    local model_dir="$LLM_PATH/$model_name"
    mkdir -p "$model_dir"
    
    # Download model using huggingface_hub
    python3 -c "
from huggingface_hub import snapshot_download
import os

model_id = '$model_id'
model_dir = '$model_dir'

print(f'Downloading {model_id} to {model_dir}...')
snapshot_download(repo_id=model_id, local_dir=model_dir, 
                 local_dir_use_symlinks=False)
print('Download complete!')
"
    
    # Create symlink if necessary
    if [ "$LLM_PATH" != "$FALLBACK_LLM_PATH" ]; then
        ln -sf "$model_dir" "$FALLBACK_LLM_PATH/$(basename "$model_dir")"
    fi
    
    # Return model directory name
    echo "$model_name"
}

# Function to optimize model for Raspberry Pi
optimize_model() {
    local model_name=$1
    local quantize=${2:-true}
    
    print_header "Optimizing Model for Raspberry Pi"
    echo "This process will create an optimized version for faster inference"
    
    if [ "$quantize" = true ]; then
        echo "Model will be quantized to 4-bit for better performance"
    fi
    
    local model_dir="$LLM_PATH/$model_name"
    local optimized_dir="${model_dir}_optimized"
    
    python3 -c "
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import os

model_dir = '$model_dir'
optimized_dir = '$optimized_dir'
quantize = $quantize

print(f'Loading model from {model_dir}...')
tokenizer = AutoTokenizer.from_pretrained(model_dir)
tokenizer.save_pretrained(optimized_dir)

if quantize:
    print('Quantizing model to 4-bit...')
    from transformers import BitsAndBytesConfig
    
    quantization_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_compute_dtype=torch.float16
    )
    
    model = AutoModelForCausalLM.from_pretrained(
        model_dir,
        device_map='auto',
        quantization_config=quantization_config
    )
else:
    model = AutoModelForCausalLM.from_pretrained(model_dir)

print(f'Saving optimized model to {optimized_dir}...')
model.save_pretrained(optimized_dir)
print('Optimization complete!')
"
    
    # Return optimized model directory name
    echo "$(basename "$optimized_dir")"
}

# Function to update Dia configuration
update_config() {
    local model_name=$1
    local optimized=${2:-true}
    
    print_header "Updating Dia Configuration"
    
    if [ "$optimized" = true ]; then
        model_name="${model_name}_optimized"
    fi
    
    local config_file="$DIA_PATH/config/dia.yaml"
    
    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found at $config_file"
    fi
    
    # Backup config file
    cp "$config_file" "${config_file}.bak"
    
    # Update LLM config section
    python3 -c "
import yaml
import os

config_file = '$config_file'
model_name = '$model_name'
model_path = os.path.join('$LLM_PATH', model_name)

# Load config
with open(config_file, 'r') as f:
    config = yaml.safe_load(f)

# Update LLM section
if 'llm' not in config:
    config['llm'] = {}

config['llm']['enabled'] = True
config['llm']['model_path'] = model_path
config['llm']['model_type'] = 'huggingface'
config['llm']['device'] = 'cpu'  # Default to CPU
config['llm']['context_size'] = 2048
config['llm']['max_tokens'] = 512

# Save config
with open(config_file, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print(f'Updated configuration in {config_file}')
"
    
    print_success "Configuration updated"
}

# Process selected option
case $option in
    1)
        model_id="meta-llama/Llama-3-8B-Instruct"
        model_name="llama3-8b-instruct"
        ;;
    2)
        model_id="meta-llama/Meta-Llama-3.1-8B-Instruct"
        model_name="meta-llama3.1-8b-instruct"
        ;;
    3)
        model_id="microsoft/Phi-3-mini-4k-instruct"
        model_name="phi3-mini-instruct"
        ;;
    4)
        model_id="mistralai/Mistral-7B-Instruct-v0.2"
        model_name="mistral-7b-instruct"
        ;;
    5)
        model_id="deepseek-ai/deepseek-coder-v2-theta"
        model_name="deepseek-coder-v2"
        ;;
    6)
        read -p "Enter HuggingFace model ID: " model_id
        read -p "Enter a simple name for the model: " model_name
        ;;
    7)
        echo "Exiting without downloading model."
        exit 0
        ;;
    *)
        print_error "Invalid option"
        ;;
esac

# Ask if Coral TPU should be used if available
read -p "Do you have a Coral TPU connected? (y/n): " use_tpu
if [[ "$use_tpu" == "y" || "$use_tpu" == "Y" ]]; then
    # Update config to use TPU
    python3 -c "
import yaml

config_file = '$DIA_PATH/config/dia.yaml'

# Load config
with open(config_file, 'r') as f:
    config = yaml.safe_load(f)

# Update LLM section to use TPU
if 'llm' not in config:
    config['llm'] = {}

config['llm']['device'] = 'tpu'
config['llm']['tpu_device'] = 'edgetpu'

# Save config
with open(config_file, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print('Updated configuration to use Coral TPU')
"
    print_success "Configuration updated to use Coral TPU"
fi

# Download the model
downloaded_model=$(download_model "$model_id" "$model_name")

# Optimize the model
read -p "Would you like to optimize the model for faster inference? (y/n): " optimize
if [[ "$optimize" == "y" || "$optimize" == "Y" ]]; then
    optimized_model=$(optimize_model "$downloaded_model" true)
    update_config "$downloaded_model" true
else
    update_config "$downloaded_model" false
fi

# Final message
print_header "LLM Setup Complete!"
echo "The Dia assistant has been configured to use the new LLM model."
echo "To test the model, restart the Dia service with:"
echo "  sudo systemctl restart dia.service"
echo ""
echo "You can also use the dia-control script:"
echo "  dia-control restart"

exit 0
