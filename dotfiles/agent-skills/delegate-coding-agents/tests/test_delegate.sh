#!/usr/bin/env bash
set -euo pipefail
SCRIPT=$(cd "$(dirname "$0")/.." && pwd)/scripts/delegate.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/repo"
cat > "$TMP/bin/agy" <<'MOCK'
#!/usr/bin/env bash
mode=''; output=''; prompt=''
while (($#)); do
 case "$1" in
 --mode=*) mode=${1#--mode=} ;;
 --output-format) shift; output=$1 ;;
 -p) shift; prompt=$1 ;;
 esac
 shift
done
[[ $output == json ]] || exit 8
if [[ $mode == accept-edits ]]; then printf 'implemented by agy\n' > agent-change.txt; fi
printf '{"status":"SUCCESS","response":"agy %s complete"}\n' "$mode"
MOCK
cat > "$TMP/bin/opencode" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == run ]] || exit 8
shift
mode=''
while (($#)); do
 if [[ $1 == --agent ]]; then shift; mode=$1; fi
 shift
done
if [[ $mode == build ]]; then printf 'implemented by opencode\n' > agent-change.txt; fi
printf 'opencode %s complete\n' "$mode"
MOCK
chmod +x "$TMP/bin/agy" "$TMP/bin/opencode"
export PATH="$TMP/bin:$PATH" DELEGATE_WORKTREE_ROOT="$TMP/worktrees"
cd "$TMP/repo"
git init -q
git config user.name 'Unit Test'
git config user.email 'test@example.com'
echo base > source.txt
git add source.txt && git commit -qm init
for agent in agy opencode; do
 for mode in plan build; do
   "$SCRIPT" --agent "$agent" --mode "$mode" --id "t-$agent-$mode" --task 'Do work' > "$TMP/$agent-$mode.out"
   grep -q 'Exit: 0' "$TMP/$agent-$mode.out"
   WT=$(sed -n 's/^  Worktree: //p' "$TMP/$agent-$mode.out" | head -n 1)
   [[ -d $WT ]]
   if [[ $mode == plan ]]; then
      [[ ! -f $WT/agent-change.txt ]]
      grep -q 'Branch: (detached)' "$TMP/$agent-$mode.out"
   else
      [[ -f $WT/agent-change.txt ]]
      grep -q "Branch: delegate/$agent/" "$TMP/$agent-$mode.out"
   fi
   [[ ! -e agent-change.txt ]]
 done
done
# Automatic delegation must be explicitly opted in for this repository.
if "$SCRIPT" --agent opencode --mode plan --orchestrator codex --automatic --task 'Nope' >"$TMP/not-opted-in.out" 2>&1; then
 echo 'Expected automatic delegation opt-in gate' >&2; exit 1
fi
grep -q 'agents.delegationAllowed true' "$TMP/not-opted-in.out"
git config --local agents.delegationAllowed true
"$SCRIPT" --agent opencode --mode plan --orchestrator agy --automatic --task 'Plan a change' > "$TMP/agy-to-opencode.out"
grep -q 'Orchestrator: agy' "$TMP/agy-to-opencode.out"
if "$SCRIPT" --agent agy --mode plan --orchestrator agy --automatic --task 'Self call' > "$TMP/self.out" 2>&1; then
 echo 'Expected self-delegation rejection' >&2; exit 1
fi
grep -q 'cannot delegate to itself' "$TMP/self.out"
# A dirty checkout must be rejected rather than silently excluded from snapshot.
echo local > local.txt
if "$SCRIPT" --agent agy --mode build --task 'Nope' >"$TMP/dirty.out" 2>&1; then
 echo 'Expected dirty-tree rejection' >&2; exit 1
fi
grep -q 'uncommitted or untracked' "$TMP/dirty.out"
echo 'PASS: four agent/mode paths, auto opt-in, agy->OpenCode, no self-delegation, dirty-tree guard'
