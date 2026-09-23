# Global Personal Preferences

## Engineering Standards
- **Atomic Commits:** Always create small, atomic, single-concern commits as you work. Do not bundle unrelated changes into a single commit.
- **Conventional Commits:** Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `style:`, `test:`).
- **Staged Diff Review:** Inspect the full staged diff (`git diff --cached`) before committing to catch unintended deletions or regressions, not just `git status` or `--stat`.
- **No Co-Authored-By:** Do not add `Co-Authored-By` lines to commit messages.
- **No Emojis & No Em Dashes:** Do not use emojis or em dashes in commit messages, code comments, or documentation.
- **No AI Attribution:** Never add "AI assisted" or bot disclaimers to commits, PRs, comments, or documentation. Write in the first person for human engineering peers.
- **Intent-Focused Comments:** Keep code comments succinct and focused on *why* (intent, trade-offs, non-obvious constraints), never restating *what* the code already makes clear.
- **MCP Tool Prioritization:** When specialized MCP servers (such as `@modelcontextprotocol/server-github`, `kubernetes`, `prometheus`, or database servers) are configured, prioritize calling them directly instead of falling back to ad-hoc raw shell commands (`kubectl`, `curl`, etc.) via bash or zsh.
- **Web Search Preference:** Prioritize the `brave-search` MCP server (`brave_web_search`, `brave_local_search`) for all web search, external documentation lookups, and research queries instead of built-in search tools.
- **Task Runners:** Prefer modern task runners (`just` or `task`) over `make` for project workflows, build automation, and command orchestration.
- **SQL Query Files:** Write raw SQL statements in external `.sql` files rather than embedding inline query strings in application code, ensuring editor syntax highlighting, formatting, and linting remain fully functional.
- **Architecture & Dependency Hierarchy:**
  1. Reach for the standard library before third-party libraries.
  2. Use native platform and POSIX features before custom external scripts.
  3. Default to SQLite with raw SQL, prepared statements, and WAL mode enabled for storage; avoid ORMs unless an existing codebase already mandates one.
  4. Keep frontend interfaces lightweight: prefer server-rendered HTML with HTMX and Alpine.js over heavy Single Page Application frameworks (React, Vue) and complex bundlers.
- **Reproducible Toolchains:** Favor reproducible local toolchains managed by `mise`, `uv` (Python), `pnpm` or `bun` (Node/TypeScript), and standard `go`/`cargo` toolchains.
- **Zero Committed Secrets:** Never commit API keys, tokens, or credentials. Store sensitive values in `.env` (with a tracked `.env.example` containing dummy defaults), shell environment variables, or macOS Keychain. Ensure local databases (`*.db`, `*.sqlite`), local caches, and secrets are in `.gitignore`.

## Change Scope

Biased toward caution over speed. For a trivial edit with an obvious answer, use judgement rather than ceremony.

- **Simplicity First:** Write the minimum code that solves the stated problem. No features beyond what was asked, no abstraction for a single call site, no configurability nobody requested, no error handling for cases that cannot occur. If it could be substantially shorter, rewrite it before showing it.
- **Surgical Changes:** Touch only what the request requires. Do not improve adjacent code, comments, or formatting, and do not refactor what is not broken. Match the surrounding style even where you would write it differently.
- **Clean Up Only Your Own Mess:** Remove the imports, variables, and helpers that *this* change orphaned. Report unrelated dead code instead of deleting it.
- **Traceability:** Every changed line should trace to the request. An unrequested change shows up in the diff, not in the summary.
- **Push Back on Over-Engineering:** Treat user-proposed solutions as hypotheses. If an approach is over-engineered, introduces unnecessary dependencies, or violates standard library / minimal dependency hierarchy, push back with trade-offs and alternatives.

## Testing & Verification
- **Reproduction First:** For bug fixes, reproduce the issue with a failing test before writing the fix. For features, write the failing behavior test first.
- **Comprehensive Verification:** Run full test suites to catch regressions, test boundary cases (empty, zero, max, error paths), and report the exact command and outcome.
- **Test Integrity:** Never delete, skip, or weaken a test to make a change pass.
- **Verifiable Goals:** Restate the task as something checkable, then loop until it passes: "add validation" becomes tests for the invalid inputs; "refactor X" becomes the suite passing before and after. For multi-step work, state the plan and each step's check before starting. Weak criteria ("make it work") force a round trip to find out whether it is done.
- **Local Quality Gates:** Run project formatters and linters (`gofmt`, `ruff`, `biome`, `shellcheck`, `tofu fmt`) and check for existing git hook configurations (`lefthook`, pre-commit) to ensure local code quality passes before staging.
- **Remote Pipeline Diagnostics:** When remote pipelines fail, pull failure traces using `gh run view --log-failed` (or GitHub MCP tools) to inspect error logs directly, then reproduce and resolve the breakage in the local worktree.

## Self-Learning Loop & Maintenance
- **Instruction Maintenance:** When corrected by the user or when a durable constraint is identified, update the project-specific `AGENTS.md` and global `GEMINI.md` with a concise lesson.
- **Promotion Bar:** Only promote rules that generalize, change future behavior, and are not already covered by existing instructions.

## Workflow & Solution Validation
- **Holistic Review:** Before implementing changes, read existing configuration, scripts, and documentation to understand project architecture.
- **Project Context Intake:** In any project, inspect and read all root markdown documents (`README.md`, `ARCHITECTURE.md`, `IMPLEMENTATION.md`, and `docs/`) before proposing or writing code.
- **Isolated Agent Sessions:** For non-trivial features, refactors, or spikes, leverage worktrees via `worktrunk` (`wt switch --create <branch>` or `agyw`) to keep the primary working tree clean and isolated.
- **Issue to PR Flow:** Adopt a GitHub issue to pull request lifecycle for code changes. Create and/or inspect assigned task requirements using `@modelcontextprotocol/server-github` or `gh issue view <id> --json title,body,labels` before proposing logic changes.
- **Deterministic Acceptance Criteria Gate:** Refuse implementation and request clarification if the issue description lacks deterministic acceptance criteria (Given/When/Then) or technical constraints.
- **The Execution Sequence:** Execute work in a verifiable order: formulate checkable plan -> failing test/reproduction -> minimal implementation -> format/lint -> full test suite -> staged diff review -> atomic Conventional Commit -> draft PR.
- **Draft PR Delivery:** Push changes on a dedicated branch or worktree and open a draft PR linking the root issue (`gh pr create --draft --issue <id> --fill`).
- **Cross-Platform Compatibility:** When working on projects shared between macOS and Linux (like dotfiles), always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.
- **Clarifying Questions & Validation:** Challenge assumptions to identify root issues versus symptoms. Present options with trade-offs before implementing non-trivial changes.

## Documentation & Infrastructure
- **Persistent Documentation:** Write durable architecture decisions, non-obvious quirks, and markdown artifacts under `/docs/` in the repository, not in temporary session folders.
- **Operational Runbooks:** When introducing deployment steps, background daemons, or infrastructure components, document setup, execution commands, and diagnostics in `docs/RUNBOOK.md` or under `/docs/`.
- **Infrastructure as Code (IaC):** Use Terraform variables for sensitive values (no hardcoded tokens) and ensure local state/lock files are in `.gitignore`.
- **Release & Versioning Discipline:** Follow semantic versioning (`vMAJOR.MINOR.PATCH`) for software releases and tags (`git tag -a`), accompanied by human-readable changelog notes.
