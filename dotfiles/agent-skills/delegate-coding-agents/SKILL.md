---
name: delegate-coding-agents
description: Delegate scoped coding work across Antigravity CLI, Codex, OpenCode, and GitHub Copilot Student in isolated worktrees. Use automatically when a bounded subtask benefits from an independent worker.
---

# Delegate coding agents (Codex and Antigravity)

## Coordinator and routing

The **agent started by the user is the orchestrator**, and always owns final design decisions, reviews, integration, and test verification.

| Orchestrator | Permitted workers | Plan | Build |
| --- | --- | --- | --- |
| Antigravity CLI | Codex, OpenCode, GitHub Copilot Student | yes | yes |
| Codex | OpenCode, GitHub Copilot Student | yes | yes |

Do **not** call a harness from inside its delegated invocation, recursively delegate, or hand tasks back in a loop. Honor explicit user choices. Prefer the Codex plugin (when installed) for read-only/continuity work and `delegate.sh` for isolated builds over same-harness `invoke_subagent` on nontrivial coding tasks, skipping low-value overhead. Keep confidential work code away from external inference.

For Antigravity CLI:

1. **Read-only plans, reviews, debugging, and continuity:** When the user-installed Codex plugin runner (`$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs`) exists, route via `node "$RUNNER" task|review|adversarial-review` (adding `--resume-last` on follow-ups). If the plugin runner is absent, fall back to `delegate.sh --orchestrator agy --agent codex --mode plan`.
2. **Isolated-worktree implementation builds and quota fallbacks:** Route via `delegate.sh` sequentially through `codex -> opencode -> github copilot student` (or pass `--agent opencode` directly after a Codex plugin quota/rate-limit failure so Codex is not retried):
   - Codex CLI non-interactive execution (`codex exec` in isolated worktree with `--sandbox read-only` or `--sandbox workspace-write`).
   - On classified provider, quota, rate-limit, or model-availability failure, retry across OpenCode candidate free models (`opencode/deepseek-v4.1-flash-free` with high variant, `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, `opencode/nemotron-3.5-lightning-free`).
   - If all OpenCode candidate free models fail with classified provider/quota errors, use first-party GitHub Copilot CLI under the Student plan with `--model auto`.
   - If Copilot Student fails or is unavailable, continue with native `invoke_subagent` or directly with Antigravity.

For Codex, route sequentially: OpenCode free models first, then GitHub Copilot Student (`--model auto`). Codex cannot delegate to Codex.

Authentication and provider-initialization errors are hard stops: show a message directing the user to check login and provider credentials/configuration (`codex login`, `copilot login`, or OpenCode configuration), and do not continue fallback. Never move to the next worker for task errors, test failures, or an ambiguous result. Do not parallelize providers or silently use a paid model. Do not invoke Antigravity CLI (`agy -p`) from Codex under a consumer plan.

## Calling the script

Use the script in **the current skill installation**. Codex default install: `~/.agents/skills/delegate-coding-agents`; agy CLI default install: `~/.gemini/config/skills/delegate-coding-agents`.

```bash
# Antigravity read-only task, review, or follow-up via Codex plugin (when installed)
RUNNER="$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs"
if [ -f "$RUNNER" ]; then
  node "$RUNNER" task --resume-last 'Inspect cursor handling; propose concrete design and tests.'
fi

# Antigravity delegates a read-only plan via delegate.sh (when plugin is absent, or --agent opencode after plugin quota error)
"$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator agy --agent codex --mode plan \
  --id pagination-plan --task 'Inspect cursor handling; propose concrete design and tests.'

# Antigravity delegates an isolated build with wrapper-owned verification
"$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator agy --agent codex --mode build \
  --id pagination-api --verify 'just test' \
  --task 'Implement cursor-based pagination and tests in API module.'

# Explicit worker pin (e.g. Copilot Student with --model auto)
"$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh" \
  --orchestrator agy --agent copilot --mode plan \
  --id copilot-review --task 'Review test coverage and edge cases.'
```

Supported flags: `--orchestrator codex|agy`, `--agent codex|opencode|copilot`, `--mode plan|build`, `--task` or `--task-file`, optional `--id`, `--model`, `--base`, `--automatic` (compatibility no-op), `--mcp-profile`, `--verify <cmd>` (`--mode build` only), `--verify-timeout <seconds>` (default `120`). Codex worker is available only for Antigravity orchestrator. Respect repository data-handling permissions and user intent before sending code to external models.

OpenCode defaults to `opencode/deepseek-v4.1-flash-free` with high variant, automatically falling back across candidate free models (`opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, `opencode/nemotron-3.5-lightning-free`) only on classified provider, quota, rate-limit, or model-availability failures. OpenCode free models execute anonymously and require no account, login, or credentials. One-shot OpenCode, Codex, and GitHub Copilot Student delegations apply a minimal MCP profile by default (`minimal`), disabling unrelated infrastructure, database, monitoring, and chat servers without mutating the user's interactive profiles. OpenCode receives an isolated configuration via `OPENCODE_CONFIG`, Codex receives ephemeral `-c mcp_servers.<name>.enabled=false` overrides, and Copilot Student receives ephemeral `--disable-builtin-mcps` (unless `github-mcp-server` is allowed) and `--disable-mcp-server <name>` overrides covering `${COPILOT_HOME:-$HOME/.copilot}/mcp-config.json` and repo-local `.mcp.json` / `.github/mcp.json` without touching authentication state in `config.json`. Override via `--mcp-profile minimal|none|full|PATH` or `DELEGATE_MCP_PROFILE` (`OPENCODE_DELEGATE_MCP_PROFILE` / `CODEX_DELEGATE_MCP_PROFILE` / `COPILOT_DELEGATE_MCP_PROFILE`). Custom allowed server sets can be defined with `DELEGATE_MCP_SERVERS` (`OPENCODE_DELEGATE_MCP_SERVERS` / `CODEX_DELEGATE_MCP_SERVERS` / `COPILOT_DELEGATE_MCP_SERVERS`). GitHub Copilot Student uses automatic model selection only (`--model auto`) and restricts model tool access to built-in commands via CLI flags (`--available-tools=view,grep,glob` in plan mode; `--available-tools=edit,view,grep,glob --allow-tool=write` in build mode; `--deny-tool=shell`). Even when MCP servers or deferred tool search are unavailable, Copilot Student completes repository tasks with those built-in tools; on classified quota/rate-limit/model unavailability, Copilot-first runs (`--agent copilot` without `--model`) proceed to the OpenCode free-model fallback chain for either orchestrator, while runs where Copilot is the final or pinned candidate fall back to native `invoke_subagent` or Antigravity directly under `--orchestrator agy` or halt under `--orchestrator codex` (auth errors always halt immediately). Codex uses its configured default CLI model unless `--model` or `CODEX_DELEGATE_MODEL` is supplied (defaulting to `auto`, which omits `-m` to let Codex decide). Never silently fall back to paid models.

