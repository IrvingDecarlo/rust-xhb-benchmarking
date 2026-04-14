# DBF logical schema (xHarbour)

Mirror of PostgreSQL `bench_rows` / [docs/workload-spec.md](../docs/workload-spec.md):


| Field    | DBF type  | Width / precision |
| -------- | --------- | ----------------- |
| `ID`     | Numeric   | 10,0              |
| `CODE`   | Character | 8                 |
| `AMOUNT` | Numeric   | 18,6              |
| `FLAG`   | Logical   | 1                 |


## Index (CDX)

- Optional secondary index on `CODE` for range scans; creation cost is part of **B3** if you build the index during load. Document in run notes whether the index exists before **B4**.

## Paths and cleanup

- Default DBF base name: `bench/work/xhb_bench` (`.dbf` / `.cdx` alongside JSONL).
- Remove artifacts between runs: [scripts/clean-workdir.sh](scripts/clean-workdir.sh) (also deletes JSONL/bincode in `bench/work/`).

## RDD

Use **DBFCDX** (`REQUEST HB_RDDCDX` / register `DBFCDX` per your toolchain) so behaviour matches Clipper-style indexed tables.