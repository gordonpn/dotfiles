#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)/scripts
SCRIPT="$SCRIPT_DIR/delegate.sh"
ANALYZE_SCRIPT="$SCRIPT_DIR/delegate-analyze.sh"
IMPLEMENT_SCRIPT="$SCRIPT_DIR/delegate-implement.sh"
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
[[ -z ${OPENCODE_MOCK_CALL_LOG:-} ]] || printf '%s %s\n' "$mode" "$model" >>"$OPENCODE_MOCK_CALL_LOG"
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

cat > "$TMP/bin/copilot" <<'MOCK'
#!/usr/bin/env bash
mode=''; model=''; has_prompt=0; args="$*"
while (($#)); do
  case "$1" in
    -p) shift; has_prompt=1 ;;
    --mode) shift; mode=$1 ;;
    --model) shift; model=$1 ;;
  esac
  shift
done
[[ $has_prompt -eq 1 ]] || exit 8
[[ -z ${COPILOT_MOCK_CALL_LOG:-} ]] || printf '%s\n' "$args" >>"$COPILOT_MOCK_CALL_LOG"
if [[ ${COPILOT_MOCK_DIRTY_ON_FAIL:-} == 1 ]]; then printf 'partial copilot edit\n' >copilot-partial.txt; fi
if [[ ${COPILOT_MOCK_AUTH_FAIL:-} == 1 ]]; then
  printf '%s\n' "${COPILOT_MOCK_FAIL_MSG:-Error: You are not signed in. Run copilot login.}" >&2
  exit 1
fi
if [[ ${COPILOT_MOCK_FAIL:-} == 1 ]]; then
  printf '%s\n' "${COPILOT_MOCK_FAIL_MSG:-AI credits limit reached}" >&2
  exit 1
fi
if [[ $mode != plan && $args == *'--allow-tool=write'* ]]; then
  printf 'implemented by copilot\n' > agent-change.txt
fi
printf 'copilot %s %s complete\n' "$model" "${mode:-build}"
MOCK

cat > "$TMP/bin/codex" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == exec ]] || exit 8
shift
sandbox=''; out_file=''; model='default'
while (($#)); do
  case "$1" in
    --sandbox) shift; sandbox=$1 ;;
    -o) shift; out_file=$1 ;;
    -m) shift; model=$1 ;;
    -C) shift ;;
    --color|--ephemeral) ;;
  esac
  shift
done
if [[ $model == auto ]]; then
  printf 'Error: model not found: auto\n' >&2
  exit 1
fi
[[ -z ${CODEX_MOCK_CALL_LOG:-} ]] || printf '%s %s\n' "$sandbox" "$model" >>"$CODEX_MOCK_CALL_LOG"
if [[ ${CODEX_MOCK_DIRTY_ON_FAIL:-} == 1 ]]; then printf 'partial codex edit\n' >codex-partial.txt; fi
if [[ ${CODEX_MOCK_AUTH_FAIL:-} == 1 ]]; then
  printf '%s\n' "${CODEX_MOCK_FAIL_MSG:-Error: You are not logged in. Please run codex login.}" >&2
  exit 1
fi
if [[ ${CODEX_MOCK_FAIL:-} == 1 ]]; then
  printf '%s\n' "${CODEX_MOCK_FAIL_MSG:-AI_APICallError: Rate limit exceeded (429)}" >&2
  exit 1
fi
if [[ $sandbox == workspace-write ]]; then
  printf 'implemented by codex\n' > agent-change.txt
fi
if [[ -n $out_file ]]; then
  printf 'codex %s %s complete\n' "$sandbox" "$model" > "$out_file"
fi
printf 'codex %s %s complete\n' "$sandbox" "$model"
MOCK

