"""
Command line entry point for the aim assist pipeline.

This module parses command‑line arguments, creates an instance of
``AimAssist`` and invokes its run loop.  Optionally, it could display
overlay graphics using Pygame, but this skeleton keeps the UI minimal.
"""

import argparse
from typing import Optional

# Lazy imports to avoid loading heavy modules when running tests

def main(argv: Optional[list] = None) -> None:
    """Run the aim assist pipeline from the command line."""
    parser = argparse.ArgumentParser(description="External AI aim assist pipeline")
    parser.add_argument(
        "--window-title",
        type=str,
        default=None,
        help="Title of the game window to capture (currently unused)",
    )
    parser.add_argument(
        "--config",
        type=str,
        default="configs/settings.json",
        help="Path to the settings JSON file",
    )
    args = parser.parse_args(argv)
    # Perform runtime import here to avoid circular dependencies
    from ..pipeline.aim_assist import AimAssist
    pipeline = AimAssist(args.config)
    try:
        pipeline.run()
    except KeyboardInterrupt:
        print("\n[INFO] Exiting aim assist pipeline.")


if __name__ == "__main__":
    main()