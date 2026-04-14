use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "BENCH_CACHE")]
    cache: Option<PathBuf>,
    #[arg(long, env = "BENCH_OUTPUT_FINAL")]
    output: Option<PathBuf>,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let cache = args
        .cache
        .unwrap_or_else(xhb_bench::default_cache_path);
    let out = args
        .output
        .unwrap_or_else(xhb_bench::default_output_path);
    let d = xhb_bench::run_b6(&cache, &out)?;
    println!(
        "{{\"phase\":\"B6\",\"nanos\":{},\"path\":\"{}\"}}",
        d.as_nanos(),
        out.display()
    );
    Ok(())
}
