"""
Speech Synthesis Module

Uses Dia-TTS ("dia-expressive") for custom voice synthesis
"""

import os
import logging
import numpy as np
import tempfile
from pathlib import Path
import time

logger = logging.getLogger(__name__)

class SpeechSynthesizer:
    """Handles text-to-speech synthesis using a custom TTS engine."""
    
    def __init__(self, config):
        """
        Initialize the speech synthesizer.
        
        Args:
            config (dict): Configuration for TTS
        """
        self.config = config
        self.sample_rate = config.get('sample_rate', 22050)
        self.tts_type = config.get('type', 'dia-expressive')
        
        # Get model paths
        model_path = config.get('model_path')
        if not model_path:
            # Use default model path
            model_path = os.path.join(Path(__file__).parent.parent.parent, 'models', 'tts')
        
        # Load the TTS system
        self.synthesizer = None
        
        try:
            if self.tts_type.lower() == 'dia-expressive':
                # Import will fail until TTS is installed, but that's expected during setup
                try:
                    from TTS.api import TTS as TTSEngine
                    self.tts_engine = 'tts'
                    
                    # Check for custom models
                    if os.path.exists(os.path.join(model_path, 'tts_model.pth')):
                        # Custom local model
                        model_file = os.path.join(model_path, 'tts_model.pth')
                        config_file = os.path.join(model_path, 'tts_config.json')
                        
                        if not os.path.exists(config_file):
                            logger.warning(f"TTS config file not found: {config_file}")
                        
                        logger.info(f"Loading custom TTS model from {model_file}")
                        self.synthesizer = TTSEngine(
                            model_path=model_file,
                            config_path=config_file,
                            progress_bar=False,
                            gpu=config.get('use_gpu', False)
                        )
                    else:
                        # Use a pre-trained model
                        logger.info("Loading pre-trained TTS model")
                        self.synthesizer = TTSEngine(
                            model_name="tts_models/en/vctk/vits",
                            progress_bar=False,
                            gpu=config.get('use_gpu', False)
                        )
                    
                    logger.info(f"TTS engine initialized with {self.tts_engine} backend")
                    
                except ImportError:
                    logger.warning("TTS library not found. Install with: pip install TTS")
                    self._fallback_to_espeak()
            
            elif self.tts_type.lower() == 'espeak':
                self._fallback_to_espeak()
                
            else:
                logger.warning(f"Unknown TTS type: {self.tts_type}, falling back to espeak")
                self._fallback_to_espeak()
                
        except Exception as e:
            logger.error(f"Failed to initialize TTS: {str(e)}")
            self._fallback_to_espeak()
    
    def _fallback_to_espeak(self):
        """Fall back to espeak as TTS engine."""
        try:
            # We'll use espeak as a fallback
            import subprocess
            self.tts_engine = 'espeak'
            logger.info("Using espeak as fallback TTS engine")
            
            # Test if espeak is available
            try:
                subprocess.run(["espeak", "--version"], capture_output=True, check=True)
            except (subprocess.SubprocessError, FileNotFoundError):
                logger.error("espeak not found, TTS functionality will be limited")
                self.tts_engine = 'none'
        except Exception as e:
            logger.error(f"Failed to initialize fallback TTS: {str(e)}")
            self.tts_engine = 'none'
    
    def synthesize(self, text):
        """
        Synthesize speech from text.
        
        Args:
            text (str): Text to synthesize
            
        Returns:
            numpy.ndarray or str: Audio data or path to audio file
        """
        if not text:
            logger.warning("Empty text provided for synthesis")
            return np.array([], dtype=np.float32)
        
        try:
            if self.tts_engine == 'tts' and self.synthesizer:
                logger.debug(f"Synthesizing: {text}")
                
                # Using TTS library
                audio_array = self.synthesizer.tts(text)
                return audio_array
                
            elif self.tts_engine == 'espeak':
                # Using espeak
                try:
                    logger.debug(f"Synthesizing with espeak: {text}")
                    
                    # Create temp file for output
                    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
                        temp_path = temp_file.name
                    
                    # Run espeak
                    import subprocess
                    subprocess.run([
                        "espeak", 
                        "-w", temp_path,  # Output to WAV file
                        "-s", "150",      # Speed
                        "-p", "50",       # Pitch
                        "-a", "100",      # Amplitude
                        text
                    ], check=True)
                    
                    # Return path to audio file
                    return temp_path
                    
                except Exception as e:
                    logger.error(f"Error with espeak synthesis: {str(e)}")
                    return np.array([], dtype=np.float32)
            else:
                logger.error("No TTS engine available")
                return np.array([], dtype=np.float32)
                
        except Exception as e:
            logger.error(f"Error in speech synthesis: {str(e)}")
            return np.array([], dtype=np.float32)
    
    def cleanup(self):
        """Release resources used by the speech synthesizer."""
        # Most TTS engines don't need special cleanup
        logger.debug("TTS resources released")
        
        # Remove any temporary files
        try:
            temp_dir = tempfile.gettempdir()
            for file in os.listdir(temp_dir):
                if file.startswith('tts_') and file.endswith('.wav'):
                    try:
                        os.remove(os.path.join(temp_dir, file))
                    except:
                        pass
        except:
            pass
