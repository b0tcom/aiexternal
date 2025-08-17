"""
Test for ArduinoSerial absolute position packet (absmouse protocol).
"""
import sys
import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))
from io_arduino.serial_protocol import ArduinoSerial

def main():
    # Example: move to (960, 540) with ENABLE and MODE_PIX flags
    x, y = 960, 540
    buttons = 0b00000011  # Example: ADS + FIRE
    flags = 0x09  # ENABLE (bit 0) + MODE_PIX (bit 3)
    ser = ArduinoSerial(port="COM1", baud=115200)  # Port not used for test
    packet = ser._build_frame(x, y, 0, 0, buttons, flags=flags)
    print(f"Packet bytes: {packet.hex()}")
    print(f"Length: {len(packet)} bytes (should be 18)")
    # Optionally, decode and print CRC
    crc = int.from_bytes(packet[-2:], "little")
    print(f"CRC16 (X25): 0x{crc:04X}")

if __name__ == "__main__":
    main()
