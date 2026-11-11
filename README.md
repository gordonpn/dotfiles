# dotfiles

## Description

The purpose of this repo is to hold my dotfiles and macOS/Ubuntu configurations.

With scripts that will help me set up a Mac on a fresh install.

---

![Last commit on develop](https://badgen.net/github/last-commit/gordonpn/dotfiles)
![License](https://badgen.net/github/license/gordonpn/dotfiles)

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/gordonpn)

## Features

- Installs Homebrew
- Installs brew taps
- Installs brew packages
- Installs brew casks
- Installs Mac App Store apps
- Symlinks dotfiles
- Creates workspace directories
- Makes zsh the default shell
- Installs zsh plugins
- Set macOS Preferences defaults

On macOS, login shells set the soft open-file limit to 4096 so coding agents can
load skills and MCP servers without exhausting file descriptors. Open a new
login shell and run `ulimit -Sn` to verify; existing background processes must be
restarted to inherit the limit. Linux resource limits are unchanged.

Antigravity CLI, OpenCode, and Codex share a local codebase knowledge graph MCP
server. Run `just setup-codebase-memory` to install and configure it. See
[MCP setup](docs/mcp-setup.md#codebase-memory-mcp) for usage and diagnostics.

Codex and Antigravity CLI use ECC for reusable engineering workflows. Run
`just setup-ecc` to install the pinned Codex plugin and Antigravity's
project-local minimal profile. See [MCP setup](docs/mcp-setup.md#ecc) for details.

## Getting started

Codex CLI copies transcript selections on mouse release with
`tui.copy_on_select = "always"`. Restart the CLI after changing this setting.

Codex's `project_doc_max_bytes = 65536` allows up to 64 KiB of combined global
and repository instructions, accommodating the shared cross-agent handoff policy.

Antigravity CLI (`agy`) runs inline without alternate screen switching
(`altScreenMode = "never"`), copies transcript selections on mouse release
(`copyOnSelect = true`), displays full tool calls and thoughts
(`verbosity = "high"`), shows active background tasks and subagents
(`hideActiveItems = false`), and animates progress lights at slow speed
(`runningLightSpeed = "slow"`). These preferences are tracked in
`dotfiles/gemini/antigravity-cli/settings.json` and symlinked to
`~/.gemini/antigravity-cli/settings.json`.

In gh-dash's PR view, press `S` to confirm squash-merging the selected pull
request and deleting its branch through Gum (`brew install gum`, included in
`lists/Brewfile`). Only confirmation runs `gh pr merge --squash --delete-branch`.
Press `W` to confirm marking the selected pull request ready for review through
Gum. Only confirmation runs `gh pr ready` for that PR and repository.

gh-dash notifications include New Comments, Review Requests, CI Activity,
My PR Activity, and Mentions, refreshing every five minutes. My PR Activity
also includes issues you opened because it uses `reason:author`.

Antigravity CLI acts as the main terminal coding harness and delegates
eligible work sequentially through `agy-cli -> codex -> opencode -> github copilot student`.
Codex CLI runs non-interactively in an isolated Git worktree; on classified
provider, quota, rate-limit, or model-availability failures, it falls back to
OpenCode zero-cost models (`opencode/deepseek-v4.1-flash-free` with high
variant, `opencode/glm-5.3-flash-free`, `opencode/mimo-v2.6-flash-free`, and
`opencode/nemotron-3.5-lightning-free`), then to first-party GitHub Copilot
CLI with `--model auto` under the Student plan. Codex as orchestrator delegates
sequentially across OpenCode and GitHub Copilot Student.
Authentication and provider-initialization errors are hard stops across all
candidates directing the user to log in (`codex login`, `copilot login`, or
check OpenCode credentials; supported OpenCode free models operate anonymously
without an account or login). Automatic delegation requires the repository-local
opt-in `agents.delegationAllowed=true`.
See [the shared delegation skill](dotfiles/agent-skills/delegate-coding-agents/SKILL.md).

### Installing and usage

- Clone the repository
- cd into the repository
- Run `./setup.sh`

## License

[MIT License](./LICENSE)
