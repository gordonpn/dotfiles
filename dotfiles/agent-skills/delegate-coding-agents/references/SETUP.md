# Install and configure automatic delegation

The dotfiles repository is the source of truth for this skill, the OpenCode
GitHub Copilot Student plugin (`dotfiles/opencode/plugins/copilot-student-models.ts`),
and the Antigravity auto-delegation rule. Run `bin/mcp-sync` from the
repository root to link them into `~/.agents/skills/`,
`~/.config/opencode/plugins/`, and `~/.gemini/antigravity-cli/rules/`, then
mirror the shared skill into Codex, OpenCode, and Antigravity's skill discovery
directory. Existing conflicting local copies are backed up by the sync script.

Codex and Antigravity CLI delegate to OpenCode free models (`opencode/deepseek-v4.1-flash-free`,
`opencode/glm-5.3-flash-free`, `opencode/minimax-m3.1-flash-free`, `opencode/qwen3.6-plus-free`)
and 0x-included GitHub Copilot models via OpenCode (`github-copilot/gpt-4.1`,
`github-copilot/gpt-4o`, `github-copilot/gpt-4o-mini`), or directly via `--agent copilot`.
Codex additionally falls back to Gemini CLI if all OpenCode and Copilot free
routes are quota-limited. Authentication and provider-initialization errors
stop delegation with a message to check login and credentials/configuration.
Codex does not delegate to Antigravity CLI under a consumer plan. OpenCode must
be authenticated with GitHub Copilot (`opencode auth login`) for Copilot models,
and Gemini CLI must be installed and authenticated before the Gemini fallback
can run.

Automatic delegation requires explicit opt-in in each eligible repository:

```bash
git config --local agents.delegationAllowed true
```

Restart active Codex and agy sessions to load the updated skill and rule.
Configure narrow build/test command permissions separately; never blindly
enable global shell-approval bypass.

## Notes

- Parent Codex uses the sequential OpenCode/Copilot-to-Gemini fallback; parent agy delegates to OpenCode and GitHub Copilot (via OpenCode).
- Automatic repo opt-in avoids accidentally sending confidential employer sources to an external hosted model.
- If no repo opt-in exists, the agent should complete tasks itself or explain that delegation is blocked.
- Both delegations operate on a clean committed checkout; current uncommitted edits cannot be safely inherited.
- To run a delegate manually without the opt-in gate, omit `--automatic`, but still ensure the repository is appropriate for external inference.
- Plans stay in an isolated detached worktree, builds on new `delegate/...` branches; review and integrate only verified changes.
