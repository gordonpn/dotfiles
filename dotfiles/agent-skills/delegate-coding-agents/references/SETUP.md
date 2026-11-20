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
- **MCP isolation & fallback behavior:** `delegate.sh` keeps user `${COPILOT_HOME:-$HOME/.copilot}/mcp-config.json` and authentication state intact while disabling built-in MCP servers (`--disable-builtin-mcps` unless `github-mcp-server` is allowed) and non-allowed user and repo-local (`.mcp.json`, `.github/mcp.json`) MCP servers via ephemeral `--disable-mcp-server <name>` flags (`minimal` by default; override via `--mcp-profile` or `COPILOT_DELEGATE_MCP_PROFILE` / `COPILOT_DELEGATE_MCP_SERVERS`). Built-in CLI tool filtering (`--available-tools` and `--deny-tool=shell`) remains enforced even when MCP or deferred tool search is unavailable. On classified quota/rate-limit/model unavailability: for Copilot-first requests (`--agent copilot` without `--model`), `delegate.sh` appends OpenCode candidate free models after Copilot and falls back to OpenCode for either orchestrator; when Copilot is the final candidate in the chain (or pinned via `--model`), `--orchestrator agy` falls back directly to Antigravity while `--orchestrator codex` halts after reporting the Copilot failure.

Restart active Codex and agy sessions to load the updated skill and rule.
Configure narrow build/test command permissions separately; never blindly
enable global shell-approval bypass.

## Notes

- Parent agy prefers `delegate.sh` over native `invoke_subagent` and delegates sequentially across Codex, OpenCode, and GitHub Copilot Student (`--model auto`).
- Parent Codex delegates sequentially across OpenCode and GitHub Copilot Student (`--model auto`).
- OpenCode free models operate anonymously with zero credentials; account login is not required for the free-tier delegation path.
- Keep confidential or employer-restricted code away from external hosted models unless explicitly authorized.
- Worktrees snapshot the committed `--base` revision (`HEAD` by default); when the base checkout has uncommitted or untracked changes, `delegate.sh` warns and records that local edits are excluded rather than aborting.
- `--automatic` is accepted for backwards compatibility as a no-op; no per-repo `agents.delegationAllowed` config is required.
- One-shot OpenCode, Codex, and Copilot Student delegations apply a minimal MCP profile (`minimal` by default) to disable unrelated cloud, database, monitoring, and chat servers without mutating user configurations (via `OPENCODE_CONFIG` for OpenCode, ephemeral `-c` overrides for Codex, and ephemeral `--disable-builtin-mcps` / `--disable-mcp-server` flags for Copilot).
- Plans stay in an isolated detached worktree, builds on new `delegate/...` branches; review and integrate only verified changes.
