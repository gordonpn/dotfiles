#!/usr/bin/env bash
# shellcheck disable=SC2088
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_dir}/scripts/deepseek-analyze.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

unset DELEGATE_SKILL_SCRIPT MOCK_DELEGATE_EXIT MOCK_OUTPUT MOCK_STDERR OPENCODE_MODEL
export HOME="${tmp_dir}/home"
mkdir -p "$HOME"

export MOCK_LOG="${tmp_dir}/delegate_calls.log"
default_model="opencode/deepseek-v4.1-flash-free"

assert_failure() {
  local expected_status=$1
  local expected_err_substr=$2
  shift 2
  : >"${MOCK_LOG}"
  set +e
  local out_file="${tmp_dir}/assert_stdout" err_file="${tmp_dir}/assert_stderr"
  "$@" >"${out_file}" 2>"${err_file}"
  local status=$?
  set -e
  local err
  err="$(cat "${err_file}")"
  if [[ "$status" -ne "$expected_status" ]]; then
    echo "Command '$*' expected exit $expected_status, got $status (stderr: $err, stdout: $(cat "${out_file}"))" >&2
    exit 1
  fi
  if [[ -s "${out_file}" ]]; then
    echo "Command '$*' unexpectedly emitted stdout on failure: $(cat "${out_file}")" >&2
    exit 1
  fi
  if [[ -s "${MOCK_LOG}" ]]; then
    echo "Command '$*' unexpectedly invoked the delegate" >&2
    exit 1
  fi
  if [[ -n "$expected_err_substr" && "$err" != *"$expected_err_substr"* ]]; then
    echo "Command '$*' stderr did not contain '$expected_err_substr', got: $err" >&2
    exit 1
  fi
}

assert_success() {
  : >"${MOCK_LOG}"
  local out_file="${tmp_dir}/assert_success_stdout"
  local err_file="${tmp_dir}/assert_success_stderr"
  set +e
  "$@" >"${out_file}" 2>"${err_file}"
  local status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    echo "Command '$*' failed with exit $status (stderr: $(cat "${err_file}"), stdout: $(cat "${out_file}"))" >&2
    exit 1
  fi
  if [[ -s "${err_file}" ]]; then
    echo "Command '$*' emitted unexpected stderr on success: $(cat "${err_file}")" >&2
    exit 1
  fi
  if [[ -s "${out_file}" ]]; then
    echo "Command '$*' emitted unexpected stdout on success: $(cat "${out_file}")" >&2
    exit 1
  fi
}

assert_delegate_call() {
  local marker=$1
  local model=$2
  local task=$3
  if [[ ! -f "${MOCK_LOG}" ]]; then
    echo "Delegate script was not invoked (missing ${MOCK_LOG})" >&2
    exit 1
  fi
  local -a expected_args=(
    "--agent"
    "opencode"
    "--mode"
    "plan"
    "--model"
    "${model}"
    "--task"
    "${task}"
  )
  local expected
  expected="--- ${marker} ---"$'\n'"${#expected_args[@]}"
  for arg in "${expected_args[@]}"; do
    expected+=$'\n'"$(printf '%q' "$arg")"
  done
  local actual
  actual="$(cat "${MOCK_LOG}")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Delegation call mismatch: expected:" >&2
    printf '%s\n' "$expected" >&2
    echo "got:" >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi
  : >"${MOCK_LOG}"
}

write_mock_delegate() {
  local target_path=$1
  local marker=$2
  [[ "${marker}" =~ ^[A-Za-z0-9_]+$ ]] || { echo "invalid mock marker: ${marker}" >&2; return 1; }
  sed "s/__MARKER__/${marker}/g" >"${target_path}" <<'EOF'
#!/usr/bin/env bash
echo "--- __MARKER__ ---" >>"${MOCK_LOG}"
echo "$#" >>"${MOCK_LOG}"
for arg in "$@"; do
  printf '%q\n' "$arg" >>"${MOCK_LOG}"
done
if [[ -n "${MOCK_STDERR:-}" ]]; then
  printf '%s\n' "${MOCK_STDERR}" >&2
fi
if [[ -n "${MOCK_OUTPUT:-}" ]]; then
  printf '%s\n' "${MOCK_OUTPUT}"
fi
exit "${MOCK_DELEGATE_EXIT:-0}"
EOF
  chmod 0755 "${target_path}"
}

