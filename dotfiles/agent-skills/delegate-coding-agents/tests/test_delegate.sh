#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)/scripts
SCRIPT="$SCRIPT_DIR/delegate.sh"
ANALYZE_SCRIPT="$SCRIPT_DIR/delegate-analyze.sh"
IMPLEMENT_SCRIPT="$SCRIPT_DIR/delegate-implement.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/repo"

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
[[ -z ${OPENCODE_MOCK_CONFIG_LOG:-} ]] || printf '%s\n' "${OPENCODE_CONFIG:-NONE}" >>"$OPENCODE_MOCK_CONFIG_LOG"
[[ -z ${OPENCODE_MOCK_CONTENT_LOG:-} ]] || printf '%s\n' "${OPENCODE_CONFIG_CONTENT:-NONE}" >>"$OPENCODE_MOCK_CONTENT_LOG"
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
    -c|--config) shift; [[ -z ${CODEX_MOCK_CONFIG_LOG:-} ]] || printf '%s\n' "$1" >>"$CODEX_MOCK_CONFIG_LOG" ;;
    -C) shift ;;
    --color|--ephemeral|--skip-git-repo-check|--non-interactive) ;;
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

chmod +x "$TMP/bin/opencode" "$TMP/bin/copilot" "$TMP/bin/codex"
export PATH="$TMP/bin:$PATH" DELEGATE_WORKTREE_ROOT="$TMP/worktrees"
export OPENCODE_MOCK_CALL_LOG="$TMP/opencode.calls"
export OPENCODE_MOCK_CONFIG_LOG="$TMP/opencode.config"
export OPENCODE_MOCK_CONTENT_LOG="$TMP/opencode.content"
export COPILOT_MOCK_CALL_LOG="$TMP/copilot.calls"
export CODEX_MOCK_CALL_LOG="$TMP/codex.calls"
export CODEX_MOCK_CONFIG_LOG="$TMP/codex.config"
unset OPENCODE_DELEGATE_MODEL OPENCODE_DELEGATE_MODELS COPILOT_DELEGATE_MODEL CODEX_DELEGATE_MODEL OPENCODE_DELEGATE_MCP_PROFILE OPENCODE_DELEGATE_MCP_SERVERS OPENCODE_MCP_PROFILE DELEGATE_MCP_PROFILE DELEGATE_MCP_SERVERS CODEX_DELEGATE_MCP_PROFILE CODEX_DELEGATE_MCP_SERVERS

cd "$TMP/repo"
git init -q
git config user.name 'Unit Test'
git config user.email 'test@example.com'
echo base > source.txt
git add source.txt && git commit -qm init

# Direct plan and build executions across all three workers
for agent in opencode copilot codex; do
  for mode in plan build; do
    : >"$COPILOT_MOCK_CALL_LOG"
    orch='codex'
    if [[ $agent == codex ]]; then orch='agy'; fi
    "$SCRIPT" --orchestrator "$orch" --agent "$agent" --mode "$mode" --id "t-$agent-$mode" --task 'Do work' > "$TMP/$agent-$mode.out"
    grep -q 'Exit: 0' "$TMP/$agent-$mode.out"
    WT=$(sed -n 's/^  Worktree: //p' "$TMP/$agent-$mode.out" | head -n 1)
    [[ -d $WT ]]
    if [[ $mode == plan ]]; then
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

# Unsupported worker rejection
if "$SCRIPT" --agent agy --mode plan --task 'Unsupported worker' > "$TMP/agy-worker.out" 2>&1; then
 echo 'Expected Antigravity worker rejection' >&2; exit 1
fi
grep -q 'Use --agent codex, opencode, or copilot' "$TMP/agy-worker.out"

# MCP profile: Minimal profile generation and non-mutation of normal user profile
mkdir -p "$TMP/user-config/opencode"
cat > "$TMP/user-config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/deepseek-v4.1-flash-free",
  "mcp": {
    "cclsp": {
      "command": "/usr/local/bin/cclsp"
    },
    "slack": {
      "command": "npx -y @modelcontextprotocol/server-slack"
    },
    "uptime-kuma": {
      "command": "npx -y @davidfuchs/mcp-uptime-kuma"
    },
    "docker": {
      "command": "npx -y @hypnosis/docker-mcp-server"
    }
  }
}
JSON
hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}
ORIG_CFG_HASH=$(hash_file "$TMP/user-config/opencode/opencode.json")

