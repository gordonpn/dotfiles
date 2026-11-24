#!/usr/bin/env python3
"""Unit tests for scripts/mcp_sync.py using zero external dependencies."""

from __future__ import annotations

import io
import json
import os
import stat
import subprocess
import sys
import tempfile
import tomllib
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from typing import cast
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import mcp_sync


class TestMcpSyncHelpers(unittest.TestCase):
    """Test pure parsing, hydration, rendering, and filesystem sync helpers."""

    def test_parse_ssh_config_skips_wildcards_and_github(self) -> None:
        raw = (
            "# comment\n"
            "Host github.com\n"
            "  HostName github.com\n"
            "Host master\n"
            "  HostName 100.72.77.63\n"
            "  User deploy\n"
            "  Port 2222\n"
            "  IdentityFile ~/.ssh/custom_ed25519\n"
            "Host *\n"
            "  User ignored"
        )

        profiles = mcp_sync.parse_ssh_config(raw, default_user="alice")

        self.assertEqual(set(profiles.keys()), {"master"})
        self.assertEqual(
            profiles["master"],
            {
                "host": "100.72.77.63",
                "username": "deploy",
                "port": 2222,
                "privateKeyPath": "~/.ssh/custom_ed25519",
            },
        )

    def test_build_docker_profiles_filters_remote_keywords(self) -> None:
        ssh_data: dict[str, object] = {
            "profiles": {
                "master": {"host": "10.0.0.1"},
                "work-laptop": {"host": "10.0.0.2"},
                "rpi4": {"host": "10.0.0.3"},
            }
        }

        docker_profiles = mcp_sync.build_docker_profiles(ssh_data)

        self.assertEqual(
            docker_profiles,
            {
                "default": "local",
                "profiles": {
                    "local": {"mode": "local"},
                    "master": {"host": "10.0.0.1"},
                    "rpi4": {"host": "10.0.0.3"},
                },
            },
        )

    def test_hydrate_json_value_handles_quotes_in_secret_safely(self) -> None:
        template: dict[str, object] = {
            "mcpServers": {
                "demo": {
                    "command": "${HOME}/bin/demo",
                    "env": {"TOKEN": "${TFE_TOKEN}"},
                }
            }
        }

        hydrated = mcp_sync.hydrate_json_value(
            template,
            {"${HOME}": "/home/gordon", "${TFE_TOKEN}": 'abc"def\\ghi'},
        )

        self.assertEqual(
            hydrated,
            {
                "mcpServers": {
                    "demo": {
                        "command": "/home/gordon/bin/demo",
                        "env": {"TOKEN": 'abc"def\\ghi'},
                    }
                }
            },
        )

    def test_render_codex_toml_strips_unmanaged_and_preserves_other_sections(self) -> None:
        existing = (
            "[tui]\n"
            'copy_on_select = "always"\n'
            "\n"
            '[mcp_servers."fetch"]\n'
            'command = "old-fetch"\n'
            "\n"
            "# === BEGIN MANAGED MCP SERVERS (mcp-sync) ===\n"
            "[mcp_servers.stale]\n"
            'command = "stale"'
        )
        specs = [
            mcp_sync.ServerSpec(name="fetch", command="uvx", args=("mcp-server-fetch",), disabled=False, env={}),
            mcp_sync.ServerSpec(
                name="vault",
                command="/bin/vault-mcp",
                args=(),
                disabled=True,
                env={"VAULT_TOKEN": 'tok"1'},
            ),
        ]

        rendered, enabled_count = mcp_sync.render_codex_toml(existing, specs, mcp_sync.DEFAULT_CORE_SERVERS)

        self.assertEqual(enabled_count, 1)
        self.assertIn('[tui]\ncopy_on_select = "always"', rendered)
        self.assertNotIn("old-fetch", rendered)
        self.assertNotIn("stale", rendered)
        self.assertIn('[mcp_servers."fetch"]\ncommand = "uvx"\nargs = ["mcp-server-fetch"]', rendered)
        self.assertIn('[mcp_servers."vault"]\ncommand = "/bin/vault-mcp"\nargs = []\nenabled = false', rendered)
        self.assertIn('VAULT_TOKEN = "tok\\"1"', rendered)

    def test_strip_jsonc_preserves_urls_inside_strings(self) -> None:
        raw = '{\n// comment\n"url": "https://example.com/a//b",\n"list": [1, 2,], /* block */\n}'

        stripped = mcp_sync.strip_jsonc(raw)
        loaded = json.loads(stripped)

        self.assertEqual(loaded, {"url": "https://example.com/a//b", "list": [1, 2]})

    def test_render_opencode_and_copilot_profiles(self) -> None:
        specs = [
            mcp_sync.ServerSpec(name="fetch", command="uvx", args=("mcp-server-fetch",), disabled=False, env={}),
            mcp_sync.ServerSpec(name="docker", command="npx", args=("docker-mcp",), disabled=False, env={"A": "1"}),
            mcp_sync.ServerSpec(name="vault", command="/bin/vault", args=(), disabled=True, env={}),
        ]
        existing_opencode: dict[str, object] = {
            "theme": "flexoki",
            "mcp": {
                "custom-local": {"type": "local", "command": ["echo"], "enabled": True},
                "memory": {"type": "local", "command": ["old"], "enabled": False},
                "sqlite": {"type": "local", "command": ["old-sqlite"], "enabled": False},
                "postgres": {"type": "local", "command": ["old-pg"], "enabled": False},
            },
        }
        existing_copilot: dict[str, object] = {
            "customSetting": True,
            "mcpServers": {
                "custom-copilot": {"type": "local", "command": "echo", "args": [], "tools": ["*"]},
                "sqlite": {"type": "local", "command": "uvx", "args": ["mcp-server-sqlite"], "tools": ["*"]},
                "postgres": {"type": "local", "command": "npx", "args": ["server-postgres"], "tools": ["*"]},
            },
        }

        oc_data, oc_enabled = mcp_sync.render_opencode_config(existing_opencode, specs, mcp_sync.DEFAULT_CORE_SERVERS)
        cp_data, cp_enabled = mcp_sync.render_copilot_config(existing_copilot, specs, mcp_sync.DEFAULT_CORE_SERVERS)

        self.assertEqual(oc_enabled, 1)
        self.assertEqual(cp_enabled, 1)
        oc_mcp = cast(dict[str, dict[str, object]], oc_data["mcp"])
        self.assertIn("custom-local", oc_mcp)
        self.assertNotIn("memory", oc_mcp)
        self.assertNotIn("sqlite", oc_mcp)
        self.assertNotIn("postgres", oc_mcp)
        self.assertTrue(oc_mcp["fetch"]["enabled"])
        self.assertFalse(oc_mcp["docker"]["enabled"])
        self.assertFalse(oc_mcp["vault"]["enabled"])

        cp_mcp = cast(dict[str, dict[str, object]], cp_data["mcpServers"])
        self.assertIn("custom-copilot", cp_mcp)
        self.assertIn("fetch", cp_mcp)
        self.assertNotIn("sqlite", cp_mcp)
        self.assertNotIn("postgres", cp_mcp)
        self.assertNotIn("docker", cp_mcp)
        self.assertNotIn("vault", cp_mcp)

    def test_backup_with_collision_avoidance_and_dangling_symlinks(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / "src"
            src.write_text("second\n", encoding="utf-8")
            base_bak = root / "item.bak"
            base_bak.write_text("first\n", encoding="utf-8")

            moved = mcp_sync.backup_with_collision_avoidance(src, base_bak)

            self.assertEqual(moved, root / "item.bak.1")
            self.assertEqual(moved.read_text(encoding="utf-8"), "second\n")
            self.assertEqual(base_bak.read_text(encoding="utf-8"), "first\n")

            # Dangling symlink at destination should also increment counter.
            src2 = root / "src2"
            src2.write_text("third\n", encoding="utf-8")
            dangling = root / "item.bak.2"
            os.symlink(root / "nonexistent", dangling)

            moved2 = mcp_sync.backup_with_collision_avoidance(src2, base_bak)
            self.assertEqual(moved2, root / "item.bak.3")

    def test_sync_skills_omits_optional_clients_and_respects_opencode_native_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            home = root / "home"
            tracked = repo / "dotfiles" / "agent-skills" / "demo-skill"
            tracked.mkdir(parents=True)
            (tracked / "SKILL.md").write_text("# Demo\n", encoding="utf-8")
            rules_file = repo / "dotfiles" / "gemini" / "GEMINI.md"
            rules_file.parent.mkdir(parents=True)
            rules_file.write_text("# Rules\n", encoding="utf-8")

            cfg = mcp_sync.SyncSkillsConfig(
                home=home,
                repo_dir=repo,
                gemini_dir=home / ".gemini",
                gemini_config_dir=home / ".gemini" / "config",
                codex_dir=home / ".codex",
                opencode_dir=home / ".config" / "opencode",
                copilot_dir=home / ".copilot",
                local_bin_dir=home / ".local" / "bin",
                opencode_enabled=True,
                copilot_enabled=False,
            )

            mcp_sync.sync_skills_and_instructions(cfg)

            self.assertEqual(os.readlink(home / ".agents" / "skills" / "demo-skill"), str(tracked))
            self.assertEqual(
                os.readlink(cfg.gemini_config_dir / "skills" / "demo-skill"),
                str(home / ".agents" / "skills" / "demo-skill"),
            )
            self.assertEqual(
                os.readlink(cfg.codex_dir / "skills" / "demo-skill"),
                str(home / ".agents" / "skills" / "demo-skill"),
            )
            self.assertFalse(os.path.lexists(cfg.opencode_dir / "skills" / "demo-skill"))
            self.assertFalse(cfg.copilot_dir.exists())


    def test_sync_skills_skips_dot_prefixed_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            home = root / "home"
            hidden = repo / "dotfiles" / "agent-skills" / ".archived-skill"
            hidden.mkdir(parents=True)
            (hidden / "SKILL.md").write_text("# Hidden\n", encoding="utf-8")
            hidden_user = home / ".gemini" / "config" / "skills" / ".disabled-skill"
            hidden_user.mkdir(parents=True)
            (hidden_user / "SKILL.md").write_text("# Hidden user\n", encoding="utf-8")
            rules_file = repo / "dotfiles" / "gemini" / "GEMINI.md"
            rules_file.parent.mkdir(parents=True)
            rules_file.write_text("# Rules\n", encoding="utf-8")

            cfg = mcp_sync.SyncSkillsConfig(
                home=home,
                repo_dir=repo,
                gemini_dir=home / ".gemini",
                gemini_config_dir=home / ".gemini" / "config",
                codex_dir=home / ".codex",
                opencode_dir=home / ".config" / "opencode",
                copilot_dir=home / ".copilot",
                local_bin_dir=home / ".local" / "bin",
                opencode_enabled=False,
                copilot_enabled=False,
            )

            mcp_sync.sync_skills_and_instructions(cfg)

            self.assertFalse(os.path.lexists(home / ".agents" / "skills" / ".archived-skill"))
            self.assertFalse(os.path.lexists(cfg.codex_dir / "skills" / ".archived-skill"))
            self.assertFalse(os.path.lexists(cfg.codex_dir / "skills" / ".disabled-skill"))

    def test_atomic_symlink_preserves_matching_and_replaces_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src_a = root / "src_a"
            src_b = root / "src_b"
            src_a.write_text("a\n", encoding="utf-8")
            src_b.write_text("b\n", encoding="utf-8")
            dest = root / "dest"

            mcp_sync.atomic_symlink(src_a, dest)
            first_ino = dest.lstat().st_ino
            mcp_sync.atomic_symlink(src_a, dest)
            self.assertEqual(dest.lstat().st_ino, first_ino)

            mcp_sync.atomic_symlink(src_b, dest)
            self.assertEqual(os.readlink(dest), str(src_b))

    def test_sync_k3s_cluster_writes_0600_and_handles_missing_ssh(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)

            with mock.patch("mcp_sync.subprocess.run", side_effect=FileNotFoundError("ssh")):
                mcp_sync.sync_k3s_cluster(home)
            self.assertFalse((home / ".kube" / "config").exists())

            sample_kube = (
                "apiVersion: v1\n"
                "clusters:\n"
                "- cluster:\n"
                "    server: https://127.0.0.1:6443\n"
                "  name: default\n"
            )
            with (
                mock.patch("mcp_sync.subprocess.run", return_value=subprocess.CompletedProcess([], 0)),
                mock.patch("mcp_sync.subprocess.check_output", side_effect=[sample_kube, "merged: true\n"]),
            ):
                mcp_sync.sync_k3s_cluster(home)

            kube_cfg = home / ".kube" / "config"
            self.assertTrue(kube_cfg.is_file())
            self.assertEqual(stat.S_IMODE(kube_cfg.stat().st_mode), 0o600)
            self.assertFalse((home / ".kube" / "k3s-master-tmp.yaml").exists())

    def test_parse_ssh_config_handles_aliases_missing_hostname_and_quoted_port(self) -> None:
        raw = (
            "Host master master-lan\n"
            "  HostName 100.72.77.63\n"
            '  Port "2222"\n'
            "Host direct.example.org\n"
            "  User ops\n"
        )

        profiles = mcp_sync.parse_ssh_config(raw, default_user="alice")

        self.assertEqual(set(profiles.keys()), {"master", "master-lan", "direct.example.org"})
        self.assertEqual(profiles["master"]["port"], 2222)
        self.assertEqual(profiles["master-lan"]["host"], "100.72.77.63")
        self.assertEqual(
            profiles["direct.example.org"],
            {
                "host": "direct.example.org",
                "username": "ops",
                "port": 22,
                "privateKeyPath": "~/.ssh/id_ed25519",
            },
        )

    def test_rewrite_k3s_kubeconfig_renames_refs_consistently(self) -> None:
        sample = (
            "apiVersion: v1\n"
            "clusters:\n"
            "- cluster:\n"
            "    certificate-authority-data: CA\n"
            "    server: https://127.0.0.1:6443\n"
            "  name: default\n"
            "contexts:\n"
            "- context:\n"
            "    cluster: default\n"
            "    user: default\n"
            "  name: default\n"
            "current-context: default\n"
            "kind: Config\n"
            "users:\n"
            "- name: default\n"
            "  user:\n"
            "    client-certificate-data: NEW_CERT\n"
        )

        rewritten = mcp_sync.rewrite_k3s_kubeconfig(sample)

        self.assertIn("server: https://master:6443", rewritten)
        self.assertIn("cluster: k3s-master", rewritten)
        self.assertIn("user: k3s-master-user", rewritten)
        self.assertIn("current-context: k3s-master", rewritten)
        self.assertIn("users:\n- name: k3s-master-user\n", rewritten)
        self.assertNotIn("default", rewritten)

    def test_sync_k3s_cluster_refreshes_existing_kubeconfig_and_preserves_context(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            kube_cfg = home / ".kube" / "config"
            kube_cfg.parent.mkdir(parents=True)
            kube_cfg.write_text("current-context: prod\n", encoding="utf-8")

            seen_kubeconfigs: list[str] = []

            def fake_run(cmd: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
                if cmd[:2] == ["kubectl", "--kubeconfig"] and cmd[-2:] == ["config", "current-context"]:
                    return subprocess.CompletedProcess(cmd, 0, stdout="prod\n", stderr="")
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

            def fake_check_output(cmd: list[str], **kwargs: object) -> str:
                if cmd[0] == "ssh":
                    return "current-context: default\n"
                env = cast(dict[str, str], kwargs["env"])
                seen_kubeconfigs.append(env["KUBECONFIG"])
                return "current-context: prod\n"

            with (
                mock.patch("mcp_sync.subprocess.run", side_effect=fake_run),
                mock.patch("mcp_sync.subprocess.check_output", side_effect=fake_check_output),
            ):
                mcp_sync.sync_k3s_cluster(home)

            self.assertEqual(len(seen_kubeconfigs), 1)
            parts = seen_kubeconfigs[0].split(":")
            self.assertEqual(len(parts), 2)
            self.assertIn(".config-clean-", parts[0])
            self.assertIn(".k3s-master-tmp-", parts[1])

    def test_hydrate_json_value_single_pass_prevents_chained_substitution(self) -> None:
        value = {"arg": "${SQLITE_DB_PATH}", "combined": "${VAULT_ADDR}/${VAULT_TOKEN}"}

        hydrated = mcp_sync.hydrate_json_value(
            value,
            {
                "${SQLITE_DB_PATH}": "/tmp/${VAULT_TOKEN}",
                "${VAULT_ADDR}": "https://vault.local",
                "${VAULT_TOKEN}": "secret",
            },
        )

        self.assertEqual(
            hydrated,
            {"arg": "/tmp/${VAULT_TOKEN}", "combined": "https://vault.local/secret"},
        )

    def test_render_codex_toml_preserves_indented_sections_and_strips_single_quoted(self) -> None:
        existing = (
            "[mcp_servers.'git']\n"
            'command = "old-git"\n'
            "\n"
            "  [tui]\n"
            '  copy_on_select = "always"\n'
        )
        specs = [mcp_sync.ServerSpec(name="git", command="uvx", args=("mcp-server-git",), disabled=False, env={})]

        rendered, enabled = mcp_sync.render_codex_toml(existing, specs, frozenset({"git"}))
        parsed = tomllib.loads(rendered)

        self.assertEqual(enabled, 1)
        self.assertIn("  [tui]\n", rendered)
        self.assertEqual(cast(dict[str, object], parsed["tui"])["copy_on_select"], "always")
        self.assertEqual(cast(dict[str, dict[str, object]], parsed["mcp_servers"])["git"]["command"], "uvx")

    def test_strip_jsonc_preserves_token_boundaries_on_comments(self) -> None:
        malformed = '{"n": 1/* comment */2}'

        stripped = mcp_sync.strip_jsonc(malformed)

        with self.assertRaises(json.JSONDecodeError):
            json.loads(stripped)

    def test_prune_managed_skill_symlinks_prunes_target_lacking_skill_md(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared_root = root / "agents_skills"
            target_dir = root / "gemini_skills"
            skill_dir = shared_root / "alpha"
            skill_dir.mkdir(parents=True)
            target_dir.mkdir(parents=True)
            link_path = target_dir / "alpha"
            os.symlink(skill_dir, link_path)

            mcp_sync.prune_managed_skill_symlinks(target_dir, {"alpha"}, (shared_root,))

            self.assertFalse(os.path.lexists(link_path))

    def test_resolve_cclsp_bin_prefers_explicit_then_pnpm_v12_then_path_then_v10(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            pnpm_home = root / "pnpm"
            custom_bin = root / "custom" / "cclsp"
            v12_bin = pnpm_home / "bin" / "cclsp"
            v10_bin = pnpm_home / "cclsp"
            path_dir = root / "bin"
            path_bin = path_dir / "cclsp"
            for candidate in (custom_bin, v12_bin, v10_bin, path_bin):
                candidate.parent.mkdir(parents=True, exist_ok=True)
                candidate.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
                candidate.chmod(0o755)

            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(
                    home, {"CCLSP_BIN": str(custom_bin), "PNPM_HOME": str(pnpm_home), "PATH": str(path_dir)}
                ),
                str(custom_bin),
            )
            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(home, {"PNPM_HOME": str(pnpm_home), "PATH": str(path_dir)}),
                str(v12_bin),
            )

            v12_bin.unlink()
            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(home, {"PNPM_HOME": str(pnpm_home), "PATH": str(path_dir)}),
                str(path_bin),
            )

            path_bin.unlink()
            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(home, {"PNPM_HOME": str(pnpm_home), "PATH": ""}),
                str(v10_bin),
            )

            v10_bin.unlink()
            stderr_buf = io.StringIO()
            with redirect_stderr(stderr_buf):
                fallback = mcp_sync.resolve_cclsp_bin(home, {"PATH": ""})
            self.assertEqual(fallback, str(home / ".local" / "share" / "pnpm" / "bin" / "cclsp"))
            self.assertIn("Warning: cclsp executable not found; falling back to", stderr_buf.getvalue())

    def test_resolve_cclsp_bin_rejects_nonexistent_and_non_executable_overrides(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            missing = root / "missing" / "cclsp"
            non_exec = root / "non_exec" / "cclsp"
            non_exec.parent.mkdir(parents=True)
            non_exec.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            non_exec.chmod(0o644)

            with self.assertRaises(ValueError) as missing_ctx:
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": str(missing)})
            self.assertIn("CCLSP_BIN is not an executable file", str(missing_ctx.exception))

            with self.assertRaises(ValueError) as non_exec_ctx:
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": str(non_exec)})
            self.assertIn("CCLSP_BIN is not an executable file", str(non_exec_ctx.exception))

            with self.assertRaises(ValueError) as dir_ctx:
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": str(non_exec.parent)})
            self.assertIn("CCLSP_BIN is not an executable file", str(dir_ctx.exception))

    def test_sync_mcp_config_exits_nonzero_on_invalid_cclsp_bin_without_writing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            template = root / "mcp_config.template.json"
            template.write_text(
                json.dumps({"mcpServers": {"cclsp": {"command": "${CCLSP_BIN}", "args": []}}}),
                encoding="utf-8",
            )
            agy_cfg = root / "agy.json"
            codex_cfg = root / "codex.toml"
            codex_tpl = root / "codex.template.toml"
            opencode_cfg = root / "opencode.json"
            copilot_cfg = root / "copilot.json"

            stderr_buf = io.StringIO()
            with (
                mock.patch.dict(os.environ, {"HOME": str(root), "CCLSP_BIN": str(root / "nope" / "cclsp")}, clear=True),
                redirect_stderr(stderr_buf),
                self.assertRaises(SystemExit) as exit_ctx,
            ):
                mcp_sync.sync_mcp_config(template, agy_cfg, codex_cfg, codex_tpl, opencode_cfg, copilot_cfg)

            self.assertEqual(exit_ctx.exception.code, 1)
            self.assertIn("Error: CCLSP_BIN is not an executable file", stderr_buf.getvalue())
            self.assertFalse(agy_cfg.exists())
            self.assertFalse(codex_cfg.exists())
            self.assertFalse(opencode_cfg.exists())
            self.assertFalse(copilot_cfg.exists())

    def test_resolve_cclsp_bin_trims_whitespace_and_handles_whitespace_only_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            pnpm_home = root / "pnpm"
            v12_bin = pnpm_home / "bin" / "cclsp"
            custom_bin = root / "custom" / "cclsp"
            for candidate in (v12_bin, custom_bin):
                candidate.parent.mkdir(parents=True, exist_ok=True)
                candidate.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
                candidate.chmod(0o755)

            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": f"  {custom_bin}  ", "PNPM_HOME": str(pnpm_home)}),
                str(custom_bin),
            )
            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": "   ", "PNPM_HOME": str(pnpm_home), "PATH": ""}),
                str(v12_bin),
            )

    def test_resolve_cclsp_bin_normalizes_relative_paths_without_dereferencing_symlinks(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prev_cwd = Path.cwd()
            try:
                os.chdir(tmp)
                cwd = Path.cwd()
                home = cwd / "home"
                other_dir = cwd / "elsewhere"
                other_dir.mkdir(parents=True)

                target_bin = cwd / "real" / "cclsp-target"
                target_bin.parent.mkdir(parents=True)
                target_bin.write_text("#!/bin/sh\nprintf 'ok\\n'\n", encoding="utf-8")
                target_bin.chmod(0o755)

                rel_bin = cwd / "bin" / "cclsp"
                rel_bin.parent.mkdir(parents=True)
                os.symlink(target_bin, rel_bin)

                resolved_explicit = mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": "./bin/cclsp"})
                self.assertEqual(resolved_explicit, str(rel_bin))
                self.assertTrue(Path(resolved_explicit).is_absolute())

                pnpm_v12 = cwd / "pnpm" / "bin" / "cclsp"
                pnpm_v12.parent.mkdir(parents=True)
                os.symlink(target_bin, pnpm_v12)
                resolved_pnpm = mcp_sync.resolve_cclsp_bin(home, {"PNPM_HOME": "./pnpm", "PATH": ""})
                self.assertEqual(resolved_pnpm, str(pnpm_v12))

                rel_path_bin = cwd / "rel-bin" / "cclsp"
                rel_path_bin.parent.mkdir(parents=True)
                os.symlink(target_bin, rel_path_bin)
                resolved_path = mcp_sync.resolve_cclsp_bin(home, {"PNPM_HOME": str(cwd / "missing"), "PATH": "./rel-bin"})
                self.assertEqual(resolved_path, str(rel_path_bin))

                for resolved in (resolved_explicit, resolved_pnpm, resolved_path):
                    proc = subprocess.run([resolved], cwd=other_dir, capture_output=True, text=True, check=True)
                    self.assertEqual(proc.stdout.strip(), "ok")
            finally:
                os.chdir(prev_cwd)

    def test_resolve_cclsp_bin_handles_bare_command_name_on_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            bin_dir = root / "tools"
            bin_dir.mkdir(parents=True)
            cmd_bin = bin_dir / "my-cclsp"
            cmd_bin.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            cmd_bin.chmod(0o755)

            self.assertEqual(
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": "my-cclsp", "PATH": str(bin_dir)}),
                str(cmd_bin),
            )

            with self.assertRaises(ValueError) as ctx:
                mcp_sync.resolve_cclsp_bin(home, {"CCLSP_BIN": "my-cclsp", "PATH": ""})
            self.assertIn("CCLSP_BIN command not found on PATH: my-cclsp", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
