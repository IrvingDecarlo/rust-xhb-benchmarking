# xHarbour vs Rust benchmarking

Reproducible **B0–B6** workloads: loop, JSONL I/O, deserialize to maps, PostgreSQL
(Rust + `tokio-postgres`), read/reserialize/write. xHarbour uses native **DBF+CDX**
(see `xharbour/`).

## Requirements

- **Rust**: stable (see `rust-toolchain.toml`)
- **Python**: 3.10+ (harness)
- **Docker**: optional, for PostgreSQL (`docker compose`)

## Quick start

From the repository root:

```bash
chmod +x harness/run.sh xharbour/scripts/clean-workdir.sh xharbour/build.sh
./harness/run.sh build
./harness/run.sh phases --rows 10000
./harness/run.sh phases --rows 10000 --with-postgres --compose-down
# CI-style URL (no local docker compose):
./harness/run.sh phases --rows 10000 --postgres-url "postgresql://bench:benchpassword@127.0.0.1:5432/benchmark"
# hyperfine + /usr/bin/time -v → bench/results/<run_id>/
./harness/run.sh measure --rows 5000 --with-postgres --compose-down
```

Artifacts: `bench/work/` (created automatically); measurement output under `bench/results/`.

## Docs

- [docs/methodology.md](docs/methodology.md)
- [docs/workload-spec.md](docs/workload-spec.md)
- [docs/CLEANUP.md](docs/CLEANUP.md) (side effects + how to undo)

## Layout


| Path                 | Role                                  |
| -------------------- | ------------------------------------- |
| `rust/xhb-bench/`    | Rust binaries `bench-b0` … `bench-b6` |
| `harness/run.sh`     | Entrypoint → `harness/run.py`         |
| `db/postgres/`       | SQL schema for Docker init            |
| `docker-compose.yml` | Postgres 16 on port **5433**          |
| `bench/`             | Work + results dirs                   |
| `xharbour/`          | Harbour sources + DBF schema notes    |


