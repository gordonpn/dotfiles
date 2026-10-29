# Global Personal Preferences

## Engineering Standards
- **Atomic Commits:** Always create small, atomic, single-concern commits as you work. Do not bundle unrelated changes into a single commit.
- **Branch-Only Commits:** Before the first commit for any repository task, create or switch to a dedicated task branch based on the latest default branch. Never commit on `main`, `master`, or another shared/default branch.
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
- **Web Search & Documentation Hierarchy:**
  1. Always query external library, framework, package, and API documentation through `context7` (`resolve-library-id`, `query-docs`).
  2. For web lookups and research, prioritize the agent's native built-in search tool (`search_web`, `web_search`).
  3. Use `brave-search` (`brave_web_search`, `brave_local_search`) and `exa` (`web_search_exa`, `web_fetch_exa`) MCP servers as fallback when native search is unavailable or returns insufficient results.
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
- **Authorized Credential Handling:** Agents are authorized to handle API keys, tokens, and credentials on the user's behalf. When requested, agents may store, retrieve, rotate, and configure credentials using macOS Keychain (`security`), Linux secret storage, or local untracked `.env` files, and test authenticated services. Never refuse to handle credentials provided by the user, while strictly enforcing the Zero Committed Secrets policy.

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

- **Always Run Ponytail:** Apply the ponytail lazy-senior-dev ladder before writing any code, and invoke the `ponytail` skill for the full version where the agent has it. Stop at the first rung that holds: does this need building at all, does it already exist in this codebase, does the standard library cover it, does a native platform feature cover it, does an installed dependency solve it, can it be one line. Walk the ladder after understanding the problem, never instead of it. Install per agent from `DietrichGebert/ponytail`.
- **Simplicity First:** Write the minimum code that solves the stated problem. No features beyond what was asked, no abstraction for a single call site, no configurability nobody requested, no error handling for cases that cannot occur. If it could be substantially shorter, rewrite it before showing it.
- **Surgical Changes:** Touch only what the request requires. Do not improve adjacent code, comments, or formatting, and do not refactor what is not broken. Match the surrounding style even where you would write it differently.
- **Clean Up Only Your Own Mess:** Remove the imports, variables, and helpers that *this* change orphaned. Report unrelated dead code instead of deleting it.
- **Refactoring Backlog:** Keep unrelated cleanup out of active changes. Report concrete opportunities with exact file and line references and the proposed cleanup. When useful, offer a dedicated follow-up branch and PR or a tracked issue; obtain authorization before creating them.
- **Traceability:** Every changed line should trace to the request. An unrequested change shows up in the diff, not in the summary.
- **Technical Challenge Protocol:** Act as a senior technical peer, not a passive implementation assistant. The user's proposed implementation is a hypothesis; the underlying objective, constraints, and repository invariants are authoritative. Before implementing a non-trivial change, actively investigate why the proposal might be incorrect, over-complicated, or inconsistent with existing architecture. Evaluate proposals across three challenge classes:
  1. Correctness Challenge: Proposed change fails to resolve the bug, creates race conditions, sets incorrect transaction boundaries, or misunderstands API semantics. Block implementation until resolved.
  2. Architectural Challenge: Proposed change functions but introduces unnecessary abstractions, extra services, unneeded caches/datastores, or premature complexity. Explain trade-offs and recommend the simpler alternative.
  3. Scope Challenge: Proposed change solves speculative future needs rather than immediate requirements (e.g. multi-provider abstractions with only one provider). Defer unrequested generalization.
  Apply a reversibility threshold: challenge aggressively when decisions are expensive or difficult to reverse; execute rapidly when changes are cheap and reversible. Prefer deleting or reusing architecture over adding new components.
- **Confidence Calibration:** Explicitly distinguish verified facts from working hypotheses. Use "I verified X" only after confirming via code, tests, or runtime logs; use "I suspect X" when inferring without direct evidence.
- **Root-Cause Resolution:** Trace failures to the core broken invariant. Never apply superficial masking, catch-all wrappers, broad `try/except` blocks, or defensive fallbacks that hide symptoms instead of fixing the underlying fault.

## Proactive Follow-Up & Alternative Exploration

