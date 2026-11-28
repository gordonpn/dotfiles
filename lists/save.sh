#!/bin/bash
pnpm_marker="/node_modules/.pnpm/"

brewfile=$(mktemp ./Brewfile.XXXXXX) || exit 1
trap 'rm -f "$brewfile"' EXIT
(set -o pipefail; brew bundle dump --all --file=- | sed -E '/^cask "(homebrew\/cask\/)?docker(-desktop)?"/d') >"$brewfile" || exit 1
mv -f "$brewfile" Brewfile || exit 1

npm root -g
npm ls -g --depth=0 --parseable | grep -o 'node_modules/.*$' | sed 's:node_modules/::g' >npm-global
pnpm ls -g --parseable --depth 0 | grep -i "$pnpm_marker" | awk -F"$pnpm_marker" '{print $2}' | awk -F'@' '{print $1}' >pnpm-global
