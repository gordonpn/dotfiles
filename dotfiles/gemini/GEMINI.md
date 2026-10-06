# Global Personal Preferences

## Engineering Standards
- **Atomic Commits:** Always create small, atomic, single-concern commits as you work. Do not bundle unrelated changes into a single commit.
- **Conventional Commits:** Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `style:`, `test:`).
- **Staged Diff Review:** Inspect the full staged diff (`git diff --cached`) before committing to catch unintended deletions or regressions, not just `git status` or `--stat`.
- **No Co-Authored-By:** Do not add `Co-Authored-By` lines to commit messages.
- **No Emojis & No Em Dashes:** Do not use emojis or em dashes in commit messages, code comments, or documentation.
- **No AI Attribution:** Never add "AI assisted" or bot disclaimers to commits, PRs, comments, or documentation. Write in the first person for human engineering peers.
- **Intent-Focused Comments:** Keep code comments succinct and focused on *why* (intent, trade-offs, non-obvious constraints), never restating *what* the code already makes clear.
- **Flat Control Flow:** Prefer early returns and guard clauses over deeply nested `if`/`else` blocks to reduce cyclomatic complexity and indentation depth.
- **Pure Functions & Explicit State:** Minimize hidden state mutations and side effects. Favor deterministic functions with clear input/output contracts so code can be understood and tested in isolation.
- **Single Responsibility:** Keep individual functions and modules focused on a single conceptual task, avoiding multi-purpose routines that mix concerns.
- **API Docs State the Contract Only:** Doc comments (godoc, docstrings, TSDoc, rustdoc) state what it does, what it accepts, what it returns, and what it raises. No implementation details, no design rationale, no claims about the rest of the codebase, no future plans. Those claims rot. Inline comments still explain *why*; this restriction applies to public API documentation.
- **Type Docs Describe Responsibility:** A type, class, or module doc states its role and contract, not an enumeration of what each of its methods does. That is each method's own doc's job.
- **No Planning References in Code:** Never reference ticket IDs, issue numbers, sprint goals, milestones, or timeline phases in code, comments, or documentation. Plain `TODO` and `FIXME` markers for genuine deferred work are fine.
- **MCP Tool Prioritization:** When specialized MCP servers (such as `@modelcontextprotocol/server-github`, `kubernetes`, `prometheus`, or database servers) are configured, prioritize calling them directly instead of falling back to ad-hoc raw shell commands (`kubectl`, `curl`, etc.) via bash or zsh.
- **Web Search Preference:** Prioritize the `brave-search` MCP server (`brave_web_search`, `brave_local_search`) for all web search, external documentation lookups, and research queries instead of built-in search tools.
- **Task Runners:** Prefer modern task runners (`just` or `task`) over `make` for project workflows, build automation, and command orchestration. Always document non-trivial, multi-step, or repeated commands as recipes or tasks in the project's task runner (`Justfile` or `Taskfile.yml`), and execute project verification via configured recipes (`just test`, `just lint`, `just build`) rather than ad-hoc raw terminal pipelines.
- **No Inline Code (Dedicated Files):** Never embed code of one language inside another. Always write code in dedicated external files with proper file extensions (for example, raw SQL in external `.sql` files rather than inline strings in application code, JavaScript and CSS in external `.js`/`.ts` and `.css` files rather than inline `<script>`, `<style>`, or attribute handlers in HTML). This ensures that syntax highlighting, formatting, type checking, and linters remain fully functional across the entire codebase.
- **Architecture & Dependency Hierarchy:**
  1. Reach for the standard library before third-party libraries.
  2. Use native platform and POSIX features before custom external scripts.
  3. Default to SQLite with raw SQL, prepared statements, and WAL mode enabled for storage; avoid ORMs unless an existing codebase already mandates one.
  4. Keep frontend interfaces lightweight: prefer server-rendered HTML with HTMX and Alpine.js over heavy Single Page Application frameworks (React, Vue) and complex bundlers.
