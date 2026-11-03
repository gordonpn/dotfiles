#!/usr/bin/env bash
set -euo pipefail

if [[ ! "${DEEPSEEK_API_KEY:-}" =~ [^[:space:]] ]]; then
  echo "DEEPSEEK_API_KEY is not configured; cannot run DeepSeek workflow" >&2
  exit 1
fi
