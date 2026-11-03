#!/usr/bin/env bash
set -euo pipefail

if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  echo "configured=true" >> "$GITHUB_OUTPUT"
else
  echo "configured=false" >> "$GITHUB_OUTPUT"
  echo "::warning::DEEPSEEK_API_KEY is not configured; skipping DeepSeek workflow"
fi
