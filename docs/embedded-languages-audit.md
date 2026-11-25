# Embedded Languages Audit

Inventory of multi-line embedded foreign-language blocks across workflows, shell scripts, and shell tests in `dotfiles`, evaluated against the `No Embedded Languages (Dedicated Files)` rule in [`dotfiles/gemini/GEMINI.md`](../dotfiles/gemini/GEMINI.md).

## Scope

Audited paths:

- `.github/workflows/*.yml`
- `.github/scripts/*.sh`
- `bin/*`
- `scripts/*.sh`
- `dotfiles/agent-skills/*/scripts/*.sh`
- `dotfiles/agent-skills/*/tests/*.sh`
- `dotfiles/gemini/antigravity-cli/title.sh`
- `tests/*.sh`

## Inventory and Dispositions

### GitHub Actions Workflows (`.github/workflows/`)

| File | Lines | Construct | Disposition | Rationale |
| --- | --- | --- | --- | --- |
| `.github/workflows/ci.yml` | - | None | Clean | All `run:` steps use single-line commands or invoke external scripts. |
| `.github/workflows/deepseek-review.yml` | 23-37 | `if: \|` | Intentional exception (allowlisted) | Multi-line GitHub Actions conditional expression cannot be loaded from an external file. Scripts and `sys-prompt` are already externalized to `.github/scripts/` and `.github/prompts/deepseek-review.md`. |
| `.github/workflows/pr-agent.yml` | 18-27 | `if: \|` | Intentional exception (allowlisted) | Multi-line GitHub Actions conditional expression cannot be loaded from an external file. Credential check is externalized to `.github/scripts/check-deepseek-credentials.sh`. |
| `.github/workflows/reviewdog.yml` | 42-46 | `exclude: \|` | Intentional exception (allowlisted) | `reviewdog/action-shellcheck` requires a newline-delimited glob string input and does not accept an external ignore file. |

### Shell Scripts (`bin/`, `scripts/`, `.github/scripts/`, `dotfiles/agent-skills/*/scripts/`, `dotfiles/gemini/antigravity-cli/`)

| File | Lines | Construct | Disposition | Rationale |
| --- | --- | --- | --- | --- |
| `.github/scripts/check-deepseek-credentials.sh` | - | None | Clean | Pure Bash. |
| `.github/scripts/install-actionlint.sh` | - | None | Clean | Pure Bash. |
| `.github/scripts/write-deepseek-review-prompt.sh` | - | None | Clean | Pure Bash. |
| `bin/cbcopy` | - | None | Clean | Pure Bash. |
| `bin/delta-inline` | - | None | Clean | Pure POSIX shell wrapper. |
| `bin/mcp-sync` | - | None | Clean | Delegates all Python logic to `scripts/mcp_sync.py`. |
| `bin/agy-statusline` | 18-90 | Inline `jq -r '...'` filter | Retained single-file binary (low-priority refactor candidate) | Installed as a direct symlink into `~/.local/bin/agy-statusline`; no `python`/`node` blocks. Could move to a `.jq` file via `jq -f` if expanded. |
| `dotfiles/gemini/antigravity-cli/title.sh` | 18-30 | Inline `jq -r '...'` filter | Retained single-file hook (low-priority refactor candidate) | Installed as a direct symlink into `~/.gemini/antigravity-cli/title.sh`; no `python`/`node` blocks. |
| `scripts/deepseek-analyze.sh` | 16-41 | `cat <<'EOF'` usage text | Clean | Plain-text CLI help output, not an embedded programming language. |
| `scripts/update-skills.sh` | - | None | Clean | Pure Bash. |
| `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate-analyze.sh` | - | None | Clean | Pure Bash wrapper. |
| `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate-implement.sh` | - | None | Clean | Pure Bash wrapper. |
| `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh` | 383-532, 710-888 | `python3 - ... <<'PY'` (2 blocks) | Intentional skill-portability exception (allowlisted, cap 2) | `delegate-coding-agents` is synced as a self-contained Agent Skill directory across `~/.agents/skills/` and `~/.gemini/config/skills/` and can be invoked standalone via `DELEGATE_SKILL_SCRIPT`. Keeping MCP profile JSON/JSONC/TOML resolution inside `delegate.sh` avoids coupling the skill entrypoint to repository-root `scripts/`. |
| `dotfiles/agent-skills/delegate-coding-agents/scripts/delegate.sh` | 574-593, 604-638, 642-645, 653-664 | Inline `awk` TOML/allowlist filters | Intentional skill-portability exception | Same standalone skill-portability constraint as above. |