## Delegate specification

State: objective, acceptance criteria, owned files, forbidden files, compatibility constraints, permitted verification commands, and required output. Prefer a task file outside the checkout for longer prompts. Explicitly say if a task is plan-only or build.

- **Plan:** explain implementation order, affected files/functions, tradeoffs, tests, and risks. No working-tree modifications. Prefer the Codex plugin (`codex-runner.mjs` in read-only mode) when present under Antigravity; when falling back to `delegate.sh --mode plan` on a dirty checkout for review, pass any uncommitted diff and untracked files in `--task` / `--task-file` (since the worktree snapshots committed `HEAD` only). Plan requests remain prompt-constrained and `delegate.sh` rejects any plan worktree that changes files.
- **Build:** create/edit files only within worktree scope, add tests, run allowed checks; do not commit/push/merge/rebase. Return changed files, test outcomes and failures.

The wrapper creates an external Git worktree from the **committed** base revision (`--base`, defaulting to `HEAD`), warns when uncommitted/untracked changes exist in the base checkout (excluding them from the worktree snapshot), and leaves build changes uncommitted on a `delegate/...` branch. When `--verify <cmd>` is passed in `--mode build` and the worker completes cleanly with HEAD and branch integrity intact, `delegate.sh` runs `<cmd>` outside the worker session inside the worktree (bounded by `--verify-timeout`, defaulting to `120` seconds) and captures combined output to `verify.log` (showing up to the last 40 lines in `DELEGATION_RESULT`). `DELEGATION_RESULT` and `manifest.txt` record:

