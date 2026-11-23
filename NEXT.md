# Next Up

**Canonical Source:** [GitHub Issues](https://github.com/gordonpn/dotfiles/issues)
**Last Refined:** 2026-11-16T01:52:00Z
**Verified Default Branch:** `origin/master` (`0010232`)

## NOW

- **#99: test(agents): verify engineering-standards compliance challenge and post-merge unified symlink cutover** -> https://github.com/gordonpn/dotfiles/issues/99
  - **Priority:** P2
  - **Effort:** S
  - **Readiness:** IN PROGRESS
  - **Why NOW:** Live cutover on `master` already confirmed unified symlinks and exposed an active OpenCode/`~/.claude/skills/` duplicate-skill warning regression (`opencode debug skill --print-logs --log-level WARN`). Resolving it plus running the synthetic `engineering-standards` compliance check finishes an already started task with no external blockers.
  - **First Concrete Action:** Inspect how `bin/mcp-sync` populates `~/.claude/skills/` and why OpenCode emits `duplicate skill name` warnings on live workstations despite `tests/mcp-sync.sh` passing.
  - **Definition of Done:**
    - `bin/mcp-sync` eliminates live `opencode debug skill --print-logs --log-level WARN` duplicate-skill warnings while preserving Claude Code, Copilot, Codex, Antigravity, and OpenCode parity and green `just lint` / `just test`.
    - At least two harnesses pass the synthetic `engineering-standards` compliance challenge (including OpenCode-backed `scripts/deepseek-analyze.sh`).
    - `docs/decisions.md` entry for `2026-11-15` links PR `#97` instead of `PR pending`.
  - **Unblocks:** Reliable skill parity baseline across all harnesses.

## NEXT

1. **#102: chore(mcp): remove deprecated and broken legacy MCP entries from template and sync** (`priority:p2`, `effort:xs`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/102
   - Safe, isolated `XS` cleanup removing retired `server-services-configs`, `chrome-devtools`, `puppeteer`, and `memory` template entries and marking `caddy`, `vault`, and `discord` `disabled: true` while keeping `filesystem` (`${HOME}`) and `exa` (`agy`-lazy).
2. **#101: feat(skills): add CLI-backed skills for semgrep, repomix, and local DB inspection** (`priority:p2`, `effort:s`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/101
   - Packages `semgrep`, `repomix`, and local DB CLI workflows as Agent Skills; directly **unblocks `#100`** so minimal-profile reduction preserves capability parity.
3. **#100: perf(mcp-sync): optimize minimal MCP profile using audit schema token measurements** (`priority:p2`, `effort:s`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/100
   - **Depends on `#101` (`semgrep`/`repomix` skill parity); coordinates with `#104` (`brave-search` package migration).** Reduces default eager minimal profile from 9 servers (`~54k` tokens) to 6 servers (`~24.7k` tokens interactively; `~7.9k` in `delegate.sh`), keeping `brave-search` in `core`.
4. **#93: test(delegate): add live runtime verification for 64k OpenCode non-compaction and Copilot CLI MCP isolation** (`priority:p2`, `effort:xs`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/93
   - Independent of `#100-#102`; can run in parallel to verify live 64k non-compaction and Copilot CLI MCP flag isolation.
5. **#86: investigation: verify DeepSeek harness MCP compatibility and minimal profile** (`priority:p2`, `effort:s`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/86
   - Can run in parallel with `#93` or follow `#100`; verifies whether any standalone DeepSeek CLI exists beyond OpenCode-backed `scripts/deepseek-analyze.sh`.

## BLOCKERS

None currently blocking execution (PR `docs/mcp-audit-decisions` open for review to persist settled `#100`-`#104` decisions).

## LATER

See [all open GitHub Issues](https://github.com/gordonpn/dotfiles/issues) for `READY` P3 maintenance and migration items (`#67`, `#94`, `#95`, `#98`, `#103`, `#104`), and `DEFERRED` / exploratory items (`#27`, `#39`, `#60`, `#61`, `#66`, `#71-#81`, `#89`).
