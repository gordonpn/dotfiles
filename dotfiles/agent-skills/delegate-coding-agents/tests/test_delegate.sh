#!/usr/bin/env bash
set -euo pipefail
SCRIPT=$(cd "$(dirname "$0")/.." && pwd)/scripts/delegate.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/repo"
cat > "$TMP/bin/gemini" <<'MOCK'
#!/usr/bin/env bash
approval=''; output=''; model=''
while (($#)); do
 case "$1" in
 --approval-mode) shift; approval=$1 ;;
 --output-format) shift; output=$1 ;;
 --model) shift; model=$1 ;;
 -p) shift ;;
 esac
 shift
done
[[ $output == json ]] || exit 8
if [[ $approval == auto_edit ]]; then printf 'implemented by gemini\n' > agent-change.txt; fi
if [[ ${GEMINI_MOCK_INVALID:-} == 1 ]]; then printf '{"error":"no response"}\n'; exit 0; fi
printf '{"response":"gemini %s complete","model":"%s"}\n' "$approval" "$model"
MOCK
cat > "$TMP/bin/opencode" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == run ]] || exit 8
shift
mode=''
while (($#)); do
 if [[ $1 == --agent ]]; then shift; mode=$1; fi
 if [[ $1 == --variant ]]; then shift; variant=$1; fi
 shift
done
if [[ $mode == build ]]; then printf 'implemented by opencode\n' > agent-change.txt; fi
printf 'opencode %s %s complete\n' "$mode" "${variant:-default-variant}"
MOCK
chmod +x "$TMP/bin/gemini" "$TMP/bin/opencode"
export PATH="$TMP/bin:$PATH" DELEGATE_WORKTREE_ROOT="$TMP/worktrees"
cd "$TMP/repo"
git init -q
git config user.name 'Unit Test'
git config user.email 'test@example.com'
echo base > source.txt
git add source.txt && git commit -qm init
for agent in gemini opencode; do
 for mode in plan build; do
   if [[ $agent == gemini ]]; then
      "$SCRIPT" --agent "$agent" --mode "$mode" --id "t-$agent-$mode" --task 'Do work' --model gemini-test-model > "$TMP/$agent-$mode.out"
   else
      "$SCRIPT" --agent "$agent" --mode "$mode" --id "t-$agent-$mode" --task 'Do work' > "$TMP/$agent-$mode.out"
   fi
   grep -q 'Exit: 0' "$TMP/$agent-$mode.out"
   WT=$(sed -n 's/^  Worktree: //p' "$TMP/$agent-$mode.out" | head -n 1)
   [[ -d $WT ]]
   if [[ $agent == gemini && $mode == plan ]]; then
      [[ ! -f $WT/agent-change.txt ]]
      grep -q 'Model: gemini-test-model' "$TMP/$agent-$mode.out"
      grep -q 'gemini  complete' "$TMP/$agent-$mode.out"
      grep -q 'Branch: (detached)' "$TMP/$agent-$mode.out"
   elif [[ $agent == gemini ]]; then
      [[ -f $WT/agent-change.txt ]]
      grep -q 'gemini auto_edit complete' "$TMP/$agent-$mode.out"
      grep -q 'Branch: delegate/gemini/' "$TMP/$agent-$mode.out"
   elif [[ $mode == plan ]]; then
      [[ ! -f $WT/agent-change.txt ]]
      grep -q 'Branch: (detached)' "$TMP/$agent-$mode.out"
      if [[ $agent == opencode ]]; then grep -q 'opencode plan high complete' "$TMP/$agent-$mode.out"; fi
   else
      [[ -f $WT/agent-change.txt ]]
      grep -q "Branch: delegate/$agent/" "$TMP/$agent-$mode.out"
   fi
   [[ ! -e agent-change.txt ]]
 done
done
# GLM is an explicit quota fallback, never a silent paid-model switch.
"$SCRIPT" --agent opencode --mode plan --model opencode/glm-5.3-flash-free --id glm-fallback --task 'Retry after a quota limit' > "$TMP/glm-fallback.out"
grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/glm-fallback.out"
grep -q 'opencode plan default-variant complete' "$TMP/glm-fallback.out"
env -u GEMINI_DELEGATE_MODEL "$SCRIPT" --agent gemini --mode plan --id gemini-default --task 'Use configured model' > "$TMP/gemini-default.out"
grep -q 'Model: Gemini CLI default' "$TMP/gemini-default.out"
if GEMINI_MOCK_INVALID=1 "$SCRIPT" --agent gemini --mode plan --id gemini-invalid --task 'Return no response' > "$TMP/gemini-invalid.out" 2>&1; then
 echo 'Expected invalid Gemini JSON response to fail' >&2; exit 1
fi
grep -q 'Gemini CLI did not return a JSON response' "$TMP/gemini-invalid.out"
# Automatic delegation must be explicitly opted in for this repository.
if "$SCRIPT" --agent opencode --mode plan --orchestrator codex --automatic --task 'Nope' >"$TMP/not-opted-in.out" 2>&1; then
 echo 'Expected automatic delegation opt-in gate' >&2; exit 1
fi
grep -q 'agents.delegationAllowed true' "$TMP/not-opted-in.out"
git config --local agents.delegationAllowed true
"$SCRIPT" --agent opencode --mode plan --orchestrator agy --automatic --task 'Plan a change' > "$TMP/agy-to-opencode.out"
grep -q 'Orchestrator: agy' "$TMP/agy-to-opencode.out"
if "$SCRIPT" --agent gemini --mode plan --orchestrator agy --automatic --task 'Unsupported route' > "$TMP/agy-to-gemini.out" 2>&1; then
 echo 'Expected agy-to-Gemini rejection' >&2; exit 1
fi
grep -q 'only enabled for Codex' "$TMP/agy-to-gemini.out"
if "$SCRIPT" --agent agy --mode plan --task 'Unsupported worker' > "$TMP/agy-worker.out" 2>&1; then
 echo 'Expected Antigravity worker rejection' >&2; exit 1
fi
grep -q 'Use --agent opencode or gemini' "$TMP/agy-worker.out"
# A dirty checkout must be rejected rather than silently excluded from snapshot.
echo local > local.txt
if "$SCRIPT" --agent gemini --mode build --task 'Nope' >"$TMP/dirty.out" 2>&1; then
 echo 'Expected dirty-tree rejection' >&2; exit 1
fi
grep -q 'uncommitted or untracked' "$TMP/dirty.out"
echo 'PASS: OpenCode/Gemini plan and build, model fallback, auto opt-in, route guards, dirty-tree guard'
