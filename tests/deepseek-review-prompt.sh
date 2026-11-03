#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

prompt_file="${repo_dir}/.github/prompts/deepseek-review.md"
output_file="${tmp_dir}/github_output"
script="${repo_dir}/.github/scripts/write-deepseek-review-prompt.sh"

GITHUB_OUTPUT="$output_file" "$script" "$prompt_file"

delimiter="$(sed -n 's/^prompt<<//p' "$output_file")"
[[ "$delimiter" =~ ^DEEPSEEK_PROMPT_[0-9]+_[0-9]+_[0-9]+$ ]]
[[ "$(sed '1d;$d' "$output_file")" == "$(cat "$prompt_file")" ]]

if GITHUB_OUTPUT="$output_file" "$script" >/dev/null 2>&1; then
  echo "prompt helper accepted a missing file argument" >&2
  exit 1
fi

echo "deepseek-review-prompt checks passed"
