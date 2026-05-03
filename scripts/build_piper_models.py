#!/usr/bin/env python3
"""
HUMAID SOUL – Piper Voice Model Forge
Downloads raw Piper models from Hugging Face, converts them for sherpa-onnx,
and packages each voice as a .zip file with:
  - model.onnx (with metadata)
  - tokens.txt
  - espeak-ng-data/ (shared across all voices)
"""

import os, sys, json, subprocess, shutil, urllib.request, tarfile

# ── voice definitions ──────────────────────────────────────────
VOICES = {
    "amy": {
        "display": "Amy (Female)",
        "huggingface_path": "en/en_US/amy/low",
        "filename": "en_US-amy-low",
    },
    "john": {
        "display": "John (Male)",
        "huggingface_path": "en/en_US/john/low",
        "filename": "en_US-john-low",
    },
    "kristin": {
        "display": "Kristin (Female)",
        "huggingface_path": "en/en_US/kristin/low",
        "filename": "en_US-kristin-low",
    },
    "norman": {
        "display": "Norman (Male)",
        "huggingface_path": "en/en_US/norman/low",
        "filename": "en_US-norman-low",
    },
}

HF_BASE  = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"
ESPEAK_URL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/espeak-ng-data.tar.bz2"
OUT_DIR  = "piper_models"
TMP_DIR  = "/tmp/piper_build"

# ── helpers ─────────────────────────────────────────────────────
def download(url, dest):
    print(f"  ↓ {url}")
    urllib.request.urlretrieve(url, dest)

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
        with tarfile.open(espeak_tar, "r:bz2") as tf:
            tf.extractall(TMP_DIR)

    # 2. Process each voice
    for voice_id, info in VOICES.items():
        print(f"\n{'='*50}\n  Building {info['display']} ({voice_id})\n{'='*50}")

        fn   = info["filename"]
        hf   = info["huggingface_path"]
        onnx_url = f"{HF_BASE}/{hf}/{fn}.onnx"
        json_url = f"{HF_BASE}/{hf}/{fn}.onnx.json"

        voice_tmp = os.path.join(TMP_DIR, voice_id)
        os.makedirs(voice_tmp, exist_ok=True)

        # Download raw model + config
        onnx_file = os.path.join(voice_tmp, f"{fn}.onnx")
        json_file = os.path.join(voice_tmp, f"{fn}.onnx.json")
        if not os.path.exists(onnx_file):
            download(onnx_url, onnx_file)
        if not os.path.exists(json_file):
            download(json_url, json_file)

        # Inject metadata + generate tokens.txt using onnx
        print("  🔧 Injecting sherpa-onnx metadata …")
        run([
            sys.executable, "-c", f'''
import json, onnx

fn = "{onnx_file}"
with open("{json_file}") as f:
    cfg = json.load(f)

# generate tokens.txt
id_map = cfg["phoneme_id_map"]
with open("{voice_tmp}/tokens.txt", "w") as f:
    for s, i in id_map.items():
        f.write(f"{{s}} {{i[0]}}\\n")

# add metadata
model = onnx.load(fn)
meta_data = {{
    "model_type":  "vits",
    "comment":     "piper",
    "language":    cfg["language"]["name_english"],
    "voice":       cfg["espeak"]["voice"],
    "has_espeak":  1,
    "n_speakers":  cfg["num_speakers"],
    "sample_rate": cfg["audio"]["sample_rate"],
}}
for k, v in meta_data.items():
    m = model.metadata_props.add()
    m.key, m.value = k, str(v)
onnx.save(model, fn)
print("  ✓ Metadata injected")
''',
        ], cwd=voice_tmp)

        # Package: model.onnx, tokens.txt, espeak-ng-data
        pkg_dir = os.path.join(TMP_DIR, f"pkg_{voice_id}")
        if os.path.isdir(pkg_dir):
            shutil.rmtree(pkg_dir)
        os.makedirs(pkg_dir)

        shutil.copy2(onnx_file, os.path.join(pkg_dir, f"{voice_id}.onnx"))
        shutil.copy2(os.path.join(voice_tmp, "tokens.txt"), pkg_dir)
        shutil.copytree(espeak_dir, os.path.join(pkg_dir, "espeak-ng-data"))

        zip_path = os.path.join(OUT_DIR, f"{voice_id}.zip")
        shutil.make_archive(zip_path[:-4], "zip", pkg_dir)
        print(f"  ✅ Packaged → {zip_path}")

    print(f"\n{'='*50}\n  All voices built in {OUT_DIR}/\n{'='*50}")

if __name__ == "__main__":
    main()
