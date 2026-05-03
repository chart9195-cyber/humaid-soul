#!/usr/bin/env python3
"""
HUMAID SOUL – Icon Generator
Creates a minimalist adaptive launcher icon using Pillow (PIL).
No external assets needed — generates directly from code.
"""

import os, sys, math

def main():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow not installed. Installing…")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
        from PIL import Image, ImageDraw, ImageFont

    out_dir = sys.argv[1] if len(sys.argv) > 1 else "ui/assets/icon"
    os.makedirs(out_dir, exist_ok=True)

    # ── Foreground: "HS" monogram on transparent background ──
    size = 1024
    fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(fg)

    # Draw a subtle rounded square as the monogram container
    margin = 200
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=160,
        fill=(0, 150, 136, 220),  # teal, semi‑transparent
    )

    # Draw "HS" text
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 480)
    except:
        font = ImageFont.load_default()

    text = "HS"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1] - 30
    draw.text((x, y), text, fill=(18, 18, 30, 255), font=font)  # dark background colour

    fg_path = os.path.join(out_dir, "ic_foreground.png")
    fg.save(fg_path)
    print(f"Foreground saved: {fg_path}")

    # ── Background: solid dark ──
    bg = Image.new('RGBA', (size, size), (18, 18, 30, 255))
    bg_path = os.path.join(out_dir, "ic_background.png")
    bg.save(bg_path)
    print(f"Background saved: {bg_path}")

    # ── Simple launcher XML for adaptive icon ──
    xml_path = os.path.join(out_dir, "ic_launcher.xml")
    with open(xml_path, "w") as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_background"/>
    <foreground android:drawable="@mipmap/ic_foreground"/>
</adaptive-icon>
''')
    print(f"Adaptive icon XML saved: {xml_path}")

if __name__ == "__main__":
    main()
