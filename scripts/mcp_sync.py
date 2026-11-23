#!/usr/bin/env python3
"""Zero-dependency stdlib implementation for mcp-sync config, profile, and skill sync."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import cast

DEFAULT_CORE_SERVERS: frozenset[str] = frozenset(
    {
        "ai-memory",
        "brave-search",
        "cclsp",
        "codebase-memory-mcp",
        "context7",
        "fetch",
    }
)

RETIRED_OPENCODE_SERVERS: frozenset[str] = frozenset(
    {
        "chrome-devtools",
        "puppeteer",
        "memory",
        "postgres",
        "server-services-configs",
        "sqlite",
    }
)

DOCKER_HOST_KEYWORDS: tuple[str, ...] = (
    "master",
    "pi",
    "vps",
    "racknerd",
    "server",
)

TEMPLATE_ENV_VARS: tuple[str, ...] = (
    "HOME",
    "GITHUB_PERSONAL_ACCESS_TOKEN",
    "BRAVE_API_KEY",
    "EXA_API_KEY",
    "CLOUDFLARE_ACCOUNT_ID",
    "CLOUDFLARE_API_TOKEN",
    "PROMETHEUS_URL",
    "LOKI_URL",
    "TAILSCALE_API_KEY",
    "UPTIME_KUMA_URL",
    "UPTIME_KUMA_JWT_TOKEN",
    "HEALTHCHECKS_API_KEY",
    "CADDY_ADMIN_URL",
    "REDIS_URL",
    "VAULT_ADDR",
    "VAULT_TOKEN",
    "SLACK_BOT_TOKEN",
    "SLACK_TEAM_ID",
    "DISCORD_TOKEN",
    "TFE_TOKEN",
    "TFE_ADDRESS",
    "POSTMAN_API_KEY",
    "SONARQUBE_TOKEN",
    "SONARQUBE_URL",
    "SONARQUBE_ORG",
)

TOKEN_AND_COMMA_RE: re.Pattern[str] = re.compile(
    r'"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/|,\s*([}\]])'
)
MANAGED_BLOCK_RE: re.Pattern[str] = re.compile(
    r"\n?# === BEGIN MANAGED MCP SERVERS.*?(?:# === END MANAGED MCP SERVERS[^\n]*|\Z)",
    flags=re.DOTALL,
)
TOML_HEADER_RE: re.Pattern[str] = re.compile(r"^[ \t]*\[(.+?)\](?:[ \t]*(?:#.*)?)?$")


@dataclass(frozen=True)
class ServerSpec:
    """Normalized MCP server definition extracted from the hydrated template."""

    name: str
    command: str
    args: tuple[str, ...]
    disabled: bool
    env: dict[str, str]


@dataclass(frozen=True)
class SyncSkillsConfig:
    """Paths and client flags required to synchronize skills and instructions."""

    home: Path
    repo_dir: Path
    gemini_dir: Path
    gemini_config_dir: Path
    codex_dir: Path
    opencode_dir: Path
    copilot_dir: Path
    local_bin_dir: Path
    opencode_enabled: bool
    copilot_enabled: bool


def safe_write_config(path: Path, text: str) -> None:
    """Write text atomically to path using a fresh private 0600 temporary file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.tmp.", dir=path.parent)
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.lexists(tmp_path):
            tmp_path.unlink()
        raise


def _strip_ssh_quotes(value: str) -> str:
    """Strip one pair of matching surrounding quotes from an SSH config token."""
    cleaned = value.strip()
    if len(cleaned) >= 2 and cleaned[0] == cleaned[-1] and cleaned[0] in ('"', "'"):
        return cleaned[1:-1]
    return cleaned


def _parse_ssh_port(raw_port: str) -> int:
    """Parse an SSH Port directive, tolerating valid OpenSSH quotes."""
    cleaned = _strip_ssh_quotes(raw_port)
    return int(cleaned) if cleaned.isdigit() else 22


def parse_ssh_config(text: str, default_user: str) -> dict[str, dict[str, object]]:
    """Parse SSH Host stanzas into SSH MCP profile dictionaries."""
    profiles: dict[str, dict[str, object]] = {}
    current_hosts: list[str] = []
    host_data: dict[str, str] = {}

    def flush() -> None:
        if not current_hosts or not host_data:
            return
        for alias in current_hosts:
            profiles[alias] = {
                "host": _strip_ssh_quotes(host_data.get("hostname", alias)),
                "username": _strip_ssh_quotes(host_data.get("user", default_user)),
                "port": _parse_ssh_port(host_data.get("port", "22")),
                "privateKeyPath": _strip_ssh_quotes(host_data.get("identityfile", "~/.ssh/id_ed25519")),
            }

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        key, val = parts[0].lower(), parts[1].strip()
        if key == "host":
            flush()
            aliases: list[str] = []
            for token in val.split():
                alias = _strip_ssh_quotes(token)
                if not alias or any(ch in alias for ch in ("*", "?", "!")) or alias == "github.com":
                    continue
                aliases.append(alias)
            current_hosts = aliases
            host_data = {}
        elif current_hosts:
            host_data.setdefault(key, val)

    flush()
    return profiles


