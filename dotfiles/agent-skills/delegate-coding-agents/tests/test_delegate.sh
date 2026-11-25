#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)/scripts
SCRIPT="$SCRIPT_DIR/delegate.sh"
ANALYZE_SCRIPT="$SCRIPT_DIR/delegate-analyze.sh"
IMPLEMENT_SCRIPT="$SCRIPT_DIR/delegate-implement.sh"
TMP=$(mktemp -d)
cleanup() {
  git -C "$TMP/repo" config --local --unset agents.delegationAllowed 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/bin" "$TMP/repo"
: > "$TMP/empty-global.gitconfig"
export GIT_CONFIG_GLOBAL="$TMP/empty-global.gitconfig" GIT_CONFIG_NOSYSTEM=1

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
if [[ ${OPENCODE_MOCK_RENAME_FILE:-} == 1 && $mode == build && -f rename-src.txt ]]; then
  git mv rename-src.txt rename-dst.txt
elif [[ $mode == build ]]; then
  printf 'implemented by opencode\n' > agent-change.txt
  if [[ ${OPENCODE_MOCK_TRAILING_WS:-} == 1 ]]; then
    printf 'trailing whitespace   \n' >> source.txt
  fi
  if [[ -n ${OPENCODE_MOCK_TOUCH_FILES:-} ]]; then
    IFS=',' read -ra touch_paths <<< "$OPENCODE_MOCK_TOUCH_FILES"
    for tp in "${touch_paths[@]}"; do
      mkdir -p "$(dirname "$tp")"
      printf 'mock change\n' > "$tp"
    done
  fi
fi
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
    --disable-builtin-mcps)
      [[ -z ${COPILOT_MOCK_MCP_LOG:-} ]] || printf '%s\n' '--disable-builtin-mcps' >>"$COPILOT_MOCK_MCP_LOG"
      ;;
    --disable-mcp-server)
      shift
      [[ -z ${COPILOT_MOCK_MCP_LOG:-} ]] || printf '%s\n' "$1" >>"$COPILOT_MOCK_MCP_LOG"
      ;;
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
export COPILOT_MOCK_MCP_LOG="$TMP/copilot.mcp"
export CODEX_MOCK_CALL_LOG="$TMP/codex.calls"
export CODEX_MOCK_CONFIG_LOG="$TMP/codex.config"
unset OPENCODE_DELEGATE_MODEL OPENCODE_DELEGATE_MODELS COPILOT_DELEGATE_MODEL CODEX_DELEGATE_MODEL OPENCODE_DELEGATE_MCP_PROFILE OPENCODE_DELEGATE_MCP_SERVERS OPENCODE_MCP_PROFILE DELEGATE_MCP_PROFILE DELEGATE_MCP_SERVERS CODEX_DELEGATE_MCP_PROFILE CODEX_DELEGATE_MCP_SERVERS COPILOT_DELEGATE_MCP_PROFILE COPILOT_DELEGATE_MCP_SERVERS COPILOT_MCP_CONFIG COPILOT_DIR COPILOT_HOME

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

# Automatic delegation runs without requiring repository opt-in in git config and records delegation_policy=default.
git config --local --unset agents.delegationAllowed 2>/dev/null || true
"$SCRIPT" --agent opencode --mode plan --orchestrator codex --automatic --id no-opt-in-needed --task 'Allowed without opt-in' >"$TMP/no-opt-in.out" 2>&1
grep -q 'Exit: 0' "$TMP/no-opt-in.out"
if grep -q 'agents.delegationAllowed true' "$TMP/no-opt-in.out"; then
  echo 'Unexpected opt-in gate error' >&2; exit 1
fi
no_opt_in_log=$(sed -n 's/^  Logs: //p' "$TMP/no-opt-in.out" | head -n 1)
grep -q '^delegation_policy=default$' "$no_opt_in_log/manifest.txt"

# Per-repo opt-out (false, 0, no, off, Off, whitespace-padded, empty) blocks delegation with or without --automatic before worktree/log/provider execution.
for opt_out_val in false 0 no off Off ' off ' ''; do
  git config --local agents.delegationAllowed "$opt_out_val"
  for auto_flag in '' '--automatic'; do
    : >"$OPENCODE_MOCK_CALL_LOG"
    : >"$CODEX_MOCK_CALL_LOG"
    : >"$COPILOT_MOCK_CALL_LOG"
    before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
    before_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    args=(--agent opencode --mode plan --id "opt-out-${opt_out_val:-empty}" --task 'Blocked by repo opt-out')
    if [[ -n $auto_flag ]]; then args+=("$auto_flag"); fi
    if "$SCRIPT" "${args[@]}" >"$TMP/opt-out.out" 2>"$TMP/opt-out.err"; then
      echo "Expected agents.delegationAllowed='$opt_out_val' (${auto_flag:-no --automatic}) to block delegation" >&2; exit 1
    fi
    grep -q "External delegation is disabled for this repository (agents.delegationAllowed=$opt_out_val)" "$TMP/opt-out.err"
    after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
    after_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    [[ $before_wt_count -eq $after_wt_count ]]
    [[ $before_log_count -eq $after_log_count ]]
    [[ ! -s $OPENCODE_MOCK_CALL_LOG && ! -s $CODEX_MOCK_CALL_LOG && ! -s $COPILOT_MOCK_CALL_LOG ]]
  done
done
git config --local --unset agents.delegationAllowed 2>/dev/null || true

# Global opt-out via isolated GIT_CONFIG_GLOBAL blocks delegation, and local true/1/yes/on/TRUE overrides it.
: > "$TMP/global-opt-out.gitconfig"
GIT_CONFIG_GLOBAL="$TMP/global-opt-out.gitconfig" git config --global agents.delegationAllowed false
: >"$OPENCODE_MOCK_CALL_LOG"
: >"$CODEX_MOCK_CALL_LOG"
: >"$COPILOT_MOCK_CALL_LOG"
before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
before_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
if GIT_CONFIG_GLOBAL="$TMP/global-opt-out.gitconfig" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id global-opt-out --task 'Blocked by global opt-out' >"$TMP/global-opt-out.out" 2>"$TMP/global-opt-out.err"; then
  echo 'Expected global agents.delegationAllowed=false to block delegation' >&2; exit 1
fi
grep -q 'External delegation is disabled for this repository (agents.delegationAllowed=false, scope=global)' "$TMP/global-opt-out.err"
after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
after_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
[[ $before_wt_count -eq $after_wt_count ]]
[[ $before_log_count -eq $after_log_count ]]
[[ ! -s $OPENCODE_MOCK_CALL_LOG && ! -s $CODEX_MOCK_CALL_LOG && ! -s $COPILOT_MOCK_CALL_LOG ]]

for allow_val in true 1 yes on TRUE; do
  git config --local agents.delegationAllowed "$allow_val"
  GIT_CONFIG_GLOBAL="$TMP/global-opt-out.gitconfig" "$SCRIPT" --agent opencode --mode plan --id "local-override-$allow_val" --task 'Local override of global opt-out' >"$TMP/local-override.out" 2>"$TMP/local-override.err"
  grep -q 'Exit: 0' "$TMP/local-override.out"
  override_log_dir=$(sed -n 's/^  Logs: //p' "$TMP/local-override.out" | head -n 1)
  grep -q '^delegation_policy=explicit_allow$' "$override_log_dir/manifest.txt"
done
git config --local --unset agents.delegationAllowed 2>/dev/null || true

