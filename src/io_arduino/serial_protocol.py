"""
Serial protocol for communicating with an Arduino Leonardo.

This module defines the ``ArduinoSerial`` class, which wraps the ``pyserial``
library to send binary packets to a Leonardo according to the protocol
described in ``docs/ArduinoProtocol.md``.  Automatic port detection is left
as an exercise for the user.
"""

from __future__ import annotations

import struct
from typing import Optional

try:
    import serial  # type: ignore[import]
except ImportError:
    serial = None  # pyserial is optional


class ArduinoSerial:
    """Send aim deltas to an Arduino Leonardo over a serial connection."""

    def __init__(self, port: str = "auto", baud: int = 115200, mode: str = "PreSolve") -> None:
        self.seq = 0
        self.mode = mode
        self.port = port
        self.baud = baud
        if serial is None:
            self.ser = None
        else:
            resolved_port = self._detect_port() if port == "auto" else port
            self.ser = serial.Serial(resolved_port, baud, timeout=0) if resolved_port else None

    def _detect_port(self) -> Optional[str]:
        """Attempt to auto‑detect an Arduino Leonardo COM port.

        Returns a port string or ``None`` if no port could be determined.
        Current implementation simply returns ``None``; modify this method
        to scan available serial ports for your device's VID/PID.
        """
        # TODO: implement auto detection by inspecting serial.tools.list_ports
        return None

    def send_deltas(self, dx: int, dy: int, bias_x: int, bias_y: int, buttons: int) -> None:
        """Send legacy delta packet (relative movement)."""
        if self.ser is None:
            return
        dx = max(min(dx, 32767), -32768)
        dy = max(min(dy, 32767), -32768)
        bias_x = max(min(bias_x, 32767), -32768)
        bias_y = max(min(bias_y, 32767), -32768)
        buttons = buttons & 0xFFFF
        frame = self._build_frame(dx, dy, bias_x, bias_y, buttons, flags=0)
        self.ser.write(frame)

    def send_position(self, x: int, y: int, buttons: int, flags: int = 0x08) -> None:
        """
        Send absolute position packet (x, y in pixels or HID units).
        flags: set FLAG_MODE_PIX (bit 3) for pixel mode, 0 for HID mode.
        """
        if self.ser is None:
            return
        x = max(min(x, 32767), 0)
        y = max(min(y, 32767), 0)
        buttons = buttons & 0xFFFF
        # bx/by unused in absolute mode
        frame = self._build_frame(x, y, 0, 0, buttons, flags=flags)
        self.ser.write(frame)

    def _build_frame(self, dx: int, dy: int, bx: int, by: int, buttons: int, flags: int = 0) -> bytes:
        header = b"\xAA\x55"
        ver = 1
        # flags: bit 3 = FLAG_MODE_PIX (1=pixels, 0=HID)
        seq = self.seq & 0xFFFF
        self.seq = (self.seq + 1) & 0xFFFF
        payload = struct.pack("<hhhhHH", dx, dy, bx, by, buttons, seq)
        body = bytes([ver, flags]) + payload
        crc = self._crc16(body)
        return header + body + struct.pack("<H", crc)

    def _crc16(self, data: bytes) -> int:
        """Compute CRC‑16 (X25) over the given data."""
        crc = 0xFFFF
        poly = 0x1021
        for b in data:
            crc ^= b << 8
            for _ in range(8):
                if crc & 0x8000:
                    crc = (crc << 1) ^ poly
                else:
                    crc <<= 1
                crc &= 0xFFFF
        return crc