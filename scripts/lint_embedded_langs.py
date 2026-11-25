#!/usr/bin/env python3
"""Zero-dependency stdlib linter guarding against new embedded language blocks."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

WORKFLOW_EXTENSIONS: frozenset[str] = frozenset({".yml", ".yaml"})
SHELL_EXTENSIONS: frozenset[str] = frozenset({".sh", ".bash", ".zsh"})
SHELL_SHEBANG_RE: re.Pattern[str] = re.compile(r"^#!.*\b(?:ba|z)?sh\b")

WORKFLOW_BLOCK_HEADER_RE: re.Pattern[str] = re.compile(
    r"^(?P<indent>[ ]*)(?P<dash>-[ ]+)?(?P<key>(?:\"[^\"]+\"|'[^']+'|[A-Za-z0-9_.-]+))[ ]*:[ ]*"
    r"(?P<style>[|>](?:[+-]?\d*|\d+[+-]?))[ ]*(?:#.*)?$"
)

FOREIGN_INTERPRETER_RE: re.Pattern[str] = re.compile(
    r"^(?:python(?:3(?:\.\d+)?)?|node(?:js)?|ruby|perl)$"
)
PYTHON_INTERPRETER_RE: re.Pattern[str] = re.compile(r"^python(?:3(?:\.\d+)?)?$")
NODE_INTERPRETER_RE: re.Pattern[str] = re.compile(r"^node(?:js)?$")
FOREIGN_HEREDOC_DELIMS: frozenset[str] = frozenset(
    {"PY", "PYTHON", "NODE", "JS", "JAVASCRIPT", "TS", "TYPESCRIPT", "RUBY", "RB", "PERL", "PL"}
)
ENV_ASSIGN_RE: re.Pattern[str] = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
WRAPPER_COMMANDS: frozenset[str] = frozenset(
    {"env", "command", "exec", "nice", "nohup", "sudo", "time", "xargs"}
)

# Audited workflow block scalars that cannot be externalized in GitHub Actions syntax.
WORKFLOW_BLOCK_ALLOWLIST: frozenset[tuple[str, str]] = frozenset(
    {
        (".github/workflows/deepseek-review.yml", "if"),
        (".github/workflows/pr-agent.yml", "if"),
        (".github/workflows/reviewdog.yml", "exclude"),
    }
)

# Audited skill-portability files mapped to their maximum allowed foreign-language blocks.
SHELL_BLOCK_ALLOWLIST: dict[str, int] = {
    "dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh": 2,
    "dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh": 0,
}


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
class _PendingHeredoc:
    """Queued heredoc declaration waiting for its body on subsequent lines."""

    delimiter: str
    strip_tabs: bool
    line: int
    cmd_tokens: tuple[str, ...]


def _unquote_yaml_key(raw_key: str) -> str:
    if len(raw_key) >= 2 and raw_key[0] == raw_key[-1] and raw_key[0] in ("'", '"'):
        return raw_key[1:-1]
    return raw_key


def _line_indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def check_workflow_text(path: Path, rel_path: str, text: str) -> list[LintIssue]:
    """Return issues for unallowlisted multi-line YAML block scalars exceeding 1 line."""
    issues: list[LintIssue] = []
    lines = text.splitlines()
    idx = 0
    total = len(lines)

    while idx < total:
        line = lines[idx]
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            idx += 1
            continue

        match = WORKFLOW_BLOCK_HEADER_RE.match(line)
        if not match:
            idx += 1
            continue

        key = _unquote_yaml_key(match.group("key"))
        key_col = len(match.group("indent")) + len(match.group("dash") or "")
        header_line = idx + 1

        cursor = idx + 1
        first_nonblank: int | None = None
        last_nonblank: int | None = None
        while cursor < total:
            body_line = lines[cursor]
            if not body_line.strip():
                cursor += 1
                continue
            if _line_indent(body_line) <= key_col:
                break
            if first_nonblank is None:
                first_nonblank = cursor
            last_nonblank = cursor
            cursor += 1

        body_line_count = (
            (last_nonblank - first_nonblank + 1)
            if first_nonblank is not None and last_nonblank is not None
            else 0
        )
        if body_line_count > 1 and (rel_path, key) not in WORKFLOW_BLOCK_ALLOWLIST:
            issues.append(
                LintIssue(
                    path=path,
                    line=header_line,
                    message=(
                        f"multi-line YAML block scalar for '{key}' ({body_line_count} lines) "
                        "should be externalized to a dedicated file"
                    ),
                )
            )

        idx = cursor

    return issues


def _strip_shell_quotes(token: str) -> str:
    if len(token) >= 2 and token[0] == token[-1] and token[0] in ("'", '"'):
        return token[1:-1]
    return token


def _command_executable(cmd_tokens: tuple[str, ...]) -> tuple[str | None, list[str]]:
    idx = 0
    n = len(cmd_tokens)
    while idx < n:
        tok = _strip_shell_quotes(cmd_tokens[idx])
        if ENV_ASSIGN_RE.match(tok) or tok in WRAPPER_COMMANDS:
            idx += 1
            continue
        return Path(tok).name.lower(), [_strip_shell_quotes(t) for t in cmd_tokens[idx + 1 :]]
    return None, []


def _is_inline_eval_flag(exe: str, flag: str) -> bool:
    if PYTHON_INTERPRETER_RE.match(exe):
        if flag in ("-c", "--command"):
            return True
        return flag.startswith("-") and not flag.startswith("--") and "c" in flag[1:]
    if NODE_INTERPRETER_RE.match(exe):
        if flag in ("-e", "--eval", "-p", "--print"):
            return True
        return flag.startswith("-") and not flag.startswith("--") and (
            "e" in flag[1:] or "p" in flag[1:]
        )
    if exe in ("ruby", "perl"):
        return flag in ("-e", "-E") or (
            flag.startswith("-") and not flag.startswith("--") and "e" in flag[1:]
        )
    return False


def _match_inline_eval_target(
    cmd_tokens: tuple[str, ...],
    current_prefix: str,
) -> str | None:
    exe, args = _command_executable(cmd_tokens)
    if exe is None or not FOREIGN_INTERPRETER_RE.match(exe):
        return None
    if current_prefix and _is_inline_eval_flag(exe, current_prefix):
        return exe
    if not current_prefix and args and _is_inline_eval_flag(exe, args[-1]):
        return exe
    return None


def _read_heredoc_delimiter(line: str, pos: int) -> tuple[str, bool, int] | None:
    n = len(line)
    strip_tabs = False
    if pos < n and line[pos] == "-":
        strip_tabs = True
        pos += 1
    while pos < n and line[pos] in (" ", "\t"):
        pos += 1
    if pos >= n:
        return None

    chars: list[str] = []
    while pos < n:
        ch = line[pos]
        if ch in (" ", "\t", ";", "&", "|", ")", "<", ">", "#"):
            break
        if ch == "'":
            pos += 1
            while pos < n and line[pos] != "'":
                chars.append(line[pos])
                pos += 1
            if pos < n and line[pos] == "'":
                pos += 1
        elif ch == '"':
            pos += 1
            while pos < n and line[pos] != '"':
                if line[pos] == "\\" and pos + 1 < n:
                    pos += 1
                chars.append(line[pos])
                pos += 1
            if pos < n and line[pos] == '"':
                pos += 1
        elif ch == "\\" and pos + 1 < n:
            pos += 1
            chars.append(line[pos])
            pos += 1
        else:
            chars.append(ch)
            pos += 1

    delim = "".join(chars)
    if not delim:
        return None
    return delim, strip_tabs, pos


def _matching_cmd_subst_closes(
    candidate: str,
    delimiter: str,
    state_stack: list[tuple[str, int, str | None]],
    paren_depths: list[int],
) -> int:
    if not candidate.startswith(delimiter):
        return 0
    suffix = candidate[len(delimiter) :]
    if not suffix or any(ch != ")" for ch in suffix):
        return 0
    closable = 0
    state_idx = len(state_stack) - 1
    depth_idx = len(paren_depths) - 1
    while (
        state_idx >= 0
        and depth_idx >= 0
        and state_stack[state_idx][0] == "cmd_subst"
        and paren_depths[depth_idx] == 0
    ):
        closable += 1
        state_idx -= 1
        depth_idx -= 1
    if len(suffix) <= closable:
        return len(suffix)
    return 0


def _consume_pending_heredocs(
    path: Path,
    lines: list[str],
    line_idx: int,
    pending_heredocs: list[_PendingHeredoc],
    issues: list[LintIssue],
    state_stack: list[tuple[str, int, str | None]],
    paren_depths: list[int],
    cmd_tokens_stack: list[list[str]],
) -> int:
    total_lines = len(lines)
    for heredoc in pending_heredocs:
        body_lines = 0
        terminated = False
        while line_idx < total_lines:
            candidate = lines[line_idx].rstrip("\r\n")
            if heredoc.strip_tabs:
                candidate = candidate.lstrip("\t")
            line_idx += 1
            if candidate == heredoc.delimiter:
                terminated = True
                break
            close_count = _matching_cmd_subst_closes(
                candidate, heredoc.delimiter, state_stack, paren_depths
            )
            if close_count > 0:
                for _ in range(close_count):
                    state_stack.pop()
                    paren_depths.pop()
                    cmd_tokens_stack.pop()
                terminated = True
                break
            body_lines += 1

        exe, _ = _command_executable(heredoc.cmd_tokens)
        is_foreign_cmd = exe is not None and bool(FOREIGN_INTERPRETER_RE.match(exe))
        is_foreign_delim = heredoc.delimiter.upper() in FOREIGN_HEREDOC_DELIMS
        if is_foreign_cmd or is_foreign_delim:
            label = exe if is_foreign_cmd and exe is not None else heredoc.delimiter
            if not terminated:
                issues.append(
                    LintIssue(
                        path=path,
                        line=heredoc.line,
                        message=(
                            f"unterminated embedded {label} heredoc (<<{heredoc.delimiter}) "
                            "reaches end of file"
                        ),
                    )
                )
            elif body_lines >= 1:
                issues.append(
                    LintIssue(
                        path=path,
                        line=heredoc.line,
                        message=(
                            f"multi-line embedded {label} heredoc (<<{heredoc.delimiter}) "
                            "should be externalized to a dedicated file"
                        ),
                    )
                )
    pending_heredocs.clear()
    return line_idx


def _scan_shell_blocks(path: Path, text: str) -> list[LintIssue]:
    issues: list[LintIssue] = []
    lines = text.splitlines(keepends=True)
    line_idx = 0
    total_lines = len(lines)

    # Stack entries: ("single" | "double" | "ansi_c" | "cmd_subst", start_line, eval_exe)
    state_stack: list[tuple[str, int, str | None]] = []
    paren_depths: list[int] = []
    cmd_tokens_stack: list[list[str]] = [[]]
    current_token: list[str] = []
    pending_heredocs: list[_PendingHeredoc] = []

    def flush_token() -> None:
        if current_token:
            cmd_tokens_stack[-1].append("".join(current_token))
            current_token.clear()

    def reset_command() -> None:
        flush_token()
        cmd_tokens_stack[-1].clear()

    while line_idx < total_lines:
        raw_line = lines[line_idx]
        line_no = line_idx + 1
        line_body = raw_line.rstrip("\r\n")
        n = len(line_body)
        col = 0
        line_continued = False

        while col < n:
            ch = line_body[col]
            top_state = state_stack[-1][0] if state_stack else "unquoted"

            if top_state == "single":
                if ch == "'":
                    _, start_line, eval_exe = state_stack.pop()
                    if eval_exe is not None and line_no > start_line:
                        issues.append(
                            LintIssue(
                                path=path,
                                line=start_line,
                                message=(
                                    f"multi-line inline {eval_exe} snippet "
                                    "should be externalized to a dedicated file"
                                ),
                            )
                        )
                current_token.append(ch)
                col += 1
                continue

            if top_state == "ansi_c":
                if ch == "\\" and col + 1 < n:
                    current_token.append(line_body[col : col + 2])
                    col += 2
                    continue
                if ch == "'":
                    state_stack.pop()
                current_token.append(ch)
                col += 1
                continue

            if top_state == "double":
                if ch == "\\" and col + 1 < n:
                    current_token.append(line_body[col : col + 2])
                    col += 2
                    continue
                if ch == "$" and col + 1 < n and line_body[col + 1] == "(":
                    if col + 2 < n and line_body[col + 2] == "(":
                        col += 2
                        continue
                    state_stack.append(("cmd_subst", line_no, None))
                    paren_depths.append(0)
                    cmd_tokens_stack.append([])
                    current_token.clear()
                    col += 2
                    continue
                if ch == '"':
                    _, start_line, eval_exe = state_stack.pop()
                    if eval_exe is not None and line_no > start_line:
                        issues.append(
                            LintIssue(
                                path=path,
                                line=start_line,
                                message=(
                                    f"multi-line inline {eval_exe} snippet "
                                    "should be externalized to a dedicated file"
                                ),
                            )
                        )
                current_token.append(ch)
                col += 1
                continue

            # Unquoted or cmd_subst mode
            if ch == "\\":
                if col == n - 1:
                    line_continued = True
                    col += 1
                    continue
                current_token.append(line_body[col : col + 2])
                col += 2
                continue

            if ch == "#" and not current_token:
                break

            if ch in (" ", "\t"):
                flush_token()
                col += 1
                continue

            if ch == "'" and (col == 0 or line_body[col - 1] != "$"):
                eval_exe = _match_inline_eval_target(
                    tuple(cmd_tokens_stack[-1]),
                    "".join(current_token),
                )
                state_stack.append(("single", line_no, eval_exe))
                current_token.append(ch)
                col += 1
                continue

            if ch == "$" and col + 1 < n and line_body[col + 1] == "'":
                state_stack.append(("ansi_c", line_no, None))
                current_token.append("$'")
                col += 2
                continue

            if ch == '"':
                eval_exe = _match_inline_eval_target(
                    tuple(cmd_tokens_stack[-1]),
                    "".join(current_token),
                )
                state_stack.append(("double", line_no, eval_exe))
                current_token.append(ch)
                col += 1
                continue

            if ch == "$" and col + 1 < n and line_body[col + 1] == "(":
                if col + 2 < n and line_body[col + 2] == "(":
                    col += 2
                    continue
                flush_token()
                state_stack.append(("cmd_subst", line_no, None))
                paren_depths.append(0)
                cmd_tokens_stack.append([])
                col += 2
                continue

            if ch == "(":
                if paren_depths:
                    paren_depths[-1] += 1
                reset_command()
                col += 1
                continue

            if ch == ")":
                if top_state == "cmd_subst" and paren_depths and paren_depths[-1] == 0:
                    flush_token()
                    state_stack.pop()
                    paren_depths.pop()
                    cmd_tokens_stack.pop()
                else:
                    if paren_depths and paren_depths[-1] > 0:
                        paren_depths[-1] -= 1
                    reset_command()
                col += 1
                continue

            if ch in (";", "{", "}"):
                reset_command()
                col += 1
                continue

            if ch in ("|", "&"):
                if col + 1 < n and line_body[col + 1] == ch:
                    col += 2
                else:
                    col += 1
                reset_command()
                continue

            if ch == "<" and col + 1 < n and line_body[col + 1] == "<":
                if col + 2 < n and line_body[col + 2] == "<":
                    flush_token()
                    col += 3
                    continue
                flush_token()
                parsed = _read_heredoc_delimiter(line_body, col + 2)
                if parsed is not None:
                    delim, strip_tabs, next_col = parsed
                    pending_heredocs.append(
                        _PendingHeredoc(
                            delimiter=delim,
                            strip_tabs=strip_tabs,
                            line=line_no,
                            cmd_tokens=tuple(cmd_tokens_stack[-1]),
                        )
                    )
                    col = next_col
                    continue

            current_token.append(ch)
            col += 1

        in_quote = bool(state_stack and state_stack[-1][0] in ("single", "double", "ansi_c"))
        if not in_quote and not line_continued:
            reset_command()

        line_idx += 1

        if pending_heredocs and not in_quote and not line_continued:
            line_idx = _consume_pending_heredocs(
                path,
                lines,
                line_idx,
                pending_heredocs,
                issues,
                state_stack,
                paren_depths,
                cmd_tokens_stack,
            )

    if pending_heredocs:
        _consume_pending_heredocs(
            path,
            lines,
            line_idx,
            pending_heredocs,
            issues,
            state_stack,
            paren_depths,
            cmd_tokens_stack,
        )

    return issues


def _deduplicate_shell_issues(issues: list[LintIssue]) -> list[LintIssue]:
    seen: set[tuple[Path, int | None]] = set()
    unique: list[LintIssue] = []
    for issue in issues:
        key = (issue.path, issue.line)
        if key not in seen:
            seen.add(key)
            unique.append(issue)
    return unique


def check_shell_text(path: Path, rel_path: str, text: str) -> list[LintIssue]:
    """Return issues for unallowlisted multi-line foreign-language blocks in a shell script."""
    detected = _deduplicate_shell_issues(_scan_shell_blocks(path, text))
    allowed_max = SHELL_BLOCK_ALLOWLIST.get(rel_path)
    if allowed_max is not None:
        if len(detected) <= allowed_max:
            return []
        return detected[allowed_max:]
    return detected


def _git_tracked_files(repo_dir: Path) -> set[Path] | None:
    try:
        proc = subprocess.run(
            ["git", "-C", str(repo_dir), "ls-files", "-z"],
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


def _has_dot_segment(rel_path: Path) -> bool:
    return any(part.startswith(".") for part in rel_path.parts)


def _is_shell_script_path(file_path: Path, rel_parts: tuple[str, ...]) -> bool:
    suffix = file_path.suffix.lower()
    if suffix in SHELL_EXTENSIONS:
        return True
    if rel_parts and rel_parts[0] == "bin" and suffix == "":
        try:
            with file_path.open("rb") as fh:
                first_line = fh.readline(256).decode("utf-8", errors="ignore")
        except OSError:
            return False
        return bool(SHELL_SHEBANG_RE.match(first_line))
    return False


def _is_target_workflow(rel_path: Path) -> bool:
    parts = rel_path.parts
    return (
        len(parts) == 3
        and parts[0] == ".github"
        and parts[1] == "workflows"
        and rel_path.suffix.lower() in WORKFLOW_EXTENSIONS
    )


def _is_target_shell_script(file_path: Path, rel_path: Path) -> bool:
    parts = rel_path.parts
    if len(parts) == 2 and parts[0] in ("bin", "scripts", "tests"):
        return _is_shell_script_path(file_path, parts)
    if len(parts) == 3 and parts[0] == ".github" and parts[1] == "scripts":
        return _is_shell_script_path(file_path, parts)
    if (
        len(parts) == 4
        and parts[0] == "dotfiles"
        and parts[1] == "gemini"
        and parts[2] == "antigravity-cli"
    ):
        return _is_shell_script_path(file_path, parts)
    if (
        len(parts) >= 5
        and parts[0] == "dotfiles"
        and parts[1] == "agent-skills"
        and parts[3] in ("scripts", "tests")
    ):
        return _is_shell_script_path(file_path, parts)
    return False


def _discover_target_files(
    repo_dir: Path,
    tracked_files: set[Path] | None,
) -> tuple[list[Path], list[Path]]:
    workflows: list[Path] = []
    shell_scripts: list[Path] = []

    if tracked_files is not None:
        candidates = sorted(p for p in tracked_files if p.is_file())
    else:
        candidates = []
        for root_sub in (
            repo_dir / ".github" / "workflows",
            repo_dir / ".github" / "scripts",
            repo_dir / "bin",
            repo_dir / "scripts",
            repo_dir / "tests",
            repo_dir / "dotfiles" / "agent-skills",
            repo_dir / "dotfiles" / "gemini" / "antigravity-cli",
        ):
            if root_sub.is_dir():
                for candidate in sorted(root_sub.rglob("*")):
                    if candidate.is_file() and not _has_dot_segment(candidate.relative_to(root_sub)):
                        candidates.append(candidate)

    for file_path in candidates:
        try:
            rel_path = file_path.relative_to(repo_dir)
        except ValueError:
            continue
        if _is_target_workflow(rel_path):
            workflows.append(file_path)
        elif _is_target_shell_script(file_path, rel_path):
            shell_scripts.append(file_path)

    return workflows, shell_scripts


def _lint_repository_with_counts(repo_dir: Path) -> tuple[list[LintIssue], int, int]:
    repo_dir = repo_dir.resolve()
    tracked_files = _git_tracked_files(repo_dir)
    workflows, shell_scripts = _discover_target_files(repo_dir, tracked_files)
    issues: list[LintIssue] = []

    for wf_path in workflows:
        rel_str = wf_path.relative_to(repo_dir).as_posix()
        try:
            text = wf_path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            issues.append(LintIssue(path=wf_path, line=None, message=f"file is not valid UTF-8: {exc}"))
            continue
        issues.extend(check_workflow_text(wf_path, rel_str, text))

    for sh_path in shell_scripts:
        rel_str = sh_path.relative_to(repo_dir).as_posix()
        try:
            text = sh_path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            issues.append(LintIssue(path=sh_path, line=None, message=f"file is not valid UTF-8: {exc}"))
            continue
        issues.extend(check_shell_text(sh_path, rel_str, text))

    return issues, len(workflows), len(shell_scripts)


def lint_repository(repo_dir: Path) -> list[LintIssue]:
    """Validate workflows and shell scripts under ``repo_dir`` for embedded language blocks."""
    issues, _, _ = _lint_repository_with_counts(repo_dir)
    return issues


def build_parser() -> argparse.ArgumentParser:
    """Create the CLI argument parser for embedded language block linting."""
    parser = argparse.ArgumentParser(
        description="Check workflows and shell scripts for unallowlisted embedded language blocks."
    )
    parser.add_argument(
        "--repo-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root directory (defaults to parent of scripts/).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run embedded-language lint checks and return 0 when clean or 1 on violations."""
    args = build_parser().parse_args(argv)
    repo_dir = args.repo_dir.resolve()
    issues, wf_count, sh_count = _lint_repository_with_counts(repo_dir)
    if issues:
        for issue in issues:
            print(issue.format(repo_dir), file=sys.stderr)
        print(f"Found {len(issues)} embedded-language lint issue(s).", file=sys.stderr)
        return 1

    print(
        f"Validated {wf_count} workflow(s) and {sh_count} shell script(s) "
        "with no unallowlisted embedded language blocks."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
