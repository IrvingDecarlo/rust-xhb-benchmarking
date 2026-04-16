# Methodology: xHarbour vs Rust benchmarks

## Purpose

Compare **xHarbour 1.2.3 (SimpLex)** with **Rust** on CPU time and memory (RSS) for:

- A tight integer loop (**B0**)
- Text generation and parsing (**B1**, **B2**)
- Database load and read (**B3**, **B4**) with **different engines by design**:
  - **Rust → PostgreSQL**
  - **xHarbour → DBF + CDX** (Clipper-style)

End-to-end comparisons across stacks are **logical workload parity**, not “same database.” DB timings answer: **PostgreSQL vs DBF/CDX** for this schema and access pattern, implemented in each language’s typical/native way.

## Environments

- **Authoritative numbers**: your **local Linux** machine, pinned toolchain and Postgres image, documented CPU governor and background load.
- **CI**: smaller `ROWS` (e.g. 10k–100k); correctness first; optional regression budgets against stored baselines.

### CI runner requirement (xHarbour)

CI is expected to run on a **self-hosted GitHub Actions runner** with the **xHarbour 1.2.3 (Build 20230605)** toolchain installed and `hbmk2` available on `PATH`, so CI can compile and benchmark **both** stacks.

### CI regression budgets (optional)

The default pipeline checks **correctness** (phases complete, schema applied). To gate on performance, keep a checked-in or artifact-stored **baseline** `manifest.json` from `harness/run.py measure` and add a small comparator step (e.g. fail if any phase mean time exceeds baseline × `BENCH_REGRESSION_FACTOR`). This is intentionally not enforced in the stock workflow so runners stay stable across GitHub’s fleet.

## Measurement

- **Wall time**: `[hyperfine](https://github.com/sharkdp/hyperfine)` for whole-process runs; export JSON.
- **CPU / RSS**: `/usr/bin/time -v` (Max resident set size) per **phase binary** where possible.
- Optional: `perf stat` for cycles/instructions.

## Phase binaries (RSS isolation)

Rust provides one binary per phase (`bench-b0` … `bench-b6`) so `/usr/bin/time -v` attributes memory to that phase. Where a phase needs prior artifacts (e.g. **B5** after **B4**), **B4** writes a cache file (`BENCH_CACHE` path) of typed rows; **B5** and **B6** read it—documented in [workload-spec.md](workload-spec.md).

## B0: anti-dead-code elimination

Both implementations must end with an **observable** result (printed checksum) derived from every iteration so optimizers cannot delete the loop. The mixing function is specified in Rust (`xhb_bench::b0_checksum` for 64-bit, `b0_checksum_u32` for the 32-bit variant used by `xharbour/src/b0.prg`); xHarbour **B0** matches the **32-bit** recurrence for portability.

## B3 timing boundary (Rust / Postgres)

**B3** measures **database write only**: the process reads the JSONL file into memory **before** starting the timer, then starts the timer for `COPY ... FROM STDIN` (or equivalent) through `COMMIT`. This matches “deserialize benchmarked separately in B2.”

## JSONL and CSV

Exact formats are in [workload-spec.md](workload-spec.md). Changing quoting or key order in canonical output changes parse/reserialize timings—keep formats stable across versions.

## xHarbour build

The repository includes `.prg` sources and [xharbour/README.md](../xharbour/README.md). CI **does** require the xHarbour compiler toolchain (self-hosted runner), and local runs compile with your xHarbour 1.2.3 toolchain.