- **Check Installed Dependencies Before Hand-Rolling:** Before writing retry or backoff, date and timezone math, pagination, caching, grouping or deduping, hashing, or validation by hand, check what the already-installed dependencies provide. Verify the capability against the resolved version's real API by reading its source, types, or lockfile rather than recalling it from memory. This is not licence to add a dependency: when nothing installed covers it, the hierarchy above still applies.
- **Layering Rules Apply Only Where Adopted:** Where a project declares a layering (core, adapters, edge, infrastructure), enforce the import direction: core never imports adapters, adapters never import each other, and no cycles. Do not impose that structure on a project that never adopted it.
- **Reproducible Toolchains:** Favor reproducible local toolchains managed by `mise`, `uv` (Python), `pnpm` or `bun` (Node/TypeScript), and standard `go`/`cargo` toolchains.
- **Zero Committed Secrets:** Never commit API keys, tokens, or credentials. Store sensitive values in `.env` (with a tracked `.env.example` containing dummy defaults), shell environment variables, or macOS Keychain. Ensure local databases (`*.db`, `*.sqlite`), local caches, and secrets are in `.gitignore`.

## Type Safety and Correctness

Language-neutral rules. The parentheticals name how each one lands in TypeScript, Python, and Go.

- **Never Escape the Type System:** Do not reach for the untyped escape hatch to get past the checker (`any`, `Any`, bare `interface{}`). At an untyped boundary use the explicit unknown type and narrow with a checked conversion (`unknown` plus a guard, a parsed model or `TypedDict`, the two-value type assertion).
- **Never Silence the Checker:** Do not suppress a diagnostic to get past an absent or failed case (`!` non-null assertion, `# type: ignore`, a blind `cast`, discarding an error into `_`). Narrow it or handle it.
- **Absence Is a Value, Not an Exception:** A lookup that finds nothing returns absence in its type (`T | undefined`, `Optional[T]` returning `None`, the comma-ok or sentinel-error form), never a thrown "not found". Reserve exceptions and errors for genuinely exceptional conditions.
- **Bind Once, Narrowest Scope:** Prefer the immutable binding and declare it at first use (`const` over `let`, never `var`; module-level constants; no mutable package-level state). Reassign only where the value genuinely changes.
- **Do Not Hand Out Mutable Internals:** Fields never reassigned after construction are immutable (`readonly`, frozen dataclass, unexported field behind an accessor), collections crossing a boundary are read-only or copied, and a caller's argument is never mutated.
- **Exhaustive Handling of Closed Sets:** A `switch` or `match` over a closed value set handles every variant, and adding a variant must fail the build rather than fall through silently: assert exhaustiveness in the default branch (`never` assignment, `assert_never`, an exhaustiveness linter), or fail loudly where the language cannot check it.
- **Strong Typing in Dynamic Languages:** Always write dynamic languages with the strongest static typing guarantees available. Annotate all function signatures, parameters, return types, and module-level constants. In Python, enforce type annotations with strict checkers (`mypy` or `pyright`) and typed data containers (`dataclass`, `TypedDict`, `Pydantic`). In JavaScript ecosystems, default to TypeScript with strict mode enabled; when plain JavaScript is unavoidable, enforce static verification through complete JSDoc annotations and checkJs.
- **Named, Greppable Exports:** Export named identifiers rather than anonymous defaults or wildcard re-exports (`export default`, `import *`, dot imports), so every public symbol is rename-safe and greppable.

## Change Scope

Biased toward caution over speed. For a trivial edit with an obvious answer, use judgement rather than ceremony.

