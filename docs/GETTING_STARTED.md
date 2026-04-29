# Getting Started with HUMAID SOUL Development

## Environment

- **Mobile development**: Termux with git and vim.
- **Build environment**: GitHub Actions (automated).

## First Steps

1. Clone the repo: `git clone https://github.com/chart9195-cyber/humaid-soul.git`
2. Edit code in `core/` (Rust) or `ui/` (Flutter) using vim.
3. Push changes: `git push origin main`
4. Watch CI build the dictionary in the Actions tab.
5. Download APK from Releases.

## Dictionary

Run `python scripts/build_dictionary.py` locally if you have Python, but the official build always runs in CI.