- **Verification status (`Verification:`):** `passed` (exit 0), `failed` (non-zero exit or timeout, forcing `Exit: 1`), `not_run` (`--verify` configured, but worker or integrity checks already failed), or `none_configured` (no `--verify` command supplied; never treat `none_configured` or `not_run` as a pass).
- **Failure category (`Failure category:`):** `none`, `auth_error`, `env_error` (missing worker binary, quota/rate-limit/model unavailability across all candidates, or worktree setup error), `verification_error` (`--verify` failed or timed out), or `task_error`.
- **Changed and test files (`Changed files:` / `Modified test files:`):** Lists all worktree-modified or untracked paths and separately flags changed test paths (`tests/`, `*/tests/*`, `test_*`, `*_test.*`, `*.test.*`, `*.spec.*`). Whenever `Modified test files:` is non-empty, inspect every test diff before staging or cherry-picking to verify assertions were not deleted, skipped, or weakened to pass verification.

The orchestrator inspects `DELEGATION_RESULT`, report/log files, `git status`, `git diff`, new files, and denied tool commands. Exit 0 means transport success (and wrapper verification pass only if `Verification: passed`), not automatically correct design. If approved, stage only intended files, commit in the worktree, and cherry-pick to the integration branch. When `dirty_base=1` or `Overlapping dirty base files` is reported (`dirty_base_overlap=1` in `manifest.txt`), never copy whole files from the worktree over dirty base files or reset/checkout the base working tree to force a cherry-pick; reconcile overlapping hunks manually against the base checkout first. Run repository tests and the existing Alibaba Open Code Review pre-PR gate (if present) before PR creation.

## Safety and practical limits

- Worktrees do **not** sandbox host credentials, Git metadata, filesystem, or network. Keep narrowly scoped shell permissions; do not enable blanket unattended execution.
- Repositories can enforce a hard runtime opt-out via `git config --local agents.delegationAllowed false` (or `0`, `no`, `off`; also honored from global Git config unless overridden locally with `true`). When disabled or set to an unrecognized value, `delegate.sh` aborts before creating logs, worktrees, or MCP profiles or invoking any external provider (`codex`, `opencode`, `copilot`). Unconfigured repositories (`default`) and explicit `true` (`explicit_allow`) proceed and record `delegation_policy=default|explicit_allow` in `manifest.txt`.
- If the base working tree has uncommitted or untracked changes, `delegate.sh` snapshots committed `BASE` (`HEAD` by default), records `dirty_base=1` in `manifest.txt`, prints a `Base snapshot note` in `DELEGATION_RESULT`, and lists any `Overlapping dirty base files` (`dirty_base_overlap=1`) modified by both the worker and the dirty base checkout; reconcile overlapping hunks manually and never overwrite dirty base files directly.
- Run one external worker at a time. Avoid recursive delegation and indefinite retry loops. Fallback only on classified provider, quota, rate-limit, or model-availability failures; if all eligible external routes fail, report and continue with native `invoke_subagent` (under Antigravity) or directly with the orchestrator if possible.
- Never treat claimed passing tests as evidence without checking command output; agy headless may soft-deny shell commands.
