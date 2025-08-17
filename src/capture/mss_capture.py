"""
MSS‑based screen capture.

This module provides a simple wrapper around the MSS library to capture
portions of the screen.  It is used by the aim assist pipeline to obtain
frames for object detection.
"""

from dataclasses import dataclass
from typing import Tuple

import cv2
import mss
import numpy as np


@dataclass
class Region:
    """Represents a rectangular region of the screen."""
    left: int
    top: int
    width: int
    height: int


class ScreenCapture:
    """Capture frames from a rectangular region of the screen using MSS."""

    def __init__(self, region: Region) -> None:
        self.region = region
        # MSS instance is thread‑safe and can be reused
        self.sct = mss.mss()

    def capture(self) -> np.ndarray:
        """Grab a frame from the configured region.

        Returns a BGR image as a NumPy array.
        """
        monitor = {
            "left": self.region.left,
            "top": self.region.top,
            "width": self.region.width,
            "height": self.region.height,
        }
        img = self.sct.grab(monitor)
        frame = np.array(img)
        # convert BGRA to BGR
        if frame.shape[2] == 4:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
        return frame