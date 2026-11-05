# Project Execution Queue

- **Last Refined:** 2026-11-05 00:30 UTC-5
- **Repository:** [gordonpn/dotfiles](https://github.com/gordonpn/dotfiles)
- **GitHub Backlog:** [gordonpn/dotfiles Issues](https://github.com/gordonpn/dotfiles/issues)

## NOW - Recommended Next Task

### [#23: perf(delegate): isolate delegated OpenCode workers with minimal MCP configuration](https://github.com/gordonpn/dotfiles/issues/23)

- **Priority:** P1
- **Effort:** S
- **Readiness:** READY
- **Why now:** Directly resolves the 5 to 8 second cold-start latency and infinite context compaction loops experienced by delegated subagents on 64k-prompt models during `delegate.sh` runs. Local repository tasks do not require the 33 external homelab MCP servers.
- **First action:** In `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh`, supply a clean configuration override (or an empty `mcpServers: {}` configuration) when invoking `opencode run` for delegated workers.
- **Definition of Done:**
  - `delegate.sh --agent opencode --mode plan --task "..."` launches with an isolated MCP configuration that does not spawn external homelab MCP servers.
  - Delegated OpenCode tasks complete without context compaction loops on 64k models.
  - `bash dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh` and `just test` pass cleanly.
- **Unblocks:** Reduces token and process load ahead of broader client-tiering in #19.

## NEXT - Upcoming Work

1. **[#31: fix(sync): eliminate duplicate OpenCode skill discovery warnings in mcp-sync](https://github.com/gordonpn/dotfiles/issues/31)**
   - **Priority:** P2
   - **Effort:** XS
   - **Readiness:** READY
   - **Dependencies:** None
   - **Rationale:** Quick win. OpenCode v1.19+ natively scans `~/.agents/skills`. Modifying `sync_skills_and_instructions` in `bin/mcp-sync` to avoid linking skills into `~/.config/opencode/skills` when they already exist in `~/.agents/skills` eliminates noisy startup warnings.

2. **[#19: feat(mcp-sync): implement client-specific MCP enablement tiers in mcp-sync](https://github.com/gordonpn/dotfiles/issues/19)**
   - **Priority:** P1
   - **Effort:** M
   - **Readiness:** READY
   - **Dependencies:** None (can follow #23)
   - **Rationale:** Solves the root eager-loading tool bloat across interactive OpenCode and Codex sessions. Keeps all 37 servers from `dotfiles/gemini/mcp_config.template.json` enabled for Antigravity CLI (which lazy-loads tools from disk), while defaulting OpenCode and Codex to core daily-driver servers (`context7`, `codebase-memory-mcp`, `ai-memory`, `github`), staying well below the 128-tool limit.

3. **[#17: perf(mcp): reduce 547 eager MCP tool schemas across 37 configured servers in OpenCode and Codex](https://github.com/gordonpn/dotfiles/issues/17)**
   - **Priority:** P1
   - **Effort:** M
   - **Readiness:** IN PROGRESS
   - **Dependencies:** Tracks completion of #23, #31, and #19.
   - **Rationale:** Parent Epic/Story tracking overall reduction of the 547 eager MCP schemas.

## BLOCKERS

None. Issues #31 and #19 are unblocked and ready for immediate implementation; #17 is in progress and tracks completion of #23, #31, and #19.

## LATER

Lower-priority deferred tasks are tracked directly in GitHub Issues:
- [#20: investigation: establish a cross-client MCP performance baseline](https://github.com/gordonpn/dotfiles/issues/20) (P3, Effort: S)
- [#21: investigation: verify Codex deferred MCP tool search compatibility](https://github.com/gordonpn/dotfiles/issues/21) (P3, Effort: XS)
- [#27: investigation: evaluate project-specific MCP profiles](https://github.com/gordonpn/dotfiles/issues/27) (P3, Effort: S)
