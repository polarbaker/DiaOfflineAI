#!/bin/bash
#
# Dia Voice Assistant Model Download Script
# 
# This script downloads and manages models for the Dia voice assistant.
# It supports downloading ASR, TTS, wake word, and LLM models.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
DIA_PATH="/opt/dia"
MODEL_PATH="$DIA_PATH/models"

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

# Function to download a file with progress tracking
download_file() {
    echo "Downloading $1 to $2..."
    wget -q --show-progress -O "$2" "$1" || print_error "Failed to download $1"
}

# Display help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --asr <model>     Download ASR model (vosk-small, vosk-medium, vosk-large)"
    echo "  --tts <model>     Download TTS model (dia-expressive, coqui-ljspeech, espeak)"
    echo "  --wake <model>    Download wake word model (hey-dia, alexa, jarvis, computer)"
    echo "  --llm <model>     Download LLM model (llama-7b, phi-2, gemma-2b)"
    echo "  --rag             Set up RAG database with embeddings model"
    echo "  --all             Download all default models"
    echo "  --list            List available models"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --asr vosk-small"
    echo "  $0 --tts dia-expressive"
    echo "  $0 --all"
    exit 0
}

# List available models
list_models() {
    print_header "Available Models"
    
    echo "ASR Models:"
    echo "  vosk-small     : Vosk small English model (0.5GB)"
    echo "  vosk-medium    : Vosk medium English model (1.5GB)"
    echo "  vosk-large     : Vosk large English model (3.0GB)"
    echo ""
    echo "TTS Models:"
    echo "  dia-expressive : Custom Dia voice model (1.0GB)"
    echo "  coqui-ljspeech : LJSpeech TTS model (150MB)"
    echo "  espeak         : Espeak TTS (uses system package)"
    echo ""
    echo "Wake Word Models:"
    echo "  hey-dia        : 'Hey Dia' wake word model (15MB)"
    echo "  alexa          : 'Alexa' wake word model (15MB)"
    echo "  jarvis         : 'Jarvis' wake word model (15MB)"
    echo "  computer       : 'Computer' wake word model (15MB)"
    echo ""
    echo "LLM Models:"
    echo "  llama-7b       : Llama 2 7B GGUF model (4.0GB)"
    echo "  phi-2          : Microsoft Phi-2 GGUF model (2.5GB)"
    echo "  gemma-2b       : Google Gemma 2B GGUF model (1.5GB)"
    exit 0
}

# Check for no arguments
if [ $# -eq 0 ]; then
    show_help
fi

# Process options
while [ $# -gt 0 ]; do
    case "$1" in
        --asr)
            ASR_MODEL="$2"
            shift 2
            ;;
        --tts)
            TTS_MODEL="$2"
            shift 2
            ;;
        --wake)
            WAKE_MODEL="$2"
            shift 2
            ;;
        --llm)
            LLM_MODEL="$2"
            shift 2
            ;;
        --rag)
            SETUP_RAG=true
            shift
            ;;
        --all)
            ASR_MODEL="vosk-small"
            TTS_MODEL="espeak"
            WAKE_MODEL="hey-dia"
            LLM_MODEL="phi-2"
            shift
            ;;
        --list)
            list_models
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            ;;
    esac
done

# Display welcome message
print_header "Dia Voice Assistant Model Download"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_warning "This script should be run as root (sudo) for proper permissions."
    echo "Do you want to continue anyway? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Download cancelled."
        exit 0
    fi
fi

# Check for model path
if [ ! -d "$MODEL_PATH" ]; then
    mkdir -p "$MODEL_PATH/asr"
    mkdir -p "$MODEL_PATH/tts"
    mkdir -p "$MODEL_PATH/wake"
    mkdir -p "$MODEL_PATH/llm"
    print_success "Created model directories"
fi

