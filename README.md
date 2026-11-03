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

In gh-dash's PR view, press `S` to confirm squash-merging the selected pull
request and deleting its branch through Gum (`brew install gum`, included in
`lists/Brewfile`). Only confirmation runs `gh pr merge --squash --delete-branch`.
Press `W` to confirm marking the selected pull request ready for review through
Gum. Only confirmation runs `gh pr ready` for that PR and repository.

gh-dash notifications include New Comments, Review Requests, CI Activity,
My PR Activity, and Mentions, refreshing every five minutes. My PR Activity
also includes issues you opened because it uses `reason:author`.

Codex and Antigravity CLI delegate eligible work sequentially to OpenCode free
models (`opencode/deepseek-v4.1-flash-free`, `opencode/glm-5.3-flash-free`,
`opencode/minimax-m3.1-flash-free`, `opencode/qwen3.6-plus-free`) and 0x-included
GitHub Copilot models via OpenCode (`github-copilot/gpt-4.1`,
`github-copilot/gpt-4o`, `github-copilot/gpt-4o-mini`), or directly via
`--agent copilot`. Codex additionally falls back to Gemini CLI if all OpenCode
and Copilot free routes are limited. It stops after a successful worker;
Antigravity CLI as a Codex worker is not used. Automatic delegation requires the
repository-local opt-in `agents.delegationAllowed=true`.
See [the shared delegation skill](dotfiles/agent-skills/delegate-coding-agents/SKILL.md).

### Installing and usage

- Clone the repository
- cd into the repository
- Run `./setup.sh`

## License

[MIT License](./LICENSE)