def sync_ssh_profiles(ssh_config: Path, target_file: Path) -> None:
    """Generate ssh-profiles.json from an SSH config file when present."""
    if not ssh_config.is_file():
        print(f"Notice: {ssh_config} not found, skipping SSH profiles generation.")
        return

    default_user = os.environ.get("USER", "root")
    profiles = parse_ssh_config(ssh_config.read_text(encoding="utf-8"), default_user)
    safe_write_config(target_file, json.dumps({"profiles": profiles}, indent=2))
    print(f"Generated {len(profiles)} SSH profiles in {target_file}")


def build_docker_profiles(ssh_data: dict[str, object]) -> dict[str, object]:
    """Build Docker profile map containing local default plus matching remote hosts."""
    profiles: dict[str, object] = {"local": {"mode": "local"}}
    raw_ssh_profiles = ssh_data.get("profiles")
    if isinstance(raw_ssh_profiles, dict):
        for name, spec in raw_ssh_profiles.items():
            if isinstance(name, str) and any(kw in name for kw in DOCKER_HOST_KEYWORDS):
                profiles[name] = spec
    return {"default": "local", "profiles": profiles}


def sync_docker_profiles(ssh_profiles: Path, target_file: Path) -> None:
    """Generate docker-profiles.json from existing SSH profiles."""
    ssh_data: dict[str, object] = {}
    if ssh_profiles.is_file():
        loaded = json.loads(ssh_profiles.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            ssh_data = cast(dict[str, object], loaded)
    docker_profiles = build_docker_profiles(ssh_data)
    safe_write_config(target_file, json.dumps(docker_profiles, indent=2))
    profile_map = cast(dict[str, object], docker_profiles["profiles"])
    print(f"Generated Docker profiles (default: local, {len(profile_map) - 1} remote) in {target_file}")


def rewrite_k3s_kubeconfig(raw: str) -> str:
    """Rename K3s default cluster, context, user, and server to k3s-master identifiers."""
    section = ""
    out_lines: list[str] = []
    for line in raw.splitlines(keepends=True):
        stripped = line.rstrip("\r\n")
        if stripped and not stripped[0].isspace() and not stripped.startswith(("-", "#")):
            if stripped.startswith("clusters:"):
                section = "clusters"
            elif stripped.startswith("contexts:"):
                section = "contexts"
            elif stripped.startswith("users:"):
                section = "users"
            else:
                section = ""
                if stripped in ("current-context: default", 'current-context: "default"', "current-context: 'default'"):
                    ending = line[len(stripped) :]
                    line = f"current-context: k3s-master{ending}"
            out_lines.append(line)
            continue

        if section == "clusters":
            line = line.replace("server: https://127.0.0.1:6443", "server: https://master:6443")
            line = re.sub(r"^([ \t]*(?:-\s+)?)name:\s*([\"']?)default\2(?=[ \t]*(?:\r?\n)?$)", r"\1name: k3s-master", line)
        elif section == "contexts":
            line = re.sub(r"^([ \t]*(?:-\s+)?)cluster:\s*([\"']?)default\2(?=[ \t]*(?:\r?\n)?$)", r"\1cluster: k3s-master", line)
            line = re.sub(r"^([ \t]*(?:-\s+)?)user:\s*([\"']?)default\2(?=[ \t]*(?:\r?\n)?$)", r"\1user: k3s-master-user", line)
            line = re.sub(r"^([ \t]*(?:-\s+)?)name:\s*([\"']?)default\2(?=[ \t]*(?:\r?\n)?$)", r"\1name: k3s-master", line)
        elif section == "users":
            line = re.sub(r"^([ \t]*(?:-\s+)?)name:\s*([\"']?)default\2(?=[ \t]*(?:\r?\n)?$)", r"\1name: k3s-master-user", line)
        out_lines.append(line)
    return "".join(out_lines)


def sync_k3s_cluster(home: Path) -> None:
    """Fetch remote k3s.yaml from master over SSH and merge into ~/.kube/config."""
    print("Checking remote K3s connectivity on master...")
    kube_dir = home / ".kube"
    tmp_path: Path | None = None
    clean_cfg: Path | None = None
    try:
        probe = subprocess.run(
            ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=3", "master", "true"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
        if probe.returncode != 0:
            print("Notice: master host not reachable via SSH, skipping K3s cluster kubeconfig refresh.")
            return

        raw = subprocess.check_output(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=5",
                "master",
                "cat /etc/rancher/k3s/k3s.yaml 2>/dev/null || sudo -n cat /etc/rancher/k3s/k3s.yaml 2>/dev/null",
            ],
            timeout=15,
            text=True,
        )
        rewritten = rewrite_k3s_kubeconfig(raw)
        kube_dir.mkdir(parents=True, exist_ok=True)
        tmp_path = kube_dir / f".k3s-master-tmp-{os.getpid()}.yaml"
        safe_write_config(tmp_path, rewritten)

        kube_cfg = kube_dir / "config"
        env = os.environ.copy()
        if kube_cfg.is_file():
            prev_ctx_proc = subprocess.run(
                ["kubectl", "--kubeconfig", str(kube_cfg), "config", "current-context"],
                capture_output=True,
                timeout=15,
                text=True,
                check=False,
            )
            prev_ctx = prev_ctx_proc.stdout.strip() if prev_ctx_proc.returncode == 0 else ""

            clean_cfg = kube_dir / f".config-clean-{os.getpid()}"
            safe_write_config(clean_cfg, kube_cfg.read_text(encoding="utf-8"))
            for args in (
                ["delete-context", "k3s-master"],
                ["delete-cluster", "k3s-master"],
                ["delete-user", "k3s-master-user"],
                ["delete-user", "k3s-master"],
            ):
                subprocess.run(
                    ["kubectl", "--kubeconfig", str(clean_cfg), "config", *args],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=15,
                    check=False,
                )
            if prev_ctx and prev_ctx != "k3s-master":
                env["KUBECONFIG"] = f"{clean_cfg}:{tmp_path}"
            else:
                env["KUBECONFIG"] = f"{tmp_path}:{clean_cfg}"
        else:
            env["KUBECONFIG"] = str(tmp_path)

        flattened = subprocess.check_output(["kubectl", "config", "view", "--flatten"], env=env, timeout=15, text=True)
        safe_write_config(kube_cfg, flattened)
        print("K3s cluster context k3s-master synchronized in ~/.kube/config")
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"Notice: K3s sync skipped ({exc})")
    finally:
        for leftover in (tmp_path, clean_cfg):
            if leftover is not None and os.path.lexists(leftover):
                leftover.unlink()


