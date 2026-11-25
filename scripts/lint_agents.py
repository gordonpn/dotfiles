#!/usr/bin/env python3
"""Zero-dependency stdlib validator for tracked agent skills and instruction files."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TypeAlias
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
QUOTE_PREFIX_RE: re.Pattern[str] = re.compile(r"^(?:[ \t]{0,3}>[ \t]?)*")
FENCE_RE: re.Pattern[str] = re.compile(r"^((?:[ \t]{0,3}>[ \t]?)*)[ \t]*(`{3,}|~{3,})")
ATX_HEADING_RE: re.Pattern[str] = re.compile(r"^[ \t]{0,3}#{1,6}(?:[ \t]|$)")
THEMATIC_BREAK_RE: re.Pattern[str] = re.compile(
    r"^[ \t]{0,3}(?:(\*[ \t]*){3,}|(-[ \t]*){3,}|(_[ \t]*){3,})$"
)
LIST_ITEM_RE: re.Pattern[str] = re.compile(r"^[ \t]{0,3}(?:[-+*]|\d{1,9}[.)])[ \t]+")
TABLE_ROW_RE: re.Pattern[str] = re.compile(r"^[ \t]*\|")
COMMONMARK_ESCAPE_RE: re.Pattern[str] = re.compile(
    r"\\([!\"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~])"
)
YAML_KEY_RE: re.Pattern[str] = re.compile(r"^([A-Za-z0-9_-]+):(.*)$")
YAML_NESTED_KEY_RE: re.Pattern[str] = re.compile(r"^[A-Za-z0-9_-]+:(?:\s|$)")
YAML_BLOCK_INDICATOR_RE: re.Pattern[str] = re.compile(r"^[|>](?:[+-]?\d*|\d+[+-]?)$")
YAML_INT_RE: re.Pattern[str] = re.compile(r"^[+-]?\d+$")
YAML_FLOAT_RE: re.Pattern[str] = re.compile(
    r"^(?:[+-]?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?|[+-]?\d+[eE][+-]?\d+)$"
)
YAML_BOOL_VALUES: dict[str, bool] = {
    "true": True,
    "false": False,
    "yes": True,
    "no": False,
    "on": True,
    "off": False,
}
YAML_SPECIAL_FLOATS: dict[str, float] = {
    ".inf": float("inf"),
    "+.inf": float("inf"),
    "-.inf": float("-inf"),
    ".nan": float("nan"),
}
REF_LINK_DEF_RE: re.Pattern[str] = re.compile(
    r"^[ \t]{0,3}\[[^\]\r\n]+\]:[ \t]*(?:<([^>\r\n]+)>|([^\s\r\n]+))"
)
MAX_SNIFF_BYTES: int = 8192
SNIFF_CHUNK_SIZE: int = 65536
MARKDOWN_EXTENSIONS: frozenset[str] = frozenset({".md", ".markdown"})
BINARY_EXTENSIONS: frozenset[str] = frozenset(
    {
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".webp",
        ".ico",
        ".bmp",
        ".tiff",
        ".avif",
        ".heic",
        ".mp3",
        ".mp4",
        ".wav",
        ".ogg",
        ".webm",
        ".mov",
        ".avi",
        ".flac",
        ".pdf",
        ".woff",
        ".woff2",
        ".ttf",
        ".otf",
        ".eot",
        ".zip",
        ".tar",
        ".gz",
        ".bz2",
        ".xz",
        ".7z",
        ".wasm",
        ".bin",
        ".exe",
        ".dll",
        ".so",
        ".dylib",
        ".pyc",
        ".db",
        ".sqlite",
        ".sqlite3",
    }
)
TEXT_EXTENSIONS: frozenset[str] = frozenset(
    {
        ".md",
        ".markdown",
        ".txt",
        ".sh",
        ".bash",
        ".zsh",
        ".py",
        ".json",
        ".yaml",
        ".yml",
        ".toml",
        ".js",
        ".ts",
        ".mjs",
        ".cjs",
        ".css",
        ".html",
        ".xml",
        ".svg",
        ".sql",
        ".csv",
        ".ini",
        ".cfg",
        ".conf",
    }
)


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


@dataclass(frozen=True)
class _YamlCollection:
    """Marker for non-string YAML collection values (mappings or sequences)."""

    kind: str


YamlValue: TypeAlias = str | bool | int | float | _YamlCollection | None


def _strip_yaml_comment(raw: str) -> str:
    in_single = False
    in_double = False
    escaped = False
    for idx, ch in enumerate(raw):
        if escaped:
            escaped = False
            continue
        if in_double and ch == "\\":
            escaped = True
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double and (idx == 0 or raw[idx - 1].isspace()):
            return raw[:idx].rstrip()
    return raw.strip()


def _parse_quoted_yaml_scalar(value: str) -> tuple[str | None, str | None]:
    quote = value[0]
    n = len(value)
    if n < 2:
        return None, "unterminated quoted YAML scalar"

    if quote == '"':
        idx = 1
        while idx < n:
            ch = value[idx]
            if ch == "\\":
                idx += 2
                continue
            if ch == '"':
                if idx == n - 1:
                    return value[1:-1], None
                return None, "unexpected trailing characters after quoted YAML scalar"
            idx += 1
        return None, "unterminated quoted YAML scalar"

    idx = 1
    while idx < n:
        if value[idx] == "'":
            if idx + 1 < n and value[idx + 1] == "'":
                idx += 2
                continue
            if idx == n - 1:
                return value[1:-1].replace("''", "'"), None
            return None, "unexpected trailing characters after quoted YAML scalar"
        idx += 1
    return None, "unterminated quoted YAML scalar"


def _is_balanced_flow_collection(value: str) -> bool:
    if not value or value[0] not in "[{":
        return False
    stack: list[str] = []
    in_single = False
    in_double = False
    idx = 0
    n = len(value)
    while idx < n:
        ch = value[idx]
        if in_double:
            if ch == "\\":
                idx += 2
                continue
            if ch == '"':
                in_double = False
            idx += 1
            continue
        if in_single:
            if ch == "'":
                if idx + 1 < n and value[idx + 1] == "'":
                    idx += 2
                    continue
                in_single = False
            idx += 1
            continue
        if ch in ('"', "'"):
            # Quotes inside plain flow scalars (e.g. O'Reilly) stay literal unless
            # preceded by whitespace or a YAML flow delimiter.
            if idx == 0 or value[idx - 1].isspace() or value[idx - 1] in "[{,:":
                if ch == '"':
                    in_double = True
                else:
                    in_single = True
        elif ch == "[":
            stack.append("]")
        elif ch == "{":
            stack.append("}")
        elif ch in ("]", "}"):
            if not stack or stack.pop() != ch:
                return False
            if not stack and idx != n - 1:
                return False
        idx += 1
    return not in_single and not in_double and not stack


def _parse_yaml_scalar(raw: str) -> tuple[YamlValue, bool, str | None]:
    """Return ``(value, is_quoted, error_message)`` for a YAML scalar line."""
    value = raw.strip()
    if not value:
        return None, False, None
    if value[0] in ("'", '"'):
        quoted_val, quoted_err = _parse_quoted_yaml_scalar(value)
        return quoted_val, True, quoted_err
    if value[0] in ("]", "}"):
        return None, False, "unexpected YAML flow collection delimiter"
    if value[0] in ("[", "{"):
        if not _is_balanced_flow_collection(value):
            return None, False, "malformed YAML flow collection"
        kind = "sequence" if value[0] == "[" else "mapping"
        return _YamlCollection(kind), False, None
    lowered = value.lower()
    if lowered == "null" or value == "~":
        return None, False, None
    if lowered in YAML_BOOL_VALUES:
        return YAML_BOOL_VALUES[lowered], False, None
    if lowered in YAML_SPECIAL_FLOATS:
        return YAML_SPECIAL_FLOATS[lowered], False, None
    if YAML_INT_RE.match(value):
        return int(value, 10), False, None
    if YAML_FLOAT_RE.match(value):
        return float(value), False, None
    return value, False, None


def parse_frontmatter(text: str) -> tuple[dict[str, YamlValue] | None, str | None]:
    """Parse top-level YAML frontmatter key-value pairs from a Markdown document.

    Accepts a document beginning with a ``---`` delimiter line and closed by a
    subsequent ``---`` delimiter line. Supports typed scalars (strings,
    booleans, numbers, null), folded/literal block scalars (``|``, ``>`` with
    optional chomping or indent indicators), flow collections, nested
    mappings/sequences, and plain multiline continuations. Rejects duplicate
    keys and malformed syntax. Returns ``(fields, None)`` on success or
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

    fields: dict[str, YamlValue] = {}
    current_key: str | None = None
    block_lines: list[str] = []
    block_mode = False
    current_is_quoted = False
    current_is_collection = False
    current_plain_lines: list[str] | None = None

    def flush_current() -> str | None:
        nonlocal current_key, block_lines, block_mode
        nonlocal current_is_quoted, current_is_collection, current_plain_lines
        if current_key is not None:
            if block_mode:
                fields[current_key] = "\n".join(block_lines).strip()
            elif current_plain_lines is not None:
                joined = " ".join(current_plain_lines)
                scalar_val, _, scalar_err = _parse_yaml_scalar(joined)
                if scalar_err is not None:
                    return f"{scalar_err} for {current_key!r}"
                fields[current_key] = scalar_val
        current_key = None
        block_lines = []
        block_mode = False
        current_is_quoted = False
        current_is_collection = False
        current_plain_lines = None
        return None

    for line in lines[1:closing_idx]:
        if not line.strip():
            if block_mode:
                block_lines.append("")
            continue
        if line.lstrip().startswith("#") and not block_mode:
            continue

        if line[0] in (" ", "\t"):
            if current_key is None:
                return None, f"unexpected indented YAML line: {line!r}"
            if block_mode:
                block_lines.append(line.strip())
                continue
            if current_is_quoted:
                return None, f"invalid indented continuation after quoted scalar for {current_key!r}"
            if current_is_collection:
                continue

            stripped = _strip_yaml_comment(line.strip())
            if not stripped:
                continue
            if current_plain_lines is None:
                return None, f"invalid indented continuation for {current_key!r}"
            if not current_plain_lines and (stripped == "-" or stripped.startswith("- ")):
                fields[current_key] = _YamlCollection("sequence")
                current_is_collection = True
                current_plain_lines = None
                continue
            if not current_plain_lines and YAML_NESTED_KEY_RE.match(stripped):
                fields[current_key] = _YamlCollection("mapping")
                current_is_collection = True
                current_plain_lines = None
                continue

            current_plain_lines.append(stripped)
            continue

        flush_err = flush_current()
        if flush_err is not None:
            return None, flush_err
        match = YAML_KEY_RE.match(line)
        if not match:
            return None, f"invalid YAML frontmatter line: {line!r}"
        key = match.group(1)
        if key in fields:
            return None, f"duplicate YAML frontmatter key: {key!r}"

        raw_rest = _strip_yaml_comment(match.group(2).strip())
        current_key = key
        if YAML_BLOCK_INDICATOR_RE.match(raw_rest):
            block_mode = True
            fields[key] = ""
            continue

        if raw_rest == "":
            fields[key] = None
            current_plain_lines = []
            continue

        if raw_rest[0] in ("'", '"', "[", "{", "]", "}"):
            scalar_val, is_quoted, scalar_err = _parse_yaml_scalar(raw_rest)
            if scalar_err is not None:
                return None, f"{scalar_err} for {key!r}"
            fields[key] = scalar_val
            current_is_quoted = is_quoted
            current_is_collection = isinstance(scalar_val, _YamlCollection)
            current_plain_lines = None
            continue

        # Defer scalar typing until continuation lines are joined so multiline
        # plain descriptions starting with numbers or booleans stay strings.
        current_plain_lines = [raw_rest]

    flush_err = flush_current()
    if flush_err is not None:
        return None, flush_err
    return fields, None


