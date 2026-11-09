# Install and configure automatic delegation

The dotfiles repository is the source of truth for this skill and the
Antigravity auto-delegation rule. Run `bin/mcp-sync` from the repository root
to link them into `~/.agents/skills/` and
`~/.gemini/antigravity-cli/rules/`, then mirror the shared skill into Codex,
OpenCode, and Antigravity's skill discovery directory. Existing conflicting
local copies are backed up by the sync script.

Antigravity CLI acts as the main harness, routing through
`agy-cli -> codex -> opencode -> github copilot student`. It tries Codex CLI
first, then falls back across OpenCode free models (DeepSeek Flash Free high,
GLM-5.3 Flash Free, MiMo-V2.6 Flash Free, Nemotron-3.5 Lightning Free), then to
GitHub Copilot Student (`--model auto`).

Codex as parent orchestrator delegates sequentially across OpenCode free
models and GitHub Copilot Student (`--model auto`). Authentication
and provider-initialization errors stop delegation with a message to check
login and credentials/configuration (`codex login`, `copilot login`, or OpenCode
provider configuration if using commercial models). Codex does not delegate to
Antigravity CLI under a consumer plan.

## Authentication and Provider Requirements

Each worker in the delegation chain has specific authentication requirements:

### 1. Codex CLI
- **Login required:** Yes.
- **Login command:** `codex login`
- **Behavior when unauthenticated:** Fails with `Error: You are not logged in. Please run codex login.` and returns non-zero exit code. `delegate.sh` classifies this as an authentication failure and halts fallback immediately.

### 2. OpenCode Free Models
- **Login required:** **No.**
- **Supported free models:**
  - `opencode/deepseek-v4.1-flash-free` (with `--variant high`)
  - `opencode/glm-5.3-flash-free`
  - `opencode/mimo-v2.6-flash-free`
  - `opencode/nemotron-3.5-lightning-free`
- **Anonymous execution:** All four supported free models can be invoked completely anonymously out of the box with zero credentials in `~/.local/share/opencode/auth.json` and no OpenCode account or token. OpenCode routes these requests through its hosted gateway service.
- **When is OpenCode login required?**
  - Only when targeting non-free or commercial models (such as `anthropic/*`, `openai/*`, or `github-copilot/*`), or when using OpenCode Zen paid subscriptions.
  - To log in for commercial providers, run `opencode auth login` (or configure provider environment variables like `ANTHROPIC_API_KEY`).
- **Failure and fallback behavior:**
  - Unauthenticated requests to non-free models fail with exit code 1 (`UnknownError: Unexpected server error` or `ProviderAuthError`), which stops fallback immediately.
  - Rate limits or temporary capacity limits on free models (such as HTTP 429, `Free usage limit reached`, or `Free usage exceeded`) are classified by `is_provider_quota_error`. When running without an explicit `--model`, `delegate.sh` automatically cascades to the next candidate free model in sequence before falling back to GitHub Copilot Student. When an explicit `--model` is specified, delegation targets only that candidate without cascading.

### 3. GitHub Copilot CLI
- **Login required:** Yes.
- **Login command:** `copilot login` (or `gh auth login`)
- **Prerequisite:** Active GitHub Copilot entitlement (such as Copilot Student).
- **Behavior when unauthenticated:** Fails with authentication errors (`not authenticated` or `authentication required`), prompting immediate halt without further fallback.

Automatic delegation requires explicit opt-in in each eligible repository:

```bash
git config --local agents.delegationAllowed true
```

Restart active Codex and agy sessions to load the updated skill and rule.
Configure narrow build/test command permissions separately; never blindly
enable global shell-approval bypass.

## Notes

- Parent agy delegates sequentially across Codex, OpenCode, and GitHub Copilot Student (`--model auto`).
- Parent Codex delegates sequentially across OpenCode and GitHub Copilot Student (`--model auto`).
- OpenCode free models operate anonymously with zero credentials; account login is not required for the free-tier delegation path.
- Automatic repo opt-in avoids accidentally sending confidential employer sources to an external hosted model.
- If no repo opt-in exists, the agent should complete tasks itself or explain that delegation is blocked.
- Both delegations operate on a clean committed checkout; current uncommitted edits cannot be safely inherited.
- To run a delegate manually without the opt-in gate, omit `--automatic`, but still ensure the repository is appropriate for external inference.
- One-shot OpenCode and Codex delegations apply a minimal MCP profile (`minimal` by default) to disable unrelated cloud, database, monitoring, and chat servers without mutating user configurations (via `OPENCODE_CONFIG` for OpenCode and ephemeral `-c` overrides for Codex).
- Plans stay in an isolated detached worktree, builds on new `delegate/...` branches; review and integrate only verified changes.
