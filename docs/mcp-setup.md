# Terminal AI Coding Agents MCP Setup & Parity

## Overview

This repository configures Model Context Protocol (MCP) servers, shared skills, and global instructions for terminal AI coding agents (Antigravity `agy` and Codex) on macOS and Linux. `bin/mcp-sync` compiles a single source of truth template (`dotfiles/gemini/mcp_config.template.json`) into client-specific configurations for both agents:
- Antigravity: `~/.gemini/config/mcp_config.json`
- Codex: `~/.codex/config.toml`

It also maintains agent parity by synchronizing global instructions (`dotfiles/gemini/GEMINI.md` to `AGENTS.md`) and custom skills into Codex, Antigravity, and OpenCode discovery paths.

The architecture separates version-controlled templates from machine-local configuration and secrets. Because this repository is public, credentials and cluster private keys are kept in the OS Keychain or environment variables and hydrated onto the local machine via `bin/mcp-sync`.

---

## Directory & Secret Management

```
dotfiles/ (Public Repository)
├── bin/
│   ├── mcp-sync                     # Bash bootstrap & installer entrypoint
│   └── vault-mcp-server             # FastMCP runner for HashiCorp Vault KV & TOTP
├── scripts/
│   └── mcp_sync.py                  # Stdlib Python engine for config, profile, and skill sync
├── dotfiles/
│   ├── cclsp.json                   # LSP server extension mappings
│   └── gemini/
│       ├── GEMINI.md                # Source instructions (symlinked to AGENTS.md)
│       ├── mcp_config.template.json # Sanitized MCP configuration template
│       ├── docker-profiles.template.json
│       └── ssh-profiles.template.json
└── docs/
    └── mcp-setup.md                 # Architecture documentation

~/.gemini/ (Antigravity State)
├── antigravity-cli/
│   ├── settings.json                # Tracked CLI settings (altScreenMode, verbosity, light speed)
│   ├── title.sh                     # Dynamic terminal title script
│   └── rules/
│       └── auto-delegation.md       # Symlink to tracked Antigravity rule
├── config/
│   ├── mcp_config.json              # Fully hydrated MCP server registry (0600)
│   └── skills/                      # Symlinks to shared custom skills
├── docker-profiles.json             # Local daemon + remote SSH Docker profiles
└── ssh-profiles.json                # Host profiles derived from ~/.ssh/config

~/.codex/ (Codex State)
├── AGENTS.md                        # Symlink to dotfiles/gemini/GEMINI.md
├── config.toml                      # Hydrated managed MCP tables (0600)
├── plugins/                         # Installed Codex plugins
└── skills/                          # Symlinked shared skills beside .system skills

~/.gemini/config/plugins/            # Installed Antigravity CLI plugins

~/.agents/skills/*/                  # Symlinks to tracked shared skills (e.g. delegate-coding-agents, engineering-standards)

~/.copilot/ (GitHub Copilot State, when installed)
├── instructions/global.instructions.md # Symlink to dotfiles/gemini/GEMINI.md
├── mcp-config.json                  # Hydrated enabled MCP servers (0600)
└── skills/                          # Symlinked shared skills

~/.local/bin/ (Machine-Local Binaries, Not Committed)
└── github-mcp-server                # Pinned release binary, installed by mcp-sync

~/.local/share/codebase-memory-mcp/   # Pinned native runtime
~/.cache/codebase-memory-mcp/         # Local indexes and coordination logs

OS Keychain / Secret Storage
├── macOS Keychain: security find-generic-password -a "$USER" -s <service>
└── Linux Libsecret: secret-tool lookup service <service>
Services: brave_api_key, exa_api_key, tailscale_api_key, uptime_kuma_jwt, healthchecks_api_key,
          github_token, vault_token, slack_bot_token, discord_token, tfe_token,
          postman_api_key, sonarqube_token, sonarqube_org, cloudflare_api_token
```

---

## The Synchronization Script (`bin/mcp-sync`)

`bin/mcp-sync` is located in the dotfiles `bin/` directory (already exposed on `PATH` via `.zprofile`).

The Codex base template enables `tui.copy_on_select = "always"` for transcript
selections, including in Ghostty. Existing Codex configs retain their non-MCP
settings during sync; set this value under `[tui]` in `~/.codex/config.toml` and
restart the CLI when applying it to an existing installation.

The base template also sets top-level `project_doc_max_bytes = 65536` so the
combined global and repository instructions fit within Codex's 64 KiB limit.
For existing installations, set it before any TOML table in `~/.codex/config.toml`
and restart Codex; synchronization preserves existing non-MCP settings.