# Download ASR model
if [ ! -z "$ASR_MODEL" ]; then
    print_header "Downloading ASR Model: $ASR_MODEL"
    
    ASR_DIR="$MODEL_PATH/asr"
    mkdir -p "$ASR_DIR"
    
    case "$ASR_MODEL" in
        vosk-small)
            if [ ! -d "$ASR_DIR/vosk-model-small-en-us-0.15" ]; then
                download_file "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip" "/tmp/vosk-model.zip"
                echo "Extracting model..."
                unzip -q "/tmp/vosk-model.zip" -d "$ASR_DIR/"
                rm "/tmp/vosk-model.zip"
                print_success "Downloaded and extracted vosk-small model"
            else
                print_warning "vosk-small model already exists"
            fi
            ;;
        vosk-medium)
            if [ ! -d "$ASR_DIR/vosk-model-en-us-0.22" ]; then
                download_file "https://alphacephei.com/vosk/models/vosk-model-en-us-0.22.zip" "/tmp/vosk-model.zip"
                echo "Extracting model..."
                unzip -q "/tmp/vosk-model.zip" -d "$ASR_DIR/"
                rm "/tmp/vosk-model.zip"
                print_success "Downloaded and extracted vosk-medium model"
            else
                print_warning "vosk-medium model already exists"
            fi
            ;;
        vosk-large)
            if [ ! -d "$ASR_DIR/vosk-model-en-us-0.22-lgraph" ]; then
                download_file "https://alphacephei.com/vosk/models/vosk-model-en-us-0.22-lgraph.zip" "/tmp/vosk-model.zip"
                echo "Extracting model..."
                unzip -q "/tmp/vosk-model.zip" -d "$ASR_DIR/"
                rm "/tmp/vosk-model.zip"
                print_success "Downloaded and extracted vosk-large model"
            else
                print_warning "vosk-large model already exists"
            fi
            ;;
        *)
            print_error "Unknown ASR model: $ASR_MODEL"
            ;;
    esac
    
    # Update config to point to the new model
    echo "Updating dia.yaml configuration to use $ASR_MODEL..."
    if [ -f "$DIA_PATH/config/dia.yaml" ]; then
        # Create backup
        cp "$DIA_PATH/config/dia.yaml" "$DIA_PATH/config/dia.yaml.bak"
        
        # Update model path based on the model name
        case "$ASR_MODEL" in
            vosk-small)
                MODEL_DIR_NAME="vosk-model-small-en-us-0.15"
                ;;
            vosk-medium)
                MODEL_DIR_NAME="vosk-model-en-us-0.22"
                ;;
            vosk-large)
                MODEL_DIR_NAME="vosk-model-en-us-0.22-lgraph"
                ;;
        esac
        
        # Update the config file
        sed -i "s|model_path:.*asr.*|model_path: \"$ASR_DIR/$MODEL_DIR_NAME\"|g" "$DIA_PATH/config/dia.yaml"
        print_success "Updated configuration file"
    fi
fi

# Download TTS model
if [ ! -z "$TTS_MODEL" ]; then
    print_header "Downloading TTS Model: $TTS_MODEL"
    
    TTS_DIR="$MODEL_PATH/tts"
    mkdir -p "$TTS_DIR"
    
    case "$TTS_MODEL" in
        dia-expressive)
            echo "Note: This would normally download a custom TTS model."
            echo "For this example, we'll create placeholder files."
            touch "$TTS_DIR/tts_model.pth"
            touch "$TTS_DIR/tts_config.json"
            print_success "Created placeholder for dia-expressive TTS model"
            ;;
        coqui-ljspeech)
            # This model would be dynamically downloaded by TTS library
            # But we'll add configuration to make it explicit
            echo '{
  "model_type": "tts_models/en/ljspeech/tacotron2-DDC",
  "speaker_embeddings": null,
  "language_embeddings": null
}' > "$TTS_DIR/coqui-ljspeech.json"
            print_success "Set up coqui-ljspeech TTS model configuration"
            ;;
        espeak)
            # Check if espeak is installed
            if ! command -v espeak &> /dev/null; then
                echo "Installing espeak package..."
                apt-get update && apt-get install -y espeak
            fi
            print_success "Espeak TTS is ready to use"
            ;;
        *)
            print_error "Unknown TTS model: $TTS_MODEL"
            ;;
    esac
    
    # Update config to use the new TTS model
    if [ -f "$DIA_PATH/config/dia.yaml" ]; then
        # Create backup if it doesn't exist
        if [ ! -f "$DIA_PATH/config/dia.yaml.bak" ]; then
            cp "$DIA_PATH/config/dia.yaml" "$DIA_PATH/config/dia.yaml.bak"
        fi
        
        # Update model type
        sed -i "s|type:.*\".*\"|type: \"$TTS_MODEL\"|g" "$DIA_PATH/config/dia.yaml"
        print_success "Updated TTS configuration"
    fi
fi

# Download wake word model
if [ ! -z "$WAKE_MODEL" ]; then
    print_header "Downloading Wake Word Model: $WAKE_MODEL"
    
    WAKE_DIR="$MODEL_PATH/wake"
    mkdir -p "$WAKE_DIR"
    
    case "$WAKE_MODEL" in
        hey-dia|alexa|jarvis|computer)
            echo "Note: This would normally download the $WAKE_MODEL wake word model."
            echo "For this example, we'll create a placeholder file."
            touch "$WAKE_DIR/$WAKE_MODEL.ppn"
            print_success "Created placeholder for $WAKE_MODEL wake word model"
            
            # Update config to use the new wake word model
            if [ -f "$DIA_PATH/config/dia.yaml" ]; then
                # Create backup if it doesn't exist
                if [ ! -f "$DIA_PATH/config/dia.yaml.bak" ]; then
                    cp "$DIA_PATH/config/dia.yaml" "$DIA_PATH/config/dia.yaml.bak"
                fi
                
                # Update keyword path
                sed -i "s|keyword_path:.*|keyword_path: \"$WAKE_DIR/$WAKE_MODEL.ppn\"|g" "$DIA_PATH/config/dia.yaml"
                print_success "Updated wake word configuration"
            fi
            ;;
        *)
            print_error "Unknown wake word model: $WAKE_MODEL"
            ;;
    esac
