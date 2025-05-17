"""
Speech Recognition Module

Uses Vosk for offline speech-to-text conversion
"""

import os
import json
import logging
from pathlib import Path
import wave
import numpy as np

# Import will fail until Vosk is installed, but that's expected during setup
try:
    from vosk import Model, KaldiRecognizer
except ImportError:
    logging.warning("Vosk not found. Install with: pip install vosk")

logger = logging.getLogger(__name__)

class SpeechRecognizer:
    """Handles speech-to-text conversion using Vosk."""
    
    def __init__(self, config):
        """
        Initialize the speech recognizer.
        
        Args:
            config (dict): Configuration for ASR
        """
        self.config = config
        self.sample_rate = config.get('sample_rate', 16000)
        
        # Get model path
        model_path = config.get('model_path')
        if not model_path:
            # Use default model path
            model_path = os.path.join(Path(__file__).parent.parent.parent, 'models', 'asr')
            
            # If specific model name provided
            model_name = config.get('model_name', 'vosk-model-small-en-us-0.15')
            if model_name:
                model_path = os.path.join(model_path, model_name)
        
        # Check if model exists
        if not os.path.exists(model_path):
            logger.error(f"ASR model not found at {model_path}")
            raise FileNotFoundError(f"ASR model not found at {model_path}")
        
        # Initialize Vosk
        try:
            logger.info(f"Loading Vosk ASR model from {model_path}")
            self.model = Model(model_path)
            self.recognizer = KaldiRecognizer(self.model, self.sample_rate)
            self.recognizer.SetWords(True)
            logger.info("ASR engine initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Vosk: {str(e)}")
            raise
    
    def transcribe(self, audio_data):
        """
        Transcribe speech from audio data.
        
        Args:
            audio_data (bytes or numpy.ndarray): Audio data to transcribe
            
        Returns:
            str: Transcribed text
        """
        try:
            # Reset recognizer for new utterance
            self.recognizer.Reset()
            
            # Handle different input types
            if isinstance(audio_data, np.ndarray):
                # Handle numpy array
                if audio_data.dtype != np.int16:
                    audio_data = (audio_data * 32767).astype(np.int16)
                audio_bytes = audio_data.tobytes()
            elif isinstance(audio_data, str) and os.path.exists(audio_data):
                # Handle file path to WAV file
                with wave.open(audio_data, "rb") as wf:
                    if wf.getnchannels() != 1 or wf.getsampwidth() != 2 or wf.getcomptype() != "NONE":
                        logger.warning("Audio file must be mono PCM WAV format")
                    
                    # If sample rate doesn't match, warn but continue
                    if wf.getframerate() != self.sample_rate:
                        logger.warning(f"Audio sample rate ({wf.getframerate()} Hz) doesn't match model ({self.sample_rate} Hz)")
                    
                    audio_bytes = wf.readframes(wf.getnframes())
            else:
                # Assume it's already bytes
                audio_bytes = audio_data
            
            # Process audio
            if self.recognizer.AcceptWaveform(audio_bytes):
                result = json.loads(self.recognizer.Result())
                transcription = result.get('text', '')
            else:
                # Fallback to get partial result
                result = json.loads(self.recognizer.PartialResult())
                transcription = result.get('partial', '')
            
            logger.debug(f"Transcription: '{transcription}'")
            return transcription
            
        except Exception as e:
            logger.error(f"Error in speech recognition: {str(e)}")
            return ""
    
    def cleanup(self):
        """Release resources used by the speech recognizer."""
        # Vosk models automatically get cleaned up by Python garbage collector
        logger.debug("ASR resources released")
