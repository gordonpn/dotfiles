# Dotfiles Project Instructions

These instructions apply specifically to this repository. Global engineering standards are managed in the global `GEMINI.md` (which is symlinked to `dotfiles/gemini/GEMINI.md`).

## Repo-Specific Context
- **Shell Configuration:** This repository contains the source of truth for shell exports, aliases, and setup scripts for both macOS and Ubuntu systems.
- **Cross-Platform:** Always verify changes against both Darwin and Linux logic blocks in `.zshrc_new`, `.zprofile`, and related files.
- **Dynamic Clipboard:** Use `bin/cbcopy` for clipboard tasks. It detects macOS (`pbcopy`), Wayland (`wl-copy`), X11 (`xclip`/`xsel`), and remote SSH sessions (OSC 52 escape sequence to local client terminal).
- **API Token Retrieval:** `ANTHROPIC_AUTH_TOKEN` in `.zprofile` queries macOS Keychain on Darwin and `secret-tool` (Linux libsecret/Keyring) or local keyfiles (`~/.config/deepseek/api_key`, `~/.deepseek_api_key`) on Linux.
- **Custom bat/delta Themes:** Custom syntax themes used by `bat` and `delta` (such as `Kanagawa.tmTheme`) are located in `dotfiles/bat/themes/`. Ensure they are placed in `~/.config/bat/themes/` and the cache is rebuilt using `bat cache --build` to avoid unknown theme warnings.