: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/user-config" "$SCRIPT" --agent opencode --mode plan --id mcp-minimal --task 'Test minimal MCP profile' > "$TMP/mcp-minimal.out"
grep -q 'Exit: 0' "$TMP/mcp-minimal.out"
grep -q 'MCP profile: minimal' "$TMP/mcp-minimal.out"
MCP_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/mcp-minimal.out" | head -n 1)
[[ -f "$MCP_LOG_DIR/opencode-profile.json" ]]
grep -q 'mcp_profile=minimal' "$MCP_LOG_DIR/manifest.txt"
grep -q "mcp_profile_path=$MCP_LOG_DIR/opencode-profile.json" "$MCP_LOG_DIR/manifest.txt"

# Verify OPENCODE_CONFIG passed to OpenCode points to the generated minimal profile
LAST_OPENCODE_CFG=$(tail -n 1 "$OPENCODE_MOCK_CONFIG_LOG")
[[ "$LAST_OPENCODE_CFG" == "$MCP_LOG_DIR/opencode-profile.json" ]]

# Verify unnecessary servers were disabled in the generated profile and minimal ones retained
jq -e '.mcp["slack"].enabled == false' "$MCP_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["uptime-kuma"].enabled == false' "$MCP_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["docker"].enabled == false' "$MCP_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp | has("cclsp") | not' "$MCP_LOG_DIR/opencode-profile.json" >/dev/null

# Verify the user normal profile was NOT mutated
POST_CFG_HASH=$(hash_file "$TMP/user-config/opencode/opencode.json")
[[ "$ORIG_CFG_HASH" == "$POST_CFG_HASH" ]]

# MCP profile: Selection override with --mcp-profile none disables all servers
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/user-config" "$SCRIPT" --agent opencode --mode plan --mcp-profile none --id mcp-none --task 'Test none MCP profile' > "$TMP/mcp-none.out"
grep -q 'Exit: 0' "$TMP/mcp-none.out"
grep -q 'MCP profile: none' "$TMP/mcp-none.out"
MCP_NONE_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/mcp-none.out" | head -n 1)
jq -e '.mcp["cclsp"].enabled == false' "$MCP_NONE_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["slack"].enabled == false' "$MCP_NONE_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["uptime-kuma"].enabled == false' "$MCP_NONE_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["docker"].enabled == false' "$MCP_NONE_LOG_DIR/opencode-profile.json" >/dev/null

# MCP profile: Selection override with --mcp-profile full preserves full profile (no OPENCODE_CONFIG)
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/user-config" "$SCRIPT" --agent opencode --mode plan --mcp-profile full --id mcp-full --task 'Test full MCP profile' > "$TMP/mcp-full.out"
grep -q 'Exit: 0' "$TMP/mcp-full.out"
grep -q 'MCP profile: full' "$TMP/mcp-full.out"
LAST_FULL_CFG=$(tail -n 1 "$OPENCODE_MOCK_CONFIG_LOG")
[[ "$LAST_FULL_CFG" == "NONE" ]]
MCP_FULL_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/mcp-full.out" | head -n 1)
grep -q 'mcp_profile=full' "$MCP_FULL_LOG_DIR/manifest.txt"
grep -q 'mcp_profile_path=(none)' "$MCP_FULL_LOG_DIR/manifest.txt"

# MCP profile: Custom profile path
cat > "$TMP/custom-mcp.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "custom-server": { "command": "custom-cmd" }
  }
}
JSON
: >"$OPENCODE_MOCK_CONFIG_LOG"
"$SCRIPT" --agent opencode --mode plan --mcp-profile "$TMP/custom-mcp.json" --id mcp-custom --task 'Test custom MCP profile' > "$TMP/mcp-custom.out"
grep -q 'Exit: 0' "$TMP/mcp-custom.out"
LAST_CUSTOM_CFG=$(tail -n 1 "$OPENCODE_MOCK_CONFIG_LOG")
[[ "$LAST_CUSTOM_CFG" == "$TMP/custom-mcp.json" ]]

