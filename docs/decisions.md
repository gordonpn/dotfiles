# Implementation Decisions Log

This document records non-obvious engineering and implementation decisions made in Dotfiles, ordered newest first.

## 2026-11-22: Hybrid Codex-first routing using Codex plugin for read-only continuity and delegate.sh for worktree builds

- Decision: Update Antigravity CLI routing in `dotfiles/gemini/antigravity-cli/rules/auto-delegation.md`, `dotfiles/gemini/GEMINI.md`, `README.md`, and `docs/mcp-setup.md` so substantive requests route Codex-first via the installed Antigravity Codex plugin (`codex-runner.mjs` in read-only mode with `--resume-last`) for questions, debugging, planning, architecture discussions, reviews, and technical research, while retaining `delegate.sh` (`--mode build`) for implementation writes inside isolated Git worktrees, keeping automatic fallback through OpenCode free models and GitHub Copilot Student on Codex quota/rate-limit/availability failures without blocking for confirmation.
- Rationale: The Codex plugin preserves session continuity (`--resume-last`) and handles read-only analysis and reviews cleanly without provisioning throwaway worktrees, whereas `delegate.sh` protects the base checkout with isolated `delegate/...` worktrees, dirty-base overlap detection, and automatic zero-cost fallback when Codex hits limits.
- Rejected alternatives: Replacing `delegate.sh` entirely for workspace edits (loses isolated worktrees, dirty-base overlap protection, and multi-provider OpenCode/Copilot fallback), or pausing to ask before every fallback (adds interactive round-trips during automated runs).

## 2026-11-19: Drop delegate.sh opt-in and dirty-tree gates and prefer external delegation over invoke_subagent

