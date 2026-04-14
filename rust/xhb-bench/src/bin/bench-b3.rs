use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "DATABASE_URL")]
    database_url: String,
    #[arg(long, env = "BENCH_INPUT")]
    input: Option<PathBuf>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let path = args
        .input
        .unwrap_or_else(xhb_bench::default_input_path);
    let nanos = xhb_bench::run_b3(&args.database_url, &path)
        .await?
        .as_nanos();
    println!(
        "{{\"phase\":\"B3\",\"nanos\":{},\"input\":\"{}\"}}",
        nanos,
        path.display()
    );
    Ok(())
}