# MCP profile: Relative custom profile path is normalized to absolute
(
  cd "$TMP/repo"
  : >"$OPENCODE_MOCK_CONFIG_LOG"
  "$SCRIPT" --agent opencode --mode plan --mcp-profile "../custom-mcp.json" --id mcp-custom-rel --task 'Test relative custom MCP profile' > "$TMP/mcp-custom-rel.out"
  grep -q 'Exit: 0' "$TMP/mcp-custom-rel.out"
  LAST_REL_CFG=$(tail -n 1 "$OPENCODE_MOCK_CONFIG_LOG")
  [[ "$LAST_REL_CFG" == "$TMP/custom-mcp.json" ]]
)

# MCP profile: Missing profile path rejection
if "$SCRIPT" --agent opencode --mode plan --mcp-profile "$TMP/missing-profile.json" --task 'Missing profile' > "$TMP/mcp-missing.out" 2>&1; then
  echo 'Expected missing profile path rejection' >&2; exit 1
fi
grep -q 'MCP profile file not found' "$TMP/mcp-missing.out"

# MCP profile: Custom servers list via OPENCODE_DELEGATE_MCP_SERVERS
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/user-config" OPENCODE_DELEGATE_MCP_SERVERS="docker,cclsp" "$SCRIPT" --agent opencode --mode plan --id mcp-servers-override --task 'Test servers override' > "$TMP/mcp-servers-override.out"
grep -q 'Exit: 0' "$TMP/mcp-servers-override.out"
MCP_OVERRIDE_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/mcp-servers-override.out" | head -n 1)
jq -e '.mcp | has("docker") | not' "$MCP_OVERRIDE_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp | has("cclsp") | not' "$MCP_OVERRIDE_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["slack"].enabled == false' "$MCP_OVERRIDE_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["uptime-kuma"].enabled == false' "$MCP_OVERRIDE_LOG_DIR/opencode-profile.json" >/dev/null

# MCP profile for Codex: Minimal profile overrides and non-mutation of normal user profile
mkdir -p "$TMP/user-config/codex"
cat > "$TMP/user-config/codex/config.toml" <<'TOML'
[mcp_servers."cclsp"]
command = "/usr/local/bin/cclsp"

[mcp_servers."slack"]
command = "npx -y @modelcontextprotocol/server-slack"

[mcp_servers."uptime-kuma"]
command = "npx -y @davidfuchs/mcp-uptime-kuma"

[mcp_servers."docker"]
command = "npx -y @hypnosis/docker-mcp-server"
TOML
ORIG_CODEX_CFG_HASH=$(hash_file "$TMP/user-config/codex/config.toml")

: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-mcp-minimal --task 'Test codex minimal MCP profile' > "$TMP/codex-mcp-minimal.out"
grep -q 'Exit: 0' "$TMP/codex-mcp-minimal.out"
grep -q 'MCP profile: minimal' "$TMP/codex-mcp-minimal.out"
CODEX_MCP_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/codex-mcp-minimal.out" | head -n 1)
[[ -f "$CODEX_MCP_LOG_DIR/codex-mcp-overrides.txt" ]]
grep -q 'mcp_profile=minimal' "$CODEX_MCP_LOG_DIR/manifest.txt"
grep -q "mcp_profile_path=$CODEX_MCP_LOG_DIR/codex-mcp-overrides.txt" "$CODEX_MCP_LOG_DIR/manifest.txt"

# Verify unnecessary servers were disabled via -c and minimal servers kept
grep -q 'mcp_servers.slack.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.uptime-kuma.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.docker.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
if grep -q 'mcp_servers.cclsp.enabled=false' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected cclsp to remain enabled for codex minimal profile' >&2; exit 1
fi

# Verify user codex config.toml was NOT mutated
POST_CODEX_CFG_HASH=$(hash_file "$TMP/user-config/codex/config.toml")
[[ "$ORIG_CODEX_CFG_HASH" == "$POST_CODEX_CFG_HASH" ]]

# MCP profile for Codex: Selection override with --mcp-profile none disables all servers
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --mcp-profile none --id codex-mcp-none --task 'Test codex none MCP profile' > "$TMP/codex-mcp-none.out"
grep -q 'Exit: 0' "$TMP/codex-mcp-none.out"
grep -q 'MCP profile: none' "$TMP/codex-mcp-none.out"
grep -q 'mcp_servers.cclsp.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.slack.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.uptime-kuma.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.docker.enabled=false' "$CODEX_MOCK_CONFIG_LOG"