def _is_escaped(text: str, pos: int) -> bool:
    bs_count = 0
    cursor = pos - 1
    while cursor >= 0 and text[cursor] == "\\":
        bs_count += 1
        cursor -= 1
    return bs_count % 2 == 1


def _find_unescaped_open_bracket(line: str, floor: int, close_pos: int) -> int:
    depth = 0
    pos = close_pos - 1
    while pos >= floor:
        if not _is_escaped(line, pos):
            if line[pos] == "]":
                depth += 1
            elif line[pos] == "[":
                if depth == 0:
                    return pos
                depth -= 1
        pos -= 1
    return -1


def _mask_inline_code_spans(text: str) -> str:
    """Replace matched inline backtick code spans with spaces, preserving newlines."""
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] != "`":
            out.append(text[i])
            i += 1
            continue

        if _is_escaped(text, i):
            out.append("`")
            i += 1
            continue

        tick_len = 0
        while i + tick_len < n and text[i + tick_len] == "`":
            tick_len += 1

        close_pos = -1
        search_idx = i + tick_len
        while search_idx < n:
            if text[search_idx] == "`":
                run_len = 0
                while search_idx + run_len < n and text[search_idx + run_len] == "`":
                    run_len += 1
                if run_len == tick_len:
                    close_pos = search_idx
                    break
                search_idx += run_len
            else:
                search_idx += 1

        if close_pos != -1:
            end_pos = close_pos + tick_len
            for ch in text[i:end_pos]:
                out.append("\n" if ch == "\n" else " ")
            i = end_pos
        else:
            out.append(text[i : i + tick_len])
            i += tick_len

    return "".join(out)