chmod +x "$TMP/bin/gemini" "$TMP/bin/opencode" "$TMP/bin/copilot" "$TMP/bin/codex"
export PATH="$TMP/bin:$PATH" DELEGATE_WORKTREE_ROOT="$TMP/worktrees"
export OPENCODE_MOCK_CALL_LOG="$TMP/opencode.calls"
export COPILOT_MOCK_CALL_LOG="$TMP/copilot.calls"
export CODEX_MOCK_CALL_LOG="$TMP/codex.calls"
unset OPENCODE_DELEGATE_MODEL OPENCODE_DELEGATE_MODELS COPILOT_DELEGATE_MODEL GEMINI_DELEGATE_MODEL CODEX_DELEGATE_MODEL

cd "$TMP/repo"
git init -q
git config user.name 'Unit Test'
git config user.email 'test@example.com'
echo base > source.txt
git add source.txt && git commit -qm init

# Direct plan and build executions across all four workers
for agent in gemini opencode copilot codex; do
  for mode in plan build; do
    : >"$COPILOT_MOCK_CALL_LOG"
    orch='codex'
    if [[ $agent == codex ]]; then orch='agy'; fi
    if [[ $agent == gemini ]]; then
      "$SCRIPT" --orchestrator "$orch" --agent "$agent" --mode "$mode" --id "t-$agent-$mode" --task 'Do work' --model gemini-test-model > "$TMP/$agent-$mode.out"
    else
      "$SCRIPT" --orchestrator "$orch" --agent "$agent" --mode "$mode" --id "t-$agent-$mode" --task 'Do work' > "$TMP/$agent-$mode.out"
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
      if [[ $agent == copilot ]]; then
        grep -q 'Model: auto' "$TMP/$agent-$mode.out"
        grep -q 'copilot auto plan complete' "$TMP/$agent-$mode.out"
        grep -q -- '--no-ask-user' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--mode plan' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--available-tools=view,grep,glob' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--deny-tool=write' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--deny-tool=shell' "$COPILOT_MOCK_CALL_LOG"
      fi
      if [[ $agent == codex ]]; then grep -q 'codex read-only default complete' "$TMP/$agent-$mode.out"; fi
    else
      [[ -f $WT/agent-change.txt ]]
      grep -q "Branch: delegate/$agent/" "$TMP/$agent-$mode.out"
      if [[ $agent == copilot ]]; then
        grep -q 'Model: auto' "$TMP/$agent-$mode.out"
        grep -q 'copilot auto build complete' "$TMP/$agent-$mode.out"
        grep -q -- '--no-ask-user' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--available-tools=edit,view,grep,glob' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--allow-tool=write' "$COPILOT_MOCK_CALL_LOG"
        grep -q -- '--deny-tool=shell' "$COPILOT_MOCK_CALL_LOG"
      fi
      if [[ $agent == codex ]]; then grep -q 'codex workspace-write default complete' "$TMP/$agent-$mode.out"; fi
    fi
    [[ ! -e agent-change.txt ]]
  done
done

# Full 4-tier chain when Antigravity delegates: agy -> codex -> opencode -> copilot
# Tier 1: Codex succeeds directly
"$SCRIPT" --orchestrator agy --agent codex --mode plan --id agy-tier1 --task 'Tier 1 test' > "$TMP/agy-tier1.out"
grep -q 'Agent: codex' "$TMP/agy-tier1.out"
grep -q 'Worker: codex' "$TMP/agy-tier1.out"
grep -q 'Exit: 0' "$TMP/agy-tier1.out"

# Tier 2: Codex fails on quota -> falls back to OpenCode (DeepSeek Flash Free)
CODEX_MOCK_FAIL=1 "$SCRIPT" --orchestrator agy --agent codex --mode plan --id agy-tier2 --task 'Tier 2 test' > "$TMP/agy-tier2.out" 2>&1
grep -q 'falling back to next candidate' "$TMP/agy-tier2.out"
grep -q 'Agent: codex' "$TMP/agy-tier2.out"
grep -q 'Worker: opencode' "$TMP/agy-tier2.out"
grep -q 'Model: opencode/deepseek-v4.1-flash-free' "$TMP/agy-tier2.out"
grep -q 'Exit: 0' "$TMP/agy-tier2.out"

