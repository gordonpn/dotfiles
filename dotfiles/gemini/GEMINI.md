# Global Personal Preferences

## Engineering Standards
- **Atomic Commits:** Always create small, atomic, single-concern commits as you work. Do not bundle unrelated changes into a single commit.
- **Conventional Commits:** Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages (e.g., `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `style:`, `test:`).
- **Instruction Maintenance:** Always keep the project-specific `GEMINI.md` and global `~/.gemini/GEMINI.md` files updated with new patterns, preferences, or established workflows identified during the session.
- **No Co-Authored-By:** Do not add `Co-Authored-By` lines to commit messages.
- **Conciseness:** Prefer commit messages that are clear and focused on the "why" rather than just the "what".

## Workflow & Research
- **Holistic Review:** Before implementing changes, always read through existing Markdown files (`README.md`, etc.) and configuration files to understand the project's architecture and requirements.
- **Cross-Platform Compatibility:** When working on projects shared between macOS and Linux (like dotfiles), always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.

## Solution Validation
- **Clarifying Questions:** Always ask clarifying questions before implementing. Do not assume you understand the full requirement without user confirmation.
- **Problem Understanding:** Challenge assumptions about what the problem actually is. Ask: "Is this the root issue, or a symptom?" Distinguish between the presented problem and the underlying need.
- **Solution Validation:** Before implementing, validate the proposed approach with the user. Ensure the solution directly addresses the root problem, not just a workaround.
- **Trade-offs:** When multiple solutions exist, present options with their trade-offs and let the user decide which aligns best with their goals.
