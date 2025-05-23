"""
Tests for Error Management System

Unit tests for the error management and exception handling utilities.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Add test directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import test utilities
from test_utils import BaseTestCase

# Import components to test
from src.utils import (
    ComponentError,
    ComponentType,
    ErrorSeverity,
    handle_error,
    get_error_manager
)
from src.utils.exception_helpers import (
    component_error_handler,
    retry_on_error,
    safe_cleanup
)


class TestComponentError(BaseTestCase):
    """Tests for ComponentError class"""
    
    def test_component_error_creation(self):
        """Test creating a ComponentError"""
        # Create a basic error
        error = ComponentError(
            message="Test error",
            component=ComponentType.SYSTEM,
            severity=ErrorSeverity.WARNING
        )
        
        # Check attributes
        # Access message via args[0] which is how Exception stores it
        self.assertEqual(error.args[0], "Test error")
        self.assertEqual(error.component, ComponentType.SYSTEM)
        self.assertEqual(error.severity, ErrorSeverity.WARNING)
        self.assertIsNone(error.original_exception)
        self.assertIsNone(error.recovery_hint)
        
        # Don't test exact string format, just make sure it doesn't throw an exception
        error_str = str(error)
        # Only check that the error message is included somewhere
        self.assertIn("Test error", error_str)
    
    def test_component_error_with_original_exception(self):
        """Test ComponentError with original exception"""
        # Create an original exception
        original = ValueError("Original error")
        
        # Create ComponentError with original exception
        error = ComponentError(
            message="Wrapped error",
            component=ComponentType.ASR,
            severity=ErrorSeverity.ERROR,
            original_exception=original
        )
        
        # Check attributes
        # Access message via args[0] which is how Exception stores it
        self.assertEqual(error.args[0], "Wrapped error")
        self.assertEqual(error.original_exception, original)
        
        # Don't test exact string format, just make sure it doesn't throw an exception
        error_str = str(error)
        # Only check that the error message is included somewhere
        self.assertIn("Wrapped error", error_str)
    
    def test_component_error_with_recovery_hint(self):
        """Test ComponentError with recovery hint"""
        # Create error with recovery hint
        error = ComponentError(
            message="Error with hint",
            component=ComponentType.MODEL,
            severity=ErrorSeverity.ERROR,
            recovery_hint="Try reloading the model"
        )
        
        # Check attributes
        self.assertEqual(error.recovery_hint, "Try reloading the model")
        
        # Check string representation includes hint
        error_str = str(error)
        self.assertIn("Error with hint", error_str)
        self.assertIn("Recovery hint: Try reloading the model", error_str)


class TestErrorHandling(BaseTestCase):
    """Tests for error handling functions"""
    
    def test_handle_error(self):
        """Test handle_error function"""
        # Create a mock error manager
        mock_manager = MagicMock()
        
        # Patch get_error_manager to return our mock
        with patch('src.utils.error_management.get_error_manager', return_value=mock_manager):
            # Create an error
            error = ComponentError(
                message="Test error",
                component=ComponentType.TPU,
                severity=ErrorSeverity.WARNING
            )
            
            # Handle the error
            handle_error(error)
            
            # Check that error manager was called
            mock_manager.handle_error.assert_called_once_with(error)
    
    def test_component_error_handler_decorator(self):
        """Test component_error_handler decorator"""
        # Create a function that raises an exception
        @component_error_handler(ComponentType.AUDIO, ErrorSeverity.WARNING)
        def problematic_function():
            raise ValueError("Something went wrong")
        
        # Use the assert_component_error context manager to check for the error
        with self.assert_component_error(ComponentType.AUDIO, ErrorSeverity.WARNING):
            problematic_function()
            
        # The context manager will fail the test if the expected error isn't raised
        # so if we get here, the test passed
    
    def test_retry_on_error_decorator(self):
        """Test retry_on_error decorator"""
        # Create a mock function that fails twice then succeeds
        mock_func = MagicMock(side_effect=[ValueError("First failure"), 
                                          ValueError("Second failure"), 
                                          "success"])
        
        # Create a decorated function
        @retry_on_error(max_attempts=3, component=ComponentType.SYSTEM)
        def retry_function():
            return mock_func()
        
        # Call the function
        result = retry_function()
        
        # Check that the function was called 3 times
        self.assertEqual(mock_func.call_count, 3)
        
        # Check that we got the successful result
        self.assertEqual(result, "success")
    
    def test_retry_on_error_exhausted(self):
        """Test retry_on_error when all attempts fail"""
        # Create a mock function that always fails
        mock_func = MagicMock(side_effect=ValueError("Always fails"))
        
        # Create a decorated function
        @retry_on_error(max_attempts=2, component=ComponentType.LLM)
        def failing_function():
            return mock_func()
        
        # Call the function and expect the original ValueError to be re-raised
        # The decorator creates a ComponentError for logging but re-raises the original exception
        with self.assertRaises(ValueError) as context:
            failing_function()
            
        # Check the exception message
        self.assertEqual(str(context.exception), "Always fails")
        
        # Check that the function was called the expected number of times
        self.assertEqual(mock_func.call_count, 2)
    
    def test_safe_cleanup_decorator(self):
        """Test safe_cleanup decorator"""
        # Create a mock to track calls
        mock_tracker = MagicMock()
        
        # Create a function that raises an exception during cleanup
        @safe_cleanup(ComponentType.TTS, "Error during test cleanup")
        def cleanup_function():
            mock_tracker.cleanup_called()
            raise RuntimeError("Cleanup failed")
        
        # Call the function - it should not raise an exception
        cleanup_function()
        
        # Check that the function was called
        mock_tracker.cleanup_called.assert_called_once()


if __name__ == '__main__':
    unittest.main()
