#!/usr/bin/env python3
"""Unit tests for scripts/lint_agents.py using zero external dependencies."""

from __future__ import annotations

import io
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import lint_agents


def init_git_repo(repo: Path, tracked_paths: list[str]) -> None:
    """Initialize a Git repo at ``repo`` and stage ``tracked_paths``."""
    subprocess.run(["git", "-C", str(repo), "init"], check=True, capture_output=True)
    if tracked_paths:
        subprocess.run(
            ["git", "-C", str(repo), "add", "--", *tracked_paths],
            check=True,
            capture_output=True,
        )


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

            missing_skills_repo = root / "missing-skills"
            (missing_skills_repo / "dotfiles" / "gemini").mkdir(parents=True)
            (missing_skills_repo / "dotfiles" / "gemini" / "GEMINI.md").write_text("# Clean\n", encoding="utf-8")
            out_buf = io.StringIO()
            err_buf = io.StringIO()
            with redirect_stdout(out_buf), redirect_stderr(err_buf):
                missing_code = lint_agents.main(["--repo-dir", str(missing_skills_repo)])
            self.assertEqual(missing_code, 1)
            self.assertIn("missing agent-skills directory", err_buf.getvalue())

    def test_frontmatter_comments_and_block_modifiers_parse(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    'name: demo-skill # inline comment\n'
                    "description: |+2\n"
                    "  Line one.\n"
                    "  Line two.\n"
                    "---\n\n"
                    "# Body\n"
                ),
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(issues, [])

    def test_escaped_backticks_stray_brackets_and_reference_links(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "Escaped \\`not code [broken](references/missing.md)\n"
                    "[ok](references/guide.md) stray](references/should-not-match.md)\n"
                    "[missing-ref]: references/missing-ref.md\n"
                    "[ok-ref]: <references/my guide.md>\n"
                ),
                extra_files={
                    "references/guide.md": "# Guide\n",
                    "references/my guide.md": "# Spaced Guide\n",
                },
            )

            issues = lint_agents.lint_repository(repo)

            messages = [issue.message for issue in issues]
            self.assertEqual(
                messages,
                [
                    "broken relative link target: references/missing.md",
                    "broken relative link target: references/missing-ref.md",
                ],
            )

    def test_yaml_null_comment_only_and_unterminated_quotes_fail(self) -> None:
        for bad_description in ("# TODO", "null", "~", '"unterminated'):
            with self.subTest(description=bad_description), tempfile.TemporaryDirectory() as tmp:
                repo = write_skill_repo(
                    Path(tmp),
                    skill_md=f"---\nname: demo-skill\ndescription: {bad_description}\n---\n",
                )

                issues = lint_agents.lint_repository(repo)

                self.assertEqual(len(issues), 1)

    def test_binary_skill_assets_are_skipped_while_invalid_utf8_docs_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(Path(tmp))
            skill_dir = repo / "dotfiles" / "agent-skills" / "demo-skill"
            assets_dir = skill_dir / "assets"
            assets_dir.mkdir(parents=True)
            (assets_dir / "logo.png").write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR")

            self.assertEqual(lint_agents.lint_repository(repo), [])

            refs_dir = skill_dir / "references"
            refs_dir.mkdir(parents=True)
            (refs_dir / "broken.md").write_bytes(b"\xff\xfe\xfd")

            issues = lint_agents.lint_repository(repo)
            self.assertEqual(len(issues), 1)
            self.assertIn("file is not valid UTF-8", issues[0].message)

    def test_git_tracked_files_catch_hidden_and_ignore_untracked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                extra_files={
                    ".hidden.md": "Broken [hidden](references/missing-hidden.md).\n",
                    "references/untracked-bad.md": "Bad \u2014 dash and [x](nope.md).\n",
                },
            )
            untracked_skill = repo / "dotfiles" / "agent-skills" / "untracked-skill"
            untracked_skill.mkdir(parents=True)
            (untracked_skill / "SKILL.md").write_text("---\nname: wrong\n---\n", encoding="utf-8")

            init_git_repo(
                repo,
                [
                    "dotfiles/gemini/GEMINI.md",
                    "dotfiles/agent-skills/demo-skill/SKILL.md",
                    "dotfiles/agent-skills/demo-skill/.hidden.md",
                ],
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(len(issues), 1)
            self.assertEqual(
                issues[0].path,
                (repo / "dotfiles" / "agent-skills" / "demo-skill" / ".hidden.md").resolve(),
            )
            self.assertIn("references/missing-hidden.md", issues[0].message)

            # Fix the tracked hidden file and verify untracked files and dirs remain excluded.
            (repo / "dotfiles" / "agent-skills" / "demo-skill" / ".hidden.md").write_text(
                "Back to [skill](SKILL.md).\n",
                encoding="utf-8",
            )
            out_buf = io.StringIO()
            err_buf = io.StringIO()
            with redirect_stdout(out_buf), redirect_stderr(err_buf):
                code = lint_agents.main(["--repo-dir", str(repo)])
            self.assertEqual(code, 0)
            self.assertIn("Validated 1 agent skill(s)", out_buf.getvalue())

    def test_git_repo_with_zero_tracked_skills_reports_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(Path(tmp))
            init_git_repo(repo, ["dotfiles/gemini/GEMINI.md"])

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(len(issues), 1)
            self.assertIn("no tracked skill directories found", issues[0].message)

    def test_git_tracked_link_to_untracked_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "See [guide](references/untracked.md).\n"
                ),
                extra_files={
                    "references/untracked.md": "# Local only\n",
                },
            )
            init_git_repo(
                repo,
                [
                    "dotfiles/gemini/GEMINI.md",
                    "dotfiles/agent-skills/demo-skill/SKILL.md",
                ],
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(len(issues), 1)
            self.assertIn("broken relative link target: references/untracked.md", issues[0].message)

    def test_duplicate_yaml_keys_fail(self) -> None:
        for dup_key in ("name", "description"):
            with self.subTest(key=dup_key), tempfile.TemporaryDirectory() as tmp:
                extra = "name: demo-skill\n" if dup_key == "name" else "description: Second.\n"
                repo = write_skill_repo(
                    Path(tmp),
                    skill_md=(
                        "---\n"
                        "name: demo-skill\n"
                        "description: First.\n"
                        f"{extra}"
                        "---\n"
                    ),
                )

                issues = lint_agents.lint_repository(repo)

                self.assertEqual(len(issues), 1)
                self.assertIn(f"duplicate YAML frontmatter key: {dup_key!r}", issues[0].message)

    def test_non_string_and_malformed_yaml_descriptions_fail(self) -> None:
        cases = (
            ("mapping", "description:\n  nested: value\n"),
            ("sequence", "description:\n  - one\n  - two\n"),
            ("flow_sequence", "description: [a, b]\n"),
            ("flow_mapping", "description: {a: 1}\n"),
            ("bool_true", "description: true\n"),
            ("bool_yes", "description: YES\n"),
            ("int_val", "description: 123\n"),
            ("float_val", "description: 3.14\n"),
            ("unclosed_flow", "description: [unclosed\n"),
            ("quoted_cont", 'description: "hello"\n  world\n'),
        )
        for label, desc_block in cases:
            with self.subTest(case=label), tempfile.TemporaryDirectory() as tmp:
                repo = write_skill_repo(
                    Path(tmp),
                    skill_md=f"---\nname: demo-skill\n{desc_block}---\n",
                )

                issues = lint_agents.lint_repository(repo)

                self.assertEqual(len(issues), 1)

        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: First line\n"
                    "  second line.\n"
                    "---\n"
                ),
            )
            self.assertEqual(lint_agents.lint_repository(repo), [])

    def test_multiline_inline_code_and_blockquoted_fences(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "Start `inline code\n"
                    "[example](references/missing-inline.md)` end.\n\n"
                    "> ```markdown\n"
                    "> [quoted-fence](references/missing-fence.md)\n"
                    "> ```\n\n"
                    "> ~~~\n"
                    "> [unclosed-blockquote-fence](references/missing-q2.md)\n\n"
                    "Unclosed `code span before blank line\n\n"
                    "[after-blank](references/missing-after-blank.md)\n"
                ),
            )

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].message, "broken relative link target: references/missing-after-blank.md")

    def test_escaped_filenames_protocol_relative_urls_backslashes_and_markdown_ext(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "Escaped dest [parens](references/a\\(b\\).md) and [star](references/my\\*file.md).\n"
                    "Network [cdn](//example.com/path) and [cdn-ref].\n"
                    "Escaped opener \\[ignored](references/missing-esc.md).\n"
                    "Double backslash \\\\[caught](references/missing-even.md).\n"
                    "Balanced [nested [tag]](references/missing-nested.md).\n\n"
                    "[cdn-ref]: //example.com/ref\n"
                    "[cdn-angle]: <//example.com/angle>\n"
                ),
                extra_files={
                    "references/a(b).md": "# Parens\n",
                    "references/my*file.md": "# Star\n",
                    "references/extra.markdown": "Broken [dot-markdown](missing-md.md).\n",
                },
            )

            issues = lint_agents.lint_repository(repo)

            messages = [issue.message for issue in issues]
            self.assertEqual(
                messages,
                [
                    "broken relative link target: references/missing-even.md",
                    "broken relative link target: references/missing-nested.md",
                    "broken relative link target: missing-md.md",
                ],
            )

    def test_unlisted_and_large_binary_assets_sniff_without_whole_file_read(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(Path(tmp))
            skill_dir = repo / "dotfiles" / "agent-skills" / "demo-skill"
            assets_dir = skill_dir / "assets"
            assets_dir.mkdir(parents=True)

            (assets_dir / "clip.mp3").write_bytes(b"ID3\x03\x00\x00\x00")
            (assets_dir / "opaque.dat").write_bytes(b"\xff\xfe\xfd")
            large_binary = assets_dir / "large.blob"
            large_binary.write_bytes(b"\xff\xfe\xfd" * 6000)

            orig_read_bytes = Path.read_bytes
            read_bytes_calls: list[Path] = []

            def spy_read_bytes(path_self: Path) -> bytes:
                read_bytes_calls.append(path_self)
                return orig_read_bytes(path_self)

            with mock.patch.object(Path, "read_bytes", spy_read_bytes):
                issues = lint_agents.lint_repository(repo)

            self.assertEqual(issues, [])
            self.assertNotIn(large_binary, read_bytes_calls)

            # A large unlisted valid UTF-8 file with a multi-byte char across the 8192 boundary is still checked.
            utf8_split = assets_dir / "large.unknown"
            payload = ("a" * 8191) + "\u20ac" + ("b" * 9000) + "\u2014"
            utf8_split.write_bytes(payload.encode("utf-8"))

            issues = lint_agents.lint_repository(repo)
            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].path, utf8_split.resolve())
            self.assertIn("forbidden em dash (U+2014)", issues[0].message)

    def test_unmatched_backticks_preserve_links_while_matched_multiline_spans_ignore_them(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: Valid description.\n"
                    "---\n\n"
                    "A literal unmatched ` marker before [guide](references/missing-inline.md).\n\n"
                    "Some `unmatched\n"
                    "- [broken](references/missing-list.md)\n\n"
                    "Matched `multiline\n"
                    "code [ignored](references/ignored.md)` span.\n\n"
                    "> ```\n"
                    "> `unclosed inside quoted fence\n"
                    "[after-fence](references/missing-after-fence.md)\n"
                ),
            )

            issues = lint_agents.lint_repository(repo)

            messages = [issue.message for issue in issues]
            self.assertEqual(
                messages,
                [
                    "broken relative link target: references/missing-inline.md",
                    "broken relative link target: references/missing-list.md",
                    "broken relative link target: references/missing-after-fence.md",
                ],
            )
            self.assertEqual(
                lint_agents.strip_inline_code("A literal unmatched ` before [guide](missing.md)."),
                "A literal unmatched ` before [guide](missing.md).",
            )

    def test_yaml_flow_apostrophes_and_multiline_numeric_plain_descriptions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(
                Path(tmp),
                skill_md=(
                    "---\n"
                    "name: demo-skill\n"
                    "description: 2026\n"
                    "  planning and forecasting assistance.\n"
                    "metadata: {author: O'Reilly, team: 'ops''core'}\n"
                    "---\n"
                ),
            )
            self.assertEqual(lint_agents.lint_repository(repo), [])

        with tempfile.TemporaryDirectory() as tmp:
            single_int = write_skill_repo(
                Path(tmp),
                skill_md="---\nname: demo-skill\ndescription: 2026\n---\n",
            )
            issues = lint_agents.lint_repository(single_int)
            self.assertEqual(len(issues), 1)
            self.assertIn("must be a non-empty string", issues[0].message)

        with tempfile.TemporaryDirectory() as tmp:
            bad_flow = write_skill_repo(
                Path(tmp),
                skill_md="---\nname: demo-skill\ndescription: Valid.\nmetadata: {a: 'unclosed}\n---\n",
            )
            issues = lint_agents.lint_repository(bad_flow)
            self.assertEqual(len(issues), 1)
            self.assertIn("malformed YAML flow collection", issues[0].message)

        self.assertFalse(lint_agents._is_balanced_flow_collection("x[a]"))
        fields, fm_err = lint_agents.parse_frontmatter("---\nname: demo-skill\ndescription: x[a]\n---\n")
        self.assertIsNone(fm_err)
        assert fields is not None
        self.assertEqual(fields["description"], "x[a]")

    def test_large_unlisted_file_distinguishes_invalid_utf8_tail_from_nul_binary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = write_skill_repo(Path(tmp))
            skill_dir = repo / "dotfiles" / "agent-skills" / "demo-skill"
            assets_dir = skill_dir / "assets"
            assets_dir.mkdir(parents=True)

            bad_tail = assets_dir / "corrupt.unknown"
            bad_tail.write_bytes((b"a" * 9000) + b"\xff\xfe")

            nul_tail = assets_dir / "late-binary.unknown"
            nul_tail.write_bytes((b"a" * 9000) + b"\x00" + (b"b" * 1000))

            issues = lint_agents.lint_repository(repo)

            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].path, bad_tail.resolve())
            self.assertIn("file is not valid UTF-8", issues[0].message)

    def test_non_git_empty_skills_dir_reports_no_skill_directories(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "dotfiles" / "gemini").mkdir(parents=True)
            (root / "dotfiles" / "gemini" / "GEMINI.md").write_text("# Clean\n", encoding="utf-8")
            (root / "dotfiles" / "agent-skills").mkdir(parents=True)

            issues = lint_agents.lint_repository(root)

            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].message, "no skill directories found")


if __name__ == "__main__":
    unittest.main()
