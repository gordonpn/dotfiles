# Global Personal Preferences

## Engineering Standards
- **Atomic Commits:** Always create small, atomic, single-concern commits as you work. Do not bundle unrelated changes into a single commit.
- **Conventional Commits:** Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages (e.g., `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `style:`, `test:`).
- **Instruction Maintenance:** Always keep the project-specific `GEMINI.md` and global `GEMINI.md` files updated with new patterns, preferences, or established workflows identified during the session.
- **No Co-Authored-By:** Do not add `Co-Authored-By` lines to commit messages.
- **Conciseness:** Prefer commit messages that are clear and focused on the "why" rather than just the "what".

## Workflow & Research
- **Holistic Review:** Before implementing changes, always read through existing Markdown files (`README.md`, etc.) and configuration files to understand the project's architecture and requirements.
- **Cross-Platform Compatibility:** When working on projects shared between macOS and Linux (like dotfiles), always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.
