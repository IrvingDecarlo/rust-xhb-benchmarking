-- Benchmark table: logical model shared with xHarbour DBF (see xharbour/DBF-SCHEMA.md)
DROP TABLE IF EXISTS bench_rows;
CREATE TABLE bench_rows (
    id INTEGER NOT NULL PRIMARY KEY,
    code TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    flag BOOLEAN NOT NULL
);
CREATE INDEX bench_rows_code_idx ON bench_rows (code);