# Missing --show-scope support (Git < 2.26) falls back to an explicit scope-unknown message.
mkdir -p "$TMP/bin-git-no-scope"
REAL_GIT=$(command -v git)
cat > "$TMP/bin-git-no-scope/git" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ $arg == --show-scope ]]; then
    echo 'error: unknown option --show-scope' >&2
    exit 129
  fi
done
exec "$REAL_GIT_BIN" "$@"
MOCK
chmod +x "$TMP/bin-git-no-scope/git"
git config --local agents.delegationAllowed false
if REAL_GIT_BIN="$REAL_GIT" PATH="$TMP/bin-git-no-scope:$PATH" "$SCRIPT" --agent opencode --mode plan --id no-show-scope --task 'Fallback scope unknown message' >"$TMP/no-show-scope.out" 2>"$TMP/no-show-scope.err"; then
  echo 'Expected opt-out without --show-scope to block delegation' >&2; exit 1
fi
grep -q 'External delegation is disabled for this repository (agents.delegationAllowed=false, scope unknown). Check local, global, or system Git config' "$TMP/no-show-scope.err"
git config --local --unset agents.delegationAllowed 2>/dev/null || true

# Invalid agents.delegationAllowed value and malformed Git config fail closed before worktree/log/provider execution.
git config --local agents.delegationAllowed maybe
: >"$OPENCODE_MOCK_CALL_LOG"
: >"$CODEX_MOCK_CALL_LOG"
: >"$COPILOT_MOCK_CALL_LOG"
before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
before_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
if "$SCRIPT" --agent opencode --mode plan --id invalid-policy --task 'Reject invalid policy value' >"$TMP/invalid-policy.out" 2>"$TMP/invalid-policy.err"; then
  echo 'Expected invalid agents.delegationAllowed=maybe to fail closed' >&2; exit 1
fi
grep -q "Invalid git config value for agents.delegationAllowed: 'maybe' (expected true/false/1/0/yes/no/on/off)" "$TMP/invalid-policy.err"
after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
after_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
[[ $before_wt_count -eq $after_wt_count ]]
[[ $before_log_count -eq $after_log_count ]]
[[ ! -s $OPENCODE_MOCK_CALL_LOG && ! -s $CODEX_MOCK_CALL_LOG && ! -s $COPILOT_MOCK_CALL_LOG ]]
git config --local --unset agents.delegationAllowed 2>/dev/null || true

printf '[broken\n' > "$TMP/malformed-global.gitconfig"
before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
before_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
if GIT_CONFIG_GLOBAL="$TMP/malformed-global.gitconfig" "$SCRIPT" --agent opencode --mode plan --id malformed-cfg --task 'Fail closed on malformed git config' >"$TMP/malformed-cfg.out" 2>"$TMP/malformed-cfg.err"; then
  echo 'Expected malformed git config to fail closed' >&2; exit 1