# Test 1: Empty, whitespace, tab, or newline task exits 2 with usage on stderr (precedence over HOME/script checks)
assert_failure 2 "Usage:" "$script"
assert_failure 2 "Usage:" "$script" ""
assert_failure 2 "Usage:" "$script" "   "
assert_failure 2 "Usage:" "$script" " " "  "
assert_failure 2 "Usage:" "$script" $'\t  \n'
assert_failure 2 "Usage:" env -u HOME "$script"
assert_failure 2 "Usage:" env -u HOME "$script" ""
assert_failure 2 "Usage:" env -u HOME "$script" "   "
assert_failure 2 "Usage:" env DELEGATE_SKILL_SCRIPT="${tmp_dir}/absent" "$script"
assert_failure 2 "Usage:" env -u HOME DELEGATE_SKILL_SCRIPT="   " "$script"

# Test 2: Unset or empty HOME reports HOME error on stderr and exits 1
assert_failure 1 "HOME is not set" env -u HOME "$script" "task"
assert_failure 1 "HOME is not set" env HOME= "$script" "task"

# Test 3: Missing skill script exits 1 with not found on stderr
assert_failure 1 "delegate skill script not found" "$script" "task"

# Test 4: Non-executable or non-readable skill scripts exit 1 with descriptive error
skill_dir="${HOME}/.agents/skills/delegate-coding-agents/scripts"
mkdir -p "$skill_dir"
touch "${skill_dir}/delegate.sh"
chmod 0644 "${skill_dir}/delegate.sh"
assert_failure 1 "delegate skill script is not executable" "$script" "task"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  chmod 0311 "${skill_dir}/delegate.sh"
  assert_failure 1 "delegate skill script is not readable" "$script" "task"
else
  echo "Notice: running as root; skipping unreadable file test (root bypasses mode 0311 read restrictions)" >&2
fi

# Shared mock fixtures
write_mock_delegate "${skill_dir}/delegate.sh" "CALL"
custom_script_with_space="${tmp_dir}/custom delegate script.sh"
write_mock_delegate "${custom_script_with_space}" "CUSTOM"

# Test 5: Successful delegation forwarding with exact shape, single invocation, and clean stdout
assert_success env -u OPENCODE_MODEL "$script" multi word task description
assert_delegate_call "CALL" "${default_model}" "multi word task description"

# Test 6: Multi-argument joining with spaces
assert_success env -u OPENCODE_MODEL "$script" first second third
assert_delegate_call "CALL" "${default_model}" "first second third"

# Test 7: Multi-line task preserves embedded and trailing newlines
assert_success env -u OPENCODE_MODEL "$script" $'line one\nline two'
assert_delegate_call "CALL" "${default_model}" $'line one\nline two'

assert_success env -u OPENCODE_MODEL "$script" $'line one\nline two\n'
assert_delegate_call "CALL" "${default_model}" $'line one\nline two\n'

# Test 8: Metacharacters, globs, quotes, leading dashes, format strings, and whitespace fidelity
# shellcheck disable=SC2016
metachar_task='--flag-prefix "quotes" $HOME `whoami` * \ ; && | %s %d %%'
assert_success env OPENCODE_MODEL="custom/model-v1" "$script" "${metachar_task}"
assert_delegate_call "CALL" "custom/model-v1" "${metachar_task}"

whitespace_task=$'  leading and  repeated  trailing  '
assert_success env OPENCODE_MODEL="custom/model-v1" "$script" "${whitespace_task}"
assert_delegate_call "CALL" "custom/model-v1" "${whitespace_task}"

# Test 9: Empty or whitespace-only OPENCODE_MODEL falls back to default model, and trims whitespace
assert_success env OPENCODE_MODEL="" "$script" "fallback model task"
assert_delegate_call "CALL" "${default_model}" "fallback model task"

assert_success env OPENCODE_MODEL="   " "$script" "whitespace model task"
assert_delegate_call "CALL" "${default_model}" "whitespace model task"

assert_success env OPENCODE_MODEL=$'\t' "$script" "tab model task"
assert_delegate_call "CALL" "${default_model}" "tab model task"

assert_success env OPENCODE_MODEL=$'\n' "$script" "newline model task"
assert_delegate_call "CALL" "${default_model}" "newline model task"

assert_success env OPENCODE_MODEL="  custom/trimmed-model  " "$script" "trimmed model task"
assert_delegate_call "CALL" "custom/trimmed-model" "trimmed model task"

