#!/usr/bin/env python3
"""Zero-dependency stdlib validator for tracked agent skills and instruction files."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote

FORBIDDEN_DASHES: dict[str, str] = {
    "\u2013": "en dash (U+2013)",
    "\u2014": "em dash (U+2014)",
}

# Unicode emoji ranges excluding non-emoji text symbols such as U+2713 CHECK MARK.
EMOJI_RANGES: tuple[tuple[int, int], ...] = (
    (0x231A, 0x231B),
    (0x23E9, 0x23FA),
    (0x25AA, 0x25AB),
    (0x25B6, 0x25B6),
    (0x25C0, 0x25C0),
    (0x25FB, 0x25FE),
    (0x2600, 0x2604),
    (0x260E, 0x260E),
    (0x2611, 0x2611),
    (0x2614, 0x2615),
    (0x2618, 0x2618),
    (0x261D, 0x261D),
    (0x2620, 0x2620),
    (0x2622, 0x2623),
    (0x2626, 0x2626),
    (0x262A, 0x262A),
    (0x262E, 0x262F),
    (0x2638, 0x263A),
    (0x2640, 0x2640),
    (0x2642, 0x2642),
    (0x2648, 0x2653),
    (0x265F, 0x2660),
    (0x2663, 0x2663),
    (0x2665, 0x2666),
    (0x2668, 0x2668),
    (0x267B, 0x267B),
    (0x267E, 0x267F),
    (0x2692, 0x2697),
    (0x2699, 0x2699),
    (0x269B, 0x269C),
    (0x26A0, 0x26A1),
    (0x26A7, 0x26A7),
    (0x26AA, 0x26AB),
    (0x26B0, 0x26B1),
    (0x26BD, 0x26BE),
    (0x26C4, 0x26C5),
    (0x26C8, 0x26C8),
    (0x26CE, 0x26CF),
    (0x26D1, 0x26D1),
    (0x26D3, 0x26D4),
    (0x26E9, 0x26EA),
    (0x26F0, 0x26F5),
    (0x26F7, 0x26FA),
    (0x26FD, 0x26FD),
    (0x2702, 0x2702),
    (0x2705, 0x2705),
    (0x2708, 0x270D),
    (0x270F, 0x270F),
    (0x2712, 0x2712),
    (0x2714, 0x2714),
    (0x2716, 0x2716),
    (0x271D, 0x271D),
    (0x2721, 0x2721),
    (0x2728, 0x2728),
    (0x2733, 0x2734),
    (0x2744, 0x2744),
    (0x2747, 0x2747),
    (0x274C, 0x274C),
    (0x274E, 0x274E),
    (0x2753, 0x2755),
    (0x2757, 0x2757),
    (0x2763, 0x2764),
    (0x2795, 0x2797),
    (0x27A1, 0x27A1),
    (0x27B0, 0x27B0),
    (0x27BF, 0x27BF),
    (0x2B05, 0x2B07),
    (0x2B1B, 0x2B1C),
    (0x2B50, 0x2B50),
    (0x2B55, 0x2B55),
    (0x3030, 0x3030),
    (0x303D, 0x303D),
    (0x3297, 0x3297),
    (0x3299, 0x3299),
    (0x1F000, 0x1F02F),
    (0x1F0A0, 0x1F0FF),
    (0x1F1E6, 0x1F1FF),
    (0x1F300, 0x1FAFF),
)

EMOJI_EXTRAS: frozenset[int] = frozenset({0x20E3, 0xFE0F})

URI_SCHEME_RE: re.Pattern[str] = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
FENCE_RE: re.Pattern[str] = re.compile(r"^[ \t]*(`{3,}|~{3,})")
YAML_KEY_RE: re.Pattern[str] = re.compile(r"^([A-Za-z0-9_-]+):(.*)$")


@dataclass(frozen=True)
class LintIssue:
    """Single validation failure located at a repository file and optional line."""

    path: Path
    line: int | None
    message: str

    def format(self, repo_dir: Path) -> str:
        """Render the issue as a relative path diagnostic string."""
        try:
            display_path = self.path.relative_to(repo_dir)
        except ValueError:
            display_path = self.path
        if self.line is None:
            return f"{display_path}: {self.message}"
        return f"{display_path}:{self.line}: {self.message}"


def _unquote_yaml_scalar(raw: str) -> str:
    value = raw.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value


def parse_frontmatter(text: str) -> tuple[dict[str, str] | None, str | None]:
    """Parse top-level YAML frontmatter key-value pairs from a Markdown document.

    Accepts a document beginning with a ``---`` delimiter line and closed by a
    subsequent ``---`` delimiter line. Returns ``(fields, None)`` on success or
    ``(None, error_message)`` when frontmatter is absent or malformed.
    """
    lines = text.lstrip("\ufeff").splitlines()
    if not lines or lines[0].rstrip() != "---":
        return None, "missing opening YAML frontmatter delimiter '---'"

    closing_idx: int | None = None
    for idx in range(1, len(lines)):
        if lines[idx].rstrip() == "---":
            closing_idx = idx
            break

    if closing_idx is None:
        return None, "missing closing YAML frontmatter delimiter '---'"

    fields: dict[str, str] = {}
    current_key: str | None = None
    block_lines: list[str] = []
    block_mode = False

    def flush_current() -> None:
        nonlocal current_key, block_lines, block_mode
        if current_key is not None and block_mode:
            fields[current_key] = "\n".join(block_lines).strip()
        current_key = None
        block_lines = []
        block_mode = False

    for line in lines[1:closing_idx]:
        if not line.strip():
            if block_mode:
                block_lines.append("")
            continue
        if line.lstrip().startswith("#") and not block_mode:
            continue

        if line[0] in (" ", "\t"):
            if current_key is not None:
                if block_mode:
                    block_lines.append(line.strip())
                else:
                    existing = fields.get(current_key, "")
                    joined = f"{existing} {line.strip()}".strip()
                    fields[current_key] = joined
            continue

        flush_current()
        match = YAML_KEY_RE.match(line)
        if not match:
            return None, f"invalid YAML frontmatter line: {line!r}"
        key, raw_rest = match.group(1), match.group(2).strip()
        current_key = key
        if raw_rest in ("|", "|-", ">", ">-"):
            block_mode = True
            fields[key] = ""
        else:
            fields[key] = _unquote_yaml_scalar(raw_rest)

    flush_current()
    return fields, None


def strip_inline_code(line: str) -> str:
    """Replace inline backtick code spans on a single line with spaces."""
    out: list[str] = []
    i = 0
    n = len(line)
    while i < n:
        if line[i] != "`":
            out.append(line[i])
            i += 1
            continue

        tick_len = 0
        while i + tick_len < n and line[i + tick_len] == "`":
            tick_len += 1

        close_pos = -1
        search_idx = i + tick_len
        while search_idx < n:
            if line[search_idx] == "`":
                run_len = 0
                while search_idx + run_len < n and line[search_idx + run_len] == "`":
                    run_len += 1
                if run_len == tick_len:
                    close_pos = search_idx
                    break
                search_idx += run_len
            else:
                search_idx += 1

        if close_pos != -1:
            end_pos = close_pos + tick_len
            out.append(" " * (end_pos - i))
            i = end_pos
        else:
            out.append("`" * tick_len)
            i += tick_len

    return "".join(out)


def _extract_link_target(raw_inside_parens: str) -> str:
    trimmed = raw_inside_parens.strip()
    if not trimmed:
        return ""
    if trimmed.startswith("<") and ">" in trimmed:
        return trimmed[1 : trimmed.index(">")].strip()
    return trimmed.split()[0]


def extract_relative_markdown_links(text: str) -> list[tuple[int, str]]:
    """Extract relative inline Markdown link paths outside code blocks and code spans.

    Ignores fenced code blocks, inline backtick spans, external URI schemes, and
    pure ``#anchor`` links. Returns ``(line_number, raw_target)`` pairs, preserving
    empty targets so broken ``[text]()`` links can be reported.
    """
    links: list[tuple[int, str]] = []
    fence_char: str | None = None
    fence_len = 0

    for line_no, raw_line in enumerate(text.splitlines(), start=1):
        fence_match = FENCE_RE.match(raw_line)
        if fence_match:
            marker = fence_match.group(1)
            if fence_char is None:
                fence_char = marker[0]
                fence_len = len(marker)
                continue
            if marker[0] == fence_char and len(marker) >= fence_len and raw_line[fence_match.end() :].strip() == "":
                fence_char = None
                fence_len = 0
                continue

        if fence_char is not None:
            continue

        line = strip_inline_code(raw_line)
        idx = 0
        length = len(line)
        while idx < length:
            bracket_close = line.find("](", idx)
            if bracket_close == -1:
                break
            # Require an unescaped '[' earlier on the line for a valid link span.
            open_bracket = line.rfind("[", 0, bracket_close)
            if open_bracket == -1 or (open_bracket > 0 and line[open_bracket - 1] == "\\"):
                idx = bracket_close + 2
                continue

            cursor = bracket_close + 2
            depth = 1
            while cursor < length and depth > 0:
                ch = line[cursor]
                if ch == "\\" and cursor + 1 < length:
                    cursor += 2
                    continue
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        break
                cursor += 1

            if depth != 0:
                idx = bracket_close + 2
                continue

            target = _extract_link_target(line[bracket_close + 2 : cursor])
            idx = cursor + 1

            if target.startswith("#") or URI_SCHEME_RE.match(target):
                continue
            links.append((line_no, target))

    return links


def describe_forbidden_char(ch: str) -> str | None:
    """Return a description if ``ch`` is a forbidden dash or emoji, else ``None``."""
    if ch in FORBIDDEN_DASHES:
        return FORBIDDEN_DASHES[ch]
    code = ord(ch)
    if code in EMOJI_EXTRAS:
        return f"emoji (U+{code:04X})"
    for start, end in EMOJI_RANGES:
        if start <= code <= end:
            return f"emoji (U+{code:04X})"
    return None


def check_text_formatting(path: Path, text: str) -> list[LintIssue]:
    """Check ``text`` for forbidden em dashes, en dashes, and emojis."""
    issues: list[LintIssue] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        seen_on_line: set[str] = set()
        for ch in line:
            label = describe_forbidden_char(ch)
            if label is not None and label not in seen_on_line:
                seen_on_line.add(label)
                issues.append(LintIssue(path=path, line=line_no, message=f"forbidden {label}"))
    return issues


def _has_dot_segment(rel_path: Path) -> bool:
    return any(part.startswith(".") for part in rel_path.parts)


def validate_skill_dir(skill_dir: Path) -> list[LintIssue]:
    """Validate frontmatter, relative Markdown links, and text formatting for one skill."""
    issues: list[LintIssue] = []
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        issues.append(LintIssue(path=skill_md, line=None, message="missing required SKILL.md"))
        return issues

    try:
        skill_text = skill_md.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        issues.append(LintIssue(path=skill_md, line=None, message=f"file is not valid UTF-8: {exc}"))
        return issues

    fields, fm_error = parse_frontmatter(skill_text)
    if fm_error is not None or fields is None:
        issues.append(LintIssue(path=skill_md, line=1, message=fm_error or "invalid frontmatter"))
    else:
        name = fields.get("name", "").strip()
        if not name:
            issues.append(LintIssue(path=skill_md, line=1, message="frontmatter missing non-empty 'name'"))
        elif name != skill_dir.name:
            issues.append(
                LintIssue(
                    path=skill_md,
                    line=1,
                    message=f"frontmatter 'name' ({name!r}) does not match folder name ({skill_dir.name!r})",
                )
            )
        description = fields.get("description", "").strip()
        if not description:
            issues.append(LintIssue(path=skill_md, line=1, message="frontmatter missing non-empty 'description'"))

    skill_root = skill_dir.resolve()
    for file_path in sorted(skill_dir.rglob("*")):
        if not file_path.is_file():
            continue
        rel = file_path.relative_to(skill_dir)
        if _has_dot_segment(rel):
            continue

        try:
            text = file_path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            issues.append(LintIssue(path=file_path, line=None, message=f"file is not valid UTF-8: {exc}"))
            continue

        issues.extend(check_text_formatting(file_path, text))

        if file_path.suffix.lower() == ".md":
            for line_no, raw_target in extract_relative_markdown_links(text):
                if not raw_target:
                    issues.append(LintIssue(path=file_path, line=line_no, message="empty relative Markdown link target"))
                    continue
                clean_target = unquote(raw_target.split("#", 1)[0].split("?", 1)[0])
                if not clean_target:
                    continue
                resolved = (file_path.parent / clean_target).resolve()
                if not resolved.is_relative_to(skill_root):
                    issues.append(
                        LintIssue(
                            path=file_path,
                            line=line_no,
                            message=f"relative link escapes skill directory: {raw_target}",
                        )
                    )
                elif not resolved.exists():
                    issues.append(
                        LintIssue(
                            path=file_path,
                            line=line_no,
                            message=f"broken relative link target: {raw_target}",
                        )
                    )

    return issues


def lint_repository(repo_dir: Path) -> list[LintIssue]:
    """Validate tracked agent skills and shared Gemini rules under ``repo_dir``."""
    issues: list[LintIssue] = []

    gemini_rules = repo_dir / "dotfiles" / "gemini" / "GEMINI.md"
    if not gemini_rules.is_file():
        issues.append(LintIssue(path=gemini_rules, line=None, message="missing required GEMINI.md"))
    else:
        try:
            rules_text = gemini_rules.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            issues.append(LintIssue(path=gemini_rules, line=None, message=f"file is not valid UTF-8: {exc}"))
        else:
            issues.extend(check_text_formatting(gemini_rules, rules_text))

    skills_dir = repo_dir / "dotfiles" / "agent-skills"
    if not skills_dir.is_dir():
        issues.append(LintIssue(path=skills_dir, line=None, message="missing agent-skills directory"))
        return issues

    skill_dirs = [p for p in sorted(skills_dir.iterdir()) if p.is_dir() and not p.name.startswith(".")]
    if not skill_dirs:
        issues.append(LintIssue(path=skills_dir, line=None, message="no tracked skill directories found"))
        return issues

    for skill_dir in skill_dirs:
        issues.extend(validate_skill_dir(skill_dir))

    return issues


def build_parser() -> argparse.ArgumentParser:
    """Create the CLI argument parser for agent skill and instruction linting."""
    parser = argparse.ArgumentParser(description="Validate tracked agent skills and GEMINI.md rules.")
    parser.add_argument(
        "--repo-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root directory (defaults to parent of scripts/).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run repository lint checks and return exit code 0 when clean or 1 on failure."""
    args = build_parser().parse_args(argv)
    repo_dir = args.repo_dir.resolve()
    issues = lint_repository(repo_dir)
    if issues:
        for issue in issues:
            print(issue.format(repo_dir), file=sys.stderr)
        print(f"Found {len(issues)} agent lint issue(s).", file=sys.stderr)
        return 1

    skills_dir = repo_dir / "dotfiles" / "agent-skills"
    skill_count = sum(1 for p in skills_dir.iterdir() if p.is_dir() and not p.name.startswith("."))
    print(f"Validated {skill_count} agent skill(s) and GEMINI.md with no issues.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
