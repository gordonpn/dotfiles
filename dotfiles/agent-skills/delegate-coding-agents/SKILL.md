---
name: delegate-coding-agents
description: Delegate scoped coding work from Codex or Antigravity CLI to OpenCode, GitHub Copilot (via OpenCode), or Gemini CLI in isolated worktrees. Use automatically when a bounded subtask benefits from an independent worker.
---

# Delegate coding agents (Codex and Antigravity)

## Coordinator and routing

The **agent started by the user is the orchestrator**, and always owns final design decisions, reviews, integration, and test verification.

| Orchestrator | Permitted workers | Plan | Build |
| --- | --- | --- | --- |
| Codex | OpenCode, GitHub Copilot (via OpenCode), Gemini CLI | yes | yes |
| Antigravity CLI | OpenCode, GitHub Copilot (via OpenCode) | yes | yes |

Do **not** call a harness from inside its delegated invocation, recursively delegate, or hand tasks back in a loop. Honor explicit user choices. Automatically consider delegation on nontrivial tasks, but skip low-value overhead. Keep confidential work code away from external inference.

For Codex and Antigravity CLI, route sequentially and stop after the first worker completes successfully:

1. OpenCode with `opencode/deepseek-v4.1-flash-free` at high variant, automatically cycling through OpenCode free models (`opencode/glm-5.3-flash-free`, `opencode/minimax-m3.1-flash-free`, `opencode/qwen3.6-plus-free`) and 0x-included GitHub Copilot models (`github-copilot/gpt-4.1`, `github-copilot/gpt-4o`, `github-copilot/gpt-4o-mini`) on classified provider, quota, rate-limit, model-availability, capacity/overload, or HTTP 429/502/503/504 failures.
2. Direct GitHub Copilot delegation (`--agent copilot`) is also available for both Codex and Antigravity CLI, cycling through `github-copilot/gpt-4.1`, `github-copilot/gpt-4o`, and `github-copilot/gpt-4o-mini`.
3. For Codex only: if all OpenCode and Copilot free routes fail with classified provider, quota, rate-limit, model-availability, or service/capacity errors, use Gemini CLI with its configured account/model.
4. If all permitted routes are unavailable, quota-limited, or cannot complete, continue with the orchestrator directly.

Authentication and provider-initialization errors are hard stops: surface a
message directing the user to check login and provider credentials/configuration,
and do not try another model or Gemini.

Never move to the next worker for task errors, test failures, or an ambiguous result. Do not parallelize providers or silently use a paid model. These OpenCode and Copilot free offers can change; confirm the selected model remains available before use. Do not invoke Antigravity CLI (`agy -p`) from Codex under a consumer plan.

## Calling the script

Use the script in **the current skill installation**. Codex default install: `~/.agents/skills/delegate-coding-agents`; agy CLI default install: `~/.gemini/config/skills/delegate-coding-agents`.

```bash
# Codex delegates a read-only plan to OpenCode
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent opencode --mode plan \
  --id pagination-plan --task 'Inspect cursor handling; propose concrete design and tests.'

# Codex or Antigravity delegates directly to GitHub Copilot (via OpenCode)
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator agy --automatic --agent copilot --mode build \
  --id pagination-api --task 'Implement cursor-based pagination and tests in API module.'

# After an explicit OpenCode/Copilot quota/rate-limit failure on Codex, use Gemini CLI
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent gemini --mode build \
  --id validation-tests --task 'Implement the assigned acceptance criteria and tests.'
```

Supported flags: `--orchestrator codex|agy`, `--agent opencode|copilot|gemini`, `--mode plan|build`, `--task` or `--task-file`, optional `--id`, `--model`, `--base`, `--automatic`. Gemini CLI is available only as a Codex worker. `--automatic` blocks external-model calls unless the repository owner has set local Git configuration `agents.delegationAllowed=true`. Explicit manual calls may omit `--automatic`; still respect data handling permissions and user intent.

OpenCode (`--agent opencode`) defaults to `opencode/deepseek-v4.1-flash-free` with high variant, automatically falling back across candidate free models (`opencode/glm-5.3-flash-free`, `opencode/minimax-m3.1-flash-free`, `opencode/qwen3.6-plus-free`, `github-copilot/gpt-4.1`, `github-copilot/gpt-4o`, `github-copilot/gpt-4o-mini`) only on classified provider, quota, rate-limit, model-availability, or capacity/service failures. GitHub Copilot (`--agent copilot`) runs via OpenCode and defaults to `github-copilot/gpt-4.1`, falling back to `github-copilot/gpt-4o` and `github-copilot/gpt-4o-mini`. `--model` pins a single model with no fallback; `OPENCODE_DELEGATE_MODEL` and `COPILOT_DELEGATE_MODEL` override only the first candidate in their respective default chains; `OPENCODE_DELEGATE_MODELS` and `COPILOT_DELEGATE_MODELS` replace the full candidate chains with comma-separated lists. Gemini CLI uses its configured default model unless `--model` or `GEMINI_DELEGATE_MODEL` is supplied. Never silently fall back to paid models.

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
- Run one external worker at a time. Avoid recursive delegation and indefinite retry loops. Authentication and provider-initialization errors are hard stops: surface a login/credential-configuration hint and do not try another model or Gemini. Fall back only on explicitly classified quota, rate-limit, model-availability, or capacity failures; if all free routes fail, report and continue with the orchestrator if possible.
- Never treat claimed passing tests as evidence without checking command output; agy headless may soft-deny shell commands.
