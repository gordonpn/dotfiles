---
name: github-backlog-workflow
description: Manage GitHub issues, pull request templates, continuous NEXT.md execution queues, backlog refinement, session completion reports, ADRs, and runbooks. Use when creating or triaging issues, opening PRs, selecting the next backlog task, refreshing NEXT.md, documenting investigations, or closing a coding session.
---

# GitHub Backlog, PR, and Documentation Workflow

Maintain a lightweight, continuous development workflow where GitHub Issues remain the canonical source of truth, `NEXT.md` makes immediate execution priorities obvious, and investigations or architectural choices leave durable records.

## Issue Hierarchy and Metadata

Model work in GitHub Issues using a 4-level hierarchy before writing code:

1. **Initiative:** Strategic multi-epic objective spanning projects or repositories. Tracked as a high-level GitHub Issue (`initiative` label) or a GitHub Project view.
2. **Epic:** Large capability or architectural shift requiring multiple deliverables. Parent GitHub Issue (`epic` label) linking child Stories via native sub-issues or task lists (`- [ ] #<id>`), with overarching architecture notes and end-to-end acceptance criteria.
3. **Story:** Single vertical slice of user or developer value delivering an end-to-end increment (`story` or `feature` label, parented by an Epic). Includes user value narrative ("As a... I want to... So that..."), deterministic acceptance criteria (`Given/When/Then`), and maps 1:1 to a single-concern ready-for-review PR.
4. **Task / Subtask:** Atomic engineering implementation unit (schema migration, adapter, test suite) represented by a native GitHub Sub-issue (`sub_issue_write`) or checklist item (`- [ ]`) within a Story.

### Priority and Effort Classification

Every created GitHub issue must define both **Priority** and **Effort** in a top metadata block and matching labels (create missing labels on first use):

- **Priority:**
  - `P0` (`priority:p0`): Blocker, critical production regression, security vulnerability, or data loss.
  - `P1` (`priority:p1`): High priority, core user path, or milestone deliverable.
  - `P2` (`priority:p2`): Normal priority, standard feature, or routine bug fix.
  - `P3` (`priority:p3`): Low priority, nice-to-have improvement, polish, or deferred task.
- **Effort (T-Shirt Size):**
  - `XS` (`effort:xs`): Minutes, single-line or config fix, minimal testing.
  - `S` (`effort:s`): Few hours, isolated change in one module/function, straightforward verification.
  - `M` (`effort:m`): 1-2 days, cross-cutting across files/adapters, comprehensive tests required.
  - `L` (`effort:l`): Multi-day architectural change or epic component; consider decomposing into smaller stories.
  - `XL` (`effort:xl`): Multi-week architectural change or complex epic; decompose before implementation.

```markdown
**Priority:** P0 | P1 | P2 | P3
**Effort:** XS | S | M | L | XL
```

### Issue Naming and Lean Body Templates

Follow Conventional Commits for all issue titles:

`<type>(<optional-scope>): <imperative summary>`

- **Types:** `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `chore`, `investigation`.
- **Rules:** Lowercase type and scope, imperative present-tense verb ("add", "resolve", "lean out"), no issue numbers or PR links in the title, no trailing period, no emojis, and no em/en dashes.
- **Explain Why:** Every issue and meaningful update must explain *why* the work is needed (underlying problem, impact, constraints, trade-offs, and evidence), not just *what* to change.

#### Task / Story / Investigation Template

```markdown
**Priority:** P0 | P1 | P2 | P3
**Effort:** XS | S | M | L | XL

## Objective
[User narrative 'As a... I want... So that...' or concise statement of intent and why it matters]

## Context & Scope
[Why this is needed, background, technical constraints, concrete areas to touch, related issues]

## Acceptance Criteria
- [ ] Given [context], when [action], then [verifiable outcome]
- [ ] Automated verification target (e.g. 'just test' or reproduction command)

## Out of Scope
- [Explicit non-goals or deferred work]
```

#### Bug Fix Template

```markdown
**Priority:** P0 | P1 | P2 | P3
**Effort:** XS | S | M | L | XL

## Problem Summary
[Succinct failure or regression description, plus why it matters and user/system impact]

## Technical Constraints
[Relevant technical constraints, or state that none apply]

## Reproduction & Observed vs Expected
1. [Reproduction step]
- **Observed:** [Actual behavior or error output]
- **Expected:** [Intended correct behavior]

