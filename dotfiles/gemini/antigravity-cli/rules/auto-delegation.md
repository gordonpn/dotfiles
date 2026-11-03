---
trigger: always_on
description: Automatically delegate engineering subtasks to Copilot CLI and OpenCode under Antigravity CLI supervision.
---

# Delegation-First Routing when Antigravity is the orchestrator

When a useful bounded subtask is available, Antigravity delegates first to first-party GitHub Copilot CLI with `--model auto`. In repositories where delegation is permitted (`agents.delegationAllowed=true`), classified provider, quota, rate-limit, model-availability, or capacity failures fall back sequentially to OpenCode's zero-cost models: DeepSeek V4.1 Flash Free (high), GLM-5.3 Flash Free, MiniMax M3.1 Flash Free, then Qwen3.6 Plus Free. Copilot Student supports Auto selection only and excludes third-party agents, so never invoke Copilot models through OpenCode. Authentication and provider-initialization errors are hard stops. Antigravity supervises, reviews, integrates, and verifies the final changes.

## Delegation-First Rules

1. **Default to Copilot CLI, then OpenCode:** For a useful bounded engineering task, start with GitHub Copilot CLI (`--agent copilot --model auto`). Use the OpenCode fallback chain only for classified service failures; stop and surface actionable login/configuration guidance on authentication or provider-initialization failures.
2. **Phase Routing:**
   - Use `--mode plan` for initial repository exploration, architecture analysis, trade-off evaluation, and test plan creation.
   - Use `--mode build` for generating tests, boilerplate, mechanical refactors, documentation, and separable implementation slices.
3. **Orchestrator Scope:** Antigravity owns cross-cutting architectural validation, final review, test verification, cherry-picking approved worktree commits, and PR delivery. Do not duplicate the worker's exploration or draft work when delegation is available.
4. **Eligibility Gate:** Delegate only when the repository has local Git configuration `agents.delegationAllowed=true` and a clean working tree (`git status --porcelain` empty). If the working tree is dirty or delegation is disabled, execute directly. Never bypass the opt-in gate for confidential or employer code.
5. **Defer to User Intent:** When the user explicitly requests direct execution, asks Antigravity not to delegate, or specifies a different workflow, respect their choice and execute directly without delegating.

## Execution

- Invoke the installed `delegate-coding-agents` skill via `scripts/delegate.sh`:
  ```bash
  # Copilot CLI Auto plan mode; classified service failures advance to OpenCode:
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent copilot --model auto --mode plan --automatic \
    --id explore-feature --task 'Investigate module structure and propose tests.'

  # Build mode (mechanical refactors and tests):
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent copilot --model auto --mode build --automatic \
    --id implement-tests --task 'Implement unit tests for the validator.'
  ```
- Give the worker explicit scope, acceptance criteria, verification commands, and prohibited file areas.
- After the run completes, inspect `DELEGATION_RESULT`, reports, diffs, and untracked files. Independently verify the proposed changes against repository invariants and tests.
- Review the worktree changes. Stage only approved files in the `delegate/...` worktree, commit them there, and cherry-pick that commit into the orchestrator branch; never blindly apply unreviewed diffs.
- Preserve the configured Alibaba Open Code Review gate. Never auto-push or create a PR unless asked.
