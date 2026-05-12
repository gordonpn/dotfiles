# Dotfiles Project Instructions

These instructions apply to all work performed within the dotfiles repository.

## Engineering Standards

- **Atomic Commits:** Always create small, atomic commits as you work. Do not bundle unrelated changes into a single commit.
- **Conventional Commits:** Use the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages (e.g., `fix:`, `feat:`, `chore:`, `refactor:`).
- **Instruction Maintenance:** Always keep the project-specific `GEMINI.md` and global `GEMINI.md` files updated with new patterns, preferences, or established workflows identified during the session.

## Research & Context

- **Holistic Review:** Before implementing changes, always read through existing Markdown files (`README.md`, etc.) and configuration files (shell exports, aliases, setup scripts) to understand the project's architecture and cross-platform requirements (macOS vs. Linux).
- **Cross-Platform Compatibility:** This repository is shared between macOS and Linux. Always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.
