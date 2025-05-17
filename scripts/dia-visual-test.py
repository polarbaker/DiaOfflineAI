#!/usr/bin/env python3
"""
Dia Visual Speech Test
A simple GUI tool to visualize speech-to-text and responses from Dia
"""

import os
import sys
import json
import time
import threading
import tkinter as tk
from tkinter import font, ttk, scrolledtext
import subprocess
import wave
import pyaudio
import tempfile
from datetime import datetime
try:
    import vosk
    VOSK_AVAILABLE = True
except ImportError:
    VOSK_AVAILABLE = False

# Configuration
CONFIG = {
    "model_path": "/opt/dia/models/vosk",
    "sample_rate": 16000,
    "device_index": None,  # None = default device
    "wake_word": "hey dia",
    "buffer_size": 8000,
}

class SpeechVisualizer(tk.Tk):
    def __init__(self):
        super().__init__()
        
        self.title("Dia Visual Speech Test")
        self.geometry("800x600")
        self.configure(bg="#f0f0f0")
        
        # Initialize variables
        self.recording = False
        self.speech_thread = None
        self.audio_stream = None
        self.p = None
        self.rec = None
        self.model = None
        self.wake_word_detected = False
        self.wake_word_time = None
        
        # Create UI elements
        self._create_widgets()
        
        # Initialize audio
        self._initialize_audio()
        
    def _create_widgets(self):
        # Main frame
        main_frame = tk.Frame(self, bg="#f0f0f0")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Title
        title_font = font.Font(family="Arial", size=24, weight="bold")
        title = tk.Label(main_frame, text="Dia Visual Speech Test", font=title_font, bg="#f0f0f0", fg="#e91e63")
        title.pack(pady=10)
        
        # Subtitle
        subtitle_font = font.Font(family="Arial", size=12)
        subtitle = tk.Label(
            main_frame, 
            text="See what Dia hears and how it responds", 
            font=subtitle_font, 
            bg="#f0f0f0"
        )
        subtitle.pack(pady=5)
        
        # Status frame
        status_frame = tk.Frame(main_frame, bg="#f0f0f0")
        status_frame.pack(fill=tk.X, pady=10)
        
        self.status_var = tk.StringVar(value="Ready")
        self.status_label = tk.Label(
            status_frame, 
            textvariable=self.status_var,
            font=font.Font(family="Arial", size=12, weight="bold"),
            fg="#4caf50",
            bg="#f0f0f0"
        )
        self.status_label.pack(side=tk.LEFT, padx=10)
        
        # Device selection
        device_frame = tk.Frame(main_frame, bg="#f0f0f0")
        device_frame.pack(fill=tk.X, pady=10)
        
        tk.Label(device_frame, text="Audio Device:", bg="#f0f0f0").pack(side=tk.LEFT, padx=5)
        
        self.device_var = tk.StringVar()
        self.device_menu = ttk.Combobox(device_frame, textvariable=self.device_var, width=40)
        self.device_menu.pack(side=tk.LEFT, padx=5)
        
        refresh_btn = tk.Button(device_frame, text="Refresh", command=self._refresh_devices)
        refresh_btn.pack(side=tk.LEFT, padx=5)
        
        # Speech text display area
        speech_frame = tk.LabelFrame(main_frame, text="What Dia Hears", bg="#f0f0f0")
        speech_frame.pack(fill=tk.BOTH, expand=True, pady=10)
        
        self.speech_text = scrolledtext.ScrolledText(
            speech_frame,
            wrap=tk.WORD,
            font=font.Font(family="Arial", size=12),
            height=8
        )
        self.speech_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Response display area
        response_frame = tk.LabelFrame(main_frame, text="Dia's Response", bg="#f0f0f0")
        response_frame.pack(fill=tk.BOTH, expand=True, pady=10)
        
        self.response_text = scrolledtext.ScrolledText(
            response_frame,
            wrap=tk.WORD,
            font=font.Font(family="Arial", size=12),
            height=8
        )
        self.response_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Control buttons
        button_frame = tk.Frame(main_frame, bg="#f0f0f0")
        button_frame.pack(fill=tk.X, pady=10)
        
        button_style = {"font": font.Font(family="Arial", size=12), "width": 15, "height": 2}
        
        self.start_btn = tk.Button(
            button_frame,
            text="Start Listening",
            command=self.start_listening,
            bg="#4caf50",
            fg="white",
            **button_style
        )
        self.start_btn.pack(side=tk.LEFT, padx=10)
        
        self.stop_btn = tk.Button(
            button_frame,
            text="Stop Listening",
            command=self.stop_listening,
            state=tk.DISABLED,
            bg="#f44336",
            fg="white",
            **button_style
        )
        self.stop_btn.pack(side=tk.LEFT, padx=10)
        
        self.clear_btn = tk.Button(
            button_frame,
            text="Clear Display",
            command=self.clear_display,
            **button_style
        )
        self.clear_btn.pack(side=tk.LEFT, padx=10)
        
        # Status bar
        self.status_bar = tk.Label(
            self, 
            text="Ready to start", 
            bd=1, 
            relief=tk.SUNKEN, 
            anchor=tk.W
        )
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)
        
        # Populate devices
        self._refresh_devices()
    
    def _refresh_devices(self):
        """Refresh the list of audio input devices"""
        p = pyaudio.PyAudio()
        devices = []
        default_device = None
        
        for i in range(p.get_device_count()):
            device_info = p.get_device_info_by_index(i)
            if device_info['maxInputChannels'] > 0:  # Input device
                name = f"{device_info['name']} (Index: {i})"
                devices.append((name, i))
                
                # Try to find the default device
                if device_info.get('isDefaultInputDevice', False):
                    default_device = name
        
        p.terminate()
        
        # Update combobox
        self.device_menu['values'] = [d[0] for d in devices]
        self.device_dict = {d[0]: d[1] for d in devices}
        
        if devices:
            if default_device:
                self.device_var.set(default_device)
            else:
                self.device_var.set(devices[0][0])
    
    def _initialize_audio(self):
        """Initialize audio and speech recognition components"""
        # Check if Vosk model exists
        if not os.path.exists(CONFIG["model_path"]):
            self.status_var.set("Speech model not found!")
            self.status_label.config(fg="#f44336")
            self.start_btn.config(state=tk.DISABLED)
            return
        
        if not VOSK_AVAILABLE:
            self.status_var.set("Vosk library not installed!")
            self.status_label.config(fg="#f44336")
            self.start_btn.config(state=tk.DISABLED)
            return
        
        # Initialize PyAudio
        self.p = pyaudio.PyAudio()
    
    def start_listening(self):
        """Start listening for speech"""
        if self.recording:
            return
        
        self.recording = True
        self.wake_word_detected = False
        
        # Update UI
        self.start_btn.config(state=tk.DISABLED)
        self.stop_btn.config(state=tk.NORMAL)
        self.status_var.set("Listening... Say 'Hey Dia' to activate")
        self.status_label.config(fg="#2196f3")
        
        # Get selected device
        device_name = self.device_var.get()
        device_index = self.device_dict.get(device_name, None)
        CONFIG["device_index"] = device_index
        
        # Start speech recognition in a separate thread
        self.speech_thread = threading.Thread(target=self._speech_recognition_loop)
        self.speech_thread.daemon = True
        self.speech_thread.start()
        
        # Update status bar
        self.status_bar.config(text=f"Using device: {device_name}")
        
        # Display instructions
        self.speech_text.insert(tk.END, "Say 'Hey Dia' followed by your question...\n")
        self.speech_text.see(tk.END)
    
    def stop_listening(self):
        """Stop listening for speech"""
        if not self.recording:
            return
        
        self.recording = False
        
        # Update UI
        self.start_btn.config(state=tk.NORMAL)
        self.stop_btn.config(state=tk.DISABLED)
        self.status_var.set("Ready")
        self.status_label.config(fg="#4caf50")
        
        # Stop audio stream
        if self.audio_stream:
            self.audio_stream.stop_stream()
            self.audio_stream.close()
            self.audio_stream = None
        
        if self.p:
            self.p.terminate()
            self.p = pyaudio.PyAudio()
        
        # Update status
        self.status_bar.config(text="Listening stopped")
    
    def clear_display(self):
        """Clear display areas"""
        self.speech_text.delete(1.0, tk.END)
        self.response_text.delete(1.0, tk.END)
    
    def _speech_recognition_loop(self):
        """Main speech recognition loop"""
        try:
            # Load Vosk model
            model = vosk.Model(CONFIG["model_path"])
            
            # Open audio stream
            self.audio_stream = self.p.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=CONFIG["sample_rate"],
                input=True,
                frames_per_buffer=CONFIG["buffer_size"],
                input_device_index=CONFIG["device_index"]
            )
            
            # Create recognizer
            self.rec = vosk.KaldiRecognizer(model, CONFIG["sample_rate"])
            
            # Process audio in chunks
            self.update_status("Listening for 'Hey Dia'...")
            
            while self.recording:
                data = self.audio_stream.read(CONFIG["buffer_size"], exception_on_overflow=False)
                
                if self.rec.AcceptWaveform(data):
                    result = json.loads(self.rec.Result())
                    
                    if "text" in result and result["text"]:
                        text = result["text"].lower()
                        self.process_speech(text)
            
            # Final processing of any remaining audio
            if self.rec:
                result = json.loads(self.rec.FinalResult())
                if "text" in result and result["text"]:
                    text = result["text"].lower()
                    self.process_speech(text)
            
        except Exception as e:
            self.update_status(f"Error: {str(e)}", error=True)
        finally:
            if self.audio_stream:
                self.audio_stream.stop_stream()
                self.audio_stream.close()
                self.audio_stream = None
            
            # Ensure buttons are reset
            self.after(0, self._reset_ui)
    
    def _reset_ui(self):
        """Reset UI elements"""
        self.start_btn.config(state=tk.NORMAL)
        self.stop_btn.config(state=tk.DISABLED)
        self.status_var.set("Ready")
        self.status_label.config(fg="#4caf50")
    
    def update_status(self, message, error=False):
        """Update status message"""
        def _update():
            self.status_var.set(message)
            self.status_label.config(fg="#f44336" if error else "#2196f3")
            self.status_bar.config(text=message)
        
        self.after(0, _update)
    
    def process_speech(self, text):
        """Process recognized speech"""
        if not text:
            return
        
        # Insert recognized text
        def _update_text():
            timestamp = datetime.now().strftime("%H:%M:%S")
            self.speech_text.insert(tk.END, f"[{timestamp}] {text}\n")
            self.speech_text.see(tk.END)
        
        self.after(0, _update_text)
        
        # Check for wake word
        if CONFIG["wake_word"] in text.lower():
            self.wake_word_detected = True
            self.wake_word_time = time.time()
            
            def _update_wake():
                self.status_var.set("Wake word detected! Listening...")
                self.status_label.config(fg="#ff9800")
            
            self.after(0, _update_wake)
            return
        
        # Process query if wake word was recently detected
        if self.wake_word_detected:
            # If it's been more than 10 seconds since wake word, require a new one
            if time.time() - self.wake_word_time > 10:
                self.wake_word_detected = False
                return
            
            # Process the query with Dia
            self.process_query(text)
    
    def process_query(self, query):
        """Process a query with Dia and display the response"""
        def _update_processing():
            self.status_var.set("Processing query...")
            self.status_label.config(fg="#ff9800")
            self.response_text.insert(tk.END, "Processing...\n")
            self.response_text.see(tk.END)
        
        self.after(0, _update_processing)
        
        # In a real implementation, this would call the Dia Assistant API
        # For this demo, we'll just simulate a response
        def _get_response():
            try:
                # Try to use Dia's response generator if available
                sys.path.append("/opt/dia")
                from src.llm.response_generator import ResponseGenerator
                from src.utils.config_loader import load_config
                
                config = load_config("/opt/dia/config/dia.yaml")
                response_gen = ResponseGenerator(config.get("llm", {}))
                response = response_gen.generate_response(query)
                return response
            except:
                # Fallback to a simple response simulation
                time.sleep(1)  # Simulate processing time
                
                if "time" in query:
                    return f"The current time is {datetime.now().strftime('%I:%M %p')}."
                elif "weather" in query:
                    return "I'm sorry, I don't have access to weather information without internet."
                elif "name" in query:
                    return "My name is Dia, your offline voice assistant."
                else:
                    return f"I heard your question: '{query}'. Since this is just a test, I'm providing a simulated response."
        
        # Get response in separate thread
        def _response_thread():
            response = _get_response()
            
            def _update_response():
                timestamp = datetime.now().strftime("%H:%M:%S")
                self.response_text.insert(tk.END, f"[{timestamp}] Dia: {response}\n")
                self.response_text.see(tk.END)
                self.status_var.set("Ready for next question")
                self.status_label.config(fg="#4caf50")
                
                # Speak the response
                try:
                    import subprocess
                    subprocess.Popen(["espeak", response])
                except:
                    pass  # Ignore speech errors
            
            self.after(0, _update_response)
            
            # Reset wake word detection after response
            self.wake_word_detected = False
        
        threading.Thread(target=_response_thread).start()

if __name__ == "__main__":
    app = SpeechVisualizer()
    app.mainloop()
