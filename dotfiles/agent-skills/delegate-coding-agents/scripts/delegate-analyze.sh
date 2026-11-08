#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper for read-only repository analysis
# Usage:
#   delegate-analyze.sh '<task>'                                     # defaults to opencode (DeepSeek Flash Free)
#   delegate-analyze.sh --orchestrator agy codex '<task>'            # uses Codex CLI under Antigravity
#   delegate-analyze.sh opencode '<task>'                            # uses OpenCode
#   delegate-analyze.sh copilot '<task>'                             # uses GitHub Copilot CLI

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORCHESTRATOR=${DELEGATE_ORCHESTRATOR:-codex}
AGENT="opencode"

if [[ $# -ge 2 && $1 == "--orchestrator" ]]; then
  ORCHESTRATOR=$2
  shift 2
fi

if [[ $# -ge 2 && ($1 == "codex" || $1 == "opencode" || $1 == "copilot") ]]; then
  AGENT=$1
  shift
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [--orchestrator codex|agy] [codex|opencode|copilot] '<analysis task>'" >&2
  exit 2
fi

exec "$SCRIPT_DIR/delegate.sh" --orchestrator "$ORCHESTRATOR" --agent "$AGENT" --mode plan --task "$*"