fi
grep -Eq 'Run inside a Git repository|Failed reading agents.delegationAllowed from Git config' "$TMP/malformed-cfg.err"
after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 ! -name logs | wc -l)
after_log_count=$(find "$DELEGATE_WORKTREE_ROOT/logs" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
[[ $before_wt_count -eq $after_wt_count ]]
[[ $before_log_count -eq $after_log_count ]]
[[ ! -s $OPENCODE_MOCK_CALL_LOG && ! -s $CODEX_MOCK_CALL_LOG && ! -s $COPILOT_MOCK_CALL_LOG ]]

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

# Codex: Custom TOML profile disabling unquoted server emits override
cat > "$TMP/custom-slack.toml" <<'TOML'
[mcp_servers.slack]
enabled = false
TOML
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --mcp-profile "$TMP/custom-slack.toml" --id codex-custom-toml-slack --task 'Codex custom toml slack' > "$TMP/codex-custom-toml-slack.out"
grep -q 'Exit: 0' "$TMP/codex-custom-toml-slack.out"
grep -q 'mcp_servers.slack.enabled=false' "$CODEX_MOCK_CONFIG_LOG"

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

# Codex: Dotted server names fail Codex invocation with clear error without blocking other workers or full profile
mkdir -p "$TMP/quoted-codex"
cat > "$TMP/quoted-codex/config.toml" <<'TOML'
[mcp_servers."foo.bar"]
command = "/path/to/foo_bar"

[mcp_servers.plain_server]
command = "/path/to/plain"
TOML
: >"$CODEX_MOCK_CONFIG_LOG"
CODEX_CONFIG="$TMP/quoted-codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id codex-quoted --task 'Codex quoted server' > "$TMP/codex-quoted.out" 2>"$TMP/codex-quoted.err" || true
grep -q 'Codex CLI does not support disabling dotted MCP server names' "$TMP/codex-quoted.err"

# Full profile on Codex is not blocked by dotted server names
CODEX_CONFIG="$TMP/quoted-codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mcp-profile full --mode plan --id codex-full-quoted --task 'Codex full profile with quoted server' > "$TMP/codex-full-quoted.out"
grep -q 'Exit: 0' "$TMP/codex-full-quoted.out"

# Other workers (OpenCode) are not blocked by Codex dotted servers
CODEX_CONFIG="$TMP/quoted-codex/config.toml" "$SCRIPT" --orchestrator agy --agent opencode --mode plan --id opencode-unblocked --task 'OpenCode worker unaffected' > "$TMP/opencode-unblocked.out"
grep -q 'Exit: 0' "$TMP/opencode-unblocked.out"

# Codex: Custom TOML profile disabling quoted dotted server is parsed and fails closed
cat > "$TMP/custom-dotted.toml" <<'TOML'
[mcp_servers."foo.bar"]
enabled = false
TOML
CODEX_CONFIG="$TMP/quoted-codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --mode plan --mcp-profile "$TMP/custom-dotted.toml" --id codex-custom-dotted --task 'Codex custom dotted' > "$TMP/codex-custom-dotted.out" 2>"$TMP/codex-custom-dotted.err" || true
grep -q 'Codex CLI does not support disabling dotted MCP server names' "$TMP/codex-custom-dotted.err"

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

# MCP profile for Copilot: Minimal profile isolation via --disable-mcp-server and non-mutation of user config
mkdir -p "$TMP/user-config/copilot"
cat > "$TMP/user-config/copilot/mcp-config.json" <<'JSON'
{
  "mcpServers": {
    "cclsp": { "type": "local", "command": "/usr/local/bin/cclsp", "args": [], "tools": ["*"] },
    "ai-memory": { "type": "local", "command": "ai-memory", "args": [], "tools": ["*"] },
    "slack": { "type": "local", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-slack"], "tools": ["*"] },
    "uptime-kuma": { "type": "local", "command": "npx", "args": ["-y", "@davidfuchs/mcp-uptime-kuma"], "tools": ["*"] },
    "docker": { "type": "local", "command": "npx", "args": ["-y", "@hypnosis/docker-mcp-server"], "tools": ["*"] }
  }
}
JSON
ORIG_COPILOT_CFG_HASH=$(hash_file "$TMP/user-config/copilot/mcp-config.json")

: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --id copilot-mcp-minimal --task 'Test copilot minimal MCP profile' > "$TMP/copilot-mcp-minimal.out"
grep -q 'Exit: 0' "$TMP/copilot-mcp-minimal.out"
grep -q 'Worker: copilot' "$TMP/copilot-mcp-minimal.out"
grep -q 'MCP profile: minimal' "$TMP/copilot-mcp-minimal.out"
COPILOT_MCP_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/copilot-mcp-minimal.out" | head -n 1)
[[ -f "$COPILOT_MCP_LOG_DIR/copilot-mcp-overrides.txt" ]]
grep -q 'mcp_profile=minimal' "$COPILOT_MCP_LOG_DIR/manifest.txt"
grep -q "mcp_profile_path=$COPILOT_MCP_LOG_DIR/copilot-mcp-overrides.txt" "$COPILOT_MCP_LOG_DIR/manifest.txt"
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'ai-memory' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'uptime-kuma' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'docker' "$COPILOT_MOCK_MCP_LOG"
if grep -qx 'cclsp' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected cclsp to remain enabled for copilot minimal profile' >&2; exit 1
fi
POST_COPILOT_CFG_HASH=$(hash_file "$TMP/user-config/copilot/mcp-config.json")
[[ "$ORIG_COPILOT_CFG_HASH" == "$POST_COPILOT_CFG_HASH" ]]

# MCP profile for Copilot: --mcp-profile none disables all servers
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile none --id copilot-mcp-none --task 'Test copilot none MCP profile' > "$TMP/copilot-mcp-none.out"
grep -q 'Exit: 0' "$TMP/copilot-mcp-none.out"
grep -q 'MCP profile: none' "$TMP/copilot-mcp-none.out"
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'cclsp' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'ai-memory' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'uptime-kuma' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'docker' "$COPILOT_MOCK_MCP_LOG"

# MCP profile for Copilot: --mcp-profile full emits zero --disable-mcp-server flags
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile full --id copilot-mcp-full --task 'Test copilot full MCP profile' > "$TMP/copilot-mcp-full.out"
grep -q 'Exit: 0' "$TMP/copilot-mcp-full.out"
grep -q 'MCP profile: full' "$TMP/copilot-mcp-full.out"
[[ ! -s "$COPILOT_MOCK_MCP_LOG" ]]
COPILOT_FULL_LOG_DIR=$(sed -n 's/^  Logs: //p' "$TMP/copilot-mcp-full.out" | head -n 1)
grep -q 'mcp_profile=full' "$COPILOT_FULL_LOG_DIR/manifest.txt"
grep -q 'mcp_profile_path=(none)' "$COPILOT_FULL_LOG_DIR/manifest.txt"

# MCP profile for Copilot: COPILOT_DELEGATE_MCP_SERVERS allowlist override
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" COPILOT_DELEGATE_MCP_SERVERS="docker,cclsp" "$SCRIPT" --agent copilot --mode plan --id copilot-mcp-override --task 'Test copilot servers override' > "$TMP/copilot-mcp-override.out"
grep -q 'Exit: 0' "$TMP/copilot-mcp-override.out"
if grep -qx 'docker' "$COPILOT_MOCK_MCP_LOG" || grep -qx 'cclsp' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected docker and cclsp to remain enabled in copilot override' >&2; exit 1
fi
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'ai-memory' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"

# MCP profile for Copilot: Custom JSON allowlist profile (Copilot mcp-config.json schema)
cat > "$TMP/custom-copilot-allow.json" <<'JSON'
{
  "mcpServers": {
    "cclsp": { "type": "local", "command": "/usr/local/bin/cclsp" },
    "docker": { "type": "local", "command": "npx" }
  }
}
JSON
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile "$TMP/custom-copilot-allow.json" --id copilot-custom-allow --task 'Test copilot custom allowlist' > "$TMP/copilot-custom-allow.out"
grep -q 'Exit: 0' "$TMP/copilot-custom-allow.out"
if grep -qx 'docker' "$COPILOT_MOCK_MCP_LOG" || grep -qx 'cclsp' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected custom allowlist servers to remain enabled for Copilot' >&2; exit 1
fi
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'uptime-kuma' "$COPILOT_MOCK_MCP_LOG"

# MCP profile for Copilot: Environment isolation and global DELEGATE_MCP_PROFILE inheritance
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" CODEX_DELEGATE_MCP_PROFILE="none" OPENCODE_DELEGATE_MCP_PROFILE="none" "$SCRIPT" --agent copilot --mode plan --id copilot-iso --task 'Test copilot env isolation' > "$TMP/copilot-iso.out"
grep -q 'Exit: 0' "$TMP/copilot-iso.out"
grep -q 'MCP profile: minimal' "$TMP/copilot-iso.out"
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
if grep -qx 'cclsp' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected CODEX/OPENCODE env profiles not to alter copilot profile' >&2; exit 1
fi

: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" DELEGATE_MCP_PROFILE="none" "$SCRIPT" --agent copilot --mode plan --id copilot-global --task 'Test copilot global profile' > "$TMP/copilot-global.out"
grep -q 'Exit: 0' "$TMP/copilot-global.out"
grep -q 'MCP profile: none' "$TMP/copilot-global.out"
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'cclsp' "$COPILOT_MOCK_MCP_LOG"

# MCP profile for Copilot: Repo-local .mcp.json and .github/mcp.json at BASE_SHA are discovered and isolated
git checkout -b copilot-repo-mcp-branch >/dev/null 2>&1
cat > .mcp.json <<'JSON'
{
  "repo_claude_server": { "command": "/usr/local/bin/repo_claude_server" },
  "fetch": { "command": "uvx mcp-server-fetch" },
  "git": { "command": "uvx mcp-server-git" }
}
JSON
mkdir -p .github
cat > .github/mcp.json <<'JSON'
{
  "mcpServers": {
    "repo_gh_server": { "command": "/usr/local/bin/repo_gh_server" }
  }
}
JSON
git add .mcp.json .github/mcp.json
git commit -m "test: commit repo mcp configs for copilot base sha test" >/dev/null 2>&1
COPILOT_BASE_SHA=$(git rev-parse HEAD)
git checkout - >/dev/null 2>&1
git branch -D copilot-repo-mcp-branch >/dev/null 2>&1
rm -rf .mcp.json .github

: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --base "$COPILOT_BASE_SHA" --id copilot-base-sha --task 'Discover repo MCP configs for copilot' > "$TMP/copilot-base-sha.out"
grep -q 'Exit: 0' "$TMP/copilot-base-sha.out"
# COPILOT_MOCK_MCP_LOG records server names passed to --disable-mcp-server (disallowed servers)
grep -qx 'repo_claude_server' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'repo_gh_server' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'git' "$COPILOT_MOCK_MCP_LOG"
if grep -qx 'fetch' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected allowed minimal server fetch in .mcp.json not to be passed to --disable-mcp-server' >&2; exit 1
fi

# MCP profile for Copilot: Malformed or unsupported custom profile fails closed
printf '{ malformed json\n' > "$TMP/bad-copilot-profile.json"
if COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile "$TMP/bad-copilot-profile.json" --id copilot-bad-profile --task 'Reject malformed profile' >"$TMP/copilot-bad-profile.out" 2>&1; then
  echo 'Expected malformed Copilot custom profile to fail' >&2; exit 1
fi
grep -q 'Failed to resolve Copilot MCP profile' "$TMP/copilot-bad-profile.out"

printf '{"unexpected": "scalar"}\n' > "$TMP/unsupported-copilot-profile.json"
if COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile "$TMP/unsupported-copilot-profile.json" --id copilot-unsupported-profile --task 'Reject unsupported profile' >"$TMP/copilot-unsupported-profile.out" 2>&1; then
  echo 'Expected unsupported Copilot custom profile structure to fail' >&2; exit 1
fi
grep -q 'Failed to resolve Copilot MCP profile' "$TMP/copilot-unsupported-profile.out"

# MCP profile for Copilot: Malformed or non-table TOML server entries fail closed
cat > "$TMP/bad-copilot-toml-scalar.toml" <<'TOML'
[mcp_servers]
slack = false
TOML
if COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile "$TMP/bad-copilot-toml-scalar.toml" --id copilot-bad-toml-scalar --task 'Reject non-table TOML server entry' >"$TMP/copilot-bad-toml-scalar.out" 2>&1; then
  echo 'Expected non-table TOML server entry to fail' >&2; exit 1
fi
grep -q 'Failed to resolve Copilot MCP profile' "$TMP/copilot-bad-toml-scalar.out"

cat > "$TMP/bad-copilot-toml-bool.toml" <<'TOML'
[mcp_servers.slack]
enabled = "false"
TOML
if COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile "$TMP/bad-copilot-toml-bool.toml" --id copilot-bad-toml-bool --task 'Reject non-boolean TOML enabled flag' >"$TMP/copilot-bad-toml-bool.out" 2>&1; then
  echo 'Expected non-boolean TOML enabled flag to fail' >&2; exit 1
fi
grep -q 'Failed to resolve Copilot MCP profile' "$TMP/copilot-bad-toml-bool.out"

cat > "$TMP/valid-copilot-toml-deny.toml" <<'TOML'
[mcp_servers.slack]
enabled = false
TOML
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" "$SCRIPT" --agent copilot --mode plan --mcp-profile "$TMP/valid-copilot-toml-deny.toml" --id copilot-valid-toml --task 'Apply valid TOML disable profile' >"$TMP/copilot-valid-toml.out"
grep -q 'Exit: 0' "$TMP/copilot-valid-toml.out"
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"
if grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected built-in MCPs to stay enabled unless explicitly disabled in denylist TOML' >&2; exit 1
fi

# MCP profile for Copilot: --mcp-profile none still disables built-ins with no config files
mkdir -p "$TMP/empty-copilot-home"
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/empty-copilot-home" "$SCRIPT" --agent copilot --mode plan --mcp-profile none --id copilot-empty-none --task 'Disable built-ins with empty config' >"$TMP/copilot-empty-none.out"
grep -q 'Exit: 0' "$TMP/copilot-empty-none.out"
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"

# MCP profile for Copilot: Allowing github-mcp-server explicitly omits --disable-builtin-mcps
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/user-config/copilot" COPILOT_DELEGATE_MCP_SERVERS="github-mcp-server,cclsp" "$SCRIPT" --agent copilot --mode plan --id copilot-allow-builtin --task 'Allow github-mcp-server explicitly' >"$TMP/copilot-allow-builtin.out"
grep -q 'Exit: 0' "$TMP/copilot-allow-builtin.out"
if grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected --disable-builtin-mcps to be omitted when github-mcp-server is allowed' >&2; exit 1
fi
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"

# MCP profile for Copilot: Discovery uses COPILOT_HOME (not COPILOT_DIR or COPILOT_MCP_CONFIG)
mkdir -p "$TMP/copilot-home-only" "$TMP/copilot-dir-other"
cat > "$TMP/copilot-home-only/mcp-config.json" <<'JSON'
{
  "mcpServers": {
    "slack": { "type": "local", "command": "npx" }
  }
}
JSON
cat > "$TMP/copilot-dir-other/mcp-config.json" <<'JSON'
{
  "mcpServers": {
    "docker": { "type": "local", "command": "npx" }
  }
}
JSON
: >"$COPILOT_MOCK_MCP_LOG"
COPILOT_HOME="$TMP/copilot-home-only" COPILOT_DIR="$TMP/copilot-dir-other" COPILOT_MCP_CONFIG="$TMP/copilot-dir-other/mcp-config.json" "$SCRIPT" --agent copilot --mode plan --mcp-profile none --id copilot-home-precedence --task 'Match COPILOT_HOME worker config' >"$TMP/copilot-home-precedence.out"
grep -q 'Exit: 0' "$TMP/copilot-home-precedence.out"
grep -qx -- '--disable-builtin-mcps' "$COPILOT_MOCK_MCP_LOG"
grep -qx 'slack' "$COPILOT_MOCK_MCP_LOG"
if grep -qx 'docker' "$COPILOT_MOCK_MCP_LOG"; then
  echo 'Expected resolver not to discover from COPILOT_DIR or COPILOT_MCP_CONFIG when COPILOT_HOME differs' >&2; exit 1
fi

# MCP profile for Copilot: A server literally named --disable-builtin-mcps still receives --disable-mcp-server
mkdir -p "$TMP/copilot-flag-collision"
cat > "$TMP/copilot-flag-collision/mcp-config.json" <<'JSON'
{
  "mcpServers": {
    "--disable-builtin-mcps": { "type": "local", "command": "npx" }
  }
}
JSON
: >"$COPILOT_MOCK_CALL_LOG"
COPILOT_HOME="$TMP/copilot-flag-collision" "$SCRIPT" --agent copilot --mode plan --mcp-profile none --id copilot-flag-collision --task 'Preserve server named like built-in flag' >"$TMP/copilot-flag-collision.out"
grep -q 'Exit: 0' "$TMP/copilot-flag-collision.out"
grep -q -- '--disable-mcp-server --disable-builtin-mcps' "$COPILOT_MOCK_CALL_LOG"

# MCP profile for Copilot: Unused COPILOT_DELEGATE_MCP_PROFILE does not break single-agent Codex runs
COPILOT_DELEGATE_MCP_PROFILE="$TMP/nonexistent-copilot-profile.json" CODEX_CONFIG="$TMP/user-config/codex/config.toml" "$SCRIPT" --orchestrator agy --agent codex --model custom-codex --mode plan --id codex-ignores-copilot-prof --task 'Ignore unused Copilot profile' > "$TMP/codex-ignores-copilot-prof.out"
grep -q 'Exit: 0' "$TMP/codex-ignores-copilot-prof.out"

# A dirty checkout runs from committed BASE_SHA with an explicit non-blocking warning and note.
expected_base_sha=$(git rev-parse HEAD)
echo local > local.txt
"$SCRIPT" --agent opencode --mode build --id dirty-base-allowed --task 'Run from HEAD despite dirty tree' >"$TMP/dirty.out" 2>"$TMP/dirty.err"
grep -q 'Exit: 0' "$TMP/dirty.out"
grep -q 'Base snapshot note: dirty base working tree' "$TMP/dirty.out"
if grep -q 'Overlapping dirty base files' "$TMP/dirty.out"; then
  echo 'Unexpected overlap report for non-overlapping dirty file' >&2; exit 1
fi
grep -q 'uncommitted or untracked changes' "$TMP/dirty.err"
dirty_log_dir=$(sed -n 's/^  Logs: //p' "$TMP/dirty.out")
dirty_worktree=$(sed -n 's/^  Worktree: //p' "$TMP/dirty.out")
grep -q 'dirty_base=1' "$dirty_log_dir/manifest.txt"
grep -q 'dirty_base_overlap=0' "$dirty_log_dir/manifest.txt"
[[ $(git -C "$dirty_worktree" rev-parse HEAD) == "$expected_base_sha" ]]
[[ ! -e "$dirty_worktree/local.txt" ]]
rm -f local.txt

# Overlapping dirty base files are flagged in manifest.txt, stderr, and DELEGATION_RESULT without clobbering local base files.
echo local-uncommitted > agent-change.txt
"$SCRIPT" --agent opencode --mode build --id dirty-base-overlap --task 'Detect overlap with dirty base file' >"$TMP/dirty-overlap.out" 2>"$TMP/dirty-overlap.err"
grep -q 'Exit: 0' "$TMP/dirty-overlap.out"
grep -q 'Overlapping dirty base files (reconcile hunks manually; do not overwrite base files):' "$TMP/dirty-overlap.out"
grep -q '^    agent-change.txt$' "$TMP/dirty-overlap.out"
grep -q 'Delegate modified files that also have uncommitted or untracked changes in base working tree' "$TMP/dirty-overlap.err"
overlap_log_dir=$(sed -n 's/^  Logs: //p' "$TMP/dirty-overlap.out")
grep -q 'dirty_base=1' "$overlap_log_dir/manifest.txt"
grep -q 'dirty_base_overlap=1' "$overlap_log_dir/manifest.txt"
grep -q '^agent-change.txt$' "$overlap_log_dir/overlapping-base-files.txt"
grep -q '^local-uncommitted$' agent-change.txt
rm -f agent-change.txt

# Renames by a worker must include source paths when checking dirty-base overlap.
printf 'line1\nline2\nline3\n' > rename-src.txt
git add rename-src.txt
git commit -m 'Add rename fixture' >/dev/null
printf 'local edit\n' >> rename-src.txt
OPENCODE_MOCK_RENAME_FILE=1 "$SCRIPT" --agent opencode --mode build --id dirty-base-rename-overlap --task 'Detect overlap when worker renames dirty base file' >"$TMP/dirty-rename.out" 2>"$TMP/dirty-rename.err"
grep -q 'Exit: 0' "$TMP/dirty-rename.out"
grep -q 'Overlapping dirty base files' "$TMP/dirty-rename.out"
grep -q '^    rename-src.txt$' "$TMP/dirty-rename.out"
rename_log_dir=$(sed -n 's/^  Logs: //p' "$TMP/dirty-rename.out")
grep -q 'dirty_base_overlap=1' "$rename_log_dir/manifest.txt"
grep -q '^rename-src.txt$' "$rename_log_dir/overlapping-base-files.txt"
git checkout -- rename-src.txt

# Missing candidate executable fallback and fail-closed checks on isolated PATH
SYS_BIN="$TMP/sys-bin"
mkdir -p "$SYS_BIN"
for tool in awk basename bash cat comm cp date dirname env git grep head jq mkdir mv pwd python3 rm sed sh sort tail tr wc; do
  if [[ $tool == python3 ]]; then
    # Resolve shim wrappers (such as pyenv) to the real interpreter binary before symlinking.
    tool_path=$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null || true)
  else
    tool_path=$(command -v "$tool" 2>/dev/null || true)
  fi
  if [[ -n $tool_path ]]; then
    ln -sf "$tool_path" "$SYS_BIN/$tool"
  fi
done

mkdir -p "$TMP/bin-no-codex" "$TMP/bin-only-copilot" "$TMP/bin-only-opencode" "$TMP/bin-empty"
ln -sf "$TMP/bin/opencode" "$TMP/bin-no-codex/opencode"
ln -sf "$TMP/bin/copilot" "$TMP/bin-no-codex/copilot"
ln -sf "$TMP/bin/copilot" "$TMP/bin-only-copilot/copilot"
ln -sf "$TMP/bin/opencode" "$TMP/bin-only-opencode/opencode"

# --orchestrator agy --agent codex advances to opencode when codex is absent from PATH
: >"$OPENCODE_MOCK_CALL_LOG"
CODEX_DELEGATE_MCP_PROFILE="$TMP/absent-codex.toml" PATH="$TMP/bin-no-codex:$SYS_BIN" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id missing-codex-plan --task 'Fallback to opencode when codex missing' >"$TMP/missing-codex-plan.out" 2>"$TMP/missing-codex-plan.err"
[[ -s "$OPENCODE_MOCK_CALL_LOG" ]]
grep -q 'Agent: codex (plan)' "$TMP/missing-codex-plan.out"
grep -q 'Worker: opencode' "$TMP/missing-codex-plan.out"
grep -q 'Model: opencode/deepseek-v4.1-flash-free' "$TMP/missing-codex-plan.out"
grep -q 'Exit: 0' "$TMP/missing-codex-plan.out"
grep -q 'Agent codex executable not found on PATH; skipping to next candidate' "$TMP/missing-codex-plan.err"
missing_codex_log=$(sed -n 's/^  Logs: //p' "$TMP/missing-codex-plan.out" | head -n 1)
grep -q 'agent=codex' "$missing_codex_log/manifest.txt"
grep -q 'resolved_agent=opencode' "$missing_codex_log/manifest.txt"

# Build mode also succeeds when codex is missing and falls through to opencode
PATH="$TMP/bin-no-codex:$SYS_BIN" "$SCRIPT" --orchestrator agy --agent codex --mode build --id missing-codex-build --task 'Build via opencode when codex missing' >"$TMP/missing-codex-build.out" 2>"$TMP/missing-codex-build.err"
grep -q 'Worker: opencode' "$TMP/missing-codex-build.out"
grep -q 'Exit: 0' "$TMP/missing-codex-build.out"
WT_MISSING_CODEX=$(sed -n 's/^  Worktree: //p' "$TMP/missing-codex-build.out" | head -n 1)
[[ -f $WT_MISSING_CODEX/agent-change.txt ]]

# --orchestrator agy --agent codex advances to copilot when both codex and opencode are absent
: >"$COPILOT_MOCK_CALL_LOG"
OPENCODE_DELEGATE_MCP_PROFILE="$TMP/absent-opencode.json" PATH="$TMP/bin-only-copilot:$SYS_BIN" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id missing-codex-opencode --task 'Fallback to copilot when codex and opencode missing' >"$TMP/missing-codex-opencode.out" 2>"$TMP/missing-codex-opencode.err"
[[ -s "$COPILOT_MOCK_CALL_LOG" ]]
grep -q 'Agent: codex (plan)' "$TMP/missing-codex-opencode.out"
grep -q 'Worker: copilot' "$TMP/missing-codex-opencode.out"
grep -q 'Model: auto' "$TMP/missing-codex-opencode.out"
grep -q 'Exit: 0' "$TMP/missing-codex-opencode.out"
missing_both_log=$(sed -n 's/^  Logs: //p' "$TMP/missing-codex-opencode.out" | head -n 1)
grep -q 'resolved_agent=copilot' "$missing_both_log/manifest.txt"

# --agent opencode advances to copilot when opencode is absent from PATH
PATH="$TMP/bin-only-copilot:$SYS_BIN" "$SCRIPT" --agent opencode --mode plan --id missing-opencode --task 'Fallback to copilot when opencode missing' >"$TMP/missing-opencode.out" 2>"$TMP/missing-opencode.err"
grep -q 'Agent: opencode (plan)' "$TMP/missing-opencode.out"
grep -q 'Worker: copilot' "$TMP/missing-opencode.out"
grep -q 'Model: auto' "$TMP/missing-opencode.out"
grep -q 'Exit: 0' "$TMP/missing-opencode.out"

# Missing all candidates in PATH fails non-zero with clear installation message and no worktree
before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 | wc -l)
if PATH="$TMP/bin-empty:$SYS_BIN" "$SCRIPT" --orchestrator agy --agent codex --mode plan --id missing-all-codex --task 'Fail when all candidates missing' >"$TMP/missing-all-codex.out" 2>"$TMP/missing-all-codex.err"; then
  echo 'Expected failure when all candidates are missing from PATH' >&2; exit 1
