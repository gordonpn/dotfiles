test:
    bash tests/mcp-sync.sh
    bash tests/deepseek-analyze.sh

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    scripts=(
        "bin/mcp-sync"
        "tests/mcp-sync.sh"
        "tests/deepseek-analyze.sh"
        "scripts/deepseek-analyze.sh"
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

verify-codebase-memory:
    uv run --no-project --with mcp==1.1.2 python tests/verify_mcp.py
