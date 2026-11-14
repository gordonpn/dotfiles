#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$test_tmp_dir"' EXIT
export UV_CACHE_DIR="${UV_CACHE_DIR:-$HOME/.cache/uv}"
export HOME="${test_tmp_dir}/home"
export XDG_CONFIG_HOME="${test_tmp_dir}/xdg"
export TMPDIR="${test_tmp_dir}"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

grep -q '^install_codebase_memory_mcp()' "${repo_dir}/bin/mcp-sync"

# Source functions without running the host's provisioning workflow.
# shellcheck source=bin/mcp-sync
source "${repo_dir}/bin/mcp-sync"

calls="${test_tmp_dir}/calls"
fixture="${test_tmp_dir}/fixture"
mkdir -p "$fixture"
cp /usr/bin/true "${fixture}/codebase-memory-mcp"
tar -czf "${fixture}/archive.tar.gz" -C "$fixture" codebase-memory-mcp
fixture_digest="$(sha256_of "${fixture}/archive.tar.gz")"
for os in darwin linux; do
  for arch in arm64 amd64; do
    suffix=
    [[ "$os" != linux ]] || suffix=-portable
    printf '%s  codebase-memory-mcp-%s-%s%s.tar.gz\n' "$fixture_digest" "$os" "$arch" "$suffix" >>"${fixture}/checksums.txt"
  done
done

fake_os=Linux
fake_arch=x86_64
uname() {
  case "$1" in
    -s) echo "$fake_os" ;;
    -m) echo "$fake_arch" ;;
  esac
}
curl() {
  printf 'curl %s\n' "$*" >>"$calls"
  [[ "${download_fails:-0}" == 0 ]] || return 22
  if [[ "$5" == */checksums.txt ]]; then
    cp "${fixture}/checksums.txt" "$5"
    [[ "${checksum_invalid:-0}" == 0 ]] || printf 'bad digest\n' >"$5"
    return 0
  fi
  cp "${fixture}/archive.tar.gz" "$5"
}
install() {
  [[ "${installer_fails:-0}" == 0 ]] || return 1
  command install "$@"
}
codesign() { echo codesign >>"$calls"; }

install_dir="${HOME}/.local/share/codebase-memory-mcp"
stamp="${install_dir}/.version"

install_codebase_memory_mcp

[[ "$(cat "$stamp")" == 0.11.0 ]]
grep -F -- 'releases/download/v0.11.0/codebase-memory-mcp-linux-amd64-portable.tar.gz' "$calls"
grep -F -- 'releases/download/v0.11.0/checksums.txt' "$calls"
[[ "$(wc -l <"$calls")" -eq 2 ]]

install_codebase_memory_mcp

[[ "$(wc -l <"$calls")" -eq 2 ]]

printf 'old\n' >"$stamp"
installer_fails=1

if (install_codebase_memory_mcp); then
  echo 'Expected installer failure' >&2
  exit 1
fi

[[ "$(cat "$stamp")" == old ]]
installer_fails=0
download_fails=0
checksum_invalid=1

if (install_codebase_memory_mcp); then
  echo 'Expected checksum failure' >&2
  exit 1
fi

[[ "$(cat "$stamp")" == old ]]
checksum_invalid=0

for platform in Darwin:arm64 Darwin:x86_64 Linux:arm64 Linux:aarch64 Linux:amd64 Linux:x86_64; do
  fake_os="${platform%:*}"
  fake_arch="${platform#*:}"
  rm -f "$stamp"
  : >"$calls"

  install_codebase_memory_mcp

  [[ "$(cat "$stamp")" == 0.11.0 ]]
  if [[ "$fake_os" == Darwin ]]; then
    grep -qx codesign "$calls"
  elif grep -qx codesign "$calls"; then
    echo 'Linux must not invoke codesign' >&2
    exit 1
  fi
done
printf 'old\n' >"$stamp"
fake_os=unsupported

if (install_codebase_memory_mcp); then
  echo 'Expected unsupported OS failure' >&2
  exit 1
fi

fake_os=Linux
fake_arch=unsupported

if (install_codebase_memory_mcp); then
  echo 'Expected unsupported architecture failure' >&2
  exit 1
fi
installer_fails=0
fake_arch=x86_64
download_fails=1

