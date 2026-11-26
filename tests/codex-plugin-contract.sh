#!/usr/bin/env bash
# Contract tests for scripts/verify-codex-plugin.sh.

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verifier="${repo_dir}/scripts/verify-codex-plugin.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

write_fixture() {
  local dest="$1"
  local omit="${2:-}"
  local bad_syntax="${3:-0}"

  local subcommands=("setup" "review" "adversarial-review" "task" "status" "result" "cancel")
  local cmd

  {
    printf '%s\n' 'function parseFlags(tokens, valueFlags = []) { return { flags: {}, rest: tokens }; }'
    printf '%s\n' 'function run(command, tokens) {'
    printf '%s\n' '  process.stdout.write("codex");'

    if [[ "${omit}" != "--base" ]]; then
      printf '%s\n' '  const reviewParsed = parseFlags(tokens, ["base", "scope", "model"]);'
      printf '%s\n' '  const baseRef = reviewParsed.flags.base || null;'
      printf '%s\n' '  void baseRef;'
    else
      printf '%s\n' '  const reviewParsed = parseFlags(tokens, ["scope", "model"]);'
      printf '%s\n' '  void reviewParsed;'
    fi

    printf '%s\n' '  const { flags } = parseFlags(tokens, ["model"]);'
    if [[ "${omit}" != "--background" ]]; then
      printf '%s\n' '  const background = Boolean(flags.background);'
      printf '%s\n' '  void background;'
    fi
    if [[ "${omit}" != "--write" ]]; then
      printf '%s\n' '  const write = Boolean(flags.write);'
      printf '%s\n' '  void write;'
    fi
    if [[ "${omit}" != "--resume-last" ]]; then
      printf '%s\n' '  const resumeLast = Boolean(flags["resume-last"]);'
      printf '%s\n' '  void resumeLast;'
    fi

    printf '%s\n' '  switch (command) {'
    for cmd in "${subcommands[@]}"; do
      if [[ "${cmd}" != "${omit}" ]]; then
        printf '    case "%s":\n      return 0;\n' "${cmd}"
      fi
    done
    printf '%s\n' '    default:'
    printf '%s\n' '      return 1;'
    printf '%s\n' '  }'
    printf '%s\n' '}'

    if [[ "${bad_syntax}" -eq 1 ]]; then
      printf '%s\n' 'const broken = ('
    fi
  } >"${dest}"
}

assert_fails() {
  local status=0
  "$@" >"${tmp_dir}/stdout" 2>"${tmp_dir}/stderr" || status=$?
  if [[ "${status}" -eq 0 ]]; then
    printf 'Expected failure but exited 0: %s\n' "$*" >&2
    exit 1
  fi
  if [[ ! -s "${tmp_dir}/stderr" ]]; then
    printf 'Expected non-empty stderr, got empty stderr for: %s\n' "$*" >&2
    exit 1
  fi
}

assert_fails_with() {
  local expected_err="$1"
  shift
  assert_fails "$@"
  if ! grep -Fq "${expected_err}" "${tmp_dir}/stderr"; then
    printf 'Expected stderr to contain %q, got:\n%s\n' "${expected_err}" "$(cat "${tmp_dir}/stderr")" >&2
    exit 1
  fi
}

# Case 1: Valid fixture runner passes.
valid_runner="${tmp_dir}/valid-runner.mjs"
write_fixture "${valid_runner}"
bash "${verifier}" --runner "${valid_runner}" >"${tmp_dir}/valid.out"
grep -Fq "Codex plugin runner syntax is valid and expected source symbols were found" "${tmp_dir}/valid.out"

# A source-only fixture can contain every expected name without exposing a CLI.
symbol_only_runner="${tmp_dir}/symbol-only.mjs"
cat >"${symbol_only_runner}" <<'EOF'
const names = ["setup", "review", "adversarial-review", "task", "status", "result", "cancel",
               "--base", "--resume-last", "--write", "--background"];
EOF
bash "${verifier}" --runner "${symbol_only_runner}" >"${tmp_dir}/symbol-only.out"
grep -Fxq "CLI behavior was not verified." "${tmp_dir}/symbol-only.out"

# Case 2: CODEX_PLUGIN_RUNNER environment override is honored.
CODEX_PLUGIN_RUNNER="${valid_runner}" bash "${verifier}" >"${tmp_dir}/env.out"
grep -Fq "Codex plugin runner syntax is valid and expected source symbols were found" "${tmp_dir}/env.out"

# Case 3: Missing any required subcommand fails (including review when adversarial-review exists).
for missing_cmd in setup review adversarial-review task status result cancel; do
  fixture="${tmp_dir}/missing-${missing_cmd}.mjs"
  write_fixture "${fixture}" "${missing_cmd}"
  assert_fails_with "missing required subcommand in ${fixture}: ${missing_cmd}" \
    bash "${verifier}" --runner "${fixture}"
done

# Case 4: Missing any required flag fails (including --write despite process.stdout.write).
for missing_flag in --base --resume-last --write --background; do
  fixture="${tmp_dir}/missing-${missing_flag#--}.mjs"
  write_fixture "${fixture}" "${missing_flag}"
  assert_fails_with "missing required flag in ${fixture}: ${missing_flag}" \
    bash "${verifier}" --runner "${fixture}"
done

# Case 5: Syntax error in runner fails with non-zero exit and non-empty stderr when node is available.
if command -v node >/dev/null 2>&1; then
  bad_syntax_runner="${tmp_dir}/bad-syntax.mjs"
  write_fixture "${bad_syntax_runner}" "" 1
  assert_fails bash "${verifier}" --runner "${bad_syntax_runner}"
fi

# Case 6: Missing runner fails without --allow-missing and exits 0 with --allow-missing.
missing_runner="${tmp_dir}/does-not-exist/codex-runner.mjs"
assert_fails_with "Codex plugin runner not found" bash "${verifier}" --runner "${missing_runner}"

bash "${verifier}" --runner "${missing_runner}" --allow-missing >"${tmp_dir}/allow-missing.out"
grep -Fq "fall back to delegate.sh" "${tmp_dir}/allow-missing.out"

# Case 7: Validates the host's installed plugin when present (environment-dependent; skipped if absent).
local_runner="${HOME}/.gemini/config/plugins/codex/scripts/codex-runner.mjs"
if [[ -f "${local_runner}" ]]; then
  bash "${verifier}" --runner "${local_runner}" >"${tmp_dir}/local.out"
  grep -Fq "Codex plugin runner syntax is valid and expected source symbols were found" "${tmp_dir}/local.out"
else
  printf 'Notice: local Codex plugin runner absent at %s; skipping live plugin check.\n' "${local_runner}"
fi

# Case 8: Missing node on PATH fails non-zero when verifying a present runner.
no_node_bin="${tmp_dir}/no-node-bin"
mkdir -p "${no_node_bin}"
ln -s "$(command -v bash)" "${no_node_bin}/bash"
ln -s "$(command -v grep)" "${no_node_bin}/grep"
assert_fails_with "Error: node is required to verify ${valid_runner} but was not found on PATH." \
  env PATH="${no_node_bin}" bash "${verifier}" --runner "${valid_runner}"

echo "codex-plugin-contract checks passed"
