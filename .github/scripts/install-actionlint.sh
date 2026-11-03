#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_PATH:?GITHUB_PATH is required}"

if [[ "${RUNNER_OS:-Linux}" != Linux || "${RUNNER_ARCH:-X64}" != X64 ]]; then
  printf '%s\n' 'actionlint installer requires a Linux x64 runner' >&2
  exit 1
fi

# reviewdog's pinned wrapper bundles actionlint 1.17.0; keep fork lint current.
version=1.7.12
archive="actionlint_${version}_linux_amd64.tar.gz"
archive_sha256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
bin_dir="${RUNNER_TEMP}/actionlint-bin"
mkdir -p "$bin_dir"
archive_path="${RUNNER_TEMP}/${archive}"
curl --fail --location --silent --show-error \
  "https://github.com/rhysd/actionlint/releases/download/v${version}/${archive}" \
  --output "$archive_path"
printf '%s  %s\n' "$archive_sha256" "$archive_path" | shasum -a 256 --check
tar -xzf "$archive_path" -C "$bin_dir" actionlint
printf '%s\n' "$bin_dir" >>"$GITHUB_PATH"