if (install_codebase_memory_mcp); then
  echo 'Expected download failure' >&2
  exit 1
fi

[[ "$(cat "$stamp")" == old ]]

entry="$(jq -c '.mcpServers["codebase-memory-mcp"]' "${TEMPLATE_DIR}/mcp_config.template.json")"
expected="{\"command\":\"\${HOME}/.local/share/codebase-memory-mcp/codebase-memory-mcp\",\"args\":[]}"
[[ "$entry" == "$expected" ]]

ai_entry="$(jq -c '.mcpServers["ai-memory"]' "${TEMPLATE_DIR}/mcp_config.template.json")"
ai_expected="{\"command\":\"\${HOME}/.local/bin/ai-memory\",\"args\":[\"mcp-bridge\",\"--no-session-id\",\"--server-url\",\"http://127.0.0.1:49374/mcp\"]}"
[[ "$ai_entry" == "$ai_expected" ]]

[[ "$(jq -r '.mcpServers["chrome-devtools"].disabled' "${TEMPLATE_DIR}/mcp_config.template.json")" == "true" ]]
[[ "$(jq -r '.mcpServers["memory"].disabled' "${TEMPLATE_DIR}/mcp_config.template.json")" == "true" ]]
[[ "$(jq -r '.mcpServers["server-services-configs"].disabled' "${TEMPLATE_DIR}/mcp_config.template.json")" == "true" ]]

get_secret() { printf ''; }
gh() { return 1; }

unset CODEX_MCP_PROFILE CODEX_MCP_SERVERS OPENCODE_MCP_PROFILE OPENCODE_MCP_SERVERS
mkdir -p "${OPENCODE_DIR}"
cat >"${OPENCODE_DIR}/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/deepseek-v4.1-flash-free",
  "theme": "flexoki",
  "mcp": {
    "custom-local": {
      "type": "local",
      "command": ["echo", "custom"],
      "enabled": true
    }
  }
}
JSON
sync_mcp_config

