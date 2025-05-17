#!/usr/bin/env python3
"""
Dia Assistant - Offline Voice Assistant for Raspberry Pi

This is the main entry point for the Dia assistant that:
1. Listens for wake-word in a loop
2. Records user query to WAV
3. Runs ASR to convert speech to text
4. Processes query with LLM or rule engine
5. Generates response with TTS
6. Plays response over audio output
"""

import os
import sys
import time
import logging
import signal
import yaml
import argparse
from pathlib import Path

# Add the project root to the path so we can import modules
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

# Import modules
from src.wake import wake_word_detector
from src.asr import speech_recognition
from src.llm import response_generator
from src.tts import speech_synthesis
from src.audio import audio_manager
from src.utils import error_handler, config_loader, logging_config

# Set up logging
log_dir = os.environ.get('DIA_LOG_DIR', '/var/log/dia')
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, 'dia_assistant.log')
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Global flags
running = True
recording = False

def signal_handler(sig, frame):
    """Handle process termination signals."""
    global running
    logger.info("Received termination signal, shutting down...")
    running = False

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Dia Assistant - Offline Voice Assistant')
    parser.add_argument(
        '--config', 
        default=os.path.join(project_root, 'config', 'dia.yaml'),
        help='Path to configuration file'
    )
    parser.add_argument(
        '--debug', 
        action='store_true',
        help='Enable debug mode'
    )
    return parser.parse_args()

def main():
    """Main application entry point."""
    # Parse command line arguments
    args = parse_arguments()
    
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Load configuration
    logger.info("Loading configuration...")
    config = config_loader.load_config(args.config)
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
        logger.debug("Debug mode enabled")
    
    try:
        # Initialize components
        logger.info("Initializing audio subsystem...")
        audio = audio_manager.AudioManager(config['audio'])
        
        logger.info("Initializing wake word detector...")
        wake = wake_word_detector.WakeWordDetector(config['wake_word'])
        
        logger.info("Initializing ASR engine...")
        asr = speech_recognition.SpeechRecognizer(config['asr'])
        
        logger.info("Initializing response generator...")
        llm = response_generator.ResponseGenerator(config['response_generator'])
        
        logger.info("Initializing TTS engine...")
        tts = speech_synthesis.SpeechSynthesizer(config['tts'])
        
        # Main application loop
        logger.info("Dia Assistant is ready!")
        
        while running:
            # Step 1: Listen for wake word
            logger.debug("Listening for wake word...")
            audio_buffer = audio.listen()
            
            if wake.detect(audio_buffer):
                logger.info("Wake word detected!")
                
                try:
                    # Step 2: Record query
                    logger.debug("Recording query...")
                    query_audio = audio.record_query(max_duration=5)
                    
                    # Step 3: Transcribe speech
                    logger.debug("Transcribing speech...")
                    query_text = asr.transcribe(query_audio)
                    logger.info(f"Transcribed: '{query_text}'")
                    
                    # Step 4: Generate response
                    logger.debug("Generating response...")
                    response_text = llm.generate_response(query_text)
                    logger.info(f"Response: '{response_text}'")
                    
                    # Step 5: Synthesize speech
                    logger.debug("Synthesizing speech...")
                    response_audio = tts.synthesize(response_text)
                    
                    # Step 6: Play response
                    logger.debug("Playing response...")
                    audio.play(response_audio)
                    
                except Exception as e:
                    error_msg = f"Error in processing: {str(e)}"
                    logger.error(error_msg)
                    error_handler.handle_error(e)
                    
                    # Play error audio if available
                    try:
                        audio.play_error_sound()
                    except:
                        pass
            
            # Small sleep to reduce CPU usage
            time.sleep(0.01)
            
    except Exception as e:
        logger.critical(f"Critical error: {str(e)}", exc_info=True)
        return 1
    finally:
        # Clean up resources
        logger.info("Cleaning up resources...")
        try:
            audio.cleanup()
            wake.cleanup()
            asr.cleanup()
            llm.cleanup()
            tts.cleanup()
        except Exception as e:
            logger.error(f"Error during cleanup: {str(e)}")
    
    logger.info("Dia Assistant shut down successfully")
    return 0

if __name__ == "__main__":
    sys.exit(main())
