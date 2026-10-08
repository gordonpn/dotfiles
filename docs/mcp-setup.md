# Terminal AI Coding Agents MCP Setup & Parity

## Overview

This repository configures Model Context Protocol (MCP) servers, shared skills, and global instructions for terminal AI coding agents (Antigravity `agy` and Codex) on macOS and Linux. `bin/mcp-sync` compiles a single source of truth template (`dotfiles/gemini/mcp_config.template.json`) into client-specific configurations for both agents:
- Antigravity: `~/.gemini/config/mcp_config.json`
- Codex: `~/.codex/config.toml`

It also maintains agent parity by synchronizing global instructions (`dotfiles/gemini/GEMINI.md` to `AGENTS.md`) and custom skills to Codex (`~/.codex/skills/`).

The architecture separates version-controlled templates from machine-local configuration and secrets. Because this repository is public, credentials and cluster private keys are kept in the OS Keychain or environment variables and hydrated onto the local machine via `bin/mcp-sync`.

---

## Directory & Secret Management

```
dotfiles/ (Public Repository)
├── bin/
│   ├── mcp-sync                     # Hydration and synchronization utility
│   └── vault-mcp-server             # FastMCP runner for HashiCorp Vault KV & TOTP
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
├── config/
│   ├── mcp_config.json              # Fully hydrated MCP server registry (0600)
│   └── skills/                      # Custom user skills
├── docker-profiles.json             # Local daemon + remote SSH Docker profiles
├── memory.json                      # Persistent knowledge graph store
└── ssh-profiles.json                # Host profiles derived from ~/.ssh/config

~/.codex/ (Codex State)
├── AGENTS.md                        # Symlink to dotfiles/gemini/GEMINI.md
├── config.toml                      # Hydrated managed MCP tables (0600)
└── skills/                          # Symlinked shared skills beside .system skills

~/.local/bin/ (Machine-Local Binaries, Not Committed)
└── github-mcp-server                # Pinned release binary, installed by mcp-sync

~/.local/share/codebase-memory-mcp/   # Pinned native runtime
~/.cache/codebase-memory-mcp/         # Local indexes and coordination logs

OS Keychain / Secret Storage
├── macOS Keychain: security find-generic-password -a "$USER" -s <service>
└── Linux Libsecret: secret-tool lookup service <service>
Services: brave_api_key, exa_api_key, tailscale_api_key, uptime_kuma_jwt, healthchecks_api_key,
          github_token, vault_token, slack_bot_token, discord_token, tfe_token
```

---

## The Synchronization Script (`bin/mcp-sync`)

`bin/mcp-sync` is located in the dotfiles `bin/` directory (already exposed on `PATH` via `.zprofile`).

The Codex base template enables `tui.copy_on_select = "always"` for transcript
selections, including in Ghostty. Existing Codex configs retain their non-MCP
settings during sync; set this value under `[tui]` in `~/.codex/config.toml` and
restart the CLI when applying it to an existing installation.

### Execution
```bash
# Full hydration: binary installs, SSH/Docker/K3s checks, MCP configs, and skills
mcp-sync

# Lightweight configs-only mode (used by shell startup hooks):
mcp-sync --configs-only

# Install only codebase-memory-mcp, then synchronize all three client configs:
just setup-codebase-memory
```

