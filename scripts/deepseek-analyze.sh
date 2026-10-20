#!/usr/bin/env bash
set -euo pipefail

# Contract required by delegate script (delegate-coding-agents skill v1):
#   delegate.sh --agent <agy|opencode> --mode <plan|build> --model <model> --task <task>

readonly DEFAULT_MODEL="opencode/deepseek-v4.1-flash-free"

usage() {
  local exit_code="${1:-2}"
  local target_fd=2
  if [[ "${exit_code}" -eq 0 ]]; then
    target_fd=1
  fi
  local help_text
  help_text="$(cat <<'EOF'
Usage: deepseek-analyze.sh [--] <analysis task ...>
       deepseek-analyze.sh -h | --help

Delegates read-only analysis to the delegate-coding-agents skill using OpenCode.

Options:
  -h, --help            Display this help and exit.
  --                    Treat all subsequent arguments as the task (useful if
                        the task begins with -h or --help).

Arguments:
  <analysis task ...>   One or more words describing the task; joined with spaces.

Environment variables:
  DELEGATE_SKILL_SCRIPT Optional custom path to delegate.sh
                        (default: $HOME/.agents/skills/delegate-coding-agents/scripts/delegate.sh).
                        Must be absolute or contain a '/' (e.g. ./delegate.sh);
                        relative paths are anchored to $PWD at startup.
  OPENCODE_MODEL        Optional model override
                        (default: @DEFAULT_MODEL@)

Requires delegate-coding-agents skill v1+ providing:
  delegate.sh --agent opencode --mode plan --model <model> --task <task>
EOF
)"
  printf '%s\n' "${help_text//@DEFAULT_MODEL@/${DEFAULT_MODEL}}" >&"${target_fd}"
  exit "${exit_code}"
}

trim() {
  local val="$1"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  printf '%s' "${val}"
}

if [[ $# -eq 0 ]]; then
  usage 2
fi

if [[ "$1" == "--" ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    usage 2
  fi
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage 0
fi

task="$*"

if [[ -z "${task//[[:space:]]/}" ]]; then
  usage 2
fi

SKILL_SCRIPT="$(trim "${DELEGATE_SKILL_SCRIPT:-}")"
# shellcheck disable=SC2088
if [[ "${SKILL_SCRIPT}" == "~" || "${SKILL_SCRIPT}" == "~/"* ]]; then
  if [[ -z "${HOME:-}" ]]; then
    echo "Error: HOME is not set; cannot expand tilde in DELEGATE_SKILL_SCRIPT: ${SKILL_SCRIPT}" >&2
    exit 1
  fi
  if [[ "${SKILL_SCRIPT}" == "~" ]]; then
    SKILL_SCRIPT="${HOME}"
  else
    SKILL_SCRIPT="${HOME}/${SKILL_SCRIPT#"~/"}"
  fi
elif [[ "${SKILL_SCRIPT}" == "~"* ]]; then
  echo "Error: user-specific tilde paths (~user/...) are not supported in DELEGATE_SKILL_SCRIPT: ${SKILL_SCRIPT}" >&2
  exit 1
fi
if [[ -z "${SKILL_SCRIPT}" ]]; then
  if [[ -z "${HOME:-}" ]]; then
    echo "Error: HOME is not set; cannot locate delegate skill script" >&2
    exit 1
  fi
  SKILL_SCRIPT="${HOME}/.agents/skills/delegate-coding-agents/scripts/delegate.sh"
fi

if [[ "${SKILL_SCRIPT}" != */* ]]; then
  echo "Error: delegate skill script must be an absolute path or contain a '/': ${SKILL_SCRIPT}" >&2
  exit 1
fi

if [[ "${SKILL_SCRIPT}" != /* ]]; then
  SKILL_SCRIPT="${PWD%/}/${SKILL_SCRIPT#./}"
fi

if [[ -L "${SKILL_SCRIPT}" && ! -e "${SKILL_SCRIPT}" ]]; then
  echo "Error: delegate skill script is a dangling symlink: ${SKILL_SCRIPT}" >&2
  exit 1
elif [[ ! -e "${SKILL_SCRIPT}" ]]; then
  echo "Error: delegate skill script not found at ${SKILL_SCRIPT} (install delegate-coding-agents skill or set DELEGATE_SKILL_SCRIPT)" >&2
  exit 1
elif [[ ! -f "${SKILL_SCRIPT}" ]]; then
  echo "Error: delegate skill script is not a regular file: ${SKILL_SCRIPT}" >&2
  exit 1
elif [[ ! -r "${SKILL_SCRIPT}" ]]; then
  echo "Error: delegate skill script is not readable: ${SKILL_SCRIPT}" >&2
  exit 1
elif [[ ! -x "${SKILL_SCRIPT}" ]]; then
  echo "Error: delegate skill script is not executable: ${SKILL_SCRIPT} (run: chmod +x \"${SKILL_SCRIPT}\")" >&2
  exit 1
fi

model="$(trim "${OPENCODE_MODEL:-}")"
if [[ -z "${model}" ]]; then
  model="${DEFAULT_MODEL}"
fi

exec "${SKILL_SCRIPT}" \
  --agent opencode \
  --mode plan \
  --model "${model}" \
  --task "${task}"
