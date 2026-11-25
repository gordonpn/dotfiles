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
  # shellcheck disable=SC2016 # Expand positional parameters in the child shell.
  (cd "${dir}" && env -i HOME="${tmp}/home" PATH="${path}" "${zsh_bin}" \
    -f -c 'source "$1" || exit; eval "$2"' zsh "${helpers}" "${script}" 2>&1)
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
  make_stub "${tmp}/stubs/uuidgen" 'echo 70000000-0000-4000-8000-000000000000'
  make_stub "${tmp}/stubs/npm" 'echo "npm-stub $*"'
  make_stub "${tmp}/stubs/repomix" 'echo "repomix $*"
while [ $# -gt 0 ]; do [ "$1" = -o ] && : >"$2"; shift; done'
  make_stub "${tmp}/eza-stub/eza" 'echo eza'
}

# A PATH with only what the helpers need here, and no eza even where /usr/bin has one.
mkdir -p "${tmp}/minbin"
ln -s "${tmp}/stubs/uuidgen" "${tmp}/minbin/uuidgen"
for t in basename dirname mv uname cut; do ln -s "$(command -v "${t}")" "${tmp}/minbin/${t}"; done

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
actual=$(run_zsh "${tmp}/minbin" "${tmp}/work" 'timed_shell() { print timed-shell-called; }; timezsh timed_shell; print -- "status=$?"')
[[ $(grep -cx timed-shell-called <<<"${actual}") -eq 10 ]] || fail "timezsh calls the shell ten times" "${actual}"
assert_contains "timezsh runs with the shell's time" "status=0" "${actual}"
assert_not_contains "timezsh runs with the shell's time" "no such file" "${actual}"
pass "timezsh runs with the shell's time"

# 5. npm refuses in a pnpm project and passes through elsewhere.
mkdir -p "${tmp}/pnpm-project/packages/app"
: >"${tmp}/pnpm-project/pnpm-lock.yaml"
actual=$(run_zsh "${base_path}" "${tmp}/pnpm-project/packages/app" 'npm install; print -- "status=$?"')
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
make_stub "${tmp}/badgen/uuidgen" 'echo partial; exit 1'
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
make_stub "${tmp}/okexif/mv" 'exit 1'
actual=$(run_zsh "${tmp}/okexif:${base_path}" "${tmp}/locked" 'random_rename -f; print -- "status=$?"')
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

mkdir -p "${tmp}/home/.antidote" "${tmp}/home/.cache/antidote" "${tmp}/bundle dir"
cat >"${tmp}/home/.antidote/antidote" <<'EOF'
case $1 in
  home) print -r -- "${ANTIDOTE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/antidote}" ;;
  bundle) print -r -- 'partial bundle'; return 1 ;;
esac
EOF
: >"${tmp}/bundle dir/.zsh_plugins.txt"
printf '%s\n' 'working bundle' >"${tmp}/bundle dir/.zsh_plugins.zsh"
# shellcheck disable=SC2016 # Expand variables in the isolated zsh.
actual=$(run_zsh "${base_path}" "${tmp}/bundle dir" 'ZDOTDIR=$PWD antidote_hard_reset; print -- "status=$?"')
assert_contains "antidote_hard_reset reports bundle failure" "status=1" "${actual}"
assert_contains "antidote_hard_reset reaches bundle generation" "Removing Antidote cache:" "${actual}"
[[ ! -e "${tmp}/home/.cache/antidote" ]] ||
  fail "antidote_hard_reset removes the default cache" "${actual}"
[[ $(cat "${tmp}/bundle dir/.zsh_plugins.zsh") == 'working bundle' ]] ||
  fail "antidote_hard_reset preserves the working bundle" "${actual}"
[[ "${tmp}/bundle dir/.zsh_plugins.txt" -nt "${tmp}/bundle dir/.zsh_plugins.zsh" ]] ||
  fail "antidote_hard_reset invalidates the saved bundle for startup" "${actual}"
