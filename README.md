# HUMAID SOUL

**Intelligence without Friction.**

An offline-first, zero-latency cognitive reading environment. Tap any word in a PDF and instantly see a rich, safe dictionary entry — with lemmatization, synonyms, and a non‑intrusive Ghost HUD.

## Philosophy

- **100% Offline** – No data leaves your device.
- **WordWeb‑class dictionary** – Definitions, examples, synonyms, word types.
- **Ghost HUD** – Definitions appear in the clearest area, never blocking your text.
- **Mobile First** – Developed on Termux, assembled in GitHub Actions.

## Structure

- `core/` – Rust engine (PDF text extraction, lemmatization, dictionary query)
- `ui/` – Flutter frontend
- `scripts/` – Dictionary builder (Python)
- `dictionaries/` – Source data (not committed)
- `voices/` – Offline TTS models (not committed)
- `.github/workflows/build.yml` – CI/CD forge

## Quick Start

See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)