# Verify OpenCode preserved top-level settings and custom unmanaged MCP entry
[[ "$(jq -r '.model' "${OPENCODE_DIR}/opencode.json")" == "opencode/deepseek-v4.1-flash-free" ]]
[[ "$(jq -r '.theme' "${OPENCODE_DIR}/opencode.json")" == "flexoki" ]]
[[ "$(jq -r '.mcp["custom-local"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["ai-memory"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["cclsp"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]
[[ "$(jq -r '.mcp["tailscale"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]
[[ "$(jq -r '.mcp["memory"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]
rm -f "${OPENCODE_DIR}/opencode.json"
sync_mcp_config
uv run --no-project --with mcp==1.1.2 python "${repo_dir}/tests/verify_mcp.py" --configs-only --require-minimal

[[ "$(jq -r '.mcpServers["ai-memory"].command' "${GEMINI_CONFIG_DIR}/mcp_config.json")" == "${HOME}/.local/bin/ai-memory" ]]
[[ "$(jq -r '.mcpServers["memory"].disabled' "${GEMINI_CONFIG_DIR}/mcp_config.json")" == "true" ]]
[[ "$(jq -r '.mcpServers["chrome-devtools"].disabled' "${GEMINI_CONFIG_DIR}/mcp_config.json")" == "true" ]]
[[ "$(jq -r '.mcpServers["server-services-configs"].disabled' "${GEMINI_CONFIG_DIR}/mcp_config.json")" == "true" ]]

grep -F '[mcp_servers."ai-memory"]' "${CODEX_DIR}/config.toml"
grep -A 4 -F '[mcp_servers."memory"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
grep -A 3 -F '[mcp_servers."chrome-devtools"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
grep -A 3 -F '[mcp_servers."server-services-configs"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'

# Minimal profile: non-core servers are disabled by default in Codex
grep -A 4 -F '[mcp_servers."tailscale"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
grep -A 4 -F '[mcp_servers."cloudflare"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
grep -A 4 -F '[mcp_servers."uptime-kuma"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'

# Minimal profile: core servers are enabled in Codex (no enabled = false)
if grep -A 4 -F '[mcp_servers."cclsp"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected cclsp to be enabled in minimal profile' >&2
  exit 1
fi
if grep -A 4 -F '[mcp_servers."git"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected git to be enabled in minimal profile' >&2
  exit 1
fi
if grep -A 4 -F '[mcp_servers."codebase-memory-mcp"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected codebase-memory-mcp to be enabled in minimal profile' >&2
  exit 1
fi
if grep -A 4 -F '[mcp_servers."ai-memory"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected ai-memory to be enabled in minimal profile' >&2
  exit 1
fi

# Codex MCP profile: Full profile enables non-core servers while preserving globally disabled servers
CODEX_MCP_PROFILE=full sync_mcp_config
grep -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml"
if grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected docker to be enabled in full profile' >&2
  exit 1
fi
grep -F '[mcp_servers."tailscale"]' "${CODEX_DIR}/config.toml"
if grep -A 4 -F '[mcp_servers."tailscale"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected tailscale to be enabled in full profile' >&2
  exit 1
fi
grep -A 4 -F '[mcp_servers."memory"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'

# Codex MCP profile: Custom server allowlist via CODEX_MCP_SERVERS
CODEX_MCP_SERVERS="cclsp,docker" sync_mcp_config
grep -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml"
if grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected docker to be enabled in custom servers' >&2
  exit 1
fi
grep -F '[mcp_servers."cclsp"]' "${CODEX_DIR}/config.toml"
if grep -A 4 -F '[mcp_servers."cclsp"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected cclsp to be enabled in custom servers' >&2
  exit 1
fi
grep -A 4 -F '[mcp_servers."git"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
grep -A 4 -F '[mcp_servers."tailscale"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'
unset CODEX_MCP_SERVERS

# Codex MCP profile: CLI arguments validation
(main --configs-only --codex-profile full)
grep -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml"
if grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected docker to be enabled via --codex-profile full' >&2
  exit 1
fi

(main --configs-only --codex-servers=cclsp,docker)
grep -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml"
if grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'; then
  echo 'Expected docker to be enabled via --codex-servers=' >&2
  exit 1
fi
grep -A 4 -F '[mcp_servers."git"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'

# Codex MCP profile: Missing CLI option arguments fail cleanly
if (main --configs-only --codex-profile 2>/dev/null); then
  echo 'Expected missing --codex-profile argument to fail' >&2
  exit 1
fi
if (main --configs-only --codex-profile --configs-only 2>/dev/null); then
  echo 'Expected swallowed --codex-profile flag to fail' >&2
  exit 1
fi
if (main --configs-only --codex-servers 2>/dev/null); then
  echo 'Expected missing --codex-servers argument to fail' >&2
  exit 1
fi
if (main --configs-only --codex-servers --configs-only 2>/dev/null); then
  echo 'Expected swallowed --codex-servers flag to fail' >&2
  exit 1
fi

# Codex MCP profile: Unrecognized profile warns and falls back to minimal
warn_output="$(CODEX_MCP_PROFILE=unknown sync_mcp_config 2>&1)"
[[ "${warn_output}" == *"Warning: Unrecognized CODEX_MCP_PROFILE \"unknown\", defaulting to \"minimal\""* ]]
grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'

# Restore default minimal profile
unset CODEX_MCP_PROFILE CODEX_MCP_SERVERS OPENCODE_MCP_PROFILE OPENCODE_MCP_SERVERS
sync_mcp_config
grep -A 4 -F '[mcp_servers."docker"]' "${CODEX_DIR}/config.toml" | grep -qx 'enabled = false'

# OpenCode MCP profile: Full profile enables non-core servers while preserving globally disabled servers
OPENCODE_MCP_PROFILE=full sync_mcp_config
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["tailscale"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["memory"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]

# OpenCode MCP profile: Custom server allowlist via OPENCODE_MCP_SERVERS
OPENCODE_MCP_SERVERS="cclsp,docker" sync_mcp_config
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["cclsp"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["git"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]
[[ "$(jq -r '.mcp["tailscale"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]
unset OPENCODE_MCP_SERVERS

# OpenCode MCP profile: CLI arguments validation
(main --configs-only --opencode-profile full)
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]

(main --configs-only --opencode-servers=cclsp,docker)
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "true" ]]
[[ "$(jq -r '.mcp["git"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]

# OpenCode MCP profile: Missing CLI option arguments fail cleanly
if (main --configs-only --opencode-profile 2>/dev/null); then
  echo 'Expected missing --opencode-profile argument to fail' >&2
  exit 1
fi
if (main --configs-only --opencode-profile --configs-only 2>/dev/null); then
  echo 'Expected swallowed --opencode-profile flag to fail' >&2
  exit 1
fi
if (main --configs-only --opencode-servers 2>/dev/null); then
  echo 'Expected missing --opencode-servers argument to fail' >&2
  exit 1
fi
if (main --configs-only --opencode-servers --configs-only 2>/dev/null); then
  echo 'Expected swallowed --opencode-servers flag to fail' >&2
  exit 1
fi

# OpenCode MCP profile: Unrecognized profile warns and falls back to minimal
opencode_warn_output="$(OPENCODE_MCP_PROFILE=unknown sync_mcp_config 2>&1)"
[[ "${opencode_warn_output}" == *"Warning: Unrecognized OPENCODE_MCP_PROFILE \"unknown\", defaulting to \"minimal\""* ]]
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]

# Restore default minimal profile
unset CODEX_MCP_PROFILE CODEX_MCP_SERVERS OPENCODE_MCP_PROFILE OPENCODE_MCP_SERVERS
sync_mcp_config
[[ "$(jq -r '.mcp["docker"].enabled' "${OPENCODE_DIR}/opencode.json")" == "false" ]]

# Fast-path stamp check for ai-memory
ai_stamp="${LOCAL_BIN_DIR}/.ai-memory.version"
mkdir -p "${LOCAL_BIN_DIR}"
touch "${LOCAL_BIN_DIR}/ai-memory"
chmod +x "${LOCAL_BIN_DIR}/ai-memory"
printf '3.2.9\n' >"${ai_stamp}"
: >"$calls"
install_ai_memory
[[ ! -s "$calls" ]]

# Verify skill and instruction synchronization across agents
mkdir -p "${HOME}/.local/share/cc-thinking-skills/skills/thinking-model-router"
touch "${HOME}/.local/share/cc-thinking-skills/skills/thinking-model-router/SKILL.md"
mkdir -p "${HOME}/.agents/skills/shared-skill"
touch "${HOME}/.agents/skills/shared-skill/SKILL.md"
mkdir -p "${HOME}/.agents/skills/shared-dir-skill"
touch "${HOME}/.agents/skills/shared-dir-skill/SKILL.md"
mkdir -p "${GEMINI_CONFIG_DIR}/skills/gemini-skill"
touch "${GEMINI_CONFIG_DIR}/skills/gemini-skill/SKILL.md"
mkdir -p "${GEMINI_CONFIG_DIR}/skills/gemini-dir-skill"
touch "${GEMINI_CONFIG_DIR}/skills/gemini-dir-skill/SKILL.md"
mkdir -p "${HOME}/.agents/skills/incomplete-shared-skill"
mkdir -p "${GEMINI_CONFIG_DIR}/skills/incomplete-shared-skill"
touch "${GEMINI_CONFIG_DIR}/skills/incomplete-shared-skill/SKILL.md"

# Directly exercise the collision suffix loop in backup_with_collision_avoidance
printf 'existing\n' >"${test_tmp_dir}/collide.bak"
printf 'moved\n' >"${test_tmp_dir}/collide-src"
backup_with_collision_avoidance "${test_tmp_dir}/collide-src" "${test_tmp_dir}/collide.bak"
[[ "$(<"${test_tmp_dir}/collide.bak")" == 'existing' ]]
[[ "$(<"${test_tmp_dir}/collide.bak.1")" == 'moved' ]]

mkdir -p "${OPENCODE_DIR}/skills/manual-skill"
touch "${OPENCODE_DIR}/skills/manual-skill/SKILL.md"

# Colliding skill directory in OpenCode to verify directory collision backup
mkdir -p "${OPENCODE_DIR}/skills/gemini-dir-skill"
printf 'colliding opencode skill\n' >"${OPENCODE_DIR}/skills/gemini-dir-skill/collision.txt"

# Colliding skill directory in OpenCode for shared skill to verify backup without redundant link
mkdir -p "${OPENCODE_DIR}/skills/shared-dir-skill"
printf 'colliding shared opencode skill\n' >"${OPENCODE_DIR}/skills/shared-dir-skill/collision.txt"

# Colliding custom symlink in OpenCode to verify symlink collision backup
ln -s "${HOME}/external-skill" "${OPENCODE_DIR}/skills/gemini-skill"

# Colliding regular file in Codex to verify non-directory collision backup
mkdir -p "${CODEX_DIR}/skills"
printf 'colliding codex skill file\n' >"${CODEX_DIR}/skills/shared-skill"

# Pre-existing backup file to verify collision-avoidance logic
mkdir -p "${OPENCODE_DIR}/plugins"
mkdir -p "${test_tmp_dir}/old-repo/dotfiles/opencode/plugins"
printf 'retired managed plugin\n' >"${test_tmp_dir}/old-repo/dotfiles/opencode/plugins/copilot-student-models.ts"
rm -f "${OPENCODE_DIR}/AGENTS.md"
printf 'preexisting backup\n' >"${OPENCODE_DIR}/AGENTS.md.bak"
printf 'old opencode instructions\n' >"${OPENCODE_DIR}/AGENTS.md"
ln -s "${repo_dir}/dotfiles/opencode/plugins/copilot-student-models.ts" "${OPENCODE_DIR}/plugins/copilot-student-models.ts"
ln -s "${HOME}/external-plugin.ts" "${OPENCODE_DIR}/plugins/user-plugin.ts"
ln -s "${test_tmp_dir}/old-repo/dotfiles/opencode/plugins/user-plugin.ts" "${OPENCODE_DIR}/plugins/user-dangling-plugin.ts"

mkdir -p "${CODEX_DIR}"
rm -f "${CODEX_DIR}/AGENTS.md"
printf 'preexisting codex backup\n' >"${CODEX_DIR}/AGENTS.md.bak"
printf 'old codex instructions\n' >"${CODEX_DIR}/AGENTS.md"

# Managed dangling symlinks to verify pruning across all agent skill directories
mkdir -p "${GEMINI_CONFIG_DIR}/skills"
ln -s "${HOME}/.agents/skills/removed-codex-skill" "${CODEX_DIR}/skills/stale-codex-skill"
ln -s "${HOME}/.agents/skills/removed-gemini-skill" "${GEMINI_CONFIG_DIR}/skills/stale-gemini-skill"
ln -s "${HOME}/.agents/skills/removed-opencode-skill" "${OPENCODE_DIR}/skills/stale-opencode-skill"

# Managed symlink pointing into search_dirs with obsolete/renamed name to verify pruning
ln -s "${HOME}/.agents/skills/shared-skill" "${OPENCODE_DIR}/skills/renamed-stale-skill"

# Pre-existing redundant symlink in OpenCode pointing to skill in ~/.agents/skills to verify pruning
ln -s "${HOME}/.agents/skills/shared-skill" "${OPENCODE_DIR}/skills/shared-skill"

# Custom user symlinks pointing outside search_dirs to verify they are preserved
mkdir -p "${HOME}/external-skill"
touch "${HOME}/external-skill/SKILL.md"
ln -s "${HOME}/external-skill" "${OPENCODE_DIR}/skills/user-custom-skill"
ln -s "${HOME}/external-skill" "${CODEX_DIR}/skills/user-codex-skill"
ln -s "${HOME}/external-skill" "${GEMINI_CONFIG_DIR}/skills/user-gemini-skill"
ln -s "${HOME}/external-missing" "${OPENCODE_DIR}/skills/user-dangling-skill"
ln -s "${HOME}/external-missing" "${GEMINI_CONFIG_DIR}/skills/user-gemini-dangling-skill"

sync_skills_and_instructions

[[ -L "${OPENCODE_DIR}/AGENTS.md" ]]
[[ "$(readlink "${OPENCODE_DIR}/AGENTS.md")" == "${repo_dir}/dotfiles/gemini/GEMINI.md" ]]
[[ ! -e "${OPENCODE_DIR}/plugins/copilot-student-models.ts" && ! -L "${OPENCODE_DIR}/plugins/copilot-student-models.ts" ]]
[[ -f "${test_tmp_dir}/old-repo/dotfiles/opencode/plugins/copilot-student-models.ts" ]]
[[ -L "${OPENCODE_DIR}/plugins/user-plugin.ts" ]]
[[ "$(readlink "${OPENCODE_DIR}/plugins/user-plugin.ts")" == "${HOME}/external-plugin.ts" ]]
[[ -L "${OPENCODE_DIR}/plugins/user-dangling-plugin.ts" ]]
[[ "$(readlink "${OPENCODE_DIR}/plugins/user-dangling-plugin.ts")" == "${test_tmp_dir}/old-repo/dotfiles/opencode/plugins/user-plugin.ts" ]]
[[ -f "${OPENCODE_DIR}/AGENTS.md.bak" ]]
[[ "$(<"${OPENCODE_DIR}/AGENTS.md.bak")" == 'preexisting backup' ]]
agent_backups=("${OPENCODE_DIR}/AGENTS.md.bak."*)
[[ ${#agent_backups[@]} -ge 1 && -f "${agent_backups[0]}" ]]
[[ "$(<"${agent_backups[0]}")" == 'old opencode instructions' ]]

[[ -L "${CODEX_DIR}/AGENTS.md" ]]
[[ "$(readlink "${CODEX_DIR}/AGENTS.md")" == "${repo_dir}/dotfiles/gemini/GEMINI.md" ]]
[[ -f "${CODEX_DIR}/AGENTS.md.bak" ]]
[[ "$(<"${CODEX_DIR}/AGENTS.md.bak")" == 'preexisting codex backup' ]]
codex_agent_backups=("${CODEX_DIR}/AGENTS.md.bak."*)
[[ ${#codex_agent_backups[@]} -ge 1 && -f "${codex_agent_backups[0]}" ]]
[[ "$(<"${codex_agent_backups[0]}")" == 'old codex instructions' ]]

[[ "$(readlink "${CODEX_DIR}/skills/shared-skill")" == "${HOME}/.agents/skills/shared-skill" ]]
[[ "$(readlink "${CODEX_DIR}/skills/gemini-skill")" == "${GEMINI_CONFIG_DIR}/skills/gemini-skill" ]]
[[ "$(readlink "${CODEX_DIR}/skills/gemini-dir-skill")" == "${GEMINI_CONFIG_DIR}/skills/gemini-dir-skill" ]]
[[ "$(readlink "${CODEX_DIR}/skills/thinking-model-router")" == "${HOME}/.agents/skills/thinking-model-router" ]]
[[ ! -e "${OPENCODE_DIR}/skills/shared-skill" && ! -L "${OPENCODE_DIR}/skills/shared-skill" ]]
[[ ! -e "${OPENCODE_DIR}/skills/shared-dir-skill" && ! -L "${OPENCODE_DIR}/skills/shared-dir-skill" ]]
[[ "$(readlink "${OPENCODE_DIR}/skills/gemini-skill")" == "${GEMINI_CONFIG_DIR}/skills/gemini-skill" ]]
[[ "$(readlink "${OPENCODE_DIR}/skills/gemini-dir-skill")" == "${GEMINI_CONFIG_DIR}/skills/gemini-dir-skill" ]]
[[ "$(readlink "${OPENCODE_DIR}/skills/incomplete-shared-skill")" == "${GEMINI_CONFIG_DIR}/skills/incomplete-shared-skill" ]]
[[ "$(readlink "${CODEX_DIR}/skills/incomplete-shared-skill")" == "${GEMINI_CONFIG_DIR}/skills/incomplete-shared-skill" ]]
[[ ! -e "${OPENCODE_DIR}/skills/thinking-model-router" && ! -L "${OPENCODE_DIR}/skills/thinking-model-router" ]]
[[ "$(readlink "${GEMINI_CONFIG_DIR}/skills/shared-skill")" == "${HOME}/.agents/skills/shared-skill" ]]
[[ "$(readlink "${GEMINI_CONFIG_DIR}/skills/thinking-model-router")" == "${HOME}/.agents/skills/thinking-model-router" ]]

# Settings, title, and statusline symlinks
[[ -L "${GEMINI_DIR}/settings.json" ]]
[[ "$(readlink "${GEMINI_DIR}/settings.json")" == "${repo_dir}/dotfiles/gemini/settings.json" ]]
[[ -L "${GEMINI_DIR}/antigravity-cli/settings.json" ]]
[[ "$(readlink "${GEMINI_DIR}/antigravity-cli/settings.json")" == "${repo_dir}/dotfiles/gemini/antigravity-cli/settings.json" ]]
[[ -L "${GEMINI_DIR}/antigravity-cli/title.sh" ]]
[[ "$(readlink "${GEMINI_DIR}/antigravity-cli/title.sh")" == "${repo_dir}/dotfiles/gemini/antigravity-cli/title.sh" ]]
[[ -L "${LOCAL_BIN_DIR}/agy-statusline" ]]
[[ "$(readlink "${LOCAL_BIN_DIR}/agy-statusline")" == "${repo_dir}/bin/agy-statusline" ]]

# Manual non-symlink skill is preserved
[[ -d "${OPENCODE_DIR}/skills/manual-skill" && ! -L "${OPENCODE_DIR}/skills/manual-skill" ]]

# Colliding skill directory in OpenCode was backed up and preserved
opencode_skill_backups=("${GEMINI_DIR}/skill-backups/opencode-gemini-dir-skill.bak."*)
[[ ${#opencode_skill_backups[@]} -ge 1 && -d "${opencode_skill_backups[0]}" ]]
[[ -f "${opencode_skill_backups[0]}/collision.txt" ]]

# Colliding skill directory for shared skill in OpenCode was backed up without creating redundant link
opencode_shared_dir_backups=("${GEMINI_DIR}/skill-backups/opencode-shared-dir-skill.bak."*)
[[ ${#opencode_shared_dir_backups[@]} -ge 1 && -d "${opencode_shared_dir_backups[0]}" ]]
[[ -f "${opencode_shared_dir_backups[0]}/collision.txt" ]]

# Colliding skill symlink in OpenCode was backed up and preserved
opencode_symlink_backups=("${GEMINI_DIR}/skill-backups/opencode-gemini-skill.bak."*)
[[ ${#opencode_symlink_backups[@]} -ge 1 && -L "${opencode_symlink_backups[0]}" ]]
[[ "$(readlink "${opencode_symlink_backups[0]}")" == "${HOME}/external-skill" ]]

# Colliding skill file in Codex was backed up and preserved
codex_skill_backups=("${GEMINI_DIR}/skill-backups/shared-skill.bak."*)
[[ ${#codex_skill_backups[@]} -ge 1 && -f "${codex_skill_backups[0]}" ]]
[[ "$(<"${codex_skill_backups[0]}")" == 'colliding codex skill file' ]]

# User-owned custom symlinks pointing outside search_dirs are preserved (including dangling user links)
[[ -L "${OPENCODE_DIR}/skills/user-custom-skill" ]]
[[ "$(readlink "${OPENCODE_DIR}/skills/user-custom-skill")" == "${HOME}/external-skill" ]]
[[ -L "${CODEX_DIR}/skills/user-codex-skill" ]]
[[ "$(readlink "${CODEX_DIR}/skills/user-codex-skill")" == "${HOME}/external-skill" ]]
[[ -L "${GEMINI_CONFIG_DIR}/skills/user-gemini-skill" ]]
[[ "$(readlink "${GEMINI_CONFIG_DIR}/skills/user-gemini-skill")" == "${HOME}/external-skill" ]]
[[ -L "${OPENCODE_DIR}/skills/user-dangling-skill" ]]
[[ "$(readlink "${OPENCODE_DIR}/skills/user-dangling-skill")" == "${HOME}/external-missing" ]]
[[ -L "${GEMINI_CONFIG_DIR}/skills/user-gemini-dangling-skill" ]]
[[ "$(readlink "${GEMINI_CONFIG_DIR}/skills/user-gemini-dangling-skill")" == "${HOME}/external-missing" ]]

# Dangling/stale symlinks were pruned
[[ ! -e "${OPENCODE_DIR}/skills/stale-opencode-skill" && ! -L "${OPENCODE_DIR}/skills/stale-opencode-skill" ]]
[[ ! -e "${CODEX_DIR}/skills/stale-codex-skill" && ! -L "${CODEX_DIR}/skills/stale-codex-skill" ]]
[[ ! -e "${GEMINI_CONFIG_DIR}/skills/stale-gemini-skill" && ! -L "${GEMINI_CONFIG_DIR}/skills/stale-gemini-skill" ]]
[[ ! -e "${OPENCODE_DIR}/skills/renamed-stale-skill" && ! -L "${OPENCODE_DIR}/skills/renamed-stale-skill" ]]

# Verify sync_skills_and_instructions is idempotent and creates no additional backups
backup_count_before=$(find "${GEMINI_DIR}/skill-backups" -mindepth 1 | wc -l)
sync_skills_and_instructions
backup_count_after=$(find "${GEMINI_DIR}/skill-backups" -mindepth 1 | wc -l)
[[ "${backup_count_before}" -eq "${backup_count_after}" ]]

# Verify OpenCode startup emits zero duplicate skill warnings when available
if command -v opencode >/dev/null 2>&1; then
  opencode_output="$(opencode debug skill --print-logs --log-level WARN 2>&1)"
  [[ ! "${opencode_output}" == *'message="duplicate skill name"'* ]]
fi

# Symlinks whose targets share the retired plugin suffix outside REPO_DIR are preserved as user-owned links.
(
  external_repo="${test_tmp_dir}/external-repo"
  external_target="${external_repo}/dotfiles/opencode/plugins/copilot-student-models.ts"
  mkdir -p "$(dirname "${external_target}")"
  printf 'external custom copilot plugin\n' >"${external_target}"
  external_plugin="${OPENCODE_DIR}/plugins/copilot-student-models.ts"
  ln -s "${external_target}" "${external_plugin}"
  sync_skills_and_instructions
  [[ -L "${external_plugin}" ]]
  [[ "$(readlink "${external_plugin}")" == "${external_target}" ]]
  rm -f "${external_plugin}"
)

# User-owned files and links with the retired plugin name are preserved.
user_plugin="${OPENCODE_DIR}/plugins/copilot-student-models.ts"
printf 'user-owned plugin\n' >"${user_plugin}"
sync_skills_and_instructions
[[ -f "${user_plugin}" && ! -L "${user_plugin}" ]]
[[ "$(<"${user_plugin}")" == 'user-owned plugin' ]]
rm -f "${user_plugin}"
ln -s "${HOME}/external-plugin.ts" "${user_plugin}"
sync_skills_and_instructions
[[ -L "${user_plugin}" ]]
[[ "$(readlink "${user_plugin}")" == "${HOME}/external-plugin.ts" ]]
rm -f "${user_plugin}"

# Verify sync_skills_and_instructions leaves OPENCODE_DIR absent when opencode is absent
(
  export XDG_CONFIG_HOME="${test_tmp_dir}/clean-xdg"
  OPENCODE_DIR="${XDG_CONFIG_HOME}/opencode"
  opencode_available() { return 1; }
  sync_skills_and_instructions
  [[ ! -e "${OPENCODE_DIR}" ]]
)

install_codebase_memory_mcp() { echo codebase >>"$calls"; }
install_ai_memory() { echo ai-memory >>"$calls"; }
install_thinking_skills() { echo thinking-skills >>"$calls"; }
install_github_mcp_server() { echo github >>"$calls"; }
install_terraform_mcp_server() { echo terraform >>"$calls"; }
install_repomix() { echo repomix >>"$calls"; }
install_semgrep() { echo semgrep >>"$calls"; }
install_sonarqube_mcp_server() { echo sonarqube >>"$calls"; }
sync_ssh_profiles() { :; }
sync_docker_profiles() { :; }
sync_k3s_cluster() { echo k3s >>"$calls"; }
sync_memory_file() { :; }
sync_mcp_config() { :; }
sync_skills_and_instructions() { :; }
opencode() { :; }

: >"$calls"

(main --configs-only)

[[ ! -s "$calls" ]]

(main --codebase-memory-only)

[[ "$(cat "$calls")" == codebase ]]
: >"$calls"

(main)

[[ "$(cat "$calls")" == $'codebase\nai-memory\nthinking-skills\ngithub\nterraform\nrepomix\nsemgrep\nsonarqube\nk3s' ]]
echo 'MCP setup checks passed'
