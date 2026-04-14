#!/usr/bin/env bash
# Single entrypoint: run from repository root.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec python3 "$ROOT/harness/run.py" "$@"