- **Simplicity First:** Write the minimum code that solves the stated problem. No features beyond what was asked, no abstraction for a single call site, no configurability nobody requested, no error handling for cases that cannot occur. If it could be substantially shorter, rewrite it before showing it.
- **Surgical Changes:** Touch only what the request requires. Do not improve adjacent code, comments, or formatting, and do not refactor what is not broken. Match the surrounding style even where you would write it differently.
- **Clean Up Only Your Own Mess:** Remove the imports, variables, and helpers that *this* change orphaned. Report unrelated dead code instead of deleting it.
- **Continuous Improvement & Refactoring Backlog:** While active changes must remain strictly surgical, actively watch for tech debt, architectural clutter, or simplification opportunities encountered while navigating the code. On every turn where an opportunity is identified, document the observation (exact file, line references, and proposed cleanup) and offer to execute it in a dedicated follow-up PR or log a tracked GitHub issue.
- **Traceability:** Every changed line should trace to the request. An unrequested change shows up in the diff, not in the summary.
- **Push Back on Over-Engineering:** Treat user-proposed solutions as hypotheses. If an approach is over-engineered, introduces unnecessary dependencies, or violates standard library / minimal dependency hierarchy, push back with trade-offs and alternatives.
- **Root-Cause Resolution:** Trace failures to the core broken invariant. Never apply superficial masking, catch-all wrappers, broad `try/except` blocks, or defensive fallbacks that hide symptoms instead of fixing the underlying fault.

## Testing & Verification
- **Reproduction First:** For bug fixes, reproduce the issue with a failing test before writing the fix. For features, write the failing behavior test first.
- **Comprehensive Verification:** Run full test suites to catch regressions, test boundary cases (empty, zero, max, error paths), and report the exact command and outcome.
- **Test Integrity:** Never delete, skip, or weaken a test to make a change pass.
- **Verifiable Goals:** Restate the task as something checkable, then loop until it passes: "add validation" becomes tests for the invalid inputs; "refactor X" becomes the suite passing before and after. For multi-step work, state the plan and each step's check before starting. Weak criteria ("make it work") force a round trip to find out whether it is done.
- **Local Quality Gates:** Run project formatters and linters (`gofmt`, `ruff`, `biome`, `shellcheck`, `tofu fmt`) and check for existing git hook configurations (`lefthook`, pre-commit) to ensure local code quality passes before staging.
- **Remote Pipeline Diagnostics:** When remote pipelines fail, pull failure traces using `gh run view --log-failed` (or GitHub MCP tools) to inspect error logs directly, then reproduce and resolve the breakage in the local worktree.
- **Exhaustiveness Over Sampling:** For closed value sets (enums, string unions, status constants), cover every member rather than a representative subset. A sampled subset is a gap unless the cap is stated and justified in the change.
- **Resolve the Case Universe:** Before claiming coverage is complete, read the definition that bounds it (the enum, the union type, the `switch` arms, the schema) and state what was judged against. Never infer the universe from the diff alone.
- **Prove Exclusion, Not Just Inclusion:** Every filter, guard, and branch needs both a matching case and a non-matching one. Assert exact set membership rather than a count or a single element, and assert every field the operation sets.
- **Reach Every New Branch:** Every added branch, `switch` arm, mapping key, error path, and validation has a case that drives it, including the absent, null, and empty defaults.
- **Test Data Factories:** Build test objects through factory helpers rather than inline literals in test bodies. Keep tests independent with no shared mutable state, and separate Arrange, Act, and Assert with blank lines.
- **Never Blind-Update Snapshots:** Investigate snapshot drift and understand what changed before regenerating the snapshot.
- **Not Applicable Is Not Unverified:** Distinguish "this rule does not apply here" from "I could not check this", and report the second explicitly. A check that never reached a verdict is never reported as passed, and a review that decided nothing is not a pass.
- **UI Boundary & Edge Proving:** When modifying user interfaces, forms, or interactive components, actively test boundary edge cases: empty input submissions, rapid double submission, pagination limits, and state preservation across page reloads.