def strip_inline_code(line: str) -> str:
    """Replace matched inline backtick code spans on a single line with spaces."""
    return _mask_inline_code_spans(line)


def _is_external_or_anchor(target: str) -> bool:
    return target.startswith(("#", "//")) or bool(URI_SCHEME_RE.match(target))


def _extract_link_target(raw_inside_parens: str) -> str:
    trimmed = raw_inside_parens.strip()
    if not trimmed:
        return ""
    if trimmed.startswith("<") and ">" in trimmed:
        return trimmed[1 : trimmed.index(">")].strip()
    return trimmed.split()[0]


def extract_relative_markdown_links(text: str) -> list[tuple[int, str]]:
    """Extract relative single-line Markdown link targets outside code blocks and spans.

    Supports inline ``[text](target)`` links and reference-style link definitions
    ``[id]: target``. Ignores fenced code blocks (including blockquoted fences),
    matched multiline inline backtick spans within a paragraph, external URI
    schemes, protocol-relative network-path URLs, and pure ``#anchor`` links.
    Returns ``(line_number, raw_target)`` pairs, preserving empty targets so
    broken ``[text]()`` links can be reported.
    """
    links: list[tuple[int, str]] = []
    fence_char: str | None = None
    fence_len = 0
    fence_quote_depth = 0
    prev_quote_depth = 0
    paragraph_lines: list[tuple[int, str]] = []

    def _scan_inline_links(line_no: int, line: str) -> None:
        idx = 0
        search_floor = 0
        length = len(line)
        while idx < length:
            bracket_close = line.find("](", idx)
            if bracket_close == -1:
                break
            if _is_escaped(line, bracket_close):
                idx = bracket_close + 2
                continue
            # Require an unescaped '[' after the previous completed link on this line.
            open_bracket = _find_unescaped_open_bracket(line, search_floor, bracket_close)
            if open_bracket == -1:
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
            search_floor = idx

            if _is_external_or_anchor(target):
                continue
            links.append((line_no, target))

    def flush_paragraph() -> None:
        if not paragraph_lines:
            return
        masked_text = _mask_inline_code_spans("\n".join(line for _, line in paragraph_lines))
        for (line_no, _), masked_line in zip(paragraph_lines, masked_text.split("\n"), strict=True):
            _scan_inline_links(line_no, masked_line)
        paragraph_lines.clear()

    for line_no, raw_line in enumerate(text.splitlines(), start=1):
        quote_match = QUOTE_PREFIX_RE.match(raw_line)
        quote_prefix = quote_match.group(0) if quote_match else ""
        line_quote_depth = quote_prefix.count(">")
        content_after_quote = raw_line[len(quote_prefix) :]

        if fence_char is not None and fence_quote_depth > 0 and line_quote_depth < fence_quote_depth:
            fence_char = None
            fence_len = 0
            fence_quote_depth = 0
            flush_paragraph()

        fence_match = FENCE_RE.match(raw_line)
        if fence_match:
            quote_depth = fence_match.group(1).count(">")
            marker = fence_match.group(2)
            trailing = raw_line[fence_match.end() :]
            if fence_char is None:
                if not (marker[0] == "`" and "`" in trailing):
                    flush_paragraph()
                    fence_char = marker[0]
                    fence_len = len(marker)
                    fence_quote_depth = quote_depth
                    prev_quote_depth = line_quote_depth
                    continue
            elif (
                quote_depth == fence_quote_depth
                and marker[0] == fence_char
                and len(marker) >= fence_len
                and trailing.strip() == ""
            ):
                fence_char = None
                fence_len = 0
                fence_quote_depth = 0
                flush_paragraph()
                prev_quote_depth = line_quote_depth
                continue

        if fence_char is not None:
            prev_quote_depth = line_quote_depth
            continue

        if not content_after_quote.strip():
            flush_paragraph()
            prev_quote_depth = line_quote_depth
            continue

        if line_quote_depth != prev_quote_depth:
            flush_paragraph()

        prev_quote_depth = line_quote_depth

        if THEMATIC_BREAK_RE.match(content_after_quote):
            flush_paragraph()
            continue

        if ATX_HEADING_RE.match(content_after_quote) or TABLE_ROW_RE.match(content_after_quote):
            flush_paragraph()
            paragraph_lines.append((line_no, raw_line))
            flush_paragraph()
            continue

        if LIST_ITEM_RE.match(content_after_quote):
            flush_paragraph()
            paragraph_lines.append((line_no, raw_line))
            continue

        ref_match = REF_LINK_DEF_RE.match(content_after_quote)
        if ref_match:
            flush_paragraph()
            ref_target = (ref_match.group(1) or ref_match.group(2) or "").strip()
            if not _is_external_or_anchor(ref_target):
                links.append((line_no, ref_target))
            continue

        paragraph_lines.append((line_no, raw_line))

    flush_paragraph()
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


