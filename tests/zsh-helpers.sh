#!/usr/bin/env bash
# Tests for dotfiles/.zsh-helpers

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helpers="${repo_dir}/dotfiles/.zsh-helpers"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/home" "${tmp}/stubs" "${tmp}/eza-stub" "${tmp}/work"
base_path="${tmp}/stubs:/usr/bin:/bin"
zsh_bin="$(command -v zsh)"

pass() { printf 'PASS: %s\n' "$1"; }
fail() {
  printf 'FAIL: %s\n%s\n' "$1" "$2" >&2
  exit 1
}

# Source the helpers in a clean zsh with the given PATH and cwd, then run a script.
run_zsh() {
  local path="$1" dir="$2" script="$3"
  (cd "${dir}" && env -i HOME="${tmp}/home" PATH="${path}" "${zsh_bin}" -f -c "source '${helpers}'; ${script}" 2>&1) || true
}

assert_contains() {
  local test_name="$1" needle="$2" actual="$3"
  [[ "${actual}" == *"${needle}"* ]] || fail "${test_name}" "expected to contain: ${needle}
actual: ${actual}"
}

assert_not_contains() {
  local test_name="$1" needle="$2" actual="$3"
  [[ "${actual}" != *"${needle}"* ]] || fail "${test_name}" "expected not to contain: ${needle}
actual: ${actual}"
}

make_stub() {
  local path="$1" body="$2"
  printf '#!/bin/sh\n%s\n' "${body}" >"${path}"
  chmod +x "${path}"
}

# shellcheck disable=SC2016 # stub bodies expand their variables when they run
{
  make_stub "${tmp}/stubs/npm" 'echo "npm-stub $*"'
  make_stub "${tmp}/stubs/repomix" 'echo "repomix $*"
while [ $# -gt 0 ]; do [ "$1" = -o ] && : >"$2"; shift; done'
  make_stub "${tmp}/eza-stub/eza" 'echo eza'
}

# A PATH with only what the helpers need here, and no eza even where /usr/bin has one.
mkdir -p "${tmp}/minbin"
for t in basename dirname tr mv uuidgen uname cut; do ln -s "$(command -v "${t}")" "${tmp}/minbin/${t}"; done

# 1. Exactly the expected helpers are defined, and the macOS ones only on macOS.
shared='md rd vsc ide reload lg zshrc log_to_file timezsh palette printc branch-delete delete-old-branches npm random_rename antidote_hard_reset pack'
macos='restartcal dns_flush clear_cache check_uptime restart_firefox'
if [[ "$(uname)" == "Darwin" ]]; then
  defined="${shared} ${macos}" undefined=''
else
  defined="${shared}" undefined="${macos}"
fi
actual=$(run_zsh "${tmp}/minbin" "${tmp}/work" "for n in ${defined} ${undefined} lt lta; do print -- \"\$n \$(whence -w \$n | cut -d' ' -f2)\"; done")
expected=''
for n in ${defined}; do
  case "${n}" in
    md | rd | vsc | ide | reload | lg | zshrc | log_to_file) expected+="${n} alias"$'\n' ;;
    *) expected+="${n} function"$'\n' ;;
  esac
done
for n in ${undefined} lt lta; do expected+="${n} none"$'\n'; done
[[ "${actual}"$'\n' == "${expected}" ]] || fail "defines exactly the expected helpers" "expected:
${expected}actual:
${actual}"
pass "defines exactly the expected helpers"

# 2. lt and lta exist only where eza does.
actual=$(run_zsh "${tmp}/eza-stub:${base_path}" "${tmp}/work" 'whence -w lt lta')
[[ "${actual}" == $'lt: alias\nlta: alias' ]] || fail "lt and lta follow eza" "${actual}"
pass "lt and lta follow eza"

# 3. branch-delete without arguments returns instead of exiting the shell.
actual=$(run_zsh "${base_path}" "${tmp}/work" 'branch-delete; print -- "status=$? alive"')
assert_contains "branch-delete usage keeps the shell" "Usage:" "${actual}"
assert_contains "branch-delete usage keeps the shell" "status=1 alive" "${actual}"
pass "branch-delete usage keeps the shell"
actual=$(run_zsh "${base_path}" "${tmp}/work" 'branch-delete ""; print -- "status=$?"')
assert_contains "branch-delete rejects an empty substring" "Usage:" "${actual}"
assert_contains "branch-delete rejects an empty substring" "status=1" "${actual}"
assert_not_contains "branch-delete rejects an empty substring" "Deleting" "${actual}"
pass "branch-delete rejects an empty substring"