fi
grep -q 'No delegate CLI found on PATH (checked: codex, opencode, copilot)' "$TMP/missing-all-codex.err"
grep -q 'codex login' "$TMP/missing-all-codex.err"
grep -q 'opencode auth login' "$TMP/missing-all-codex.err"
grep -q 'copilot login' "$TMP/missing-all-codex.err"
after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 | wc -l)
[[ $before_wt_count -eq $after_wt_count ]]

if PATH="$TMP/bin-empty:$SYS_BIN" "$SCRIPT" --agent opencode --mode plan --id missing-all-opencode --task 'Fail when opencode and copilot missing' >"$TMP/missing-all-opencode.out" 2>"$TMP/missing-all-opencode.err"; then
  echo 'Expected failure when opencode and copilot are missing from PATH' >&2; exit 1
fi
grep -q 'No delegate CLI found on PATH (checked: opencode, copilot)' "$TMP/missing-all-opencode.err"
if grep -q 'codex login' "$TMP/missing-all-opencode.err"; then
  echo 'Unexpected advice to install Codex outside the candidate chain' >&2; exit 1
fi

# Pinned --model fails cleanly when that agent executable is missing even if fallbacks exist
: >"$OPENCODE_MOCK_CALL_LOG"
: >"$COPILOT_MOCK_CALL_LOG"
if PATH="$TMP/bin-no-codex:$SYS_BIN" "$SCRIPT" --orchestrator agy --agent codex --model custom-codex --mode plan --id pinned-missing-codex --task 'Pinned codex missing' >"$TMP/pinned-missing-codex.out" 2>"$TMP/pinned-missing-codex.err"; then
  echo 'Expected pinned codex invocation to fail when codex is missing' >&2; exit 1