# Tier 3: Codex fails on quota, all OpenCode free models fail -> falls back to Copilot Student (auto)
CODEX_MOCK_FAIL=1 OPENCODE_MOCK_FAIL_ALL=1 "$SCRIPT" --orchestrator agy --agent codex --mode plan --id agy-tier3 --task 'Tier 3 test' > "$TMP/agy-tier3.out" 2>&1
grep -q 'Agent: codex' "$TMP/agy-tier3.out"
grep -q 'Worker: copilot' "$TMP/agy-tier3.out"
grep -q 'Model: auto' "$TMP/agy-tier3.out"
grep -q 'Exit: 0' "$TMP/agy-tier3.out"

# All tiers exhausted on quota failures -> non-zero exit with failure log
if CODEX_MOCK_FAIL=1 OPENCODE_MOCK_FAIL_ALL=1 COPILOT_MOCK_FAIL=1 "$SCRIPT" --orchestrator agy --agent codex --mode plan --id agy-all-fail --task 'All tiers fail' > "$TMP/agy-all-fail.out" 2>&1; then
  echo 'Expected all tiers failure to return non-zero' >&2; exit 1
fi
grep -q 'Delegate failed or requires manual verification' "$TMP/agy-all-fail.out"
grep -q 'Exit: 1' "$TMP/agy-all-fail.out"

# Fallback in build mode cleans up dirty worktree left by failed Codex candidate
CODEX_MOCK_FAIL=1 CODEX_MOCK_DIRTY_ON_FAIL=1 "$SCRIPT" --orchestrator agy --agent codex --mode build --id agy-codex-dirty-reset --task 'Reset dirty worktree' > "$TMP/agy-codex-dirty-reset.out" 2>&1
grep -q 'falling back to next candidate' "$TMP/agy-codex-dirty-reset.out"
grep -q 'Worker: opencode' "$TMP/agy-codex-dirty-reset.out"
WT_CLEAN=$(sed -n 's/^  Worktree: //p' "$TMP/agy-codex-dirty-reset.out" | head -n 1)
[[ -f $WT_CLEAN/agent-change.txt ]]
[[ ! -f $WT_CLEAN/codex-partial.txt ]]

# Fallback in build mode cleans up dirty worktree left by failed Copilot candidate
COPILOT_MOCK_FAIL=1 COPILOT_MOCK_DIRTY_ON_FAIL=1 "$SCRIPT" --agent copilot --mode build --id copilot-build-fallback --task 'Test Copilot build fallback' >"$TMP/copilot-build-fallback.out" 2>&1
grep -q 'Worker: opencode' "$TMP/copilot-build-fallback.out"
grep -q 'Model: opencode/deepseek-v4.1-flash-free' "$TMP/copilot-build-fallback.out"
WT_COPILOT_BUILD=$(sed -n 's/^  Worktree: //p' "$TMP/copilot-build-fallback.out" | head -n 1)
[[ -f $WT_COPILOT_BUILD/agent-change.txt ]]
[[ ! -f $WT_COPILOT_BUILD/copilot-partial.txt ]]

# Authentication hard stops for Codex
if CODEX_MOCK_AUTH_FAIL=1 "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-auth-stop --task 'Stop on auth error' > "$TMP/codex-auth-stop.out" 2>&1; then
  echo 'Expected Codex auth error to stop delegation' >&2; exit 1
fi
grep -q 'Authentication/setup failed for Codex' "$TMP/codex-auth-stop.out"
grep -q 'Stopping fallback' "$TMP/codex-auth-stop.out"
if grep -q 'falling back to next candidate' "$TMP/codex-auth-stop.out"; then
  echo 'Expected Codex auth failure not to trigger fallback' >&2; exit 1
fi

# Authentication hard stops for Copilot
if COPILOT_MOCK_AUTH_FAIL=1 "$SCRIPT" --orchestrator agy --agent copilot --mode plan --id copilot-auth-stop --task 'Stop on auth error' > "$TMP/copilot-auth-stop.out" 2>&1; then
  echo 'Expected Copilot auth error to stop delegation' >&2; exit 1