# 4. timezsh needs no external time binary.
actual=$(run_zsh "${base_path}" "${tmp}/work" 'timezsh true; print -- "status=$?"')
assert_contains "timezsh runs with the shell's time" "status=0" "${actual}"
assert_not_contains "timezsh runs with the shell's time" "no such file" "${actual}"
pass "timezsh runs with the shell's time"

# 5. npm refuses in a pnpm project and passes through elsewhere.
mkdir -p "${tmp}/pnpm-project"
: >"${tmp}/pnpm-project/pnpm-lock.yaml"
actual=$(run_zsh "${base_path}" "${tmp}/pnpm-project" 'npm install')
assert_contains "npm refuses in a pnpm project" "Please use pnpm" "${actual}"
assert_not_contains "npm refuses in a pnpm project" "npm-stub" "${actual}"
actual=$(run_zsh "${base_path}" "${tmp}/pnpm-project" 'npm install; print -- "status=$?"')
assert_contains "npm refuses in a pnpm project" "status=1" "${actual}"
pass "npm refuses in a pnpm project"
actual=$(run_zsh "${base_path}" "${tmp}/work" 'npm install left-pad')
[[ "${actual}" == "npm-stub install left-pad" ]] || fail "npm passes through elsewhere" "${actual}"
pass "npm passes through elsewhere"
actual=$(run_zsh "${base_path}" "${tmp}/pnpm-project" 'npm completion')
[[ "${actual}" == "npm-stub completion" ]] || fail "npm completion passes through in a pnpm project" "${actual}"
pass "npm completion passes through in a pnpm project"

# 6. pack names the output after the repo and maps the style.
actual=$(run_zsh "${base_path}" "${tmp}/work" 'pack https://github.com/owner/repo.name.git md; print -- "status=$?"')
assert_contains "pack names output owner-repo" "repomix --remote https://github.com/owner/repo.name.git --style markdown --compress -o owner-repo.name.md" "${actual}"
assert_contains "pack names output owner-repo" "status=0" "${actual}"
[[ -f "${tmp}/work/owner-repo.name.md" ]] || fail "pack names output owner-repo" "no owner-repo.name.md written"
pass "pack names output owner-repo"
actual=$(run_zsh "${base_path}" "${tmp}/work" 'pack https://github.com/owner/repo bogus; print -- "status=$?"')
assert_contains "pack rejects an unknown style" "unknown style 'bogus'" "${actual}"
assert_contains "pack rejects an unknown style" "status=2" "${actual}"
pass "pack rejects an unknown style"
# shellcheck disable=SC2016 # expands inside the zsh under test
actual=$(run_zsh "/usr/bin:/bin" "${tmp}/work" 'pnpx() { print -- "pnpx-fn $*"; }; pack https://github.com/owner/repo; print -- "status=$?"')
assert_contains "pack uses a pnpx function" "pnpx-fn repomix@latest --remote https://github.com/owner/repo --style xml --compress -o owner-repo.xml" "${actual}"
assert_contains "pack uses a pnpx function" "status=0" "${actual}"
pass "pack uses a pnpx function"
actual=$(run_zsh "${base_path}" "${tmp}/work" 'pack; print -- "status=$?"')
assert_contains "pack needs a repo" "no repo given and no git origin here" "${actual}"
assert_contains "pack needs a repo" "status=1" "${actual}"
pass "pack needs a repo"