def _git_tracked_files(repo_dir: Path) -> set[Path] | None:
    try:
        proc = subprocess.run(
            [
                "git",
                "-C",
                str(repo_dir),
                "ls-files",
                "-z",
                "--",
                "dotfiles/agent-skills",
                "dotfiles/gemini/GEMINI.md",
            ],
            capture_output=True,
            check=False,
        )
    except OSError:
        return None
    if proc.returncode != 0:
        return None
    return {
        repo_dir / os.fsdecode(raw_entry)
        for raw_entry in proc.stdout.split(b"\x00")
        if raw_entry
    }


def _discover_skill_dirs(repo_dir: Path, tracked_files: set[Path] | None) -> list[Path]:
    skills_dir = repo_dir / "dotfiles" / "agent-skills"
    if not skills_dir.is_dir():
        return []
    if tracked_files is None:
        return [p for p in sorted(skills_dir.iterdir()) if p.is_dir() and not p.name.startswith(".")]

    discovered: set[Path] = set()
    for tracked_path in tracked_files:
        try:
            rel = tracked_path.relative_to(skills_dir)
        except ValueError:
            continue
        if len(rel.parts) >= 2:
            discovered.add(skills_dir / rel.parts[0])
    return sorted(discovered)


def _decode_sniffed_text(file_path: Path) -> tuple[str | None, str | None]:
    """Sniff up to ``MAX_SNIFF_BYTES`` bytes to skip binary assets without whole-file reads.

    Returns ``(text, None)`` for valid UTF-8 text, ``(None, None)`` for binary
    assets that should be skipped, or ``(None, error_message)`` for files with
    a valid UTF-8 prefix and an invalid UTF-8 tail.
    """
    with file_path.open("rb") as fh:
        head = fh.read(MAX_SNIFF_BYTES + 1)
        if b"\x00" in head:
            return None, None

        if len(head) <= MAX_SNIFF_BYTES:
            try:
                return head.decode("utf-8"), None
            except UnicodeDecodeError:
                return None, None

        prefix = head[:MAX_SNIFF_BYTES]
        try:
            prefix.decode("utf-8")
        except UnicodeDecodeError as exc:
            if exc.reason != "unexpected end of data" or exc.start < len(prefix) - 3:
                return None, None

        chunks = [head]
        while True:
            chunk = fh.read(SNIFF_CHUNK_SIZE)
            if not chunk:
                break
            if b"\x00" in chunk:
                return None, None
            chunks.append(chunk)

    raw_bytes = b"".join(chunks)
    try:
        return raw_bytes.decode("utf-8"), None
    except UnicodeDecodeError as exc:
        return None, f"file is not valid UTF-8: {exc}"