def hydrate_json_value(value: object, replacements: dict[str, str]) -> object:
    """Recursively substitute placeholder tokens once inside JSON string values."""
    if isinstance(value, str):
        if not replacements:
            return value
        pattern = re.compile("|".join(re.escape(token) for token in replacements))
        return pattern.sub(lambda match: replacements[match.group(0)], value)
    if isinstance(value, list):
        return [hydrate_json_value(item, replacements) for item in value]
    if isinstance(value, dict):
        return {k: hydrate_json_value(v, replacements) for k, v in value.items()}
    return value


def extract_servers(template_data: dict[str, object]) -> list[ServerSpec]:
    """Parse normalized ServerSpec records from hydrated template JSON."""
    raw_servers = template_data.get("mcpServers")
    if not isinstance(raw_servers, dict):
        return []

    specs: list[ServerSpec] = []
    for name, raw_spec in raw_servers.items():
        if not isinstance(name, str) or not isinstance(raw_spec, dict):
            continue
        cmd = raw_spec.get("command")
        command = cmd if isinstance(cmd, str) else ""
        raw_args = raw_spec.get("args")
        args = tuple(str(a) for a in raw_args) if isinstance(raw_args, list) else ()
        disabled = bool(raw_spec.get("disabled", False))
        raw_env = raw_spec.get("env")
        env: dict[str, str] = {}
        if isinstance(raw_env, dict):
            env = {str(ek): str(ev) for ek, ev in raw_env.items()}
        specs.append(ServerSpec(name=name, command=command, args=args, disabled=disabled, env=env))
    return specs


def resolve_allowed_servers(
    profile_env: str,
    servers_env: str,
    default_servers: frozenset[str],
    environ: dict[str, str] | None = None,
) -> tuple[frozenset[str] | None, str]:
    """Resolve enabled MCP server allowlist from profile and server override env vars."""
    env_map = environ if environ is not None else dict(os.environ)
    profile = env_map.get(profile_env, "minimal").strip().lower()
    custom_raw = env_map.get(servers_env, "").strip()

    if profile not in ("minimal", "full"):
        print(f'Warning: Unrecognized {profile_env} "{profile}", defaulting to "minimal"', file=sys.stderr)
        profile = "minimal"

    if custom_raw:
        allowed = frozenset(s.strip() for s in custom_raw.split(",") if s.strip())
        return allowed, f"custom ({len(allowed)} servers)"
    if profile == "full":
        return None, "full"
    return default_servers, "minimal"


def is_server_enabled(spec: ServerSpec, allowed_servers: frozenset[str] | None) -> bool:
    """Return True if a server should be enabled for the given allowlist."""
    if spec.disabled:
        return False
    return allowed_servers is None or spec.name in allowed_servers


