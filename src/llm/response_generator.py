"""
Response Generator Module

Handles response generation through an LLM or rule-based engine
"""

import os
import logging
import json
import re
from pathlib import Path
import time

logger = logging.getLogger(__name__)

class ResponseGenerator:
    """
    Generates responses to user queries using either:
    1. A local LLM (llama.cpp)
    2. A rule-based engine
    """
    
    def __init__(self, config):
        """
        Initialize the response generator.
        
        Args:
            config (dict): Configuration for response generation
        """
        self.config = config
        self.engine_type = config.get('engine_type', 'rules')  # 'llm' or 'rules'
        
        # Get model path for LLM
        if self.engine_type == 'llm':
            model_path = config.get('model_path')
            if not model_path:
                # Use default model path
                model_path = os.path.join(Path(__file__).parent.parent.parent, 'models', 'llm')
                
                # If specific model name provided
                model_name = config.get('model_name')
                if model_name:
                    model_path = os.path.join(model_path, model_name)
            
            # Initialize LLM
            self._init_llm(model_path)
        else:
            # Initialize rule-based engine
            self._init_rules()
            
        logger.info(f"Response generator initialized with {self.engine_type} engine")
    
    def _init_llm(self, model_path):
        """
        Initialize the LLM engine.
        
        Args:
            model_path (str): Path to the LLM model
        """
        # Try to import llama-cpp-python
        try:
            from llama_cpp import Llama
            
            # Check if model file exists
            model_files = list(Path(model_path).glob("*.gguf"))
            if not model_files:
                logger.error(f"No GGUF model files found in {model_path}")
                logger.warning("Falling back to rule-based engine")
                self.engine_type = 'rules'
                self._init_rules()
                return
            
            # Use the first model file found
            model_file = str(model_files[0])
            logger.info(f"Loading LLM model from {model_file}")
            
            # Initialize Llama with the model
            try:
                # Get context size from config
                context_size = self.config.get('context_size', 2048)
                
                # Initialize Llama with appropriate parameters
                self.llm = Llama(
                    model_path=model_file,
                    n_ctx=context_size,
                    n_threads=self.config.get('n_threads', 4),
                    use_mlock=self.config.get('use_mlock', True)
                )
                
                logger.info(f"LLM initialized with context size {context_size}")
                
                # Set system prompt
                self.system_prompt = self.config.get('system_prompt', 
                    "You are Dia, a helpful voice assistant running on a Raspberry Pi. "
                    "Provide concise, accurate responses. You run completely offline."
                )
                
                logger.info("LLM engine initialized successfully")
                
            except Exception as e:
                logger.error(f"Failed to initialize Llama: {str(e)}")
                logger.warning("Falling back to rule-based engine")
                self.engine_type = 'rules'
                self._init_rules()
        
        except ImportError:
            logger.warning("llama-cpp-python not found. Install with: pip install llama-cpp-python")
            logger.warning("Falling back to rule-based engine")
            self.engine_type = 'rules'
            self._init_rules()
    
    def _init_rules(self):
        """Initialize the rule-based engine."""
        # Load rules from file if available
        rules_file = self.config.get('rules_file')
        self.rules = {}
        
        if rules_file and os.path.exists(rules_file):
            try:
                with open(rules_file, 'r') as f:
                    self.rules = json.load(f)
                logger.info(f"Loaded {len(self.rules)} rules from {rules_file}")
            except Exception as e:
                logger.error(f"Failed to load rules file: {str(e)}")
                self._setup_default_rules()
        else:
            logger.info("No rules file specified, using default rules")
            self._setup_default_rules()
    
    def _setup_default_rules(self):
        """Set up default rules for the rule-based engine."""
        self.rules = {
            "greeting": {
                "patterns": ["hello", "hi", "hey", "greetings"],
                "responses": ["Hello there!", "Hi! How can I help?", "Hey! I'm Dia. What can I do for you?"]
            },
            "farewell": {
                "patterns": ["goodbye", "bye", "see you", "later"],
                "responses": ["Goodbye!", "See you later!", "Bye for now!"]
            },
            "gratitude": {
                "patterns": ["thank you", "thanks"],
                "responses": ["You're welcome!", "Happy to help!", "No problem!"]
            },
            "time": {
                "patterns": ["what time", "current time", "time now"],
                "responses": ["function:get_time"]
            },
            "date": {
                "patterns": ["what date", "current date", "date today"],
                "responses": ["function:get_date"]
            },
            "weather": {
                "patterns": ["weather", "temperature", "forecast"],
                "responses": ["I'm sorry, I can't check the weather since I'm running completely offline."]
            },
            "capabilities": {
                "patterns": ["what can you do", "your abilities", "help me", "your features"],
                "responses": [
                    "I can answer simple questions, tell you the time and date, and handle basic conversations. "
                    "I run completely offline on your Raspberry Pi!"
                ]
            },
            "identity": {
                "patterns": ["who are you", "your name", "what are you"],
                "responses": [
                    "I'm Dia, your offline voice assistant running on a Raspberry Pi. "
                    "I process everything locally without sending data to the cloud."
                ]
            },
            "fallback": {
                "patterns": [],
                "responses": [
                    "I'm not sure how to respond to that.", 
                    "I don't have an answer for that right now.",
                    "I'm still learning and don't know how to answer that."
                ]
            }
        }
        
        logger.info("Default rules initialized")
    
    def _get_time(self):
        """Get the current time."""
        import datetime
        now = datetime.datetime.now()
        return f"The current time is {now.strftime('%I:%M %p')}."
    
    def _get_date(self):
        """Get the current date."""
        import datetime
        now = datetime.datetime.now()
        return f"Today is {now.strftime('%A, %B %d, %Y')}."
    
    def _execute_function(self, function_name):
        """
        Execute a function based on its name.
        
        Args:
            function_name (str): Name of the function to execute
            
        Returns:
            str: Result of the function
        """
        function_map = {
            "get_time": self._get_time,
            "get_date": self._get_date
        }
        
        if function_name in function_map:
            return function_map[function_name]()
        else:
            logger.warning(f"Unknown function: {function_name}")
            return "I'm not sure how to do that right now."
    
    def _generate_with_llm(self, query):
        """
        Generate a response using the LLM.
        
        Args:
            query (str): User query
            
        Returns:
            str: Generated response
        """
        try:
            # Set up prompt
            prompt = f"{self.system_prompt}\n\nUser: {query}\nDia:"
            
            # Generate response
            max_tokens = self.config.get('max_tokens', 100)
            temperature = self.config.get('temperature', 0.7)
            
            response = self.llm(
                prompt, 
                max_tokens=max_tokens,
                stop=["User:", "\n"],
                temperature=temperature
            )
            
            # Extract text from response
            generated_text = response["choices"][0]["text"].strip()
            logger.debug(f"LLM generated: {generated_text}")
            
            return generated_text
            
        except Exception as e:
            logger.error(f"Error in LLM generation: {str(e)}")
            return "I'm having trouble thinking right now."
    
    def _generate_with_rules(self, query):
        """
        Generate a response using rule-based matching.
        
        Args:
            query (str): User query
            
        Returns:
            str: Generated response
        """
        import random
        
        # Normalize query
        query_lower = query.lower()
        
        # Check each rule
        for rule_name, rule in self.rules.items():
            patterns = rule["patterns"]
            
            # Skip fallback rule during pattern matching
            if rule_name == "fallback" and not patterns:
                continue
                
            # Check if any pattern matches
            for pattern in patterns:
                if pattern.lower() in query_lower:
                    # Get a random response
                    responses = rule["responses"]
                    response = random.choice(responses)
                    
                    # Check if it's a function call
                    if response.startswith("function:"):
                        function_name = response.split(":")[1]
                        return self._execute_function(function_name)
                    else:
                        return response
        
        # If no rule matched, use fallback
        return random.choice(self.rules["fallback"]["responses"])
    
    def generate_response(self, query):
        """
        Generate a response to the user query.
        
        Args:
            query (str): User query
            
        Returns:
            str: Generated response
        """
        if not query:
            return "I didn't catch that. Could you please repeat?"
        
        # Log the query
        logger.info(f"Generating response for: '{query}'")
        
        # Generate response based on engine type
        if self.engine_type == 'llm' and hasattr(self, 'llm'):
            return self._generate_with_llm(query)
        else:
            return self._generate_with_rules(query)
    
    def cleanup(self):
        """Release resources used by the response generator."""
        # Clean up LLM resources if needed
        if self.engine_type == 'llm' and hasattr(self, 'llm'):
            logger.debug("LLM resources released")
        
        logger.debug("Response generator resources released")