# 7. random_rename only reports by default.
mkdir -p "${tmp}/pdfs/sub" "${tmp}/pdfs/.hidden"
: >"${tmp}/pdfs/a.pdf"
: >"${tmp}/pdfs/sub/b.pdf"
: >"${tmp}/pdfs/.hidden/c.pdf"
mkdir -p "${tmp}/outside"
: >"${tmp}/outside/x.pdf"
ln -s .. "${tmp}/pdfs/sub/up"
ln -s "${tmp}/outside" "${tmp}/pdfs/out"
actual=$(run_zsh "${base_path}" "${tmp}/pdfs" 'random_rename')
assert_not_contains "random_rename dry run" "pdfs/sub/up" "${actual}"
assert_not_contains "random_rename dry run" "x.pdf" "${actual}"
assert_contains "random_rename dry run" "Would rename 'a.pdf'" "${actual}"
assert_contains "random_rename dry run" "Would rename 'b.pdf'" "${actual}"
assert_not_contains "random_rename dry run" ".hidden" "${actual}"
assert_not_contains "random_rename dry run" "'c.pdf'" "${actual}"
[[ -f "${tmp}/pdfs/a.pdf" && -f "${tmp}/pdfs/sub/b.pdf" ]] || fail "random_rename dry run" "files were renamed"
pass "random_rename dry run"

mkdir -p "${tmp}/badgen"
make_stub "${tmp}/badgen/uuidgen" 'exit 1'
make_stub "${tmp}/badgen/exiftool" 'exit 0'
actual=$(run_zsh "${tmp}/badgen:${base_path}" "${tmp}/pdfs" 'random_rename -f; print -- "status=$?"')
assert_contains "random_rename keeps files when uuidgen fails" "uuidgen gave no name" "${actual}"
[[ -f "${tmp}/pdfs/a.pdf" && -f "${tmp}/pdfs/sub/b.pdf" && ! -e "${tmp}/pdfs/.pdf" && ! -e "${tmp}/pdfs/sub/.pdf" ]] ||
  fail "random_rename keeps files when uuidgen fails" "$(find "${tmp}/pdfs" -name '*.pdf')"
pass "random_rename keeps files when uuidgen fails"
mkdir -p "${tmp}/badexif"
make_stub "${tmp}/badexif/exiftool" 'exit 1'
actual=$(run_zsh "${tmp}/badexif:${base_path}" "${tmp}/pdfs" 'random_rename -f; print -- "status=$?"')
assert_contains "random_rename keeps files when exiftool fails" "exiftool failed" "${actual}"
[[ -f "${tmp}/pdfs/a.pdf" && -f "${tmp}/pdfs/sub/b.pdf" ]] || fail "random_rename keeps files when exiftool fails" "$(find "${tmp}/pdfs" -name '*.pdf')"
pass "random_rename keeps files when exiftool fails"
mkdir -p "${tmp}/okexif" "${tmp}/locked"
make_stub "${tmp}/okexif/exiftool" 'exit 0'
: >"${tmp}/locked/d.pdf"
chmod a-w "${tmp}/locked"
actual=$(run_zsh "${tmp}/okexif:${base_path}" "${tmp}/locked" 'random_rename -f; print -- "status=$?"')
chmod u+w "${tmp}/locked"
assert_contains "random_rename -f reports a failed mv" "status=1" "${actual}"
[[ -f "${tmp}/locked/d.pdf" ]] || fail "random_rename -f reports a failed mv" "d.pdf is gone"
pass "random_rename -f reports a failed mv"
actual=$(run_zsh "${tmp}/minbin" "${tmp}/pdfs" 'random_rename -f; print -- "status=$?"')
assert_contains "random_rename -f needs exiftool" "random_rename: needs exiftool" "${actual}"
assert_contains "random_rename -f needs exiftool" "status=1" "${actual}"
[[ -f "${tmp}/pdfs/a.pdf" ]] || fail "random_rename -f needs exiftool" "a.pdf was renamed"
pass "random_rename -f needs exiftool"
actual=$(run_zsh "${base_path}" "${tmp}/pdfs" 'setopt null_glob; random_rename >/dev/null; [[ -o null_glob ]] && print on || print off; unsetopt null_glob; random_rename >/dev/null; [[ -o null_glob ]] && print on || print off')
[[ "${actual}" == $'on\noff' ]] || fail "random_rename keeps the caller's null_glob" "${actual}"
pass "random_rename keeps the caller's null_glob"