- Decision: Remove the blocking `agents.delegationAllowed=true` check (`--automatic` remains accepted as a compatibility no-op) and blocking clean-working-tree check from `delegate.sh`, warn on stderr, record `dirty_base=1` and `dirty_base_overlap=0|1` in `manifest.txt`, print a `Base snapshot note` and any `Overlapping dirty base files` in `DELEGATION_RESULT` when uncommitted or untracked base edits exist, require manual hunk reconciliation rather than whole-file overwrites or resets when integrating overlapping dirty files, and instruct Antigravity (`agy`) in `dotfiles/gemini/GEMINI.md`, `auto-delegation.md`, and `delegate-coding-agents/SKILL.md` to prefer `delegate.sh` over native `invoke_subagent` (with confidentiality enforced by orchestrator policy rather than a per-repo script opt-in gate).
- Rationale: Unblock automatic delegation across personal repositories (including worktrees or checkouts with unrelated uncommitted files like `NEXT.md`) and offload eligible work onto Codex, free OpenCode models, and Copilot Student rather than defaulting to `invoke_subagent` on Antigravity quota, while keeping snapshot semantics transparent and preventing local uncommitted work from being clobbered when worker changes overlap with dirty base files.
- Rejected alternatives: Requiring an opt-in git config per repo (`agents.delegationAllowed=true`) or failing whenever local files are dirty (blocked routine delegation on personal repos), auto-stashing/copying dirty working trees into the worker worktree (risks leaking `.env`/untracked artifacts or breaking cherry-picks), or defaulting Antigravity to `invoke_subagent` (consumes Antigravity quota instead of Codex/OpenCode/Copilot).
- Source: [PR #117](https://github.com/gordonpn/dotfiles/pull/117) (`feat/prefer-delegate-drop-gates`).

## 2026-11-15: Adopt three-tier MCP architecture and lock server dispositions

- Decision: Formalize a three-tier MCP distribution policy in [`docs/mcp-audit.md`](mcp-audit.md): (1) eager clients (`codex`, `opencode`, `copilot`, and `delegate.sh`) receive only a lean `core` (`< 100` tools) keeping `context7`, `fetch`, `cclsp`, `codebase-memory-mcp`, `brave-search`, and interactive `ai-memory`; (2) CLI-covered integrations (`semgrep`, `repomix`, `git`, `sequentialthinking`, `sqlite`, `postgres`, `redis`) move out of eager profiles onto native CLIs and Agent Skills; and (3) retain `filesystem` (preserving `${HOME}` root scoping on `agy`) and `exa` (lazy semantic search fallback on `agy` alongside `brave-search`), while disabling `discord`, `caddy`, and `vault` (`caddy` and `vault` unreachable over Tailscale; `discord` unused) and deleting broken/superseded legacy entries (`server-services-configs`, `chrome-devtools`, `puppeteer`, `memory`).
- Rationale: Cuts eager minimal profile turn-0 schema cost by ~54.3% (`~54.1k` to `~24.7k` tokens interactively and `~7.9k` headless) while preserving web search coverage (`brave-search` in `core` + `exa` lazy on `agy`) and `${HOME}` scoping on `agy` (`filesystem`), without running unreachable or unused daemon/admin servers.
- Rejected alternatives: Removing `brave-search` or `exa` despite complementary keyword/semantic search workflows, removing `filesystem` despite its explicit `${HOME}` root allowlist on `agy`, introducing a custom MCP proxy daemon (rejected in #30/#41), or keeping unmaintained/unreachable `caddy`, `vault`, and legacy entries active.
- Source: [#70 investigation: audit MCP servers and classify as keep MCP, CLI + skill, or lazy-load/code-execution](https://github.com/gordonpn/dotfiles/issues/70), [PR #105](https://github.com/gordonpn/dotfiles/pull/105), follow-ups [#100](https://github.com/gordonpn/dotfiles/issues/100)-[#104](https://github.com/gordonpn/dotfiles/issues/104).

## 2026-11-15: Package domain engineering standards as a progressive-disclosure skill and sync all tracked skills across CLIs

- Decision: Add only non-duplicative baseline rules (untrusted content authorization boundaries, existing machine-readable contract validation, and on-demand domain triggers) to `dotfiles/gemini/GEMINI.md`, package the 8 domain standards profiles under `dotfiles/agent-skills/engineering-standards/` (`SKILL.md` plus `references/*.md`), update `bin/mcp-sync` to iterate over all tracked skills in `dotfiles/agent-skills/*`, and extend instruction and skill symlinks to GitHub Copilot (`${COPILOT_DIR}/instructions/global.instructions.md`, `${COPILOT_DIR}/skills`) and Claude Code (`~/.claude/CLAUDE.md`, `~/.claude/skills`) alongside Antigravity, Codex, and OpenCode.
- Rationale: Keep always-loaded instructions small while allowing every terminal AI CLI to load domain standards only when triggered by changed files or interfaces, and keep skill discovery aligned with Copilot CLI's `COPILOT_HOME` behavior (where overriding `COPILOT_HOME` disables `~/.agents/skills` scanning).
- Rejected alternatives: Appending all 8 domain profile files directly into `dotfiles/gemini/GEMINI.md` (unnecessary always-on context bloat), keeping `delegate-coding-agents` hardcoded in `bin/mcp-sync`, or duplicating skills into `~/.config/opencode/skills` when OpenCode natively scans `~/.agents/skills`.
- Source: [#97 feat(agents): add engineering-standards skill and sync skills across agent CLIs](https://github.com/gordonpn/dotfiles/pull/97).

## 2026-11-12: Standardize GitHub issue conventions, discovery tracking, and decisions logs

- Decision: Adopt Conventional Commits syntax (`<type>(<optional-scope>): <imperative summary>`) for GitHub issue titles alongside a lean 3-section issue body template, require ready-for-review PRs instead of defaulting to drafts, separate global rules in `dotfiles/gemini/GEMINI.md` from dotfiles-specific rules in `AGENTS.md`, require proactive issue creation for adjacent discoveries, and standardize per-project `docs/decisions.md` logs.
- Rationale: Keep issue metadata, discovery capture, and implementation decisions consistent across personal repositories without polluting global instructions with repository-specific constraints.
- Rejected alternatives: Shipping `.github/ISSUE_TEMPLATE/` files across repositories or keeping project-specific database and dotfiles path rules in global instructions.
- Source: [#68 docs(agents): define github issue naming and body conventions](https://github.com/gordonpn/dotfiles/pull/68)

## 2026-11-11: Lean Codex CLI MCP profile and one-shot agent isolation

- Decision: Disable heavy or credentialed MCP servers by default (`enabled = false` with pre-populated configs) in `~/.codex/config.toml`, retain all 37 lazy-loaded servers on Antigravity CLI, and supply isolated minimal MCP profiles (`opencode-minimal-profile.json`) for one-shot delegated OpenCode and Codex tasks while relying on OpenCode's native `~/.agents/skills` scanning rather than duplicating symlinks in `~/.config/opencode/skills`.
- Rationale: Cut Codex CLI startup and turn-0 token overhead, prevent interactive MCP timeouts and log noise in headless worktrees, eliminate duplicate-skill warnings in OpenCode v1.19+, and preserve single-flag session overrides without re-entering credentials.
- Rejected alternatives: Building a custom MCP control plane or gateway wrapper (closed as not planned in favor of static client tiering), mirroring skills into both OpenCode skill directories, and requiring login setup for supported OpenCode free models (verified to run anonymously).
- Source: [#65 perf(codex): lean out MCP servers for command-line use](https://github.com/gordonpn/dotfiles/pull/65), [#56 feat(delegation): create minimal MCP profile for one-shot agents](https://github.com/gordonpn/dotfiles/pull/56), [#59 fix(sync): eliminate duplicate OpenCode skill discovery warnings in mcp-sync](https://github.com/gordonpn/dotfiles/pull/59), [#58 docs(delegation): document OpenCode free model authentication requirements](https://github.com/gordonpn/dotfiles/pull/58), [#41 investigation: determine whether an MCP control plane is worth building](https://github.com/gordonpn/dotfiles/issues/41)

## 2026-11-08: Multi-tier agent delegation fallback chain and inline agy rendering

- Decision: Route delegated coding tasks through a four-tier fallback chain (`agy-cli -> codex -> opencode -> github copilot student`) with automatic free-model fallback cycling for OpenCode in isolated worktrees, and configure Antigravity CLI with `altScreenMode: "never"` and `verbosity: "high"`.
- Rationale: Keep Antigravity focused on supervision and integration while preventing single-provider quota or rate limits from stalling delegated tasks, and keep conversation output inline in terminal scrollback.
- Rejected alternatives: Restricting delegation to interactive Antigravity execution or blocking Copilot CLI usage under delegation.
- Source: [#18 feat(delegate): support GitHub Copilot delegation for Codex and Antigravity CLI](https://github.com/gordonpn/dotfiles/pull/18), [#14 feat(delegation): add automatic free model fallback cycling for opencode](https://github.com/gordonpn/dotfiles/pull/14), [#54 feat(gemini): configure antigravity cli rendering and verbosity preferences](https://github.com/gordonpn/dotfiles/pull/54), [#11 feat(delegation): establish delegation-first policy for opencode under antigravity](https://github.com/gordonpn/dotfiles/pull/11)

## 2026-10-29: Consolidate shared memory on ai-memory and prune redundant context plugins

- Decision: Standardize cross-agent memory and wiki persistence on `ai-memory` across Antigravity CLI, Codex, and OpenCode, remove Context Mode and Claude-Mem integrations, and disable overlapping `memory`, `chrome-devtools`, and `server-services-configs` MCP entries in `mcp_config.template.json` in favor of `ai-memory`, `playwright`, and `filesystem`.
- Rationale: Remove duplicate MCP servers and conflicting memory/context-capture plugins while preserving existing stored data.
- Rejected alternatives: Retaining legacy `@modelcontextprotocol/server-memory`, Context Mode, Claude-Mem, or overlapping browser/filesystem servers.
- Source: [#10 feat(mcp): add ai-memory and consolidate mcp servers](https://github.com/gordonpn/dotfiles/pull/10), [#9 chore(agents): remove context capture plugins](https://github.com/gordonpn/dotfiles/pull/9)

## 2026-11-02: Exclude standard path tools from Carapace completions

- Decision: Add standard file and path tools (`basename`, `chmod`, `chown`, `dirname`, `du`, `file`, `readlink`, `realpath`, `stat`, `wc`) to `CARAPACE_EXCLUDES` in `dotfiles/.zshrc_new` alongside existing exclusions, and pass `-e CARAPACE_EXCLUDES -e CARAPACE_MATCH` to `_zcache_source`.
- Rationale: Prevent Carapace's generic completers from intercepting standard path tool completions and double-escaping paths containing spaces under `fzf-tab`, while ensuring edits to `CARAPACE_EXCLUDES` invalidate the cached Carapace init script.
- Rejected alternatives: Relying on Carapace's built-in completers for standard file utilities or manually clearing the zsh completion cache after every `CARAPACE_EXCLUDES` edit.
- Source: [#13 fix(zsh): exclude standard path tools from carapace completions](https://github.com/gordonpn/dotfiles/pull/13)

## 2026-10-29: Enforce mandatory task-branch pull request delivery

- Decision: Require every repository change (code, tests, configuration, documentation, scripts, and agent rules) to be committed on a dedicated task branch and delivered through a pull request targeting the default branch, never committing directly to or fast-forwarding `main` or `master`.
- Rationale: Maintain reviewable, isolated history across repositories and prevent unreviewed changes from landing directly on shared default branches.
- Rejected alternatives: Committing or fast-forwarding changes directly onto `main` or `master`.
- Source: [#12 docs(rules): enforce mandatory pull request delivery for all changes](https://github.com/gordonpn/dotfiles/pull/12)

## 2026-10-27: Use Ghostty 1.4 copy-on-select=both

- Decision: Set `copy-on-select = both` in the Ghostty configuration for Ghostty 1.4.0 instead of legacy values.
- Rationale: Align terminal selection-to-clipboard behavior with Ghostty 1.4.0 on macOS and Linux.
- Rejected alternatives: Retaining the pre-1.4 `copy-on-select` setting that no longer matched Ghostty 1.4.0 behavior.
- Source: [#8 fix(ghostty): use Ghostty 1.4 copy-on-select value](https://github.com/gordonpn/dotfiles/pull/8)
