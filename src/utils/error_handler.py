"""
Error Handler Module

Handles error reporting and recovery
"""

import logging
import traceback
import os
import datetime
import json
from pathlib import Path

logger = logging.getLogger(__name__)

class ErrorTypes:
    """Enum for different error types."""
    AUDIO = "audio_error"
    WAKE_WORD = "wake_word_error"
    ASR = "asr_error"
    LLM = "llm_error"
    TTS = "tts_error"
    SYSTEM = "system_error"
    UNKNOWN = "unknown_error"

def handle_error(error, error_type=None):
    """
    Handle errors gracefully and log them appropriately.
    
    Args:
        error (Exception): The error that occurred
        error_type (str, optional): Type of error from ErrorTypes enum
    """
    if error_type is None:
        error_type = classify_error(error)
    
    # Get stack trace
    stack_trace = traceback.format_exc()
    
    # Log the error
    logger.error(f"{error_type}: {str(error)}", exc_info=True)
    
    # Save error report
    save_error_report(error, error_type, stack_trace)
    
    # Attempt recovery based on error type
    recovery_action = get_recovery_action(error_type)
    
    # Return information about the error for further handling
    return {
        "error_type": error_type,
        "error_message": str(error),
        "recovery_action": recovery_action
    }

def classify_error(error):
    """
    Classify the error type based on the exception.
    
    Args:
        error (Exception): The error to classify
        
    Returns:
        str: Error type from ErrorTypes enum
    """
    error_class = error.__class__.__name__
    
    if "Audio" in error_class or "PyAudio" in error_class or "sound" in error_class.lower():
        return ErrorTypes.AUDIO
    elif "Porcupine" in error_class or "wake" in error_class.lower():
        return ErrorTypes.WAKE_WORD
    elif "Vosk" in error_class or "recognition" in error_class.lower() or "ASR" in error_class:
        return ErrorTypes.ASR
    elif "Llama" in error_class or "LLM" in error_class:
        return ErrorTypes.LLM
    elif "TTS" in error_class or "synthesis" in error_class.lower():
        return ErrorTypes.TTS
    elif any(sys_err in error_class for sys_err in ["OS", "IO", "File", "Memory", "System"]):
        return ErrorTypes.SYSTEM
    else:
        return ErrorTypes.UNKNOWN

def get_recovery_action(error_type):
    """
    Get recovery action based on error type.
    
    Args:
        error_type (str): Type of error from ErrorTypes enum
        
    Returns:
        str: Description of recovery action
    """
    recovery_actions = {
        ErrorTypes.AUDIO: "Restart audio subsystem and check hardware connections",
        ErrorTypes.WAKE_WORD: "Reload wake word model",
        ErrorTypes.ASR: "Restart ASR engine",
        ErrorTypes.LLM: "Fall back to rule-based responses",
        ErrorTypes.TTS: "Fall back to espeak TTS",
        ErrorTypes.SYSTEM: "Check system resources and restart service if needed",
        ErrorTypes.UNKNOWN: "Restart component or full service"
    }
    
    return recovery_actions.get(error_type, "Restart service")

def save_error_report(error, error_type, stack_trace):
    """
    Save detailed error report to file.
    
    Args:
        error (Exception): The error that occurred
        error_type (str): Type of error from ErrorTypes enum
        stack_trace (str): Formatted stack trace
    """
    try:
        # Create error report
        timestamp = datetime.datetime.now().isoformat()
        report = {
            "timestamp": timestamp,
            "error_type": error_type,
            "error_class": error.__class__.__name__,
            "error_message": str(error),
            "stack_trace": stack_trace
        }
        
        # Get log directory
        log_dir = os.environ.get('DIA_LOG_DIR', '/var/log/dia')
        os.makedirs(log_dir, exist_ok=True)
        
        # Save to file
        error_log_path = os.path.join(log_dir, 'error_reports.jsonl')
        with open(error_log_path, 'a') as f:
            f.write(json.dumps(report) + '\n')
            
    except Exception as e:
        logger.error(f"Failed to save error report: {str(e)}")

def check_system_health():
    """
    Check system health and resources.
    
    Returns:
        dict: System health metrics
    """
    import psutil
    
    try:
        # Get system metrics
        cpu_percent = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        health = {
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "disk_percent": disk.percent,
            "memory_available_mb": memory.available / (1024 * 1024),
            "disk_free_gb": disk.free / (1024 * 1024 * 1024)
        }
        
        # Log if resources are running low
        if cpu_percent > 90:
            logger.warning(f"CPU usage is high: {cpu_percent}%")
        if memory.percent > 85:
            logger.warning(f"Memory usage is high: {memory.percent}%")
        if disk.percent > 90:
            logger.warning(f"Disk usage is high: {disk.percent}%")
            
        return health
        
    except Exception as e:
        logger.error(f"Failed to check system health: {str(e)}")
        return {"error": str(e)}
