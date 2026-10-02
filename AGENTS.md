# Dotfiles Project Instructions

These instructions apply specifically to this repository. Global engineering standards are managed in the global `AGENTS.md` (which is symlinked to `dotfiles/gemini/GEMINI.md` or `dotfiles/gemini/AGENTS.md`).

## Repo-Specific Context
- **Shell Configuration:** This repository contains the source of truth for shell exports, aliases, and setup scripts for both macOS and Ubuntu systems.
- **Cross-Platform:** Always verify changes against both Darwin and Linux logic blocks in `.zshrc_new`, `.zprofile`, and related files.
- **Dynamic Clipboard:** Use `bin/cbcopy` for clipboard tasks. It detects macOS (`pbcopy`), Wayland (`wl-copy`), X11 (`xclip`/`xsel`), and remote SSH sessions (OSC 52 escape sequence to local client terminal).
- **Syntax Themes:** CLI diffs and previews (`delta` and `bat`) use `flexoki-dark` and `--theme="ansi"`, directly inheriting Ghostty's Flexoki ANSI 16 palette registers without requiring custom TextMate cache builds.

