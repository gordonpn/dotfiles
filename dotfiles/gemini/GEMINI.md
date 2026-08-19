# Global Personal Preferences

## Engineering Standards
- **Atomic Commits:** Always create small, atomic, single-concern commits as you work. Do not bundle unrelated changes into a single commit.
- **Conventional Commits:** Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `style:`, `test:`).
- **Staged Diff Review:** Inspect the full staged diff (`git diff --cached`) before committing to catch unintended deletions or regressions, not just `git status` or `--stat`.
- **No Co-Authored-By:** Do not add `Co-Authored-By` lines to commit messages.
- **No Emojis & No Em Dashes:** Do not use emojis or em dashes in commit messages, code comments, or documentation.
- **No AI Attribution:** Never add "AI assisted" or bot disclaimers to commits, PRs, comments, or documentation. Write in the first person for human engineering peers.
- **Intent-Focused Comments:** Keep code comments succinct and focused on *why* (intent, trade-offs, non-obvious constraints), never restating *what* the code already makes clear.

## Testing & Verification
- **Reproduction First:** For bug fixes, reproduce the issue with a failing test before writing the fix. For features, write the failing behavior test first.
- **Comprehensive Verification:** Run full test suites to catch regressions, test boundary cases (empty, zero, max, error paths), and report the exact command and outcome.
- **Test Integrity:** Never delete, skip, or weaken a test to make a change pass.

## Self-Learning Loop & Maintenance
- **Instruction Maintenance:** When corrected by the user or when a durable constraint is identified, update the project-specific `AGENTS.md` and global `GEMINI.md` with a concise lesson.
- **Promotion Bar:** Only promote rules that generalize, change future behavior, and are not already covered by existing instructions.

## Workflow & Solution Validation
- **Holistic Review:** Before implementing changes, read existing configuration, scripts, and documentation to understand project architecture.
- **Cross-Platform Compatibility:** When working on projects shared between macOS and Linux (like dotfiles), always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.
- **Clarifying Questions & Validation:** Challenge assumptions to identify root issues versus symptoms. Present options with trade-offs before implementing non-trivial changes.

## Documentation & Infrastructure
- **Persistent Documentation:** Write durable architecture decisions, non-obvious quirks, and markdown artifacts under `/docs/` in the repository, not in temporary session folders.
- **Infrastructure as Code (IaC):** Use Terraform variables for sensitive values (no hardcoded tokens) and ensure local state/lock files are in `.gitignore`.
