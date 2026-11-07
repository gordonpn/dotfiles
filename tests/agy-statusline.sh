#!/usr/bin/env bash
# shellcheck disable=SC2088
# Tests for bin/agy-statusline

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_dir}/bin/agy-statusline"

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

# 1. Full telemetry payload with home shortening
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/Users/gordonpn/workspace/dotfiles"},
  "model": {"display_name": "Gemini 3.8 Flash (High)"},
  "context_window": {"used_percentage": 0},
  "quota": {
    "gemini-5h": {"remaining_fraction": 0.95597667},
    "gemini-weekly": {"remaining_fraction": 0.98599327}
  }
}
EOF
)
assert_output "Full Gemini payload" "~/workspace/dotfiles | Gemini 3.8 Flash (High) | ctx: 0% | quota: 96%" "$actual"

# 2. Exact home directory path
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/Users/gordonpn"},
  "model": {"display_name": "Gemini 3.8 Flash (High)"}
}
EOF
)
assert_output "Exact home directory" "~ | Gemini 3.8 Flash (High)" "$actual"

# 3. Path matching home prefix but different directory name
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/Users/gordonpn_other/project"},
  "model": {"display_name": "Gemini 3.8 Flash (High)"}
}
EOF
)
assert_output "Home prefix collision avoidance" "/Users/gordonpn_other/project | Gemini 3.8 Flash (High)" "$actual"

# 4. Directory outside home
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/tmp/project"},
  "model": {"display_name": "Gemini 3.8 Flash (High)"}
}
EOF
)
assert_output "Directory outside home" "/tmp/project | Gemini 3.8 Flash (High)" "$actual"

# 5. Fallback to cwd and model.id
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "cwd": "/Users/gordonpn/other",
  "model": {"id": "gemini-2.5"}
}
EOF
)
assert_output "Fallback cwd and model.id" "~/other | gemini-2.5" "$actual"

# 6. Claude/3p model with 3p-5h quota
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/Users/gordonpn/workspace/app"},
  "model": {"display_name": "Claude 3.7 Sonnet"},
  "context_window": {"used_percentage": 42.4},
  "quota": {
    "3p-5h": {"remaining_fraction": 0.724},
    "3p-weekly": {"remaining_fraction": 0.95}
  }
}
EOF
)
assert_output "Claude 3p quota" "~/workspace/app | Claude 3.7 Sonnet | ctx: 42% | quota: 72%" "$actual"

# 7. Flat quota object with remaining_fraction
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/Users/gordonpn/workspace/app"},
  "model": {"display_name": "Test Model"},
  "context_window": {"used_percentage": 10},
  "quota": {"remaining_fraction": 0.5}
}
EOF
)
assert_output "Flat quota object" "~/workspace/app | Test Model | ctx: 10% | quota: 50%" "$actual"

# 8. Numeric quota
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/tmp/test"},
  "model": {"display_name": "Test Model"},
  "quota": 0.8
}
EOF
)
assert_output "Numeric quota" "/tmp/test | Test Model | quota: 80%" "$actual"

# 9. Missing context and quota
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/tmp/test"},
  "model": {"display_name": "Test Model"}
}
EOF
)
assert_output "Missing context and quota" "/tmp/test | Test Model" "$actual"

# 10. Zero percentages
actual=$(HOME="/Users/gordonpn" "$script" << 'EOF'
{
  "workspace": {"current_dir": "/tmp/test"},
  "model": {"display_name": "Test Model"},
  "context_window": {"used_percentage": 0},
  "quota": {"remaining_fraction": 0}
}
EOF
)
assert_output "Zero percentages" "/tmp/test | Test Model | ctx: 0% | quota: 0%" "$actual"

# 11. Empty JSON object
actual=$(echo '{}' | "$script")
assert_output "Empty JSON object" "" "$actual"

# 12. Empty stdin
actual=$(echo -n '' | "$script")
assert_output "Empty stdin" "" "$actual"

# 13. Invalid JSON input
actual=$(echo 'not valid json' | "$script")
assert_output "Invalid JSON" "" "$actual"

printf '\nAll agy-statusline tests passed successfully.\n'