# shellcheck disable=SC2016
special_model='custom/model v1 $HOME `id` *'
assert_success env OPENCODE_MODEL="${special_model}" "$script" "model with special characters"
assert_delegate_call "CALL" "${special_model}" "model with special characters"

# Test 10: Output, stderr, and exit code propagation from delegate script (byte-for-byte stream verification)
# Failure path (exit 42):
: >"${MOCK_LOG}"
set +e
MOCK_OUTPUT="mock review output" MOCK_STDERR="mock delegate warning" MOCK_DELEGATE_EXIT=42 env -u OPENCODE_MODEL "$script" "propagation test" >"${tmp_dir}/propagation_stdout" 2>"${tmp_dir}/propagation_stderr"
status=$?
set -e
if [[ "$status" -ne 42 ]]; then
  echo "Expected exit 42 from delegate, got $status" >&2
  exit 1
fi
printf 'mock review output\n' >"${tmp_dir}/expected_stdout"
printf 'mock delegate warning\n' >"${tmp_dir}/expected_stderr"
if ! cmp -s "${tmp_dir}/propagation_stdout" "${tmp_dir}/expected_stdout"; then
  echo "Delegate stdout byte mismatch" >&2
  diff -u "${tmp_dir}/expected_stdout" "${tmp_dir}/propagation_stdout" >&2
  exit 1
fi
if ! cmp -s "${tmp_dir}/propagation_stderr" "${tmp_dir}/expected_stderr"; then
  echo "Delegate stderr byte mismatch" >&2
  diff -u "${tmp_dir}/expected_stderr" "${tmp_dir}/propagation_stderr" >&2
  exit 1
fi
assert_delegate_call "CALL" "${default_model}" "propagation test"

# Success path (exit 0): streams must be forwarded unchanged as well
: >"${MOCK_LOG}"
set +e
MOCK_OUTPUT="mock success output" MOCK_STDERR="mock success warning" env -u OPENCODE_MODEL "$script" "success propagation" >"${tmp_dir}/success_stdout" 2>"${tmp_dir}/success_stderr"
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  echo "Expected exit 0 from delegate, got $status" >&2
  exit 1
fi
printf 'mock success output\n' >"${tmp_dir}/expected_success_stdout"
printf 'mock success warning\n' >"${tmp_dir}/expected_success_stderr"
if ! cmp -s "${tmp_dir}/success_stdout" "${tmp_dir}/expected_success_stdout"; then
  echo "Delegate success stdout byte mismatch" >&2
  diff -u "${tmp_dir}/expected_success_stdout" "${tmp_dir}/success_stdout" >&2
  exit 1
fi
if ! cmp -s "${tmp_dir}/success_stderr" "${tmp_dir}/expected_success_stderr"; then
  echo "Delegate success stderr byte mismatch" >&2
  diff -u "${tmp_dir}/expected_success_stderr" "${tmp_dir}/success_stderr" >&2
  exit 1
fi
assert_delegate_call "CALL" "${default_model}" "success propagation"

# Test 11: Custom DELEGATE_SKILL_SCRIPT validation
assert_failure 1 "must be an absolute path or contain a '/'" env DELEGATE_SKILL_SCRIPT="no_slash_binary" "$script" "task"
assert_failure 1 "delegate skill script not found" env DELEGATE_SKILL_SCRIPT="${tmp_dir}/absent_delegate.sh" "$script" "task"
assert_failure 1 "delegate skill script is not a regular file" env DELEGATE_SKILL_SCRIPT="${tmp_dir}" "$script" "task"

ln -s "${tmp_dir}/missing_target.sh" "${tmp_dir}/dangling_delegate.sh"
assert_failure 1 "delegate skill script is a dangling symlink" env DELEGATE_SKILL_SCRIPT="${tmp_dir}/dangling_delegate.sh" "$script" "task"

touch "${tmp_dir}/non_exec_delegate.sh"
chmod 0644 "${tmp_dir}/non_exec_delegate.sh"
assert_failure 1 "delegate skill script is not executable" env DELEGATE_SKILL_SCRIPT="${tmp_dir}/non_exec_delegate.sh" "$script" "task"

# Test 12: Custom DELEGATE_SKILL_SCRIPT override execution, path with spaces, and trimming
assert_success env -u OPENCODE_MODEL DELEGATE_SKILL_SCRIPT="  ${custom_script_with_space}  " "$script" "custom script task"
assert_delegate_call "CUSTOM" "${default_model}" "custom script task"