# MCP profile for Codex: Selection override with --mcp-profile full preserves full profile (no -c overrides)
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --mcp-profile full --id codex-mcp-full --task 'Test codex full MCP profile' > "$TMP/codex-mcp-full.out"
grep -q 'Exit: 0' "$TMP/codex-mcp-full.out"
grep -q 'MCP profile: full' "$TMP/codex-mcp-full.out"
[[ ! -s "$CODEX_MOCK_CONFIG_LOG" ]]
CODEX_FULL_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/codex-mcp-full.out" | head -n 1)
grep -q 'mcp_profile=full' "$CODEX_FULL_LOG_DIR/manifest.txt"
grep -q 'mcp_profile_path=(none)' "$CODEX_FULL_LOG_DIR/manifest.txt"

# MCP profile for Codex: Custom servers list via CODEX_DELEGATE_MCP_SERVERS
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" CODEX_DELEGATE_MCP_SERVERS="docker,cclsp" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-mcp-override --task 'Test codex servers override' > "$TMP/codex-mcp-override.out"
grep -q 'Exit: 0' "$TMP/codex-mcp-override.out"
if grep -q 'mcp_servers.docker.enabled=false' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected docker to remain enabled in override' >&2; exit 1
fi
if grep -q 'mcp_servers.cclsp.enabled=false' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected cclsp to remain enabled in override' >&2; exit 1
fi
grep -q 'mcp_servers.slack.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.uptime-kuma.enabled=false' "$CODEX_MOCK_CONFIG_LOG"

# MCP profile for Codex: Custom TOML profile resets state across sections
cat > "$TMP/custom-codex.toml" <<'TOML'
[mcp_servers."cclsp"]
command = "cclsp"

[features]
enabled = false

[mcp_servers."slack"]
enabled = false
TOML
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --mcp-profile "$TMP/custom-codex.toml" --id codex-custom-toml --task 'Test codex custom toml' > "$TMP/codex-custom-toml.out"
grep -q 'Exit: 0' "$TMP/codex-custom-toml.out"
grep -q 'mcp_servers.slack.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
if grep -q 'mcp_servers.cclsp.enabled=false' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected cclsp to remain enabled despite subsequent section having enabled=false' >&2; exit 1
fi

# MCP profile: Environment variable isolation between agents
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/user-config" CODEX_DELEGATE_MCP_PROFILE="none" "$SCRIPT" --agent opencode --mode plan --id opencode-iso --task 'Test profile isolation' > "$TMP/opencode-iso.out"
grep -q 'Exit: 0' "$TMP/opencode-iso.out"
grep -q 'MCP profile: minimal' "$TMP/opencode-iso.out"

: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" OPENCODE_DELEGATE_MCP_PROFILE="none" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-iso --task 'Test profile isolation' > "$TMP/codex-iso.out"
grep -q 'Exit: 0' "$TMP/codex-iso.out"
grep -q 'MCP profile: minimal' "$TMP/codex-iso.out"
if grep -q 'mcp_servers.cclsp.enabled=false' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected cclsp to remain enabled when OPENCODE_DELEGATE_MCP_PROFILE is set' >&2; exit 1
fi

# MCP profile: Global DELEGATE_MCP_PROFILE applies to both workers when specific override is omitted
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/user-config" DELEGATE_MCP_PROFILE="none" "$SCRIPT" --agent opencode --mode plan --id opencode-global --task 'Test global profile' > "$TMP/opencode-global.out"
grep -q 'Exit: 0' "$TMP/opencode-global.out"
grep -q 'MCP profile: none' "$TMP/opencode-global.out"

: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" DELEGATE_MCP_PROFILE="none" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-global --task 'Test global profile' > "$TMP/codex-global.out"
grep -q 'Exit: 0' "$TMP/codex-global.out"
grep -q 'MCP profile: none' "$TMP/codex-global.out"
grep -q 'mcp_servers.cclsp.enabled=false' "$CODEX_MOCK_CONFIG_LOG"