## Self-Learning Loop & Maintenance
- **Instruction Maintenance:** When corrected by the user or when a durable constraint is identified, update the project-specific `AGENTS.md` and global `GEMINI.md` with a concise lesson.
- **Cross-Session Project Memory:** Record durable project-wide decisions, constraints, and non-obvious context needed by other agents or future sessions in the project's `AGENTS.md`. Keep entries actionable and concise; link to `/docs/` for detailed rationale. Do not record temporary progress or duplicate existing guidance.
- **Promotion Bar:** Only promote rules that generalize, change future behavior, and are not already covered by existing instructions.
- **Rule Precedence:** A project's own `AGENTS.md` overrides this global file on conflict. Record project-specific rules there and keep only what generalizes here.
- **Concise Correction Format:** When recording user corrections, write them in the action-oriented form: "When X, do Y".
- **Repeat Mistake Rule:** If an error occurs despite an existing rule, treat the instruction as ambiguous or poorly scoped and rewrite it rather than appending redundant rules.

## Workflow & Solution Validation
- **Holistic Review:** Before implementing changes, read existing configuration, scripts, and documentation to understand project architecture.
- **Project Context Intake:** In any project, inspect and read all root markdown documents (`README.md`, `ARCHITECTURE.md`, `IMPLEMENTATION.md`, and `docs/`) before proposing or writing code.
- **Isolated Agent Sessions:** For non-trivial features, refactors, or spikes, leverage worktrees via `worktrunk` (`wt switch --create <branch>`, `agyw`, `cdxw`, or `opw`) to keep the primary working tree clean and isolated.
- **Issue Hierarchy & Work Breakdown:** Model work in GitHub Issues using a strict 4-level hierarchy before writing code:
  1. **Initiative:** Strategic multi-epic objective spanning projects or repositories. Represented by a high-level GitHub Issue (labeled `initiative`) or a GitHub Project view tracking cross-cutting milestones.
  2. **Epic:** Large capability or architectural shift requiring multiple deliverables. Represented by a parent GitHub Issue (labeled `epic`) linking child Stories via GitHub native sub-issues or markdown task lists (`- [ ] #<id>`). Contains overarching architecture notes and end-to-end acceptance criteria.
  3. **Story:** Single vertical slice of user-facing or developer value delivering an end-to-end increment. Represented by an Issue (labeled `story` or `feature`) parented by an Epic. Must include user value narrative ("As a... I want to... So that..."), deterministic acceptance criteria (`Given/When/Then`), and maps 1:1 to a draft PR meeting size ceilings (<400 diff lines).
  4. **Task / Subtask:** Atomic engineering implementation unit (e.g., schema migration, adapter, test suite). Represented by a native GitHub Sub-issue (using `sub_issue_write`) or checklist items (`- [ ]`) within a Story issue.
