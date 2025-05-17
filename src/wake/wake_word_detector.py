"""
Wake Word Detection Module

Uses Porcupine SDK to detect custom wake-word "Hey Dia"
"""

import os
import logging
from pathlib import Path
import numpy as np

# Import will fail until Porcupine is installed, but that's expected during setup
try:
    import pvporcupine
except ImportError:
    logging.warning("Porcupine SDK not found. Install with: pip install pvporcupine")

logger = logging.getLogger(__name__)

class WakeWordDetector:
    """Handles wake word detection using Porcupine."""
    
    def __init__(self, config):
        """
        Initialize the wake word detector.
        
        Args:
            config (dict): Configuration for wake word detection
        """
        self.config = config
        self.sensitivity = config.get('sensitivity', 0.5)
        
        # Get model paths
        model_path = config.get('model_path')
        if not model_path:
            # Use default model path
            model_path = os.path.join(Path(__file__).parent.parent.parent, 'models', 'wake')
        
        # Get the wake word model (.ppn file)
        self.keyword_path = config.get('keyword_path')
        if not self.keyword_path or not os.path.exists(self.keyword_path):
            # Search for .ppn files
            ppn_files = list(Path(model_path).glob('*.ppn'))
            if ppn_files:
                self.keyword_path = str(ppn_files[0])
                logger.info(f"Using wake word model: {self.keyword_path}")
            else:
                raise FileNotFoundError("No .ppn wake word model files found")
        
        # Initialize Porcupine
        try:
            self.porcupine = pvporcupine.create(
                keywords=[os.path.basename(self.keyword_path).replace('.ppn', '')],
                sensitivities=[self.sensitivity],
                keyword_paths=[self.keyword_path]
            )
            
            self.sample_rate = self.porcupine.sample_rate
            self.frame_length = self.porcupine.frame_length
            
            logger.info(f"Wake word detector initialized with model: {self.keyword_path}")
            logger.info(f"Wake word sample rate: {self.sample_rate} Hz")
            logger.info(f"Wake word frame length: {self.frame_length} samples")
            
        except Exception as e:
            logger.error(f"Failed to initialize Porcupine: {str(e)}")
            raise
    
    def detect(self, audio_buffer):
        """
        Detect wake word in audio buffer.
        
        Args:
            audio_buffer (numpy.ndarray): Audio buffer containing audio samples
            
        Returns:
            bool: True if wake word detected, False otherwise
        """
        try:
            # Ensure audio is the right format (16-bit signed integers)
            if audio_buffer.dtype != np.int16:
                audio_buffer = (audio_buffer * 32767).astype(np.int16)
            
            # Process audio in frames
            for i in range(0, len(audio_buffer) - self.frame_length + 1, self.frame_length):
                frame = audio_buffer[i:i + self.frame_length]
                result = self.porcupine.process(frame)
                
                if result >= 0:
                    logger.info(f"Wake word detected with confidence: {result}")
                    return True
                    
            return False
            
        except Exception as e:
            logger.error(f"Error in wake word detection: {str(e)}")
            return False
    
    def cleanup(self):
        """Release resources used by Porcupine."""
        try:
            if hasattr(self, 'porcupine') and self.porcupine:
                self.porcupine.delete()
                logger.debug("Porcupine resources released")
        except Exception as e:
            logger.error(f"Error cleaning up Porcupine: {str(e)}")
