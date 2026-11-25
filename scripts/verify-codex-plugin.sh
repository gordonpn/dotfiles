#!/usr/bin/env bash
# Non-mutating heuristic contract smoke check for the Antigravity Codex plugin runner.
# Verifies syntax with node --check and checks CLI symbols via grep (not a JS AST proof).

set -euo pipefail

runner_path="${CODEX_PLUGIN_RUNNER:-${HOME}/.gemini/config/plugins/codex/scripts/codex-runner.mjs}"
allow_missing=0

usage() {
  cat <<'EOF'
Usage: verify-codex-plugin.sh [--runner <path>] [--allow-missing]

Verify the Antigravity Codex plugin runner syntax and CLI contract without
executing codex or modifying background jobs.

Options:
  --runner <path>   Path to codex-runner.mjs
                    (default: ${CODEX_PLUGIN_RUNNER:-$HOME/.gemini/config/plugins/codex/scripts/codex-runner.mjs})
  --allow-missing   Exit 0 with a fallback notice if the runner is absent
  -h, --help        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runner)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "Error: --runner requires a non-empty path." >&2
        exit 2
      fi
      runner_path="$2"
      shift 2
      ;;
    --runner=*)
      runner_path="${1#--runner=}"
      if [[ -z "${runner_path}" ]]; then
        echo "Error: --runner requires a non-empty path." >&2
        exit 2
      fi
      shift
      ;;
    --allow-missing)
      allow_missing=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "${runner_path}" ]]; then
  if [[ "${allow_missing}" -eq 1 ]]; then
    printf 'Notice: Codex plugin runner not found at %s; read-only plan tasks fall back to delegate.sh.\n' "${runner_path}"
    exit 0
  fi
  printf 'Error: Codex plugin runner not found at %s.\n' "${runner_path}" >&2
  printf 'Install the Antigravity Codex plugin, or pass --allow-missing when relying on delegate.sh fallback.\n' >&2
  exit 1
fi

if [[ ! -r "${runner_path}" ]]; then
  printf 'Error: Codex plugin runner is not readable: %s\n' "${runner_path}" >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  node --check "${runner_path}"
else
  printf 'Error: node is required to verify %s but was not found on PATH.\n' "${runner_path}" >&2
  exit 1
fi

# Strip full-line // comments only; trailing or block comments are outside this heuristic smoke check.
source_body="$(grep -v '^[[:space:]]*//' "${runner_path}" || true)"

required_subcommands=(
  "setup"
  "review"
  "adversarial-review"
  "task"
  "status"
  "result"
  "cancel"
)

missing=0
for cmd in "${required_subcommands[@]}"; do
  cmd_pattern="(['\"]${cmd}['\"]|[|<]${cmd}[|>])"
  if ! printf '%s\n' "${source_body}" | grep -Eq "${cmd_pattern}"; then
    printf 'Error: missing required subcommand in %s: %s\n' "${runner_path}" "${cmd}" >&2
    missing=1
  fi
done

required_flags=(
  "--base"
  "--resume-last"
  "--write"
  "--background"
)

for flag in "${required_flags[@]}"; do
  flag_name="${flag#--}"
  flag_pattern="(--${flag_name}([^[:alnum:]_-]|$)|flags\\.${flag_name}([^[:alnum:]_-]|$)|flags\\[['\"]${flag_name}['\"]\\]|parseFlags\\([^)]*['\"]${flag_name}['\"])"
  if ! printf '%s\n' "${source_body}" | grep -Eq "${flag_pattern}"; then
    printf 'Error: missing required flag in %s: %s\n' "${runner_path}" "${flag}" >&2
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

printf 'Verified Codex plugin runner contract: %s\n' "${runner_path}"
