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

# Case 3: Diverged clone and failing skills CLI warn and exit non-zero without skipping remaining pulls or mcp-sync.
cat >"${fake_bin}/skills" <<EOF
#!/usr/bin/env bash
printf 'skills-fail %s\n' "\$*" >>"${calls}"
exit 1
EOF
chmod +x "${fake_bin}/skills"

git -C "${home_full}/.gemini/config/plugins/ponytail" config user.name 'Test'
git -C "${home_full}/.gemini/config/plugins/ponytail" config user.email 'test@example.com'
printf 'local-only\n' >"${home_full}/.gemini/config/plugins/ponytail/LOCAL.md"
git -C "${home_full}/.gemini/config/plugins/ponytail" add LOCAL.md
git -C "${home_full}/.gemini/config/plugins/ponytail" commit -m 'Diverge locally' >/dev/null 2>&1

printf 'v3-upstream\n' >"${tmp_dir}/ponytail-seed/SKILL.md"
git -C "${tmp_dir}/ponytail-seed" add SKILL.md
git -C "${tmp_dir}/ponytail-seed" commit -m 'Diverge upstream' >/dev/null 2>&1
git -C "${tmp_dir}/ponytail-seed" push >/dev/null 2>&1

printf 'v3\n' >"${tmp_dir}/thinking-seed/SKILL.md"
git -C "${tmp_dir}/thinking-seed" add SKILL.md
git -C "${tmp_dir}/thinking-seed" commit -m 'Advance v3' >/dev/null 2>&1
git -C "${tmp_dir}/thinking-seed" push >/dev/null 2>&1

: >"${calls}"
set +e
HOME="${home_full}" MCP_SYNC_BIN="${fake_bin}/mcp-sync-stub" PATH="${fake_bin}:${PATH}" \
  bash "${script}" >"${tmp_dir}/case3.out" 2>"${tmp_dir}/case3.err"
case3_status=$?
set -e
[[ "${case3_status}" -eq 1 ]]
grep -qx 'skills-fail update -g -y' "${calls}"
grep -qx 'mcp-sync --configs-only' "${calls}"
grep -q 'Warning: skills update -g -y failed' "${tmp_dir}/case3.err"
grep -q 'Warning: failed to fast-forward' "${tmp_dir}/case3.err"
[[ "$(<"${home_full}/.local/share/cc-thinking-skills/SKILL.md")" == 'v3' ]]

# Case 4: Missing mcp-sync target fails explicitly.
set +e
HOME="${home_empty}" MCP_SYNC_BIN="${tmp_dir}/missing-mcp-sync" PATH="${fake_bin}:/usr/bin:/bin" \
  bash "${script}" >/dev/null 2>"${tmp_dir}/case4.err"
case4_status=$?
set -e
[[ "${case4_status}" -ne 0 ]]
grep -q 'Error: mcp-sync not found' "${tmp_dir}/case4.err"

echo 'update-skills checks passed'
