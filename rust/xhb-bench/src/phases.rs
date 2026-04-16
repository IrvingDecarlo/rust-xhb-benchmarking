use std::path::{Path, PathBuf};
use std::time::Instant;

use anyhow::Context;
use bytes::Bytes;
use futures_util::SinkExt;
use serde_json::{Map, Value};
use tokio_postgres::NoTls;

use crate::model::{
    b0_checksum, canonical_json_line, make_row, rolling_hash_bytes, rows_from_json_maps, BenchRow,
};

pub fn default_input_path() -> PathBuf {
    PathBuf::from("bench/work/data.jsonl")
}

pub fn default_cache_path() -> PathBuf {
    PathBuf::from("bench/work/cache.bincode")
}

pub fn default_output_path() -> PathBuf {
    PathBuf::from("bench/work/out.jsonl")
}

pub fn run_b0(n: u64) -> u64 {
    let v = b0_checksum(n);
    std::hint::black_box(v)
}

pub fn run_b1(n: u64, out: &Path) -> anyhow::Result<()> {
    std::fs::create_dir_all(
        out.parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new(".")),
    )?;
    let mut f = std::fs::File::create(out)?;
    use std::io::Write;
    for i in 0..n {
        let row = make_row(i);
        let line = canonical_json_line(&row);
        writeln!(f, "{line}")?;
    }
    Ok(())
}

pub fn run_b1_timed(n: u64, out: &Path) -> anyhow::Result<std::time::Duration> {
    let t0 = Instant::now();
    run_b1(n, out)?;
    Ok(t0.elapsed())
}

/// B2: deserialize every line into a JSON object map; returns wall time for that work only.
pub fn run_b2_timed(path: &Path) -> anyhow::Result<(std::time::Duration, usize, u64)> {
    let t0 = Instant::now();
    let (n, h) = run_b2_maps_only(path)?;
    Ok((t0.elapsed(), n, h))
}

/// Load rows from JSONL (not timed here — caller decides).
pub fn load_rows_jsonl(path: &Path) -> anyhow::Result<Vec<BenchRow>> {
    let data = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let mut maps = Vec::new();
    for line in data.lines() {
        if line.is_empty() {
            continue;
        }
        let v: serde_json::Value = serde_json::from_str(line)?;
        let obj = v
            .as_object()
            .ok_or_else(|| anyhow::anyhow!("line is not a JSON object"))?
            .clone();
        maps.push(obj);
    }
    rows_from_json_maps(&maps)
}

pub async fn pg_connect(database_url: &str) -> anyhow::Result<tokio_postgres::Client> {
    let (client, connection) = tokio_postgres::connect(database_url, NoTls)
        .await
        .with_context(|| "connect postgres")?;
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("postgres connection error: {e}");
        }
    });
    Ok(client)
}

pub async fn run_b3(database_url: &str, path: &Path) -> anyhow::Result<std::time::Duration> {
    let rows = load_rows_jsonl(path)?;
    let client = pg_connect(database_url).await?;
    client
        .execute("TRUNCATE bench_rows", &[])
        .await
        .context("truncate")?;

    let t0 = Instant::now();
    let sink = client
        .copy_in(
            "COPY bench_rows (id, code, amount, flag) FROM STDIN WITH (FORMAT text, DELIMITER E'\\t', NULL '\\N')",
        )
        .await
        .context("copy_in")?;

    tokio::pin!(sink);
    for row in &rows {
        let flag = if row.flag { "t" } else { "f" };
        let line = format!(
            "{}\t{}\t{:.6}\t{}\n",
            row.id, row.code, row.amount, flag
        );
        sink.as_mut()
            .send(Bytes::from(line))
            .await
            .context("copy send")?;
    }
    sink.as_mut()
        .finish()
        .await
        .context("copy finish")?;
    let elapsed = t0.elapsed();
    Ok(elapsed)
}

pub async fn run_b4(
    database_url: &str,
    cache_path: &Path,
) -> anyhow::Result<(std::time::Duration, usize, u64)> {
    let client = pg_connect(database_url).await?;
    let t0 = Instant::now();
    let rows = client
        .query(
            "SELECT id, code, amount, flag FROM bench_rows ORDER BY id",
            &[],
        )
        .await
        .context("select")?;

    let mut out: Vec<BenchRow> = Vec::with_capacity(rows.len());
    for r in rows {
        out.push(BenchRow {
            id: r.get::<_, i32>(0),
            code: r.get::<_, String>(1),
            amount: r.get::<_, f64>(2),
            flag: r.get::<_, bool>(3),
        });
    }
    let elapsed = t0.elapsed();

    std::fs::create_dir_all(
        cache_path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new(".")),
    )?;
    let encoded = bincode::serialize(&out)?;
    std::fs::write(cache_path, &encoded)?;

    let mut h: u64 = 0;
    for row in &out {
        h = h.wrapping_add(rolling_hash_bytes(canonical_json_line(row).as_bytes()));
    }
    Ok((elapsed, out.len(), h))
}

pub fn run_b5(cache_path: &Path) -> anyhow::Result<(std::time::Duration, u64)> {
    let bytes = std::fs::read(cache_path)?;
    let rows: Vec<BenchRow> = bincode::deserialize(&bytes)?;
    let t0 = Instant::now();
    let mut h: u64 = 0;
    for row in &rows {
        let line = canonical_json_line(row);
        h = h.wrapping_add(rolling_hash_bytes(line.as_bytes()));
    }
    let elapsed = t0.elapsed();
    std::hint::black_box(h);
    Ok((elapsed, h))
}

pub fn run_b6(cache_path: &Path, out_path: &Path) -> anyhow::Result<std::time::Duration> {
    let bytes = std::fs::read(cache_path)?;
    let rows: Vec<BenchRow> = bincode::deserialize(&bytes)?;
    std::fs::create_dir_all(
        out_path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new(".")),
    )?;
    let t0 = Instant::now();
    let mut f = std::fs::File::create(out_path)?;
    use std::io::Write;
    for row in &rows {
        writeln!(f, "{}", canonical_json_line(row))?;
    }
    let elapsed = t0.elapsed();
    Ok(elapsed)
}

/// Deserialize JSONL into Vec<Map> only (B2 “maps” shape).
pub fn run_b2_maps_only(path: &Path) -> anyhow::Result<(usize, u64)> {
    let data = std::fs::read_to_string(path)?;
    let mut maps: Vec<Map<String, Value>> = Vec::new();
    let mut h: u64 = 0;
    for line in data.lines() {
        if line.is_empty() {
            continue;
        }
        let v: serde_json::Value = serde_json::from_str(line)?;
        let obj = v
            .as_object()
            .ok_or_else(|| anyhow::anyhow!("not object"))?
            .clone();
        h = h.wrapping_add(rolling_hash_bytes(line.as_bytes()));
        maps.push(obj);
    }
    Ok((maps.len(), h))
}
