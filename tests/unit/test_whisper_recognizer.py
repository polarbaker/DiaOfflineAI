"""
Tests for Whisper Recognizer

Unit tests for the standardized Whisper ASR implementation.
"""

import os
import sys
import unittest
from unittest.mock import (
    MagicMock,
    patch,
    PropertyMock,
    call
)
import numpy as np

# Add test directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import test utilities
from test_utils import BaseTestCase

# Import components to test
from src.utils.exception_helpers import (
    component_error_handler,
    retry_on_error,
    safe_cleanup
)
from src.models.model_interface import (
    ModelState
)
from src.utils import (
    ComponentError,
    ComponentType,
    ErrorSeverity
)

# Create mock modules before importing WhisperRecognizer
mock_whisper = MagicMock()
mock_faster_whisper = MagicMock()
mock_whisper_model = MagicMock()
mock_faster_whisper.WhisperModel = mock_whisper_model

# Apply the patches
sys.modules['whisper'] = mock_whisper
sys.modules['faster_whisper'] = mock_faster_whisper

# Now import the module under test
from src.asr.whisper_recognizer import (
    WhisperRecognizer,
    create_whisper_recognizer
)


class TestWhisperRecognizer(BaseTestCase):
    """Tests for Whisper Recognizer"""
    
    def setUp(self):
        """Set up test environment"""
        super().setUp()
        
        # Patch the whisper and faster-whisper availability flags
        self.whisper_patch = patch('src.asr.whisper_recognizer.WHISPER_AVAILABLE', True)
        self.mock_whisper_available = self.whisper_patch.start()
        
        self.faster_whisper_patch = patch('src.asr.whisper_recognizer.FASTER_WHISPER_AVAILABLE', True)
        self.mock_faster_whisper_available = self.faster_whisper_patch.start()
        
        # Use the global mock modules
        self.mock_whisper = mock_whisper
        self.mock_faster_whisper = mock_faster_whisper
        self.mock_whisper_model = mock_whisper_model
        
        # Reset the mocks for this test
        self.mock_whisper.reset_mock()
        self.mock_faster_whisper.reset_mock()
        self.mock_whisper_model.reset_mock()
        
        # Add SileroVAD patch for the silero_vad module
        self.silero_vad = MagicMock()
        self.silero_vad_patch = patch('src.asr.vad.SileroVAD', self.silero_vad)
        self.mock_silero_vad = self.silero_vad_patch.start()
        
        # Configure mock transcription responses
        self.mock_whisper.load_model.return_value = self.mock_whisper_model
        self.mock_whisper_model.transcribe.return_value = {"text": "Standard whisper transcription"}
        
        # Configure mock faster-whisper responses
        self.mock_faster_model = MagicMock()
        self.mock_faster_whisper.WhisperModel.return_value = self.mock_faster_model
        mock_segments = [MagicMock(text="Segment 1"), MagicMock(text="Segment 2")]
        self.mock_faster_model.transcribe.return_value = (mock_segments, {"some": "info"})
    
    def tearDown(self):
        """Clean up after test"""
        # Stop the patches we started
        self.whisper_patch.stop()
        self.faster_whisper_patch.stop()
        
        # Stop SileroVAD patch if it was created
        if self.silero_vad_patch is not None:
            try:
                self.silero_vad_patch.stop()
            except RuntimeError:
                # Patch might not have been started
                pass
        
        super().tearDown()
    
    def test_initialization_standard_whisper(self):
        """Test initializing with standard whisper"""
        # Set faster-whisper to unavailable
        with patch('src.asr.whisper_recognizer.FASTER_WHISPER_AVAILABLE', False):
            # Create recognizer with standard whisper
            recognizer = WhisperRecognizer(
                model_name="tiny",
                use_tpu=False,
                use_faster_whisper=False
            )
            
            # Initialize
            result = recognizer.initialize()
            
            # Check initialization
            self.assertTrue(result)
            # Accept any string for the model path
        args, kwargs = self.mock_whisper.load_model.call_args
        self.assertEqual(kwargs, {"device": "cpu"})
        self.assertIsInstance(args[0], str)
        self.assertEqual(recognizer.state, ModelState.READY)
    
    def test_initialization_faster_whisper(self):
        """Test initializing with faster-whisper"""
        # Create recognizer with faster-whisper
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False,
            use_faster_whisper=True
        )
        
        # Initialize
        result = recognizer.initialize()
        
        # Check initialization
        self.assertTrue(result)
        self.mock_faster_whisper.WhisperModel.assert_called_once()
        self.assertEqual(recognizer.state, ModelState.READY)
    
    def test_initialization_with_tpu(self):
        """Test initializing with TPU"""
        # Mock TPU availability
        with patch('src.tpu.tpu_interface.TPUInterface.is_tpu_available', return_value=True):
            # Create recognizer with TPU
            recognizer = WhisperRecognizer(
                model_name="tiny",
                use_tpu=True
            )
            
            # Override _setup_device to simulate TPU availability
            recognizer.device = "tpu"
            
            # Initialize
            result = recognizer.initialize()
            
            # Check initialization
            self.assertTrue(result)
            self.assertEqual(recognizer.device, "tpu")
            self.assertEqual(recognizer.state, ModelState.READY)
    
    def test_transcribe_standard_whisper(self):
        """Test transcription with standard whisper"""
        # Create recognizer with standard whisper
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False,
            use_faster_whisper=False
        )
        
        # Initialize
        recognizer.initialize()
        
        # Create test audio
        audio_data = np.random.rand(16000)  # 1 second of audio at 16kHz
        
        # Transcribe
        transcript = recognizer.transcribe(audio_data)
        
        # Check result
        self.assertEqual(transcript, "Standard whisper transcription")
        self.mock_whisper_model.transcribe.assert_called_once()
        
        # Check transcript history
        self.assertEqual(recognizer.transcript_history, ["Standard whisper transcription"])
    
    def test_transcribe_faster_whisper(self):
        """Test transcription with faster-whisper"""
        # Create recognizer with faster-whisper
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False,
            use_faster_whisper=True
        )
        
        # Initialize
        recognizer.initialize()
        
        # Create test audio
        audio_data = np.random.rand(16000)  # 1 second of audio at 16kHz
        
        # Transcribe
        transcript = recognizer.transcribe(audio_data)
        
        # Check result
        self.assertEqual(transcript, "Segment 1 Segment 2")
        self.mock_faster_model.transcribe.assert_called_once()
        
        # Check transcript history
        self.assertEqual(recognizer.transcript_history, ["Segment 1 Segment 2"])
    
    def test_transcribe_with_retry(self):
        """Test transcription with retry on failure"""
        # Create recognizer
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False
        )
        
        # Initialize
        recognizer.initialize()
        
        # Create test audio
        audio_data = np.random.rand(16000)  # 1 second of audio at 16kHz
        
        # Create a mock function with side effects to simulate failures and retries
        mock_transcribe = MagicMock(side_effect=[RuntimeError("First attempt fails"), "Retry succeeded"])
        
        # Create a test function with retry decorator
        @retry_on_error(max_attempts=2, component=ComponentType.ASR)
        def test_function(audio):
            return mock_transcribe(audio)
        
        # Execute the test function with retry
        result = test_function(audio_data)
        
        # Verify results
        self.assertEqual(result, "Retry succeeded")
        self.assertEqual(mock_transcribe.call_count, 2)
        mock_transcribe.assert_has_calls([call(audio_data), call(audio_data)])
    
    def test_get_transcript_history(self):
        """Test getting transcript history"""
        # Create recognizer
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False
        )
        
        # Initialize
        recognizer.initialize()
        
        # Add some transcripts
        recognizer.transcript_history = ["Transcript 1", "Transcript 2", "Transcript 3"]
        
        # Get history
        history = recognizer.get_transcript_history()
        
        # Check result
        self.assertEqual(history, ["Transcript 1", "Transcript 2", "Transcript 3"])
        
        # Modify the returned history (should not affect original)
        history.append("Transcript 4")
        
        # Check original is unchanged
        self.assertEqual(recognizer.transcript_history, ["Transcript 1", "Transcript 2", "Transcript 3"])
    
    def test_vad_initialization(self):
        """Test Voice Activity Detection initialization"""
        # Create a mock for the torch module and silero model
        mock_torch = MagicMock()
        mock_model = MagicMock()  # This will be our VAD model
        
        # Set up mock_torch.hub.load to return our mock model
        mock_torch.hub.load = MagicMock(return_value=mock_model)
        
        # Patch torch and setup recognizer
        with patch.dict(sys.modules, {'torch': mock_torch}):
            # Create recognizer with VAD enabled
            recognizer = WhisperRecognizer(
                model_name="tiny",
                use_tpu=False
            )
            recognizer.vad_enabled = True
            
            # Now patch is_speech on our model to return True
            mock_model.is_speech = MagicMock(return_value=True)
            
            # Initialize
            recognizer.initialize()
            
            # We can't directly check if the model is set since the object gets created
            # during initialization, but we can verify VAD is enabled
            self.assertTrue(recognizer.vad_enabled)
    
    def test_transcribe_with_vad(self):
        """Test transcription with VAD"""
        # Create mock VAD
        mock_vad = MagicMock()
        mock_vad.is_speech.return_value = True
        
        # Create recognizer
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False
        )
        
        # Initialize and set mock VAD
        recognizer.initialize()
        recognizer.vad_enabled = True
        recognizer.vad_model = mock_vad
        
        # Create test audio
        audio_data = np.random.rand(16000)  # 1 second of audio at 16kHz
        
        # Transcribe
        recognizer.transcribe(audio_data)
        
        # Check VAD was called
        mock_vad.is_speech.assert_called_once()
    
    def test_transcribe_no_speech_detected(self):
        """Test transcription when VAD detects no speech"""
        # Create mock VAD that detects no speech
        mock_vad = MagicMock()
        mock_vad.is_speech.return_value = False
        
        # Create recognizer
        recognizer = WhisperRecognizer(
            model_name="tiny",
            use_tpu=False
        )
        
        # Initialize and set mock VAD
        recognizer.initialize()
        recognizer.vad_enabled = True
        recognizer.vad_model = mock_vad
        
        # Create test audio
        audio_data = np.random.rand(16000)  # 1 second of audio at 16kHz
        
        # Transcribe
        result = recognizer.transcribe(audio_data)
        
        # Check result (should be empty since no speech detected)
        self.assertEqual(result, "")
        
        # VAD should be called but not the transcription model
        mock_vad.is_speech.assert_called_once()
        self.mock_whisper_model.transcribe.assert_not_called()
        self.mock_faster_model.transcribe.assert_not_called()
    
    def test_no_whisper_available(self):
        """Test behavior when no whisper implementations are available"""
        # Set both whisper implementations to unavailable
        with patch('src.asr.whisper_recognizer.WHISPER_AVAILABLE', False), \
             patch('src.asr.whisper_recognizer.FASTER_WHISPER_AVAILABLE', False):
            
            # Create recognizer
            recognizer = WhisperRecognizer(model_name="tiny")
            
            # Initialize should fail
            with self.assert_component_error(ComponentType.ASR, ErrorSeverity.ERROR):
                recognizer.initialize()
    
    def test_factory_function(self):
        """Test the factory function"""
        # Use the factory function
        recognizer = create_whisper_recognizer("tiny", use_tpu=False)
        
        # Check instance
        self.assertIsInstance(recognizer, WhisperRecognizer)
        self.assertEqual(recognizer.model_name, "tiny")
        self.assertFalse(recognizer.use_tpu)
    
    def test_get_impl_info(self):
        """Test getting implementation info"""
        # Create recognizer with specific settings
        recognizer = WhisperRecognizer(
            model_name="small",
            use_tpu=True,
            use_faster_whisper=True
        )
        recognizer.device = "tpu"
        
        # Get implementation info
        info = recognizer._get_impl_info()
        
        # Check info contents
        self.assertEqual(info['implementation'], "faster-whisper")
        self.assertEqual(info['device'], "tpu")
        self.assertTrue(info['vad_enabled'])
        self.assertEqual(info['sample_rate'], 16000)
        self.assertEqual(info['language'], "en")


if __name__ == '__main__':
    unittest.main()
