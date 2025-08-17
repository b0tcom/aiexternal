# Parameter Map

This document maps the variables defined in **Features_for_my_newGame.txt** to
the keys used in the configuration files for this project.

| TXT Variable             | Config Key                | Description                                                            |
|--------------------------|---------------------------|------------------------------------------------------------------------|
| `DETECTION_RADIUS`       | `DETECTION_RADIUS`        | Pixels around the reticle used as the region of interest (ROI).        |
| `CONFIDENCE_THRESHOLD`   | `CONFIDENCE_THRESHOLD`    | Minimum detection confidence to consider a target.                     |
| `PID_KP`                 | `PID_KP`                  | Proportional gain of the PID controller.                               |
| `PID_KI`                 | `PID_KI`                  | Integral gain of the PID controller.                                   |
| `PID_KD`                 | `PID_KD`                  | Derivative gain of the PID controller.                                 |
| `AIM_SMOOTHING`          | `AIM_SMOOTHING`           | Low‑pass smoothing factor applied to solver output.                    |
| `TARGET_LOCK_STRENGTH`   | `TARGET_LOCK_STRENGTH`    | Blending factor between raw input and aim correction.                  |
| `SHOOTING_HEIGHT_OFFSET` | `SHOOTING_HEIGHT_OFFSET`  | Vertical offset applied to the target position.                        |
| `DEADZONE_RADIUS`        | `DEADZONE_RADIUS`         | Deadzone around the reticle where no correction is applied.            |
| `SENSITIVITY_SCALING`    | `SENSITIVITY_SCALING`     | Scalar applied to raw input sensitivity.                               |
| `USE_MOUSE_AIM`          | `USE_MOUSE_AIM`           | Enables mouse input for aim assist.                                    |
| `PROFILE`                | `PROFILE`                 | Name of the profile to load from `configs/profiles/*.json`.            |
| `HOTKEY_TOGGLE`          | `HOTKEY_TOGGLE`           | Keyboard key to toggle aim assist at runtime.                          |
| `CUDA`                   | `CUDA`                    | Enables GPU acceleration if available.                                 |
| `SERIAL.port`            | `SERIAL.port`             | Serial port for the Arduino Leonardo (`auto` attempts auto‑detection). |
| `SERIAL.baud`            | `SERIAL.baud`             | Baud rate for the serial connection.                                   |
| `SERIAL.mode`            | `SERIAL.mode`             | Mode for integrating the Arduino deltas (`PreSolve`, `PostSolve`, `Off`). |