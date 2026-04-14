use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "ROWS", default_value_t = 1_000_000)]
    rows: u64,
    #[arg(long, env = "BENCH_OUTPUT")]
    output: Option<PathBuf>,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let out = args
        .output
        .unwrap_or_else(xhb_bench::default_input_path);
    let nanos = xhb_bench::run_b1_timed(args.rows, &out)?.as_nanos();
    println!(
        "{{\"phase\":\"B1\",\"rows\":{},\"nanos\":{},\"path\":\"{}\"}}",
        args.rows,
        nanos,
        out.display()
    );
    Ok(())
}
