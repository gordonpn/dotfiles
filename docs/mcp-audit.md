# MCP Server Inventory and Disposition Audit

Audits all 37 MCP servers configured in [`dotfiles/gemini/mcp_config.template.json`](../dotfiles/gemini/mcp_config.template.json) to classify each into **Keep as MCP**, **CLI + skill**, or **Lazy-load / code-execute**, minimize turn-0 schema overhead for eager clients below 100 tools, preserve documentation and resource discovery workflows, and track follow-up migrations.

Related tracking: [#70](https://github.com/gordonpn/dotfiles/issues/70), [#17](https://github.com/gordonpn/dotfiles/issues/17), [#19](https://github.com/gordonpn/dotfiles/issues/19), [#27](https://github.com/gordonpn/dotfiles/issues/27), [#39](https://github.com/gordonpn/dotfiles/issues/39), [#43](https://github.com/gordonpn/dotfiles/issues/43), [#57](https://github.com/gordonpn/dotfiles/issues/57), [#67](https://github.com/gordonpn/dotfiles/issues/67), [#86](https://github.com/gordonpn/dotfiles/issues/86), [#89](https://github.com/gordonpn/dotfiles/issues/89).

---

## Methodology & Scope

- **Inventory source:** All `37` entries in `dotfiles/gemini/mcp_config.template.json` (`32` enabled by default, `5` disabled: `chrome-devtools`, `puppeteer`, `memory`, `server-services-configs`, `discord`), probed against the hydrated `~/.gemini/config/mcp_config.json` on `2026-11-15`.
- **Live MCP probing:** Executed uniform direct JSON-RPC (`protocolVersion: "2025-03-26"`, supplying `roots/list` to workspace-aware servers) over stdio to record handshake latency (`init` through `tools/list`), `tool_count`, compact `tools` JSON byte size, `resources/list` count, `prompts/list` count, and reported server version.
- **Schema token estimate:** Approximated as `round(schema_bytes / 4)` from compact serialized `tools` JSON payloads. Actual prompt overhead varies slightly by model tokenizer and client wrapper formatting.
- **Special runtime measurement notes:**
  - `server-services-configs` (`disabled: true`) exited with `eof rc=1` (`905 ms`) because `${HOME}/workspace/server-services-configs` no longer exists on disk after the repository was renamed to `homelab`. Its cached Antigravity schema baseline (`16` tools, `13,757` bytes, `~3,439` tokens in `~/.gemini/antigravity-cli/mcp/server-services-configs/`) is reported for reference.
  - `cclsp` returned `tools/list` in `78 ms`, while asynchronously preloading 7 matching LSP servers (`pyright-langserver`, `bash-language-server`, `lua-language-server`, `yaml-language-server`, `vscode-json-language-server`, `marksman`, `taplo`), all 7 of which logged initialization timeouts in stderr and stalled `mcp==1.1.2` `stdio_client` teardown for `45 s`.
  - Cold `uvx` startup for `fetch` measured `7,962 ms` before local `uvx` cache warmup and `481 ms` warm.
- **Usage evidence:** Aggregated tool-call logs across **178 local sessions**:
  - `75` Antigravity CLI transcripts (`~/.gemini/antigravity-cli/brain/*/.system_generated/logs/transcript*.jsonl`)
  - `80` OpenCode SQLite sessions (`~/.local/share/opencode/opencode.db`)
  - `4` Codex JSONL sessions (`~/.codex/sessions/**/*.jsonl`)
  - `19` GitHub Copilot CLI session logs (`~/.copilot/session-state/**/*.jsonl`)
  - Note: OpenCode, Codex, and Copilot runs in this dataset overwhelmingly used native shell/file tools (`bash`/`exec`/`view`/`edit`), recording `0` MCP calls in Codex/OpenCode and `1` (`fetch`) in Copilot, while `4,775` MCP tool calls came from Antigravity CLI sessions.

---

## Executive Summary & Core Profile Recommendation

| Profile / Subset | Servers | Total Tools | Compact Schema Bytes | ~Tokens | Status vs `< 100` Tool Target |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **All enabled in template** | 32 | 599 | 994,768 | ~248,691 | Exceeds 128-tool cap (`4.7x`) |
| **All disabled in template** (4 live + 1 cached) | 5 | 165 | 204,229 | ~51,058 | Disabled (`chrome-devtools`, `puppeteer`, `memory`, `server-services-configs`, `discord`) |
| **Current `minimal` default (`bin/mcp-sync`)** | 9 | 84 | 216,310 | ~54,078 | Compliant (`84` tools), but `semgrep` (`~22.6k` tok) is `41.9%` of schema cost |
| **Recommended interactive `core`** | 6 | 58 | 98,915 | ~24,729 | Compliant (`58` tools), cuts minimal tokens by **54.3%** |
| **Recommended headless `delegate.sh` `core`** (no `ai-memory`) | 5 | 34 | 31,483 | ~7,871 | Lean sub-35-tool baseline with doc + search + LSP + code graph |

### Key Takeaways

1. **The current 9-server minimal profile wastes ~29.7k turn-0 tokens on CLI-duplicative tools:**
   - `semgrep` (`7` tools, `90,544` bytes, `~22,636` tokens) consumes **41.9%** of the current minimal profile while `~/.local/bin/semgrep` is already installed locally and recorded only `3` MCP calls.
   - `repomix` (`6` tools, `~4,466` tokens, `0` uses), `git` (`14` tools, `~1,910` tokens, `0` eager-client calls), and `sequentialthinking` (`1` tool, `~700` tokens, `0` uses) add `21` more tools and `~7,076` tokens despite installed CLIs (`repomix`, `git`, `gh`) or existing skills (`git-workflow`, `thinking-model-router`).
2. **Swap `semgrep`, `repomix`, `git`, and `sequentialthinking` out of `DEFAULT_CORE_SERVERS`, and add `brave-search`:**
   - Recommended interactive `core`: `ai-memory`, `codebase-memory-mcp`, `cclsp`, `context7`, `fetch`, `brave-search` (**58 tools**, **~24,729 tokens**).
   - Adding `brave-search` (`2` tools, `~363` tokens, `105` logged uses) restores non-interactive web search fallback for Codex, OpenCode, and Copilot when native `search_web` is absent at negligible schema cost (`0.15%` of full profile).
3. **Top schema consumers must remain lazy-loaded or opt-in:**
   - Just `postman` (`~43.2k` tokens), `discord` (`~35.2k`, disabled), `github` (`~30.3k`), `semgrep` (`~22.6k`), `tailscale` (`~22.3k`), `uptime-kuma` (`~19.6k`), and `sonarqube` (`~11.3k`) account for **~184.5k tokens**.
4. **Already-disabled entries need cleanup:**
   - `server-services-configs` points to a deleted directory (`~/workspace/server-services-configs`), and `chrome-devtools`, `puppeteer`, and `memory` are superseded by `playwright` and `ai-memory` (`#102`).

---

## Full 37-Server Inventory & Disposition Matrix

All 37 servers from `dotfiles/gemini/mcp_config.template.json` appear in template order. Usage counts combine all 178 local sessions; `CLIs` indicates whether a matching CLI binary is installed in the local environment (`Yes` / `No`).

| Server | Tools | ~Schema tokens | Usage | CLI alternative | Disposition | Client tier | Notes |
| :--- | :---: | :---: | :---: | :--- | :--- | :--- | :--- |
| `cclsp` | 12 | 1,512 | 0 | LSP servers directly (`No` single generic CLI) | Keep as MCP | `core` | `78 ms` tools/list, but 7 LSP preloads timed out in stderr; fix preload config (`#103`) |
| `fetch` | 1 | 362 | 15 | `curl` / `httpie` (`Yes`) | Keep as MCP | `core` | Clean HTML-to-Markdown conversion with pagination; `481 ms` warm (`7,962 ms` cold `uvx`) |
| `git` | 14 | 1,910 | 496 | `git` + `gh` (`Yes`) | CLI + skill | `agy-only` (remove from eager `core`) | Heavy use in `agy` (`496`), `0` in Codex/OpenCode/Copilot; `git-workflow` skill covers CLI (`#100`) |
| `playwright` | 25 | 5,294 | 114 | `playwright` CLI (`No`) | Keep as MCP | `agy-only` / `opt-in` | Persistent accessibility-tree browser state cannot be cleanly replicated via stateless CLI (`567 ms`) |
| `chrome-devtools` | 33 | 8,076 | 0 | `playwright` MCP / headless Chrome flags (`No`) | CLI + skill | `remove` (already `disabled: true`) | Deprecated/consolidated: redundant with `playwright` (`681 ms` live probe) (`#102`) |
| `puppeteer` | 7 | 612 | 1 | `playwright` MCP (`No`) | CLI + skill | `remove` (already `disabled: true`) | Deprecated/consolidated: upstream npm package deprecated 2025, superseded by `playwright` (`#102`) |
| `memory` | 9 | 3,734 | 1 | `ai-memory` MCP / `ai-memory` CLI (`Yes`) | CLI + skill | `remove` (already `disabled: true`) | Deprecated/consolidated: superseded by `ai-memory`; keep data-export check before deleting (`#102`) |
| `ai-memory` | 24 | 16,858 | 1 | `ai-memory` CLI (`Yes`, bridge/daemon helper) | Keep as MCP | `core` (omitted in `delegate.sh`) | `39 ms` HTTP-bridged daemon (`127.0.0.1:49374`); structured wiki/handoff/inbox tools |
| `codebase-memory-mcp` | 17 | 4,327 | 0 | `rg` + `jq` (`Yes`, partial only) | Keep as MCP | `core` | AST index, call graph tracing, and architecture queries (`1,343 ms`, `2` prompts) |
| `sequentialthinking` | 1 | 700 | 0 | Native reasoning + `thinking-model-router` skill (`Yes`) | CLI + skill | `remove` from eager `core` | Zero logged calls; duplicates native model reasoning and existing `cc-thinking-skills` router (`#100`) |
| `github` | 44 | 30,255 | 3,242 | `gh` (`Yes`) | Lazy-load / code-execute | `agy-only` / `opt-in` | #1 used server (`3,242` calls, `4` resources, `81 ms`), but `~30.3k` tok; use `gh` CLI on eager clients |
| `brave-search` | 2 | 363 | 105 | `curl` Brave Search REST API (`Yes`, manual) | Keep as MCP | `core` (headless fallback) / `agy-only` | `105` calls; cheap (`363` tok) web search fallback (`GEMINI.md` Step 3); npm package frozen (`#104`) |
| `exa` | 3 | 1,660 | 0 | `curl` Exa REST API (`Yes`, manual) | Lazy-load / code-execute | `agy-only` / evaluate removal | `0` uses, `3` resources; overlaps `search_web`, `brave-search`, and `fetch` |
| `sqlite` | 6 | 320 | 0 | `sqlite3` (`Yes`, `/usr/bin/sqlite3`) | CLI + skill | `remove` / replace with CLI | `0` uses; hardcodes `anime-recommendation/anime.db` and requires `mcp==1.1.2` pin (`#101`, `#102`) |
| `cloudflare` | 89 | 7,837 | 14 | `wrangler` (`No` local) / Cloudflare API (`curl`) | Lazy-load / code-execute | `agy-only` / `opt-in` | `89` tools nears 128 cap by itself; keep on-demand on `agy` or `Code Mode`/bridge (`#39`, `#89`) |
| `prometheus` | 10 | 1,164 | 128 | `promtool` (`No`) / `curl` PromQL HTTP API | Lazy-load / code-execute | `agy-only` / `opt-in` | `128` calls against `master.tailb65f8c.ts.net:30090` (reachable); homelab-only |
| `loki` | 5 | 1,728 | 16 | `logcli` (`No`) / `curl` Loki HTTP API | Lazy-load / code-execute | `agy-only` / `opt-in` | `16` calls, `31 ms` Go binary against `master:31100` (reachable); homelab-only |
| `docker` | 10 | 7,535 | 0 | `docker` CLI (`No` installed locally) | Lazy-load / code-execute | `agy-only` / `opt-in` | Multi-host SSH profile wrapper (`docker-profiles.json`); needs `roots/list` handshake |
| `kubernetes` | 23 | 5,977 | 412 | `kubectl` + `helm` + `helmfile` (`Yes`) | Lazy-load / code-execute | `agy-only` / `opt-in` | `412` calls + `5` MCP resources (`k3s-master` reachable); `1,391 ms` startup |
| `terraform` | 9 | 2,535 | 8 | `tofu` / `terraform` (`Yes`) | Keep as MCP | `agy-only` / `opt-in` | `98 ms`, `2` resources; Registry provider/module docs lookup works without `TFE_TOKEN` |
| `ssh` | 18 | 10,223 | 61 | `ssh` + `scp` (`Yes`) | Lazy-load / code-execute | `agy-only` / `opt-in` | `61` calls, `2` resources; enforces `ssh-profiles.json` targets (`master`, `router`, `vps`) |
| `tailscale` | 98 | 22,268 | 12 | `tailscale` CLI (`No` local; host-scoped only) | Lazy-load / code-execute | `agy-only` / `Code Mode` | `98` tools / `~22.3k` tok; admin ACL/key/DNS API has no parity in `tailscale` node CLI |
| `uptime-kuma` | 36 | 19,631 | 43 | `curl` / Python Socket.IO client (`No` official CLI) | Lazy-load / code-execute | `agy-only` | `43` calls, `~19.6k` tok; no official CLI for Uptime Kuma monitor/status management |
| `healthchecks` | 14 | 7,752 | 29 | `curl` Healthchecks.io REST API (`No` CLI) | Lazy-load / code-execute | `agy-only` | `29` calls against `HEALTHCHECKS_API_KEY`; clean CRUD/ping inspection (`525 ms`) |
| `filesystem` | 16 | 4,842 | 6 | Native agent file tools + `rg`/`fd`/`find` (`Yes`) | CLI + skill | `agy-only` / evaluate removal | `6` calls; built-in harness file tools already cover `${HOME}` ops (`601 ms`) |
| `server-services-configs` | 16 (cached) | 3,439 (cached) | 1 | Native agent file tools (`Yes`) | CLI + skill | `remove` (already `disabled: true`) | Live probe failed (`eof rc=1`): repo path renamed to `homelab`; redundant with `filesystem` (`#102`) |
| `repomix` | 6 | 4,466 | 0 | `repomix` (`Yes`, `~/.local/bin/repomix`) | CLI + skill | `agy-only` / move out of `core` | CLI already installed and matches MCP capabilities; saves `~4.5k` eager tokens (`#100`, `#101`) |
| `caddy` | 18 | 6,196 | 0 | `caddy` CLI (`No`) / `curl` Caddy Admin API | Lazy-load / code-execute | `agy-only` (audit endpoint) | `0` uses; `master:2019` refused TCP connection during probe (`#104`) |
| `context7` | 2 | 1,307 | 23 | `curl` / `gh` fallback (no Context7 CLI) | Keep as MCP | `core` | `23` uses; mandatory Step 1 library docs lookup in `GEMINI.md` (`928 ms`) |
| `postgres` | 1 | 33 | 0 | `psql` / `pgcli` (`No` installed locally) | CLI + skill | `remove` / replace with CLI | Deprecated frozen package; `localhost:5432` refused connection; `0` uses (`#101`, `#102`) |
| `redis` | 7 | 2,342 | 1 | `redis-cli` (`No` local; container exec) | CLI + skill | `opt-in` / replace with CLI | `localhost:6379` refused connection; `1` historical call (`redis_health`) (`#101`) |
| `vault` | 13 | 1,385 | 0 | `vault` CLI (`No` local) | Lazy-load / code-execute | `agy-only` (audit endpoint) | Custom FastMCP script (`bin/vault-mcp-server`) adds TOTP; `VAULT_TOKEN` empty & `:8200` refused (`#104`) |
| `slack` | 8 | 779 | 19 | `curl` Slack Web API (`No` CLI) | Lazy-load / code-execute | `agy-only` | `19` calls; frozen 2025 npm package (migration note `korotovsky/slack-mcp-server`) (`#104`) |
| `discord` | 100 | 35,197 | 1 | `curl` Discord REST / bot CLI (`No`) | Lazy-load / code-execute | `remove` or keep `disabled: true` | **Largest disabled server (`100` tools, `~35.2k` tok, `5,467 ms`)**, `DISCORD_TOKEN` empty (`#102`) |
| `semgrep` | 7 | 22,636 | 3 | `semgrep` (`Yes`, `~/.local/bin/semgrep`) | CLI + skill | `agy-only` / move out of `core` | **`~22.6k` tok (`41.9%` of current minimal)**, `1,963 ms`, `3` uses; CLI installed locally (`#100`, `#101`) |
| `postman` | 42 | 43,193 | 0 | `newman` / `postman` CLI (`No`) / `curl` | Lazy-load / code-execute | `agy-only` | **Largest enabled schema payload (`172.8 KiB`, `~43.2k` tok)**, `0` uses, `1` resource |
| `sonarqube` | 18 | 11,301 | 1 | `sonar-scanner` (`No`) / Web API (`curl`) | Lazy-load / code-execute | `agy-only` / `opt-in` | Slowest enabled startup (`3,873 ms` JVM + analyzer download), `~11.3k` tok, `1` use |

---

## Runtime, Transport, Auth & Homelab Dependencies

All 37 entries use **stdio** client transport in `dotfiles/gemini/mcp_config.template.json` (`ai-memory` runs an `mcp-bridge` over stdio to its local HTTP daemon on `127.0.0.1:49374`). Exact startup times, compact schema bytes, capability counts, credential variables, and live network reachability recorded on `2026-11-15`:

| Server | Default Enabled | Status (`tools/list`) | Init / Total (`ms`) | Schema Bytes | Resources / Prompts | Auth Env / Secret Status | Network / Dependency Scope |
| :--- | :---: | :--- | :---: | :---: | :---: | :--- | :--- |
| `cclsp` | Yes | `ok` (background LSP preload timed out) | 77 / 78 | 6,048 | 0 / 0 | `CCLSP_CONFIG_PATH` (`SET`) | Local LSP binaries (`14` servers configured) |
| `fetch` | Yes | `ok` | 480 / 481 (`7,962` cold) | 1,449 | 0 / 1 | None | Outbound internet HTTP/HTTPS |
| `git` | Yes | `ok` | 387 / 388 | 7,639 | 0 / 2 | None | Local git repositories |
| `playwright` | Yes | `ok` | 565 / 567 | 21,177 | 0 / 0 | None | Local headless browser + target URLs |
| `chrome-devtools` | No | `ok` | 676 / 681 | 32,302 | 0 / 0 | None | Local Chrome DevTools target |
| `puppeteer` | No | `ok` | 663 / 664 | 2,448 | 0 / 0 | None | Local Chromium + target URLs |
| `memory` | No | `ok` | 1,682 / 1,685 | 14,934 | 1 / 0 | `MEMORY_FILE_PATH` (`SET`) | Local `~/.gemini/memory.json` |
| `ai-memory` | Yes | `ok` | 35 / 39 | 67,432 | 0 / 0 | Local daemon `127.0.0.1:49374` | Local SQLite + `ai-memory` launchd daemon (reachable) |
| `codebase-memory-mcp` | Yes | `ok` | 1,330 / 1,343 | 17,308 | 0 / 2 | None | Local cached graph DB (`~/.cache/codebase-memory-mcp`) |
| `sequentialthinking` | Yes | `ok` | 549 / 551 | 2,801 | 0 / 0 | None | Local in-process only |
| `github` | Yes | `ok` | 77 / 81 | 121,020 | 4 / 2 | `GITHUB_PERSONAL_ACCESS_TOKEN` (`SET`) | GitHub SaaS API |
| `brave-search` | Yes | `ok` | 694 / 694 | 1,451 | 0 / 0 | `BRAVE_API_KEY` (`SET`) | Brave Search SaaS API |
| `exa` | Yes | `ok` | 490 / 492 | 6,642 | 3 / 0 | `EXA_API_KEY` (`SET`) | Exa SaaS API |
| `sqlite` | Yes | `ok` | 291 / 293 | 1,282 | 1 / 1 | None (`anime.db` exists locally) | Local SQLite file (`--with mcp==1.1.2`) |
| `cloudflare` | Yes | `ok` | 789 / 790 | 31,349 | 0 / 0 | `CLOUDFLARE_API_TOKEN` (`SET`) | Cloudflare SaaS API |
| `prometheus` | Yes | `ok` | 783 / 785 | 4,658 | 0 / 0 | `PROMETHEUS_URL` (`SET`) | Homelab Tailscale `master.tailb65f8c.ts.net:30090` (reachable) |
| `loki` | Yes | `ok` | 31 / 31 | 6,912 | 0 / 0 | `LOKI_URL` (`SET`) | Homelab Tailscale `master.tailb65f8c.ts.net:31100` (reachable) |
| `docker` | Yes | `ok` | 707 / 709 | 30,141 | 0 / 0 | `DOCKER_MCP_PROFILES_FILE` (`SET`) | Local Docker socket + SSH profiles (`master`, `vps`) |
| `kubernetes` | Yes | `ok` | 1,390 / 1,391 | 23,909 | 5 / 0 | `KUBECONFIG` (`SET`) | `docker-desktop` + Homelab Tailscale `master:6443` (reachable) |
| `terraform` | Yes | `ok` | 97 / 98 | 10,139 | 2 / 0 | `TFE_TOKEN` (`EMPTY`), `TFE_ADDRESS` (`SET`) | Public Terraform Registry (`app.terraform.io` for TFE optional) |
| `ssh` | Yes | `ok` | 934 / 937 | 40,893 | 2 / 0 | `SSH_PROFILES_FILE` (`SET`) | Homelab SSH profiles (`master`, `master-tailscale`, `router`, `vps`) |
| `tailscale` | Yes | `ok` | 665 / 670 | 89,071 | 4 / 0 | `TAILSCALE_API_KEY` (`SET`) | Tailscale Cloud Admin API |
| `uptime-kuma` | Yes | `ok` | 917 / 926 | 78,524 | 0 / 0 | `UPTIME_KUMA_URL` / `_JWT_TOKEN` (`SET`) | Remote hosted Uptime Kuma (`code.run`) |
| `healthchecks` | Yes | `ok` | 521 / 525 | 31,006 | 0 / 0 | `HEALTHCHECKS_API_KEY` (`SET`) | Healthchecks.io SaaS API |
| `filesystem` | Yes | `ok` | 597 / 601 | 19,369 | 0 / 0 | None (arg: `${HOME}`) | Local filesystem (`$HOME` root) |
| `server-services-configs` | No | `eof rc=1` | - / 905 | 13,757 (cached) | 0 / 0 | None (missing directory) | Local deleted path `${HOME}/workspace/server-services-configs` |
| `repomix` | Yes | `ok` | 212 / 215 | 17,862 | 0 / 0 | None | Local CLI + optional remote git clone |
| `caddy` | Yes | `ok` | 1,390 / 1,396 | 24,783 | 0 / 0 | `CADDY_ADMIN_URL` (`SET`) | Homelab Tailscale `master.tailb65f8c.ts.net:2019` (connection refused) |
| `context7` | Yes | `ok` | 926 / 928 | 5,227 | 0 / 0 | None | Context7 SaaS API |
| `postgres` | Yes | `ok` | 489 / 493 | 131 | -1 / 0 | `POSTGRES_URL` (inline arg URI) | `localhost:5432` (connection refused) |
| `redis` | Yes | `ok` | 871 / 874 | 9,370 | 0 / 0 | `REDIS_URL` (`SET`) | `localhost:6379` (connection refused) |
| `vault` | Yes | `ok` | 346 / 348 | 5,540 | 0 / 0 | `VAULT_ADDR` (`SET`), `VAULT_TOKEN` (`EMPTY`) | Homelab Tailscale `master.tailb65f8c.ts.net:8200` (connection refused) |
| `slack` | Yes | `ok` | 540 / 540 | 3,116 | 0 / 0 | `SLACK_BOT_TOKEN` / `_TEAM_ID` (`SET`) | Slack Web API |
| `discord` | No | `ok` | 5,464 / 5,467 | 140,788 | 0 / 0 | `DISCORD_TOKEN` (`EMPTY`) | Discord API |
| `semgrep` | Yes | `ok` | 1,961 / 1,963 | 90,544 | 2 / 2 | None | Local CLI + optional Semgrep AppSec rules |
| `postman` | Yes | `ok` | 1,334 / 1,343 | 172,771 | 1 / 0 | `POSTMAN_API_KEY` (`SET`) | Postman SaaS API |
| `sonarqube` | Yes | `ok` | 3,862 / 3,873 | 45,204 | 0 / 0 | `SONARQUBE_URL` / `_TOKEN` / `_ORG` (`SET`) | SonarCloud (`sonarcloud.io`) + local JVM analyzers |

---

## CLI + Skill Migration Candidates

Every server classified as `CLI + skill` maps to a specific CLI, concrete gaps vs the MCP server, a follow-up skill, and data/credential boundary notes:

| Server | Specific CLI (Installed?) | Gaps vs MCP | Follow-up Skill | Credential & Data-Boundary Impact |
| :--- | :--- | :--- | :--- | :--- |
| **`semgrep`** | `semgrep` (`~/.local/bin/semgrep`, `Yes`) | Lacks dedicated `semgrep_rule_schema` JSON dump and persistent MCP `rules` prompt; covered by `semgrep validate`, `semgrep scan --json --config ...`, and `--pattern`. | `semgrep-scan` (`#101`) | Low risk: runs locally with zero secret env vars; CLI avoids loading `90.5 KiB` of turn-0 tool schemas. |
| **`repomix`** | `repomix` (`~/.local/bin/repomix`, `Yes`) | Outputs to disk/stdout instead of returning managed MCP `outputId` handles for `grep_repomix_output` / `read_repomix_output`; agents inspect generated output with native file/search tools. | `repomix` (`#101`) | Low risk: local read-only packing; remote repo flags (`--remote`) inherit shell network access and must respect untrusted-content rules. |
| **`git`** | `git` + `gh` (`Yes`, `/opt/homebrew/bin/{git,gh}`) | No single unified `repo_path` guard parameter; CLI offers strictly richer operations (`rebase`, `worktree`, `--cached`, `bisect`). | `git-workflow` (already installed via ECC) | Moderate improvement in eager clients (saves 14 tools / `~1.9k` tok); `git` runs with user SSH/credential-helper scope in shell either way. |
| **`sequentialthinking`** | Native model thinking + `thinking-model-router` (`Yes`) | No external stateful `thoughtNumber` counter tool; native reasoning + `~/.agents/skills/thinking-model-router` handles structured reasoning models directly. | None (existing `thinking-model-router`) | None: pure in-context reasoning, zero external I/O. |
| **`filesystem`** | Built-in harness file tools + `rg`/`fd`/`find` (`Yes`) | Built-in CLI/harness tools do not constrain paths solely via an MCP `--allowed-directories` argument; sandboxing/worktrees enforce boundary containment instead. | None (built-in tools + existing rules) | Important: MCP server scoped access to `${HOME}`; built-in shell commands rely on harness sandboxing (`--sandbox`) for directory isolation. |
| **`sqlite`** | `sqlite3` (`Yes`, `/usr/bin/sqlite3`) | Lacks business-insight `append_insight` / `memo://insights` MCP resource; pure SQL queries and schema inspection (`.schema`, `.tables`) are cleaner in `sqlite3 -readonly`. | `local-db-cli` (`#101`) | Better boundary: removes hardcoded `${SQLITE_DB_PATH}` coupling to `anime.db` and passes explicit `-readonly` when inspecting untrusted DBs. |
| **`postgres`** | `psql` / `pgcli` (`No` installed locally; install via Homebrew if needed) | Single-tool MCP `query` lacks `\dt`, explain formatting, and role switching; CLI adds interactive meta-commands and explicit transaction flags. | `local-db-cli` (`#101`) | **Critical improvement:** currently `bin/mcp-sync` writes raw `POSTGRES_URL` into CLI args in plaintext configs (`0600`). Migrating to CLI + `~/.pgpass` / `.env` removes URI embedding in MCP definitions. |
| **`redis`** | `redis-cli` (`No` installed locally; or `kubectl`/`docker exec`) | Lacks pre-packaged composite `redis_health` / `redis_advisor` text report; `redis-cli --scan`, `INFO`, `TTL`, `SLOWLOG GET` require multi-step commands. | `local-db-cli` (`#101`) | Moderate: keep `REDIS_URL` / passwords out of shell history (`REDISCLI_AUTH` env or `.env` rather than `-a` flag). |
| **`chrome-devtools`** *(disabled)* | `playwright` MCP / Chrome CLI (`No`) | Performance trace capture not exposed directly by basic Playwright actions without `page.tracing` scripts; already consolidated onto `playwright` MCP. | None (remove `#102`) | None (`disabled: true`, uncredentialed). |
| **`puppeteer`** *(disabled)* | `playwright` MCP (`No`) | Deprecated 2025 package; full parity covered by `playwright` MCP. | None (remove `#102`) | None (`disabled: true`, uncredentialed). |
| **`memory`** *(disabled)* | `ai-memory` MCP (`Yes`) | Deprecated legacy JSON entity graph (`~/.gemini/memory.json`), superseded by `ai-memory`. | Existing `ai-memory-*` skills (`#102`) | None (verify `~/.gemini/memory.json` holds no unmigrated data before removing `bin/mcp-sync` seeding). |
| **`server-services-configs`** *(disabled)* | Native file tools / `filesystem` (`Yes`) | Directory `${HOME}/workspace/server-services-configs` no longer exists (renamed to `homelab`). | None (remove `#102`) | None (broken legacy path). |

---

## Lazy-Load / Code-Execute Mechanisms & Fallbacks

Each client harness supports a distinct mechanism for loading heavy or infrequently used servers without turn-0 context bloat:

| Client / Harness | Native Lazy-Load Mechanism | Opt-In / Dynamic Fallback | Current Code-Mode / Bridge Status |
| :--- | :--- | :--- | :--- |
| **Antigravity CLI (`agy`)** | **Native disk lazy-loading:** renders tool schemas as directory files (`~/.gemini/antigravity-cli/mcp/<server>/*.json`) and invokes via `call_mcp_tool` (`0` eager prompt tokens on turn 0). | Already holds all `32` enabled servers cleanly; `list_resources` / `read_resource` work on demand. | Primary mechanism works today; no gateway proxy needed (`#30`, `#41` closed). |
| **Codex CLI (`codex`)** | None enabled by default (`code_mode_tool_search` is experimental / `under development`, `tool_search` removed). | `-c mcp_servers.<name>.enabled=true` per session, or `mcp-sync --codex-servers "..."` / `--codex-profile full`. | `#89` tracks re-verifying `code_mode_tool_search` once non-experimental (currently still initializes enabled servers eagerly). |
| **OpenCode (`opencode`)** | None enabled by default (`OPENCODE_EXPERIMENTAL_CODE_MODE=1` enables `tools.$codemode.search` while still starting enabled servers eagerly). | `mcp-sync --opencode-servers "..."`, `--opencode-profile full`, or `delegate.sh --mcp-profile`. | `#89` tracks stable Code Mode; `#39` tracks MCP-to-CLI bridges (`mcporter`/`mcpc`/`mcp2cli`) for delegated workers. |
| **GitHub Copilot CLI (`copilot`)** | None (CLI ignores `disabled` flags, so `bin/mcp-sync` writes only enabled `core` servers to `~/.copilot/mcp-config.json`). | `mcp-sync --copilot-servers "..."` / `--copilot-profile full`; `delegate.sh` restricts built-ins via `--available-tools`. | `#39` (MCP-to-CLI bridge) or `#43` (MCPProxy) would expose heavy servers like `github`/`cloudflare`/`tailscale` without 128-tool cap errors. |
| **DeepSeek Harness (`scripts/deepseek-analyze.sh`)** | None (`OPENCODE_CONFIG` points to isolated minimal profile). | `DELEGATE_MCP_SERVERS` / `DELEGATE_MCP_PROFILE`. | `#86` tracks formal DeepSeek harness compatibility verification. |

### Lazy-Load Candidate Mapping

- **`github`, `kubernetes`, `prometheus`, `loki`, `ssh`, `docker`, `uptime-kuma`, `healthchecks`, `cloudflare`, `tailscale`, `slack`, `postman`, `sonarqube`, `caddy`, `vault`, `exa`, `discord` (`disabled: true`):**
  - **Antigravity CLI (`agy`):** Keep registered and lazy-loaded natively (`disabled: false`, except `discord` kept `disabled: true` unless needed).
  - **Eager clients (Codex / OpenCode / Copilot):** Set disabled by default; invoke native CLI alternatives where installed (`gh`, `kubectl`/`helm`, `ssh`) or enable per session (`-c mcp_servers.<name>.enabled=true`, `--*-servers`).
  - **Code-execution / bridge candidates (`#39`, `#43`, `#89`):** `cloudflare` (`89` tools), `tailscale` (`98` tools), `github` (`44` tools), and `postman` (`42` tools) benefit most from dynamic tool search or code execution because loading any two of them eagerly approaches or exceeds the `128`-tool limit.

---

## Documentation & Resource Discovery Coverage

Per the explicit requirement in [#70](https://github.com/gordonpn/dotfiles/issues/70#issuecomment-6829402987), removing eager schemas must never blind agents when retrieving external docs, specs, or internal project knowledge:

1. **Library / Framework / API Docs:** `context7` (`core`, `2` tools, `~1.3k` tok, `23` uses) stays enabled across **every** client (`GEMINI.md` Step 1).
2. **Arbitrary Web Docs, RFCs, & Markdown Specs:** `fetch` (`core`, `1` tool, `~362` tok, `15` uses) stays enabled across **every** client (`481 ms` warm startup, clean HTML-to-Markdown pagination).
3. **Web Search Fallback (Headless / Non-Native Clients):** `brave-search` (`~363` tok, `105` uses) added to recommended eager `core` (or `opt-in`) guarantees web lookup even inside Codex, OpenCode, or DeepSeek workers where `search_web` is absent (`GEMINI.md` Step 3). `exa` (`~1.7k` tok, `0` uses) remains lazy-loaded on `agy`.
4. **IaC Registry & Schema Lookup:** `terraform` (`9` tools, `~2.5k` tok, `2` MCP resources, `8` uses) stays **Keep as MCP** (`agy-only` / `opt-in`) because `tofu`/`terraform` CLI cannot query arbitrary uninitialized provider/module docs from the public Registry (`TFE_TOKEN` is unnecessary for Registry tools).
5. **Internal Repo Knowledge, ADRs & Cross-Session Wiki:** `ai-memory` (`~16.9k` tok) + `codebase-memory-mcp` (`~4.3k` tok) stay `core` for interactive sessions (with `codebase-memory-mcp` retained in headless `delegate.sh`).
6. **Live Infrastructure & API Schemas:** `github` (`4` resources), `kubernetes` (`5` resources + `explain_resource`), `postman` (`1` Instructions resource), `prometheus`/`loki` (label taxonomy tools), and `tailscale` (`4` resources) stay on-demand via `agy` lazy-loading (`0` turn-0 tokens).

---

## Credential & Data-Boundary Implications

Per `dotfiles/agent-skills/engineering-standards/references/ai-agents.md`, moving integrations from MCP to shell CLIs or code execution shifts where secrets live and what guardrails apply:

1. **Secret scoping (MCP child env vs ambient shell environment):**
   - Today, `bin/mcp-sync` writes secrets (`GITHUB_PERSONAL_ACCESS_TOKEN`, `BRAVE_API_KEY`, `EXA_API_KEY`, `TAILSCALE_API_KEY`, `CLOUDFLARE_API_TOKEN`, `UPTIME_KUMA_JWT_TOKEN`, `HEALTHCHECKS_API_KEY`, `POSTMAN_API_KEY`, `SONARQUBE_TOKEN`, `SLACK_BOT_TOKEN`, `VAULT_TOKEN`) into `0600` client configs scoped to each MCP server subprocess.
   - Moving **`vault`**, **`postgres`**, **`tailscale`**, or **`github`** to shell CLI execution (`CLI + skill` or ad-hoc `curl`) means either storing auth in CLI credential stores (`gh auth`, `~/.pgpass`, `vault login`) or exposing tokens directly inside shell commands where arbitrary bash scripts or logs could read `env`.
   - **Rule:** Keep `vault`, `tailscale`, `cloudflare`, `postman`, `sonarqube`, `uptime-kuma`, `healthchecks`, and `slack` as MCP (`agy` lazy-load / opt-in) rather than replacing them with raw `curl` + shell-exported tokens. Where `postgres` or `sqlite` moves to CLI (`#101`), require `~/.pgpass` or untracked `.env` instead of embedding `POSTGRES_URL` passwords in `~/.gemini/config/mcp_config.json` and `~/.codex/config.toml`.
2. **SSH & Docker host allowlisting:**
   - `ssh` and `docker` MCP servers restrict targets through `~/.gemini/ssh-profiles.json` and `~/.gemini/docker-profiles.json`. Direct `ssh` shell usage bypasses MCP job wrappers; `ssh` MCP remains useful for structured multi-host triage while preserving explicit operator rules against destructive commands.
3. **Host filesystem boundary:**
   - `filesystem` MCP enforces an explicit root (`${HOME}`). Built-in file/shell tools rely on harness worktree sandboxing (`codex --sandbox`, `delegate.sh` git worktrees) rather than an MCP root allowlist.
4. **Prompt injection via untrusted retrieval (`ai-agents.md`):**
   - `fetch`, `brave-search`, `exa`, `context7`, `github` (issues/PRs), `slack`, and `loki` retrieve untrusted external content. Keeping structured MCP schemas reduces shell-escaping injection risks compared to interpolating untrusted strings into `curl`/shell pipelines; regardless of transport, treat retrieved output as untrusted data.

---

## Follow-Up Issues

### Newly Filed from This Audit

- [#100](https://github.com/gordonpn/dotfiles/issues/100) `perf(mcp-sync): optimize minimal MCP profile using audit schema token measurements` (`P2`, `S`)
- [#101](https://github.com/gordonpn/dotfiles/issues/101) `feat(skills): add CLI-backed skills for semgrep, repomix, and local DB inspection` (`P2`, `S`)
- [#102](https://github.com/gordonpn/dotfiles/issues/102) `chore(mcp): remove deprecated and broken legacy MCP entries from template and sync` (`P2`, `XS`)
- [#103](https://github.com/gordonpn/dotfiles/issues/103) `fix(cclsp): eliminate startup LSP initialization timeouts and preload noise` (`P3`, `S`)
- [#104](https://github.com/gordonpn/dotfiles/issues/104) `fix(mcp): remediate unreachable homelab endpoints and frozen upstream npm servers` (`P3`, `S`)

### Existing Related Open Issues

- [#27](https://github.com/gordonpn/dotfiles/issues/27) Project-specific MCP profiles
- [#39](https://github.com/gordonpn/dotfiles/issues/39) Evaluate MCP-to-CLI bridges (`MCPorter`, `mcpc`, `mcp2cli`)
- [#43](https://github.com/gordonpn/dotfiles/issues/43) Evaluate MCPProxy gateway
- [#67](https://github.com/gordonpn/dotfiles/issues/67) Audit and improve `bin/mcp-sync`
- [#86](https://github.com/gordonpn/dotfiles/issues/86) Verify DeepSeek harness MCP compatibility and minimal profile
- [#89](https://github.com/gordonpn/dotfiles/issues/89) Re-verify Codex `code_mode_tool_search` and OpenCode Code Mode once stabilized
