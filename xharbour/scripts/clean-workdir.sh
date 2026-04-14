#!/usr/bin/env bash
# Remove generated DBF/CDX/JSONL/cache under bench/work (repo root).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
rm -f "${ROOT}/bench/work/"*.dbf "${ROOT}/bench/work/"*.cdx \
  "${ROOT}/bench/work/"*.jsonl "${ROOT}/bench/work/"*.bincode 2>/dev/null || true
echo "Cleaned ${ROOT}/bench/work (dbf/cdx/jsonl/bincode)"
