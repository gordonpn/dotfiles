import argparse
import asyncio
import json
import tomllib
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER_NAME: str = "codebase-memory-mcp"
EXPECTED_TOOLS: frozenset[str] = frozenset(
    {
        "check_index_coverage",
        "compare_graphs",
        "delete_project",
        "detect_changes",
        "get_architecture",
        "get_code_snippet",
        "get_file_outline",
        "get_graph_schema",
        "index_repository",
        "index_status",
        "ingest_traces",
        "list_projects",
        "manage_adr",
        "query_graph",
        "search_code",
        "search_graph",
        "trace_path",
    }
)


def server_entry(config: object, section_name: str) -> object:
    assert isinstance(config, dict), "Configuration must be an object"
    section: object = config.get(section_name)
    assert isinstance(section, dict), f"Missing {section_name} section"
    return section.get(SERVER_NAME)


def verify_configs() -> Path:
    home = Path.home()
    executable = home / ".local/share/codebase-memory-mcp/codebase-memory-mcp"
    agy: object = json.loads((home / ".gemini/config/mcp_config.json").read_text())
    codex: object = tomllib.loads((home / ".codex/config.toml").read_text())
    expected: dict[str, object] = {"command": str(executable), "args": []}

    assert server_entry(agy, "mcpServers") == expected
    assert server_entry(codex, "mcp_servers") == expected

    # Verify Codex CLI has lean core servers enabled by default and non-core disabled
    assert isinstance(codex, dict)
    codex_servers: object = codex.get("mcp_servers")
    assert isinstance(codex_servers, dict)
    enabled_codex: set[str] = {
        name
        for name, entry in codex_servers.items()
        if isinstance(entry, dict) and entry.get("enabled", True)
    }
    assert "codebase-memory-mcp" in enabled_codex
    assert "cclsp" in enabled_codex
    assert "git" in enabled_codex
    assert "ai-memory" in enabled_codex
    assert "tailscale" not in enabled_codex
    assert "cloudflare" not in enabled_codex
    assert "docker" not in enabled_codex
    assert len(enabled_codex) <= 12, f"Unexpectedly high enabled servers in Codex: {len(enabled_codex)}"

    configs = [
        home / ".gemini/config/mcp_config.json",
        home / ".codex/config.toml",
    ]

    # OpenCode MCP registration is not managed by mcp-sync (only shared skills
    # and AGENTS.md instructions are synchronized for OpenCode).

    for config in configs:
        assert config.stat().st_mode & 0o777 == 0o600, f"Unsafe permissions: {config}"
    print("Client registrations match; config permissions are 0600")
    return executable


async def verify_handshake(executable: Path) -> None:
    parameters = StdioServerParameters(command=str(executable), args=[])
    async with (
        stdio_client(parameters) as (read, write),
        ClientSession(read, write) as session,
    ):
        initialized = await session.initialize()
        catalog = await session.list_tools()
        names = {tool.name for tool in catalog.tools}

        assert names == EXPECTED_TOOLS, f"Unexpected v0.11.0 catalog: {sorted(names)}"
        print(f"MCP handshake passed: {initialized.serverInfo.name}")
        print(f"Tools: {', '.join(sorted(names))}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--configs-only", action="store_true")
    options = parser.parse_args()
    executable = verify_configs()
    if not options.configs_only:
        asyncio.run(asyncio.wait_for(verify_handshake(executable), timeout=45))


if __name__ == "__main__":
    main()
