use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "DATABASE_URL")]
    database_url: String,
    #[arg(long, env = "BENCH_CACHE")]
    cache: Option<PathBuf>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let cache = args
        .cache
        .unwrap_or_else(xhb_bench::default_cache_path);
    let (elapsed, n, h) = xhb_bench::run_b4(&args.database_url, &cache).await?;
    println!(
        "{{\"phase\":\"B4\",\"rows\":{n},\"nanos\":{},\"content_hash\":{h},\"cache\":\"{}\"}}",
        elapsed.as_nanos(),
        cache.display()
    );
    Ok(())
}