# shellcheck disable=SC2016 # Expand variables in the isolated zsh.
actual=$(run_zsh "${base_path}" "${tmp}/bundle dir" 'ZDOTDIR=$PWD ANTIDOTE_HOME=$HOME antidote_hard_reset; print -- "status=$?"')
assert_contains "antidote_hard_reset rejects custom cache" "Refusing to reset" "${actual}"
[[ -e "${tmp}/home/.antidote/antidote" ]] || fail "antidote_hard_reset preserves the home" "${actual}"
mkdir -p "${tmp}/bundle dir/antidote/.antidote"
cp "${tmp}/home/.antidote/antidote" "${tmp}/bundle dir/antidote/.antidote/antidote"
# shellcheck disable=SC2016 # Expand variables in the isolated zsh.
actual=$(run_zsh "${base_path}" "${tmp}/bundle dir" 'HOME=$PWD/antidote XDG_CACHE_HOME=$PWD ZDOTDIR=$PWD antidote_hard_reset; print -- "status=$?"')
assert_contains "antidote_hard_reset rejects an overlapping default cache" "Refusing to remove a parent of HOME or ZDOTDIR" "${actual}"
[[ -e "${tmp}/bundle dir/antidote/.antidote/antidote" ]] ||
  fail "antidote_hard_reset preserves the overlapping home" "${actual}"
mkdir -p "${tmp}/bad-staging" "${tmp}/home/.cache/antidote" "${tmp}/timeout-stubs"
make_stub "${tmp}/bad-staging/mktemp" 'exit 1'
# shellcheck disable=SC2016 # Expand variables in the isolated zsh.
actual=$(run_zsh "${tmp}/bad-staging:${base_path}" "${tmp}/bundle dir" 'ZDOTDIR=$PWD antidote_hard_reset; print -- "status=$?"')
assert_contains "antidote_hard_reset reports staging failure" "status=1" "${actual}"
[[ -d "${tmp}/home/.cache/antidote" ]] || fail "antidote_hard_reset preserves cache on staging failure" "${actual}"

# shellcheck disable=SC2016 # Expand positional parameters in the stub.
make_stub "${tmp}/timeout-stubs/gtimeout" 'shift; exec "$@"'
mkdir -p "${tmp}/bundle dir/functions"
mv "${tmp}/home/.antidote/antidote" "${tmp}/bundle dir/functions/antidote"
sed 's/partial bundle/new bundle/; s/; return 1/; return 0/' "${tmp}/bundle dir/functions/antidote" > "${tmp}/bundle dir/functions/antidote.new"
mv "${tmp}/bundle dir/functions/antidote.new" "${tmp}/bundle dir/functions/antidote"
# shellcheck disable=SC2016 # Expand variables in the isolated zsh.
actual=$(run_zsh "${tmp}/timeout-stubs:${base_path}" "${tmp}/bundle dir" 'fpath=("$PWD/functions" $fpath); ZDOTDIR=$PWD antidote_hard_reset --timeout 5')
[[ $(cat "${tmp}/bundle dir/.zsh_plugins.zsh") == 'new bundle' ]] ||
  fail "antidote_hard_reset passes the custom fpath to the timeout child" "${actual}"
pass "antidote_hard_reset preserves the working bundle and home"


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

g -C "${tmp}/clone" branch feature/--dry-run-notes
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete --dry-run; print -- "status=$?"')
assert_contains "branch-delete rejects a missing substring" "status=2" "${actual}"
[[ -n $(g -C "${tmp}/clone" branch --list feature/--dry-run-notes) ]] ||
  fail "branch-delete preserves branches when the substring is missing" "${actual}"
g -C "${tmp}/clone" branch -D feature/--dry-run-notes >/dev/null
g -C "${tmp}/clone" branch audit-local-only
g -C "${tmp}/clone" tag refs/remotes/origin/audit-local-only
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete audit-local-only')
assert_contains "branch-delete ignores tags named like tracking refs" "Deleted branches: audit-local-only" "${actual}"
pass "branch-delete checks the substring and exact tracking refs"


old_tip=$(g -C "${tmp}/clone" rev-parse refs/heads/old)
recent_tip=$(g -C "${tmp}/clone" rev-parse refs/heads/recent)
g -C "${tmp}/origin.git" update-ref refs/heads/old "${recent_tip}" "${old_tip}"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
assert_contains "branch-delete rejects a changed origin tip" "stale info" "${actual}"
assert_contains "branch-delete rejects a changed origin tip" "status=1" "${actual}"
[[ $(g -C "${tmp}/origin.git" rev-parse refs/heads/old) == "${recent_tip}" &&
   $(g -C "${tmp}/clone" rev-parse refs/heads/old) == "${old_tip}" ]] ||
  fail "branch-delete preserves both refs after a rejected lease" "${actual}"
g -C "${tmp}/origin.git" update-ref refs/heads/old "${old_tip}" "${recent_tip}"
pass "branch-delete preserves both refs after a rejected lease"