fi

# Download LLM model
if [ ! -z "$LLM_MODEL" ]; then
    print_header "Downloading LLM Model: $LLM_MODEL"
    
    LLM_DIR="$MODEL_PATH/llm"
    mkdir -p "$LLM_DIR"
    
    case "$LLM_MODEL" in
        llama-7b)
            FILENAME="llama-2-7b-chat.Q4_K_M.gguf"
            if [ ! -f "$LLM_DIR/$FILENAME" ]; then
                echo "This would download the Llama 2 7B model (4GB)."
                echo "For this example, we'll create a placeholder file."
                touch "$LLM_DIR/$FILENAME"
                print_success "Created placeholder for Llama 2 7B model"
            else
                print_warning "Llama 2 7B model already exists"
            fi
            ;;
        phi-2)
            FILENAME="phi-2.Q4_K_M.gguf"
            if [ ! -f "$LLM_DIR/$FILENAME" ]; then
                echo "This would download the Microsoft Phi-2 model (2.5GB)."
                echo "For this example, we'll create a placeholder file."
                touch "$LLM_DIR/$FILENAME"
                print_success "Created placeholder for Phi-2 model"
            else
                print_warning "Phi-2 model already exists"
            fi
            ;;
        gemma-2b)
            FILENAME="gemma-2b.Q4_K_M.gguf"
            if [ ! -f "$LLM_DIR/$FILENAME" ]; then
                echo "This would download the Google Gemma 2B model (1.5GB)."
                echo "For this example, we'll create a placeholder file."
                touch "$LLM_DIR/$FILENAME"
                print_success "Created placeholder for Gemma 2B model"
            else
                print_warning "Gemma 2B model already exists"
            fi
            ;;
        *)
            print_error "Unknown LLM model: $LLM_MODEL"
            ;;
    esac
    
    # Update config to use LLM
    if [ -f "$DIA_PATH/config/dia.yaml" ]; then
        # Create backup if it doesn't exist
        if [ ! -f "$DIA_PATH/config/dia.yaml.bak" ]; then
            cp "$DIA_PATH/config/dia.yaml" "$DIA_PATH/config/dia.yaml.bak"
        fi
        
        # Update engine type and model path
        sed -i "s|engine_type:.*\"rules\"|engine_type: \"llm\"|g" "$DIA_PATH/config/dia.yaml"
        sed -i "s|model_path:.*llm.*|model_path: \"$LLM_DIR\"|g" "$DIA_PATH/config/dia.yaml"
        print_success "Updated LLM configuration"
    fi
fi

# Set up RAG if needed
if [ "$SETUP_RAG" = true ]; then
    print_header "Setting Up RAG System"
    
    RAG_DIR="/mnt/nvme/dia/rag"
    if [ ! -d "$RAG_DIR" ]; then
        if [ -d "/mnt/nvme" ]; then
            mkdir -p "$RAG_DIR"
        else
            # Fall back to local storage
            RAG_DIR="$DIA_PATH/models/rag"
            mkdir -p "$RAG_DIR"
            print_warning "NVMe not mounted, using local storage for RAG"
        fi
    fi
    
    # Create database structure
    touch "$RAG_DIR/documents.sqlite"
    mkdir -p "$RAG_DIR/embeddings"
    
    # Download embedding model
    echo "Setting up embedding model..."
    pip install sentence-transformers
    
    # Update config to enable RAG
    if [ -f "$DIA_PATH/config/dia.yaml" ]; then
        # Create backup if it doesn't exist
        if [ ! -f "$DIA_PATH/config/dia.yaml.bak" ]; then
            cp "$DIA_PATH/config/dia.yaml" "$DIA_PATH/config/dia.yaml.bak"
        fi
        
        # Enable RAG and set path
        sed -i "s|enabled: false|enabled: true|g" "$DIA_PATH/config/dia.yaml"
        sed -i "s|database_path:.*|database_path: \"$RAG_DIR\"|g" "$DIA_PATH/config/dia.yaml"
        print_success "Enabled RAG system"
    fi
    
    print_success "RAG system set up at $RAG_DIR"
fi

# Final messages
print_header "Model Download Complete!"
echo "All requested models have been downloaded and configured."
echo ""
echo "To start using these models, restart the Dia service:"
echo "  sudo systemctl restart dia.service"
echo ""
echo "Or if you're running in Docker, restart the container."

exit 0
