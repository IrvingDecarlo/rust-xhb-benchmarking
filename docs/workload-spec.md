# Workload specification (B0–B6)

## Row model (logical)

All persisted rows share this shape:


| Field    | Type    | Notes                                                                      |
| -------- | ------- | -------------------------------------------------------------------------- |
| `id`     | integer | `0 .. N-1`, unique                                                         |
| `code`   | string  | exactly **8** ASCII chars: `C` + 7 decimal digits from `(id % 10_000_000)` |
| `amount` | float   | `(id as f64) * 0.01 + ((id % 100) as f64) * 0.001`                         |
| `flag`   | boolean | `(id % 2) == 0`                                                            |


### Canonical `code` format

Example: `id=0` → `C0000000`; `id=123` → `C0000123`.

## File formats

### JSONL (B1 output, B2 input)

- UTF-8, one JSON object per line, no array wrapper.
- Key order does not matter for parsing; canonical output for hashing uses sorted keys: `amount`, `code`, `flag`, `id`.
- Example: `{"amount":0.0,"code":"C0000000","flag":true,"id":0}`

### Canonical numeric formatting (for hashing/parity)

- `**id`**: integer, base-10, no leading spaces.
- `**amount`**: fixed **6** decimals (matches DBF `N(18,6)`), e.g. `1.230000`.

### CSV (optional B1/B2 variant)

- UTF-8, header: `id,code,amount,flag`
- `amount` as decimal; `flag` as `true`/`false` (lowercase).

## B0 checksums (Rust stdout)

- `**checksum_u64`**: full 64-bit mixing loop (Rust reference).
- `**checksum_u32`**: 32-bit wrapping recurrence (valid for `ROWS <= 4_294_967_295`); matches **xHarbour `b0.prg`** for cross-language checks.

## Phases


| ID  | Name        | Input                                                | Output                                                |
| --- | ----------- | ---------------------------------------------------- | ----------------------------------------------------- |
| B0  | loop        | `ROWS` env                                           | JSON: `nanos`, `checksum_u64`, `checksum_u32`         |
| B1  | generate    | —                                                    | JSONL path (`OUTPUT` or default)                      |
| B2  | deserialize | JSONL path                                           | in-memory maps only; prints line count + rolling hash |
| B3  | db_write    | in-memory from file read inside phase                | Postgres table `bench_rows` or DBF                    |
| B4  | db_read     | DB                                                   | maps in memory; prints count + hash                   |
| B5  | reserialize | maps from DB in phase                                | rolling hash of canonical lines                       |
| B6  | file_write  | re-read from DB or regenerate from DB in same binary | file on disk                                          |


**Note:** Rust splits B3–B6 so B2 can feed B3 from the same process after deserialize, or separate invocations with temp pickle—simplest is **one process per phase** passing file paths: B2 writes sidecar binary bincode optional, or **B3 reads JSONL again** and only times INSERT (plan: separate B2 vs B3). So:

- **B2**: read JSONL → maps; report time + hash of row data.
- **B3**: read JSONL again (I/O outside timed section optional) OR accept that B3 includes read—plan says "Time persistence only". So B3 should **load from prebuilt in-memory not possible cross-process** without IPC.

**Practical split (implemented):**

- **B2**: time to read JSONL + deserialize to `Vec<Map>`; print stats.
- **B3**: time **only** the database insert: data loaded **before** timer start from same file in a **warm cache** scenario, or we document "B3 includes re-read"—cleanest for subprocess RSS: **B3 binary reads file (untimed) then times only `client` bulk insert** by splitting with `--only-insert` and reading file before `Instant::now()`.

Implemented behavior:

- **B2**: entire read+deserialize timed.
- **B3**: read JSONL (untimed) + `Instant::now()` + COPY + commit timed.
- **B4**: `Instant::now()` + SELECT all + fetch to maps timed.
- **B5**: maps already in memory from B4 in combined `bench-pipeline`—for separate binaries, **B4** writes `bench/work/rows.bincode` or **B5 reads DB again** (double work). Simplest: provide `**bench-full`** that runs B2–B6 with internal phase timers JSON, plus **separate bins** for RSS where each loads minimal data.

For **separate bins per phase** (RSS):

- **b3**: load from JSONL before timer, then time COPY only.
- **b4**: time query+hydrate only.
- **b5**: must get maps without B4—**re-read DB** (timed as B4 already?) or load from bincode file written by b4.

I'll implement **b4** that writes `rows.msgpack` or **bincode** after fetch, **b5** reads bincode (deserialize maps) and times reserialize hash only, **b6** reads bincode and times file write. That adds B4→B5 dependency.

**Simpler approach matching plan:**

- Single `**xhb-bench`** binary: `run --phase b0|b1|...` with internal `Instant` per phase when `run --phase all` prints JSON timings.
- Separate `**bench-b0`…`bench-b6`** binaries for `/usr/bin/time -v`: each self-contained:
  - **b3**: read file (include in timing for fairness with "end user" story) OR exclude—**exclude** read from B3 timer: read all to RAM, then timer, then COPY.

I'll go with exclude read from B3 timer (document in methodology).

## Validation

- **B0**: checksum must match formula `mix(i)` for `i in 1..=N` (see Rust `bench_core::b0_checksum`).
- **B1**: `N` lines; optional `sha256sum` of file.
- **B3** / **xHarbour**: row count `N` after load.

PostgreSQL and DBF must store logically identical rows for the same input file.

## Default `N`

- Local: `1_000_000` (via env `ROWS`).
- CI: `10_000`–`100_000`.