- **Work Before Exploration:** Complete actionable work and verification before optional follow-ups. Ask earlier only when missing information materially affects correctness or scope.
- **Targeted Questions:** When meaningful, end user-facing responses with 1-3 specific questions that clarify unresolved decisions, challenge assumptions, expose risks, explore simpler solutions, or identify valuable next steps. Ground them in the task, repository, requirements, ADRs, and verified findings. Omit generic, artificial, repetitive, or already-answered questions; a completed task needs no forced follow-up.
- **Honest Alternatives:** For significant architectural or implementation choices, briefly explain credible alternatives actually evaluated and why they were rejected. Label unevaluated alternatives as suggestions for future exploration; never invent retrospective design deliberations.
- **Planning Trade-Offs:** Before implementing a non-trivial choice, state the selected trade-off in two sentences or fewer. Explore a rejected alternative only when new evidence or a concrete reconsideration trigger warrants it; follow the Architectural Decision Protocol below for durable rationale.
- **Question Placement:** Put optional follow-up questions at the very end, after outcomes, verification results, limitations, and risks.

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
- **UI Verification Loop:** When modifying user interfaces, follow the complete interaction loop: read code -> understand requirements -> modify code -> run automated tests -> launch application -> interact with UI (via Playwright or browser tools) -> verify actual behavioral output across edge cases (empty input submissions, rapid double submission, pagination limits, and state preservation across page reloads).

## Self-Learning Loop & Maintenance
- **Authoritative Information Hierarchy:** Resolve context and evaluate technical decisions against a strict hierarchy of authority:
  1. Explicit product / acceptance requirements
  2. Existing system invariants
  3. Reproducible runtime behavior & traces
  4. Automated tests
  5. Architecture decision records (ADRs)
  6. Existing repository conventions
  7. Official dependency documentation (via Context7 matching resolved version)
  8. Historical PR / issue context & CI logs
  9. Established engineering principles
  10. User's suggested implementation
  11. Model intuition
- **Persistent Correction Protocol:** Distinguish transient mistakes from recurring repository-specific misconceptions. The first incorrect assumption is corrected immediately in the active conversation. On the second occurrence of the same underlying misconception, persist it in `docs/agent-knowledge/corrections.md` capturing: incorrect assumption, correct understanding, supporting evidence, affected scope, rationale, and the rule future agents must follow. Track lifecycle states (`Active`, `Superseded`, `Obsolete`). When a correction represents a critical repository-wide invariant, promote a concise rule to `AGENTS.md` linking to the detailed entry.
- **Ground Truth over Model Echoes:** Never persist an agent correction or rule merely because another agent asserted it. Require verification against code, documentation, test results, runtime traces, or explicit user instruction.
- **Instruction Maintenance:** When corrected by the user or when a durable constraint is identified, update the project-specific `AGENTS.md` and global `GEMINI.md` with a concise lesson.
- **Cross-Session Project Memory:** Record durable project-wide decisions, constraints, and non-obvious context needed by other agents or future sessions in the project's `AGENTS.md`. Keep entries actionable and concise; link to `/docs/` for detailed rationale. Do not record temporary progress or duplicate existing guidance.
- **Promotion Bar:** Only promote rules that generalize, change future behavior, and are not already covered by existing instructions.
- **Rule Precedence:** A project's own `AGENTS.md` overrides this global file on conflict. Record project-specific rules there and keep only what generalizes here.
- **Concise Correction Format:** When recording user corrections, write them in the action-oriented form: "When X, do Y".
- **Repeat Mistake Rule:** If an error occurs despite an existing rule, treat the instruction as ambiguous or poorly scoped and rewrite it rather than appending redundant rules.

## Workflow & Solution Validation
- **Holistic Review:** Before implementing changes, read existing configuration, scripts, and documentation to understand project architecture.
- **Project Context Intake:** In any project, inspect and read all root markdown documents (`README.md`, `ARCHITECTURE.md`, `IMPLEMENTATION.md`, and `docs/`) before proposing or writing code.
- **Isolated Agent Sessions:** For non-trivial features, refactors, or spikes, leverage worktrees via `worktrunk` (`wt switch --create <branch>`, `agyw`, or `cdxw`) to keep the primary working tree clean and isolated.
- **Issue Hierarchy & Work Breakdown:** Model work in GitHub Issues using a strict 4-level hierarchy before writing code:
  1. **Initiative:** Strategic multi-epic objective spanning projects or repositories. Represented by a high-level GitHub Issue (labeled `initiative`) or a GitHub Project view tracking cross-cutting milestones.
  2. **Epic:** Large capability or architectural shift requiring multiple deliverables. Represented by a parent GitHub Issue (labeled `epic`) linking child Stories via GitHub native sub-issues or markdown task lists (`- [ ] #<id>`). Contains overarching architecture notes and end-to-end acceptance criteria.
  3. **Story:** Single vertical slice of user-facing or developer value delivering an end-to-end increment. Represented by an Issue (labeled `story` or `feature`) parented by an Epic. Must include user value narrative ("As a... I want to... So that..."), deterministic acceptance criteria (`Given/When/Then`), and maps 1:1 to a single-concern draft PR.
  4. **Task / Subtask:** Atomic engineering implementation unit (e.g., schema migration, adapter, test suite). Represented by a native GitHub Sub-issue (using `sub_issue_write`) or checklist items (`- [ ]`) within a Story issue.
