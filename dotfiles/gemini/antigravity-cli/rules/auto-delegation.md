---
trigger: always_on
description: Automatically delegate suitable engineering subtasks to OpenCode under Antigravity CLI supervision.
---

# Automatic OpenCode delegation when Antigravity is the orchestrator

When directly asked to solve an engineering task, Antigravity owns planning, implementation, integration, verification, and the final answer. Proactively consider the installed `delegate-coding-agents` skill for bounded planning or implementation by OpenCode; no special user phrase is required.

## Routing

- Use OpenCode plan for repository exploration, test strategy, design alternatives, or independent analysis.
- Use OpenCode build for mechanical refactors, test generation, boilerplate, documentation, and separable low-to-medium risk implementation.
- Keep architecture decisions, cross-cutting risky changes, security-sensitive code, complex concurrency fixes, final review, and integration with Antigravity.
- Delegate only when the repository has local Git config `agents.delegationAllowed=true`. Otherwise work directly. Never bypass this gate for confidential or employer code.
- Usually delegate zero or one task per phase. Parallelize only independent scopes with disjoint files. Skip trivial tasks where the handoff costs more than it saves.

## Execution

- Read `~/.gemini/config/skills/delegate-coding-agents/SKILL.md` and invoke its `scripts/delegate.sh` with `--orchestrator agy --agent opencode --mode plan|build --automatic`, a meaningful `--id`, and a bounded `--task` or `--task-file`.
- Never delegate to agy itself or call Codex in a circular chain. A delegated worker must not delegate to any agent.
- Use isolated worktrees. Do not stash, reset, or discard a dirty checkout to satisfy the snapshot requirement.
- Give the worker precise scope, acceptance criteria, test commands, prohibited file areas, and required evidence.
- Inspect reports, logs, tracked diffs, and untracked files; independently verify results and integrate only intended changes. Exit status zero alone does not establish correctness.
- Do not silently switch to paid models or bypass tool approvals if OpenCode fails or is rate-limited.
- Preserve the configured Alibaba Open Code Review gate. Never auto-push or create a PR unless asked.