- **Issue to PR Flow:** Adopt a GitHub issue to pull request lifecycle for code changes. Create and/or inspect assigned task requirements using `@modelcontextprotocol/server-github` or `gh issue view <id> --json title,body,labels` before proposing logic changes.
- **Deterministic Acceptance Criteria Gate:** Refuse implementation and request clarification if the issue description lacks deterministic acceptance criteria (Given/When/Then) or technical constraints.
- **The Execution Sequence:** Execute work in a verifiable order: formulate checkable plan -> failing test/reproduction -> minimal implementation -> format/lint -> full test suite -> staged diff review -> atomic Conventional Commit -> automated review via OCR -> draft PR.
- **Review by Dimension:** Review a change as separate focused passes (architecture and layering, missing test cases, missed capability in an installed dependency, API documentation, style) rather than one generic review pass, then merge and deduplicate the findings by file and line. Cap the fix rounds and report what is still unresolved instead of looping indefinitely.
- **Automated Review Gate (OCR):** Always execute Open Code Review via the `ocr` CLI before pushing code to a remote repository or opening a pull request. If an external LLM provider is configured in OCR, run `ocr review --audience agent`. In delegated or offline agent workflows, run deterministic inspection via `ocr delegate preview --format json` and `ocr delegate rule --format json` to resolve review rules and evaluate findings against them. Address all critical, high, and medium severity findings before delivering changes.
- **Draft PR Delivery:** Push changes on a dedicated branch or worktree and open a draft PR linking the root issue (`gh pr create --draft --issue <id> --fill`).
- **Cognitively Small PRs & Size Ceilings:** Keep pull requests small, single-concern, and straightforward to review. Target under 400 lines of diff (excluding auto-generated lockfiles or snapshots) and fewer than 8 changed files per PR. PRs exceeding ~500 lines of functional code must be decomposed into sequential, layered PRs (e.g. database schema/queries -> core engine/adapters -> UI presentation). If a PR title requires "and" to summarize its scope, decompose it into smaller stacked PRs.
- **PR Review Audit Trail (gordonpn/*):** For all repositories under the gordonpn/ namespace, leave explicit audit replies on PR review threads (both peer reviews and automated bots like CodeRabbit) whenever addressing or triaging feedback. Document what decision was made, why that choice was selected, why alternatives were rejected, and reference the resolving commit SHA. Never silently resolve, ignore, or bypass review comments without a clear audit record.
- **Refactoring Sessions:** Proactively offer dedicated refactoring sessions when identifying structural tech debt, code smells, or readability improvements. Keep refactoring work isolated in its own branch and PR to preserve maintainability without cluttering feature reviews.
- **Cross-Platform Compatibility:** When working on projects shared between macOS and Linux (like dotfiles), always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.
- **Trade-Off Declaration:** When architectural choices or non-trivial forks arise during planning, challenge assumptions, enumerate the viable options, and cite the selected trade-off in two sentences or fewer before switching to implementation.
- **Single-Turn Verification Focus:** Conclude each execution turn with the exact atomic outcome and the single immediate verification command or target (e.g. `Run 'just test' to verify the reproduction suite passes`).
- **Two-Attempt Circuit Breaker:** If a tool call, test fix, or command fails twice on the same step, stop immediately. Document what failed, reassess assumptions, and re-plan rather than retrying blindly.
- **Triad Evaluation (UX, DX, AX):** When evaluating architectural trade-offs, weigh User Experience (UX), Developer Experience (DX), and Agent Experience (AX: greppability, unambiguous symbols, explicit types, and clean tool parsing).

## Subagent Orchestration
- **Role Boundaries:** Keep subagent responsibilities segregated. Explorers read and research; workers make file edits; reviewers audit and critique without mutating files.
- **Bounded Contracts:** Assign each subagent a single objective, a deterministic done condition, and require a concise outcome report (5 lines or fewer).
- **No Concurrent File Collisions:** Parallel subagent dispatch is encouraged for independent tasks, but never assign multiple subagents to touch or edit the same file concurrently.
- **Claim Verification:** Treat subagent findings as hypotheses; verify key assertions against the real codebase before basing architecture or code changes on them.

## Documentation & Infrastructure
- **Documentation Parity:** When code changes introduce, modify, or deprecate user-facing behavior, CLI commands, configuration keys, environment variables, or operational workflows, update the corresponding `README.md` and `/docs/` documentation within the same commit or PR. Never leave documentation out of sync with working code.
- **Persistent Documentation:** Write durable architecture decisions, non-obvious quirks, and markdown artifacts under `/docs/` in the repository, not in temporary session folders.
- **Operational Runbooks:** When introducing deployment steps, background daemons, or infrastructure components, document setup, execution commands, and diagnostics in `docs/RUNBOOK.md` or under `/docs/`.
- **Everything as Code (* as Code):** Always opt for declarative, version-controlled code over manual configuration, web console clicks, or ad-hoc host changes. Define infrastructure (Terraform/OpenTofu), container runtimes, CI/CD pipelines, dashboards, alerting, and operational environments in tracked configuration files. Ensure provisioning is reproducible, automated, and audit-traceable. Use variables for sensitive values and keep local state/secrets in `.gitignore`.
- **Release & Versioning Discipline:** Follow semantic versioning (`vMAJOR.MINOR.PATCH`) for software releases and tags (`git tag -a`), accompanied by human-readable changelog notes.

## Lessons
<!-- Newest on top. Delete what no longer applies. -->

