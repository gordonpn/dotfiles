---
name: local-db-cli
description: Inspect and query local or containerized SQLite, PostgreSQL, and Redis databases using sqlite3, psql, and redis-cli with read-only defaults and secret-safe authentication.
---

# Local database CLI workflow (SQLite, PostgreSQL, Redis)

Use native database CLIs (`sqlite3`, `psql`/`pgcli`, `redis-cli`) instead of static `sqlite`, `postgres`, and `redis` MCP servers. This avoids hardcoding single database paths or plaintext `POSTGRES_URL` credentials in MCP configuration files.

## 1. SQLite (`sqlite3`)

`/usr/bin/sqlite3` ships with macOS. On Linux, install the `sqlite3` package with the distribution package manager (for example, `sudo apt install sqlite3`) before using these commands. Always pass `-readonly` when inspecting or diagnosing databases so queries cannot mutate state or create stray database files.

```bash
# List tables and views in read-only mode
sqlite3 -readonly path/to/database.db ".tables"

# Inspect full schema or a specific table schema
sqlite3 -readonly path/to/database.db ".schema"
sqlite3 -readonly path/to/database.db ".schema users"

# Run a read-only query with JSON or column output
sqlite3 -readonly -json path/to/database.db "SELECT id, email FROM users LIMIT 10;"
sqlite3 -readonly -header -column path/to/database.db "PRAGMA table_info(users);"
```

For multi-line queries, place the SQL in a dedicated `.sql` file and execute `sqlite3 -readonly path/to/database.db ".read query.sql"`.

## 2. PostgreSQL (`psql` / `pgcli`)

Use `psql` (installed on macOS via keg-only Homebrew `libpq` at `"$(brew --prefix libpq)/bin/psql"` or linked to `/opt/homebrew/bin/psql` via `brew link --force libpq`, or via `docker exec` / `kubectl exec` against a running Postgres container/pod when `psql` is not installed on the host). Enforce read-only sessions via `PGOPTIONS='-c default_transaction_read_only=on'` (because a single `-c` string runs inside one implicit transaction where `SET default_transaction_read_only = on;` would only affect subsequent transactions) or wrap `.sql` file queries in `BEGIN READ ONLY; ...; COMMIT;`.

```bash
# Inspect tables and schema using environment variables or ~/.pgpass (never inline password URIs)
PGOPTIONS='-c default_transaction_read_only=on' psql --no-psqlrc -v ON_ERROR_STOP=1 -c "\dt"
PGOPTIONS='-c default_transaction_read_only=on' psql --no-psqlrc -v ON_ERROR_STOP=1 -c "\d+ table_name"

# Run a read-only query from a single-line -c command or dedicated .sql file
PGOPTIONS='-c default_transaction_read_only=on' psql --no-psqlrc -v ON_ERROR_STOP=1 --csv -c "SELECT count(*) FROM events;"
PGOPTIONS='-c default_transaction_read_only=on' psql --no-psqlrc -v ON_ERROR_STOP=1 -f query.sql

# Execute against a containerized or Kubernetes Postgres instance when local psql is absent
kubectl exec -n <namespace> <postgres-pod> -- env PGOPTIONS='-c default_transaction_read_only=on' psql -U <user> -d <db> -v ON_ERROR_STOP=1 -c "\dt"
```

## 3. Redis (`redis-cli`)

Use `redis-cli` (`/opt/homebrew/bin/redis-cli` via Homebrew `redis` on macOS, or via `docker exec` / `kubectl exec`). Always prefer non-blocking `--scan` over `KEYS *`.

```bash
# Connectivity and server health summary
redis-cli PING
redis-cli INFO server
redis-cli INFO memory
redis-cli INFO stats

# Non-blocking key iteration and key metadata inspection
redis-cli --scan --pattern "session:*" | head -n 20
redis-cli TYPE "session:123"
redis-cli TTL "session:123"

# Inspect slowlog entries (replaces redis_slowlog MCP tool)
redis-cli SLOWLOG GET 10
```

## MCP feature mapping and gaps

| Former MCP Server / Tool | CLI Equivalent | Notes |
| --- | --- | --- |
| `sqlite` (`read_query`, `list_tables`, `describe_table`) | `sqlite3 -readonly -json <db> "<sql>"`, `.tables`, `PRAGMA table_info(<table>)` | Works on any `.db`/`.sqlite` file without reconfiguring `${SQLITE_DB_PATH}` |
| `sqlite` (`append_insight` / `memo://insights`) | Standard Markdown notes or project artifacts | In-process MCP memo resource is not used in CLI workflows |
| `postgres` (`query`) | `PGOPTIONS='-c default_transaction_read_only=on' psql -v ON_ERROR_STOP=1 -c "<sql>"` | Supports `\d`, `EXPLAIN`, and session-level read-only transaction enforcement |
| `redis` (`redis_scan`, `redis_key_info`, `redis_health`, `redis_slowlog`) | `redis-cli --scan`, `TYPE` + `TTL`, `INFO`, `SLOWLOG GET` | Combine `INFO memory` + `INFO stats` + `SLOWLOG GET` in place of `redis_advisor` |

## Credential and data-boundary rules

- **Never embed passwords in command arguments:** Do not pass `postgresql://user:password@...` or `redis-cli -a <password>` on the command line where process tables (`ps`) or shell logs can capture them.
- **Use credential files or scoped environment variables:** Configure PostgreSQL credentials via `~/.pgpass` (`0600` permissions) or `.env` (`PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE`, `PGPASSFILE`), and Redis authentication via `REDISCLI_AUTH` sourced from an untracked `.env` or secret store.
- **Default to read-only:** Use `sqlite3 -readonly` and `PGOPTIONS='-c default_transaction_read_only=on'` (or `BEGIN READ ONLY;`) for all diagnostic and exploration queries.
- **Dedicated `.sql` files:** Keep non-trivial or multi-line SQL queries in dedicated `.sql` files rather than inline multi-line shell strings.
