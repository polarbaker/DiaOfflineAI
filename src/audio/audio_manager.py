"""
Audio Manager Module

Handles audio I/O for the Dia assistant using PyAudio with
ALSA configurations for ReSpeaker 4-Mic Array and HiFiBerry DAC+
"""

import os
import logging
import tempfile
import wave
import numpy as np
from pathlib import Path
import time
import threading

# Import will fail until PyAudio is installed, but that's expected during setup
try:
    import pyaudio
except ImportError:
    logging.warning("PyAudio not found. Install with: pip install pyaudio")

logger = logging.getLogger(__name__)

class AudioManager:
    """Handles audio input and output operations."""
    
    def __init__(self, config):
        """
        Initialize the audio manager.
        
        Args:
            config (dict): Configuration for audio I/O
        """
        self.config = config
        
        # Audio configuration
        self.sample_rate = config.get('sample_rate', 16000)
        self.channels = config.get('channels', 1)
        self.chunk_size = config.get('chunk_size', 1024)
        self.format = pyaudio.paInt16
        
        # Device configuration
        self.input_device_name = config.get('input_device_name', 'ReSpeaker 4 Mic Array')
        self.output_device_name = config.get('output_device_name', 'HiFiBerry DAC+')
        self.input_device_index = None
        self.output_device_index = None
        
        # Buffer for continuous listening
        self.audio_buffer = np.array([], dtype=np.int16)
        self.buffer_max_length = config.get('buffer_max_length', int(self.sample_rate * 5))  # 5 seconds
        
        # Lock for thread-safe buffer access
        self.buffer_lock = threading.Lock()
        
        # Initialize PyAudio
        try:
            self.p = pyaudio.PyAudio()
            
            # Find input and output devices
            self._find_devices()
            
            # Start listening
            self._start_listening()
            
            logger.info("Audio manager initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize audio: {str(e)}")
            raise
    
    def _find_devices(self):
        """Find the input and output device indices."""
        for i in range(self.p.get_device_count()):
            device_info = self.p.get_device_info_by_index(i)
            device_name = device_info.get('name', '')
            
            logger.debug(f"Found audio device {i}: {device_name}")
            
            # Find the ReSpeaker input device
            if self.input_device_name in device_name and device_info.get('maxInputChannels', 0) > 0:
                self.input_device_index = i
                logger.info(f"Selected input device {i}: {device_name}")
            
            # Find the HiFiBerry output device
            if self.output_device_name in device_name and device_info.get('maxOutputChannels', 0) > 0:
                self.output_device_index = i
                logger.info(f"Selected output device {i}: {device_name}")
        
        # Use default devices if specific ones not found
        if self.input_device_index is None:
            logger.warning(f"Input device '{self.input_device_name}' not found, using default")
            self.input_device_index = self.p.get_default_input_device_info().get('index')
            
        if self.output_device_index is None:
            logger.warning(f"Output device '{self.output_device_name}' not found, using default")
            self.output_device_index = self.p.get_default_output_device_info().get('index')
    
    def _audio_callback(self, in_data, frame_count, time_info, status):
        """
        Callback function for PyAudio stream.
        Adds incoming audio to the buffer.
        """
        if status:
            logger.warning(f"Audio callback status: {status}")
        
        # Convert data to numpy array
        data = np.frombuffer(in_data, dtype=np.int16)
        
        # Add to buffer with thread safety
        with self.buffer_lock:
            self.audio_buffer = np.append(self.audio_buffer, data)
            
            # Trim buffer to max length
            if len(self.audio_buffer) > self.buffer_max_length:
                self.audio_buffer = self.audio_buffer[-self.buffer_max_length:]
        
        return (None, pyaudio.paContinue)
    
    def _start_listening(self):
        """Start the audio stream for continuous listening."""
        try:
            self.stream = self.p.open(
                format=self.format,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                output=False,
                input_device_index=self.input_device_index,
                frames_per_buffer=self.chunk_size,
                stream_callback=self._audio_callback
            )
            
            logger.info("Started continuous audio listening")
            
        except Exception as e:
            logger.error(f"Failed to start audio stream: {str(e)}")
            raise
    
    def listen(self):
        """
        Return the current audio buffer.
        
        Returns:
            numpy.ndarray: Audio buffer
        """
        with self.buffer_lock:
            # Return a copy to avoid modification during processing
            return self.audio_buffer.copy()
    
    def record_query(self, max_duration=5):
        """
        Record audio for a query.
        
        Args:
            max_duration (float): Maximum recording duration in seconds
            
        Returns:
            numpy.ndarray: Recorded audio data
        """
        logger.debug(f"Recording query (max {max_duration}s)")
        
        # Stop the callback stream temporarily
        self.stream.stop_stream()
        
        try:
            # Create a new stream for direct recording
            record_stream = self.p.open(
                format=self.format,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                output=False,
                input_device_index=self.input_device_index,
                frames_per_buffer=self.chunk_size
            )
            
            # Calculate frames to record
            frames = []
            max_frames = int(self.sample_rate / self.chunk_size * max_duration)
            
            # Record data
            for i in range(max_frames):
                data = record_stream.read(self.chunk_size, exception_on_overflow=False)
                frames.append(data)
                
                # TODO: Add voice activity detection to stop recording when silence is detected
            
            # Close recording stream
            record_stream.stop_stream()
            record_stream.close()
            
            # Restart the callback stream
            self.stream.start_stream()
            
            # Convert frames to numpy array
            result = np.frombuffer(b''.join(frames), dtype=np.int16)
            logger.debug(f"Recorded {len(result) / self.sample_rate:.2f}s of audio")
            
            return result
            
        except Exception as e:
            logger.error(f"Error in recording: {str(e)}")
            # Restart the callback stream
            self.stream.start_stream()
            return np.array([], dtype=np.int16)
    
    def play(self, audio_data):
        """
        Play audio data over the output device.
        
        Args:
            audio_data: Audio data (numpy array, bytes, or file path)
        """
        try:
            # Handle different input types
            if isinstance(audio_data, np.ndarray):
                # Convert numpy array to bytes
                if audio_data.dtype != np.int16:
                    audio_data = (audio_data * 32767).astype(np.int16)
                audio_bytes = audio_data.tobytes()
            elif isinstance(audio_data, str) and os.path.exists(audio_data):
                # Read from WAV file
                with wave.open(audio_data, 'rb') as wf:
                    audio_bytes = wf.readframes(wf.getnframes())
            else:
                # Assume it's already bytes
                audio_bytes = audio_data
            
            # Open output stream
            output_stream = self.p.open(
                format=self.format,
                channels=self.channels,
                rate=self.sample_rate,
                output=True,
                output_device_index=self.output_device_index,
                frames_per_buffer=self.chunk_size
            )
            
            # Play audio in chunks
            chunk_size_bytes = self.chunk_size * 2  # 2 bytes per sample for paInt16
            for i in range(0, len(audio_bytes), chunk_size_bytes):
                chunk = audio_bytes[i:i + chunk_size_bytes]
                output_stream.write(chunk)
            
            # Close stream
            output_stream.stop_stream()
            output_stream.close()
            
            logger.debug("Finished playing audio")
            
        except Exception as e:
            logger.error(f"Error playing audio: {str(e)}")
    
    def play_error_sound(self):
        """Play a predefined error sound."""
        error_sound_path = self.config.get('error_sound_path')
        if error_sound_path and os.path.exists(error_sound_path):
            logger.debug(f"Playing error sound from {error_sound_path}")
            self.play(error_sound_path)
        else:
            # Generate a simple error tone
            freq = 440  # A4 note
            duration = 0.3
            t = np.linspace(0, duration, int(self.sample_rate * duration), False)
            error_tone = (0.5 * np.sin(2 * np.pi * freq * t)).astype(np.float32)
            
            # Play three short beeps
            for _ in range(3):
                self.play(error_tone)
                time.sleep(0.1)
    
    def cleanup(self):
        """Release audio resources."""
        try:
            if hasattr(self, 'stream') and self.stream:
                self.stream.stop_stream()
                self.stream.close()
                
            if hasattr(self, 'p') and self.p:
                self.p.terminate()
                
            logger.debug("Audio resources released")
        except Exception as e:
            logger.error(f"Error cleaning up audio: {str(e)}")
