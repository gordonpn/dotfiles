#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper for read-only repository analysis
# Usage:
#   delegate-analyze.sh '<task>'                 # defaults to opencode (DeepSeek Flash Free)
#   delegate-analyze.sh copilot '<task>'         # uses GitHub Copilot via OpenCode
#   delegate-analyze.sh gemini '<task>'          # uses Gemini CLI
#   delegate-analyze.sh opencode '<task>'        # explicitly uses OpenCode

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT="opencode"

if [[ $# -ge 2 && ($1 == "opencode" || $1 == "copilot" || $1 == "gemini") ]]; then
  AGENT=$1
  shift
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [opencode|copilot|gemini] '<analysis task>'" >&2
  exit 2
fi

exec "$SCRIPT_DIR/delegate.sh" --agent "$AGENT" --mode plan --task "$*"
