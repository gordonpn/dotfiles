# Dotfiles Project Instructions

These instructions apply specifically to this repository. Global engineering standards are managed in the global `GEMINI.md` (which is symlinked to `dotfiles/gemini/GEMINI.md`).

## Repo-Specific Context
- **Shell Configuration:** This repository contains the source of truth for shell exports, aliases, and setup scripts for both macOS and Ubuntu systems.
- **Cross-Platform:** Always verify changes against both Darwin and Linux logic blocks in `.zshrc_new`, `.zprofile`, and related files.
- **Custom bat/delta Themes:** Custom syntax themes used by `bat` and `delta` (such as `Kanagawa.tmTheme`) are located in `dotfiles/bat/themes/`. Ensure they are placed in `~/.config/bat/themes/` and the cache is rebuilt using `bat cache --build` to avoid unknown theme warnings.

