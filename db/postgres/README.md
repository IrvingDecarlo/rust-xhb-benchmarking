# PostgreSQL (Rust benchmark side)

## Docker (local)

From the repository root:

```bash
docker compose up -d
```

- **Image**: `postgres:16.4-alpine` (pinned minor in [docker-compose.yml](../../docker-compose.yml)).
- **Host port**: `5433` → container `5432`.
- **Init**: [schema.sql](schema.sql) is applied on first data directory creation.

## Connection string (fixed defaults for benchmarks)

```text
postgresql://bench:benchpassword@127.0.0.1:5433/benchmark
```

Set `DATABASE_URL` in the environment (see [.env.example](../../.env.example)) so `bench-b3` … `bench-b6` connect without extra flags.

## CI

GitHub Actions starts Postgres as a **service** on port `5432` and applies `schema.sql` with `psql` before running phases (`--postgres-url`).
