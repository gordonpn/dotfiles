---
trigger: always_on
description: Automatically delegate engineering subtasks to OpenCode under Antigravity CLI supervision.
---

# Delegation-First OpenCode routing when Antigravity is the orchestrator

When tasked with repository exploration, architecture analysis, refactoring, test writing, or feature implementation, Antigravity operates in a delegation-first posture in repositories where delegation is permitted (`agents.delegationAllowed=true`). OpenCode handles initial planning and implementation in isolated worktrees using free models; Antigravity supervises, reviews, integrates, and verifies the final changes.

## Delegation-First Rules

1. **Default to OpenCode:** Whenever an engineering task requires codebase exploration, design analysis, test drafting, or code modification, delegate the subtask to OpenCode before attempting to write code directly.
2. **Phase Routing:**
   - Use OpenCode `--mode plan` (or `scripts/deepseek-analyze.sh`) for initial repository exploration, architecture analysis, trade-off evaluation, and test plan creation.
   - Use OpenCode `--mode build` for generating tests, boilerplate, mechanical refactors, documentation, and separable implementation slices.
3. **Orchestrator Scope:** Antigravity owns cross-cutting architectural validation, final review, test verification, integration cherry-picking, and PR delivery. Do not duplicate OpenCode's exploration or draft work when delegation is available.
4. **Eligibility Gate:** Delegate only when the repository has local Git configuration `agents.delegationAllowed=true` and a clean working tree (`git status --porcelain` empty). If the working tree is dirty or delegation is disabled, execute directly. Never bypass the opt-in gate for confidential or employer code.

## Execution

- Invoke the installed `delegate-coding-agents` skill via `scripts/delegate.sh` or `scripts/deepseek-analyze.sh`:
  `"$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" --orchestrator agy --agent opencode --mode plan|build --automatic --id <meaningful-id> --task '<bounded-task>'`
- Give the worker explicit scope, acceptance criteria, verification commands, and prohibited file areas.
- After the run completes, inspect `DELEGATION_RESULT`, reports, diffs, and untracked files. Independently verify the proposed changes against repository invariants and tests.
- Integrate approved work into the orchestrator branch; never blindly apply unreviewed diffs.
- Preserve the configured Alibaba Open Code Review gate. Never auto-push or create a PR unless asked.
