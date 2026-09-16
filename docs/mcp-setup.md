# Antigravity Model Context Protocol (MCP) Setup

## Overview

This repository configures Model Context Protocol (MCP) servers for the Antigravity AI coding agent (`agy`) on macOS and Linux. `agy` is the only consumer: `bin/mcp-sync` writes `~/.gemini/config/mcp_config.json` and nothing else. The other agents in use read their own machine-local registries, deliberately untracked here because their contents are environment-specific: `~/.kiro/settings/mcp.json` for kiro-cli and `~/.claude.json` for Claude Code, both of which carry work-only servers.

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
│       ├── mcp_config.template.json # Sanitized MCP configuration template
│       ├── docker-profiles.template.json
│       └── ssh-profiles.template.json
└── docs/
    └── mcp-setup.md                 # Architecture documentation

~/.gemini/ (Machine-Local State, Not Committed)
├── config/
│   └── mcp_config.json              # Fully hydrated MCP server registry
├── docker-profiles.json             # Local daemon + remote SSH Docker profiles
└── ssh-profiles.json                # Host profiles derived from ~/.ssh/config

~/.local/bin/ (Machine-Local Binaries, Not Committed)
└── github-mcp-server                # Pinned release binary, installed by mcp-sync

OS Keychain / Secret Storage
├── macOS Keychain: security find-generic-password -a "$USER" -s <service>
└── Linux Libsecret: secret-tool lookup service <service>
Services: brave_api_key, tailscale_api_key, uptime_kuma_jwt, healthchecks_api_key,
          github_token, vault_token, slack_bot_token, discord_token
```

---

## The Synchronization Script (`bin/mcp-sync`)

`bin/mcp-sync` is located in the dotfiles `bin/` directory (already exposed on `PATH` via `.zprofile`).

### Execution
```bash
mcp-sync
```

### What It Does
1. **Installs `github-mcp-server`:** Downloads the pinned release tarball for the host OS/arch, verifies its SHA-256 against the published checksums file, and installs the binary to `~/.local/bin`. Skipped when the version stamp already matches. Override the version with `GITHUB_MCP_SERVER_VERSION`.
2. **Pulls Secrets & Defaults:** Queries macOS Keychain (or Linux `secret-tool`) and environment variables for service credentials and addresses (`brave_api_key`, `tailscale_api_key`, `uptime_kuma_jwt`, `healthchecks_api_key`, `github_token`, `vault_token`, `slack_bot_token`, `discord_token`, `CADDY_ADMIN_URL`, `POSTGRES_URL`, `REDIS_URL`, `VAULT_ADDR`, `LOKI_URL`).
3. **Generates SSH Profiles:** Parses [~/.ssh/config](file:///Users/gordonpn/.ssh/config) to generate `~/.gemini/ssh-profiles.json` for all configured hosts.
4. **Generates Docker Profiles:** Populates `~/.gemini/docker-profiles.json` with `local` as default, plus remote server targets for remote container and Swarm management.
5. **Synchronizes K3s Cluster:** Checks reachability of `master` over SSH, pulls `/etc/rancher/k3s/k3s.yaml`, updates endpoint to `https://master:6443`, and safely merges context `k3s-master` into `~/.kube/config` via `kubectl config view --flatten`.
6. **Hydrates MCP Config:** Renders `dotfiles/gemini/mcp_config.template.json` into `~/.gemini/config/mcp_config.json` (28 total servers).

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
| **`sequentialthinking`** | stdio | `npx -y @modelcontextprotocol/server-sequential-thinking` | Structured multi-step reasoning scratchpad |
| **`github`** | stdio | `~/.local/bin/github-mcp-server stdio` | Issues, PRs, Actions, code scanning, and repository search |
| **`brave-search`** | stdio | `npx -y @modelcontextprotocol/server-brave-search` | Web search integration via Brave Search API |
| **`sqlite`** | stdio | `uvx --with mcp==1.1.2 mcp-server-sqlite` | Local SQLite database queries and schema introspection |
| **`cloudflare`** | stdio | `npx -y @cloudflare/mcp-server-cloudflare` | Cloudflare Workers, KV, D1, Queues, and Pages |
| **`prometheus`** | stdio | `npx -y prometheus-mcp@latest stdio` | Metrics discovery and PromQL instant/range queries |
| **`loki`** | stdio | `loki-mcp-server` | Grafana Loki log search, labels/series discovery, and LogQL queries |
| **`docker`** | stdio | `npx -y @hypnosis/docker-mcp-server` | Local daemon & remote Swarm containers, logs, and Compose |
| **`kubernetes`** | stdio | `npx -y mcp-server-kubernetes` | Cluster management across `docker-desktop` and `k3s-master` |
| **`ssh`** | stdio | `npx -y @hypnosis/ssh-mcp-server` | Remote command execution, log search, and server audits |
| **`tailscale`** | stdio | `npx -y @yawlabs/tailscale-mcp` | Tailnet management: devices, ACLs, routes, and DNS |
| **`uptime-kuma`** | stdio | `npx -y @davidfuchs/mcp-uptime-kuma` | Monitor healthchecks, status pages, and heartbeats |
| **`healthchecks`**| stdio | `npx -y healthchecks-mcp` | Dead man's switch and scheduled cron task inspection |
| **`server-services-configs`** | stdio | `@modelcontextprotocol/server-filesystem` | Scoped filesystem access to service configurations |
| **`caddy`** | stdio | `@yawlabs/caddy-mcp` | Caddy reverse proxy admin API for dynamic route inspection |
| **`context7`** | stdio | `@upstash/context7-mcp` | Real-time library documentation and code reference search |
| **`postgres`** | stdio | `@modelcontextprotocol/server-postgres` | PostgreSQL schema introspection and read queries |
| **`redis`** | stdio | `@yawlabs/redis-mcp` | Redis key inspection, TTLs, and metrics via SCAN |
| **`vault`** | stdio | `uv run --with "mcp<2" --with "httpx"` | HashiCorp Vault KV v2 secret reads/writes and TOTP management |
| **`slack`** | stdio | `@modelcontextprotocol/server-slack` | Slack workspace channels, threads, and bot communication |
| **`discord`** | stdio | `@pasympa/discord-mcp` | Discord guild channels, messages, and role queries |

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