- **Issue Effort & Priority Classification:** Every created GitHub issue must define both **Priority** and **Effort (T-Shirt Size)** in its body metadata and as GitHub labels:
  - **Priority Scale:**
    - `P0` (`priority:p0`): Blocker, critical production regression, security vulnerability, or data loss.
    - `P1` (`priority:p1`): High priority, core user path or milestone deliverable.
    - `P2` (`priority:p2`): Normal priority, standard feature or routine bug fix.
    - `P3` (`priority:p3`): Low priority, nice-to-have improvement, polish, or deferred task.
  - **Effort Scale (T-Shirt Sizes):**
    - `XS` (`effort:xs`): Trivial, minutes to execute, single-line or config fix, minimal testing required.
    - `S` (`effort:s`): Small, few hours, isolated change within one module or function, straightforward verification.
    - `M` (`effort:m`): Medium, 1-2 days, cross-cutting change across several files or adapters, requires comprehensive tests.
    - `L` (`effort:l`): Large, multi-day architectural change or epic component; consider decomposing into smaller stories.
    - `XL` (`effort:xl`): Extra Large, multi-week architectural change or complex epic; must be decomposed into smaller stories before implementation.
  - **Issue Metadata Format:** Include the metadata block at the top of the issue body:
    ```markdown
    **Priority:** P0 | P1 | P2 | P3
    **Effort:** XS | S | M | L | XL
    ```
    Attach the matching labels (`priority:p<0-3>`, `effort:<xs|s|m|l|xl>`). If the labels do not exist in the target repository, create them on first use.
- **Issue to PR Flow:** Adopt a GitHub issue to pull request lifecycle for code changes. Create and/or inspect assigned task requirements using `@modelcontextprotocol/server-github` or `gh issue view <id> --json title,body,labels` before proposing logic changes.
- **Atomic Issue Scope & Lifecycle Protection:** Each issue must tackle one atomic code change addressed by a corresponding PR. Ensure the issue and PR scopes are aligned 1:1 so that merging a PR delivers the entire scope of the issue. A PR must not close an issue prematurely before all concerns, requirements, and acceptance criteria in the issue are completely satisfied. Never use auto-closing keywords (`Fixes #<id>`, `Closes #<id>`) if residual tasks, sub-tasks, or unresolved concerns remain open.
- **Deterministic Acceptance Criteria Gate:** Refuse implementation and request clarification if the issue description lacks deterministic acceptance criteria (Given/When/Then) or technical constraints.
- **The Investigation & Execution Sequence:** Before modifying code, gather evidence rather than guessing runtime behavior from source alone:
  1. Read repository instructions, `AGENTS.md`, and active context.
  2. Inspect git status, current diff, and recent commit log.
  3. Locate affected code and map callers and callees.
  4. Consult relevant architecture docs, ADRs (`docs/adr/`), and historical PRs/issues/CI logs to answer why the code was structured this way.
  5. Check error monitoring (such as Sentry) or runtime traces for reported failures.
  6. Identify external dependencies and query Context7 for documentation matching the exact resolved lockfile version.
  7. Formulate checkable plan and reproduce failing behavior with a test.
  8. State the verified root cause and make the smallest coherent change.
  9. Run targeted tests, local quality gates (`just test`, `just lint`), and broader verification.
  10. Verify actual runtime behavior (UI verification loop if frontend).
  11. Create a task branch -> review staged diff against original requirements -> atomic Conventional Commit -> automated review via OCR -> draft PR.
