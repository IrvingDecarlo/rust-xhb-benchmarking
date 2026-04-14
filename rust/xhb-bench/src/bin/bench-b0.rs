use std::time::Instant;

use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long, env = "ROWS", default_value_t = 1_000_000)]
    rows: u64,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let t0 = Instant::now();
    let checksum_u64 = xhb_bench::run_b0(args.rows);
    let nanos = t0.elapsed().as_nanos();
    let checksum_u32 = xhb_bench::b0_checksum_u32(args.rows);
    println!(
        "{{\"phase\":\"B0\",\"rows\":{},\"nanos\":{},\"checksum_u64\":\"{checksum_u64}\",\"checksum_u32\":{checksum_u32}}}",
        args.rows, nanos
    );
    Ok(())
}