def toml_str(val: str) -> str:
    """Format a string as a basic double-quoted TOML string literal."""
    escaped = (
        val.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def render_codex_toml(
    existing_content: str,
    servers: list[ServerSpec],
    allowed_servers: frozenset[str] | None,
) -> tuple[str, int]:
    """Render updated Codex config.toml content and count of enabled servers."""
    toml_lines: list[str] = ["\n# === BEGIN MANAGED MCP SERVERS (mcp-sync) ==="]
    enabled_count = 0

    for spec in servers:
        codex_enabled = is_server_enabled(spec, allowed_servers)
        if codex_enabled:
            enabled_count += 1

        toml_lines.append(f'[mcp_servers."{spec.name}"]')
        toml_lines.append(f"command = {toml_str(spec.command)}")
        args_str = ", ".join(toml_str(arg) for arg in spec.args)
        toml_lines.append(f"args = [{args_str}]")
        if not codex_enabled:
            toml_lines.append("enabled = false")

        if spec.env:
            toml_lines.append(f'[mcp_servers."{spec.name}".env]')
            for ek, ev in spec.env.items():
                toml_lines.append(f"{ek} = {toml_str(ev)}")
        toml_lines.append("")

    toml_lines.append("# === END MANAGED MCP SERVERS (mcp-sync) ===\n")
    managed_block = "\n".join(toml_lines)

    cleaned = MANAGED_BLOCK_RE.sub("", existing_content)
    managed_prefixes: tuple[str, ...] = tuple(
        prefix
        for spec in servers
        for prefix in (f'mcp_servers."{spec.name}"', f"mcp_servers.'{spec.name}'", f"mcp_servers.{spec.name}")
    )
    kept_lines: list[str] = []
    skip_section = False
    for line in cleaned.splitlines(keepends=True):
        header_match = TOML_HEADER_RE.match(line)
        if header_match:
            header = header_match.group(1).strip()
            skip_section = any(header == prefix or header.startswith(f"{prefix}.") for prefix in managed_prefixes)
        if not skip_section:
            kept_lines.append(line)

    stripped_existing = "".join(kept_lines).rstrip()
    rendered = (stripped_existing + "\n" + managed_block) if stripped_existing else managed_block.lstrip("\n")
    tomllib.loads(rendered)
    return rendered, enabled_count


def strip_jsonc(text: str) -> str:
    """Strip line comments, block comments, and trailing commas outside string literals."""

    def repl(match: re.Match[str]) -> str:
        token = match.group(0)
        if token.startswith('"'):
            return token
        if token.startswith(("//", "/*")):
            return " "
        return match.group(1)

    prev: str | None = None
    curr = text
    while prev != curr:
        prev = curr
        curr = TOKEN_AND_COMMA_RE.sub(repl, curr)
    return curr


def load_json_dict(path: Path, *, allow_jsonc: bool = False) -> dict[str, object]:
    """Load a JSON (or optional JSONC) file and require a top-level JSON object."""
    if not path.is_file():
        return {}
    raw = path.read_text(encoding="utf-8-sig")
    if not raw.strip():
        return {}

    loaded: object
    try:
        loaded = json.loads(raw)
    except json.JSONDecodeError as exc:
        if not allow_jsonc:
            print(f"Error: Could not parse existing {path} ({exc}); aborting without overwriting", file=sys.stderr)
            raise SystemExit(1) from exc
        try:
            loaded = json.loads(strip_jsonc(raw))
        except json.JSONDecodeError as jsonc_exc:
            print(f"Error: Could not parse existing {path} ({jsonc_exc}); aborting without overwriting", file=sys.stderr)
            raise SystemExit(1) from jsonc_exc

    if not isinstance(loaded, dict):
        print(f"Error: Expected JSON object in {path}; aborting without overwriting", file=sys.stderr)
        raise SystemExit(1)
    return cast(dict[str, object], loaded)


def render_opencode_config(
    existing_data: dict[str, object],
    servers: list[ServerSpec],
    allowed_servers: frozenset[str] | None,
) -> tuple[dict[str, object], int]:
    """Return updated OpenCode config dictionary and count of enabled servers."""
    result = dict(existing_data)
    if "$schema" not in result:
        result["$schema"] = "https://opencode.ai/config.json"

    raw_mcp = result.get("mcp")
    existing_mcp = dict(raw_mcp) if isinstance(raw_mcp, dict) else {}
    managed_names = {spec.name for spec in servers}

    opencode_mcp: dict[str, object] = {
        k: v for k, v in existing_mcp.items() if k not in managed_names and k not in RETIRED_OPENCODE_SERVERS
    }

    enabled_count = 0
    for spec in servers:
        opencode_enabled = is_server_enabled(spec, allowed_servers)
        if opencode_enabled:
            enabled_count += 1
        entry: dict[str, object] = {
            "type": "local",
            "command": [spec.command, *spec.args] if spec.command else list(spec.args),
            "enabled": opencode_enabled,
        }
        if spec.env:
            entry["environment"] = dict(spec.env)
        opencode_mcp[spec.name] = entry

    result["mcp"] = opencode_mcp
    return result, enabled_count


def render_copilot_config(
    existing_data: dict[str, object],
    servers: list[ServerSpec],
    allowed_servers: frozenset[str] | None,
) -> tuple[dict[str, object], int]:
    """Return updated GitHub Copilot CLI mcp-config dictionary and enabled count."""
    result = dict(existing_data)
    raw_mcp = result.get("mcpServers")
    existing_mcp = dict(raw_mcp) if isinstance(raw_mcp, dict) else {}
    managed_names = {spec.name for spec in servers}

    copilot_mcp: dict[str, object] = {
        k: v
        for k, v in existing_mcp.items()
        if k not in managed_names and k not in RETIRED_OPENCODE_SERVERS
    }
    enabled_count = 0
    for spec in servers:
        if not is_server_enabled(spec, allowed_servers):
            continue
        enabled_count += 1
        entry: dict[str, object] = {
            "type": "local",
            "command": spec.command,
            "args": list(spec.args),
            "tools": ["*"],
        }
        if spec.env:
            entry["env"] = dict(spec.env)
        copilot_mcp[spec.name] = entry

    result["mcpServers"] = copilot_mcp
    return result, enabled_count


def sync_mcp_config(
    template_file: Path,
    antigravity_target: Path,
    codex_config: Path,
    codex_template: Path,
    opencode_config: Path,
    copilot_config: Path,
) -> None:
    """Hydrate mcp_config template and synchronize all configured MCP clients."""
    if not template_file.is_file():
        print(f"Error: Template {template_file} not found.", file=sys.stderr)
        raise SystemExit(1)

    try:
        raw_template = json.loads(template_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Error: Could not parse template {template_file} ({exc}).", file=sys.stderr)
        raise SystemExit(1) from exc
    if not isinstance(raw_template, dict):
        print(f"Error: Template {template_file} must be a JSON object.", file=sys.stderr)
        raise SystemExit(1)

    replacements = {f"${{{var}}}": os.environ.get(var, "") for var in TEMPLATE_ENV_VARS}
    hydrated_raw = hydrate_json_value(raw_template, replacements)
    hydrated_data = cast(dict[str, object], hydrated_raw)
    servers = extract_servers(hydrated_data)

    # 1. Antigravity MCP config
    safe_write_config(antigravity_target, json.dumps(hydrated_data, indent=2))
    print(f"Synchronized {len(servers)} MCP servers to {antigravity_target}")

    # 2. Codex MCP config (~/.codex/config.toml)
    codex_existing = ""
    if codex_config.is_file():
        codex_existing = codex_config.read_text(encoding="utf-8")
    elif codex_template.is_file():
        codex_existing = codex_template.read_text(encoding="utf-8")

    allowed_codex, codex_label = resolve_allowed_servers("CODEX_MCP_PROFILE", "CODEX_MCP_SERVERS", DEFAULT_CORE_SERVERS)
    try:
        new_codex, codex_enabled_count = render_codex_toml(codex_existing, servers, allowed_codex)
    except tomllib.TOMLDecodeError as exc:
        print(f"Error: Rendered Codex TOML for {codex_config} is invalid ({exc}).", file=sys.stderr)
        raise SystemExit(1) from exc
    safe_write_config(codex_config, new_codex)
    print(f"Synchronized {len(servers)} MCP servers to {codex_config} ({codex_enabled_count} enabled, profile: {codex_label})")

    # 3. OpenCode MCP config (~/.config/opencode/opencode.json)
    allowed_opencode, opencode_label = resolve_allowed_servers(
        "OPENCODE_MCP_PROFILE", "OPENCODE_MCP_SERVERS", DEFAULT_CORE_SERVERS
    )
    opencode_existing = load_json_dict(opencode_config, allow_jsonc=True)
    new_opencode, opencode_enabled_count = render_opencode_config(opencode_existing, servers, allowed_opencode)
    safe_write_config(opencode_config, json.dumps(new_opencode, indent=2) + "\n")
    print(
        f"Synchronized {len(servers)} MCP servers to {opencode_config} "
        f"({opencode_enabled_count} enabled, profile: {opencode_label})"
    )

    # 4. GitHub Copilot CLI MCP config (~/.copilot/mcp-config.json)
    allowed_copilot, copilot_label = resolve_allowed_servers(
        "COPILOT_MCP_PROFILE", "COPILOT_MCP_SERVERS", DEFAULT_CORE_SERVERS
    )
    copilot_existing = load_json_dict(copilot_config)
    new_copilot, copilot_enabled_count = render_copilot_config(copilot_existing, servers, allowed_copilot)
    safe_write_config(copilot_config, json.dumps(new_copilot, indent=2) + "\n")
    print(f"Synchronized {copilot_enabled_count} enabled MCP servers to {copilot_config} (profile: {copilot_label})")


def backup_with_collision_avoidance(src: Path, base_dest: Path) -> Path:
    """Move src to base_dest, appending a numeric suffix when base_dest already exists."""
    dest = base_dest
    counter = 1
    while os.path.lexists(dest):
        dest = Path(f"{base_dest}.{counter}")
        counter += 1
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dest))
    return dest


