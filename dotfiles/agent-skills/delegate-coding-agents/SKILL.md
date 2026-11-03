---
name: delegate-coding-agents
description: Delegate scoped coding work from Codex or Antigravity CLI to GitHub Copilot CLI, OpenCode, or Gemini CLI in isolated worktrees. Use automatically when a bounded subtask benefits from an independent worker.
---

# Delegate coding agents (Codex and Antigravity)

## Coordinator and routing

The **agent started by the user is the orchestrator**, and always owns final design decisions, reviews, integration, and test verification.

| Orchestrator | Permitted workers | Plan | Build |
| --- | --- | --- | --- |
| Codex | GitHub Copilot CLI, OpenCode, Gemini CLI | yes | yes |
| Antigravity CLI | GitHub Copilot CLI, OpenCode | yes | yes |

Do **not** call a harness from inside its delegated invocation, recursively delegate, or hand tasks back in a loop. Honor explicit user choices. Automatically consider delegation on nontrivial tasks, but skip low-value overhead. Keep confidential work code away from external inference.

For Codex and Antigravity CLI, route sequentially and stop after the first worker completes successfully:

1. First-party GitHub Copilot CLI (`--agent copilot`) with `--model auto`.
2. On classified provider, quota, rate-limit, model-availability, or capacity failures only, fall back to OpenCode free models: `opencode/deepseek-v4.1-flash-free` at high variant, then `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, and `opencode/nemotron-3.5-lightning-free`.
3. For Codex only: after all OpenCode candidates fail with classified provider, quota, rate-limit, model-availability, or capacity errors, use Gemini CLI with its configured account/model.
4. If all permitted routes are unavailable or cannot complete, continue with the orchestrator directly.

Authentication and provider-initialization errors are hard stops: surface a
message directing the user to check login and provider credentials/configuration,
and do not try another model or Gemini.

Copilot Student supports Auto model selection only and excludes third-party agents, so use the first-party Copilot CLI instead of explicit Copilot model IDs through OpenCode. Never move to the next worker for authentication/provider-initialization failures, task errors, test failures, or an ambiguous result. Do not parallelize providers or silently use a paid model. OpenCode free offers can change; confirm availability before use. Do not invoke Antigravity CLI (`agy -p`) from Codex under a consumer plan.

## Calling the script

Use the script in **the current skill installation**. Codex default install: `~/.agents/skills/delegate-coding-agents`; agy CLI default install: `~/.gemini/config/skills/delegate-coding-agents`.

```bash
# Codex delegates to Copilot CLI Auto; OpenCode free models are its classified-failure fallback
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent copilot --mode plan \
  --id pagination-plan --task 'Inspect cursor handling; propose concrete design and tests.'

# Explicit OpenCode-only route
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent opencode --mode build \
  --id pagination-api --task 'Implement cursor-based pagination and tests in API module.'

# After Copilot Auto and every OpenCode free candidate fail with classified errors, use Gemini CLI
"$HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator codex --automatic --agent gemini --mode build \
  --id validation-tests --task 'Implement the assigned acceptance criteria and tests.'
```

Supported flags: `--orchestrator codex|agy`, `--agent opencode|copilot|gemini`, `--mode plan|build`, `--task` or `--task-file`, optional `--id`, `--model`, `--base`, `--automatic`. Gemini CLI is available only as a Codex worker. `--automatic` blocks external-model calls unless the repository owner has set local Git configuration `agents.delegationAllowed=true`. Explicit manual calls may omit `--automatic`; still respect data handling permissions and user intent.

GitHub Copilot (`--agent copilot`) runs first-party Copilot CLI with `--model auto`; Student-plan access is Auto-only. Plans deny write and shell tools. Builds allow file edits but deny shell commands, so the orchestrator must run verification. Classified provider, quota, rate-limit, model-availability, or capacity failures advance to OpenCode. OpenCode (`--agent opencode`) defaults to `opencode/deepseek-v4.1-flash-free` with high variant, then tries `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, and `opencode/nemotron-3.5-lightning-free` on those same classified failures. `--model` pins an OpenCode model; `OPENCODE_DELEGATE_MODEL` overrides its first candidate and `OPENCODE_DELEGATE_MODELS` replaces its chain with comma-separated models. Gemini CLI uses its configured default model unless `--model` or `GEMINI_DELEGATE_MODEL` is supplied. Never silently fall back to paid models.

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
