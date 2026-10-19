#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 '<analysis task>'" >&2
  exit 2
fi

exec opencode run \
  --model "${OPENCODE_MODEL:-opencode/deepseek-v4.1-flash-free}" \
  --agent plan \
  -- \
  "$@"
