//! Logical row model (matches docs/workload-spec.md and xharbour/DBF-SCHEMA.md).

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BenchRow {
    pub id: i32,
    pub code: String,
    pub amount: f64,
    pub flag: bool,
}

/// Observable mixing checksum for B0 (full 64-bit; Rust reference).
pub fn b0_checksum(n: u64) -> u64 {
    let mut acc: u64 = 0;
    for i in 1..=n {
        acc = acc.wrapping_mul(1315423911).wrapping_add(i);
    }
    acc
}

/// 32-bit wrapping variant for cross-checking with xHarbour (valid for `n <= u32::MAX`).
pub fn b0_checksum_u32(n: u64) -> u32 {
    let n32 = n.min(u32::MAX as u64) as u32;
    let mut acc: u32 = 0;
    for i in 1u32..=n32 {
        acc = acc.wrapping_mul(1315423911).wrapping_add(i);
    }
    acc
}

pub fn make_row(id: u64) -> BenchRow {
    let amount = id as f64 * 0.01 + (id % 100) as f64 * 0.001;
    BenchRow {
        id: id as i32,
        code: format!("C{:07}", id % 10_000_000),
        amount,
        flag: id % 2 == 0,
    }
}

/// Canonical JSON object with keys sorted: amount, code, flag, id
pub fn canonical_json_line(row: &BenchRow) -> String {
    let mut map = Map::new();
    map.insert(
        "amount".into(),
        serde_json::Number::from_f64(row.amount)
            .map(Value::Number)
            .unwrap_or(Value::Null),
    );
    map.insert("code".into(), Value::String(row.code.clone()));
    map.insert("flag".into(), Value::Bool(row.flag));
    map.insert("id".into(), Value::Number(row.id.into()));
    let v = Value::Object(map);
    v.to_string()
}

pub fn row_from_map(map: &Map<String, Value>) -> anyhow::Result<BenchRow> {
    let id = map
        .get("id")
        .and_then(|v| v.as_i64())
        .ok_or_else(|| anyhow::anyhow!("missing id"))? as i32;
    let code = map
        .get("code")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("missing code"))?
        .to_string();
    let amount = map
        .get("amount")
        .and_then(|v| v.as_f64())
        .ok_or_else(|| anyhow::anyhow!("missing amount"))?;
    let flag = map
        .get("flag")
        .and_then(|v| v.as_bool())
        .ok_or_else(|| anyhow::anyhow!("missing flag"))?;
    Ok(BenchRow {
        id,
        code,
        amount,
        flag,
    })
}

pub fn rolling_hash_bytes(data: &[u8]) -> u64 {
    let mut h: u64 = 0;
    for &b in data {
        h = h.wrapping_mul(1315423911).wrapping_add(b as u64);
    }
    h
}

pub fn rows_from_json_maps(maps: &[Map<String, Value>]) -> anyhow::Result<Vec<BenchRow>> {
    maps.iter().map(row_from_map).collect()
}
