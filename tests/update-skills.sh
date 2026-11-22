#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_dir}/scripts/update-skills.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

calls="${tmp_dir}/calls.log"
fake_bin="${tmp_dir}/bin"
mkdir -p "${fake_bin}"

cat >"${fake_bin}/mcp-sync-stub" <<EOF
#!/usr/bin/env bash
printf 'mcp-sync %s\n' "\$*" >>"${calls}"
EOF
chmod +x "${fake_bin}/mcp-sync-stub"

# Case 1: No skills lockfile and no git clones; still runs mcp-sync --configs-only cleanly.
home_empty="${tmp_dir}/home-empty"
mkdir -p "${home_empty}"
: >"${calls}"
HOME="${home_empty}" MCP_SYNC_BIN="${fake_bin}/mcp-sync-stub" PATH="${fake_bin}:/usr/bin:/bin" \
  bash "${script}" >/dev/null
grep -qx 'mcp-sync --configs-only' "${calls}"

# Case 2: Lockfile + skills CLI + standalone skill git clones present.
cat >"${fake_bin}/skills" <<EOF
#!/usr/bin/env bash
printf 'skills %s\n' "\$*" >>"${calls}"
EOF
chmod +x "${fake_bin}/skills"

home_full="${tmp_dir}/home-full"
mkdir -p "${home_full}/.agents" "${home_full}/.local/share" "${home_full}/.gemini/config/plugins"
printf '{"version":3,"skills":{}}\n' >"${home_full}/.agents/.skill-lock.json"

seed_and_advance_repo() {
  local name="$1"
  local clone_dest="$2"
  local origin_bare="${tmp_dir}/${name}-origin.git"
  local seed_work="${tmp_dir}/${name}-seed"

  git init --bare "${origin_bare}" >/dev/null 2>&1
  git clone "${origin_bare}" "${seed_work}" >/dev/null 2>&1
  git -C "${seed_work}" config user.name 'Test'
  git -C "${seed_work}" config user.email 'test@example.com'
  printf 'v1\n' >"${seed_work}/SKILL.md"
  git -C "${seed_work}" add SKILL.md
  git -C "${seed_work}" commit -m 'Initial' >/dev/null 2>&1
  git -C "${seed_work}" push -u origin HEAD >/dev/null 2>&1

  git clone "${origin_bare}" "${clone_dest}" >/dev/null 2>&1

  printf 'v2\n' >"${seed_work}/SKILL.md"
  git -C "${seed_work}" add SKILL.md
  git -C "${seed_work}" commit -m 'Update' >/dev/null 2>&1
  git -C "${seed_work}" push >/dev/null 2>&1
}

seed_and_advance_repo "thinking" "${home_full}/.local/share/cc-thinking-skills"
seed_and_advance_repo "ponytail" "${home_full}/.gemini/config/plugins/ponytail"

: >"${calls}"
HOME="${home_full}" MCP_SYNC_BIN="${fake_bin}/mcp-sync-stub" PATH="${fake_bin}:${PATH}" \
  bash "${script}" >/dev/null

grep -qx 'skills update -g -y' "${calls}"
grep -qx 'mcp-sync --configs-only' "${calls}"
[[ "$(<"${home_full}/.local/share/cc-thinking-skills/SKILL.md")" == 'v2' ]]
[[ "$(<"${home_full}/.gemini/config/plugins/ponytail/SKILL.md")" == 'v2' ]]

echo 'update-skills checks passed'
