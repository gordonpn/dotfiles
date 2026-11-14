# Implementation Decisions Log

This document records non-obvious engineering and implementation decisions made in Dotfiles, ordered newest first.

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

## 2026-10-29: Mandatory task-branch PR delivery and Ghostty 1.4 copy-on-select

- Decision: Require every repository change to land via a pull request from a dedicated task branch (never committing directly to default branches), set Ghostty `copy-on-select = both` for Ghostty 1.4.0, and exclude standard PATH tools from Carapace completions where native completions cause issues.
- Rationale: Maintain reviewable, isolated history across repositories and align terminal selection behavior with Ghostty 1.4.0 behavior on macOS and Linux.
- Rejected alternatives: Committing or fast-forwarding changes directly onto `main` or `master`.
- Source: [#12 docs(rules): enforce mandatory pull request delivery for all changes](https://github.com/gordonpn/dotfiles/pull/12), [#8 fix(ghostty): use Ghostty 1.4 copy-on-select value](https://github.com/gordonpn/dotfiles/pull/8), [#13 fix(zsh): exclude standard path tools from carapace completions](https://github.com/gordonpn/dotfiles/pull/13)