g -C "${tmp}/clone" update-ref refs/heads/old "${recent_tip}" "${old_tip}"
actual=$(run_zsh "${base_path}" "${tmp}/clone" "_zsh_helpers_delete_branch old ${old_tip} ${old_tip}; print -- \"status=\$?\"")
assert_contains "branch-delete rejects local changes before push" "changed since selection" "${actual}"
assert_contains "branch-delete rejects local changes before push" "status=1" "${actual}"
[[ $(g -C "${tmp}/origin.git" rev-parse refs/heads/old) == "${old_tip}" &&
   $(g -C "${tmp}/clone" rev-parse refs/heads/old) == "${recent_tip}" ]] ||
  fail "branch-delete preserves both refs if the local tip changes before push" "${actual}"
g -C "${tmp}/clone" update-ref refs/heads/old "${old_tip}" "${recent_tip}"
pass "branch-delete preserves both refs if the local tip changes before push"

make_stub "${tmp}/origin.git/hooks/pre-receive" \
  "env -i PATH=/usr/bin:/bin git --git-dir=\"${tmp}/clone/.git\" update-ref refs/heads/old ${recent_tip} ${old_tip}"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
assert_contains "branch-delete detects local changes during push" "changed during deletion" "${actual}"
assert_contains "branch-delete reports the partial update" "Remote branch origin/old was already deleted" "${actual}"
assert_contains "branch-delete reports recovery command" "git push origin ${old_tip}:refs/heads/old" "${actual}"
assert_contains "branch-delete detects local changes during push" "status=1" "${actual}"
[[ -z $(g -C "${tmp}/origin.git" branch --list old) &&
   $(g -C "${tmp}/clone" rev-parse refs/heads/old) == "${recent_tip}" ]] ||
  fail "branch-delete preserves the changed local tip during push" "${actual}"
rm "${tmp}/origin.git/hooks/pre-receive"
g -C "${tmp}/clone" push -q origin "${old_tip}:refs/heads/old"
[[ $(g -C "${tmp}/origin.git" rev-parse refs/heads/old) == "${old_tip}" ]] ||
  fail "branch-delete recovery command restores origin/old" "${actual}"
g -C "${tmp}/clone" update-ref refs/heads/old "${old_tip}" "${recent_tip}"
pass "branch-delete preserves the changed local tip during push"

make_stub "${tmp}/origin.git/hooks/pre-receive" \
  ": >\"${tmp}/clone/.git/refs/heads/old.lock\""
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
assert_contains "branch-delete reports local deletion failure" "Could not delete local branch old at ${old_tip}" "${actual}"
assert_contains "branch-delete reports local deletion failure" "Remote branch origin/old was already deleted" "${actual}"
assert_contains "branch-delete reports local deletion failure recovery" "git push origin ${old_tip}:refs/heads/old" "${actual}"
assert_contains "branch-delete reports local deletion failure" "status=1" "${actual}"
[[ -z $(g -C "${tmp}/origin.git" branch --list old) &&
   $(g -C "${tmp}/clone" rev-parse refs/heads/old) == "${old_tip}" ]] ||
  fail "branch-delete preserves unchanged local tip on local deletion failure" "${actual}"
rm -f "${tmp}/clone/.git/refs/heads/old.lock" "${tmp}/origin.git/hooks/pre-receive"
g -C "${tmp}/clone" push -q origin "${old_tip}:refs/heads/old"
[[ $(g -C "${tmp}/origin.git" rev-parse refs/heads/old) == "${old_tip}" ]] ||
  fail "branch-delete local deletion failure recovery restores origin/old" "${actual}"
pass "branch-delete preserves unchanged local tip on local deletion failure"

# Concurrent checkout in main worktree during push keeps local branch and HEAD intact.
make_stub "${tmp}/origin.git/hooks/pre-receive" \
  "env -u GIT_DIR -u GIT_WORK_TREE git -C \"${tmp}/clone\" checkout -q old"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
assert_contains "branch-delete detects checkout during push" "checked out in a worktree); local branch was kept." "${actual}"
assert_contains "branch-delete detects checkout during push" "Remote branch origin/old was already deleted" "${actual}"
assert_contains "branch-delete detects checkout during push" "git push origin ${old_tip}:refs/heads/old" "${actual}"
assert_contains "branch-delete detects checkout during push" "status=1" "${actual}"
[[ -z $(g -C "${tmp}/origin.git" branch --list old) &&
   $(g -C "${tmp}/clone" symbolic-ref HEAD) == "refs/heads/old" &&
   $(g -C "${tmp}/clone" rev-parse --verify HEAD) == "${old_tip}" ]] ||
  fail "branch-delete preserves checked-out branch and HEAD during push" "${actual}"
