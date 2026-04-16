# Cleanup / Side effects

This repo is designed to be safe to run on a developer machine, but it **does** create files, build binaries, and (optionally) start Docker containers. This document explains what changes and how to undo them.

## What changes on the machine

### Files created/modified inside the repository

Running the harness will create or overwrite artifacts under the repository root:

- **Rust build outputs**: `rust/target/**`
- **xHarbour build outputs**: `xharbour/bin/**`
- **Benchmark working files**: `bench/work/**`
  - `data.jsonl` (generated input)
  - `out.jsonl` (Rust output)
  - `out-xhb.jsonl` (xHarbour output)
  - `cache.bincode` (Rust cache produced by B4)
  - `xhb_cache.jsonl` (xHarbour cache)
  - `xhb_bench.dbf`, `xhb_bench.cdx` (xHarbour DBF+CDX)
- **Benchmark results**: `bench/results/<run_id>/**`
  - `manifest.json`, `summary.md`, `summary.csv`
  - per-phase `/usr/bin/time -v` output JSON
  - optional `hyperfine` JSON exports (if installed)

### Docker / PostgreSQL (optional)

If you run the harness with Postgres via Docker (e.g. `--with-postgres`), it will:

- start a Postgres container using `docker-compose.yml` (image `postgres:16.4-alpine`)
- bind **host port 5433** → container port 5432
- apply schema on first init via `db/postgres/schema.sql` (docker entrypoint init)

It does **not** modify your system Postgres installation (if you have one). It uses Docker only.

### Environment variables

The harness sets environment variables **only for the child processes it launches**. It does not write to shell profiles or persist them on disk.

Common variables used:

- `ROWS`
- `DATABASE_URL` (defaults to `postgresql://bench:benchpassword@127.0.0.1:5433/benchmark` if not provided)
- `BENCH_INPUT`, `BENCH_OUTPUT`, `BENCH_CACHE`, `BENCH_OUTPUT_FINAL` (paths under `bench/work/`)

### Downloads / caches (outside the repo)

These are normal tooling caches, not “system modifications”, but they persist:

- **Cargo crate downloads**: typically under `~/.cargo/registry` and `~/.cargo/git`
- **Docker image layers**: stored in Docker’s local image cache

## How to undo / clean up

### 1) Remove generated benchmark artifacts (recommended)

From repo root:

```bash
chmod +x xharbour/scripts/clean-workdir.sh
./xharbour/scripts/clean-workdir.sh
```

This removes common generated files under `bench/work/` (`*.dbf`, `*.cdx`, `*.jsonl`, `*.bincode`).

### 2) Remove stored results (optional)

```bash
rm -rf bench/results
```

### 3) Remove build outputs (optional)

Rust build outputs:

```bash
rm -rf rust/target
```

xHarbour build outputs:

```bash
rm -rf xharbour/bin
```

### 4) Stop and remove Docker Postgres (optional)

If you used `--with-postgres`:

```bash
docker compose down
```

If you also want to remove the Postgres image from your Docker cache:

```bash
docker image rm postgres:16.4-alpine
```

(This only affects Docker’s local cache; it does not touch your host OS packages.)

### 5) Remove Cargo downloads (optional, not usually recommended)

Cargo caches speed up builds; deleting them is rarely necessary:

```bash
rm -rf ~/.cargo/registry ~/.cargo/git
```

## “Can this corrupt my machine?”

The repo does not change OS settings. The biggest practical risks are:

- **disk usage** from 1M-row JSONL + outputs
- **RAM usage** when phases materialize large in-memory structures
- **port conflict** if something already uses `5433` (Docker Postgres won’t start)

