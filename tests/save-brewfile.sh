#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

brew() {
    [[ "$*" == 'bundle dump --all --file=-' ]] || return 1
    if [[ ${FAIL_DUMP:-0} == 1 ]]; then
        sed -n '1p' "$SAVE_FIXTURES/Brewfile.input"
        return 1
    fi
    cat "$SAVE_FIXTURES/Brewfile.input"
}
npm() { printf '%s\n' '/stub/node_modules/example'; }
pnpm() { printf '%s\n' '/stub/node_modules/.pnpm/example@1.0.0'; }
export -f brew npm pnpm
export SAVE_FIXTURES="$repo/tests/fixtures/save-brewfile"

cp "$SAVE_FIXTURES/Brewfile.expected" Brewfile
bash "$repo/lists/save.sh"
diff -u "$SAVE_FIXTURES/Brewfile.expected" Brewfile
if FAIL_DUMP=1 bash "$repo/lists/save.sh"; then
    echo 'Expected the save to fail when Homebrew fails' >&2
    exit 1
fi
diff -u "$SAVE_FIXTURES/Brewfile.expected" Brewfile