def atomic_symlink(src: Path, dest: Path) -> None:
    """Point dest symlink at src atomically without deleting an already-matching link."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink() and os.readlink(dest) == str(src):
        return
    if os.path.lexists(dest) and not dest.is_symlink() and dest.is_dir():
        raise IsADirectoryError(f"Refusing to replace non-symlink directory with symlink: {dest}")
    tmp_link = dest.with_name(f".{dest.name}.tmp.{os.getpid()}")
    if os.path.lexists(tmp_link):
        tmp_link.unlink()
    try:
        os.symlink(src, tmp_link)
        os.replace(tmp_link, dest)
    except OSError:
        if os.path.lexists(tmp_link):
            tmp_link.unlink()
        raise


def link_with_backup(src: Path, dest: Path, backup_path: Path) -> None:
    """Create a symlink dest -> src, moving non-matching existing dest to backup_path."""
    if os.path.lexists(dest):
        current_target = os.readlink(dest) if dest.is_symlink() else None
        if current_target != str(src):
            backup_with_collision_avoidance(dest, backup_path)
    atomic_symlink(src, dest)


def same_target_entity(path_a: Path, path_b: Path) -> bool:
    """Return True when both paths resolve to the same existing filesystem object."""
    try:
        return path_a.exists() and path_b.exists() and os.path.samefile(path_a, path_b)
    except OSError:
        return False


def link_skill_into(target_dir: Path, skill_name: str, skill_path: Path, backup_prefix: str, backup_root: Path) -> None:
    """Symlink skill_path into target_dir/skill_name, backing up colliding non-matching entries."""
    dest_skill = target_dir / skill_name
    if same_target_entity(dest_skill, skill_path):
        return

    needs_backup = False
    if dest_skill.is_symlink():
        if os.readlink(dest_skill) != str(skill_path):
            needs_backup = True
    elif os.path.lexists(dest_skill):
        needs_backup = True

    if needs_backup:
        backup_root.mkdir(parents=True, exist_ok=True)
        bak_dest = backup_root / f"{backup_prefix}.bak.{int(time.time())}"
        backup_with_collision_avoidance(dest_skill, bak_dest)

    atomic_symlink(skill_path, dest_skill)


def link_instructions_file(dest: Path, src: Path) -> None:
    """Symlink instruction file dest -> src, backing up existing regular files safely."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if os.path.lexists(dest) and not dest.is_symlink():
        bak_file = Path(f"{dest}.bak")
        if os.path.lexists(bak_file):
            bak_file = Path(f"{dest}.bak.{int(time.time())}")
        backup_with_collision_avoidance(dest, bak_file)
    atomic_symlink(src, dest)