fi
grep -q 'Install Codex CLI and authenticate with codex login first' "$TMP/pinned-missing-codex.err"
[[ ! -s $OPENCODE_MOCK_CALL_LOG && ! -s $COPILOT_MOCK_CALL_LOG ]]

if PATH="$TMP/bin-only-copilot:$SYS_BIN" "$SCRIPT" --agent opencode --model opencode/deepseek-v4.1-flash-free --mode plan --id pinned-missing-opencode --task 'Pinned opencode missing' >"$TMP/pinned-missing-opencode.out" 2>"$TMP/pinned-missing-opencode.err"; then
  echo 'Expected pinned opencode invocation to fail when opencode is missing' >&2; exit 1
fi
grep -q 'Install OpenCode CLI first' "$TMP/pinned-missing-opencode.err"
[[ ! -s $COPILOT_MOCK_CALL_LOG ]]

if PATH="$TMP/bin-only-opencode:$SYS_BIN" "$SCRIPT" --agent copilot --model auto --mode plan --id pinned-missing-copilot --task 'Pinned copilot missing' >"$TMP/pinned-missing-copilot.out" 2>"$TMP/pinned-missing-copilot.err"; then
  echo 'Expected pinned copilot invocation to fail when copilot is missing' >&2; exit 1
fi
grep -q 'Install GitHub Copilot CLI and authenticate with copilot login first' "$TMP/pinned-missing-copilot.err"

