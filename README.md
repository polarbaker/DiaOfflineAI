# DiaBuddy: User-Friendly Offline Voice Assistant for Raspberry Pi

An entirely offline voice assistant that runs on Raspberry Pi to detect a custom wake-word, transcribe speech, generate responses, and speak them back in a custom TTS voice. DiaBuddy focuses on user-friendliness, allowing non-technical users to easily install, customize, and use a powerful voice assistant without cloud dependencies.

## Hardware Requirements

- Raspberry Pi 5 (16 GB)
- 64 GB A2 microSD (OS, swap, logs)
- 512 GB NVMe SSD on M.2 HAT+ (large models, RAG store)
- Coral USB Edge TPU + Hailo-8L AI Kit (dual accelerator)
- ReSpeaker 4-Mic Array HAT (far-field voice capture)
- HiFiBerry DAC+ HAT (speaker output)
- Official 27 W USB-C PSU, active-cooler case, GPIO spacers

## Software Components

1. **Wake-Word Engine**
   - Porcupine SDK with custom "Hey Dia" model (.ppn)

2. **Offline ASR**
   - Vosk small-en US model for 16 kHz microphone input

3. **Local LLM** (optional / future)
   - Integration with llama.cpp or similar for on-device chat

4. **TTS**
   - Dia-TTS ("dia-expressive") to synthesize responses as WAV
   - Custom voice creator and profile manager

5. **Audio I/O**
   - PyAudio for capture/playback, ALSA config tuned for ReSpeaker & DAC
   - Easy Bluetooth headset integration

6. **AI Acceleration**
   - PyCoral / TensorFlow Lite for TPU, plus Hailo SDK integration
   - Automatic performance optimization

7. **Persistence & RAG**
   - FAISS+SQLite on NVMe for retrieval of user data or documents
   - Simple knowledge pack installation

8. **User-Friendly Interfaces**
   - Visual feedback for speech recognition
   - Control Center GUI for easy management
   - Personality customization

## Project Structure

```
dia-assistant/
├── config/             # Configuration files for components
│   ├── alsa/           # ALSA configurations for audio hardware
│   ├── systemd/        # Systemd service unit
│   └── dia.yaml        # Main configuration
├── docs/               # Documentation
├── logs/               # Log files (symlinked to /var/log/dia)
├── models/             # Model storage directory
│   ├── asr/            # Vosk ASR models
│   ├── llm/            # LLM models
│   ├── tts/            # TTS voice models
│   └── wake/           # Wake word models
├── scripts/            # Utility scripts
│   ├── setup_dia.sh    # Main installation script
│   ├── model_download.sh # For downloading models
│   ├── dia-voice.sh    # Voice profile manager
│   ├── dia-custom-voice.sh # Custom voice creator
│   ├── dia-knowledge.sh # Knowledge pack manager
│   ├── dia-optimize.sh # Performance optimization
│   ├── dia-personality.sh # Personality customizer
│   ├── dia-bluetooth.sh # Bluetooth device manager
│   ├── dia-visual-test.py # Speech recognition visualizer
│   ├── dia-easy.sh     # Easy launcher for all functions
│   ├── dia-control-center.py # Graphical user interface
│   └── install-control-center.sh # GUI installer
├── src/                # Source code
│   ├── asr/            # ASR module
│   ├── llm/            # LLM/response generation
│   ├── rag/            # RAG components
│   ├── tts/            # TTS module
│   ├── wake/           # Wake word detection
│   ├── audio/          # Audio handling
│   ├── utils/          # Utility functions
│   └── dia_assistant.py # Main application entry point
├── Dockerfile          # For containerization
├── docker-compose.yml  # Docker configuration
└── requirements.txt    # Python dependencies
```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-org/diabuddy.git
   cd diabuddy
   ```

2. Run the easy setup script:
   ```bash
   ./scripts/easy-setup.sh
   ```
   
The setup script will:
- Create a Python virtual environment
- Install required dependencies
- Download necessary models
- Configure hardware components
- Set up systemd service
- Create desktop shortcuts
- Install the Dia Control Center

## Usage

Once installed, DiaBuddy will automatically start on boot. The easiest way to manage it is through the graphical Control Center:

```bash
# Launch the graphical control center
sudo dia-control
```

Alternatively, you can use command-line tools:

```bash
# Launch the easy management menu
dia-easy

# Or use the traditional service commands
sudo systemctl start dia.service
sudo systemctl status dia.service
sudo systemctl stop dia.service
```

## User-Friendly Features

### Visual Control Center

The Dia Control Center provides an intuitive graphical interface with:
- Simple start/stop/restart buttons
- Status indicator showing if Dia is running
- Quick access to all tools organized by category
- Clean, modern interface that's easy to navigate

### Voice & Personality

```bash
# Voice profile manager
dia-voice

# Custom voice creator
dia-custom-voice

# Personality customizer
dia-personality
```

### Knowledge Management

```bash
# Install specialized knowledge packs
dia-knowledge
```

### Hardware & Performance

```bash
# Set up Bluetooth devices
dia-bluetooth

# Test speech recognition visually
dia-visual

# Optimize performance
dia-optimize
```

### Traditional Customization

#### Adding Custom Wake Words

Place your `.ppn` Porcupine wake word model files in the `models/wake/` directory and update the configuration in `config/dia.yaml`.

#### Replacing ASR/TTS Models

1. Download new models to the appropriate directory:
   ```bash
   ./scripts/model_download.sh --asr large-model
   ./scripts/model_download.sh --tts new-voice
   ```

2. Update the model paths in `config/dia.yaml`

#### RAG Updates via USB

1. Prepare your documents on a USB drive with a specific format
2. Insert the USB drive into the Raspberry Pi
3. Run the RAG update script:
   ```bash
   ./scripts/update_rag.sh --source /media/usb
   ```

## Troubleshooting

Use the Control Center to quickly access logs and status information, or check logs at `/var/log/dia/` using:
```bash
journalctl -u dia.service
```

Common issues:
- Audio device not found: Use `dia-bluetooth` to reconfigure audio devices
- Wake word not detected: Run `dia-visual` to test microphone input visually
- High CPU usage: Use `dia-optimize` to tune performance

## License

MIT License
