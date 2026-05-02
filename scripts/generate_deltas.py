#!/usr/bin/env python3
"""Generates xdelta3 patch files between previous and current versions."""

import json
import os
import subprocess
import sys
from pathlib import Path

RELEASE_DIR = sys.argv[1] if len(sys.argv) > 1 else "."
PREVIOUS_RELEASE_DIR = sys.argv[2] if len(sys.argv) > 2 else None

ARTIFACTS = [
    "soul_dict.db.zst",
    "medical.db.zst",
    "legal.db.zst",
]

def generate_delta(previous: str, current: str, output: str):
    """Run xdelta3 to create a patch."""
    subprocess.run(
        ["xdelta3", "-e", "-s", previous, current, output],
        check=True,
    )
    print(f"Delta created: {output} ({os.path.getsize(output)} bytes)")

def main():
    if PREVIOUS_RELEASE_DIR is None:
        print("No previous release directory provided; skipping delta generation.")
        return

    for artifact in ARTIFACTS:
        prev_file = os.path.join(PREVIOUS_RELEASE_DIR, artifact)
        curr_file = os.path.join(RELEASE_DIR, artifact)
        if os.path.exists(prev_file) and os.path.exists(curr_file):
            patch_file = os.path.join(RELEASE_DIR, f"{artifact}.xdelta")
            generate_delta(prev_file, curr_file, patch_file)

if __name__ == "__main__":
    main()
