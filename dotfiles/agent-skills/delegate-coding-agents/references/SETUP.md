# Install and configure automatic delegation

The dotfiles repository is the source of truth for this skill and the
Antigravity auto-delegation rule. Run `bin/mcp-sync` from the repository root
to link them into `~/.agents/skills/` and
`~/.gemini/antigravity-cli/rules/`, then mirror the shared skill into Codex,
OpenCode, and Antigravity's skill discovery directory. Existing conflicting
local copies are backed up by the sync script.

Antigravity CLI acts as the main harness, routing through
`agy-cli -> codex -> opencode -> github copilot student`. It tries Codex CLI
first, then falls back across OpenCode free models (DeepSeek Flash Free high,
GLM-5.3 Flash Free, MiMo-V2.6 Flash Free, Nemotron-3.5 Lightning Free), then to
GitHub Copilot Student (`--model auto`).

Codex as parent orchestrator delegates sequentially across OpenCode free
models and GitHub Copilot Student (`--model auto`). Authentication
and provider-initialization errors stop delegation with a message to check
login and credentials/configuration (`codex login`, `copilot login`, or OpenCode
provider configuration). Codex does not delegate to Antigravity CLI under a
consumer plan.

Automatic delegation requires explicit opt-in in each eligible repository:

```bash
git config --local agents.delegationAllowed true
```

Restart active Codex and agy sessions to load the updated skill and rule.
Configure narrow build/test command permissions separately; never blindly
enable global shell-approval bypass.

## Notes

- Parent agy delegates sequentially across Codex, OpenCode, and GitHub Copilot Student (`--model auto`).
- Parent Codex delegates sequentially across OpenCode and GitHub Copilot Student (`--model auto`).
- Automatic repo opt-in avoids accidentally sending confidential employer sources to an external hosted model.
- If no repo opt-in exists, the agent should complete tasks itself or explain that delegation is blocked.
- Both delegations operate on a clean committed checkout; current uncommitted edits cannot be safely inherited.
- To run a delegate manually without the opt-in gate, omit `--automatic`, but still ensure the repository is appropriate for external inference.
- Plans stay in an isolated detached worktree, builds on new `delegate/...` branches; review and integrate only verified changes.