def is_managed_link_target(target_dest: str, roots: tuple[Path, ...]) -> bool:
    """Return True when symlink target points inside any managed root prefix."""
    return any(target_dest.startswith(f"{root}/") for root in roots)


def prune_managed_skill_symlinks(target_dir: Path, valid_names: set[str], roots: tuple[Path, ...]) -> None:
    """Remove dangling or obsolete symlinks in target_dir whose targets lie inside roots."""
    if not target_dir.is_dir():
        return
    for existing in sorted(target_dir.iterdir()):
        if not existing.is_symlink():
            continue
        target_dest = os.readlink(existing)
        if not is_managed_link_target(target_dest, roots):
            continue
        if not existing.exists() or not (existing / "SKILL.md").is_file() or existing.name not in valid_names:
            print(f"Pruned stale skill link: {existing}")
            existing.unlink()


def sync_skills_and_instructions(cfg: SyncSkillsConfig) -> None:
    """Synchronize tracked skills, plugin mirrors, settings, and global instructions."""
    gemini_rules = cfg.repo_dir / "dotfiles" / "gemini" / "GEMINI.md"
    tracked_skills_dir = cfg.repo_dir / "dotfiles" / "agent-skills"
    agents_skills_dir = cfg.home / ".agents" / "skills"
    skill_backup_root = cfg.gemini_dir / "skill-backups"

    if tracked_skills_dir.is_dir():
        tracked_valid: set[str] = set()
        agents_skills_dir.mkdir(parents=True, exist_ok=True)
        for entry in sorted(tracked_skills_dir.iterdir()):
            if entry.name.startswith("."):
                continue
            if entry.is_dir() and (entry / "SKILL.md").is_file():
                tracked_valid.add(entry.name)
                link_skill_into(agents_skills_dir, entry.name, entry, entry.name, skill_backup_root)
        prune_managed_skill_symlinks(agents_skills_dir, tracked_valid, (tracked_skills_dir,))

    thinking_skill = cfg.home / ".local" / "share" / "cc-thinking-skills" / "skills" / "thinking-model-router"
    if thinking_skill.is_dir():
        agents_skills_dir.mkdir(parents=True, exist_ok=True)
        link_skill_into(agents_skills_dir, "thinking-model-router", thinking_skill, "thinking-model-router", skill_backup_root)

    agy_rule_src = cfg.repo_dir / "dotfiles" / "gemini" / "antigravity-cli" / "rules" / "auto-delegation.md"
    if agy_rule_src.is_file():
        link_with_backup(
            agy_rule_src,
            cfg.gemini_dir / "antigravity-cli" / "rules" / "auto-delegation.md",
            cfg.gemini_dir / "rule-backups" / f"auto-delegation.md.bak.{int(time.time())}",
        )

    agy_statusline_src = cfg.repo_dir / "bin" / "agy-statusline"
    if agy_statusline_src.is_file():
        link_with_backup(
            agy_statusline_src,
            cfg.local_bin_dir / "agy-statusline",
            cfg.local_bin_dir / f"agy-statusline.bak.{int(time.time())}",
        )

    file_links: tuple[tuple[Path, Path, Path], ...] = (
        (
            cfg.repo_dir / "dotfiles" / "gemini" / "settings.json",
            cfg.gemini_dir / "settings.json",
            cfg.gemini_dir / f"settings.json.bak.{int(time.time())}",
        ),
        (
            cfg.repo_dir / "dotfiles" / "gemini" / "antigravity-cli" / "settings.json",
            cfg.gemini_dir / "antigravity-cli" / "settings.json",
            cfg.gemini_dir / "antigravity-cli" / f"settings.json.bak.{int(time.time())}",
        ),
        (
            cfg.repo_dir / "dotfiles" / "gemini" / "antigravity-cli" / "title.sh",
            cfg.gemini_dir / "antigravity-cli" / "title.sh",
            cfg.gemini_dir / "antigravity-cli" / f"title.sh.bak.{int(time.time())}",
        ),
    )
    for src_path, dest_path, bak_path in file_links:
        if src_path.is_file():
            link_with_backup(src_path, dest_path, bak_path)

    link_instructions_file(cfg.codex_dir / "AGENTS.md", gemini_rules)

    if cfg.opencode_enabled:
        cfg.opencode_dir.mkdir(parents=True, exist_ok=True)
        link_instructions_file(cfg.opencode_dir / "AGENTS.md", gemini_rules)

        removed_plugin = cfg.opencode_dir / "plugins" / "copilot-student-models.ts"
        retired_target = str(cfg.repo_dir / "dotfiles" / "opencode" / "plugins" / "copilot-student-models.ts")
        if removed_plugin.is_symlink() and os.readlink(removed_plugin) == retired_target:
            removed_plugin.unlink()

    if cfg.copilot_enabled:
        (cfg.copilot_dir / "skills").mkdir(parents=True, exist_ok=True)
        link_instructions_file(cfg.copilot_dir / "instructions" / "global.instructions.md", gemini_rules)

    search_dirs: tuple[Path, ...] = (
        agents_skills_dir,
        cfg.gemini_config_dir / "skills",
        cfg.gemini_config_dir / "plugins" / "ponytail" / "skills",
    )
    codex_skills_dir = cfg.codex_dir / "skills"
    codex_skills_dir.mkdir(parents=True, exist_ok=True)
    if cfg.opencode_enabled:
        (cfg.opencode_dir / "skills").mkdir(parents=True, exist_ok=True)

    valid_skills: set[str] = set()
    opencode_valid_skills: set[str] = set()

    for s_dir in search_dirs:
        if not s_dir.is_dir():
            continue
        for skill_path in sorted(s_dir.iterdir()):
            if skill_path.name.startswith("."):
                continue
            if not (skill_path.is_dir() and (skill_path / "SKILL.md").is_file()):
                continue
            skill_name = skill_path.name
            if skill_name in valid_skills:
                continue
            valid_skills.add(skill_name)

            link_skill_into(codex_skills_dir, skill_name, skill_path, skill_name, skill_backup_root)

            if cfg.copilot_enabled:
                link_skill_into(
                    cfg.copilot_dir / "skills", skill_name, skill_path, f"copilot-{skill_name}", skill_backup_root
                )

            if cfg.opencode_enabled:
                opencode_skills_dir = cfg.opencode_dir / "skills"
                if not (agents_skills_dir / skill_name / "SKILL.md").is_file():
                    link_skill_into(
                        opencode_skills_dir, skill_name, skill_path, f"opencode-{skill_name}", skill_backup_root
                    )
                    opencode_valid_skills.add(skill_name)
                else:
                    opencode_dest = opencode_skills_dir / skill_name
                    if os.path.lexists(opencode_dest):
                        is_managed = opencode_dest.is_symlink() and is_managed_link_target(
                            os.readlink(opencode_dest), search_dirs
                        )
                        if not is_managed:
                            bak = skill_backup_root / f"opencode-{skill_name}.bak.{int(time.time())}"
                            backup_with_collision_avoidance(opencode_dest, bak)

            if s_dir == agents_skills_dir:
                gemini_skills_dir = cfg.gemini_config_dir / "skills"
                gemini_skills_dir.mkdir(parents=True, exist_ok=True)
                gemini_skill = gemini_skills_dir / skill_name
                if not os.path.lexists(gemini_skill) or gemini_skill.is_symlink():
                    atomic_symlink(skill_path, gemini_skill)

    prune_managed_skill_symlinks(codex_skills_dir, valid_skills, search_dirs)
    prune_managed_skill_symlinks(cfg.gemini_config_dir / "skills", valid_skills, search_dirs)
    if cfg.opencode_enabled:
        prune_managed_skill_symlinks(cfg.opencode_dir / "skills", opencode_valid_skills, search_dirs)
    if cfg.copilot_enabled:
        prune_managed_skill_symlinks(cfg.copilot_dir / "skills", valid_skills, search_dirs)

    print("Synchronized shared skills and AGENTS.md instructions across agents")


