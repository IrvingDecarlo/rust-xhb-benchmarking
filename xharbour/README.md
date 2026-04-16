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
| `b3.prg` | B3 — JSONL → DBF write (timed persistence; CDX built after timing) |
| `b4.prg` | B4 — DBF → in-memory hashes (timed), write cache |
| `b5.prg` | B5 — cache → in-memory hashes (untimed), timed canonical reserialize + hash |
| `b6.prg` | B6 — cache → in-memory hashes (untimed), timed canonical file write |
| `json_helpers.prg` | Shared — JSON parse/encode helpers |
| `line_reader.prg` | Shared — buffered JSONL line reader |
| `canon_helpers.prg` | Shared — canonical JSON formatting + rolling hash |

Build with [build.sh](build.sh) (`hbmk2` on `PATH`). The harness (`harness/run.py`) builds and runs xHarbour phases as part of `phases` and `measure` (see repo root [README.md](../README.md)).