# MCP profile: Preservation of caller OPENCODE_CONFIG settings and allowed server definitions
cat > "$TMP/caller-opencode.json" <<'JSON'
{
  "provider": { "my-provider": { "apiKey": "xyz" } },
  "permissions": { "allow": ["read"] },
  "model": "custom/model",
  "custom_pattern": "contains ,} and ,] verbatim",
  "mcp": {
    "cclsp": { "command": "/usr/local/bin/cclsp" },
    "slack": { "command": "npx -y slack-server" }
  }
}
JSON
: >"$OPENCODE_MOCK_CONFIG_LOG"
OPENCODE_CONFIG="$TMP/caller-opencode.json" "$SCRIPT" --agent opencode --mode plan --id caller-preserve --task 'Preserve caller config' > "$TMP/caller-preserve.out"
grep -q 'Exit: 0' "$TMP/caller-preserve.out"
CALLER_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/caller-preserve.out" | head -n 1)
jq -e '.provider["my-provider"].apiKey == "xyz"' "$CALLER_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.permissions.allow[0] == "read"' "$CALLER_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.model == "custom/model"' "$CALLER_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.custom_pattern == "contains ,} and ,] verbatim"' "$CALLER_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["cclsp"].command == "/usr/local/bin/cclsp"' "$CALLER_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["slack"].enabled == false' "$CALLER_LOG_DIR/opencode-profile.json" >/dev/null

# MCP profile: OpenCode opencode.jsonc discovery and JSONC syntax parsing
mkdir -p "$TMP/jsonc-config/opencode"
cat > "$TMP/jsonc-config/opencode/opencode.jsonc" <<'JSONC'
{
  // Single line comment
  /* Multi
     line
     comment */
  "url": "https://example.com/api",
  "string_with_comma_brace": "contains ,} and ,] verbatim",
  "mcp": {
    "cclsp": {
      "command": "/usr/local/bin/cclsp",
    },
    "slack": {
      "command": "npx -y slack-server",
    },
  },
}
JSONC
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/jsonc-config" "$SCRIPT" --agent opencode --mode plan --id jsonc-test --task 'Test jsonc parsing' > "$TMP/jsonc-test.out"
grep -q 'Exit: 0' "$TMP/jsonc-test.out"
JSONC_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/jsonc-test.out" | head -n 1)
jq -e '.mcp["slack"].enabled == false' "$JSONC_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp | has("cclsp") | not' "$JSONC_LOG_DIR/opencode-profile.json" >/dev/null

# MCP profile: Malformed user OpenCode config falls back gracefully and filters via allowed list
mkdir -p "$TMP/bad-json-config/opencode"
printf '{ malformed json: not valid' > "$TMP/bad-json-config/opencode/opencode.json"
: >"$OPENCODE_MOCK_CONFIG_LOG"
XDG_CONFIG_HOME="$TMP/bad-json-config" OPENCODE_DELEGATE_MCP_SERVERS="docker" "$SCRIPT" --agent opencode --mode plan --id bad-json --task 'Handle malformed config' > "$TMP/bad-json.out"
grep -q 'Exit: 0' "$TMP/bad-json.out"
BAD_JSON_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/bad-json.out" | head -n 1)
jq -e '.mcp | has("docker") | not' "$BAD_JSON_LOG_DIR/opencode-profile.json" >/dev/null
jq -e '.mcp["slack"].enabled == false' "$BAD_JSON_LOG_DIR/opencode-profile.json" >/dev/null

# Relative DELEGATE_WORKTREE_ROOT is resolved to absolute paths
: >"$OPENCODE_MOCK_CONFIG_LOG"
DELEGATE_WORKTREE_ROOT="./rel-worktrees" "$SCRIPT" --agent opencode --mode plan --id rel-worktree --task 'Test relative worktree' > "$TMP/rel-worktree.out"
grep -q 'Exit: 0' "$TMP/rel-worktree.out"
LAST_REL_CFG=$(tail -n 1 "$OPENCODE_MOCK_CONFIG_LOG")
[[ "$LAST_REL_CFG" =~ ^/ ]]
rm -rf rel-worktrees

# Codex: Missing config.toml emits zero -c overrides instead of undefined servers
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-cfg-check --task 'Codex with config' > "$TMP/codex-cfg-check.out"
grep -q 'Exit: 0' "$TMP/codex-cfg-check.out"
[[ -s "$CODEX_MOCK_CONFIG_LOG" ]]

: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/nonexistent/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-no-cfg --task 'Codex with no config' > "$TMP/codex-no-cfg.out"
grep -q 'Exit: 0' "$TMP/codex-no-cfg.out"
[[ ! -s "$CODEX_MOCK_CONFIG_LOG" ]]

