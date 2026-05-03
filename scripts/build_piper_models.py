#!/usr/bin/env python3
"""
HUMAID SOUL – Piper Voice Model Forge (v2)
Downloads raw Piper ONNX models from Hugging Face (main branch),
injects sherpa‑onnx metadata, generates tokens.txt, and packages
each voice as a .zip file with:
  - {voice}.onnx (metadata‑enriched)
  - tokens.txt
  - espeak-ng-data/
"""

import os, sys, json, subprocess, shutil, urllib.request, tarfile

# ── voice definitions ──────────────────────────────────────────
# quality: "low" or "medium" – must match what exists on HF main
VOICES = {
    "amy": {
        "display": "Amy (Female)",
        "quality": "low",
        "filename": "en_US-amy-low",
    },
    "john": {
        "display": "John (Male)",
        "quality": "medium",
        "filename": "en_US-john-medium",
    },
    "kristin": {
        "display": "Kristin (Female)",
        "quality": "medium",
        "filename": "en_US-kristin-medium",
    },
    "norman": {
        "display": "Norman (Male)",
        "quality": "medium",
        "filename": "en_US-norman-medium",
    },
}

# Use 'main' branch – contains all voices including recent additions
HF_BASE  = "https://huggingface.co/rhasspy/piper-voices/resolve/main"
ESPEAK_URL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/espeak-ng-data.tar.bz2"
OUT_DIR  = "piper_models"
TMP_DIR  = "/tmp/piper_build"

# ── helpers ─────────────────────────────────────────────────────
def download(url, dest):
    print(f"  ↓ {url}")
    try:
        urllib.request.urlretrieve(url, dest)
    except Exception as e:
        print(f"  ❌ Download failed: {e}")
        raise

def run(cmd, **kw):
    print(f"  ▶ {' '.join(cmd)}")
    subprocess.run(cmd, check=True, **kw)

# ── main ────────────────────────────────────────────────────────
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)

    # 1. Download shared espeak-ng-data
    espeak_tar = os.path.join(TMP_DIR, "espeak-ng-data.tar.bz2")
    if not os.path.exists(espeak_tar):
        download(ESPEAK_URL, espeak_tar)
    espeak_dir = os.path.join(TMP_DIR, "espeak-ng-data")
    if not os.path.isdir(espeak_dir):
        print("  📦 Extracting espeak-ng-data …")
        with tarfile.open(espeak_tar, "r:bz2") as tf:
            tf.extractall(TMP_DIR)

    # 2. Process each voice
    for voice_id, info in VOICES.items():
        quality = info["quality"]
        fn      = info["filename"]
        hf_path = f"en/en_US/{voice_id}/{quality}"

        print(f"\n{'='*50}\n  Building {info['display']} ({voice_id}, {quality})\n{'='*50}")

        voice_tmp = os.path.join(TMP_DIR, voice_id)
        os.makedirs(voice_tmp, exist_ok=True)

        onnx_url = f"{HF_BASE}/{hf_path}/{fn}.onnx"
        json_url = f"{HF_BASE}/{hf_path}/{fn}.onnx.json"

        onnx_file = os.path.join(voice_tmp, f"{fn}.onnx")
        json_file = os.path.join(voice_tmp, f"{fn}.onnx.json")

        if not os.path.exists(onnx_file):
            download(onnx_url, onnx_file)
        if not os.path.exists(json_file):
            download(json_url, json_file)

        # Generate tokens.txt from JSON
        print("  🔧 Generating tokens.txt …")
        with open(json_file) as f:
            cfg = json.load(f)
        id_map = cfg.get("phoneme_id_map", {})
        with open(os.path.join(voice_tmp, "tokens.txt"), "w") as f:
            for s, ids in id_map.items():
                f.write(f"{s} {ids[0]}\n")

        # Inject sherpa‑onnx metadata
        print("  🔧 Injecting sherpa-onnx metadata …")
        run([
            sys.executable, "-c", f'''
import onnx, json

model = onnx.load("{onnx_file}")
with open("{json_file}") as f:
    cfg = json.load(f)

meta = {{
    "model_type":  "vits",
    "comment":     "piper",
    "language":    cfg["language"]["name_english"],
    "voice":       cfg["espeak"]["voice"],
    "has_espeak":  1,
    "n_speakers":  cfg.get("num_speakers", 1),
    "sample_rate": cfg["audio"]["sample_rate"],
}}
for k, v in meta.items():
    m = model.metadata_props.add()
    m.key, m.value = k, str(v)
onnx.save(model, "{onnx_file}")
print("  ✓ Metadata injected")
''',
        ])

        # Package: model.onnx, tokens.txt, espeak-ng-data
        pkg_dir = os.path.join(TMP_DIR, f"pkg_{voice_id}")
        if os.path.isdir(pkg_dir):
            shutil.rmtree(pkg_dir)
        os.makedirs(pkg_dir)

        # Rename model to {voice_id}.onnx for simpler loading
        shutil.copy2(onnx_file, os.path.join(pkg_dir, f"{voice_id}.onnx"))
        shutil.copy2(os.path.join(voice_tmp, "tokens.txt"), pkg_dir)
        shutil.copytree(espeak_dir, os.path.join(pkg_dir, "espeak-ng-data"))

        zip_path = os.path.join(OUT_DIR, f"{voice_id}.zip")
        shutil.make_archive(zip_path[:-4], "zip", pkg_dir)
        print(f"  ✅ Packaged → {zip_path}")

    print(f"\n{'='*50}\n  All voices built in {OUT_DIR}/\n{'='*50}")

if __name__ == "__main__":
    main()
