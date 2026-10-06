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
    opencode: object = json.loads((home / ".config/opencode/opencode.json").read_text())
    codex: object = tomllib.loads((home / ".codex/config.toml").read_text())
    expected: dict[str, object] = {"command": str(executable), "args": []}

    assert server_entry(agy, "mcpServers") == expected
    assert server_entry(codex, "mcp_servers") == expected
    assert server_entry(opencode, "mcp") == {
        "type": "local",
        "command": [str(executable)],
        "enabled": True,
    }
    for config in (
        home / ".gemini/config/mcp_config.json",
        home / ".config/opencode/opencode.json",
        home / ".codex/config.toml",
    ):
        assert config.stat().st_mode & 0o777 == 0o600, f"Unsafe permissions: {config}"
    print("All three client registrations match; config permissions are 0600")
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
