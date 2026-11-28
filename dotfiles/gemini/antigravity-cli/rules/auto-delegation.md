---
trigger: always_on
description: Codex-first delegation trigger for Antigravity CLI; delegates routing details to delegate-coding-agents.
---

# Auto-Delegation

Delegate coding, debugging, planning, architecture, refactoring, reviews, and research by default unless the user requests Antigravity or `invoke_subagent`. Never send confidential or restricted code externally without permission.

- **Repository opt-out:** Before using the Codex plugin or `delegate.sh` in a Git repository, check the effective `agents.delegationAllowed` setting. Follow the wrapper's policy: an unset or true value permits delegation subject to user and data-handling constraints. For false, empty or invalid values, or config read errors, stay in Antigravity or use native `invoke_subagent`.
- **Read-only and continuity:** Set `RUNNER="$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs"`. If the file exists, run `node "$RUNNER"` with `task`, `review`, or `adversarial-review` (`--resume-last` on follow-ups where supported). Otherwise use `delegate.sh --orchestrator agy --agent codex --mode plan`; use `--agent opencode` instead only after a plugin failure eligible for fallback under the skill. The wrapper snapshots committed `HEAD`; include relevant uncommitted or untracked content in `--task`/`--task-file` only if it can be shared, or review the active checkout directly.
- **Isolated builds:** Run `$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh --orchestrator agy --agent codex --mode build` for worktree-isolated edits, passing request, context, constraints, and decisions.
- **Skill reference:** Read `~/.gemini/config/skills/delegate-coding-agents/SKILL.md` for exact flags, fallback chain (Codex -> OpenCode free models -> Copilot Student -> native `invoke_subagent`), auth hard stops, `agents.delegationAllowed` opt-out rules, and dirty-base reconciliation.
- **Ownership and delivery:** Delegated workers never push or open PRs. Antigravity owns verification, cherry-picking, the `ocr` review gate, and PR delivery when the user authorizes pushing or opening a PR.