# Auth failure on fallback worker halts cleanly and records actual attempted agent
if PATH="$TMP/bin-no-codex:$SYS_BIN" OPENCODE_MOCK_FAIL_DEEPSEEK=1 OPENCODE_MOCK_FAIL_MSG='ProviderAuthError: authentication failed' "$SCRIPT" --orchestrator agy --agent codex --mode plan --id missing-codex-auth-fail --task 'Auth stop on fallback' >"$TMP/missing-codex-auth-fail.out" 2>&1; then
  echo 'Expected auth failure on fallback opencode to halt delegation' >&2; exit 1
fi
grep -q 'Stopping fallback' "$TMP/missing-codex-auth-fail.out"
grep -q 'Worker: opencode' "$TMP/missing-codex-auth-fail.out"
auth_fallback_log=$(sed -n 's/^  Logs: //p' "$TMP/missing-codex-auth-fail.out" | head -n 1)
grep -q 'resolved_agent=opencode' "$auth_fallback_log/manifest.txt"

# Quota exhaustion with missing trailing copilot keeps resolved_agent as last attempted worker (opencode)
if PATH="$TMP/bin-only-opencode:$SYS_BIN" OPENCODE_MOCK_FAIL_ALL=1 "$SCRIPT" --orchestrator agy --agent codex --mode plan --id missing-codex-copilot-quota --task 'Quota exhaustion without copilot' >"$TMP/missing-codex-copilot-quota.out" 2>&1; then
  echo 'Expected quota failure when only opencode is installed and fails all models' >&2; exit 1
fi
grep -q 'Worker: opencode' "$TMP/missing-codex-copilot-quota.out"
quota_only_opencode_log=$(sed -n 's/^  Logs: //p' "$TMP/missing-codex-copilot-quota.out" | head -n 1)
grep -q 'resolved_agent=opencode' "$quota_only_opencode_log/manifest.txt"

# Whitespace-only pinned model fails preflight before creating any worktree
before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 | wc -l)
if PATH="$TMP/bin-only-opencode:$SYS_BIN" "$SCRIPT" --agent opencode --model '   ' --mode plan --id whitespace-opencode-model --task 'Whitespace pinned model' >"$TMP/whitespace-model.out" 2>"$TMP/whitespace-model.err"; then
  echo 'Expected whitespace-only pinned opencode model to fail preflight' >&2; exit 1
fi
grep -q 'No runnable model configured for delegate agent opencode' "$TMP/whitespace-model.err"
after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 | wc -l)
[[ $before_wt_count -eq $after_wt_count ]]

# Whitespace OPENCODE_DELEGATE_MODEL skips empty primary slot cleanly when falling back from missing codex
: >"$OPENCODE_MOCK_CALL_LOG"
PATH="$TMP/bin-only-opencode:$SYS_BIN" OPENCODE_DELEGATE_MODEL='   ' "$SCRIPT" --orchestrator agy --agent codex --mode plan --id whitespace-env-model --task 'Fallback past whitespace env model' >"$TMP/whitespace-env.out" 2>"$TMP/whitespace-env.err"
grep -q 'Worker: opencode' "$TMP/whitespace-env.out"
grep -q 'Model: opencode/glm-5.3-flash-free' "$TMP/whitespace-env.out"
grep -q 'Exit: 0' "$TMP/whitespace-env.out"

# --mode plan --verify is rejected before creating a worktree
before_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 | wc -l)
if "$SCRIPT" --agent opencode --mode plan --verify 'true' --id plan-verify-reject --task 'Reject verify in plan mode' >"$TMP/plan-verify.out" 2>"$TMP/plan-verify.err"; then
  echo 'Expected --mode plan --verify to be rejected' >&2; exit 1
fi
grep -q -- '--verify is only supported with --mode build' "$TMP/plan-verify.err"
after_wt_count=$(find "$DELEGATE_WORKTREE_ROOT" -mindepth 1 -maxdepth 1 | wc -l)
[[ $before_wt_count -eq $after_wt_count ]]

