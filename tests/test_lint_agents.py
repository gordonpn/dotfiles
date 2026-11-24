#!/usr/bin/env python3
"""Unit tests for scripts/lint_agents.py using zero external dependencies."""

from __future__ import annotations

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import lint_agents


def write_skill_repo(
    root: Path,
    *,
    skill_dir_name: str = "demo-skill",
    skill_md: str | None = None,
    extra_files: dict[str, str] | None = None,
    gemini_md: str = "# Global Rules\n\nPlain ASCII rules.\n",
) -> Path:
    """Create a minimal repository tree containing GEMINI.md and one skill."""
    rules_path = root / "dotfiles" / "gemini" / "GEMINI.md"
    rules_path.parent.mkdir(parents=True, exist_ok=True)
    rules_path.write_text(gemini_md, encoding="utf-8")

    skill_dir = root / "dotfiles" / "agent-skills" / skill_dir_name
    skill_dir.mkdir(parents=True, exist_ok=True)
    default_skill_md = (
        "---\n"
        f"name: {skill_dir_name}\n"
        "description: Valid demo skill description.\n"
        "---\n\n"
        "# Demo\n"
    )
    (skill_dir / "SKILL.md").write_text(
        default_skill_md if skill_md is None else skill_md,
        encoding="utf-8",
    )

    if extra_files:
        for rel_path, content in extra_files.items():
            target = skill_dir / rel_path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")

    return root


class TestLintAgents(unittest.TestCase):
    """Test frontmatter, relative link, and dash/emoji validation rules."""

    def test_valid_skill_with_reference_links_and_external_urls_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "\ufeff---\n"
                    "name: demo-skill\n"
                    "description: Valid demo skill.\n"
                    "---\n\n"
                    "See [guide](references/my%20guide.md#usage) and [refs](references/).\n"
                    "Also [docs](https://example.com/docs), [section](#overview), [mail](mailto:ops@example.com).\n"
                    "Non-emoji checkmarks \u2713 and \u2717 are permitted.\n"
                ),
                extra_files={
                    "references/my guide.md": "# Guide\n\nBack to [skill](../SKILL.md).\n",
                },
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(issues, [])

    def test_mismatched_frontmatter_name_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_dir_name="demo-skill",
                skill_md=(
                    "---\n"
                    "name: other-skill\n"
                    "description: Valid description.\n"
                    "---\n"
                ),
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(len(issues), 1)
            self.assertIn("does not match folder name", issues[0].message)

    def test_missing_or_empty_description_and_missing_frontmatter_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            missing_desc = write_skill_repo(
                root / "missing_desc",
                skill_md="---\nname: demo-skill\ndescription: \"\"\n---\n",
            )
            no_fm = write_skill_repo(
                root / "no_fm",
                skill_md="# Heading without frontmatter\n",
            )

            issues_missing_desc = lint_agents.lint_repository(missing_desc)
            issues_no_fm = lint_agents.lint_repository(no_fm)

            self.assertEqual(len(issues_missing_desc), 1)
            self.assertIn("missing non-empty 'description'", issues_missing_desc[0].message)
            self.assertEqual(len(issues_no_fm), 1)
            self.assertIn("missing opening YAML frontmatter", issues_no_fm[0].message)

    def test_multiline_description_in_frontmatter_is_supported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: >\n"
                    "  Line one\n"
                    "  line two.\n"
                    "---\n"
                ),
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(issues, [])

    def test_broken_relative_links_and_directory_escapes_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "Broken [ref](references/missing.md) and [escape](../../outside.md).\n"
                ),
                extra_files={
                    "references/sub.md": "Broken [nested](nope.md).\n",
                },
            )

            issues = lint_agents.lint_repository(repo)

            messages = [issue.message for issue in issues]
            self.assertEqual(len(issues), 3)
            self.assertIn("broken relative link target: references/missing.md", messages)
            self.assertIn("relative link escapes skill directory: ../../outside.md", messages)
            self.assertIn("broken relative link target: nope.md", messages)

    def test_links_inside_code_blocks_and_inline_backticks_are_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "Inline `[ignored](references/missing.md)` and ``[also](missing2.md)``.\n\n"
                    "```markdown\n"
                    "[fenced](references/does-not-exist.md)\n"
                    "```\n\n"
                    "~~~\n"
                    "[tilde](references/missing-tilde.md)\n"
                    "~~~\n"
                ),
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(issues, [])

    def test_forbidden_em_dash_en_dash_and_emojis_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                gemini_md="# Rules\n\nNo em dash \u2014 allowed.\n",
                extra_files={
                    "references/notes.md": "Range 1\u20132 and rocket \U0001F680.\n",
                },
            )

            issues = lint_agents.lint_repository(repo)

            messages = [issue.message for issue in issues]
            self.assertEqual(len(issues), 3)
            self.assertIn("forbidden em dash (U+2014)", messages)
            self.assertIn("forbidden en dash (U+2013)", messages)
            self.assertIn("forbidden emoji (U+1F680)", messages)

    def test_cli_main_returns_expected_exit_codes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            valid_repo = write_skill_repo(root / "valid")
            invalid_repo = write_skill_repo(
                root / "invalid",
                gemini_md="# Rules\n\nBad \u2014 dash.\n",
            )

            out_buf = io.StringIO()
            err_buf = io.StringIO()
            with redirect_stdout(out_buf), redirect_stderr(err_buf):
                ok_code = lint_agents.main(["--repo-dir", str(valid_repo)])
            self.assertEqual(ok_code, 0)
            self.assertIn("Validated 1 agent skill(s)", out_buf.getvalue())
            self.assertEqual(err_buf.getvalue(), "")

            out_buf = io.StringIO()
            err_buf = io.StringIO()
            with redirect_stdout(out_buf), redirect_stderr(err_buf):
                fail_code = lint_agents.main(["--repo-dir", str(invalid_repo)])
            self.assertEqual(fail_code, 1)
            self.assertIn("forbidden em dash", err_buf.getvalue())


if __name__ == "__main__":
    unittest.main()
