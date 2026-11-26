---
trigger: always_on
description: Codex-first delegation trigger for Antigravity CLI; delegates routing details to delegate-coding-agents.
---

# Auto-Delegation

Delegate coding, debugging, planning, architecture, refactoring, reviews, and research by default unless the user requests Antigravity or `invoke_subagent`. Never send confidential or restricted code externally without permission.

- **Read-only and continuity:** If `$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs` exists, run `node "$RUNNER" task|review|adversarial-review` (`--resume-last` on follow-ups); otherwise (or after Codex quota/rate limits) run `delegate.sh --mode plan` (`--agent opencode` after a plugin failure) with any uncommitted diff and untracked files included.
- **Isolated builds:** Run `$HOME/.gemini/config/skills/delegate-coding-agents/scripts/delegate.sh --orchestrator agy --agent codex --mode build` for worktree-isolated edits, passing request, context, constraints, and decisions.
- **Skill reference:** Read `~/.gemini/config/skills/delegate-coding-agents/SKILL.md` for exact flags, fallback chain (Codex -> OpenCode free models -> Copilot Student -> native `invoke_subagent`), auth hard stops, `agents.delegationAllowed` opt-out rules, and dirty-base reconciliation.
- **Ownership and delivery:** Delegated workers never push or open PRs; Antigravity owns verification, cherry-picking, the `ocr` review gate, and PR delivery.
