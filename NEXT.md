# Next Up

**Canonical Source:** [GitHub Issues](https://github.com/gordonpn/dotfiles/issues)
**Last Refined:** 2026-11-23T17:00:00Z
**Default Branch Snapshot (as of refinement):** `origin/master` (`47514d3`)

## NOW

- **#126: fix(delegate): advance fallback chain when primary candidate executable is missing** -> https://github.com/gordonpn/dotfiles/issues/126
  - **Priority:** P2
  - **Effort:** XS
  - **Readiness:** READY
  - **Dependencies:** None
  - **Why NOW:** Small, self-contained `XS` bug fix in `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh` identified during PR #123 review: when `codex` is absent from `PATH`, `delegate.sh` currently exits before entering the fallback loop even when valid OpenCode free models or GitHub Copilot CLI fallbacks are installed.
  - **First Concrete Action:** Update the pre-loop executable availability check in `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh` so missing primary candidates advance to the next configured fallback candidate while still failing fast when zero candidates in the chain are installed.
  - **Definition of Done:**
    - `delegate.sh --orchestrator agy --agent codex` advances to OpenCode/Copilot when `codex` is absent from `PATH` and at least one fallback executable is present.
    - Running with no available candidate executables still exits non-zero with an actionable installation message.
    - `bash dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh`, `just lint`, and `just test` pass cleanly.
  - **Unblocks:** Resilient multi-agent fallback on hosts where only a subset of agent CLIs is installed.

## NEXT

1. **#133: test(mcp): verify reduced-profile runtime and cross-client skill parity** (`priority:p2`, `effort:s`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/133
   - **Dependencies:** Follows merged PR #130 (`bf7be1c`, which implemented the 6-server `DEFAULT_CORE_SERVERS` profile and `semgrep`, `repomix`, and `local-db-cli` skills for `#100` and `#101`); coordinates with `#93`.
   - **Rationale:** Verifies live client startup tool/schema counts and skill discovery across harnesses so `#100` and `#101` can be closed with runtime evidence.
2. **#119: feat(delegate): add mechanical per-repo and remote opt-out guard for external delegation** (`priority:p2`, `effort:xs`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/119
   - **Dependencies:** None (can follow `#126` in `delegate.sh`).
   - **Rationale:** Adds an explicit per-repository or remote opt-out mechanism in `delegate.sh` for confidential repositories while keeping delegation frictionless by default on personal repos.
3. **#93: test(delegate): add live runtime verification for 64k OpenCode non-compaction and Copilot CLI MCP isolation** (`priority:p2`, `effort:xs`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/93
   - **Dependencies:** Coordinates with `#133`.
   - **Rationale:** Validates live 64k non-compaction and Copilot CLI MCP flag isolation outside mocked unit tests.
4. **#86: investigation: verify DeepSeek harness MCP compatibility and minimal profile** (`priority:p2`, `effort:s`, `READY`) -> https://github.com/gordonpn/dotfiles/issues/86
   - **Dependencies:** Can run in parallel with `#93` and `#133`.
   - **Rationale:** Confirms whether any standalone DeepSeek CLI integration is needed beyond OpenCode-backed `scripts/deepseek-analyze.sh`.

## BLOCKERS

None currently blocking execution (prior milestone issues `#17`, `#19`, `#23`, `#31`, `#99`, and `#102` are closed; `#100` and `#101` implementation landed in PR #130 at `bf7be1c` with live runtime verification tracked in `#133`).

## LATER

See [all open GitHub Issues](https://github.com/gordonpn/dotfiles/issues) for `READY` P3 maintenance, test, and migration items (`#67`, `#94`, `#95`, `#98`, `#103`, `#104`, `#111`, `#112`, `#113`, `#118`, `#121`, `#125`, `#128`, `#129`, `#131`, `#132`), and `DEFERRED` / exploratory items (`#27`, `#39`, `#60`, `#61`, `#66`, `#71-#81`, `#89`).
