#!/usr/bin/env bash
# Tests for dotfiles/gemini/antigravity-cli/title.sh

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_dir}/dotfiles/gemini/antigravity-cli/title.sh"

assert_output() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nExpected: %q\nActual:   %q\n' "$test_name" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$test_name"
}

# 1. Normal state and workspace directory
actual=$("$script" << 'EOF'
{
  "agent_state": "idle",
  "workspace": {"current_dir": "/home/user/my-project"}
}
EOF
)
assert_output "State and workspace directory" "[idle] my-project" "$actual"

# 2. Directory with trailing slash
actual=$("$script" << 'EOF'
{
  "agent_state": "running",
  "workspace": {"current_dir": "/home/user/my-project/"}
}
EOF
)
assert_output "Trailing slash normalization" "[running] my-project" "$actual"

# 3. Directory with multiple trailing slashes
actual=$("$script" << 'EOF'
{
  "agent_state": "running",
  "workspace": {"current_dir": "/home/user/my-project///"}
}
EOF
)
assert_output "Multiple trailing slashes normalization" "[running] my-project" "$actual"

# 4. Root directory
actual=$("$script" << 'EOF'
{
  "agent_state": "idle",
  "workspace": {"current_dir": "/"}
}
EOF
)
assert_output "Root directory" "[idle] /" "$actual"

# 5. Fallback to cwd
actual=$("$script" << 'EOF'
{
  "agent_state": "thinking",
  "cwd": "/Users/gordonpn/workspace/dotfiles"
}
EOF
)
assert_output "Fallback to cwd" "[thinking] dotfiles" "$actual"

# 6. Missing agent_state (directory only)
actual=$("$script" << 'EOF'
{
  "workspace": {"current_dir": "/Users/gordonpn/workspace/dotfiles"}
}
EOF
)
assert_output "Missing agent_state" "dotfiles" "$actual"

# 7. Missing current_dir (state only)
actual=$("$script" << 'EOF'
{
  "agent_state": "idle"
}
EOF
)
assert_output "Missing current_dir" "[idle]" "$actual"

# 8. Single-level root or top directory
actual=$("$script" << 'EOF'
{
  "agent_state": "idle",
  "workspace": {"current_dir": "/workspace"}
}
EOF
)
assert_output "Single level path" "[idle] workspace" "$actual"

# 9. Empty JSON object
actual=$(echo '{}' | "$script")
assert_output "Empty JSON object" "" "$actual"

# 10. Empty stdin
actual=$(printf '' | "$script")
assert_output "Empty stdin" "" "$actual"

# 11. Invalid JSON input
actual=$(echo 'invalid json' | "$script")
assert_output "Invalid JSON" "" "$actual"

printf '\nAll agy-title tests passed successfully.\n'
