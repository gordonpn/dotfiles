---
name: task-handoff
description: Maintain and recover local untracked .agent/HANDOFF.md checkpoints across coding agents during multi-step tasks. Use when pausing unfinished work, handing off across agents or sessions, or resuming a multi-step task in an existing branch or worktree.
---

# Cross-Agent Task Continuity and Handoff

These rules apply across coding agents, including Antigravity CLI and Codex CLI, to keep multi-step implementations recoverable without polluting repository history.

## Task State Rules

- **One Checkpoint:** For multi-step implementations, maintain `.agent/HANDOFF.md` in the relevant worktree unless the project already defines a handoff location. Reuse that location rather than creating a competing record. Trivial, single-step edits need no handoff document.
- **Local Only:** Keep `.agent/HANDOFF.md` local and untracked. Never stage, commit, or force-add it.
- **Update Timing:** Update the checkpoint at meaningful milestones and before ending an unfinished session or transferring the task. Keep it concise, factual, and current, not a transcript or growing activity log.
- **Required Context:** Record:
  - Objective and acceptance criteria
  - Branch and latest commit
  - Completed work and modified files, including uncommitted changes
  - Significant decisions and rationale
  - Exact verification commands and outcomes
  - Outstanding failures, blockers, remaining tasks, and the single next recommended action
- **Evidence and Limits:** Distinguish verified results from inherited claims, hypotheses, and checks not run. Identify the revision or working-tree state tested and relevant environment constraints. Never include secrets or sensitive log contents.
- **Lifecycle:** Treat the handoff as a temporary task checkpoint, an exception to the durable-documentation location rule. Link to existing requirements and ADRs rather than duplicating them. On completion, mark it complete and preserve any durable knowledge in the appropriate project documentation.

## Session Recovery

1. Read repository instructions and `.agent/HANDOFF.md` (or the project-defined handoff), if present.
2. Inspect the current branch, recent commits, working-tree status, and staged and unstaged diffs.
3. Reconcile the checkpoint with source code and available verification evidence. Re-run relevant checks when evidence is missing or subsequent changes invalidate it; never treat another agent's claims as proof of success.
4. Continue from the latest verified state, preserving existing work. Do not reset, discard, or overwrite unfamiliar changes to match the handoff; resolve discrepancies first.
5. Correct stale checkpoint entries. If no handoff exists, reconstruct the necessary context from the repository and user request before proceeding.