fi
grep -q 'GitHub Copilot' "$TMP/copilot-auth-stop.out"
grep -q 'Stopping fallback' "$TMP/copilot-auth-stop.out"
if grep -q 'falling back to next candidate' "$TMP/copilot-auth-stop.out"; then
  echo 'Expected Copilot auth failure not to trigger fallback' >&2; exit 1
fi

# GLM is an explicit quota fallback, never a silent paid-model switch.
"$SCRIPT" --agent opencode --mode plan --model opencode/glm-5.3-flash-free --id glm-fallback --task 'Retry after a quota limit' > "$TMP/glm-fallback.out"
grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/glm-fallback.out"
grep -q 'opencode plan default-variant complete' "$TMP/glm-fallback.out"

# Automatic fallback from deepseek to glm when deepseek fails across retained provider-error forms
for provider_err in \
  'timestamp=2026-11-03T16:57:10.019Z level=ERROR run=e048f2aa message=failed ref=err_5508aa4d error="ProviderModelNotFoundError: Model not found: opencode/deepseek-v4.1-flash-free."' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Rate limit exceeded"' \
  $'\x1b[91m\x1b[1mError: \x1b[0mModel not found: opencode/deepseek-v4.1-flash-free' \
  $'\x1b[91m\x1b[1mError: \x1b[0mFree usage exceeded, subscribe to Go' \
  'Error: You have hit your usage limit' \
  'Error: You have hit your usage limits' \
  'Error: Usage limit reached' \
  'Error: You have reached the usage limit' \
  'Error: Provider says quota exceeded for this model' \
  $'\x1b[91m\x1b[1mError: \x1b[0mQuota exceeded. Check your plan and billing details.' \
  $'\x1b[91m\x1b[1mError: \x1b[0mProvider is overloaded' \
  'AI_APICallError: Rate limit exceeded for deepseek' \
  'ProviderModelNotFoundError: model not found' \
  'AI_APICallError: Too Many Requests status 429 url https://api.example.com/v1 request_id=a1403ms' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Too Many Requests status 429 url https://api.example.com/v1 request_id=a1403ms"' \
  'AI_APICallError: Too Many Requests at https://api.example.com/v1/403' \
  'timestamp=2026-11-03T16:58:10.859Z level=ERROR run=08956276 message="stream error" providerID=opencode modelID=deepseek-v4.1-flash-free error.error="AI_APICallError: Too Many Requests at https://api.example.com/v1/403"' \
  'HTTP 429 Too Many Requests' \
  'HTTP 502 Bad Gateway' \
  'Status: 503 Service Unavailable' \
  'HTTP 504 Gateway Timeout' \
  'Response: 502' \
  'Error: Bad Request: {"error":{"message":"The requested model is not supported.","code":"model_not_supported"}}'; do
  OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_FAIL_MSG="$provider_err" "$SCRIPT" --agent opencode --mode plan --id auto-fallback --task 'Test automatic fallback' > "$TMP/auto-fallback.out" 2>&1 || { echo "Fallback case failed: $provider_err" >&2; exit 1; }
  grep -q 'falling back to next candidate' "$TMP/auto-fallback.out" || { echo "No fallback triggered for: $provider_err" >&2; exit 1; }
  grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/auto-fallback.out"
  grep -q 'opencode plan default-variant complete' "$TMP/auto-fallback.out"
  grep -q 'Exit: 0' "$TMP/auto-fallback.out"
done

# Authentication and provider initialization errors stop OpenCode chain and tell the user what to fix.
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
  'Error: You are not signed in. Please run opencode auth login.' \
  'Error: Please run opencode auth login.' \
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
OPENCODE_DELEGATE_MODELS="opencode/nemotron-3.5-lightning-free,opencode/glm-5.3-flash-free" "$SCRIPT" --agent opencode --mode plan --id custom-chain --task 'Test custom chain' > "$TMP/custom-chain.out"
grep -q 'Model: opencode/nemotron-3.5-lightning-free' "$TMP/custom-chain.out"
grep -q 'Exit: 0' "$TMP/custom-chain.out"

