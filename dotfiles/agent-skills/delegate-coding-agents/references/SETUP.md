# Install and configure automatic delegation

The dotfiles repository is the source of truth for this skill and the
Antigravity auto-delegation rule. Run `bin/mcp-sync` from the repository root to
link them into `~/.agents/skills/` and
`~/.gemini/antigravity-cli/rules/`, then mirror the shared skill into Codex,
OpenCode, and Antigravity's skill discovery directory. Existing conflicting
local copies are backed up by the sync script. A stale managed symlink to the
removed Copilot Student OpenCode plugin is pruned without deleting user-created
plugins.

Codex and Antigravity CLI use first-party GitHub Copilot CLI with `--model auto`
first, then fall back on classified provider, quota, rate-limit,
model-availability, or capacity failures to OpenCode zero-cost models:
`opencode/deepseek-v4.1-flash-free` (high variant),
`opencode/glm-5.3-flash-free`, `opencode/minimax-m3.1-flash-free`, then
`opencode/qwen3.6-plus-free`. Copilot Student access supports automatic model
selection only and excludes third-party agents, so do not route it through
OpenCode or pin Copilot model IDs. Authentication and provider-initialization
errors are hard stops with a login/credential-configuration hint. Codex may use
Gemini CLI only after every OpenCode candidate fails with a classified provider,
quota, rate-limit, model-availability, or capacity error. Install and authenticate
Copilot CLI with `copilot login`
and Gemini CLI separately. Codex does not invoke Antigravity CLI under a
consumer plan.

Automatic delegation requires explicit opt-in in each eligible repository:

```bash
git config --local agents.delegationAllowed true
```

Restart active Codex and agy sessions to load the updated skill and rule.
Configure narrow build/test command permissions separately; never blindly
enable global shell-approval bypass.

## Notes

- Codex and Antigravity use Copilot CLI Auto first, then the sequential OpenCode zero-cost fallback; only Codex can continue to Gemini after classified OpenCode service failures.
- Automatic repo opt-in avoids accidentally sending confidential employer sources to an external hosted model.
- If no repo opt-in exists, the agent should complete tasks itself or explain that delegation is blocked.
- Both delegations operate on a clean committed checkout; current uncommitted edits cannot be safely inherited.
- To run a delegate manually without the opt-in gate, omit `--automatic`, but still ensure the repository is appropriate for external inference.
- Plans stay in an isolated detached worktree, builds on new `delegate/...` branches; review and integrate only verified changes.
