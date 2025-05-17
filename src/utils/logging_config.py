"""
Logging Configuration Module

Sets up logging handlers and formatting for the Dia assistant
"""

import os
import logging
import logging.handlers
from pathlib import Path

def setup_logging(config):
    """
    Configure logging based on the provided configuration.
    
    Args:
        config (dict): Logging configuration
    """
    # Get log file path
    log_file = config.get('file', '/var/log/dia/dia_assistant.log')
    log_dir = os.path.dirname(log_file)
    os.makedirs(log_dir, exist_ok=True)
    
    # Get log level
    log_level_str = config.get('level', 'INFO')
    log_level = getattr(logging, log_level_str.upper(), logging.INFO)
    
    # Get max size and backup count for rotated logs
    max_size = config.get('max_size', 10 * 1024 * 1024)  # Default 10 MB
    backup_count = config.get('backup_count', 5)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    
    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=max_size,
        backupCount=backup_count
    )
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    logging.info(f"Logging initialized at level {log_level_str}")
    
    return root_logger

def setup_module_logger(module_name):
    """
    Get a logger for a specific module.
    
    Args:
        module_name (str): Name of the module
        
    Returns:
        logging.Logger: Configured logger
    """
    return logging.getLogger(module_name)
