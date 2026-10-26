# Install and configure automatic delegation

The dotfiles repository is the source of truth for this skill and the
Antigravity auto-delegation rule. Run `bin/mcp-sync` from the repository root
to link them into `~/.agents/skills/` and
`~/.gemini/antigravity-cli/rules/`, then mirror the shared skill into Codex,
OpenCode, and Antigravity's skill discovery directory. Existing conflicting
local copies are backed up by the sync script.

Codex delegates sequentially to OpenCode DeepSeek Flash Free, OpenCode GLM
Flash Free only after an explicit quota/rate-limit failure, then Gemini CLI if
both OpenCode free routes are limited. Codex does not delegate to Antigravity
CLI or Copilot CLI. Gemini CLI must be installed and authenticated before that
fallback can run.

Automatic delegation requires explicit opt-in in each eligible repository:

```bash
git config --local agents.delegationAllowed true
```

Restart active Codex and agy sessions to load the updated skill and rule.
Configure narrow build/test command permissions separately; never blindly
enable global shell-approval bypass.

## Notes

- Parent Codex uses the sequential OpenCode-to-Gemini fallback; parent agy delegates only to OpenCode.
- Automatic repo opt-in avoids accidentally sending confidential employer sources to an external hosted model.
- If no repo opt-in exists, the agent should complete tasks itself or explain that delegation is blocked.
- Both delegations operate on a clean committed checkout; current uncommitted edits cannot be safely inherited.
- To run a delegate manually without the opt-in gate, omit `--automatic`, but still ensure the repository is appropriate for external inference.
- Plans stay in an isolated detached worktree, builds on new `delegate/...` branches; review and integrate only verified changes.
