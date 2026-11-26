# Dotfiles Project Instructions

Repository-specific rules only. Global standards live in `dotfiles/gemini/GEMINI.md`.

## Repo-Specific Context
- **Personal Agent Client Parity:** Configure Antigravity CLI (`agy`) and Codex by default for personal MCP servers and skills, synchronized via `bin/mcp-sync`.
- **Dotfiles Delivery:** GitHub issues and issue hierarchies are optional in this repository; changes must go through a PR to the default branch. Never commit directly to `main` or `master`.
- **Cross-Platform:** Verify Darwin and Linux `uname` guards in `dotfiles/.zshrc_new`, `dotfiles/.zprofile`, and `bin/` scripts before changing platform-specific paths or commands.
- **Dynamic Clipboard:** Use `bin/cbcopy` for clipboard tasks (macOS `pbcopy`, Wayland `wl-copy`, X11 `xclip`/`xsel`, and SSH OSC 52) rather than hardcoding `pbcopy`.
- **Syntax Themes:** Keep `bat` on `--theme="ansi"` (`dotfiles/.batconfig`) and `delta` on `features = flexoki-dark` with `syntax-theme = none` (`dotfiles/.gitconfig-common`) so previews inherit terminal ANSI registers without custom TextMate caches.
- **Codebase Memory MCP:** Keep client registrations in `dotfiles/gemini/mcp_config.template.json` and use the pinned, checksum-verified release binary instead of the upstream installer (which edits shell startup files even with `--skip-config`; see `docs/mcp-setup.md#codebase-memory-mcp`).
