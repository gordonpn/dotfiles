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
if [[ -n ${GEMINI_MOCK_FAIL_EXIT:-} ]]; then
  printf '{"response":"gemini failed output","model":"%s"}\n' "$model"
  exit "$GEMINI_MOCK_FAIL_EXIT"
fi
printf '{"response":"gemini %s complete","model":"%s"}\n' "$approval" "$model"
MOCK
cat > "$TMP/bin/opencode" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == run ]] || exit 8
shift
mode=''; variant=''; model=''
while (($#)); do
 if [[ $1 == --agent ]]; then shift; mode=$1; fi
 if [[ $1 == --variant ]]; then shift; variant=$1; fi
 if [[ $1 == --model ]]; then shift; model=$1; fi
 shift
done
if [[ ${OPENCODE_MOCK_COMPILER_ERROR:-} == 1 ]]; then
  if [[ $mode == build ]]; then printf 'compiler error uncommitted\n' > compiler-error.txt; fi
  echo 'src/server.ts:502:12 - error TS2304: Cannot find name foo' >&2
  echo 'error: rate limit validation failed' >&2
  echo 'timestamp=2026-11-03T16:58:09.362Z level=ERROR run=08956276 message="MCP server log" server=uptime-kuma logger=undefined level=error data="Failed to authenticate with Uptime Kuma: authInvalidToken"' >&2
  echo 'AssertionError: expected AI_APICallError handler capacity to be 10, got 8' >&2
  echo 'FAIL test_quota_validation: expected rate limit quota 10, got 8' >&2
  echo 'stdout report mentioning quota, rate limit, and model not found'
  exit 1
fi
if [[ ${OPENCODE_MOCK_TASK_ERROR:-} == 1 ]]; then
  if [[ $mode == build ]]; then printf 'task error uncommitted modification\n' > task-error-work.txt; fi
  echo 'Simulated task execution failure (test error)' >&2
  exit 1
fi
if [[ ${OPENCODE_MOCK_FAIL_DEEPSEEK:-} == 1 && $model == opencode/deepseek-v4.1-flash-free ]]; then
  if [[ ${OPENCODE_MOCK_DIRTY_ON_FAIL:-} == 1 ]]; then
    printf 'stale uncommitted modification\n' > failed-dirty.txt
  fi
  echo "${OPENCODE_MOCK_FAIL_MSG:-AI_APICallError: Rate limit exceeded for deepseek}" >&2
  exit 1
fi
if [[ ${OPENCODE_MOCK_FAIL_ALL:-} == 1 ]]; then
  echo 'AI_APICallError: Quota exceeded for all models' >&2
  exit 1
fi
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
# Automatic fallback from deepseek to glm when deepseek fails across each retained OpenCode v1.19.3 provider-error form
for provider_err in \
  'timestamp=2026-11-03T16:57:10.019Z level=ERROR run=e048f2aa message=failed ref=err_5508aa4d error="ProviderModelNotFoundError: Model not found: opencode/deepseek-v4.1-flash-free."' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Rate limit exceeded"' \
  $'\x1b[91m\x1b[1mError: \x1b[0mModel not found: opencode/deepseek-v4.1-flash-free' \
  $'\x1b[91m\x1b[1mError: \x1b[0mFree usage exceeded, subscribe to Go' \
  'Error: You have hit your usage limit reached' \
  $'\x1b[91m\x1b[1mError: \x1b[0mQuota exceeded. Check your plan and billing details.' \
  $'\x1b[91m\x1b[1mError: \x1b[0mProvider is overloaded' \
  'AI_APICallError: Rate limit exceeded for deepseek' \
  'ProviderModelNotFoundError: model not found' \
  'AI_APICallError: Too Many Requests status 429 url https://api.example.com/v1 request_id=a1403ms' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Too Many Requests status 429 url https://api.example.com/v1 request_id=a1403ms"' \
  'AI_APICallError: Too Many Requests at https://api.example.com/v1/403' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Too Many Requests at https://api.example.com/v1/403"' \
  'HTTP 429 Too Many Requests' \
  'Status: 503 Service Unavailable'; do
  OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_FAIL_MSG="$provider_err" "$SCRIPT" --agent opencode --mode plan --id auto-fallback --task 'Test automatic fallback' > "$TMP/auto-fallback.out" 2>&1 || { echo "Fallback case failed: $provider_err" >&2; exit 1; }
  grep -q 'falling back to next candidate' "$TMP/auto-fallback.out" || { echo "No fallback triggered for: $provider_err" >&2; exit 1; }
  grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/auto-fallback.out"
  grep -q 'opencode plan default-variant complete' "$TMP/auto-fallback.out"
  grep -q 'Exit: 0' "$TMP/auto-fallback.out"
done
# Authentication and provider initialization errors stop the chain and tell the user what to fix.
for auth_err in \
  'ProviderAuthError: authentication failed' \
  'timestamp=2026-11-03T16:57:10.019Z level=ERROR run=e048f2aa message=failed ref=err_5508aa4d error="ProviderAuthError: authentication failed"' \
  'timestamp=2026-11-03T16:57:10.019Z level=ERROR run=e048f2aa message=failed ref=err_5508aa4d error="ProviderInitError: Failed to initialize provider"' \
  'Error: Incorrect API key provided: test-key' \
  'Error: Invalid API key' \
  'Error: No API key found for provider' \
  'Error: Failed to initialize provider "opencode". Check credentials and configuration.' \
  'Error: AI_APICallError: Request failed with status code 401' \
  'Error: AI_APICallError: 401' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Request failed with status code 403"' \
  'HTTP 401 Unauthorized' \
  'Error: AI_APICallError: Unauthorized: missing API key'; do
  if OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_FAIL_MSG="$auth_err" "$SCRIPT" --agent opencode --mode plan --id auth-hard-stop --task 'Stop on invalid credentials' > "$TMP/auth-hard-stop.out" 2>&1; then
    echo "Expected authentication error to stop delegation: $auth_err" >&2; exit 1
  fi
  grep -q 'Model: opencode/deepseek-v4.1-flash-free' "$TMP/auth-hard-stop.out"
  grep -q 'Stopping fallback' "$TMP/auth-hard-stop.out"
  grep -q 'Check the OpenCode login and provider API key/configuration' "$TMP/auth-hard-stop.out"
  grep -q '/stderr.log' "$TMP/auth-hard-stop.out"
  if grep -q 'falling back to next candidate' "$TMP/auth-hard-stop.out"; then
    echo 'Expected authentication failure not to trigger fallback' >&2; exit 1
  fi
done
# Automatic fallback in build mode resets dirty worktree from failed candidate
OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_DIRTY_ON_FAIL=1 "$SCRIPT" --agent opencode --mode build --id auto-fallback-build --task 'Test build fallback worktree reset' > "$TMP/auto-fallback-build.out" 2>&1
grep -q 'falling back to next candidate' "$TMP/auto-fallback-build.out"
grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/auto-fallback-build.out"
grep -q 'Exit: 0' "$TMP/auto-fallback-build.out"
WT_BUILD=$(sed -n 's/^  Worktree: //p' "$TMP/auto-fallback-build.out" | head -n 1)
[[ -f $WT_BUILD/agent-change.txt ]]
[[ ! -f $WT_BUILD/failed-dirty.txt ]]
# Plan mode mutation before provider error must not be wiped by retry and must fail read-only check
if OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_DIRTY_ON_FAIL=1 "$SCRIPT" --agent opencode --mode plan --id plan-dirty-no-retry --task 'Test plan dirty no retry' > "$TMP/plan-dirty-no-retry.out" 2>&1; then
  echo 'Expected plan mode mutation on failed candidate to return non-zero' >&2; exit 1
fi
grep -q 'Planning delegate modified its isolated worktree' "$TMP/plan-dirty-no-retry.out"
grep -q 'Model: opencode/deepseek-v4.1-flash-free' "$TMP/plan-dirty-no-retry.out"
# Environment variable OPENCODE_DELEGATE_MODELS override
OPENCODE_DELEGATE_MODELS="opencode/qwen3.6-plus-free,opencode/glm-5.3-flash-free" "$SCRIPT" --agent opencode --mode plan --id custom-chain --task 'Test custom chain' > "$TMP/custom-chain.out"
grep -q 'Model: opencode/qwen3.6-plus-free' "$TMP/custom-chain.out"
grep -q 'Exit: 0' "$TMP/custom-chain.out"
# Empty and whitespace-only entries in OPENCODE_DELEGATE_MODELS are skipped
OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_DELEGATE_MODELS="opencode/deepseek-v4.1-flash-free,, ,opencode/glm-5.3-flash-free" "$SCRIPT" --agent opencode --mode plan --id whitespace-chain --task 'Test whitespace chain' > "$TMP/whitespace-chain.out"
grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/whitespace-chain.out"
grep -q 'Exit: 0' "$TMP/whitespace-chain.out"
# Explicit --model pins a single candidate and does not fallback on quota error
if OPENCODE_MOCK_FAIL_DEEPSEEK=1 "$SCRIPT" --agent opencode --mode plan --model opencode/deepseek-v4.1-flash-free --id model-no-fallback --task 'Test explicit model' > "$TMP/model-no-fallback.out" 2>&1; then
  echo 'Expected explicit model quota failure to return non-zero' >&2; exit 1
fi
grep -q 'Model: opencode/deepseek-v4.1-flash-free' "$TMP/model-no-fallback.out"
if grep -q 'falling back to next candidate' "$TMP/model-no-fallback.out"; then
  echo 'Expected explicit model not to fall back' >&2; exit 1
fi
# Failure when all candidate models fail
if OPENCODE_MOCK_FAIL_ALL=1 "$SCRIPT" --agent opencode --mode plan --id all-fail --task 'Test all fail' > "$TMP/all-fail.out" 2>&1; then
  echo 'Expected all models failure to return non-zero' >&2; exit 1
fi
grep -q 'Delegate failed or requires manual verification' "$TMP/all-fail.out"
grep -q 'Model opencode/deepseek-v4.1-flash-free encountered provider/quota failure' "$TMP/all-fail.out"
grep -q 'Model opencode/glm-5.3-flash-free encountered provider/quota failure' "$TMP/all-fail.out"
grep -q 'Model opencode/minimax-m3.1-flash-free encountered provider/quota failure' "$TMP/all-fail.out"
grep -q 'Model: opencode/qwen3.6-plus-free' "$TMP/all-fail.out"
env -u GEMINI_DELEGATE_MODEL "$SCRIPT" --agent gemini --mode plan --id gemini-default --task 'Use configured model' > "$TMP/gemini-default.out"
grep -q 'Model: Gemini CLI default' "$TMP/gemini-default.out"
if GEMINI_MOCK_INVALID=1 "$SCRIPT" --agent gemini --mode plan --id gemini-invalid --task 'Return no response' > "$TMP/gemini-invalid.out" 2>&1; then
 echo 'Expected invalid Gemini JSON response to fail' >&2; exit 1
fi
grep -q 'Gemini CLI did not return a JSON response' "$TMP/gemini-invalid.out"
# Gemini nonzero exit with string response must preserve nonzero exit code
if GEMINI_MOCK_FAIL_EXIT=42 "$SCRIPT" --agent gemini --mode plan --id gemini-nonzero --task 'Test nonzero exit' > "$TMP/gemini-nonzero.out" 2>&1; then
  echo 'Expected nonzero exit for failing Gemini process' >&2; exit 1
fi
grep -q 'Exit: 42' "$TMP/gemini-nonzero.out"
# OpenCode task error must not fallback to next candidate model and must preserve worktree
if OPENCODE_MOCK_TASK_ERROR=1 "$SCRIPT" --agent opencode --mode build --id task-error --task 'Test task error' > "$TMP/task-error.out" 2>&1; then
  echo 'Expected task error to return nonzero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/task-error.out"
if grep -q 'falling back to next candidate' "$TMP/task-error.out"; then
  echo 'Expected task error not to trigger fallback candidate retry' >&2; exit 1
fi
WT_TASK_ERROR=$(sed -n 's/^  Worktree: //p' "$TMP/task-error.out" | head -n 1)
[[ -f $WT_TASK_ERROR/task-error-work.txt ]]
# OpenCode compiler/line-number error with numbers like 502 or term capacity must not trigger fallback
if OPENCODE_MOCK_COMPILER_ERROR=1 "$SCRIPT" --agent opencode --mode build --id compiler-error --task 'Test compiler error' > "$TMP/compiler-error.out" 2>&1; then
  echo 'Expected compiler error to return nonzero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/compiler-error.out"
if grep -q 'Stopping fallback' "$TMP/compiler-error.out"; then
  echo 'Expected auth-looking compiler output not to be treated as an authentication failure' >&2; exit 1
fi
if grep -q 'falling back to next candidate' "$TMP/compiler-error.out"; then
  echo 'Expected compiler line numbers and capacity terms not to trigger fallback candidate retry' >&2; exit 1
fi
WT_COMPILER_ERROR=$(sed -n 's/^  Worktree: //p' "$TMP/compiler-error.out" | head -n 1)
[[ -f $WT_COMPILER_ERROR/compiler-error.txt ]]
# Generic API failures and auth-looking digits in URLs/request IDs do not trigger retries.
for task_error in \
  'APIError: upstream error' \
  'RetryError: max retries reached' \
  'AI_APICallError: status check failed at https://api.example.com/v1/403' \
  'AI_APICallError: code=req401abc' \
  'AI_APICallError: 400 Bad Request'; do
  if OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_FAIL_MSG="$task_error" "$SCRIPT" --agent opencode --mode build --id generic-error --task 'Do not retry unclassified errors' > "$TMP/generic-error.out" 2>&1; then
    echo "Expected unclassified error not to succeed by retrying: $task_error" >&2; exit 1
  fi
  if grep -q 'Stopping fallback' "$TMP/generic-error.out" || grep -q 'falling back to next candidate' "$TMP/generic-error.out"; then
    echo "Expected unclassified error not to be classified as auth/provider failure: $task_error" >&2; exit 1
  fi
done
# Reject a configured chain containing no usable model before creating a worktree.
if OPENCODE_DELEGATE_MODELS=',  , ' "$SCRIPT" --agent opencode --mode plan --id empty-chain --task 'Reject an empty model chain' > "$TMP/empty-chain.out" 2>&1; then
  echo 'Expected an empty OpenCode model chain to be rejected' >&2; exit 1
fi
grep -q 'No usable OpenCode delegate models' "$TMP/empty-chain.out"
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