# Empty and whitespace-only entries in OPENCODE_DELEGATE_MODELS are skipped
OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_DELEGATE_MODELS="opencode/deepseek-v4.1-flash-free,, ,opencode/glm-5.3-flash-free" "$SCRIPT" --agent opencode --mode plan --id whitespace-chain --task 'Test whitespace chain' > "$TMP/whitespace-chain.out" 2>&1
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

# Copilot models other than Auto are rejected for Student-plan routing
if "$SCRIPT" --agent copilot --mode plan --model gpt-4.1 --id copilot-no-pin --task 'Reject explicit Student model' >"$TMP/copilot-no-pin.out" 2>&1; then
  echo 'Expected explicit non-Auto Copilot model to be rejected' >&2; exit 1
fi
grep -q 'automatic model selection only' "$TMP/copilot-no-pin.out"

if COPILOT_DELEGATE_MODEL=gpt-4.1 "$SCRIPT" --agent copilot --mode plan --id copilot-env-no-pin --task 'Reject env Student model' >"$TMP/copilot-env-no-pin.out" 2>&1; then
  echo 'Expected non-Auto COPILOT_DELEGATE_MODEL to be rejected' >&2; exit 1
fi
grep -q 'COPILOT_DELEGATE_MODEL supports automatic model selection only' "$TMP/copilot-env-no-pin.out"

# Codex --model auto and CODEX_DELEGATE_MODEL=auto omit -m to let Codex decide
"$SCRIPT" --orchestrator agy --agent codex --mode plan --model auto --id codex-model-auto --task 'Codex with model auto' > "$TMP/codex-model-auto.out"
grep -q 'Model: auto' "$TMP/codex-model-auto.out"
grep -q 'codex read-only default complete' "$TMP/codex-model-auto.out"

CODEX_DELEGATE_MODEL=auto "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-env-auto --task 'Codex with env auto' > "$TMP/codex-env-auto.out"
grep -q 'Model: auto' "$TMP/codex-env-auto.out"
grep -q 'codex read-only default complete' "$TMP/codex-env-auto.out"

"$SCRIPT" --orchestrator agy --agent codex --mode plan --model custom-codex --id codex-explicit --task 'Codex explicit model' > "$TMP/codex-explicit.out"
grep -q 'Model: custom-codex' "$TMP/codex-explicit.out"
grep -q 'codex read-only custom-codex complete' "$TMP/codex-explicit.out"

# Gemini default model
env -u GEMINI_DELEGATE_MODEL "$SCRIPT" --agent gemini --mode plan --id gemini-default --task 'Use configured model' > "$TMP/gemini-default.out"
grep -q 'Model: gemini-2.5-flash' "$TMP/gemini-default.out"

# Invalid Gemini JSON response
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
  'AI_APICallError: 400 Bad Request' \
  'Error: Usage limits are configured in the project'; do
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

if OPENCODE_DELEGATE_MODELS=',  , ' "$SCRIPT" --agent copilot --mode plan --id empty-fallback --task 'Reject an empty Copilot fallback chain' > "$TMP/empty-fallback.out" 2>&1; then
  echo 'Expected an empty Copilot fallback chain to be rejected' >&2; exit 1
fi
grep -q 'No usable OpenCode fallback models' "$TMP/empty-fallback.out"

# Automatic delegation must be explicitly opted in for this repository.
if "$SCRIPT" --agent opencode --mode plan --orchestrator codex --automatic --task 'Nope' >"$TMP/not-opted-in.out" 2>&1; then
 echo 'Expected automatic delegation opt-in gate' >&2; exit 1
fi
grep -q 'agents.delegationAllowed true' "$TMP/not-opted-in.out"
git config --local agents.delegationAllowed true

