test:
    bash tests/mcp-sync.sh
    bash tests/deepseek-analyze.sh
    bash dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    scripts=(
        "bin/mcp-sync"
        "tests/mcp-sync.sh"
        "tests/deepseek-analyze.sh"
        "scripts/deepseek-analyze.sh"
        "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh"
        "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate-analyze.sh"
        "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate-implement.sh"
        "dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh"
    )
    for f in "${scripts[@]}"; do
        bash -n "$f"
    done
    shellcheck -x "${scripts[@]}"
    uvx ruff check --target-version py311 tests/verify_mcp.py
    uvx --with mcp==1.1.2 mypy --strict tests/verify_mcp.py
    git diff --check

setup-codebase-memory:
    bash bin/mcp-sync --codebase-memory-only

setup-ecc:
    if ! codex plugin marketplace list --json | jq -e '.marketplaces[] | select(.name == "ecc")' >/dev/null; then codex plugin marketplace add affaan-m/ECC --ref v2.2.3; fi
    if ! codex plugin list --json | jq -e '.installed[] | select(.name == "ecc" and .marketplaceName == "ecc")' >/dev/null; then codex plugin add ecc@ecc; fi
    npx --yes ecc-universal@2.2.3 install --profile minimal --target antigravity

setup-claude-mem:
    CLAUDE_MEM_TELEMETRY=0 npx --yes claude-mem@15.3.0 telemetry disable
    CLAUDE_MEM_TELEMETRY=0 CLAUDE_MEM_ONLINE_OPTIN=false npx --yes claude-mem@15.3.0 install --ide claude-code --provider claude --runtime worker --no-auto-start
    CLAUDE_MEM_TELEMETRY=0 CLAUDE_MEM_ONLINE_OPTIN=false npx --yes claude-mem@15.3.0 install --ide codex-cli --provider claude --runtime worker --no-auto-start
    npx --yes claude-mem@15.3.0 start

verify-codebase-memory:
    uv run --no-project --with mcp==1.1.2 python tests/verify_mcp.py
