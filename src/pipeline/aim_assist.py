"""
Aim assist pipeline.

This module combines screen capture, object detection and PID control to
compute aim deltas that are sent to an Arduino Leonardo.  It loads
configuration from JSON files and provides a simple run loop.

The detection decoding is left as a placeholder; you should integrate a
proper YOLOv10 post‑processing implementation for real use.
"""

import json
import time
from typing import Optional, Tuple

import numpy as np

from ..capture.mss_capture import ScreenCapture, Region
from ..models.onnx_loader import ModelLoader
from ..pipeline.detection import Detector
from ..pipeline.pid_controller import PIDController
from ..io_arduino.serial_protocol import ArduinoSerial


class AimAssist:
    """Main entry point for the aim assist pipeline."""

    def __init__(self, config_path: str) -> None:
        # Load settings
        with open(config_path, "r") as f:
            self.config = json.load(f)
        # Derive the active profile settings by merging profile data
        profile_name: str = self.config.get("PROFILE", "GENERAL")
        profile_path = f"configs/profiles/{profile_name}.json"
        try:
            with open(profile_path, "r") as pf:
                profile_data = json.load(pf)
        except Exception:
            profile_data = {}
        # Merge profile into settings (profile overrides base)
        merged = {**self.config, **profile_data}
        self.settings = merged
        # Initialize screen capture
        # TODO: derive region from config or detect game window
        region = Region(0, 0, 1920, 1080)
        self.capture = ScreenCapture(region)
        # Initialize model and detector
        model_path = "models/best.onnx"
        use_cuda = self.settings.get("CUDA", True)
        self.model = ModelLoader(model_path, use_cuda)
        conf_thresh = self.settings.get("CONFIDENCE_THRESHOLD", 0.5)
        self.detector = Detector(self.model, conf_thresh)
        # PID controllers for horizontal and vertical deltas
        kp = self.settings.get("PID_KP", 0.2)
        ki = self.settings.get("PID_KI", 0.0)
        kd = self.settings.get("PID_KD", 0.0)
        dt = 1.0 / 60.0
        self.pid_x = PIDController(kp, ki, kd, dt)
        self.pid_y = PIDController(kp, ki, kd, dt)
        # Arduino serial interface
        serial_conf = self.settings.get("SERIAL", {})
        self.arduino = ArduinoSerial(
            port=serial_conf.get("port", "auto"),
            baud=serial_conf.get("baud", 115200),
            mode=serial_conf.get("mode", "PreSolve"),
        )
        # Activation state
        self.enabled = True
        # Input scaling factors
        self.sensitivity_scaling = self.settings.get("SENSITIVITY_SCALING", 1.0)
        self.target_lock_strength = self.settings.get("TARGET_LOCK_STRENGTH", 1.0)
        self.deadzone_radius = self.settings.get("DEADZONE_RADIUS", 0)
        self.shooting_height_offset = self.settings.get("SHOOTING_HEIGHT_OFFSET", 0.0)

    def _select_target(
        self, boxes: list, scores: list, classes: list, frame_shape: Tuple[int, int, int]
    ) -> Optional[Tuple[float, float]]:
        """Select the best target from detections.

        Returns the (x, y) center of the chosen target in pixel coordinates.
        The default implementation picks the box closest to the center of the
        screen.  If no boxes are provided, returns ``None``.
        """
        if not boxes:
            return None
        h, w = frame_shape[:2]
        cx, cy = w / 2.0, h / 2.0
        min_dist = float("inf")
        best = None
        for box in boxes:
            x1, y1, x2, y2 = box
            tx = (x1 + x2) / 2.0
            ty = (y1 + y2) / 2.0
            dist = np.hypot(tx - cx, ty - cy)
            if dist < min_dist:
                min_dist = dist
                best = (tx, ty)
        return best

    def _compute_error(self, target: Tuple[float, float], frame_shape: Tuple[int, int, int]) -> Tuple[float, float]:
        """Compute the pixel error between the reticle and the target."""
        h, w = frame_shape[:2]
        cx, cy = w / 2.0, h / 2.0
        tx, ty = target
        error_x = tx - cx
        error_y = (ty + self.shooting_height_offset * h) - cy
        return error_x, error_y

    def run(self) -> None:
        """Main loop of the aim assist pipeline."""
        while True:
            frame = self.capture.capture()
            boxes, scores, classes = self.detector.detect(frame)
            target = self._select_target(boxes, scores, classes, frame.shape)
            dx = dy = 0.0
            if target is not None:
                error_x, error_y = self._compute_error(target, frame.shape)
                # Deadzone: ignore small errors
                if abs(error_x) > self.deadzone_radius:
                    dx = self.pid_x.update(error_x)
                else:
                    self.pid_x.reset()
                if abs(error_y) > self.deadzone_radius:
                    dy = self.pid_y.update(error_y)
                else:
                    self.pid_y.reset()
                # Apply smoothing factor
                smoothing = self.settings.get("AIM_SMOOTHING", 0.0)
                dx *= (1.0 - smoothing)
                dy *= (1.0 - smoothing)
                # Apply target lock strength (blend factor)
                dx *= self.target_lock_strength
                dy *= self.target_lock_strength
            # Cast to integers for transmission
            out_dx = int(dx)
            out_dy = int(dy)
            # Currently no biases or button bits
            self.arduino.send_deltas(out_dx, out_dy, 0, 0, 0)
            # Sleep briefly to avoid maxing out CPU
            time.sleep(0.001)