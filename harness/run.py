#!/usr/bin/env python3
"""
Benchmark harness: phases (Rust B0–B6), optional Postgres (docker or URL),
measurement (hyperfine + /usr/bin/time -v), manifest + markdown summary.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
RUST = ROOT / "rust"
BENCH_WORK = ROOT / "bench" / "work"
RESULTS = ROOT / "bench" / "results"
DEFAULT_DATABASE_URL = "postgresql://bench:benchpassword@127.0.0.1:5433/benchmark"


def redact_database_url(url: str) -> str:
    if not url:
        return ""
    return re.sub(r"(//[^:/]+:)[^@]+@", r"\1***@", url, count=1)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, **kwargs)


def run_check(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True, **kwargs)


def ensure_workdir() -> None:
    BENCH_WORK.mkdir(parents=True, exist_ok=True)


def cargo_build_release() -> Path:
    run_check(["cargo", "build", "--release"], cwd=RUST)
    return RUST / "target" / "release"


def docker_up() -> None:
    try:
        run_check(["docker", "compose", "up", "-d", "--wait"], cwd=ROOT)
    except subprocess.CalledProcessError:
        run_check(["docker", "compose", "up", "-d"], cwd=ROOT)
        wait_pg()


def docker_down() -> None:
    run_check(["docker", "compose", "down"], cwd=ROOT)


def wait_pg(timeout_s: float = 45.0) -> None:
    import socket

    deadline = time.monotonic() + timeout_s
    host, port = "127.0.0.1", 5433
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((host, port), timeout=2.0):
                return
        except OSError:
            time.sleep(0.3)
    raise SystemExit("Postgres not reachable on 127.0.0.1:5433")


def parse_stdout_json_line(stdout: str) -> dict[str, Any] | None:
    for line in reversed(stdout.strip().splitlines()):
        s = line.strip()
        if s.startswith("{"):
            try:
                return json.loads(s)
            except json.JSONDecodeError:
                continue
    return None


def parse_time_v(stderr: str) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for line in stderr.splitlines():
        line = line.strip()
        if line.startswith("Command being timed:"):
            out["command"] = line[len("Command being timed:") :].strip()
        elif line.startswith("Maximum resident set size (kbytes):"):
            out["max_rss_kb"] = int(line.split(":", 1)[1].strip())
        elif line.startswith("User time (seconds):"):
            out["user_seconds"] = float(line.split(":", 1)[1].strip())
        elif line.startswith("System time (seconds):"):
            out["system_seconds"] = float(line.split(":", 1)[1].strip())
        elif line.startswith("Elapsed (wall clock)"):
            idx = line.rfind("):")
            if idx != -1:
                out["elapsed_wall"] = line[idx + 2 :].strip()
        elif line.startswith("Exit status:"):
            out["exit_status"] = int(line.split(":", 1)[1].strip())
    return out


def which_hyperfine() -> str | None:
    return shutil.which("hyperfine")


def run_hyperfine_json(
    name: str,
    cmd: list[str],
    env: dict[str, str],
    cwd: Path,
    warmup: int,
    runs: int,
    export_path: Path,
) -> dict[str, Any] | None:
    hf = which_hyperfine()
    if not hf:
        return None
    export_path.parent.mkdir(parents=True, exist_ok=True)
    run_check(
        [
            hf,
            "--warmup",
            str(warmup),
            "-r",
            str(runs),
            "--export-json",
            str(export_path),
            "--show-output",
            "--command",
            subprocess.list2cmdline(cmd),
        ],
        cwd=cwd,
        env=env,
    )
    data = json.loads(export_path.read_text())
    return {"name": name, "hyperfine": data}


def run_time_v(
    name: str, cmd: list[str], env: dict[str, str], cwd: Path
) -> dict[str, Any]:
    tv = "/usr/bin/time"
    if not Path(tv).is_file():
        tv = shutil.which("time") or "time"
    p = run(
        [tv, "-v", *cmd],
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
    )
    info = parse_time_v(p.stderr)
    info["name"] = name
    info["stdout_json"] = parse_stdout_json_line(p.stdout)
    if p.returncode != 0:
        info["error"] = f"exit {p.returncode}"
        info["stderr_tail"] = p.stderr[-4000:]
    return info


def run_phases(args: argparse.Namespace) -> list[dict[str, Any]]:
    ensure_workdir()
    rows = str(args.rows)
    env = os.environ.copy()
    env["ROWS"] = rows
    if getattr(args, "postgres_url", None):
        env["DATABASE_URL"] = args.postgres_url
    else:
        env.setdefault("DATABASE_URL", DEFAULT_DATABASE_URL)
    env["BENCH_INPUT"] = str(BENCH_WORK / "data.jsonl")
    env["BENCH_CACHE"] = str(BENCH_WORK / "cache.bincode")
    env["BENCH_OUTPUT"] = str(BENCH_WORK / "data.jsonl")
    env["BENCH_OUTPUT_FINAL"] = str(BENCH_WORK / "out.jsonl")

    bins = cargo_build_release()

    if args.with_postgres and not getattr(args, "postgres_url", None):
        docker_up()

    phases_out: list[dict[str, Any]] = []

    def b(bin_name: str) -> None:
        cmd = [str(bins / bin_name)]
        p = run(cmd, env=env, cwd=ROOT, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stderr, file=sys.stderr)
            p.check_returncode()
        j = parse_stdout_json_line(p.stdout)
        if j:
            phases_out.append({"binary": bin_name, **j})
        else:
            phases_out.append({"binary": bin_name, "raw_stdout": p.stdout.strip()[:500]})

    try:
        b("bench-b0")
        b("bench-b1")
        b("bench-b2")
        if args.with_postgres or getattr(args, "postgres_url", None):
            b("bench-b3")
            b("bench-b4")
            b("bench-b5")
            b("bench-b6")
    finally:
        if (
            args.with_postgres
            and args.compose_down
            and not getattr(args, "postgres_url", None)
        ):
            docker_down()

    return phases_out


def cmd_measure(args: argparse.Namespace) -> None:
    ensure_workdir()
    RESULTS.mkdir(parents=True, exist_ok=True)
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = RESULTS / run_id
    out_dir.mkdir(parents=True)

    rows = str(args.rows)
    env = os.environ.copy()
    env["ROWS"] = rows
    if getattr(args, "postgres_url", None):
        env["DATABASE_URL"] = args.postgres_url
    else:
        env.setdefault("DATABASE_URL", DEFAULT_DATABASE_URL)
    env["BENCH_INPUT"] = str(BENCH_WORK / "data.jsonl")
    env["BENCH_CACHE"] = str(BENCH_WORK / "cache.bincode")
    env["BENCH_OUTPUT"] = str(BENCH_WORK / "data.jsonl")
    env["BENCH_OUTPUT_FINAL"] = str(BENCH_WORK / "out.jsonl")

    bins = cargo_build_release()

    if args.with_postgres and not getattr(args, "postgres_url", None):
        docker_up()
        wait_pg()

    # Seed JSONL before B3+ and before timing each binary in isolation.
    for seed in ("bench-b0", "bench-b1", "bench-b2"):
        run_check(
            [str(bins / seed)],
            env=env,
            cwd=ROOT,
            capture_output=True,
            text=True,
        )

    binaries = ["bench-b0", "bench-b1", "bench-b2"]
    if args.with_postgres or getattr(args, "postgres_url", None):
        binaries += ["bench-b3", "bench-b4", "bench-b5", "bench-b6"]

    manifest: dict[str, Any] = {
        "run_id": run_id,
        "rows": int(rows),
        "stack": "rust",
        "database_url_redacted": redact_database_url(env.get("DATABASE_URL", "")),
        "phases": [],
    }

    try:
        for name in binaries:
            cmd = [str(bins / name)]
            entry: dict[str, Any] = {"binary": name}
            hf_path = out_dir / f"{name}.hyperfine.json"
            hf = run_hyperfine_json(
                name, cmd, env, ROOT, warmup=args.warmup, runs=args.runs, export_path=hf_path
            )
            if hf:
                entry.update(hf)
            tv = run_time_v(name, cmd, env, ROOT)
            entry["time_v"] = tv
            if tv.get("stdout_json"):
                entry["stdout_json"] = tv["stdout_json"]
            manifest["phases"].append(entry)
            (out_dir / f"{name}.time-v.txt").write_text(
                json.dumps(tv, indent=2), encoding="utf-8"
            )
    finally:
        if (
            args.with_postgres
            and args.compose_down
            and not getattr(args, "postgres_url", None)
        ):
            docker_down()

    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_summary_md(manifest), encoding="utf-8")
    print("Wrote", out_dir / "manifest.json", flush=True)


def render_summary_md(manifest: dict[str, Any]) -> str:
    lines = [
        f"# Benchmark run `{manifest.get('run_id')}`",
        "",
        f"- Rows: **{manifest.get('rows')}**",
        f"- Stack: **{manifest.get('stack')}**",
        "",
        "| Phase | Mean ms (hyperfine) | Max RSS KB |",
        "|-------|---------------------|------------|",
    ]
    for p in manifest.get("phases", []):
        name = p.get("name") or p.get("binary", "")
        mean_ms = ""
        hf = p.get("hyperfine")
        if hf and hf.get("results"):
            r0 = hf["results"][0]
            t = r0.get("mean")
            if t is not None:
                mean_ms = f"{t * 1000:.3f}"
        rss = ""
        tv = p.get("time_v") or {}
        if "max_rss_kb" in tv:
            rss = str(tv["max_rss_kb"])
        lines.append(f"| {name} | {mean_ms} | {rss} |")
    lines.append("")
    lines.append("_Hyperfine omitted if not installed; then only `/usr/bin/time -v` fields apply._")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    p = argparse.ArgumentParser(description="xHarbour vs Rust benchmark harness")
    sub = p.add_subparsers(dest="cmd", required=True)

    def add_pg_flags(sp: argparse.ArgumentParser) -> None:
        sp.add_argument(
            "--with-postgres",
            action="store_true",
            help="Run B3–B6; start local docker compose Postgres unless --postgres-url is set",
        )
        sp.add_argument(
            "--postgres-url",
            default=None,
            help="If set, use this DATABASE_URL for B3–B6 (no docker compose)",
        )
        sp.add_argument(
            "--compose-down",
            action="store_true",
            help="With --with-postgres only: docker compose down after run",
        )

    sp = sub.add_parser("phases", help="Run B0–B6 (Rust); Postgres optional")
    sp.add_argument("--rows", type=int, default=10_000)
    add_pg_flags(sp)

    sm = sub.add_parser("measure", help="Hyperfine + /usr/bin/time -v per binary; write manifest")
    sm.add_argument("--rows", type=int, default=10_000)
    sm.add_argument("--warmup", type=int, default=1)
    sm.add_argument("--runs", type=int, default=3)
    add_pg_flags(sm)

    sb = sub.add_parser("build", help="Only cargo build --release")
    sb.add_argument("--rows", type=int, default=0)

    args = p.parse_args()

    if args.cmd == "build":
        cargo_build_release()
        print("Built:", RUST / "target" / "release", flush=True)
        return

    if args.cmd == "phases":
        phases = run_phases(args)
        print(json.dumps({"phases": phases}, indent=2))
        return

    if args.cmd == "measure":
        cmd_measure(args)
        return


if __name__ == "__main__":
    main()