### Shell Tests (`tests/*.sh`, `dotfiles/agent-skills/*/tests/*.sh`)

| File | Construct | Disposition | Rationale |
| --- | --- | --- | --- |
| `dotfiles/agent-skills/delegate-coding-agents/tests/test_delegate.sh` | Inline `MOCK` shell stubs (4), `JSON` (12), `JSONC` (1), and `TOML` (8) heredoc fixtures; single-line `python3 -c` (line 1308) | Intentional skill-portability exception (allowlisted, 0 multi-line `python`/`node` blocks) | Self-contained skill test suite generating isolated temp-dir mock binaries and ephemeral config fixtures per test case. |
| `tests/agy-statusline.sh` | `cat << 'EOF'` JSON stdin payloads | Test stdin fixtures | Short per-case JSON payloads piped directly to `bin/agy-statusline`. |
| `tests/agy-title.sh` | `cat << 'EOF'` JSON stdin payloads | Test stdin fixtures | Short per-case JSON payloads piped directly to `title.sh`. |
| `tests/deepseek-analyze.sh` | `sed ... <<'EOF'` mock delegate script | Test mock stub | Dynamic marker-templated shell mock inside temp dir. |
| `tests/deepseek-review-prompt.sh` | None | Clean | Reads `.github/prompts/deepseek-review.md` directly. |
| `tests/mcp-sync.sh` | `cat <<'JSON'` / `cat <<'JSONC'` config fixtures | Test fixtures (future cleanup candidate) | Candidate to extract static config fixtures to dedicated files under `tests/fixtures/` if modified substantially. |
| `tests/update-skills.sh` | `cat <<EOF` shell stubs | Test mock stubs | Short temp-dir CLI stubs (`mcp-sync-stub`, `skills`). |
| `tests/zsh-helpers.sh` | `cat <<'EOF'` / `cat <<EOF` shell stubs | Test mock stubs | Short temp-dir stubs (`antidote`, `git`). |

## Automated Enforcement Decision

Automated enforcement is **adopted** via [`scripts/lint_embedded_langs.py`](../scripts/lint_embedded_langs.py), wired into `just lint`:

- **Workflow guard:** Rejects any unallowlisted multi-line YAML block scalar (`|`, `>`, and chomping/indent variants) exceeding 1 line in `.github/workflows/*.yml` and `*.yaml`.
- **Shell guard:** Rejects any unallowlisted multi-line `python`/`python3`/`node` heredoc (such as `<<'PY'`, `<<PY`, `<<'NODE'`) or multi-line `-c`/`-e` inline snippet in shell scripts under `bin/`, `scripts/`, `.github/scripts/`, `dotfiles/agent-skills/*/scripts/`, `dotfiles/agent-skills/*/tests/`, and `tests/*.sh`.
- **Explicit allowlist:** Existing intentional exceptions in `.github/workflows/` (`deepseek-review.yml` `if`, `pr-agent.yml` `if`, `reviewdog.yml` `exclude`) and `dotfiles/agent-skills/delegate-coding-agents/` (`delegate.sh` capped at its 2 existing `python3` heredoc blocks, `test_delegate.sh` capped at 0 `python`/`node` blocks) are explicitly allowlisted by repository-relative path so CI stays green while new embedded blocks fail `just lint`.
