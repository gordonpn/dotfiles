---
trigger: always_on
description: Codex-first routing for Antigravity CLI using the installed Codex plugin for read-only/continuity work and delegate.sh worktree isolation for builds.
---

# Codex-first routing

Use the installed Codex plugin (`$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs`) as the default worker for substantive user requests, paired with `delegate.sh` for isolated-worktree implementation builds.

## Routing Rules

- Automatically delegate coding, debugging, planning, architecture discussions, refactoring, reviews, and technical research to Codex without requiring the user to mention Codex or use slash commands.
- Use the Codex plugin in read-only mode (`task`, `review`, `adversarial-review`, or `codex-rescue`) for questions, debugging, planning, architecture discussions, reviews, and technical research.
- Keep `delegate.sh` (`--orchestrator agy --agent codex --mode build`) as the default for implementation and refactoring that modifies files so workspace writes execute inside an isolated Git worktree (`--sandbox workspace-write`). Use Codex plugin `task --write` only when direct active-workspace edits are explicitly requested or outside a Git repository.
- Include the user's original request, relevant conversation context, project constraints, and previous decisions in every delegation prompt.
- Preserve continuity across follow-up conversations using `--resume-last` on the Codex plugin where supported.
- Use Antigravity primarily for orchestration, cross-cutting verification, reviewing and cherry-picking worktree commits, and presenting results.
- Defer to user intent if the user explicitly asks Antigravity to execute directly or use native `invoke_subagent`. Never send confidential or employer-restricted code to external inference without explicit permission.

## Automatic Fallback

If Codex is unavailable or fails with classified provider, quota, rate-limit, or model-availability errors, fall back automatically without blocking for confirmation through `delegate.sh`:

1. **OpenCode Free Models:** Cycle through `opencode/deepseek-v4.1-flash-free` (high variant), `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, and `opencode/nemotron-3.5-lightning-free`.
2. **GitHub Copilot Student:** Fall back to first-party Copilot CLI with `--model auto`.
3. **Antigravity / `invoke_subagent`:** If all external workers fail with classified provider/quota errors, continue with native `invoke_subagent` or Antigravity directly and note the fallback in the response.
4. **Authentication Hard Stops:** Credential, permission, or provider initialization failures (`ProviderInitError`, HTTP 403, missing login) stop fallback immediately with actionable setup guidance (`codex login`, `/codex:setup`, `copilot login`, or OpenCode credentials).

## Execution

- **Codex plugin (read-only analysis, planning, debugging, review, continuity):**
  ```bash
  RUNNER="$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs"
  node "$RUNNER" task --resume-last "<context, constraints, decisions, and request>"
  node "$RUNNER" review "--base master"
  node "$RUNNER" adversarial-review "<design focus>"
  ```
- **`delegate.sh` (isolated worktree build and automatic fallback chain):**
  ```bash
  "$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
    --orchestrator agy --agent codex --mode build \
    --id implement-slice --task '<context, constraints, decisions, and acceptance criteria>'
  ```
- Inspect `DELEGATION_RESULT`, reports, diffs, and untracked files before integrating worktree changes. When `dirty_base=1` or `Overlapping dirty base files` is reported, reconcile overlapping hunks manually instead of overwriting base files or resetting local edits.
- Preserve the configured Alibaba Open Code Review gate before PR submission. Never auto-push or create a PR unless asked.