# 8. antidote_hard_reset parses its options before touching anything.
actual=$(run_zsh "${base_path}" "${tmp}/work" 'antidote_hard_reset --help; print -- "status=$?"')
assert_contains "antidote_hard_reset help" "Usage: antidote_hard_reset" "${actual}"
assert_contains "antidote_hard_reset help" "status=0" "${actual}"
pass "antidote_hard_reset help"
actual=$(run_zsh "${base_path}" "${tmp}/work" 'antidote_hard_reset --bogus; print -- "status=$?"')
assert_contains "antidote_hard_reset rejects unknown options" "status=2" "${actual}"
pass "antidote_hard_reset rejects unknown options"
for arg in --timeout --timeout= "--timeout --reload" "--timeout abc" --timeout=5x; do
  actual=$(run_zsh "${base_path}" "${tmp}/work" "antidote_hard_reset ${arg}; print -- \"status=\$?\"")
  assert_contains "antidote_hard_reset ${arg} needs a duration" "--timeout needs a duration" "${actual}"
  assert_contains "antidote_hard_reset ${arg} needs a duration" "status=2" "${actual}"
  assert_not_contains "antidote_hard_reset ${arg} needs a duration" "Removing" "${actual}"
  pass "antidote_hard_reset ${arg} needs a duration"
done
actual=$(run_zsh "${tmp}/minbin" "${tmp}/work" 'antidote_hard_reset --timeout 5; print -- "status=$?"')
assert_contains "antidote_hard_reset --timeout needs a timeout tool" "needs timeout or gtimeout" "${actual}"
assert_contains "antidote_hard_reset --timeout needs a timeout tool" "status=2" "${actual}"
assert_not_contains "antidote_hard_reset --timeout needs a timeout tool" "Removing" "${actual}"
pass "antidote_hard_reset --timeout needs a timeout tool"

# 9. delete-old-branches --dry-run picks only branches older than six months.
old_date='2020-01-01T00:00:00Z'
g() { git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=master "$@"; }
old_commit() { GIT_COMMITTER_DATE="${old_date}" GIT_AUTHOR_DATE="${old_date}" g -C "${tmp}/clone" commit -q --allow-empty -m "$1"; }
g init -q --bare "${tmp}/origin.git"
g clone -q "${tmp}/origin.git" "${tmp}/clone" 2>/dev/null
old_commit init
g -C "${tmp}/clone" checkout -q -b old
old_commit old
g -C "${tmp}/clone" checkout -q -b fresh-local master
old_commit fresh-local
g -C "${tmp}/clone" checkout -q -b current master
old_commit current
g -C "${tmp}/clone" checkout -q -b recent master
g -C "${tmp}/clone" commit -q --allow-empty -m recent
g -C "${tmp}/clone" push -q origin --all
g -C "${tmp}/clone" checkout -q fresh-local
g -C "${tmp}/clone" commit -q --allow-empty -m "unpushed work"
g -C "${tmp}/clone" checkout -q current
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'delete-old-branches --dry-run')
assert_contains "delete-old-branches dry run" "Would delete branch: old" "${actual}"
for kept in recent master current fresh-local; do
  assert_not_contains "delete-old-branches dry run" "Would delete branch: ${kept}" "${actual}"
done
assert_contains "delete-old-branches dry run" "Skipping branch: master" "${actual}"
assert_contains "delete-old-branches dry run" "Skipping branch: current" "${actual}"
[[ -n "$(git -C "${tmp}/origin.git" branch --list old)" ]] || fail "delete-old-branches dry run" "old was deleted"
pass "delete-old-branches dry run"
for arg in --help --dryrun; do
  actual=$(run_zsh "${base_path}" "${tmp}/clone" "delete-old-branches ${arg}; print -- \"status=\$?\"")
  assert_contains "delete-old-branches rejects ${arg}" "Usage: delete-old-branches [--dry-run]" "${actual}"
  assert_contains "delete-old-branches rejects ${arg}" "status=2" "${actual}"
  assert_not_contains "delete-old-branches rejects ${arg}" "Deleting" "${actual}"
  pass "delete-old-branches rejects ${arg}"
