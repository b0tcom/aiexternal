"""
ONNX model loader.

Provides a simple wrapper around the onnxruntime InferenceSession API to
initialize a model with optional CUDA acceleration and run inference.
"""

from typing import Any, List

import onnxruntime as ort


class ModelLoader:
    """Wrap an ONNX model using onnxruntime."""

    def __init__(self, model_path: str, use_cuda: bool = True) -> None:
        providers: List[str]
        if use_cuda:
            providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        else:
            providers = ["CPUExecutionProvider"]
        # Try to initialize with the requested providers; fall back to CPU if
        # necessary.
        try:
            self.session = ort.InferenceSession(model_path, providers=providers)
        except Exception:
            # Fallback to CPU only
            self.session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name

    def run(self, input_tensor: Any) -> Any:
        """Run inference on the provided input tensor.

        Returns the list of output tensors as produced by the model.
        """
        return self.session.run(None, {self.input_name: input_tensor})