## Acceptance Criteria
- [ ] Given [context], when [action], then [verifiable outcome]
- [ ] Failing reproduction test case is committed
- [ ] Fix resolves the issue without regression in related test suites
```

## Issue-to-PR Lifecycle and PR Body Convention

- **Issue-to-PR Flow:** Inspect assigned task requirements via GitHub MCP or `gh issue view <id> --json title,body,labels` before proposing logic changes.
- **Atomic Issue Scope & Lifecycle Protection:** Align issue and PR scopes 1:1. Do not close an issue prematurely before all acceptance criteria are verified; never use auto-closing keywords (`Fixes #<id>`, `Closes #<id>`) if residual tasks or unresolved concerns remain open.
- **Deterministic Acceptance Criteria Gate:** Refuse implementation and request clarification if an issue lacks deterministic acceptance criteria (`Given/When/Then`) or technical constraints.
- **PR Body Convention & Lean Template:** Unless the repository provides its own PR template, structure every PR description with `## Why`, `## Summary`, and `## Verification`. When a repository provides a partial PR template in any GitHub-supported location (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`, repo root, or `docs/`), keep the repository's template headings and supply whichever of `## Why`, `## Summary`, and `## Verification` are missing without duplicating headings (treat `## Description`, `## Overview`, and `## What` as summary-equivalent to `## Summary`):

```markdown
## Why
[Problem, user or operational impact, constraints, or trade-offs motivating the change; link supporting evidence or docs/decisions.md]

## Summary
- [Focused summary of what changed and link to the root issue, e.g. Closes #<id> or Refs #<id> when applicable]

## Verification
- [Exact checks run and observed outcomes, or explicit statement of any checks not run]
```

## Continuous Development and Backlog Management Protocol

Follow this protocol in repositories that use GitHub Issues for task management. Do not run comprehensive backlog refinement unless requested or materially justified by major project changes.

### 1. Sources of Truth

1. **GitHub Issues:** Canonical task definitions, priorities, effort estimates (XS-XL), dependencies, and status.
2. **GitHub Projects:** Planning fields and workflow status, where configured.
3. **Repository and tests:** Evidence of implementation and correctness.
4. **Project documentation:** Requirements and intended behavior.
5. **`NEXT.md`:** Derived snapshot of immediate execution priorities.

Never treat `NEXT.md` as authoritative over newer GitHub information, and avoid duplicating the full backlog in Markdown when GitHub Issues already tracks it.

### 2. Beginning a Coding Session and Selecting Work

1. Read applicable repository instructions.
2. Identify the current GitHub repository and working branch.
3. Check the working tree for existing uncommitted changes.
4. Read `NEXT.md` if present.
5. Retrieve relevant GitHub Issues and verify their current state.
6. Identify active work in progress and outstanding blockers.
7. Determine the next task.

Do not perform a full repository or backlog audit unless necessary. Prioritize explicit user requests over the queue, consult the queue + GitHub when asked what is next, and select the highest-leverage READY task only when autonomous backlog execution is explicitly requested. Do not begin unrelated implementation merely because `NEXT.md` lists available work.

#### Next-Task Decision Rules

Prefer tasks that are:

1. Critical, when a genuine urgent issue exists.
2. Already in progress and appropriate to finish.
3. Ready for immediate implementation.
4. Blocking important downstream work.
5. High-impact relative to implementation effort.
6. Capable of reducing meaningful technical uncertainty.

Respect dependencies, avoid unnecessary context switching, and never pick a blocked task merely for higher priority. When nothing is ready, recommend the smallest useful blocker-resolution or investigation task.

### 3. Definition of Ready

Before starting an issue, verify:

- [ ] Objective is clear.
- [ ] Acceptance criteria are testable.
- [ ] Scope is appropriately bounded.
- [ ] Dependencies are satisfied.
- [ ] No unresolved decision prevents execution.
- [ ] Relevant implementation context is available.
- [ ] Verification expectations are known.

Resolve minor implementation details via repository inspection; refine or clarify missing major requirements before coding instead of inventing them.

### 4. NOW / NEXT / LATER Queue (`NEXT.md`)

Keep `NEXT.md` concise enough to review at session start:

- **NOW:** Exactly one primary recommended task with issue number/link, Priority (`P0`-`P3`), Effort (`XS`-`XL`), Readiness, Reason for selection, First concrete action, Definition of Done, and important downstream tasks unblocked.
- **NEXT:** The next 3-5 tasks ordered by dependencies and value, with links, priorities, effort sizes, blockers, and parallelizable items noted.
- **LATER:** Links to relevant GitHub Issues or Project views rather than reproducing the backlog.
- **BLOCKERS:** Meaningful blockers and unresolved decisions affecting immediate work.

#### Refresh Procedure

Update `NEXT.md` on meaningful execution-state changes (task completion, new blocking dependency, major priority shift, important discovery, or backlog refinement) -- never after trivial edits:

1. Retrieve current GitHub Issue state.
2. Remove completed, obsolete, or superseded tasks from the immediate queue.
3. Reevaluate dependencies and readiness.
4. Identify the highest-leverage actionable task.
5. Select exactly one `NOW` task and 3-5 `NEXT` tasks.
6. Update `NEXT.md` without overwriting unrelated local changes, verifying all issue numbers and links.

Treat regeneration as synchronization from GitHub, never the reverse. If GitHub is unavailable, preserve the existing queue or mark the result unverified.

### 5. Implementation Workflow

1. Retrieve the latest GitHub Issue details.
2. Inspect relevant source code and tests.
3. Confirm implementation scope and follow existing conventions.
4. Implement the smallest complete solution satisfying acceptance criteria.
5. Add or update tests and run verification.
6. Review changes for unintended consequences.
7. Capture out-of-scope defects, debt, or blockers by creating dedicated GitHub Issues.
8. Record implementation decisions in `docs/decisions.md` (or an ADR when architectural) within the same PR.
9. Synchronize GitHub and `NEXT.md` as appropriate.

Do not combine unrelated backlog tasks into one implementation unless explicitly justified.

### 6. Keep GitHub Issues Updated

- **When Starting Work:** Mark in progress, respect existing assignee/ownership, reference the issue in branch/PR, and record material scope clarifications.
- **Discovering Missing Work:** If a finding falls outside current acceptance criteria, search existing issues to avoid duplicates, create a new scoped GitHub Issue (`P0`-`P3`, `<type>(<scope>): <summary>`, lean template) without asking approval during authorized coding work in `gordonpn/*` repos (falling back to `NEXT.md` under `LATER` elsewhere), cross-reference the origin issue/PR, update `NEXT.md` (`LATER` or `NEXT`), and reassess the queue only for a `P0` blocker invalidating current work. Never mutate GitHub during read-only reviews or informational questions.
- **When Blocked:** Identify the blocker, update the issue/project status, record a resolution path and prerequisite links, and move to another task only when continued work is authorized.
- **When Completing Work:** Verify acceptance criteria, run tests/checks, confirm scope, link commits/PRs, and record remaining work. Close issues only when explicitly authorized and after acceptance criteria are verified and the PR is merged (never report an unmerged PR as fully closed). Never claim unexecuted verification.

### 7. Avoid Unnecessary Replanning

- **Level 1 (Task Execution):** Verify selected issue, execute, validate, update GitHub, refresh queue if needed. Do not audit unrelated issues.
- **Level 2 (Incremental Refinement):** Use when dependencies shift, discoveries affect nearby work, or the immediate queue is unrealistic. Review affected issues and direct dependencies only.
- **Level 3 (Comprehensive Backlog Audit):** Use only when requested, or recommend when objectives change, architecture invalidates the backlog, implementation diverges substantially, or stale duplicates break ordering.

### 8. Synchronization, Idempotency, and Concurrency

Before writing to GitHub: check current state, preserve existing descriptions/edits, follow repo labels and Project fields, avoid duplicate issues/comments, avoid recreating closed tasks without justification, reread recently modified issues when concurrent edits are possible, apply updates idempotently, and verify mutations succeeded. Never modify issues in unrelated repositories, auto-start multiple tasks, or confuse planned/implemented/verified/reviewed/merged states. Report write failures accurately.

### 9. Session Completion Protocol

At the end of a substantive implementation session:

- **A. Implementation Summary:** Report what changed, which issue was addressed, what was verified, and what remains incomplete.
- **B. GitHub Status:** Report issues updated/created, issues closed (if any), related PRs, remaining blockers, and any sync failures.
- **C. Next Task:** Identify the next actionable issue from the latest state and conclude with:

`**WORK ON THIS NEXT: [Issue Number] - [Issue Title]**`

Add a brief explanation of why it is next (or the immediate blocker-resolution action if blocked). Do not auto-start the next task unless continued/autonomous execution was requested.

### 10. Interaction and Authorization Rules

- For informational questions, explanations, or read-only reviews, do not modify GitHub or local files.
- For requested coding work, keep the associated issue status and execution queue synchronized within available permissions.
- For explicitly requested backlog refinement, execute the authorized GitHub mutations rather than only proposing them.
- Never delete issues, force-push, modify unrelated repos, or alter organization-wide settings.
- Respect the user's current request over standing backlog preferences, escalate consequential ambiguities, and report missing GitHub auth/permissions honestly.

### Core Principle

Always make the next actionable task obvious without turning every coding session into a planning session: GitHub defines the work, `NEXT.md` identifies what matters now, implementation advances the project, verification establishes completion, and GitHub sync preserves progress.

## Documentation Workflows

- **Actionable Investigation & Documentation Outcomes:** Every investigation/spike issue and documentation PR must state what was learned, supporting evidence and limitations, how findings apply to the project, and the recommended next action (explicitly recommending no change when justified). For concrete follow-ups, search and update/link existing issues or create scoped issues with priority, effort, and testable acceptance criteria. Never create speculative tasks merely to produce follow-ups.
- **Architectural Decision Protocol (ADRs):** Where a project adopts ADRs, store sequentially numbered records under `docs/adr/` and maintain an index table in `docs/adr/README.md` (`ID`, `Title`, `Status`: `Proposed`/`Accepted`/`Superseded`/`Rejected`, `Date`, `Decision`). Each ADR includes: `Context`, `Decision` (plus rejected alternatives with rationale), `Consequences`, and `Reconsideration Triggers`. Do not reopen accepted decisions unless recorded reconsideration triggers occur.
- **Operational Runbooks:** When introducing deployment steps, background daemons, or infrastructure components, document setup, execution commands, and diagnostics in `docs/RUNBOOK.md` or under `/docs/`.
