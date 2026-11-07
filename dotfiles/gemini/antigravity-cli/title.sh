#!/usr/bin/env bash
# Antigravity CLI terminal title generator.
# Reads runtime telemetry JSON from stdin and formats:
# [agent_state] <directory_basename>

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input=$(cat)

if [[ -z "$input" ]]; then
    exit 0
fi

printf '%s\n' "$input" | jq -r '
  (try (.agent_state // "") catch "") as $state |
  (try (.workspace.current_dir // .cwd // "" | (if . == "/" then "/" else (split("/") | map(select(length > 0)) | last // "") end)) catch "") as $dir |
  if $state != "" and $dir != "" then
    "[\($state)] \($dir)"
  elif $dir != "" then
    $dir
  elif $state != "" then
    "[\($state)]"
  else
    empty
  end
' 2>/dev/null || true
