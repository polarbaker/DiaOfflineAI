"""
Configuration Loader Module

Handles loading and validation of configuration files
"""

import os
import logging
import yaml
from pathlib import Path

logger = logging.getLogger(__name__)

def load_config(config_path):
    """
    Load configuration from YAML file.
    
    Args:
        config_path (str): Path to configuration file
        
    Returns:
        dict: Loaded configuration
    """
    try:
        if not os.path.exists(config_path):
            logger.warning(f"Configuration file not found: {config_path}")
            return get_default_config()
        
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        logger.info(f"Loaded configuration from {config_path}")
        
        # Merge with defaults for any missing keys
        default_config = get_default_config()
        merged_config = deep_merge(default_config, config)
        
        return merged_config
        
    except Exception as e:
        logger.error(f"Error loading configuration: {str(e)}")
        logger.warning("Using default configuration")
        return get_default_config()

def get_default_config():
    """
    Get default configuration.
    
    Returns:
        dict: Default configuration
    """
    config = {
        'audio': {
            'sample_rate': 16000,
            'channels': 1,
            'chunk_size': 1024,
            'buffer_max_length': 80000,  # 5 seconds at 16kHz
            'input_device_name': 'ReSpeaker 4 Mic Array',
            'output_device_name': 'HiFiBerry DAC+'
        },
        'wake_word': {
            'sensitivity': 0.5,
            'model_path': None,  # Use default path
            'keyword_path': None  # Auto-detect
        },
        'asr': {
            'sample_rate': 16000,
            'model_path': None,  # Use default path
            'model_name': 'vosk-model-small-en-us-0.15'
        },
        'response_generator': {
            'engine_type': 'rules',  # 'llm' or 'rules'
            'model_path': None,  # Use default path
            'model_name': None,  # Auto-detect
            'context_size': 2048,
            'n_threads': 4,
            'max_tokens': 100,
            'temperature': 0.7,
            'use_mlock': True,
            'system_prompt': (
                "You are Dia, a helpful voice assistant running on a Raspberry Pi. "
                "Provide concise, accurate responses. You run completely offline."
            ),
            'rules_file': None  # Use default rules
        },
        'tts': {
            'sample_rate': 22050,
            'type': 'dia-expressive',
            'model_path': None,  # Use default path
            'use_gpu': False
        },
        'rag': {
            'enabled': False,
            'database_path': None,  # Use default path
            'embedding_model': 'all-MiniLM-L6-v2'
        },
        'logging': {
            'level': 'INFO',
            'file': '/var/log/dia/dia_assistant.log',
            'max_size': 10485760,  # 10 MB
            'backup_count': 5
        }
    }
    
    return config

def deep_merge(dict1, dict2):
    """
    Deep merge two dictionaries.
    Values from dict2 take precedence over dict1.
    
    Args:
        dict1 (dict): Base dictionary
        dict2 (dict): Dictionary to merge on top
        
    Returns:
        dict: Merged dictionary
    """
    result = dict1.copy()
    
    for key, value in dict2.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    
    return result

def save_config(config, config_path):
    """
    Save configuration to YAML file.
    
    Args:
        config (dict): Configuration to save
        config_path (str): Path to save configuration to
        
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Ensure directory exists
        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        
        with open(config_path, 'w') as f:
            yaml.dump(config, f, default_flow_style=False)
        
        logger.info(f"Saved configuration to {config_path}")
        return True
        
    except Exception as e:
        logger.error(f"Error saving configuration: {str(e)}")
        return False
