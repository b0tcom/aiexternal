"""
Object detection wrapper for YOLO models.

This module defines a ``Detector`` class that uses an instance of
``ModelLoader`` to run inference on frames and returns bounding boxes,
scores and class indices.  The actual decoding of YOLOv10 output is
implementation‑specific and should be provided by the user or a third‑party
library.  Here we provide a skeleton implementation with a placeholder
decoder.
"""

from typing import List, Tuple

import cv2
import numpy as np

from ..models.onnx_loader import ModelLoader


class Detector:
    """Wraps a YOLO model for object detection."""

    def __init__(self, model_loader: ModelLoader, conf_threshold: float = 0.5) -> None:
        self.model_loader = model_loader
        self.conf_threshold = conf_threshold

    def preprocess(self, frame: np.ndarray) -> np.ndarray:
        """Resize and normalize an image for YOLOv10 inference.

        Produces a float32 tensor shaped (1, 3, 416, 416) in CHW order.
        """
        # Resize to 416×416 to match the model input size
        img = cv2.resize(frame, (416, 416))
        # Convert BGR → RGB
        img = img[:, :, ::-1]
        img = img.astype(np.float32) / 255.0
        # Transpose to channel first
        img = np.transpose(img, (2, 0, 1))
        img = np.expand_dims(img, axis=0)
        return img

    def detect(self, frame: np.ndarray) -> Tuple[List[Tuple[int, int, int, int]], List[float], List[int]]:
        """Run detection on a frame.

        Returns a tuple ``(boxes, scores, classes)`` where each list has the
        same length.  Boxes are `(x1, y1, x2, y2)` coordinates in pixels
        relative to the original frame.  Scores are confidence values in
        `[0, 1]`.  Classes are integer class indices.

        The default implementation returns empty lists; you should replace
        the decoder logic with appropriate YOLOv10 post‑processing.
        """
        input_tensor = self.preprocess(frame)
        outputs = self.model_loader.run(input_tensor)
        # TODO: decode outputs into boxes, scores and class indices.
        # Placeholder implementation returns no detections.
        boxes: List[Tuple[int, int, int, int]] = []
        scores: List[float] = []
        classes: List[int] = []
        return boxes, scores, classes