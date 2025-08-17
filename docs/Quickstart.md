# Quickstart

This document explains how to set up and run the external aim‑assist pipeline.

## Requirements

- Python 3.10 or later.
- A supported GPU with CUDA 12.1 for GPU acceleration (optional).
- The following Python packages: `onnxruntime‑gpu`, `ultralytics`,
  `opencv‑python`, `mss`, `pygame`, `pyserial`, and `numpy`.  If you do not
  have a supported GPU you can replace `onnxruntime‑gpu` with `onnxruntime`.
- An Arduino Leonardo connected via USB running the reference sketch in
  `arduino/Leonardo/`.
- Your game running in a window on the same system.

## Setup

1. Create and activate a virtual environment:

   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```

2. Install dependencies:

   ```bash
   pip install onnxruntime-gpu ultralytics opencv-python mss pygame pyserial numpy
   ```

   If you do not have a supported GPU, use `onnxruntime` in place of
   `onnxruntime-gpu`.

3. Download the ONNX models referenced in
   `Features_for_my_newGame.txt` and place them in the `models/` directory:

   ```
   models/
     best.onnx
     AIOv10.onnx
   ```

4. Create or adjust the configuration in `configs/settings.json` and select a
   profile in `configs/profiles/*.json`.

## Running

Use the provided UI entry point to start the pipeline:

```bash
python -m src.ui.app --window-title "Name of Your Game Window" --config configs/settings.json
```

The pipeline will:

* Capture frames from the specified window.
* Run YOLO detection on each frame.
* Compute aim corrections based on the closest target and PID smoothing.
* Send aim deltas to the Arduino Leonardo via serial.

Press **F1** to toggle aim assist on and off at runtime.

## Notes

- The pipeline is designed to be transparent and ethical.  It omits any
  anti‑detection or obfuscation code.
- Ensure your Arduino Leonardo is flashed with the reference sketch in
  `arduino/Leonardo/` before running.
- Logging output will show performance metrics and the current target and
  PID values.