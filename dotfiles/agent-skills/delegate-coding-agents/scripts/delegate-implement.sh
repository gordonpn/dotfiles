#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper for worktree-isolated implementation
# Usage:
#   delegate-implement.sh [--orchestrator codex|agy] <codex|opencode|copilot> <task-id> '<task>'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORCHESTRATOR=${DELEGATE_ORCHESTRATOR:-codex}

if [[ $# -ge 2 && $1 == "--orchestrator" ]]; then
  ORCHESTRATOR=$2
  shift 2
fi

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 [--orchestrator codex|agy] <codex|opencode|copilot> <task-id> '<task description>'" >&2
  exit 2
fi

AGENT=$1
TASK_ID=$2
shift 2

exec "$SCRIPT_DIR/delegate.sh" --orchestrator "$ORCHESTRATOR" --agent "$AGENT" --mode build --id "$TASK_ID" --task "$*"
