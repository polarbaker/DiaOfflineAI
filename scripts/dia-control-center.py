#!/usr/bin/env python3
"""
Dia Control Center
A lightweight GUI to manage all aspects of the Dia Assistant
"""

import os
import sys
import subprocess
import threading
import time
from datetime import datetime
import tkinter as tk
from tkinter import ttk, messagebox, font

class DiaControlCenter(tk.Tk):
    def __init__(self):
        super().__init__()
        
        # Configure window
        self.title("Dia Control Center")
        self.geometry("700x520")
        self.minsize(700, 520)
        
        # Set theme colors
        self.colors = {
            "bg": "#f5f5f5",
            "primary": "#e91e63",
            "success": "#4caf50",
            "warning": "#ff9800",
            "danger": "#f44336",
            "info": "#2196f3",
            "dark": "#333333",
            "light": "#ffffff",
            "muted": "#9e9e9e"
        }
        
        self.configure(bg=self.colors["bg"])
        
        # Load images if available
        self.images = {}
        
        # Create widgets
        self.create_widgets()
        
        # Start status monitoring
        self.status_monitoring = True
        self.status_thread = threading.Thread(target=self.monitor_status)
        self.status_thread.daemon = True
        self.status_thread.start()
    
    def create_widgets(self):
        # Main frame
        main_frame = tk.Frame(self, bg=self.colors["bg"])
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Title and status
        title_frame = tk.Frame(main_frame, bg=self.colors["bg"])
        title_frame.pack(fill=tk.X, pady=(0, 15))
        
        # Title
        title_font = font.Font(family="Arial", size=18, weight="bold")
        title = tk.Label(
            title_frame, 
            text="Dia Assistant Control Center",
            font=title_font,
            fg=self.colors["primary"],
            bg=self.colors["bg"]
        )
        title.pack(side=tk.LEFT)
        
        # Status indicator
        self.status_frame = tk.Frame(main_frame, bg=self.colors["bg"])
        self.status_frame.pack(fill=tk.X, pady=(0, 15))
        
        self.status_label = tk.Label(
            self.status_frame,
            text="Status:",
            font=font.Font(family="Arial", size=12),
            bg=self.colors["bg"]
        )
        self.status_label.pack(side=tk.LEFT)
        
        self.status_indicator = tk.Label(
            self.status_frame,
            text="Checking...",
            font=font.Font(family="Arial", size=12, weight="bold"),
            fg=self.colors["info"],
            bg=self.colors["bg"]
        )
        self.status_indicator.pack(side=tk.LEFT, padx=(5, 0))
        
        # Basic controls
        controls_frame = tk.Frame(main_frame, bg=self.colors["bg"])
        controls_frame.pack(fill=tk.X, pady=(0, 20))
        
        self.start_button = tk.Button(
            controls_frame,
            text="Start Dia",
            command=self.start_dia,
            bg=self.colors["success"],
            fg=self.colors["light"],
            width=10,
            height=2
        )
        self.start_button.pack(side=tk.LEFT, padx=(0, 10))
        
        self.stop_button = tk.Button(
            controls_frame,
            text="Stop Dia",
            command=self.stop_dia,
            bg=self.colors["danger"],
            fg=self.colors["light"],
            width=10,
            height=2
        )
        self.stop_button.pack(side=tk.LEFT, padx=(0, 10))
        
        self.restart_button = tk.Button(
            controls_frame,
            text="Restart Dia",
            command=self.restart_dia,
            bg=self.colors["warning"],
            fg=self.colors["light"],
            width=10,
            height=2
        )
        self.restart_button.pack(side=tk.LEFT)
        
        # Create cards frame (2x2 grid)
        cards_frame = tk.Frame(main_frame, bg=self.colors["bg"])
        cards_frame.pack(fill=tk.BOTH, expand=True)
        
        # Distribution for the grid
        cards_frame.columnconfigure(0, weight=1)
        cards_frame.columnconfigure(1, weight=1)
        cards_frame.rowconfigure(0, weight=1)
        cards_frame.rowconfigure(1, weight=1)
        
        # Voice & Personality Card
        voice_card = self.create_card(
            cards_frame, 
            "Voice & Personality", 
            [
                ("Change Voice", self.launch_voice_settings),
                ("Create Custom Voice", self.launch_custom_voice),
                ("Set Personality", self.launch_personality)
            ],
            0, 0
        )
        
        # Knowledge Card
        knowledge_card = self.create_card(
            cards_frame, 
            "Knowledge Base", 
            [
                ("Add Knowledge", self.launch_knowledge),
                ("Update Wikipedia", self.launch_wikipedia),
                ("Add Documents", self.launch_documents)
            ],
            0, 1
        )
        
        # System Card
        system_card = self.create_card(
            cards_frame, 
            "System", 
            [
                ("Optimize Performance", self.launch_optimize),
                ("Check Status", self.launch_status),
                ("View Logs", self.launch_logs)
            ],
            1, 0
        )
        
        # Hardware Card
        hardware_card = self.create_card(
            cards_frame, 
            "Hardware", 
            [
                ("Setup Audio", self.launch_audio),
                ("Test Microphone", self.launch_test),
                ("Update LLM", self.launch_llm)
            ],
            1, 1
        )
        
        # Footer
        footer_frame = tk.Frame(main_frame, bg=self.colors["bg"])
        footer_frame.pack(fill=tk.X, pady=(20, 0))
        
        footer_text = "Dia Assistant v1.0 - " + datetime.now().strftime("%Y-%m-%d")
        footer = tk.Label(
            footer_frame,
            text=footer_text,
            font=font.Font(family="Arial", size=9),
            fg=self.colors["muted"],
            bg=self.colors["bg"]
        )
        footer.pack(side=tk.RIGHT)
    
    def create_card(self, parent, title, buttons, row, col):
        """Create a card with a title and buttons"""
        card = tk.Frame(
            parent, 
            bg=self.colors["light"],
            relief=tk.RAISED,
            borderwidth=1
        )
        card.grid(row=row, column=col, padx=10, pady=10, sticky="nsew")
        
        # Card title
        title_label = tk.Label(
            card,
            text=title,
            font=font.Font(family="Arial", size=14, weight="bold"),
            fg=self.colors["dark"],
            bg=self.colors["light"]
        )
        title_label.pack(anchor="w", padx=15, pady=(15, 10))
        
        # Separator
        separator = ttk.Separator(card, orient="horizontal")
        separator.pack(fill=tk.X, padx=15, pady=(0, 10))
        
        # Buttons
        buttons_frame = tk.Frame(card, bg=self.colors["light"])
        buttons_frame.pack(fill=tk.BOTH, expand=True, padx=15, pady=(0, 15))
        
        for i, (text, command) in enumerate(buttons):
            button = tk.Button(
                buttons_frame,
                text=text,
                command=command,
                bg=self.colors["info"],
                fg=self.colors["light"],
                width=20,
                height=1
            )
            button.pack(anchor="w", pady=(0, 10))
        
        return card
    
    def monitor_status(self):
        """Continuously monitor Dia service status"""
        while self.status_monitoring:
            try:
                # Check if Dia service is running
                result = subprocess.run(
                    ["systemctl", "is-active", "dia.service"],
                    capture_output=True,
                    text=True
                )
                
                self.update_status(result.stdout.strip() == "active")
            except Exception as e:
                print(f"Error monitoring status: {e}")
            
            # Wait before checking again
            time.sleep(5)
    
    def update_status(self, is_running):
        """Update the status indicator based on service status"""
        def _update():
            if is_running:
                self.status_indicator.config(text="RUNNING", fg=self.colors["success"])
                self.start_button.config(state=tk.DISABLED)
                self.stop_button.config(state=tk.NORMAL)
                self.restart_button.config(state=tk.NORMAL)
            else:
                self.status_indicator.config(text="STOPPED", fg=self.colors["danger"])
                self.start_button.config(state=tk.NORMAL)
                self.stop_button.config(state=tk.DISABLED)
                self.restart_button.config(state=tk.DISABLED)
        
        # Execute in main thread
        self.after(0, _update)
    
    def run_command(self, command, wait=True):
        """Run a system command"""
        try:
            if wait:
                subprocess.run(command, check=True)
            else:
                subprocess.Popen(command)
            return True
        except subprocess.CalledProcessError as e:
            messagebox.showerror("Error", f"Command failed: {e}")
            return False
        except Exception as e:
            messagebox.showerror("Error", f"Failed to run command: {e}")
            return False
    
    # Service control functions
    def start_dia(self):
        if self.run_command(["sudo", "systemctl", "start", "dia.service"]):
            messagebox.showinfo("Success", "Dia Assistant started successfully")
    
    def stop_dia(self):
        if self.run_command(["sudo", "systemctl", "stop", "dia.service"]):
            messagebox.showinfo("Success", "Dia Assistant stopped successfully")
    
    def restart_dia(self):
        if self.run_command(["sudo", "systemctl", "restart", "dia.service"]):
            messagebox.showinfo("Success", "Dia Assistant restarted successfully")
    
    # Launch tool functions
    def launch_voice_settings(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-voice.sh"], wait=False)
    
    def launch_custom_voice(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-custom-voice.sh"], wait=False)
    
    def launch_personality(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-personality.sh"], wait=False)
    
    def launch_knowledge(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-knowledge.sh"], wait=False)
    
    def launch_wikipedia(self):
        self.run_command(["sudo", "/opt/dia/scripts/setup-wikipedia.sh"], wait=False)
    
    def launch_documents(self):
        self.run_command(["sudo", "/opt/dia/scripts/update_rag.sh"], wait=False)
    
    def launch_optimize(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-optimize.sh"], wait=False)
    
    def launch_status(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-status.sh"], wait=False)
    
    def launch_logs(self):
        self.run_command(["sudo", "journalctl", "-u", "dia.service", "-f"], wait=False)
    
    def launch_audio(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-bluetooth.sh"], wait=False)
    
    def launch_test(self):
        self.run_command(["sudo", "/opt/dia/scripts/dia-visual-test.py"], wait=False)
    
    def launch_llm(self):
        self.run_command(["sudo", "/opt/dia/scripts/setup-llm.sh"], wait=False)
    
    def on_closing(self):
        """Handle window closing"""
        self.status_monitoring = False
        self.destroy()


if __name__ == "__main__":
    # Check if running as root
    if os.geteuid() != 0:
        print("Please run as root (use sudo)")
        sys.exit(1)
    
    app = DiaControlCenter()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()
