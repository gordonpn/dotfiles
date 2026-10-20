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

get_secret() { printf ''; }
gh() { return 1; }

sync_mcp_config
uv run --no-project --with mcp==1.1.2 python "${repo_dir}/tests/verify_mcp.py" --configs-only

# Verify skill and instruction synchronization across agents
mkdir -p "${HOME}/.agents/skills/shared-skill"
touch "${HOME}/.agents/skills/shared-skill/SKILL.md"
mkdir -p "${GEMINI_CONFIG_DIR}/skills/gemini-skill"
touch "${GEMINI_CONFIG_DIR}/skills/gemini-skill/SKILL.md"

# Directly exercise the collision suffix loop in backup_with_collision_avoidance
printf 'existing\n' >"${test_tmp_dir}/collide.bak"
printf 'moved\n' >"${test_tmp_dir}/collide-src"
backup_with_collision_avoidance "${test_tmp_dir}/collide-src" "${test_tmp_dir}/collide.bak"
[[ "$(<"${test_tmp_dir}/collide.bak")" == 'existing' ]]
[[ "$(<"${test_tmp_dir}/collide.bak.1")" == 'moved' ]]

mkdir -p "${OPENCODE_DIR}/skills/manual-skill"
touch "${OPENCODE_DIR}/skills/manual-skill/SKILL.md"

# Colliding skill directory in OpenCode to verify directory collision backup
mkdir -p "${OPENCODE_DIR}/skills/shared-skill"
printf 'colliding opencode skill\n' >"${OPENCODE_DIR}/skills/shared-skill/collision.txt"

# Colliding custom symlink in OpenCode to verify symlink collision backup
ln -s "${HOME}/external-skill" "${OPENCODE_DIR}/skills/gemini-skill"

# Colliding regular file in Codex to verify non-directory collision backup
mkdir -p "${CODEX_DIR}/skills"
printf 'colliding codex skill file\n' >"${CODEX_DIR}/skills/shared-skill"

# Pre-existing backup file to verify collision-avoidance logic
mkdir -p "${OPENCODE_DIR}"
printf 'preexisting backup\n' >"${OPENCODE_DIR}/AGENTS.md.bak"
printf 'old opencode instructions\n' >"${OPENCODE_DIR}/AGENTS.md"

mkdir -p "${CODEX_DIR}"
printf 'preexisting codex backup\n' >"${CODEX_DIR}/AGENTS.md.bak"
printf 'old codex instructions\n' >"${CODEX_DIR}/AGENTS.md"

# Managed dangling symlinks to verify pruning across all agent skill directories
mkdir -p "${GEMINI_CONFIG_DIR}/skills"
ln -s "${HOME}/.agents/skills/removed-codex-skill" "${CODEX_DIR}/skills/stale-codex-skill"
ln -s "${HOME}/.agents/skills/removed-gemini-skill" "${GEMINI_CONFIG_DIR}/skills/stale-gemini-skill"
ln -s "${HOME}/.agents/skills/removed-opencode-skill" "${OPENCODE_DIR}/skills/stale-opencode-skill"

# Managed symlink pointing into search_dirs with obsolete/renamed name to verify pruning
ln -s "${HOME}/.agents/skills/shared-skill" "${OPENCODE_DIR}/skills/renamed-stale-skill"

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
[[ "$(readlink "${OPENCODE_DIR}/skills/shared-skill")" == "${HOME}/.agents/skills/shared-skill" ]]
[[ "$(readlink "${OPENCODE_DIR}/skills/gemini-skill")" == "${GEMINI_CONFIG_DIR}/skills/gemini-skill" ]]
[[ "$(readlink "${GEMINI_CONFIG_DIR}/skills/shared-skill")" == "${HOME}/.agents/skills/shared-skill" ]]

# Manual non-symlink skill is preserved
[[ -d "${OPENCODE_DIR}/skills/manual-skill" && ! -L "${OPENCODE_DIR}/skills/manual-skill" ]]

# Colliding skill directory in OpenCode was backed up and preserved
opencode_skill_backups=("${GEMINI_DIR}/skill-backups/opencode-shared-skill.bak."*)
[[ ${#opencode_skill_backups[@]} -ge 1 && -d "${opencode_skill_backups[0]}" ]]
[[ -f "${opencode_skill_backups[0]}/collision.txt" ]]

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

# Verify sync_skills_and_instructions leaves OPENCODE_DIR absent when opencode is absent
(
  export XDG_CONFIG_HOME="${test_tmp_dir}/clean-xdg"
  OPENCODE_DIR="${XDG_CONFIG_HOME}/opencode"
  opencode_available() { return 1; }
  sync_skills_and_instructions
  [[ ! -e "${OPENCODE_DIR}" ]]
)

install_codebase_memory_mcp() { echo codebase >>"$calls"; }
install_github_mcp_server() { echo github >>"$calls"; }
install_terraform_mcp_server() { echo terraform >>"$calls"; }
install_repomix() { echo repomix >>"$calls"; }
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

[[ "$(cat "$calls")" == $'codebase\ngithub\nterraform\nrepomix\nk3s' ]]
echo 'MCP setup checks passed'