# Codex: Custom profile does not emit overrides for undefined servers
cat > "$TMP/custom-unknown.json" <<'JSON'
{
  "mcp": {
    "slack": { "enabled": false },
    "unknown-server": { "enabled": false }
  }
}
JSON
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --mcp-profile "$TMP/custom-unknown.json" --id codex-custom-defined --task 'Codex custom defined only' > "$TMP/codex-custom-defined.out"
grep -q 'Exit: 0' "$TMP/codex-custom-defined.out"
grep -q 'mcp_servers.slack.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
if grep -q 'mcp_servers.unknown-server.enabled=false' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected unknown server not to be emitted for Codex' >&2; exit 1
fi

# Codex: Nested TOML tables (.env) do not produce invalid server overrides
mkdir -p "$TMP/nested-codex"
cat > "$TMP/nested-codex/config.toml" <<'TOML'
[mcp_servers.node_repl]
command = "/path/to/node_repl"

[mcp_servers.node_repl.env]
NODE_ENV = "production"
TOKEN = "secret"
TOML
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/nested-codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-nested --task 'Codex nested toml' > "$TMP/codex-nested.out"
grep -q 'Exit: 0' "$TMP/codex-nested.out"
grep -q 'mcp_servers.node_repl.enabled=false' "$CODEX_MOCK_CONFIG_LOG"
if grep -q 'mcp_servers.node_repl.env' "$CODEX_MOCK_CONFIG_LOG"; then
  echo 'Expected nested table .env not to be emitted as a server override' >&2; exit 1
fi

# Codex: Quoted server names containing dots produce quoted override paths
mkdir -p "$TMP/quoted-codex"
cat > "$TMP/quoted-codex/config.toml" <<'TOML'
[mcp_servers."foo.bar"]
command = "/path/to/foo_bar"

[mcp_servers.plain_server]
command = "/path/to/plain"
TOML
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/quoted-codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-quoted --task 'Codex quoted server' > "$TMP/codex-quoted.out"
grep -q 'Exit: 0' "$TMP/codex-quoted.out"
grep -q 'mcp_servers."foo.bar".enabled=false' "$CODEX_MOCK_CONFIG_LOG"
grep -q 'mcp_servers.plain_server.enabled=false' "$CODEX_MOCK_CONFIG_LOG"

# OpenCode: Inline OPENCODE_CONFIG_CONTENT is emitted to override project-level configs
OPENCODE_MOCK_CONTENT_LOG="$TMP/opencode-content.log"
: >"$OPENCODE_MOCK_CONTENT_LOG"
"$SCRIPT" --agent opencode --mode plan --id opencode-content-test --task 'OpenCode inline content' > "$TMP/opencode-content.out"
grep -q 'Exit: 0' "$TMP/opencode-content.out"
[[ -s "$OPENCODE_MOCK_CONTENT_LOG" ]]
jq -e '.mcp["slack"].enabled == false' "$OPENCODE_MOCK_CONTENT_LOG" >/dev/null
jq -e '.mcp | has("cclsp") | not' "$OPENCODE_MOCK_CONTENT_LOG" >/dev/null

# OpenCode: Project config committed at BASE_SHA is discovered by server discovery
git checkout -b base-sha-test-branch >/dev/null 2>&1
cat > opencode.json <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "git_blob_server": {
      "command": "/usr/local/bin/git_blob_server"
    }
  }
}
JSON
git add opencode.json
git commit -m "test: commit opencode.json for base sha test" >/dev/null 2>&1
TEST_BASE_SHA=$(git rev-parse HEAD)
git checkout - >/dev/null 2>&1
git branch -D base-sha-test-branch >/dev/null 2>&1
rm -f opencode.json

: >"$OPENCODE_MOCK_CONTENT_LOG"
"$SCRIPT" --agent opencode --mode plan --base "$TEST_BASE_SHA" --id base-sha-test --task 'Discover from BASE_SHA' > "$TMP/base-sha-test.out"
grep -q 'Exit: 0' "$TMP/base-sha-test.out"
jq -e '.mcp["git_blob_server"].enabled == false' "$OPENCODE_MOCK_CONTENT_LOG" >/dev/null

# A dirty checkout must be rejected rather than silently excluded from snapshot.
echo local > local.txt
if "$SCRIPT" --agent opencode --mode build --task 'Nope' >"$TMP/dirty.out" 2>&1; then
 echo 'Expected dirty-tree rejection' >&2; exit 1
fi
grep -q 'uncommitted or untracked' "$TMP/dirty.out"

echo 'PASS: All delegation tests passed across Codex, OpenCode, and Copilot'
