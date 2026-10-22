#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper for worktree-isolated implementation
# Usage:
#   delegate-implement.sh <opencode|agy> <task-id> '<task>'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <opencode|agy> <task-id> '<task description>'" >&2
  exit 2
fi

AGENT=$1
TASK_ID=$2
shift 2

exec "$SCRIPT_DIR/delegate.sh" --agent "$AGENT" --mode build --id "$TASK_ID" --task "$*"