rm "${tmp}/origin.git/hooks/pre-receive"
g -C "${tmp}/clone" checkout -q current
g -C "${tmp}/clone" push -q origin "${old_tip}:refs/heads/old"
pass "branch-delete preserves checked-out branch and HEAD during push"

# Concurrent linked worktree addition during push keeps local branch intact.
make_stub "${tmp}/origin.git/hooks/pre-receive" \
  "env -u GIT_DIR -u GIT_WORK_TREE git -C \"${tmp}/clone\" worktree add -q \"${tmp}/wt-race\" old"
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
assert_contains "branch-delete detects linked worktree added during push" "checked out in a worktree); local branch was kept." "${actual}"
assert_contains "branch-delete detects linked worktree added during push" "git push origin ${old_tip}:refs/heads/old" "${actual}"
assert_contains "branch-delete detects linked worktree added during push" "status=1" "${actual}"
[[ -z $(g -C "${tmp}/origin.git" branch --list old) &&
   $(g -C "${tmp}/clone" rev-parse --verify refs/heads/old) == "${old_tip}" &&
   $(g -C "${tmp}/wt-race" rev-parse --verify HEAD) == "${old_tip}" ]] ||
  fail "branch-delete preserves branch checked out in concurrent linked worktree" "${actual}"
rm "${tmp}/origin.git/hooks/pre-receive"
g -C "${tmp}/clone" worktree remove --force "${tmp}/wt-race"
g -C "${tmp}/clone" push -q origin "${old_tip}:refs/heads/old"
pass "branch-delete preserves branch checked out in concurrent linked worktree"

# Symbolic branch refs are refused without deleting the target or pushing.
g -C "${tmp}/clone" symbolic-ref refs/heads/alias refs/heads/master
master_tip=$(g -C "${tmp}/clone" rev-parse refs/heads/master)
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete alias; print -- "status=$?"')
assert_contains "branch-delete refuses symbolic branch refs" "Refusing to delete symbolic branch ref alias." "${actual}"
assert_contains "branch-delete refuses symbolic branch refs" "status=1" "${actual}"
[[ $(g -C "${tmp}/clone" symbolic-ref refs/heads/alias) == "refs/heads/master" &&
   $(g -C "${tmp}/clone" rev-parse refs/heads/master) == "${master_tip}" ]] ||
  fail "branch-delete keeps symbolic branch ref and target intact" "${actual}"
g -C "${tmp}/clone" update-ref --no-deref -d refs/heads/alias
pass "branch-delete refuses symbolic branch refs"

# Recovery command shell-quotes branch names containing shell metacharacters.
meta_branch='feature/a;false'
g -C "${tmp}/clone" branch "${meta_branch}" "${old_tip}"
g -C "${tmp}/clone" push -q origin "${meta_branch}"
mkdir -p "${tmp}/clone/.git/refs/heads/feature"
make_stub "${tmp}/origin.git/hooks/pre-receive" \
  ": >\"${tmp}/clone/.git/refs/heads/${meta_branch}.lock\""
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete "feature/a;false"; print -- "status=$?"')
assert_contains "branch-delete shell-quotes recovery command" "Restore it with: git push origin '${old_tip}:refs/heads/${meta_branch}'" "${actual}"
assert_contains "branch-delete shell-quotes recovery command" "status=1" "${actual}"
rm -f "${tmp}/clone/.git/refs/heads/${meta_branch}.lock" "${tmp}/origin.git/hooks/pre-receive"
recovery_cmd="${actual#*Restore it with: }"
recovery_cmd="${recovery_cmd%%$'\n'*}"
(cd "${tmp}/clone" && eval "${recovery_cmd}" >/dev/null 2>&1) ||
  fail "branch-delete recovery command executes cleanly with metacharacters" "${recovery_cmd}"
[[ $(g -C "${tmp}/origin.git" rev-parse "refs/heads/${meta_branch}") == "${old_tip}" ]] ||
  fail "branch-delete recovery command restores metacharacter branch on origin" "${actual}"
