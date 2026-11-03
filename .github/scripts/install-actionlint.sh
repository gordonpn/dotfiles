#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_PATH:?GITHUB_PATH is required}"

bin_dir="${RUNNER_TEMP}/actionlint-bin"
mkdir -p "$bin_dir"
GOBIN="$bin_dir" go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
printf '%s\n' "$bin_dir" >>"$GITHUB_PATH"