def _validate_frontmatter_fields(
    skill_md: Path,
    skill_dir_name: str,
    fields: dict[str, YamlValue],
) -> list[LintIssue]:
    issues: list[LintIssue] = []

    if "name" not in fields or fields["name"] is None:
        issues.append(LintIssue(path=skill_md, line=1, message="frontmatter missing non-empty 'name'"))
    else:
        name_val = fields["name"]
        if not isinstance(name_val, str):
            issues.append(
                LintIssue(path=skill_md, line=1, message="frontmatter 'name' must be a non-empty string")
            )
        else:
            name = name_val.strip()
            if not name:
                issues.append(
                    LintIssue(path=skill_md, line=1, message="frontmatter missing non-empty 'name'")
                )
            elif name != skill_dir_name:
                issues.append(
                    LintIssue(
                        path=skill_md,
                        line=1,
                        message=f"frontmatter 'name' ({name!r}) does not match folder name ({skill_dir_name!r})",
                    )
                )

    if "description" not in fields or fields["description"] is None:
        issues.append(LintIssue(path=skill_md, line=1, message="frontmatter missing non-empty 'description'"))
    else:
        desc_val = fields["description"]
        if not isinstance(desc_val, str):
            issues.append(
                LintIssue(path=skill_md, line=1, message="frontmatter 'description' must be a non-empty string")
            )
        elif not desc_val.strip():
            issues.append(
                LintIssue(path=skill_md, line=1, message="frontmatter missing non-empty 'description'")
            )

    return issues