- **Read-Only Production Guard:** Treat production and cloud services (GitHub, databases, Cloudflare, Sentry, cloud infrastructure) as read-only by default. Freely query and inspect runtime state, logs, and metrics to gather diagnostic evidence, but never perform mutations, schema alterations, or write operations against production services without explicit authorization. Do not write to production merely to investigate a problem.
- **Review by Dimension:** Review a change as separate focused passes (architecture and layering, missing test cases, missed capability in an installed dependency, API documentation, style) rather than one generic review pass, then merge and deduplicate the findings by file and line. Cap the fix rounds and report what is still unresolved instead of looping indefinitely.
- **Automated Review Gate (OCR):** Always execute Open Code Review via the `ocr` CLI before pushing code to a remote repository or opening a pull request. If an external LLM provider is configured in OCR, run `ocr review --audience agent`. In delegated or offline agent workflows, run deterministic inspection via `ocr delegate preview --format json` and `ocr delegate rule --format json` to resolve review rules and evaluate findings against them. Address all critical, high, and medium severity findings before delivering changes.
- **Draft PR Delivery:** Push the dedicated task branch and open a draft PR targeting the default branch, linking a root issue when one exists. If the user explicitly forbids pushing or opening a PR, leave commits on the task branch and report that the PR remains unopened; never substitute a commit on the default branch.
- **User-Only PR Merging:** Never call `merge_pull_request` or execute `gh pr merge`. Only the user merges pull requests. Agents prepare changes, push branches, open draft or ready PRs, and address review feedback, leaving merge execution strictly to the human maintainer.
- **No Stacked PRs with GitHub:** Never create stacked pull requests or chain PR branches (where a branch is cut from another unmerged PR branch or targets a non-default branch). Every PR must target the repository default branch (`main` or `master`) directly from an isolated branch based on the latest default branch. Merge each PR into the default branch before branching downstream work from the updated default branch.
- **Distinct PR Branches & Merge Isolation:** Each PR must originate from its own distinct, dedicated branch based on the default target branch. Never share or daisy-chain branches across concurrent PRs: when a PR merges and its remote branch is deleted, no other active or pending PR should be affected, broken, or invalidated.
- **Cognitively Small PRs:** Keep pull requests as small as possible, single-concern, and straightforward to review. A PR too large to hold in your head must be decomposed into sequential, independent PRs (e.g. database schema/queries -> core engine/adapters -> UI presentation) merged incrementally into the default branch, never into stacked or chained PR branches. If a PR title requires "and" to summarize its scope, decompose it into smaller independent increments.
- **PR Review Audit Trail (gordonpn/*):** For all repositories under the gordonpn/ namespace, leave explicit audit replies on PR review threads (both peer reviews and automated bots like CodeRabbit) whenever addressing or triaging feedback. Document what decision was made, why that choice was selected, why alternatives were rejected, and reference the resolving commit SHA. Never silently resolve, ignore, or bypass review comments without a clear audit record.
- **Issue Maintenance (gordonpn/*):** When requested work relates to an existing issue in a `gordonpn/*` repository, read it and keep it current at meaningful milestones and handoff. This rule authorizes relevant progress comments and verified checklist updates unless the task explicitly forbids GitHub writes. Record verified outcomes, blockers, remaining work, test results, and commit or PR links when available; avoid duplicate updates and preserve others' edits. Do not create issues solely to satisfy this rule, expand their scope, or close them without explicit authorization and complete, verified acceptance criteria. If an update cannot be published, report it and provide the intended update in the handoff.
- **Cross-Platform Compatibility:** When working on projects shared between macOS and Linux (like dotfiles), always verify that commands and environment variables are wrapped in appropriate OS checks where necessary.
- **Single-Turn Verification Focus:** Conclude each execution turn with the exact atomic outcome and the single immediate verification command or target (e.g. `Run 'just test' to verify the reproduction suite passes`).
- **Two-Attempt Circuit Breaker:** If a tool call, test fix, or command fails twice on the same step, stop immediately. Document what failed, reassess assumptions, and re-plan rather than retrying blindly.
- **Triad Evaluation (UX, DX, AX):** When evaluating architectural trade-offs, weigh User Experience (UX), Developer Experience (DX), and Agent Experience (AX: greppability, unambiguous symbols, explicit types, and clean tool parsing).

## Continuous Development & Backlog Management Protocol

### Purpose

Maintain a continuous, lightweight development workflow that makes the next actionable task obvious, keeps GitHub Issues synchronized with actual progress, and minimizes repeated planning.

Follow this workflow when working in repositories that use GitHub Issues for task management.

Do not perform comprehensive backlog refinement unless explicitly requested or materially justified by major project changes.

### 1. Sources of Truth

Use the following hierarchy:

1. **GitHub Issues:** Canonical task definitions, priorities, effort estimates (T-shirt sizes: XS, S, M, L, XL), dependencies, and completion status.
2. **GitHub Projects:** Planning fields and workflow status, where configured.
3. **Repository and tests:** Evidence of implementation and correctness.
4. **Project documentation:** Requirements and intended behavior.
5. **`NEXT.md`:** Derived snapshot of immediate execution priorities.

Never treat `NEXT.md` as authoritative over newer GitHub information.

Avoid maintaining duplicate backlogs in Markdown when GitHub Issues already provides the necessary task tracking.

### 2. Beginning a Coding Session

When starting an implementation session:

1. Read applicable repository instructions.
2. Identify the current GitHub repository and working branch.
3. Check the working tree for existing uncommitted changes.
4. Read `NEXT.md` if present.
5. Retrieve the relevant GitHub Issues and verify their current state.
6. Identify existing work in progress and outstanding blockers.
7. Determine the most appropriate next task.

Do not perform a full repository or backlog audit unless necessary.

#### Selecting Work

If the user requests a specific task, prioritize that request over the existing execution queue.

If the user asks what to work on next, consult the current queue and validate it against GitHub.

If the user explicitly requests autonomous backlog execution, select the highest-leverage READY task.

Do not begin unrelated implementation merely because `NEXT.md` identifies available work.

#### Next-Task Decision Rules

Prefer tasks that are:

1. Critical, when a genuine urgent issue exists.
2. Already in progress and appropriate to finish.
3. Ready for immediate implementation.
4. Blocking important downstream work.
5. High-impact relative to implementation effort.
6. Capable of reducing meaningful technical uncertainty.

Respect dependencies and avoid unnecessary context switching.

Do not choose a blocked task merely because it has a higher priority.

When no implementation task is ready, recommend the smallest useful blocker-resolution or investigation task.

### 3. Definition of Ready

Before starting an issue, verify:

- [ ] Objective is clear.
- [ ] Acceptance criteria are testable.
- [ ] Scope is appropriately bounded.
- [ ] Dependencies are satisfied.
- [ ] No unresolved decision prevents execution.
- [ ] Relevant implementation context is available.
- [ ] Verification expectations are known.

If an issue is missing minor implementation details, resolve them through repository investigation.

If important requirements are missing, clarify or refine the issue before implementation.

Do not invent major requirements to make a task appear ready.

### 4. Maintain a NOW / NEXT / LATER Queue

Maintain `NEXT.md` as a concise representation of the current execution plan.

#### NOW

Exactly one primary recommended task.

Include:

- GitHub issue number and link
- Priority (`P0` to `P3`)
- Effort estimate (T-shirt size: `XS`, `S`, `M`, `L`, `XL`)
- Readiness
- Reason for selection
- First concrete action
- Definition of Done
- Important downstream tasks it unblocks

#### NEXT

The next 3-5 tasks, ordered by dependencies and expected value.

Include links, priorities, effort estimates (T-shirt sizes), and blockers.

Identify work that can be executed in parallel.

#### LATER

Do not reproduce the entire backlog.

Link to the relevant GitHub Issues or GitHub Project view.

#### BLOCKERS

List meaningful blockers and unresolved decisions affecting immediate work.

Keep this file short enough to review at the start of every coding session.

GitHub remains the canonical source of truth.

### 5. Implementation Workflow

When executing a selected task:

1. Retrieve the latest GitHub Issue details.
2. Inspect relevant source code and tests.
3. Confirm the implementation scope.
4. Follow existing project architecture and conventions.
5. Implement the smallest complete solution satisfying acceptance criteria.
6. Add or update appropriate tests.
7. Run relevant verification.
8. Review the resulting changes for unintended consequences.
9. Record significant discoveries or blockers.
10. Update GitHub and the execution queue as appropriate.

Prefer minimal, focused changes.

Do not combine unrelated backlog tasks into one implementation unless explicitly justified.

For complex tasks, use an implementation plan. Avoid unnecessary planning overhead for straightforward changes.

### 6. Keep GitHub Issues Updated

During implementation, treat GitHub task management as part of the workflow rather than a separate administrative activity.

#### When Starting Work

When supported by the repository's conventions:

- Mark the issue as in progress.
- Maintain the existing assignee or ownership conventions.
- Reference the issue in the relevant branch or pull request.
- Record material scope clarifications when necessary.

Do not overwrite another contributor's active ownership or work.

#### When Discovering Missing Work

If implementation reveals a previously unknown task:

1. Determine whether it belongs within the current issue's scope.
2. Search for an existing GitHub Issue.
3. If necessary, create a new issue with clear acceptance criteria.
4. Set an appropriate priority (`P0`-`P3`) and effort estimate (T-shirt size: `XS`, `S`, `M`, `L`, `XL`).
5. Link it to the current task when relevant.
6. Reassess the execution queue only if the discovery materially changes priorities or dependencies.

Do not expand the current implementation indefinitely to address unrelated discoveries.

#### When Blocked

If a task becomes blocked:

- Identify the specific blocker.
- Update the relevant GitHub Issue or Project status.
- Record an actionable resolution path.
- Link prerequisite work.
- Select the next available task only when continued work is authorized.

Do not repeatedly attempt the same unsuccessful approach without addressing its underlying cause.

#### When Completing Work

Before reporting completion:

- Verify relevant acceptance criteria.
- Run appropriate tests and checks.
- Confirm that implementation scope is satisfied.
- Identify any remaining limitations.

Then synchronize GitHub appropriately:

- Link related commits or pull requests.
- Update the issue's implementation status.
- Record meaningful remaining work.
- Close the issue only when it meets the repository's actual completion criteria.

If a pull request still requires review or merging, do not falsely report the issue as fully completed. Follow the repository's established PR-to-issue closure workflow.

Never claim verification that was not performed.

### 7. Automatically Refresh `NEXT.md`

Update `NEXT.md` when a meaningful execution-state change occurs, including:

- Completion of the current task
- A new blocking dependency
- A major priority change
- Discovery of important missing work
- Changes to the immediate execution order
- Comprehensive backlog refinement

#### Refresh Procedure

1. Retrieve current GitHub Issue state.
2. Remove completed, obsolete, or superseded tasks from the immediate queue.
3. Reevaluate dependencies and readiness.
4. Identify the highest-leverage actionable task.
5. Select exactly one NOW task.
6. Choose the next 3-5 tasks.
7. Update `NEXT.md`.
8. Ensure all referenced issue numbers and links are valid.

Do not regenerate `NEXT.md` after every trivial code edit.

Do not overwrite unrelated local changes.

Treat regeneration as synchronization from GitHub, never the reverse.

If GitHub is unavailable, do not silently assume cached issue data is current. Preserve the existing queue or clearly mark the result as unverified.

### 8. Avoid Unnecessary Replanning

Use three levels of planning:

#### Level 1: Task Execution

For ordinary implementation work:

- Verify the selected issue.
- Execute the task.
- Validate the result.
- Update GitHub.
- Refresh the execution queue if needed.

Do not audit unrelated issues.

#### Level 2: Incremental Refinement

Use when:

- Important dependencies change.
- New implementation discoveries affect nearby work.
- Several upcoming tasks become blocked.
- The current execution queue is no longer realistic.

Review the affected issues and their direct dependencies.

Update only what is necessary.

#### Level 3: Comprehensive Backlog Audit

Use when explicitly requested, or recommend it when:

- Project objectives change significantly.
- Major architectural changes invalidate the backlog.
- A substantial amount of implementation has diverged from the plan.
- The backlog contains widespread stale or duplicated work.
- Reliable execution ordering cannot be established incrementally.

Do not automatically perform a comprehensive audit after every completed task.

### 9. Synchronization, Idempotency & Concurrency

When updating GitHub:

- Check issue state before writing.
- Preserve existing descriptions, comments, and metadata.
- Follow existing labels and GitHub Projects conventions.
- Avoid duplicate issues or comments.
- Do not recreate previously closed tasks without justification.
- Do not overwrite changes made by another contributor or agent.
- Reread recently modified issues when concurrent changes are possible.
- Apply changes idempotently.
- Verify successful GitHub mutations.

Do not modify issues in unrelated repositories.

Avoid automatically starting multiple tasks or assigning work to other contributors without authorization.

Never confuse planned, implemented, verified, reviewed, and merged states.

If an update fails, report the failure accurately instead of assuming it succeeded.

### 10. Session Completion Protocol

At the end of a substantive implementation session:

#### A. Implementation Summary

Report:

- What changed
- Which issue was addressed
- What was verified
- What remains incomplete

#### B. GitHub Status

Report:

- Issues updated or created
- Issues closed, if any
- Related pull requests
- Remaining blockers
- Any synchronization failures

#### C. Next Task

Identify the next actionable issue based on the latest available state.

Conclude with:

**WORK ON THIS NEXT: [Issue Number] - [Issue Title]**

Include a brief explanation of why it is next.

If the next task is blocked, identify the immediate blocker-resolution action instead.

Do not automatically start another implementation task unless the user has requested continued or autonomous execution.

### 11. Interaction & Authorization Rules

- For informational questions, explanations, or read-only reviews, do not modify GitHub or local files.
- For requested coding work, keep the associated issue status and execution queue synchronized within available permissions.
- For explicitly requested backlog refinement, perform the authorized GitHub changes rather than merely proposing them.
- Do not delete issues, force-push, modify unrelated repositories, or change organization-wide settings.
- Respect the user's current request over standing backlog preferences.
- Escalate consequential ambiguities rather than making unsupported project decisions.
- If GitHub authentication or write permissions are missing, report the limitation and provide the intended changes without pretending they were applied.

Global instructions do not create background automation. Perform this workflow during active coding-agent sessions and authorized execution.

### Core Principle

**Always make the next actionable task obvious without turning every coding session into a planning session.**

GitHub defines the work.

`NEXT.md` identifies what matters now.

Implementation advances the project.

Verification establishes completion.

GitHub synchronization preserves progress.

The next task is selected from the updated state.

## Cross-Agent Task Continuity

These rules apply across coding agents, including Antigravity CLI and Codex CLI.

### Task State

- **One Checkpoint:** For multi-step implementations, maintain `.agent/HANDOFF.md` in the relevant worktree unless the project already defines a handoff location. Reuse that location rather than creating a competing record. Trivial, single-step edits need no handoff document.
- **Local Only:** Keep `.agent/HANDOFF.md` local and untracked. Never stage, commit, or force-add it.
- **Update Timing:** Update the checkpoint at meaningful milestones and before ending an unfinished session or transferring the task. Keep it concise, factual, and current, not a transcript or growing activity log.
- **Required Context:** Record the objective and acceptance criteria; branch and latest commit; completed work and modified files, including uncommitted changes; significant decisions and rationale; exact verification commands and outcomes; outstanding failures, blockers, remaining tasks, and the single next recommended action.
- **Evidence and Limits:** Distinguish verified results from inherited claims, hypotheses, and checks not run. Identify the revision or working-tree state tested and relevant environment constraints. Never include secrets or sensitive log contents.
- **Lifecycle:** Treat the handoff as a temporary task checkpoint, an exception to the durable-documentation location rule. Link to existing requirements and ADRs rather than duplicating them. On completion, mark it complete and preserve any durable knowledge in the appropriate project documentation.

### Session Recovery

1. Read repository instructions and the handoff, if present.
2. Inspect the current branch, recent commits, working-tree status, and staged and unstaged diffs.
3. Reconcile the checkpoint with source code and available verification evidence. Re-run relevant checks when evidence is missing or subsequent changes invalidate it; never treat another agent's claims as proof of success.
4. Continue from the latest verified state, preserving existing work. Do not reset, discard, or overwrite unfamiliar changes to match the handoff; resolve discrepancies first.
5. Correct stale checkpoint entries. If no handoff exists, reconstruct the necessary context from the repository and user request before proceeding.

## Subagent Orchestration
- **Role Boundaries:** Keep subagent responsibilities segregated. Explorers read and research; workers make file edits; reviewers audit and critique without mutating files.
- **Bounded Contracts:** Assign each subagent a single objective, a deterministic done condition, and require a concise outcome report (5 lines or fewer).
- **No Concurrent File Collisions:** Parallel subagent dispatch is encouraged for independent tasks, but never assign multiple subagents to touch or edit the same file concurrently.
- **Claim Verification:** Treat subagent findings as hypotheses; verify key assertions against the real codebase before basing architecture or code changes on them.

## External Agent Delegation

- **Primary Orchestrator:** Codex or Antigravity acts as the primary orchestrator owning integration, test execution, commits, and PR submission.
- **Skill Discovery & Parity:** Use the authoritative `delegate-coding-agents` skill (`~/.agents/skills/delegate-coding-agents/`) synchronized across Codex, Antigravity, and OpenCode via `bin/mcp-sync`.
- **Automatic Routing:** In repositories where `agents.delegationAllowed=true`, Antigravity CLI adopts a delegation-first posture, delegating initial exploration and analysis (`--mode plan`) or separable implementation (`--mode build`) to OpenCode (`opencode/deepseek-v4.1-flash-free`) before performing integration, verification, and delivery. Codex delegates sequentially: OpenCode `opencode/deepseek-v4.1-flash-free` first, OpenCode `opencode/glm-5.3-flash-free` only after a clear quota/rate-limit failure, then Gemini CLI only if OpenCode is also quota/rate limited. Stop when a worker completes successfully; never parallelize providers or retry for task errors, failed tests, or ambiguous results. For Antigravity, continue directly with the orchestrator if OpenCode is unavailable or quota-limited. For Codex, continue directly with the orchestrator only after the documented OpenCode and Gemini CLI fallback routes are exhausted. Keep cross-cutting architecture, sensitive decisions, complex integration, and final verification with the orchestrator.
- **Execution Gate:** Invoke the skill's `scripts/delegate.sh` with the correct `--orchestrator`, `--agent`, `--mode`, and `--automatic` flags. Automatic delegation is allowed only when the current repository has local Git config `agents.delegationAllowed=true`; otherwise continue directly. Do not bypass this gate for private or confidential code. The script also requires a clean checkout so the worktree snapshot matches the reviewed commit.
- **Delegate Model Defaults:** Use OpenCode `opencode/deepseek-v4.1-flash-free` at high variant; the OpenCode fallback `opencode/glm-5.3-flash-free` uses its supported default variant. Gemini CLI uses its configured model unless explicitly overridden. These OpenCode free offers may change; verify availability and never switch to a paid model silently. Do not use Copilot CLI or invoke Antigravity CLI (`agy -p`) as a Codex worker under a consumer plan.
- **No Recursion or Silent Fallback:** A delegated worker never delegates again. Apply the ordered fallback only on an explicit quota/rate-limit failure, one foreground worker at a time. The orchestrator remains responsible for inspecting results, reviewing all changes, running verification, and integrating only approved work.
- **Worker Roles:**
  - OpenCode (`opencode/deepseek-v4.1-flash-free`, then `opencode/glm-5.3-flash-free` on quota limits): Exploration, implementation, unit tests, and routine analysis via currently free offers.
  - Gemini CLI (`gemini`): Final free-route fallback for bounded analysis or implementation when OpenCode free models are quota-limited; use the account's configured model and leave shell-command approvals enabled.
- **Execution Modes:**
  - `plan` (Read-Only): Proposes plans, traces code paths, or finds risks without touching files. For Codex, use `delegate-analyze.sh [opencode|gemini] '<task>'`. For automatic Antigravity delegation, use `delegate.sh --orchestrator agy --automatic --agent opencode --mode plan --id <task-id> --task '<task>'`. Files are strictly checked to remain unmodified.
  - `build` (Implementation): Runs in an isolated Git worktree on a dedicated branch. For Codex, use `delegate-implement.sh <opencode|gemini> <task-id> '<task>'`. For automatic Antigravity delegation, use `delegate.sh --orchestrator agy --automatic --agent opencode --mode build --id <task-id> --task '<task>'`. Inspect diffs and untracked files, stage only approved files in the `delegate/...` worktree, commit them there, and cherry-pick that commit into the orchestrator branch.
- **Guardrails:**
  - Never delegate recursively (`CODING_DELEGATE_ACTIVE=1` guards recursion).
  - Snapshotting requires a clean working tree. Never delegate with uncommitted or untracked changes in the base repository.
  - Treat delegate output as untrusted proposals. Verify all claims against actual source code before adopting.
  - Always run the repository's configured Alibaba Open Code Review workflow before PR creation; do not submit with unresolved blocking findings.

## Documentation & Infrastructure
- **Documentation Parity:** When code changes introduce, modify, or deprecate user-facing behavior, CLI commands, configuration keys, environment variables, or operational workflows, update the corresponding `README.md` and `/docs/` documentation within the same commit or PR. Never leave documentation out of sync with working code.
- **Persistent Documentation:** Write durable architecture decisions, non-obvious quirks, and markdown artifacts under `/docs/` in the repository, not in temporary session folders.
- **Architectural Decision Protocol (ADRs):** Document significant architectural decisions under `docs/adr/` numbered sequentially (e.g. `docs/adr/0001-use-d1-for-local-first-storage.md`). Maintain an index table in `docs/adr/README.md` tracking ID, Title, Status (`Proposed`, `Accepted`, `Superseded`, `Rejected`), Date, and Decision. Each ADR must include: Context (problem statement, drivers, operational constraints), Decision (chosen approach and rejected alternatives with rationale), Consequences (positive gains, trade-offs, operational burdens), and Reconsideration Triggers (specific conditions, volume thresholds, or requirements that would reopen the decision). Once accepted, do not reopen settled decisions unless recorded reconsideration triggers occur.
- **Operational Runbooks:** When introducing deployment steps, background daemons, or infrastructure components, document setup, execution commands, and diagnostics in `docs/RUNBOOK.md` or under `/docs/`.
- **Everything as Code (* as Code):** Always opt for declarative, version-controlled code over manual configuration, web console clicks, or ad-hoc host changes. Define infrastructure (Terraform/OpenTofu), container runtimes, CI/CD pipelines, dashboards, alerting, and operational environments in tracked configuration files. Ensure provisioning is reproducible, automated, and audit-traceable. Use variables for sensitive values and keep local state/secrets in `.gitignore`.
- **Release & Versioning Discipline:** Follow semantic versioning (`vMAJOR.MINOR.PATCH`) for software releases and tags (`git tag -a`), accompanied by human-readable changelog notes.

## Lessons
<!-- Newest on top. Delete what no longer applies. -->

- When a service targets different hosted and self-hosted databases, keep dialect-specific SQL and migrations behind storage adapters and verify each supported backend.

