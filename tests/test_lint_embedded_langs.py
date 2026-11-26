#!/usr/bin/env python3
"""Unit tests for scripts/lint_embedded_langs.py using zero external dependencies."""

from __future__ import annotations

import io
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import lint_embedded_langs

REPO_ROOT: Path = Path(__file__).resolve().parents[1]


def write_repo_file(root: Path, rel_path: str, content: str) -> Path:
    """Write ``content`` at ``root / rel_path``, creating parent directories."""
    target = root / rel_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    return target


def init_git_repo(repo: Path, tracked_paths: list[str]) -> None:
    """Initialize a Git repo at ``repo`` and stage ``tracked_paths``."""
    subprocess.run(["git", "-C", str(repo), "init"], check=True, capture_output=True)
    if tracked_paths:
        subprocess.run(
            ["git", "-C", str(repo), "add", "--", *tracked_paths],
            check=True,
            capture_output=True,
        )


class TestLintEmbeddedLangs(unittest.TestCase):
    """Test workflow block scalar and shell embedded-language checks."""

    def test_clean_workflow_and_plain_text_heredoc_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo_file(
                root,
                ".github/workflows/ci.yml",
                (
                    "name: ci\n"
                    "on: [push]\n"
                    "jobs:\n"
                    "  test:\n"
                    "    runs-on: ubuntu-latest\n"
                    "    steps:\n"
                    "      - name: Run script\n"
                    "        run: ./.github/scripts/check.sh\n"
                    "      - name: Single-line block\n"
                    "        run: |\n"
                    "          just test\n"
                ),
            )
            write_repo_file(
                root,
                "scripts/demo.sh",
                (
                    "#!/usr/bin/env bash\n"
                    "set -euo pipefail\n"
                    "cat <<'EOF'\n"
                    "Usage: demo.sh [options]\n"
                    "Plain text help block.\n"
                    "EOF\n"
                    "printf 'prompt<<%s\\n' \"$delim\"\n"
                    "grep -q 'pattern' <<< \"${value:-}\"\n"
                    "out=$(cat <<'EOF'\n"
                    "hello\n"
                    "EOF)\n"
                ),
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(issues, [])

    def test_multiline_workflow_run_and_sys_prompt_fail_with_line_numbers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            wf_path = write_repo_file(
                root,
                ".github/workflows/bad.yml",
                (
                    "name: bad\n"
                    "jobs:\n"
                    "  review:\n"
                    "    runs-on: ubuntu-latest\n"
                    "    steps:\n"
                    "      - name: Inline shell\n"
                    "        run: |\n"
                    "          echo one\n"
                    "          echo two\n"
                    "      - name: Inline prompt\n"
                    "        with:\n"
                    "          sys-prompt: |\n"
                    "            Line one\n"
                    "            Line two\n"
                    "      - name: Folded shell\n"
                    "        run: >-\n"
                    "          echo alpha\n"
                    "          echo beta\n"
                ),
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(len(issues), 3)
            self.assertEqual(issues[0].path, wf_path.resolve())
            self.assertEqual(issues[0].line, 7)
            self.assertIn("run", issues[0].message)
            self.assertEqual(issues[1].line, 12)
            self.assertIn("sys-prompt", issues[1].message)
            self.assertEqual(issues[2].line, 16)
            self.assertIn("run", issues[2].message)

    def test_same_workflow_key_does_not_exempt_another_block(self) -> None:
        rel_path = ".github/workflows/deepseek-review.yml"
        path = REPO_ROOT / rel_path
        existing = path.read_text(encoding="utf-8")
        issues = lint_embedded_langs.check_workflow_text(
            path, rel_path, existing + "  another-job:\n    if: |\n      true\n      && false\n"
        )
        self.assertEqual(len(issues), 1)
        self.assertIn("'if'", issues[0].message)

    def test_inline_eval_requires_an_interpreter_option(self) -> None:
        path = Path("scripts/example.sh")
        cases = (
            ("if python3 -c 'print(1)\nprint(2)'; then :; fi", True),
            ("python3 -c $'print(1)\nprint(2)'", True),
            ("python3 -W ignore -c 'print(1)\nprint(2)'", True),
            ("python3 -Xtracemalloc -c 'print(1)\nprint(2)'", True),
            ("python3 -m module -c 'one\ntwo'", False),
            ("python3 script.py -c 'one\ntwo'", False),
            ("node script.js -e 'one\ntwo'", False),
        )
        for command, should_report in cases:
            with self.subTest(command=command):
                issues = lint_embedded_langs.check_shell_text(path, path.as_posix(), command)
                self.assertEqual(bool(issues), should_report)

    def test_unallowlisted_python_heredoc_and_multiline_node_or_python_eval_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sh_path = write_repo_file(
                root,
                "scripts/bad.sh",
                (
                    "#!/usr/bin/env bash\n"
                    "set -euo pipefail\n"
                    "python3 - \"$1\" <<'PY'\n"
                    "import sys\n"
                    "print(sys.argv[1])\n"
                    "PY\n"
                    "node -e \"\n"
                    "const x = 1;\n"
                    "console.log(x);\n"
                    "\"\n"
                    "python3 -c '\n"
                    "import json\n"
                    "print(json.dumps({}))\n"
                    "'\n"
                ),
            )
            bin_path = write_repo_file(
                root,
                "bin/tool",
                (
                    "#!/usr/bin/env bash\n"
                    "python - <<PY\n"
                    "print('inline')\n"
                    "PY\n"
                ),
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(len(issues), 4)
            sh_issues = [i for i in issues if i.path == sh_path.resolve()]
            bin_issues = [i for i in issues if i.path == bin_path.resolve()]
            self.assertEqual([i.line for i in sh_issues], [3, 7, 11])
            self.assertEqual([i.line for i in bin_issues], [2])

    def test_single_line_python_eval_and_non_shell_bin_are_allowed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo_file(
                root,
                "tests/helper.sh",
                (
                    "#!/usr/bin/env bash\n"
                    "tool_path=$(python3 -c 'import sys; print(sys.executable)')\n"
                    "python3 -c 'print(1)' \"multi\n"
                    "line\n"
                    "arg\"\n"
                ),
            )
            write_repo_file(
                root,
                "bin/pytool",
                (
                    "#!/usr/bin/env python3\n"
                    "print('native python binary')\n"
                ),
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(issues, [])

    def test_allowlisted_delegate_portability_passes_and_third_block_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            delegate_rel = "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh"
            two_blocks = (
                "#!/usr/bin/env bash\n"
                "python3 - <<'PY'\n"
                "print('opencode')\n"
                "PY\n"
                "python3 - <<'PY'\n"
                "print('copilot')\n"
                "PY\n"
            )
            write_repo_file(root, delegate_rel, two_blocks)

            self.assertEqual(lint_embedded_langs.lint_repository(root), [])

            write_repo_file(
                root,
                delegate_rel,
                two_blocks + "python3 - <<'PY'\nprint('regression')\nPY\n",
            )
            issues = lint_embedded_langs.lint_repository(root)
            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].line, 8)

    def test_git_tracked_discovery_ignores_untracked_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo_file(
                root,
                "scripts/clean.sh",
                "#!/usr/bin/env bash\necho ok\n",
            )
            write_repo_file(
                root,
                "scripts/untracked_bad.sh",
                "#!/usr/bin/env bash\npython3 - <<'PY'\nprint(1)\nPY\n",
            )
            init_git_repo(root, ["scripts/clean.sh"])

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(issues, [])

    def test_live_repository_passes_cleanly(self) -> None:
        resolved_root = REPO_ROOT.resolve()
        issues, wf_count, sh_count = lint_embedded_langs._lint_repository_with_counts(REPO_ROOT)

        self.assertEqual(issues, [])
        self.assertGreaterEqual(wf_count, 4)
        self.assertGreaterEqual(sh_count, 20)

        tracked_files = lint_embedded_langs._git_tracked_files(resolved_root)
        _, shell_scripts = lint_embedded_langs._discover_target_files(resolved_root, tracked_files)
        self.assertIn((resolved_root / "dotfiles/gemini/antigravity-cli/title.sh"), shell_scripts)

    def test_nested_skill_scripts_and_title_hook_are_scanned(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            nested_path = write_repo_file(
                root,
                "dotfiles/agent-skills/demo/scripts/sub/helper.sh",
                "#!/usr/bin/env bash\npython3 - <<'PY'\nprint('nested')\nPY\n",
            )
            title_path = write_repo_file(
                root,
                "dotfiles/gemini/antigravity-cli/title.sh",
                "#!/usr/bin/env bash\nnode - <<'NODE'\nconsole.log(1)\nNODE\n",
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(len(issues), 2)
            self.assertEqual(
                [(i.path, i.line) for i in issues],
                [(nested_path.resolve(), 2), (title_path.resolve(), 2)],
            )

    def test_heredoc_variants_command_subst_and_wrapper_commands(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sh_path = write_repo_file(
                root,
                "scripts/variants.sh",
                (
                    "#!/usr/bin/env bash\n"
                    "cat <<EOF; python3 - <<'PY'\n"
                    "plain text\n"
                    "EOF\n"
                    "print('fifo')\n"
                    "PY\n"
                    "python3 - <<-'PY'\n"
                    "\tprint('tabs')\n"
                    "\tPY\n"
                    "out=$(python3 - <<'PY'\n"
                    "print('subst')\n"
                    "PY\n"
                    ")\n"
                    "env python3 - <<'PY'\n"
                    "print('env')\n"
                    "PY\n"
                    "python3 - <<\"PY\"\n"
                    "print('double-quoted-delim')\n"
                    "PY\n"
                    "out=$(cat <<'EOF'\n"
                    "hello\n"
                    "EOF)\n"
                    "out=$(python3 - <<'PY'\n"
                    "print(1)\n"
                    "PY)\n"
                    "sudo python3 - <<'EOF'\n"
                    "print('sudo')\n"
                    "EOF\n"
                    "nice python3 - <<'EOF'\n"
                    "print('nice')\n"
                    "EOF\n"
                    "xargs python3 - <<'EOF'\n"
                    "print('xargs')\n"
                    "EOF\n"
                    "python3 -c \"$(\n"
                    "  echo 1\n"
                    ")\"\n"
                ),
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual([i.line for i in issues], [2, 7, 10, 14, 17, 23, 26, 29, 32, 35])
            self.assertTrue(all(i.path == sh_path.resolve() for i in issues))
            self.assertIn("python3", issues[3].message)
            self.assertIn("multi-line embedded python3 heredoc", issues[5].message)
            self.assertNotIn("unterminated", issues[5].message)
            self.assertIn("multi-line embedded python3 heredoc", issues[6].message)
            self.assertIn("multi-line embedded python3 heredoc", issues[7].message)
            self.assertIn("multi-line embedded python3 heredoc", issues[8].message)
            self.assertIn("multi-line inline python3 snippet", issues[9].message)

    def test_unterminated_foreign_heredoc_is_flagged_even_after_unterminated_fifo(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            single_bad = write_repo_file(
                root,
                "scripts/unterminated_single.sh",
                "#!/usr/bin/env bash\npython3 - <<'PY'\nprint(1)\n",
            )
            fifo_bad = write_repo_file(
                root,
                "scripts/unterminated_fifo.sh",
                "#!/usr/bin/env bash\ncat <<EOF; python3 - <<'PY'\nplain\nprint(1)\nPY\n",
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(len(issues), 2)
            self.assertEqual(
                [(i.path, i.line) for i in issues],
                [(fifo_bad.resolve(), 2), (single_bad.resolve(), 2)],
            )
            self.assertTrue(all("unterminated" in i.message for i in issues))

    def test_nested_inline_eval_and_heredoc_deduplicates_per_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sh_path = write_repo_file(
                root,
                "scripts/nested_eval.sh",
                (
                    "#!/usr/bin/env bash\n"
                    "python3 -c \"$(cat <<'PY'\n"
                    "print('nested')\n"
                    "PY\n"
                    ")\"\n"
                ),
            )
            delegate_rel = "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh"
            write_repo_file(
                root,
                delegate_rel,
                (
                    "#!/usr/bin/env bash\n"
                    "python3 -c \"$(cat <<'PY'\n"
                    "print('one')\n"
                    "PY\n"
                    ")\"\n"
                    "python3 -c \"$(cat <<'PY'\n"
                    "print('two')\n"
                    "PY\n"
                    ")\"\n"
                ),
            )

            issues = lint_embedded_langs.lint_repository(root)

            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].path, sh_path.resolve())
            self.assertEqual(issues[0].line, 2)

    def test_cli_main_returns_expected_exit_codes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            clean_repo = root / "clean"
            write_repo_file(clean_repo, "scripts/ok.sh", "#!/usr/bin/env bash\necho ok\n")

            bad_repo = root / "bad"
            write_repo_file(
                bad_repo,
                ".github/workflows/ci.yaml",
                "jobs:\n  build:\n    steps:\n      - run: |\n          echo 1\n          echo 2\n",
            )

            out_buf = io.StringIO()
            err_buf = io.StringIO()
            with redirect_stdout(out_buf), redirect_stderr(err_buf):
                ok_code = lint_embedded_langs.main(["--repo-dir", str(clean_repo)])
            self.assertEqual(ok_code, 0)
            self.assertIn("Validated 0 workflow(s) and 1 shell script(s)", out_buf.getvalue())
            self.assertEqual(err_buf.getvalue(), "")

            out_buf = io.StringIO()
            err_buf = io.StringIO()
            with redirect_stdout(out_buf), redirect_stderr(err_buf):
                bad_code = lint_embedded_langs.main(["--repo-dir", str(bad_repo)])
            self.assertEqual(bad_code, 1)
            self.assertIn(".github/workflows/ci.yaml:4:", err_buf.getvalue())
            self.assertIn("Found 1 embedded-language lint issue(s).", err_buf.getvalue())


if __name__ == "__main__":
    unittest.main()
