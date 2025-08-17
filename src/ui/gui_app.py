"""Minimal GUI wrapper for the AI Assist pipeline.

This module provides a lightweight tkinter window that starts the
existing command-line pipeline (`src.ui.app`) in a background thread.
It is intentionally minimal so the rest of the codebase remains
unchanged.
"""

import threading
import tkinter as tk
import sys
from typing import Optional


class SimpleGUI(tk.Tk):
	def __init__(self):
		super().__init__()
		self.title("AI Assist - GUI")
		self.geometry("800x480")
		self._worker: Optional[threading.Thread] = None
		self._stop_event = threading.Event()
		self._create_widgets()

	def _create_widgets(self):
		frm = tk.Frame(self)
		frm.pack(fill=tk.BOTH, expand=True, padx=12, pady=12)
		self.status = tk.Label(frm, text="Idle", anchor="w")
		self.status.pack(fill=tk.X)
		btn_frame = tk.Frame(frm)
		btn_frame.pack(pady=8)
		self.start_btn = tk.Button(btn_frame, text="Start", command=self.start)
		self.start_btn.pack(side=tk.LEFT, padx=4)
		self.stop_btn = tk.Button(btn_frame, text="Stop", command=self.stop, state=tk.DISABLED)
		self.stop_btn.pack(side=tk.LEFT, padx=4)

	def start(self):
		if self._worker and self._worker.is_alive():
			return
		self._stop_event.clear()
		self.status.config(text="Running")
		self.start_btn.config(state=tk.DISABLED)
		self.stop_btn.config(state=tk.NORMAL)
		self._worker = threading.Thread(target=self._run_pipeline, daemon=True)
		self._worker.start()

	def stop(self):
		self._stop_event.set()
		self.status.config(text="Stopping...")
		self.start_btn.config(state=tk.NORMAL)
		self.stop_btn.config(state=tk.DISABLED)

	def _run_pipeline(self):
		# Run the existing CLI pipeline (non-blocking UI). Import inside the
		# thread to avoid interfering with the main thread state.
		try:
			from src.ui.app import main as app_main
			app_main(["--config", "configs/settings.json"])
		except Exception as e:
			# Show error in the GUI
			self.status.config(text=f"Error: {e}")


def main(argv=None):
	root = SimpleGUI()
	root.mainloop()


if __name__ == "__main__":
	main()

