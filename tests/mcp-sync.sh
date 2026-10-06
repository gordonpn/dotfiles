#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$test_tmp_dir"' EXIT
export UV_CACHE_DIR="${UV_CACHE_DIR:-$HOME/.cache/uv}"
export HOME="${test_tmp_dir}/home"
export TMPDIR="${test_tmp_dir}"
mkdir -p "$HOME"

grep -q '^install_codebase_memory_mcp()' "${repo_dir}/bin/mcp-sync"

# Source functions without running the host's provisioning workflow.
# shellcheck source=bin/mcp-sync
source "${repo_dir}/bin/mcp-sync"

calls="${test_tmp_dir}/calls"
fixture="${test_tmp_dir}/fixture"
mkdir -p "$fixture"
cp /usr/bin/true "${fixture}/codebase-memory-mcp"
tar -czf "${fixture}/archive.tar.gz" -C "$fixture" codebase-memory-mcp
fixture_digest="$(sha256_of "${fixture}/archive.tar.gz")"
for os in darwin linux; do
  for arch in arm64 amd64; do
    suffix=
    [[ "$os" != linux ]] || suffix=-portable
    printf '%s  codebase-memory-mcp-%s-%s%s.tar.gz\n' "$fixture_digest" "$os" "$arch" "$suffix" >>"${fixture}/checksums.txt"
  done
done

fake_os=Linux
fake_arch=x86_64
uname() {
  case "$1" in
    -s) echo "$fake_os" ;;
    -m) echo "$fake_arch" ;;
  esac
}
curl() {
  printf 'curl %s\n' "$*" >>"$calls"
  [[ "${download_fails:-0}" == 0 ]] || return 22
  if [[ "$5" == */checksums.txt ]]; then
    cp "${fixture}/checksums.txt" "$5"
    [[ "${checksum_invalid:-0}" == 0 ]] || printf 'bad digest\n' >"$5"
    return 0
  fi
  cp "${fixture}/archive.tar.gz" "$5"
}
install() {
  [[ "${installer_fails:-0}" == 0 ]] || return 1
  command install "$@"
}
codesign() { echo codesign >>"$calls"; }

install_dir="${HOME}/.local/share/codebase-memory-mcp"
stamp="${install_dir}/.version"

install_codebase_memory_mcp

[[ "$(cat "$stamp")" == 0.11.0 ]]
grep -F -- 'releases/download/v0.11.0/codebase-memory-mcp-linux-amd64-portable.tar.gz' "$calls"
grep -F -- 'releases/download/v0.11.0/checksums.txt' "$calls"
[[ "$(wc -l <"$calls")" -eq 2 ]]

install_codebase_memory_mcp

[[ "$(wc -l <"$calls")" -eq 2 ]]

printf 'old\n' >"$stamp"
installer_fails=1

if (install_codebase_memory_mcp); then
  echo 'Expected installer failure' >&2
  exit 1
fi

[[ "$(cat "$stamp")" == old ]]
installer_fails=0
download_fails=0
checksum_invalid=1

if (install_codebase_memory_mcp); then
  echo 'Expected checksum failure' >&2
  exit 1
fi

[[ "$(cat "$stamp")" == old ]]
checksum_invalid=0

for platform in Darwin:arm64 Darwin:x86_64 Linux:arm64 Linux:aarch64 Linux:amd64 Linux:x86_64; do
  fake_os="${platform%:*}"
  fake_arch="${platform#*:}"
  rm -f "$stamp"
  : >"$calls"

  install_codebase_memory_mcp

  [[ "$(cat "$stamp")" == 0.11.0 ]]
  if [[ "$fake_os" == Darwin ]]; then
    grep -qx codesign "$calls"
  elif grep -qx codesign "$calls"; then
    echo 'Linux must not invoke codesign' >&2
    exit 1
  fi
done
printf 'old\n' >"$stamp"
fake_os=unsupported

if (install_codebase_memory_mcp); then
  echo 'Expected unsupported OS failure' >&2
  exit 1
fi

fake_os=Linux
fake_arch=unsupported

if (install_codebase_memory_mcp); then
  echo 'Expected unsupported architecture failure' >&2
  exit 1
fi
installer_fails=0
fake_arch=x86_64
download_fails=1

if (install_codebase_memory_mcp); then
  echo 'Expected download failure' >&2
  exit 1
fi

[[ "$(cat "$stamp")" == old ]]

entry="$(jq -c '.mcpServers["codebase-memory-mcp"]' "${TEMPLATE_DIR}/mcp_config.template.json")"
expected="{\"command\":\"\${HOME}/.local/share/codebase-memory-mcp/codebase-memory-mcp\",\"args\":[]}"
[[ "$entry" == "$expected" ]]

get_secret() { printf ''; }
gh() { return 1; }

sync_mcp_config
uv run --no-project --with mcp==1.1.2 python "${repo_dir}/tests/verify_mcp.py" --configs-only

install_codebase_memory_mcp() { echo codebase >>"$calls"; }
install_github_mcp_server() { echo github >>"$calls"; }
install_terraform_mcp_server() { echo terraform >>"$calls"; }
install_repomix() { echo repomix >>"$calls"; }
sync_ssh_profiles() { :; }
sync_docker_profiles() { :; }
sync_k3s_cluster() { echo k3s >>"$calls"; }
sync_memory_file() { :; }
sync_mcp_config() { :; }
sync_skills_and_instructions() { :; }
opencode() { :; }

: >"$calls"

(main --configs-only)

[[ ! -s "$calls" ]]

(main --codebase-memory-only)

[[ "$(cat "$calls")" == codebase ]]
: >"$calls"

(main)

[[ "$(cat "$calls")" == $'codebase\ngithub\nterraform\nrepomix\nk3s' ]]
echo 'MCP setup checks passed'
