#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
fixture="$(cd "$fixture" && pwd -P)"
mkdir -p "$fixture/home" "$fixture/.agents"
cp "$repo_dir/Justfile" "$fixture/"
sed "s|FIXTURE_ROOT|$fixture|g" "$repo_dir/tests/fixtures/ecc-install-state.json" >"$fixture/.agents/ecc-install-state.json"
cp -R "$fixture/.agents" "$fixture/expected"

codex() {
    case "$*" in
        'plugin marketplace list --json') printf '%s\n' '{"marketplaces":[]}' ;;
        'plugin list --json') printf '%s\n' '{"installed":[]}' ;;
        'plugin marketplace add affaan-m/ECC --ref v2.2.3'|'plugin add ecc@ecc')
            printf '%s\n' "$*" >>"$HOME/codex-calls" ;;
        *) return 1 ;;
    esac
}

npx() {
    printf '%s\n' "Unexpected Antigravity package invocation: $*" >&2
    return 1
}

export -f codex npx
export HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/home" CODEX_HOME="$fixture/home"
cd "$fixture"
just --shell bash --shell-arg=-cu setup-ecc
diff -r expected .agents
printf '%s\n' 'plugin marketplace add affaan-m/ECC --ref v2.2.3' 'plugin add ecc@ecc' | diff - "$HOME/codex-calls"
