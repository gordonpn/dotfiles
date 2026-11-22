---
trigger: always_on
description: Codex-first routing for Antigravity CLI using the installed Codex plugin for read-only/continuity work and delegate.sh worktree isolation for builds.
---

# Codex-first routing

When the installed Codex plugin runner (`$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs`) is present, use it as the default worker for read-only/continuity requests, paired with `delegate.sh` for isolated-worktree implementation builds. If the Codex plugin runner is not installed on the machine, skip invoking it and route directly via `delegate.sh --orchestrator agy --agent codex`.

## Routing Rules

- Automatically delegate coding, debugging, planning, architecture discussions, refactoring, reviews, and technical research to Codex without requiring the user to mention Codex or use slash commands.
- When `$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs` exists, use it in read-only mode (`task`, `review`, `adversarial-review`, or `codex-rescue`) for questions, debugging, planning, architecture discussions, reviews, and technical research.
- Keep `delegate.sh` (`--orchestrator agy --agent codex --mode build`) as the default for implementation and refactoring that modifies files so workspace writes execute inside an isolated Git worktree (`--sandbox workspace-write`). Use Codex plugin `task --write` only when direct active-workspace edits are explicitly requested or outside a Git repository.
- Include the user's original request, relevant conversation context, project constraints, and previous decisions in every delegation prompt.
- Preserve continuity across follow-up conversations using `--resume-last` on the Codex plugin where supported.
- Use Antigravity primarily for orchestration, cross-cutting verification, reviewing and cherry-picking worktree commits, and presenting results.
- Defer to user intent if the user explicitly asks Antigravity to execute directly or use native `invoke_subagent`. Never send confidential or employer-restricted code to external inference without explicit permission.

## Automatic Fallback

If the Codex plugin fails with classified provider, quota, rate-limit, or model-availability errors, invoke `delegate.sh --orchestrator agy --agent opencode` directly so Codex is not retried redundantly. When `delegate.sh` is invoked with `--agent codex` (including when the Codex plugin runner is absent), it cascades automatically without blocking for confirmation:

1. **OpenCode Free Models:** Cycle through `opencode/deepseek-v4.1-flash-free` (high variant), `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, and `opencode/nemotron-3.5-lightning-free`.
2. **GitHub Copilot Student:** Fall back to first-party Copilot CLI with `--model auto`.
3. **Antigravity / `invoke_subagent`:** If all external workers fail with classified provider/quota errors, continue with native `invoke_subagent` or Antigravity directly and note the fallback in the response.
4. **Authentication Hard Stops:** Credential, permission, or provider initialization failures (`ProviderInitError`, HTTP 403, missing login) stop fallback immediately with actionable setup guidance (`codex login`, `/codex:setup`, `copilot login`, or OpenCode credentials).

Because `delegate.sh` snapshots committed `HEAD` and excludes uncommitted or untracked changes, if a rate-limit fallback for a review runs `delegate.sh --mode plan` on a dirty checkout, either include the uncommitted diff (and untracked file contents) in `--task` / `--task-file` or review the active checkout directly instead of relying solely on the dirty-base warning.

## Execution

- **Codex plugin (when `$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs` is present):**
  ```bash
  RUNNER="$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs"
  if [ -f "$RUNNER" ]; then
    node "$RUNNER" task --resume-last "<context, constraints, decisions, and request>"
    node "$RUNNER" review --base master
    node "$RUNNER" adversarial-review "<design focus>"
  fi
  ```
- **`delegate.sh` (isolated worktree build and automatic fallback chain):**
  ```bash
  # Primary isolated worktree build (or plan when plugin runner is absent):
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent codex --mode build \
    --id implement-slice --task '<context, constraints, decisions, and acceptance criteria>'

  # Direct fallback after a Codex plugin quota/rate-limit error (cascades OpenCode -> Copilot):
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent opencode --mode plan \
    --id fallback-analysis --task '<context, uncommitted diff if any, and request>'
  ```
- Inspect `DELEGATION_RESULT`, reports, diffs, and untracked files before integrating worktree changes. When `dirty_base=1` or `Overlapping dirty base files` is reported, reconcile overlapping hunks manually instead of overwriting base files or resetting local edits.
- Preserve the configured Alibaba Open Code Review gate before PR submission. Never auto-push or create a PR unless asked.