def build_parser() -> argparse.ArgumentParser:
    """Create CLI subcommand parser invoked by bin/mcp-sync."""
    parser = argparse.ArgumentParser(prog="mcp_sync.py")
    sub = parser.add_subparsers(dest="subcommand", required=True)

    p_ssh = sub.add_parser("sync-ssh-profiles")
    p_ssh.add_argument("--ssh-config", required=True, type=Path)
    p_ssh.add_argument("--target", required=True, type=Path)

    p_docker = sub.add_parser("sync-docker-profiles")
    p_docker.add_argument("--ssh-profiles", required=True, type=Path)
    p_docker.add_argument("--target", required=True, type=Path)

    p_k3s = sub.add_parser("sync-k3s")
    p_k3s.add_argument("--home", required=True, type=Path)

    p_mcp = sub.add_parser("sync-mcp-config")
    p_mcp.add_argument("--template", required=True, type=Path)
    p_mcp.add_argument("--antigravity", required=True, type=Path)
    p_mcp.add_argument("--codex", required=True, type=Path)
    p_mcp.add_argument("--codex-template", required=True, type=Path)
    p_mcp.add_argument("--opencode", required=True, type=Path)
    p_mcp.add_argument("--copilot", required=True, type=Path)

    p_bak = sub.add_parser("backup")
    p_bak.add_argument("--src", required=True, type=Path)
    p_bak.add_argument("--base-dest", required=True, type=Path)

    p_skills = sub.add_parser("sync-skills")
    p_skills.add_argument("--home", required=True, type=Path)
    p_skills.add_argument("--repo-dir", required=True, type=Path)
    p_skills.add_argument("--gemini-dir", required=True, type=Path)
    p_skills.add_argument("--gemini-config-dir", required=True, type=Path)
    p_skills.add_argument("--codex-dir", required=True, type=Path)
    p_skills.add_argument("--opencode-dir", required=True, type=Path)
    p_skills.add_argument("--copilot-dir", required=True, type=Path)
    p_skills.add_argument("--local-bin-dir", required=True, type=Path)
    p_skills.add_argument("--opencode-enabled", required=True, type=int, choices=(0, 1))
    p_skills.add_argument("--copilot-enabled", required=True, type=int, choices=(0, 1))

    return parser


