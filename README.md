# xHarbour vs Rust benchmarking

Reproducible **B0–B6** workloads: loop, JSONL I/O, deserialize to maps, PostgreSQL
(Rust + `tokio-postgres`), read/reserialize/write. xHarbour uses native **DBF+CDX**
(see `xharbour/`).

The harness (`harness/run.sh` → `harness/run.py`) runs **both** stacks by default for
`phases` and `measure`: it completes **all Rust** phase binaries for that invocation
first, then **all xHarbour** B3–B6 binaries (same JSONL input; Postgres only on the
Rust side). There is no “Rust-only” shortcut in the stock harness.

## Requirements

- **Rust**: stable (see `rust-toolchain.toml`)
- **Python**: 3.10+ (harness)
- **xHarbour**: toolchain with `**hbmk2` on `PATH`** so `xharbour/build.sh` can emit
`xharbour/bin/b3` … `b6` (required for `phases` / `measure`; see `xharbour/README.md`).
A best-effort helper script exists to unpack a *user-provided* xHarbour archive into
`xharbour/toolchain/` (it does **not** download or install Harbour).
- **Docker**: optional, for PostgreSQL (`docker compose`) when running Rust B3–B6 locally

## Quick start

From the repository root (install xHarbour / `hbmk2` first, or `phases` will exit with
a message pointing at missing `xharbour/bin/`*):

```bash
chmod +x harness/run.sh xharbour/scripts/clean-workdir.sh xharbour/build.sh xharbour/scripts/install-toolchain.sh
# Optional convenience: unpack a local xHarbour archive into `xharbour/toolchain/`.
# (No network download; avoids licensing/redistribution issues.)
# XHB_ARCHIVE=/path/to/xharbour.tar.gz ./xharbour/scripts/install-toolchain.sh
# export PATH="$PWD/xharbour/toolchain/bin:$PATH"
# Optional: compile Rust only (`phases` / `measure` also run `cargo` + `xharbour/build.sh`).
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