def validate_skill_dir(
    skill_dir: Path,
    tracked_files: set[Path] | None = None,
    resolved_tracked: set[Path] | None = None,
) -> list[LintIssue]:
    """Validate frontmatter, relative Markdown links, and text formatting for one skill.

    When ``tracked_files`` is provided, it must contain canonical absolute paths
    matching ``skill_dir``; only tracked files and tracked link targets are
    validated. When ``tracked_files`` is ``None`` (non-Git fallback), all
    non-dot-prefixed files under ``skill_dir`` are checked against the
    filesystem without tracked-status enforcement.
    """
    issues: list[LintIssue] = []
    skill_md = skill_dir / "SKILL.md"
    skill_md_tracked = tracked_files is None or skill_md in tracked_files
    if not skill_md_tracked or not skill_md.is_file():
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
        issues.extend(_validate_frontmatter_fields(skill_md, skill_dir.name, fields))

    skill_root = skill_dir.resolve()
    if resolved_tracked is None and tracked_files is not None:
        resolved_tracked = {p.resolve() for p in tracked_files}
    if tracked_files is None:
        candidate_files = [
            p
            for p in sorted(skill_dir.rglob("*"))
            if p.is_file() and not _has_dot_segment(p.relative_to(skill_dir))
        ]
    else:
        candidate_files = [
            p for p in sorted(tracked_files) if p.is_relative_to(skill_dir) and p.is_file()
        ]

    for file_path in candidate_files:
        suffix = file_path.suffix.lower()
        if suffix in BINARY_EXTENSIONS:
            continue

        if suffix in TEXT_EXTENSIONS:
            try:
                text = file_path.read_bytes().decode("utf-8")
            except UnicodeDecodeError as exc:
                issues.append(LintIssue(path=file_path, line=None, message=f"file is not valid UTF-8: {exc}"))
                continue
        else:
            sniffed_text, sniff_error = _decode_sniffed_text(file_path)
            if sniff_error is not None:
                issues.append(LintIssue(path=file_path, line=None, message=sniff_error))
                continue
            if sniffed_text is None:
                continue
            text = sniffed_text

        issues.extend(check_text_formatting(file_path, text))

        if suffix in MARKDOWN_EXTENSIONS:
            for line_no, raw_target in extract_relative_markdown_links(text):
                if not raw_target:
                    issues.append(LintIssue(path=file_path, line=line_no, message="empty relative Markdown link target"))
                    continue
                unescaped_target = COMMONMARK_ESCAPE_RE.sub(r"\1", raw_target)
                clean_target = unquote(unescaped_target.split("#", 1)[0].split("?", 1)[0])
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
                elif resolved_tracked is not None:
                    is_tracked_file = resolved.is_file() and resolved in resolved_tracked
                    is_tracked_dir = resolved.is_dir() and any(
                        p.is_relative_to(resolved) for p in resolved_tracked
                    )
                    if not (is_tracked_file or is_tracked_dir):
                        issues.append(
                            LintIssue(
                                path=file_path,
                                line=line_no,
                                message=f"broken relative link target: {raw_target}",
                            )
                        )

    return issues


