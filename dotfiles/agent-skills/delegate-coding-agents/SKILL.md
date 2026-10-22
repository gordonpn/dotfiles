---
name: delegate-coding-agents
description: Delegate scoped coding investigation, implementation planning, code generation, tests, and refactoring from Codex CLI or Antigravity CLI to OpenCode (DeepSeek Flash); Codex may also delegate to Antigravity. Use automatically when a bounded subtask benefits from a lower-cost agent or independent worktree-based implementation.
---

# Delegate coding agents (Codex and Antigravity)

## Coordinator and routing

The **agent started by the user is the orchestrator**, and always owns final design decisions, reviews, integration, and test verification.

| Orchestrator | Permitted workers | Plan | Build |
| --- | --- | --- | --- |
| Codex | OpenCode / DeepSeek Flash, Antigravity CLI | yes | yes |
| Antigravity CLI | OpenCode / DeepSeek Flash | yes | yes |

Do **not** call a harness from inside its delegated invocation, recursively delegate, or hand tasks back in a loop. Honor explicit user choices. Automatically consider delegation on nontrivial tasks, but skip low-value overhead. In all cases, keep confidential work code away from external free inference unless approved.

## Calling the script

Use the script in **the current skill installation**. Codex default install: `~/.agents/skills/delegate-coding-agents`; agy CLI default install: `~/.gemini/config/skills/delegate-coding-agents`.

```bash
# Codex delegates a read-only plan to OpenCode
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent opencode --mode plan \
  --id pagination-plan --task 'Inspect cursor handling; propose concrete design and tests.'

# Codex delegates an implementation to Antigravity
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent agy --mode build \
  --id pagination-api --task 'Implement cursor-based pagination and tests in API module.'

# Antigravity delegates an implementation to OpenCode
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator agy --automatic --agent opencode --mode build \
  --id validation-tests --task 'Add validation edge-case tests in src/test only.'
```

Supported flags: `--orchestrator codex|agy`, `--agent opencode|agy`, `--mode plan|build`, `--task` or `--task-file`, optional `--id`, `--model`, `--base`, `--automatic`. `--automatic` blocks external-model calls unless the repository owner has set local Git configuration `agents.delegationAllowed=true`. Explicit manual calls may omit `--automatic`; still respect data handling permissions and user intent.

OpenCode defaults to `opencode/deepseek-v4.1-flash-free` with `--variant high`; agy defaults to `gemini-3.8-flash-high` with `--effort high`. Use `OPENCODE_DELEGATE_MODEL` or `AGY_DELEGATE_MODEL` only for an intentional model override. Never silently fall back to paid models.

## Delegate specification

State: objective, acceptance criteria, owned files, forbidden files, compatibility constraints, permitted verification commands, and required output. Prefer a task file outside the checkout for longer prompts. Explicitly say if a task is plan-only or build.

- **Plan:** explain implementation order, affected files/functions, tradeoffs, tests, and risks. No working-tree modifications.
- **Build:** create/edit files only within worktree scope, add tests, run allowed checks; do not commit/push/merge/rebase. Return changed files, test outcomes and failures.

The wrapper creates an external Git worktree from the **committed** base revision, refuses dirty starting checkouts, and leaves build changes uncommitted on a `delegate/...` branch. The orchestrator inspects `DELEGATION_RESULT`, report/log files, `git status`, `git diff`, new files, and denied tool commands. Exit 0 means transport success, not correct code. If approved, stage only intended files, commit in the worktree, and cherry-pick to the integration branch. Run repository tests and the existing Alibaba Open Code Review pre-PR gate (if present) before PR creation.

## Safety and practical limits

- Automatic delegation requires explicit per-repository opt-in: `git config --local agents.delegationAllowed true`. This setting is in local Git config, not committed to the repository.
- Worktrees do **not** sandbox host credentials, Git metadata, filesystem, or network. Keep narrowly scoped shell permissions; do not enable blanket unattended execution.
- If there is no isolated, valid committed state, do not stash/reset or discard user changes to force delegation.
- Avoid concurrent editing of overlapping files, recursive delegation, and indefinite retry loops. If free quotas run out, report and continue with the orchestrator if possible.
- Never treat claimed passing tests as evidence without checking command output; agy headless may soft-deny shell commands.
