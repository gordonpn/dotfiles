test:
    bash tests/mcp-sync.sh
    python3 -m unittest discover -s tests -p "test_*.py" -v
    bash tests/update-skills.sh
    bash tests/deepseek-analyze.sh
    bash tests/deepseek-review-prompt.sh
    bash dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh
    bash tests/agy-statusline.sh
    bash tests/agy-title.sh

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    scripts=(
        ".github/scripts/check-deepseek-credentials.sh"
        ".github/scripts/install-actionlint.sh"
        ".github/scripts/write-deepseek-review-prompt.sh"
        "bin/agy-statusline"
        "bin/mcp-sync"
        "dotfiles/gemini/antigravity-cli/title.sh"
        "tests/agy-statusline.sh"
        "tests/agy-title.sh"
        "tests/mcp-sync.sh"
        "tests/deepseek-analyze.sh"
        "tests/deepseek-review-prompt.sh"
        "scripts/deepseek-analyze.sh"
        "scripts/update-skills.sh"
        "tests/update-skills.sh"
        "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh"
        "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate-analyze.sh"
        "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate-implement.sh"
        "dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh"
    )
    for f in "${scripts[@]}"; do
        bash -n "$f"
    done
    shellcheck -x "${scripts[@]}"
    if command -v actionlint >/dev/null 2>&1; then
        actionlint
    fi
    uvx ruff check --target-version py311 tests/verify_mcp.py scripts/mcp_sync.py tests/test_mcp_sync_py.py
    uvx --with mcp==1.1.2 mypy --strict tests/verify_mcp.py scripts/mcp_sync.py tests/test_mcp_sync_py.py
    git diff --check

setup-codebase-memory:
    bash bin/mcp-sync --codebase-memory-only

update-skills:
    bash scripts/update-skills.sh

setup-ecc:
    if ! codex plugin marketplace list --json | jq -e '.marketplaces[] | select(.name == "ecc")' >/dev/null; then codex plugin marketplace add affaan-m/ECC --ref v2.2.3; fi
    if ! codex plugin list --json | jq -e '.installed[] | select(.name == "ecc" and .marketplaceName == "ecc")' >/dev/null; then codex plugin add ecc@ecc; fi
    npx --yes ecc-universal@2.2.3 install --profile minimal --target antigravity

verify-codebase-memory:
    uv run --no-project --with mcp==1.1.2 python tests/verify_mcp.py