# --verify-timeout rejects invalid values and --verify rejects empty command
for bad_timeout in 0 -5 abc; do
  if "$SCRIPT" --agent opencode --mode build --verify 'true' --verify-timeout "$bad_timeout" --id bad-timeout --task 'Reject bad timeout' >"$TMP/bad-timeout.out" 2>"$TMP/bad-timeout.err"; then
    echo "Expected --verify-timeout '$bad_timeout' to fail" >&2; exit 1
  fi
  grep -q -- '--verify-timeout must be a positive integer' "$TMP/bad-timeout.err"
done
if "$SCRIPT" --agent opencode --mode build --verify '   ' --id empty-verify --task 'Reject empty verify' >"$TMP/empty-verify.out" 2>"$TMP/empty-verify.err"; then
  echo 'Expected empty --verify command to fail' >&2; exit 1
fi
grep -q 'Verification command is empty' "$TMP/empty-verify.err"

# Omitted --verify on --mode build records Verification: none_configured and Failure category: none
"$SCRIPT" --agent opencode --mode build --id build-no-verify --task 'Build without verify' >"$TMP/build-no-verify.out"
grep -q 'Exit: 0' "$TMP/build-no-verify.out"
grep -q '  Failure category: none' "$TMP/build-no-verify.out"
grep -q '  Verification: none_configured' "$TMP/build-no-verify.out"
if grep -q '  Verification exit:' "$TMP/build-no-verify.out"; then
  echo 'Unexpected Verification exit line when --verify omitted' >&2; exit 1
fi
grep -q '^    (none)$' <(sed -n '/^  Modified test files:/,/^  Git changes:/p' "$TMP/build-no-verify.out")
no_verify_log=$(sed -n 's/^  Logs: //p' "$TMP/build-no-verify.out" | head -n 1)
grep -q '^verification=none_configured$' "$no_verify_log/manifest.txt"
grep -q '^verification_exit=(none)$' "$no_verify_log/manifest.txt"
grep -q '^failure_category=none$' "$no_verify_log/manifest.txt"

# --verify passing check runs inside worktree outside worker session and records passed status
# shellcheck disable=SC2016
"$SCRIPT" --agent opencode --mode build --verify 'test -f agent-change.txt && test -z "${CODING_DELEGATE_ACTIVE:-}" && echo verify-ok' --id verify-pass --task 'Verify passing build' >"$TMP/verify-pass.out"
grep -q 'Exit: 0' "$TMP/verify-pass.out"
grep -q '  Failure category: none' "$TMP/verify-pass.out"
grep -q '  Verification: passed' "$TMP/verify-pass.out"
grep -q '  Verification exit: 0' "$TMP/verify-pass.out"
grep -q '^    verify-ok$' "$TMP/verify-pass.out"
verify_pass_log=$(sed -n 's/^  Logs: //p' "$TMP/verify-pass.out" | head -n 1)
[[ -s $verify_pass_log/verify.log ]]
grep -q '^verification=passed$' "$verify_pass_log/manifest.txt"
grep -q '^verification_exit=0$' "$verify_pass_log/manifest.txt"
grep -q '^failure_category=none$' "$verify_pass_log/manifest.txt"

# --verify failing check sets EXIT_CODE=1, verification_error, and caps output at last 40 lines
# shellcheck disable=SC2016
if "$SCRIPT" --agent opencode --mode build --verify 'for i in $(seq 1 60); do echo "verify-line-$i"; done; exit 7' --id verify-fail --task 'Verify failing build' >"$TMP/verify-fail.out" 2>"$TMP/verify-fail.err"; then
  echo 'Expected failing --verify command to return non-zero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/verify-fail.out"
grep -q '  Failure category: verification_error' "$TMP/verify-fail.out"
grep -q '  Verification: failed' "$TMP/verify-fail.out"
grep -q '  Verification exit: 7' "$TMP/verify-fail.out"
grep -q '^    verify-line-21$' "$TMP/verify-fail.out"
grep -q '^    verify-line-60$' "$TMP/verify-fail.out"
if grep -q '^    verify-line-20$' "$TMP/verify-fail.out"; then
  echo 'Expected DELEGATION_RESULT verification output to be capped to last 40 lines' >&2; exit 1
fi
verify_fail_log=$(sed -n 's/^  Logs: //p' "$TMP/verify-fail.out" | head -n 1)
grep -q '^verify-line-1$' "$verify_fail_log/verify.log"
grep -q '^verification=failed$' "$verify_fail_log/manifest.txt"
grep -q '^verification_exit=7$' "$verify_fail_log/manifest.txt"
grep -q '^failure_category=verification_error$' "$verify_fail_log/manifest.txt"
grep -q '^exit_code=1$' "$verify_fail_log/manifest.txt"

# --verify timeout triggers failure via pure-Bash watchdog when timeout/gtimeout are absent from PATH
for tool in sleep kill; do
  tool_path=$(command -v "$tool" 2>/dev/null || true)
  if [[ -n $tool_path ]]; then
    ln -sf "$tool_path" "$SYS_BIN/$tool"
  fi
done
if PATH="$TMP/bin-only-opencode:$SYS_BIN" "$SCRIPT" --agent opencode --mode build --verify-timeout 1 --verify 'echo before-timeout; sleep 5' --id verify-bash-timeout --task 'Verify bash timeout watchdog' >"$TMP/verify-timeout.out" 2>"$TMP/verify-timeout.err"; then
  echo 'Expected timed-out --verify command to return non-zero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/verify-timeout.out"
grep -q '  Failure category: verification_error' "$TMP/verify-timeout.out"
grep -q '  Verification: failed' "$TMP/verify-timeout.out"
grep -q '  Verification exit: 124' "$TMP/verify-timeout.out"
grep -q 'Verification timed out after 1s' "$TMP/verify-timeout.out"

# --verify fallback watchdog kills grandchild processes on timeout
# shellcheck disable=SC2016
if PATH="$TMP/bin-only-opencode:$SYS_BIN" "$SCRIPT" --agent opencode --mode build --verify-timeout 1 --verify 'sh -c "sleep 30 & echo \$! > pidfile; wait"' --id verify-grandchild-timeout --task 'Verify watchdog kills grandchild processes' >"$TMP/verify-grandchild.out" 2>"$TMP/verify-grandchild.err"; then
  echo 'Expected timed-out --verify grandchild command to return non-zero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/verify-grandchild.out"
grep -q '  Failure category: verification_error' "$TMP/verify-grandchild.out"
grep -q '  Verification: failed' "$TMP/verify-grandchild.out"
grep -q '  Verification exit: 124' "$TMP/verify-grandchild.out"
WT_GRANDCHILD=$(sed -n 's/^  Worktree: //p' "$TMP/verify-grandchild.out" | head -n 1)
[[ -s $WT_GRANDCHILD/pidfile ]]
grandchild_pid=$(tr -d '[:space:]' <"$WT_GRANDCHILD/pidfile")
[[ $grandchild_pid =~ ^[0-9]+$ ]]
if kill -0 "$grandchild_pid" 2>/dev/null; then
  kill -KILL "$grandchild_pid" 2>/dev/null || true
  echo "Expected fallback watchdog to kill grandchild PID $grandchild_pid" >&2; exit 1
fi

# Primary timeout/gtimeout path passes -k 2 and records exit 124 on timeout
mkdir -p "$TMP/bin-timeout-shim"
cat > "$TMP/bin-timeout-shim/timeout" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TIMEOUT_SHIM_LOG"
if [[ ${TIMEOUT_SHIM_FORCE_TIMEOUT:-0} == 1 ]]; then
  exit 124
