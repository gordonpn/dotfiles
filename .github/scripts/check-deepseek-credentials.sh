#!/usr/bin/env bash
set -euo pipefail

if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  echo "configured=true" >> "$GITHUB_OUTPUT"
else
  echo "DEEPSEEK_API_KEY is not configured; cannot run DeepSeek workflow" >&2
  exit 1
fi
