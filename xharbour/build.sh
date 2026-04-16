#!/usr/bin/env bash
# Build xHarbour sources with hbmk2 when HB_ROOT / Harbour toolchain is available.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/xharbour/src"
OUT="${ROOT}/xharbour/bin"
mkdir -p "${OUT}"

if ! command -v hbmk2 >/dev/null 2>&1; then
  echo "hbmk2 not on PATH; set HB_ROOT and install xHarbour build tools, or compile PRGs from your IDE."
  exit 0
fi

shopt -s nullglob
for prg in "${SRC}"/*.prg; do
  base="$(basename "${prg}" .prg)"
  echo "hbmk2 ${prg} -> ${OUT}/${base}"
  # Link shared helpers into each binary.
  hbmk2 \
    "${prg}" \
    "${SRC}/json_helpers.prg" \
    "${SRC}/line_reader.prg" \
    "${SRC}/canon_helpers.prg" \
    -o"${OUT}/${base}" || exit 1
done
