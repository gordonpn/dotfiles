#!/usr/bin/env bash
# Update lockfile-tracked global skills, standalone skill clones, and re-sync harnesses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL_LOCK_FILE="${HOME}/.agents/.skill-lock.json"
MCP_SYNC_BIN="${MCP_SYNC_BIN:-${REPO_DIR}/bin/mcp-sync}"

had_error=0

if command -v skills >/dev/null 2>&1 && [[ -f "${SKILL_LOCK_FILE}" ]]; then
  if ! skills update -g -y; then
    echo "Warning: skills update -g -y failed; continuing to remaining updates and sync." >&2
    had_error=1
  fi
else
  echo "Notice: skills CLI or ${SKILL_LOCK_FILE} not present, skipping lockfile skill updates."
fi

skill_repos=(
  "${HOME}/.local/share/cc-thinking-skills"
  "${HOME}/.gemini/config/plugins/ponytail"
)

for repo in "${skill_repos[@]}"; do
  if [[ -d "${repo}/.git" ]]; then
    if ! git -C "${repo}" pull --ff-only; then
      echo "Warning: failed to fast-forward ${repo}; continuing." >&2
      had_error=1
    fi
  else
    echo "Notice: ${repo} not found, skipping git pull."
  fi
done

if [[ ! -f "${MCP_SYNC_BIN}" ]]; then
  echo "Error: mcp-sync not found at ${MCP_SYNC_BIN}" >&2
  exit 1
fi

bash "${MCP_SYNC_BIN}" --configs-only
exit "${had_error}"