assert_success env -u OPENCODE_MODEL DELEGATE_SKILL_SCRIPT="" "$script" "empty override task"
assert_delegate_call "CALL" "${default_model}" "empty override task"

assert_success env -u OPENCODE_MODEL DELEGATE_SKILL_SCRIPT="   " "$script" "whitespace override task"
assert_delegate_call "CALL" "${default_model}" "whitespace override task"

# Test 13: Custom DELEGATE_SKILL_SCRIPT functions when HOME is unset
assert_success env -u HOME -u OPENCODE_MODEL DELEGATE_SKILL_SCRIPT="${custom_script_with_space}" "$script" "task without HOME"
assert_delegate_call "CUSTOM" "${default_model}" "task without HOME"

# Test 14: Custom DELEGATE_SKILL_SCRIPT accepts relative path containing '/'
(cd "${tmp_dir}" && assert_success env -u OPENCODE_MODEL DELEGATE_SKILL_SCRIPT="./custom delegate script.sh" "$script" "relative path task")
assert_delegate_call "CUSTOM" "${default_model}" "relative path task"

# Test 15: Custom DELEGATE_SKILL_SCRIPT tilde handling
assert_failure 1 "HOME is not set; cannot expand tilde in DELEGATE_SKILL_SCRIPT" env -u HOME DELEGATE_SKILL_SCRIPT="~" "$script" "task"
assert_failure 1 "HOME is not set; cannot expand tilde in DELEGATE_SKILL_SCRIPT" env -u HOME DELEGATE_SKILL_SCRIPT="~/tilde_delegate/delegate.sh" "$script" "task"
assert_failure 1 "HOME is not set; cannot expand tilde in DELEGATE_SKILL_SCRIPT" env HOME= DELEGATE_SKILL_SCRIPT="~/tilde_delegate/delegate.sh" "$script" "task"
assert_failure 1 "user-specific tilde paths (~user/...) are not supported" env DELEGATE_SKILL_SCRIPT="~otheruser/delegate.sh" "$script" "task"
assert_failure 1 "delegate skill script is not a regular file" env DELEGATE_SKILL_SCRIPT="~" "$script" "task"

tilde_script_dir="${HOME}/tilde_delegate"
mkdir -p "${tilde_script_dir}"
write_mock_delegate "${tilde_script_dir}/delegate.sh" "TILDE"
assert_success env -u OPENCODE_MODEL DELEGATE_SKILL_SCRIPT="~/tilde_delegate/delegate.sh" "$script" "tilde script task"
assert_delegate_call "TILDE" "${default_model}" "tilde script task"

# Test 16: Explicit help requests (-h, --help) exit 0 with usage on stdout and empty stderr
assert_help_success() {
  local out status
  set +e
  out="$("$@" 2>"${tmp_dir}/help_stderr")"
  status=$?
  set -e
  if [[ "$status" -ne 0 || "$out" != *"Usage:"* || "$out" != *"${default_model}"* || "$out" == *"@DEFAULT_MODEL@"* || -s "${tmp_dir}/help_stderr" ]]; then
    echo "Expected exit 0 and clean usage on stdout for '$*', got exit $status (stderr: $(cat "${tmp_dir}/help_stderr")): $out" >&2
    exit 1
  fi
}

: >"${MOCK_LOG}"
assert_help_success "$script" -h
assert_help_success "$script" --help

# Help request short-circuits HOME and skill script validation
assert_help_success env -u HOME "$script" --help
assert_help_success env DELEGATE_SKILL_SCRIPT=no_slash "$script" -h

if [[ -s "${MOCK_LOG}" ]]; then
  echo "Help request unexpectedly invoked the delegate" >&2
  exit 1
fi

# Test 17: Multi-word tasks with -h/--help and '--' escaping
# -h or --help as first argument displays help even with trailing words
assert_help_success "$script" -h and more words

# Literal leading dashes escaped with '--' are forwarded as tasks
assert_success env -u OPENCODE_MODEL "$script" -- -h
assert_delegate_call "CALL" "${default_model}" "-h"

assert_success env -u OPENCODE_MODEL "$script" -- -h and more words
assert_delegate_call "CALL" "${default_model}" "-h and more words"

# -h appearing after the first argument is forwarded as part of the task
assert_success env -u OPENCODE_MODEL "$script" task with -h embedded
assert_delegate_call "CALL" "${default_model}" "task with -h embedded"

assert_failure 2 "Usage:" "$script" --
assert_failure 2 "Usage:" "$script" -- "   "

echo "deepseek-analyze checks passed"