fi
while (($#)); do
  case "$1" in
    -k) shift 2 ;;
    *) shift; break ;;
  esac
done
exec "$@"
SHIM
chmod +x "$TMP/bin-timeout-shim/timeout"
: >"$TMP/timeout-shim.log"
TIMEOUT_SHIM_LOG="$TMP/timeout-shim.log" PATH="$TMP/bin-only-opencode:$TMP/bin-timeout-shim:$SYS_BIN" "$SCRIPT" --agent opencode --mode build --verify-timeout 5 --verify 'echo via-timeout-shim' --id verify-timeout-shim-pass --task 'Verify primary timeout shim passes' >"$TMP/verify-timeout-shim-pass.out"
grep -q 'Exit: 0' "$TMP/verify-timeout-shim-pass.out"
grep -q '  Verification: passed' "$TMP/verify-timeout-shim-pass.out"
grep -q '^    via-timeout-shim$' "$TMP/verify-timeout-shim-pass.out"
grep -qx -- '-k 2 5 bash -c echo via-timeout-shim' "$TMP/timeout-shim.log"

: >"$TMP/timeout-shim.log"
if TIMEOUT_SHIM_LOG="$TMP/timeout-shim.log" TIMEOUT_SHIM_FORCE_TIMEOUT=1 PATH="$TMP/bin-only-opencode:$TMP/bin-timeout-shim:$SYS_BIN" "$SCRIPT" --agent opencode --mode build --verify-timeout 5 --verify 'echo should-timeout' --id verify-timeout-shim-fail --task 'Verify primary timeout shim timeout' >"$TMP/verify-timeout-shim-fail.out" 2>"$TMP/verify-timeout-shim-fail.err"; then
  echo 'Expected primary timeout shim timeout to return non-zero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/verify-timeout-shim-fail.out"
grep -q '  Failure category: verification_error' "$TMP/verify-timeout-shim-fail.out"
grep -q '  Verification: failed' "$TMP/verify-timeout-shim-fail.out"
grep -q '  Verification exit: 124' "$TMP/verify-timeout-shim-fail.out"
grep -q 'Verification timed out after 5s' "$TMP/verify-timeout-shim-fail.out"
grep -qx -- '-k 2 5 bash -c echo should-timeout' "$TMP/timeout-shim.log"

# Worker exiting 0 while git diff --check fails sets Verification: not_run and skips --verify
if OPENCODE_MOCK_TRAILING_WS=1 "$SCRIPT" --agent opencode --mode build --verify "touch '$TMP/diff-check-should-not-run'" --id verify-diff-check-fail --task 'Worker exits 0 with whitespace error' >"$TMP/verify-diff-check.out" 2>"$TMP/verify-diff-check.err"; then
  echo 'Expected git diff --check failure to exit non-zero' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/verify-diff-check.out"
grep -q '  Failure category: task_error' "$TMP/verify-diff-check.out"
grep -q '  Verification: not_run' "$TMP/verify-diff-check.out"
[[ ! -e $TMP/diff-check-should-not-run ]]
diff_check_log=$(sed -n 's/^  Logs: //p' "$TMP/verify-diff-check.out" | head -n 1)
[[ ! -e $diff_check_log/verify.log ]]
[[ -s $diff_check_log/diff-check.txt ]]
grep -q '^verification=not_run$' "$diff_check_log/manifest.txt"
grep -q '^failure_category=task_error$' "$diff_check_log/manifest.txt"

# --verify is not_run when worker fails before verification
if OPENCODE_MOCK_TASK_ERROR=1 "$SCRIPT" --agent opencode --mode build --verify 'echo should-not-run' --id verify-not-run --task 'Worker fails before verify' >"$TMP/verify-not-run.out" 2>"$TMP/verify-not-run.err"; then
  echo 'Expected worker task error to fail before verification' >&2; exit 1
fi
grep -q 'Exit: 1' "$TMP/verify-not-run.out"
grep -q '  Failure category: task_error' "$TMP/verify-not-run.out"
grep -q '  Verification: not_run' "$TMP/verify-not-run.out"
verify_not_run_log=$(sed -n 's/^  Logs: //p' "$TMP/verify-not-run.out" | head -n 1)
[[ ! -e $verify_not_run_log/verify.log ]]
grep -q '^verification=not_run$' "$verify_not_run_log/manifest.txt"
grep -q '^failure_category=task_error$' "$verify_not_run_log/manifest.txt"

# Auth and quota exhaustion map to auth_error and env_error failure categories
if CODEX_MOCK_AUTH_FAIL=1 "$SCRIPT" --orchestrator agy --agent codex --mode build --verify 'true' --id auth-cat --task 'Auth failure category' >"$TMP/auth-cat.out" 2>"$TMP/auth-cat.err"; then
  echo 'Expected auth failure to exit non-zero' >&2; exit 1
fi
grep -q '  Failure category: auth_error' "$TMP/auth-cat.out"
grep -q '  Verification: not_run' "$TMP/auth-cat.out"

if PATH="$TMP/bin-only-opencode:$SYS_BIN" OPENCODE_MOCK_FAIL_ALL=1 "$SCRIPT" --agent opencode --mode build --verify 'true' --id env-cat --task 'Quota failure category' >"$TMP/env-cat.out" 2>"$TMP/env-cat.err"; then
  echo 'Expected quota exhaustion to exit non-zero' >&2; exit 1
fi
grep -q '  Failure category: env_error' "$TMP/env-cat.out"
grep -q '  Verification: not_run' "$TMP/env-cat.out"

# Modified test files flags test paths separately from non-test changed files
OPENCODE_MOCK_TOUCH_FILES='tests/unit_case.sh,pkg/tests/sub.py,scripts/test_helper.py,pkg/handler_test.go,web/app.test.ts,web/app.spec.tsx,src/main.sh' \
  "$SCRIPT" --agent opencode --mode build --id test-files-flag --task 'Touch test and non-test files' >"$TMP/test-files-flag.out"
grep -q 'Exit: 0' "$TMP/test-files-flag.out"
changed_section=$(sed -n '/^  Changed files:/,/^  Modified test files:/p' "$TMP/test-files-flag.out")
modified_test_section=$(sed -n '/^  Modified test files:/,/^  Git changes:/p' "$TMP/test-files-flag.out")
for expected_test in \
  '    tests/unit_case.sh' \
  '    pkg/tests/sub.py' \
  '    scripts/test_helper.py' \
  '    pkg/handler_test.go' \
  '    web/app.test.ts' \
  '    web/app.spec.tsx'; do
  grep -qx "$expected_test" <<< "$changed_section"
  grep -qx "$expected_test" <<< "$modified_test_section"
done
grep -qx '    src/main.sh' <<< "$changed_section"
grep -qx '    agent-change.txt' <<< "$changed_section"
if grep -qx '    src/main.sh' <<< "$modified_test_section" || grep -qx '    agent-change.txt' <<< "$modified_test_section"; then
  echo 'Expected non-test files not to appear under Modified test files' >&2; exit 1
fi
test_files_log=$(sed -n 's/^  Logs: //p' "$TMP/test-files-flag.out" | head -n 1)
grep -q '^changed_files_count=8$' "$test_files_log/manifest.txt"
grep -q '^modified_test_files_count=6$' "$test_files_log/manifest.txt"

echo 'PASS: All delegation tests passed across Codex, OpenCode, and Copilot'
