use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "BENCH_CACHE")]
    cache: Option<PathBuf>,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let cache = args
        .cache
        .unwrap_or_else(xhb_bench::default_cache_path);
    let (elapsed, h) = xhb_bench::run_b5(&cache)?;
    println!(
        "{{\"phase\":\"B5\",\"nanos\":{},\"serialize_hash\":{h}}}",
        elapsed.as_nanos()
    );
    Ok(())
}