def main(argv: list[str] | None = None) -> int:
    """Dispatch CLI subcommands."""
    args = build_parser().parse_args(argv)
    if args.subcommand == "sync-ssh-profiles":
        sync_ssh_profiles(args.ssh_config, args.target)
    elif args.subcommand == "sync-docker-profiles":
        sync_docker_profiles(args.ssh_profiles, args.target)
    elif args.subcommand == "sync-k3s":
        sync_k3s_cluster(args.home)
    elif args.subcommand == "sync-mcp-config":
        sync_mcp_config(
            args.template,
            args.antigravity,
            args.codex,
            args.codex_template,
            args.opencode,
            args.copilot,
        )
    elif args.subcommand == "backup":
        backup_with_collision_avoidance(args.src, args.base_dest)
    elif args.subcommand == "sync-skills":
        sync_skills_and_instructions(
            SyncSkillsConfig(
                home=args.home,
                repo_dir=args.repo_dir,
                gemini_dir=args.gemini_dir,
                gemini_config_dir=args.gemini_config_dir,
                codex_dir=args.codex_dir,
                opencode_dir=args.opencode_dir,
                copilot_dir=args.copilot_dir,
                local_bin_dir=args.local_bin_dir,
                opencode_enabled=bool(args.opencode_enabled),
                copilot_enabled=bool(args.copilot_enabled),
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
