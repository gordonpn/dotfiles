# Dotfiles Project Instructions

These instructions apply specifically to this repository. Global engineering standards are managed in the global `AGENTS.md` (which is symlinked to `dotfiles/gemini/GEMINI.md` or `dotfiles/gemini/AGENTS.md`).

## Repo-Specific Context
- **Personal Agent Client Parity:** When installing MCP servers or skills for personal projects, configure Antigravity CLI (`agy`), OpenCode, and Codex unless explicitly requested otherwise. Keep shared configuration and skill synchronization authoritative.
- **Direct Dotfiles Delivery:** For this repository and dotfiles work, GitHub issues, issue hierarchies, and pull requests are not required. Deliver verified, atomic Conventional Commits directly to the default `main` or `master` branch. Keep staged diff review and the automated review gate before pushing.
- **Shell Configuration:** This repository contains the source of truth for shell exports, aliases, and setup scripts for both macOS and Ubuntu systems.
- **Cross-Platform:** Always verify changes against both Darwin and Linux logic blocks in `.zshrc_new`, `.zprofile`, and related files.
- **Dynamic Clipboard:** Use `bin/cbcopy` for clipboard tasks. It detects macOS (`pbcopy`), Wayland (`wl-copy`), X11 (`xclip`/`xsel`), and remote SSH sessions (OSC 52 escape sequence to local client terminal).
- **Syntax Themes:** CLI diffs and previews (`delta` and `bat`) use `flexoki-dark` and `--theme="ansi"`, directly inheriting Ghostty's Flexoki ANSI 16 palette registers without requiring custom TextMate cache builds.
- **Codebase Memory MCP:** Keep all three client registrations in `dotfiles/gemini/mcp_config.template.json`. Use the pinned, checksum-verified release binary instead of the upstream installer, which edits shell startup files even with `--skip-config`. See `docs/mcp-setup.md#codebase-memory-mcp`.
