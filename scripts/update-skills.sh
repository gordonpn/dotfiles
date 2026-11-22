#!/usr/bin/env bash
# Update lockfile-tracked global skills, standalone skill clones, and re-sync harnesses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL_LOCK_FILE="${HOME}/.agents/.skill-lock.json"
MCP_SYNC_BIN="${MCP_SYNC_BIN:-${REPO_DIR}/bin/mcp-sync}"

if command -v skills >/dev/null 2>&1 && [[ -f "${SKILL_LOCK_FILE}" ]]; then
  skills update -g -y
else
  echo "Notice: skills CLI or ${SKILL_LOCK_FILE} not present, skipping lockfile skill updates."
fi

skill_repos=(
  "${HOME}/.local/share/cc-thinking-skills"
  "${HOME}/.gemini/config/plugins/ponytail"
)

for repo in "${skill_repos[@]}"; do
  if [[ -d "${repo}/.git" ]]; then
    git -C "${repo}" pull --ff-only
  else
    echo "Notice: ${repo} not found, skipping git pull."
  fi
done

bash "${MCP_SYNC_BIN}" --configs-only