### What It Does
1. **Installs MCP Binaries:** Downloads and verifies `github-mcp-server` into `~/.local/bin` and pinned `codebase-memory-mcp` into its dedicated runtime directory, ensures `terraform-mcp-server` is installed and linked (via Homebrew or `go install`), and links or installs `repomix` (skipped with `--configs-only`).
2. **Pulls Secrets & Defaults:** Queries macOS Keychain (or Linux `secret-tool`) and environment variables for service credentials and addresses (`brave_api_key`, `exa_api_key`, `tailscale_api_key`, `uptime_kuma_jwt`, `healthchecks_api_key`, `github_token`, `vault_token`, `slack_bot_token`, `discord_token`, `tfe_token`, `CADDY_ADMIN_URL`, `POSTGRES_URL`, `REDIS_URL`, `VAULT_ADDR`, `LOKI_URL`, `TFE_ADDRESS`).
3. **Generates SSH Profiles:** Parses [~/.ssh/config](file:///Users/gordonpn/.ssh/config) to generate `~/.gemini/ssh-profiles.json` for all configured hosts.
4. **Generates Docker Profiles:** Populates `~/.gemini/docker-profiles.json` with `local` as default, plus remote server targets for remote container and Swarm management.
5. **Synchronizes K3s Cluster:** Checks reachability of `master` over SSH, pulls `/etc/rancher/k3s/k3s.yaml`, updates endpoint to `https://master:6443`, and safely merges context `k3s-master` into `~/.kube/config` via `kubectl config view --flatten` (skipped with `--configs-only`).
6. **Initializes Memory Store:** Ensures `~/.gemini/memory.json` exists for `@modelcontextprotocol/server-memory`.
7. **Hydrates MCP Configs:** Renders `dotfiles/gemini/mcp_config.template.json` atomically with `0600` permissions into `~/.gemini/config/mcp_config.json` and `~/.codex/config.toml` (36 total servers).
8. **Synchronizes Skills & Instructions:** Symlinks `GEMINI.md` to `~/.codex/AGENTS.md`, and symlinks custom skills from `~/.gemini` into `~/.codex/skills/`.
9. **Shell Startup Integration:** `.zshrc_new` runs `_check_mcp_sync` on shell startup to compare source timestamps against target configs, backgrounding `mcp-sync --configs-only` with a 5-minute cooldown on errors.

---

## Registered MCP Servers

| Server Name | Transport | Implementation | Key Capabilities |
| :--- | :--- | :--- | :--- |
| **`cclsp`** | stdio | `@ktnyt/cclsp` | Multi-language LSP router for 14 local language servers |
| **`fetch`** | stdio | `uvx mcp-server-fetch` | HTTP web requests and HTML-to-markdown conversion |
| **`git`** | stdio | `uvx mcp-server-git` | Structured status, diff, log, branch, and commit operations on local repos |
| **`playwright`** | stdio | `npx -y @playwright/mcp@latest` | Accessibility-tree browser automation and interaction |
| **`chrome-devtools`** | stdio | `npx -y chrome-devtools-mcp@latest` | Performance traces, network inspection, and console access |
| **`puppeteer`** | stdio | `npx -y @modelcontextprotocol/server-puppeteer` | Headless browser execution and interaction |
| **`memory`** | stdio | `npx -y @modelcontextprotocol/server-memory` | Persistent knowledge graph in `~/.gemini/memory.json` |
| **`codebase-memory-mcp`** | stdio | Pinned native binary | Local code indexing, structural search, call graphs, and architecture queries |
| **`sequentialthinking`** | stdio | `npx -y @modelcontextprotocol/server-sequential-thinking` | Structured multi-step reasoning scratchpad |
| **`github`** | stdio | `~/.local/bin/github-mcp-server stdio` | Issues, PRs, Actions, code scanning, and repository search |
| **`brave-search`** | stdio | `npx -y @modelcontextprotocol/server-brave-search` | Web search integration via Brave Search API |
| **`exa`** | stdio | `npx -y exa-mcp-server` | Neural web search and webpage content extraction via Exa AI |
| **`sqlite`** | stdio | `uvx --with mcp==1.1.2 mcp-server-sqlite` | Local SQLite database queries and schema introspection |
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
| **`server-services-configs`** | stdio | `@modelcontextprotocol/server-filesystem` | Scoped filesystem access to service configurations |
| **`repomix`** | stdio | `repomix --mcp` | AI-optimized repository packing, remote git cloning, and output analysis |
| **`caddy`** | stdio | `@yawlabs/caddy-mcp` | Caddy reverse proxy admin API for dynamic route inspection |
| **`context7`** | stdio | `@upstash/context7-mcp` | Real-time library documentation and code reference search |
| **`postgres`** | stdio | `@modelcontextprotocol/server-postgres` | PostgreSQL schema introspection and read queries |
| **`redis`** | stdio | `@yawlabs/redis-mcp` | Redis key inspection, TTLs, and metrics via SCAN |
| **`vault`** | stdio | `uv run --with "mcp<2" --with "httpx"` | HashiCorp Vault KV v2 secret reads/writes and TOTP management |
| **`slack`** | stdio | `@modelcontextprotocol/server-slack` | Slack workspace channels, threads, and bot communication |
| **`discord`** | stdio | `@pasympa/discord-mcp` | Discord guild channels, messages, and role queries |
| **`semgrep`** | stdio | `semgrep mcp` | Local AST static analysis, SAST security scans, and custom rule matching |
| **`postman`** | stdio | `@postman/postman-mcp-server` | Postman workspaces, collections, environments, and mock server management |
| **`sonarqube`** | stdio | Standalone JAR (`java -jar`) | SonarQube Cloud and Server code quality metrics, quality gates, and hotspots |

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

### Deprecated Upstream, Retained Here

`puppeteer`, `brave-search`, `postgres`, and `slack` come from `modelcontextprotocol/servers`, whose npm packages are marked "package no longer supported" and frozen at 2025 releases. They still work; expect no fixes. Maintained alternatives if one breaks: `@playwright/mcp` (already registered) for `puppeteer`, `@brave/brave-search-mcp-server`, `crystaldba/postgres-mcp`, and `korotovsky/slack-mcp-server`.

---

## Quirks & Technical Decisions

### 1. SQLite MCP Version Pinning
Upstream Python package `mcp-server-sqlite` breaks when installed with `mcp` SDK v1.2+ because `Server.list_resources` was removed/restructured. It is pinned using `uvx --with mcp==1.1.2 mcp-server-sqlite`.

### 2. K3s Remote Endpoint TLS Validation
The K3s API server certificate on `master` generates TLS Subject Alternative Names (SANs) for `DNS:master` and `IP:100.72.77.63`, but not `master.tailb65f8c.ts.net`. Using `https://master:6443` resolves over Tailscale MagicDNS while matching the certificate SAN, avoiding TLS verification errors without disabling validation.

### 3. Docker MCP Multi-Host Support
`@hypnosis/docker-mcp-server` allows the agent to omit the profile argument during local development (`mode: "local"`), or pass `profile: "master"` to execute Docker and Docker Compose commands against remote servers over SSH.

### 4. Cloudflare Wrangler OAuth
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