def _lint_repository_with_count(repo_dir: Path) -> tuple[list[LintIssue], int]:
    repo_dir = repo_dir.resolve()
    issues: list[LintIssue] = []
    tracked_files = _git_tracked_files(repo_dir)
    resolved_tracked = {p.resolve() for p in tracked_files} if tracked_files is not None else None

    gemini_rules = repo_dir / "dotfiles" / "gemini" / "GEMINI.md"
    gemini_tracked = tracked_files is None or gemini_rules in tracked_files
    if not gemini_tracked or not gemini_rules.is_file():
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
        return issues, 0

    skill_dirs = _discover_skill_dirs(repo_dir, tracked_files)
    if not skill_dirs:
        empty_msg = (
            "no skill directories found"
            if tracked_files is None
            else "no tracked skill directories found"
        )
        issues.append(LintIssue(path=skills_dir, line=None, message=empty_msg))
        return issues, 0

    for skill_dir in skill_dirs:
        issues.extend(validate_skill_dir(skill_dir, tracked_files, resolved_tracked))

    return issues, len(skill_dirs)


def lint_repository(repo_dir: Path) -> list[LintIssue]:
    """Validate tracked agent skills and shared Gemini rules under ``repo_dir``."""
    issues, _ = _lint_repository_with_count(repo_dir)
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
    issues, skill_count = _lint_repository_with_count(repo_dir)
    if issues:
        for issue in issues:
            print(issue.format(repo_dir), file=sys.stderr)
        print(f"Found {len(issues)} agent lint issue(s).", file=sys.stderr)
        return 1

    print(f"Validated {skill_count} agent skill(s) and GEMINI.md with no issues.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