# Orchestrator route tests
"$SCRIPT" --agent opencode --mode plan --orchestrator agy --automatic --task 'Plan a change' > "$TMP/agy-to-opencode.out"
grep -q 'Orchestrator: agy' "$TMP/agy-to-opencode.out"
grep -q 'Worker: opencode' "$TMP/agy-to-opencode.out"

"$SCRIPT" --agent copilot --mode plan --orchestrator agy --automatic --task 'Plan a change with copilot' > "$TMP/agy-to-copilot.out"
grep -q 'Orchestrator: agy' "$TMP/agy-to-copilot.out"
grep -q 'Worker: copilot' "$TMP/agy-to-copilot.out"
grep -q 'Model: auto' "$TMP/agy-to-copilot.out"

"$SCRIPT" --agent codex --mode plan --orchestrator agy --automatic --task 'Plan a change with codex' > "$TMP/agy-to-codex.out"
grep -q 'Orchestrator: agy' "$TMP/agy-to-codex.out"
grep -q 'Worker: codex' "$TMP/agy-to-codex.out"

# Codex cannot delegate to Codex
if "$SCRIPT" --agent codex --mode plan --orchestrator codex --automatic --task 'Self delegation' > "$TMP/codex-to-codex.out" 2>&1; then
  echo 'Expected Codex-to-Codex rejection' >&2; exit 1
fi
grep -q 'Codex cannot delegate to Codex' "$TMP/codex-to-codex.out"

# Wrapper scripts accept --orchestrator and preserve self-delegation guard
"$ANALYZE_SCRIPT" --orchestrator agy codex 'Wrapper analyze with codex' > "$TMP/wrap-analyze-agy.out"
grep -q 'Orchestrator: agy' "$TMP/wrap-analyze-agy.out"
grep -q 'Worker: codex' "$TMP/wrap-analyze-agy.out"

if "$ANALYZE_SCRIPT" codex 'Wrapper self-delegation' > "$TMP/wrap-analyze-self.out" 2>&1; then
  echo 'Expected wrapper Codex-to-Codex rejection' >&2; exit 1
fi
grep -q 'Codex cannot delegate to Codex' "$TMP/wrap-analyze-self.out"

"$IMPLEMENT_SCRIPT" --orchestrator agy codex wrap-build 'Wrapper build with codex' > "$TMP/wrap-implement-agy.out"
grep -q 'Orchestrator: agy' "$TMP/wrap-implement-agy.out"
grep -q 'Worker: codex' "$TMP/wrap-implement-agy.out"
WT_WRAP_CODEX=$(sed -n 's/^  Worktree: //p' "$TMP/wrap-implement-agy.out" | head -n 1)
[[ -f $WT_WRAP_CODEX/agent-change.txt ]]

# agy cannot delegate to Gemini
if "$SCRIPT" --agent gemini --mode plan --orchestrator agy --automatic --task 'Unsupported route' > "$TMP/agy-to-gemini.out" 2>&1; then
 echo 'Expected agy-to-Gemini rejection' >&2; exit 1
fi
grep -q 'only enabled for Codex' "$TMP/agy-to-gemini.out"

# Unsupported worker rejection
if "$SCRIPT" --agent agy --mode plan --task 'Unsupported worker' > "$TMP/agy-worker.out" 2>&1; then
 echo 'Expected Antigravity worker rejection' >&2; exit 1
fi
grep -q 'Use --agent codex, opencode, copilot, or gemini' "$TMP/agy-worker.out"

# A dirty checkout must be rejected rather than silently excluded from snapshot.
echo local > local.txt
if "$SCRIPT" --agent gemini --mode build --task 'Nope' >"$TMP/dirty.out" 2>&1; then
 echo 'Expected dirty-tree rejection' >&2; exit 1
fi
grep -q 'uncommitted or untracked' "$TMP/dirty.out"

echo 'PASS: All delegation tests passed across Codex, OpenCode, Copilot, and Gemini'
