---
name: delegate-coding-agents
description: Delegate scoped coding work from Codex to OpenCode or Gemini CLI, or from Antigravity CLI to OpenCode, in isolated worktrees. Use automatically when a bounded subtask benefits from an independent worker.
---

# Delegate coding agents (Codex and Antigravity)

## Coordinator and routing

The **agent started by the user is the orchestrator**, and always owns final design decisions, reviews, integration, and test verification.

| Orchestrator | Permitted workers | Plan | Build |
| --- | --- | --- | --- |
| Codex | OpenCode, Gemini CLI | yes | yes |
| Antigravity CLI | OpenCode | yes | yes |

Do **not** call a harness from inside its delegated invocation, recursively delegate, or hand tasks back in a loop. Honor explicit user choices. Automatically consider delegation on nontrivial tasks, but skip low-value overhead. Keep confidential work code away from external inference.

For Codex, route sequentially and stop after the first worker completes successfully:

1. OpenCode with `opencode/deepseek-v4.1-flash-free` at high variant.
2. Only after a clear quota/rate-limit failure, retry with OpenCode `opencode/glm-5.3-flash-free`.
3. If that is also explicitly quota/rate limited, use Gemini CLI with its configured account/model.
4. If Gemini CLI is unavailable, quota-limited, or cannot complete, continue with Codex directly.

Never move to the next worker for task errors, test failures, or an ambiguous result. Do not parallelize providers or silently use a paid model. These OpenCode free offers can change; confirm the selected model remains available before use. Do not invoke Antigravity CLI (`agy -p`) from Codex under a consumer plan. Copilot CLI is not part of this route.

## Calling the script

Use the script in **the current skill installation**. Codex default install: `~/.agents/skills/delegate-coding-agents`; agy CLI default install: `~/.gemini/config/skills/delegate-coding-agents`.

```bash
# Codex delegates a read-only plan to OpenCode
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent opencode --mode plan \
  --id pagination-plan --task 'Inspect cursor handling; propose concrete design and tests.'

# After an explicit OpenCode quota/rate-limit failure, try the free GLM model
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent opencode --mode build \
  --model opencode/glm-5.3-flash-free \
  --id pagination-api --task 'Implement cursor-based pagination and tests in API module.'

# After an explicit OpenCode quota/rate-limit failure, use Gemini CLI
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent gemini --mode build \
  --id validation-tests --task 'Implement the assigned acceptance criteria and tests.'
```

Supported flags: `--orchestrator codex|agy`, `--agent opencode|gemini`, `--mode plan|build`, `--task` or `--task-file`, optional `--id`, `--model`, `--base`, `--automatic`. Gemini CLI is available only as a Codex worker. `--automatic` blocks external-model calls unless the repository owner has set local Git configuration `agents.delegationAllowed=true`. Explicit manual calls may omit `--automatic`; still respect data handling permissions and user intent.

OpenCode defaults to `opencode/deepseek-v4.1-flash-free` with high variant. GLM fallback is passed explicitly with `--model opencode/glm-5.3-flash-free` and uses the model's default variant. Gemini CLI uses its configured default model unless `--model` or `GEMINI_DELEGATE_MODEL` is supplied. OpenCode's `OPENCODE_DELEGATE_MODEL` is an intentional override, not an automatic fallback. Never silently fall back to paid models.

## Delegate specification

State: objective, acceptance criteria, owned files, forbidden files, compatibility constraints, permitted verification commands, and required output. Prefer a task file outside the checkout for longer prompts. Explicitly say if a task is plan-only or build.

- **Plan:** explain implementation order, affected files/functions, tradeoffs, tests, and risks. No working-tree modifications.
- **Build:** create/edit files only within worktree scope, add tests, run allowed checks; do not commit/push/merge/rebase. Return changed files, test outcomes and failures.

Gemini CLI runs with `--approval-mode auto_edit` for builds, which approves edit tools but does not auto-approve shell commands. It is not run with YOLO mode. Plan requests remain prompt-constrained and the runner rejects any plan worktree that changes files.

The wrapper creates an external Git worktree from the **committed** base revision, refuses dirty starting checkouts, and leaves build changes uncommitted on a `delegate/...` branch. The orchestrator inspects `DELEGATION_RESULT`, report/log files, `git status`, `git diff`, new files, and denied tool commands. Exit 0 means transport success, not correct code. If approved, stage only intended files, commit in the worktree, and cherry-pick to the integration branch. Run repository tests and the existing Alibaba Open Code Review pre-PR gate (if present) before PR creation.

## Safety and practical limits

- Automatic delegation requires explicit per-repository opt-in: `git config --local agents.delegationAllowed true`. This setting is in local Git config, not committed to the repository.
- Worktrees do **not** sandbox host credentials, Git metadata, filesystem, or network. Keep narrowly scoped shell permissions; do not enable blanket unattended execution.
- If there is no isolated, valid committed state, do not stash/reset or discard user changes to force delegation.
- Run one external worker at a time. Avoid recursive delegation and indefinite retry loops. Fallback only on clear quota/rate-limit failures; if all free routes fail, report and continue with the orchestrator if possible.
- Never treat claimed passing tests as evidence without checking command output; agy headless may soft-deny shell commands.
