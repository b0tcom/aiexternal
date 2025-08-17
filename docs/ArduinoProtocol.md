# Arduino Protocol

This document describes the binary protocol used to communicate between the
Python pipeline and the Arduino Leonardo.

## Frame Format

Each packet sent from the host to the Arduino is constructed as follows:

| Field              | Size (bytes) | Description                                                       |
|--------------------|--------------|-------------------------------------------------------------------|
| Header            | 2            | Constant bytes `0xAA 0x55` marking the start of a frame.         |
| Version           | 1            | Protocol version (currently `1`).                                 |
| Flags             | 1            | Reserved for future use (set to `0`).                             |
| `dx`              | 2            | Horizontal aim delta after PID smoothing (`int16`, little‑endian).|
| `dy`              | 2            | Vertical aim delta after PID smoothing (`int16`, little‑endian).  |
| `bias_x`          | 2            | Optional horizontal bias applied before or after the solver.      |
| `bias_y`          | 2            | Optional vertical bias applied before or after the solver.        |
| `buttons`         | 2            | Button bitmask (e.g. ADS/FIRE flags).                             |
| `seq`             | 2            | Frame sequence number (`uint16`, increments each packet).         |
| CRC16             | 2            | CRC‑16 (X25 polynomial) computed over version, flags and payload.  |

All multi‑byte fields are encoded little‑endian.  The CRC is computed over the
version byte, the flags byte and the 12‑byte payload (`dx`…`seq`).

## Baud Rate

The default baud rate for the serial connection is `115200`.  You can adjust
this value in the `configs/settings.json` file.

## Timing and Rate Limiting

Packets are transmitted at a maximum of **250 Hz**.  The Python pipeline
enforces a rate limit and drops frames if they are stale.  The Arduino should
delay between sends to avoid flooding the host.

## Arduino Sketch

A reference sketch is provided in `arduino/Leonardo/leonardo_aim_assist.ino`.
It reads sensor data or implements user‑defined logic, assembles frames
according to the protocol described above and sends them over the USB serial
interface.  You can build more advanced logic on top of this skeleton.