done
[[ -n "$(git -C "${tmp}/origin.git" branch --list old)" ]] || fail "delete-old-branches rejects bad arguments" "old was deleted"
empty_tree="$(g -C "${tmp}/clone" mktree </dev/null)"
# A remote-tracking ref may name a tree, which git log cannot date.
g -C "${tmp}/clone" update-ref refs/remotes/origin/not-a-commit "${empty_tree}"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'delete-old-branches --dry-run')
assert_contains "delete-old-branches skips an unknown age" "Skipping branch with unknown age: not-a-commit" "${actual}"
assert_not_contains "delete-old-branches skips an unknown age" "Would delete branch: not-a-commit" "${actual}"
pass "delete-old-branches skips an unknown age"
g -C "${tmp}/clone" update-ref -d refs/remotes/origin/not-a-commit
make_stub "${tmp}/origin.git/hooks/pre-receive" 'exit 1'
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'delete-old-branches; print -- "status=$?"')
[[ -n "$(git -C "${tmp}/clone" branch --list old)" ]] || fail "delete-old-branches keeps local when the remote delete fails" "${actual}"
assert_contains "delete-old-branches keeps local when the remote delete fails" "Could not delete old on origin" "${actual}"
assert_contains "delete-old-branches keeps local when the remote delete fails" "status=1" "${actual}"
assert_not_contains "delete-old-branches keeps local when the remote delete fails" "Deleted branches: old" "${actual}"
pass "delete-old-branches keeps local when the remote delete fails"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
[[ -n "$(git -C "${tmp}/clone" branch --list old)" ]] || fail "branch-delete keeps local when the remote delete fails" "${actual}"
assert_contains "branch-delete keeps local when the remote delete fails" "Could not delete old on origin" "${actual}"
assert_contains "branch-delete keeps local when the remote delete fails" "status=1" "${actual}"
assert_not_contains "branch-delete keeps local when the remote delete fails" "Deleted branches: old" "${actual}"
pass "branch-delete keeps local when the remote delete fails"
rm "${tmp}/origin.git/hooks/pre-receive"
for args in "old --dryrun" "old --dry-run extra"; do
  actual=$(run_zsh "${base_path}" "${tmp}/clone" "branch-delete ${args}; print -- \"status=\$?\"")
  assert_contains "branch-delete rejects ${args}" "Usage:" "${actual}"
  assert_contains "branch-delete rejects ${args}" "status=2" "${actual}"
  assert_not_contains "branch-delete rejects ${args}" "Deleting" "${actual}"
  pass "branch-delete rejects ${args}"
done
g -C "${tmp}/clone" checkout -q old
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
g -C "${tmp}/clone" checkout -q current
assert_contains "branch-delete skips the checked-out branch" "Skipping branch: old" "${actual}"
assert_not_contains "branch-delete skips the checked-out branch" "Deleting" "${actual}"
[[ -n "$(git -C "${tmp}/origin.git" branch --list old)" ]] || fail "branch-delete skips the checked-out branch" "old was deleted on origin"
pass "branch-delete skips the checked-out branch"
g -C "${tmp}/clone" checkout -q -b wt-old master
old_commit wt-old
g -C "${tmp}/clone" push -q origin wt-old
g -C "${tmp}/clone" checkout -q current
g -C "${tmp}/clone" worktree add -q "${tmp}/wt" wt-old
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'delete-old-branches; print -- "status=$?"')
assert_contains "delete-old-branches reports a failed local delete" "Could not delete local branch wt-old" "${actual}"
assert_contains "delete-old-branches reports a failed local delete" "status=1" "${actual}"
assert_not_contains "delete-old-branches reports a failed local delete" "Deleted branches: old wt-old" "${actual}"
pass "delete-old-branches reports a failed local delete"
g -C "${tmp}/clone" worktree remove --force "${tmp}/wt"
g -C "${tmp}/clone" checkout -q -B old master
old_commit old
g -C "${tmp}/clone" push -q -f origin old
g -C "${tmp}/clone" checkout -q current
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
[[ -z "$(git -C "${tmp}/clone" branch --list old)" && -z "$(git -C "${tmp}/origin.git" branch --list old)" ]] ||
  fail "branch-delete deletes local and remote" "${actual}"
assert_contains "branch-delete deletes local and remote" "Deleted branches: old" "${actual}"
assert_contains "branch-delete deletes local and remote" "status=0" "${actual}"
pass "branch-delete deletes local and remote"
g -C "${tmp}/clone" remote set-url origin "${tmp}/missing.git"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'delete-old-branches --dry-run; print -- "status=$?"')
assert_contains "delete-old-branches stops when fetch fails" "Fetch failed" "${actual}"
assert_contains "delete-old-branches stops when fetch fails" "status=1" "${actual}"
assert_not_contains "delete-old-branches stops when fetch fails" "Would delete" "${actual}"
pass "delete-old-branches stops when fetch fails"
