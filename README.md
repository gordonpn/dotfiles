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

## Getting started

Codex CLI copies transcript selections on mouse release with
`tui.copy_on_select = "always"`. Restart the CLI after changing this setting.

### Installing and usage

- Clone the repository
- cd into the repository
- Run `./setup.sh`

## License

[MIT License](./LICENSE)
