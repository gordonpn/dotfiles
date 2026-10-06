test:
    bash tests/mcp-sync.sh

lint:
    bash -n bin/mcp-sync tests/mcp-sync.sh
    shellcheck -x tests/mcp-sync.sh
    uvx ruff check --target-version py311 tests/verify_mcp.py
    uvx --with mcp==1.1.2 mypy --strict tests/verify_mcp.py
    git diff --check

setup-codebase-memory:
    bash bin/mcp-sync --codebase-memory-only

verify-codebase-memory:
    uv run --no-project --with mcp==1.1.2 python tests/verify_mcp.py