g -C "${tmp}/clone" branch -D "${meta_branch}" >/dev/null
g -C "${tmp}/origin.git" branch -D "${meta_branch}" >/dev/null
pass "branch-delete shell-quotes recovery command"

# Post-deletion tracking config cleanup is skipped if the branch was recreated concurrently.
g -C "${tmp}/clone" config "branch.old.remote" origin
g -C "${tmp}/clone" config "branch.old.merge" refs/heads/old
mkdir -p "${tmp}/recreate-git-bin"
cat >"${tmp}/recreate-git-bin/git" <<EOF
#!/bin/sh
real_git="$(command -v git)"
if [ "\$1" = "update-ref" ] && [ "\$2" = "--no-deref" ] && [ "\$3" = "-d" ]; then
  "\$real_git" "\$@" || exit \$?
  "\$real_git" update-ref "\$4" "${recent_tip}"
  "\$real_git" config "branch.old.remote" origin
  "\$real_git" config "branch.old.merge" refs/heads/old
  exit 0
fi
exec "\$real_git" "\$@"
EOF
chmod +x "${tmp}/recreate-git-bin/git"
actual=$(run_zsh "${tmp}/recreate-git-bin:${base_path}" "${tmp}/clone" 'branch-delete old; print -- "status=$?"')
assert_contains "branch-delete preserves recreated branch tracking config" "status=0" "${actual}"
[[ $(g -C "${tmp}/clone" config --get "branch.old.remote") == "origin" &&
   $(g -C "${tmp}/clone" config --get "branch.old.merge") == "refs/heads/old" ]] ||
  fail "branch-delete preserves recreated branch tracking config" "${actual}"
g -C "${tmp}/clone" update-ref refs/heads/old "${old_tip}" "${recent_tip}"
g -C "${tmp}/clone" config --remove-section "branch.old"
g -C "${tmp}/clone" push -q origin "${old_tip}:refs/heads/old"
pass "branch-delete preserves recreated branch tracking config"



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
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'branch-delete master')
assert_contains "branch-delete protects master" "Skipping branch: master" "${actual}"
[[ -n $(git -C "${tmp}/origin.git" branch --list master) ]] ||
  fail "branch-delete protects master" "${actual}"
pass "branch-delete protects master"
g -C "${tmp}/clone" checkout -q -b wt-old master
old_commit wt-old
g -C "${tmp}/clone" push -q origin wt-old
g -C "${tmp}/clone" checkout -q current
g -C "${tmp}/clone" worktree add -q "${tmp}/wt" wt-old
actual=$(run_zsh "${base_path}" "${tmp}/clone" 'delete-old-branches; print -- "status=$?"')
assert_contains "delete-old-branches reports a failed local delete" "Could not delete local branch wt-old" "${actual}"
assert_contains "delete-old-branches reports a failed local delete" "status=1" "${actual}"
assert_not_contains "delete-old-branches reports a failed local delete" "Deleted branches: old wt-old" "${actual}"
[[ -n $(git -C "${tmp}/origin.git" branch --list wt-old) ]] ||
  fail "delete-old-branches retains the linked worktree branch on origin" "${actual}"
pass "delete-old-branches reports a failed local delete"
g -C "${tmp}/clone" worktree remove --force "${tmp}/wt"

# Linked-worktree inspection failures abort branch deletion without mutating origin or local refs.
mkdir -p "${tmp}/wt-fail-git-bin"
cat >"${tmp}/wt-fail-git-bin/git" <<EOF
#!/bin/sh
real_git="$(command -v git)"
if [ "\$1" = "worktree" ]; then
  exit 1
fi
exec "\$real_git" "\$@"
EOF
chmod +x "${tmp}/wt-fail-git-bin/git"
actual=$(run_zsh "${tmp}/wt-fail-git-bin:${base_path}" "${tmp}/clone" 'branch-delete wt-old; print -- "status=$?"')
assert_contains "branch-delete aborts when git worktree list fails" "Could not verify linked worktrees for wt-old." "${actual}"
assert_contains "branch-delete aborts when git worktree list fails" "status=1" "${actual}"
[[ -n $(git -C "${tmp}/origin.git" branch --list wt-old) && -n $(git -C "${tmp}/clone" branch --list wt-old) ]] ||
  fail "branch-delete keeps refs when git worktree list fails" "${actual}"
pass "branch-delete aborts when git worktree list fails"
g -C "${tmp}/clone" push -q origin :refs/heads/wt-old
g -C "${tmp}/clone" branch -D wt-old >/dev/null

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
