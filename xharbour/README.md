# xHarbour benchmarks (B0–B6)

Sources and build scripts for **xHarbour 1.2.3 Intl. (SimpLex)** live here. The
Rust side lives in `rust/xhb-bench/`; this directory holds the Clipper/xHarbour
implementation and DBF/CDX notes.

See [DBF-SCHEMA.md](DBF-SCHEMA.md) for field layout matching `docs/workload-spec.md`.

## Sources (`src/`)

| File | Phase |
|------|--------|
| `b0.prg` | B0 — 32-bit checksum (matches Rust `checksum_u32`) |
| `b1.prg` | B1 — JSONL generator |
| `b2.prg` | B2 — JSONL read + diagnostic hash |

Build with [build.sh](build.sh) (`hbmk2` on `PATH`). **B3–B6** (DBF/CDX bulk load, read, reserialize, file write) are not yet checked in as `.prg`; extend here using [DBF-SCHEMA.md](DBF-SCHEMA.md), then add a `phases-xharbour` hook in `harness/run.py` if you want the same manifest format as Rust.
