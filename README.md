# AI Assist External Pipeline

This repository implements a modular external aim‑assist pipeline for a third‑person shooter.
It follows the specifications in **Features_for_my_newGame.txt** with modifications
to remove obfuscation and anti‑detection features and to integrate with an
Arduino Leonardo for input and output.  It is designed to be run **outside** of
the game process while providing configurable object detection and PID
smoothing.

## Features

- **Screen capture** using the MSS library.
- **ONNX Runtime** inference for object detection (YOLOv10) with CUDA support and
  CPU fallback.
- Configurable detection thresholds, region of interest (ROI) radius,
  and PID control gains.
- PID‑based smoothing for aim corrections.
- **Serial communication** with an Arduino Leonardo to output aim deltas.
- Config‑driven profiles and runtime toggling via hotkeys.
- Lightweight UI and logging (Pygame overlay optional).

## Quickstart

See [docs/Quickstart.md](docs/Quickstart.md) for installation and usage instructions.