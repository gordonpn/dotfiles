---
trigger: always_on
description: Automatically delegate engineering subtasks to OpenCode under Antigravity CLI supervision.
---

# Delegation-First OpenCode routing when Antigravity is the orchestrator

When tasked with repository exploration, architecture analysis, refactoring, test writing, or feature implementation, Antigravity operates in a delegation-first posture in repositories where delegation is permitted (`agents.delegationAllowed=true`). OpenCode handles initial planning and implementation in isolated worktrees using free models; Antigravity supervises, reviews, integrates, and verifies the final changes.

## Delegation-First Rules

1. **Default to OpenCode:** Whenever an engineering task requires codebase exploration, design analysis, test drafting, or code modification, delegate the subtask to OpenCode before attempting to write code directly.
2. **Phase Routing:**
   - Use OpenCode `--mode plan` for initial repository exploration, architecture analysis, trade-off evaluation, and test plan creation.
   - Use OpenCode `--mode build` for generating tests, boilerplate, mechanical refactors, documentation, and separable implementation slices.
3. **Orchestrator Scope:** Antigravity owns cross-cutting architectural validation, final review, test verification, cherry-picking approved worktree commits, and PR delivery. Do not duplicate OpenCode's exploration or draft work when delegation is available.
4. **Eligibility Gate:** Delegate only when the repository has local Git configuration `agents.delegationAllowed=true` and a clean working tree (`git status --porcelain` empty). If the working tree is dirty or delegation is disabled, execute directly. Never bypass the opt-in gate for confidential or employer code.
5. **Defer to User Intent:** When the user explicitly requests direct execution, asks Antigravity not to delegate, or specifies a different workflow, respect their choice and execute directly without delegating.

## Execution

- Invoke the installed `delegate-coding-agents` skill via `scripts/delegate.sh`:
  ```bash
  # Plan mode (investigation and architecture):
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent opencode --mode plan --automatic \
    --id explore-feature --task 'Investigate module structure and propose tests.'

  # Build mode (mechanical refactors and tests):
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent opencode --mode build --automatic \
    --id implement-tests --task 'Implement unit tests for the validator.'
  ```
- Give the worker explicit scope, acceptance criteria, verification commands, and prohibited file areas.
- After the run completes, inspect `DELEGATION_RESULT`, reports, diffs, and untracked files. Independently verify the proposed changes against repository invariants and tests.
- Review the worktree changes. Stage only approved files in the `delegate/...` worktree, commit them there, and cherry-pick that commit into the orchestrator branch; never blindly apply unreviewed diffs.
- Preserve the configured Alibaba Open Code Review gate. Never auto-push or create a PR unless asked.