### Execution
```bash
# Full hydration: binary installs, SSH/Docker/K3s checks, MCP configs, and skills
mcp-sync

# Lightweight configs-only mode (used by shell startup hooks):
mcp-sync --configs-only

# Install only codebase-memory-mcp, then synchronize all three client configs:
just setup-codebase-memory

# Update external lockfile skills, standalone skill clones, and re-sync harnesses (continues syncing on pull/update warnings and exits non-zero if an update step failed):
just update-skills
```

### What It Does
1. **Installs MCP Binaries:** Downloads and verifies `github-mcp-server` into `~/.local/bin` and pinned `codebase-memory-mcp` into its dedicated runtime directory, ensures `terraform-mcp-server` is installed and linked (via Homebrew or `go install`), and links or installs `repomix` (skipped with `--configs-only`).
2. **Pulls Secrets & Defaults:** Queries macOS Keychain (or Linux `secret-tool`) and environment variables for service credentials and addresses (`brave_api_key`, `exa_api_key`, `tailscale_api_key`, `uptime_kuma_jwt`, `healthchecks_api_key`, `github_token`, `vault_token`, `slack_bot_token`, `discord_token`, `tfe_token`, `postman_api_key`, `sonarqube_token`, `sonarqube_org`, `cloudflare_api_token`, `CADDY_ADMIN_URL`, `REDIS_URL`, `VAULT_ADDR`, `LOKI_URL`, `TFE_ADDRESS`).
3. **Generates SSH Profiles:** Parses [~/.ssh/config](file:///Users/gordonpn/.ssh/config) to generate `~/.gemini/ssh-profiles.json` for all configured hosts.
4. **Generates Docker Profiles:** Populates `~/.gemini/docker-profiles.json` with `local` as default, plus remote server targets for remote container and Swarm management.
5. **Synchronizes K3s Cluster:** Checks reachability of `master` over SSH, pulls `/etc/rancher/k3s/k3s.yaml`, updates endpoint to `https://master:6443`, and safely merges context `k3s-master` into `~/.kube/config` via `kubectl config view --flatten` (skipped with `--configs-only`).
6. **Hydrates MCP Configs:** Renders `dotfiles/gemini/mcp_config.template.json` atomically with `0600` permissions into `~/.gemini/config/mcp_config.json` (all 31 servers, lazy-loaded on demand by Antigravity CLI; `caddy`, `vault`, `discord`, `postman`, and `sonarqube` disabled by default), `~/.codex/config.toml`, `~/.config/opencode/opencode.json` (lean minimal profile by default with 6 core coding, search, and memory servers enabled; 25 heavy, homelab, disabled, and CLI-covered servers defined as disabled while pruning retired entries), and `${COPILOT_HOME:-$HOME/.copilot}/mcp-config.json` (lean minimal profile with only the 6 enabled servers rendered, omitting disabled managed servers because Copilot CLI ignores per-server `disabled` flags). Profiles can be configured via `--codex-profile`/`CODEX_MCP_PROFILE`, `--opencode-profile`/`OPENCODE_MCP_PROFILE`, and `--copilot-profile`/`COPILOT_MCP_PROFILE`. Delegated GitHub Copilot Student runs through `delegate.sh --agent copilot` still restrict tools via `--available-tools`.
7. **Synchronizes Skills & Instructions:** Links all tracked skills under `dotfiles/agent-skills/` (including `delegate-coding-agents`, `engineering-standards`, `semgrep`, `repomix`, and `local-db-cli`) and the Antigravity auto-delegation rule into their home-directory locations, symlinks `GEMINI.md` across installed harnesses (`~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`, and `${COPILOT_HOME:-$HOME/.copilot}/instructions/global.instructions.md`), and mirrors shared skills into Antigravity, Codex, OpenCode (skipping redundant links in `~/.config/opencode/skills` for skills present in `~/.agents/skills` to eliminate duplicate OpenCode discovery warnings), and GitHub Copilot (`${COPILOT_HOME:-$HOME/.copilot}/skills`). The tracked sources are `dotfiles/agent-skills/*/` and `dotfiles/gemini/antigravity-cli/rules/auto-delegation.md`.
   Antigravity CLI uses Codex-first routing: when the user-installed Antigravity Codex plugin runner (`~/.gemini/config/plugins/codex/scripts/codex-runner.mjs`, exposing `setup`, `review`, `adversarial-review`, `task`, `status`, `result`, and `cancel` with `--write`, `--resume-last`, `--base`, and `--background`) is present, read-only questions, debugging, planning, architecture discussions, reviews, and follow-up continuity default to that plugin; when absent, read-only `plan` runs fall through to `delegate.sh`. Implementation builds default to `delegate.sh` in an isolated Git worktree. On classified Codex provider, quota, rate-limit, or model-availability failures from the plugin, Antigravity invokes `delegate.sh --orchestrator agy --agent opencode` directly (cascading OpenCode free models `opencode/deepseek-v4.1-flash-free` high, `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, `opencode/nemotron-3.5-lightning-free` then GitHub Copilot Student `--model auto` without retrying Codex). Codex as orchestrator delegates sequentially across OpenCode free models and GitHub Copilot Student (`--model auto`). OpenCode free models run anonymously without requiring an account or login. Authentication and provider-initialization errors (such as `ProviderInitError` or HTTP 403) are hard stops across all candidates with actionable credential/configuration guidance (`codex login`, `/codex:setup`, `copilot login`, or OpenCode provider configuration). Build runs via `delegate.sh` still proceed even when uncommitted edits exist (warning when uncommitted edits are excluded from the committed `HEAD` snapshot; fallback reviews on dirty checkouts must include the uncommitted diff in `--task` or review the active checkout directly).
8. **Shell Startup Integration:** `.zshrc_new` runs `_check_mcp_sync` on shell startup to compare source timestamps against target configs, backgrounding `mcp-sync --configs-only` with a 5-minute cooldown on errors.
9. **Synchronizes Agent Preferences & Status Tools:** Symlinks `dotfiles/gemini/antigravity-cli/settings.json` and `dotfiles/gemini/settings.json` to their respective home directory locations (`~/.gemini/antigravity-cli/settings.json` and `~/.gemini/settings.json`), symlinks `dotfiles/gemini/antigravity-cli/title.sh` to `~/.gemini/antigravity-cli/title.sh`, and links `bin/agy-statusline` to `~/.local/bin/agy-statusline`.

---

## Codex & OpenCode Minimal MCP Profile & Performance Tuning

Codex CLI and OpenCode eagerly spawn all enabled MCP servers and advertise their full tool schemas to the model on turn 0. Enabling all 33 servers exposed **593 tools** (~643 KiB of JSON schemas, ~160k tokens), which exceeded the 128-tool limit on OpenAI and Copilot chat completion endpoints, triggered aggressive auto-compaction loops on 64k models, and generated cold-start stderr errors from offline homelab services.

To optimize interactive and CLI workflows, `bin/mcp-sync` configures both Codex (`~/.codex/config.toml`) and OpenCode (`~/.config/opencode/opencode.json`) with a lean **minimal profile** by default while leaving Antigravity CLI (which lazy-loads tools from disk) with all 31 template servers.

### Default Minimal Profile

Only 6 core coding, search, and memory servers are enabled by default in `~/.codex/config.toml`, `~/.config/opencode/opencode.json`, and `${COPILOT_HOME:-$HOME/.copilot}/mcp-config.json` (`58` tools, `~24.7k` tokens interactively; `5` servers / `34` tools / `~7.9k` tokens in `delegate.sh` excluding `ai-memory`), while CLI-covered integrations (`semgrep`, `repomix`, `git`, `sequentialthinking`, retired `sqlite`/`postgres`, and opt-in `redis`) use local CLIs and tracked Agent Skills:

| Server Name | Tools | Role |
| :--- | :---: | :--- |
| **`ai-memory`** | 24 | Unified cross-agent memory, session tracking, handoffs, and durable knowledge base |
| **`brave-search`** | 2 | Enabled unconditionally in the minimal profile as web search fallback for Codex, OpenCode, and interactive Copilot (requires `BRAVE_API_KEY` at runtime; delegated `delegate.sh --agent copilot` runs restrict tools to built-in CLI tools via `--available-tools`) |
| **`cclsp`** | 12 | Multi-language LSP router for local language servers |
| **`codebase-memory-mcp`** | 17 | Codebase indexing, call graphs, architecture queries, and ADR management |
| **`context7`** | 2 | Real-time library documentation and code reference search |
| **`fetch`** | 1 | Web requests and HTML-to-markdown conversion |

All other 25 template servers remain fully defined in `~/.codex/config.toml` and `~/.config/opencode/opencode.json` (with their command, arguments, and environment variables pre-configured), but are set to `enabled = false` / `"enabled": false`. Existing top-level keys and custom unmanaged `mcp` entries in `~/.config/opencode/opencode.json` and `~/.copilot/mcp-config.json` are preserved across syncs, while retired entries (`sqlite`, `postgres`, `memory`, `chrome-devtools`, `puppeteer`, `server-services-configs`) are intentionally pruned by name across both OpenCode and Copilot configs.

### Measured Performance Reduction (Codex CLI)

These measurements were captured on Codex CLI (`33` -> `9` managed startup processes, `593` -> `84` tools); cross-client startup and task-success benchmarking for OpenCode, DeepSeek, and Copilot is tracked in GitHub issue `#20`.

| Metric | Before (Full Profile) | After (Minimal Profile) | Change |
| :--- | :---: | :---: | :---: |
| **Enabled MCP Servers** | 33 | 9 (+ internal `node_repl`) | -72.7% |
| **Model-Visible Tools** | 593 | 84 | -85.8% |
| **Tool Schema JSON Size** | 642.9 KiB | 116.6 KiB | -81.9% |
| **Tool Cap Compliance** | Exceeded 128-tool limit (4.6x) | 84 tools (comfortably below 128) | Compliant |
| **Process Startup Errors** | Uptime Kuma auth / offline warnings | Zero startup errors or stderr noise | Clean |
| **Tool Discovery Latency** | High | 0.042s min / 0.085s avg | Fast |

### Escape Hatches & Overrides

When additional MCP servers are needed for specific tasks, multiple tiers of overrides are available:

1. **One-Off Session Override (Codex CLI):**
   Pass `-c mcp_servers.<name>.enabled=true` when launching Codex. Because the server definition is already in `~/.codex/config.toml`, only the enablement flag is required:
   ```bash
   # Enable Docker for a container debugging session:
   codex -c mcp_servers.docker.enabled=true

   # Enable multiple servers:
   codex -c mcp_servers.docker.enabled=true -c mcp_servers.github.enabled=true
   ```

2. **Full Profile via `mcp-sync`:**
   To enable all configured MCP servers across Codex, OpenCode, or Copilot:
   ```bash
   mcp-sync --codex-profile full
   mcp-sync --opencode-profile full
   mcp-sync --copilot-profile full
   # Or set via environment variables:
   CODEX_MCP_PROFILE=full OPENCODE_MCP_PROFILE=full COPILOT_MCP_PROFILE=full mcp-sync --configs-only
   ```

3. **Custom Server Allowlist:**
   To configure a specific subset of enabled servers:
   ```bash
   mcp-sync --codex-servers "cclsp,docker,github,context7"
   mcp-sync --opencode-servers "cclsp,docker,github,context7"
   mcp-sync --copilot-servers "cclsp,docker,github,context7"
   # Or set via environment variables:
   export CODEX_MCP_SERVERS="cclsp,docker,github,context7"
   export OPENCODE_MCP_SERVERS="cclsp,docker,github,context7"
   export COPILOT_MCP_SERVERS="cclsp,docker,github,context7"
   mcp-sync --configs-only
   ```

### Client & Harness Compatibility Matrix

| Client / Harness | Version | Provider / Model | Startup Processes | Tool Loading | Deferred Search | Default Profile & Visible MCP Tools | Fallback / Override |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Antigravity CLI (`agy`)** | Primary | Gemini / configured default | 0 eager MCP processes (spawned on demand) | Lazy-loaded on demand from disk | Native | Full (`31` template servers, `0` turn-0 schema overhead) | N/A |
| **Codex CLI (`codex`)** | `0.167.2` | OpenAI / `gpt-6.1-terra` | 6 managed servers (`+ node_repl`; 5 in `delegate.sh`) | Eager at startup (`~/.codex/config.toml`) | `tool_search` `removed`; `code_mode_tool_search` `under development` (`false`) | `minimal` (`6` servers, `58` tools; `5` servers in `delegate.sh`) | `-c mcp_servers.<name>.enabled=true`, `--codex-profile`, `--codex-servers` |
| **OpenCode (`opencode`)** | `1.19.3` | OpenCode / `opencode/deepseek-v4.1-flash-free` | 6 managed servers (5 in `delegate.sh`) | Eager at startup (`~/.config/opencode/opencode.json`) | Disabled by default (`OPENCODE_EXPERIMENTAL_CODE_MODE=1` enables `tools.$codemode.search` while still starting enabled servers eagerly) | `minimal` (`6` servers, `58` tools; `5` servers in `delegate.sh`) | `--opencode-profile`, `--opencode-servers`, `delegate.sh --mcp-profile` |
| **DeepSeek Harness (`scripts/deepseek-analyze.sh`)** | via OpenCode `1.19.3` | `opencode/deepseek-v4.1-flash-free` (`high` variant) | 5 managed servers (`OPENCODE_CONFIG` override) | Eager via `delegate.sh --agent opencode` | Unavailable by default | `minimal` (`5` servers, excluding `ai-memory`) | `DELEGATE_MCP_PROFILE`, `OPENCODE_DELEGATE_MCP_PROFILE`, `DELEGATE_MCP_SERVERS` |
| **GitHub Copilot Student (`copilot`)** | Delegated | Copilot Student (`--model auto`) | Isolated via `--disable-builtin-mcps` / `--disable-mcp-server` (`5` allowed in `delegate.sh`; `6` interactively in `mcp-config.json`) | Eager when enabled (`mcp-config.json` / `.mcp.json` / `.github/mcp.json`); restricted by `--available-tools` in `delegate.sh` | N/A (built-in CLI tools only via `--available-tools` in `delegate.sh`; no MCP web search in delegated runs) | `minimal` (`--mcp-profile`, `COPILOT_DELEGATE_MCP_PROFILE`) + `--available-tools` (`view,grep,glob` / `edit,view,grep,glob`; `--deny-tool=shell`) | Uses built-in CLI tools if MCP/deferred search unavailable; `--agent copilot` (unpinned) falls back to OpenCode free models, otherwise hands back to `agy` or halts under `codex` (auth errors always halt) |

### Deferred Tool Search & Code Mode Verification

Experimental probes against the live toolchains (keeping default `bin/mcp-sync` configs unchanged) established the following behavior:

1. **Codex CLI (`0.167.2`, OpenAI `gpt-6.1-terra`):**
   - `codex features list` reports `search_tool`, `tool_search`, and `tool_search_always_defer_mcp_tools` as `removed`, while `code_mode` and `code_mode_tool_search` are `under development` (`false` by default).
   - Passing `--enable tool_search` is silently ignored and falls back to eager schema loading (`46,103` input tokens vs `44,243` baseline; `15.8s-20.4s` turn time).
   - Passing `--enable code_mode --enable code_mode_tool_search` exposes `functions.exec` and `tools.tool_search`, and `tool_search` successfully resolves deferred tools across enabled servers (verified with `mcp_servers.github.enabled=true`: `mcp__github__get_me`, `mcp__context7__resolve_library_id` in `15.84s`). However, it emits an `under development` warning banner, still loads ~44.4k-49k input tokens per turn, and eagerly starts enabled MCP servers at startup.
2. **OpenCode (`1.19.3`, `opencode/deepseek-v4.1-flash-free`):**
   - Under default V1 configuration, per-server `codemode` settings are stripped with `"Omitted native setting that cannot be represented in V1"`, and enabled MCP tools load eagerly (`9.0s-11.8s` turn time).
   - Setting `OPENCODE_EXPERIMENTAL_CODE_MODE=1` activates the `execute` tool and `tools.$codemode.search(...)` (`29.37s` measured with `sequentialthinking` and default servers), while still connecting enabled MCP servers eagerly at startup.
3. **Sync & Fallback Policy:**
   - Keep `code_mode_tool_search` and `OPENCODE_EXPERIMENTAL_CODE_MODE` disabled in default synced configs. Both Codex and OpenCode fall back to the static `minimal` profile (`6` servers locally; `5` servers in `delegate.sh`), using per-session CLI overrides (`-c mcp_servers.<name>.enabled=true`, `--codex-profile`, `--opencode-profile`, `--codex-servers`, `--opencode-servers`) when additional servers are required.

---

## Registered MCP Servers

| Server Name | Transport | Implementation | Key Capabilities |
| :--- | :--- | :--- | :--- |
| **`cclsp`** | stdio | `cclsp` | Multi-language LSP router for 10 local language servers |
| **`fetch`** | stdio | `uvx mcp-server-fetch` | HTTP web requests and HTML-to-markdown conversion |
| **`git`** | stdio | `uvx mcp-server-git` | Structured status, diff, log, branch, and commit operations on local repos |
| **`playwright`** | stdio | `npx -y @playwright/mcp@latest` | Accessibility-tree browser automation and interaction |
| **`ai-memory`** | stdio | `~/.local/bin/ai-memory mcp-bridge --no-session-id --server-url http://127.0.0.1:49374/mcp` | Unified cross-agent memory, session tracking, handoffs, and durable wiki knowledge base |
| **`codebase-memory-mcp`** | stdio | Pinned native binary | Local code indexing, structural search, call graphs, and architecture queries |
| **`sequentialthinking`** | stdio | `npx -y @modelcontextprotocol/server-sequential-thinking` | Structured multi-step reasoning scratchpad |
| **`github`** | stdio | `~/.local/bin/github-mcp-server stdio` | Issues, PRs, Actions, code scanning, and repository search |
| **`brave-search`** | stdio | `npx -y @modelcontextprotocol/server-brave-search` | Web search integration via Brave Search API |
| **`exa`** | stdio | `npx -y exa-mcp-server` | Neural web search and webpage content extraction via Exa AI |
| **`cloudflare`** | stdio | `npx -y @cloudflare/mcp-server-cloudflare` | Cloudflare Workers, KV, D1, Queues, and Pages |
| **`prometheus`** | stdio | `npx -y prometheus-mcp@latest stdio` | Metrics discovery and PromQL instant/range queries |
| **`loki`** | stdio | `loki-mcp-server` | Grafana Loki log search, labels/series discovery, and LogQL queries |
| **`docker`** | stdio | `npx -y @hypnosis/docker-mcp-server` | Local daemon & remote Swarm containers, logs, and Compose |
| **`kubernetes`** | stdio | `npx -y mcp-server-kubernetes` | Cluster management across `docker-desktop` and `k3s-master` |
| **`terraform`** | stdio | `terraform-mcp-server stdio` | Terraform Registry provider/module schemas, documentation, and IaC generation |
| **`ssh`** | stdio | `npx -y @hypnosis/ssh-mcp-server` | Remote command execution, log search, and server audits |
| **`tailscale`** | stdio | `npx -y @yawlabs/tailscale-mcp` | Tailnet management: devices, ACLs, routes, and DNS |
| **`uptime-kuma`** | stdio | `npx -y @davidfuchs/mcp-uptime-kuma` | Monitor healthchecks, status pages, and heartbeats |
| **`healthchecks`**| stdio | `npx -y healthchecks-mcp` | Dead man's switch and scheduled cron task inspection |
| **`filesystem`** | stdio | `npx -y @modelcontextprotocol/server-filesystem` | Scoped filesystem access for the user home directory |
| **`repomix`** | stdio | `repomix --mcp` | AI-optimized repository packing, remote git cloning, and output analysis |
| **`caddy`** (disabled) | stdio | `@yawlabs/caddy-mcp` | Caddy reverse proxy admin API for dynamic route inspection |
| **`context7`** | stdio | `@upstash/context7-mcp` | Real-time library documentation and code reference search |
| **`redis`** | stdio | `@yawlabs/redis-mcp` | Redis key inspection, TTLs, and metrics via SCAN |
| **`vault`** (disabled) | stdio | `uv run --with "mcp<2" --with "httpx"` | HashiCorp Vault KV v2 secret reads/writes and TOTP management |
| **`slack`** | stdio | `@modelcontextprotocol/server-slack` | Slack workspace channels, threads, and bot communication |
| **`discord`** (disabled) | stdio | `@pasympa/discord-mcp` | Discord guild channels, messages, and role queries |
| **`semgrep`** | stdio | `semgrep mcp` | Local AST static analysis, SAST security scans, and custom rule matching |
| **`postman`** (disabled) | stdio | `@postman/postman-mcp-server` | Postman workspaces, collections, environments, and mock server management |
| **`sonarqube`** (disabled) | stdio | Standalone JAR (`java -jar`) | SonarQube Cloud and Server code quality metrics, quality gates, and hotspots |

### codebase-memory-mcp

Run `just setup-codebase-memory` from this checkout. It invokes
`mcp-sync --codebase-memory-only`, installs v0.11.0 into
`~/.local/share/codebase-memory-mcp/`, and synchronizes the shared stdio entry
to Antigravity CLI (`agy`) and Codex. No API key, Docker, or language
runtime is required for the server. Setup requires Bash and curl; verification
uses the installed Python MCP SDK through `uv`.

`mcp-sync` selects the macOS/Linux architecture, verifies the release checksum,
and signs the macOS binary. Linux uses the static portable release. The upstream
installer is deliberately not run: even `--skip-config` edits shell startup
files. Our templates and shared instruction symlinks remain authoritative;
upstream hooks, plugins, skills, and subagents are not installed. To upgrade,
close all clients using the server, change `CODEBASE_MEMORY_MCP_VERSION` in
`bin/mcp-sync`, and rerun the setup recipe. All running CBM processes must use
the same binary build. Avoid the upstream installer/updater, which bypasses
the pin and modifies settings outside this repository's managed setup.

Restart existing `agy` and Codex sessions after setup; check `codex mcp get codebase-memory-mcp`.
In a fresh session, ask the agent to index the specific repository you want to
query. Automatic indexing is not enabled by setup. Graph data stays under
`~/.cache/codebase-memory-mcp/`; if indexing exports a `.codebase-memory/`
artifact into a repository, keep it untracked unless deliberately sharing it.

Diagnostics:

```bash
~/.local/share/codebase-memory-mcp/codebase-memory-mcp --version
~/.local/share/codebase-memory-mcp/codebase-memory-mcp daemon status
just verify-codebase-memory
just test
just lint
```

Daemon startup and indexing errors are recorded in
`~/.cache/codebase-memory-mcp/logs/cbm-daemon.log`. All clients must use the same
runtime build and cache root to share the coordination daemon.

### ai-memory

`ai-memory` provides unified cross-agent conversation capture, turn tracking, handoffs, and a local wiki knowledge base across Antigravity CLI, Codex, and OpenCode.

- **Daemon Architecture:** Runs a local background service on `http://127.0.0.1:49374` managed via launchd (`com.github.akitaonrails.ai-memory.plist` on macOS).
- **Client Transport:** Clients connect via the stdio bridge:
  `~/.local/bin/ai-memory mcp-bridge --no-session-id --server-url http://127.0.0.1:49374/mcp`
- **Knowledge Storage:** Sessions, observations, and wiki markdown pages persist in SQLite under `~/Library/Application Support/ai-memory/` on macOS.
- **Hook Integration:** Capture hooks are staged in `~/.local/share/ai-memory/hooks/` for automated session lifecycle recording.
- **Setup & Verification:** `bin/mcp-sync` checks the binary stamp, extracts hooks if missing, and verifies service availability. Run `ai-memory status` or check `curl -fsSL http://127.0.0.1:49374/healthz` for daemon health.

### cc-thinking-skills (Thinking Model Router)

`tjboudreaux/cc-thinking-skills` contains specialized thinking skills for reasoning, architecture, debugging, and verification.

- **Context Budget Protection:** Registering all 28 individual thinking skills directly into agent skill discovery paths overflows context window prompts (consuming substantial budget and displacing operational skills).
- **Router Pattern:** The repository is cloned to `~/.local/share/cc-thinking-skills/`. Only `thinking-model-router` is symlinked into `~/.agents/skills/`.
- **Workflow:** The single `thinking-model-router` skill inspects incoming tasks and activates or references the specific thinking model needed from `~/.local/share/cc-thinking-skills/skills/`.

### Everything Claude Code (ECC)

ECC provides reusable skills, workflows, rules, agents, and a Codex session-start
hook. The Codex plugin is pinned to `v2.2.3`; Antigravity's minimal profile is
installed project-locally into `.agents/` with the pinned `ecc-universal@2.2.3`
package. Run `just setup-ecc` to install both integrations. The generated
`.agents/` directory is ignored by Git; the pinned recipe recreates it.

ECC also bundles a Chrome DevTools MCP server. It is disabled in the Codex
template because this setup already has browser and Chrome plugins. Enable it
in the Codex plugin settings if you specifically want that additional server.
Start new Codex and Antigravity sessions after setup; Codex may ask you to trust
the plugin's session-start hook.

See the [ECC repository](https://github.com/affaan-m/ECC) and its
[Antigravity guide](https://github.com/affaan-m/ECC/blob/v2.2.3/docs/ANTIGRAVITY-GUIDE.md)
for supported components and usage.

### Deprecated Upstream, Retained Here

`brave-search` and `slack` come from `modelcontextprotocol/servers`, whose npm packages are marked "package no longer supported" and frozen at 2025 releases. They still work; expect no fixes. Maintained alternatives if one breaks: `@brave/brave-search-mcp-server` and `korotovsky/slack-mcp-server`.

---

## Quirks & Technical Decisions

### 1. K3s Remote Endpoint TLS Validation
The K3s API server certificate on `master` generates TLS Subject Alternative Names (SANs) for `DNS:master` and `IP:100.72.77.63`, but not `master.tailb65f8c.ts.net`. Using `https://master:6443` resolves over Tailscale MagicDNS while matching the certificate SAN, avoiding TLS verification errors without disabling validation.

### 2. Docker MCP Multi-Host Support
`@hypnosis/docker-mcp-server` allows the agent to omit the profile argument during local development (`mode: "local"`), or pass `profile: "master"` to execute Docker and Docker Compose commands against remote servers over SSH.

### 3. Cloudflare Wrangler OAuth
Rather than requiring API tokens that expire or have restricted scopes, the Cloudflare server binds directly to the local Wrangler OAuth session initiated via `npx wrangler login`.

### 5. HashiCorp Vault FastMCP SDK Pinning
FastMCP in `mcp` SDK v2.x restructured internal classes (`FastMCP` -> `MCPServer`). Running `bin/vault-mcp-server` with `uv run --with "mcp<2" --with "httpx"` ensures clean FastMCP compatibility and avoids virtual environment pollution.

### 6. Redis Cursor-Based SCAN Traversal
The `@yawlabs/redis-mcp` integration defaults to read-only mode and uses cursor-based `SCAN` rather than `KEYS *`, preventing long-running blocking operations on active databases.

### 7. Caddy Admin API
`@yawlabs/caddy-mcp` connects to Caddy's HTTP admin endpoint (defaults to `http://master.tailb65f8c.ts.net:2019`). It allows querying active reverse proxy routes and server configurations.

### 8. Context7 Documentation
`@upstash/context7-mcp` provides current API and framework documentation without requiring an API key for baseline usage.

### 9. Loki Discovery-First Granular Tools
The `incu6us/loki-mcp-server` implementation provides 5 granular tools (`labels`, `label_values`, `series`, `query`, `query_range`). This allows the agent to inspect the label taxonomy (e.g. apps, namespaces, containers) before formulating LogQL expressions, preventing blind query errors.

### 10. GitHub MCP Server Binary Distribution
`github/github-mcp-server` is a Go binary published only to GitHub releases and `ghcr.io`, with no npm or PyPI entry point, so it cannot be run through `npx`/`uvx` like every other server here. `mcp-sync` downloads the pinned release for the host OS/arch and verifies its SHA-256 against the published checksums file before installing; an unverifiable download is skipped rather than installed. Installed version is tracked in `~/.local/bin/.github-mcp-server.version` instead of parsing `--version`, whose output format is not a stability contract. The Docker image was rejected to avoid making the GitHub tools depend on a running daemon.

It replaces `@modelcontextprotocol/server-github`, which npm marks "package no longer supported".

### 11. Git MCP Without a Pinned Repository
`mcp-server-git` accepts a `--repository` argument that scopes it to one checkout. It is intentionally omitted so the `repo_path` tool parameter stays free, letting one server instance serve every repository on the machine.

### 12. cclsp Language Server Scope and Startup Behavior
`dotfiles/cclsp.json` (symlinked to `~/.config/cclsp/cclsp.json`) configures 10 code and infrastructure language servers:

- TypeScript/JavaScript (`ts`, `tsx`, `js`, `jsx`, `mjs`, `cjs`): `typescript-language-server --stdio`
- Python (`py`, `pyi`): `pyright-langserver --stdio`
- Go (`go`): `gopls`
- Shell (`sh`, `bash`, `zsh`): `bash-language-server start`
- Lua (`lua`): `lua-language-server`
- Dockerfile (`dockerfile`, `Dockerfile`): `docker-langserver --stdio`
- Astro (`astro`): `astro-ls --stdio`
- Terraform (`tf`, `tfvars`): `terraform-ls serve`
- Java (`java`): `jdtls`
- CSS/SCSS/Sass (`css`, `scss`, `sass`): `tailwindcss-language-server --stdio`

Config and documentation language servers (`yaml-language-server`, `vscode-json-language-server`, `marksman`, and `taplo`) are intentionally omitted. In this repository, `cclsp@0.7.0` eagerly preloads every entry whose extensions appear within depth 3 of the workspace root (`preloadServers()`), and `taplo` emits `SchemaCatalog` decode errors while `marksman` logs bogus-workspace warnings on startup. Limiting `dotfiles/cclsp.json` to code and infrastructure servers reduces observed startup preloads on the current `dotfiles` depth-3 tree from 7 LSPs to up to 3 (`pyright-langserver`, `bash-language-server`, and `lua-language-server`), depending on which language files exist in a checkout. As a trade-off, LSP routing and diagnostics are disabled for YAML, JSON, Markdown, and TOML files; revisit this omission when upstream `cclsp` adds an option to disable eager preloads.

Upstream `cclsp@0.7.0` exposes no configuration field, CLI flag, or environment variable to disable `preloadServers()`, and its `startServer()` method waits 3000 ms for a server-to-client `initialized` notification that standard LSP servers do not send, so each started LSP still logs `Error: Initialization timeout` on stderr before proceeding. In addition, `cclsp` only disposes child LSP processes on `SIGINT`/`SIGTERM` rather than `stdin` EOF, so stdio clients that do not terminate the subprocess on close (such as `mcp==1.1.2` `stdio_client`) must enforce a teardown timeout and explicitly send `SIGTERM` and wait (or terminate the process tree if the timeout expires).
