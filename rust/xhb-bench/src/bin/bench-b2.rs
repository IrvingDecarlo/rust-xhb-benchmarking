use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "BENCH_INPUT")]
    input: Option<PathBuf>,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let path = args
        .input
        .unwrap_or_else(xhb_bench::default_input_path);
    let (elapsed, n, h) = xhb_bench::run_b2_timed(&path)?;
    println!(
        "{{\"phase\":\"B2\",\"rows\":{n},\"nanos\":{},\"map_hash\":{h}}}",
        elapsed.as_nanos()
    );
    Ok(())
}
