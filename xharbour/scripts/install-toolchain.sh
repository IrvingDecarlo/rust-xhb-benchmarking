#!/usr/bin/env bash
# Best-effort local installer for an xHarbour toolchain (hbmk2).
#
# Notes:
# - We intentionally do NOT auto-install the open-source Harbour toolchain because this
#   repository’s stated comparison is xHarbour vs Rust, and “close enough” compilers can
#   change semantics and performance.
# - Fully autonomous “download xHarbour from the internet” is often blocked by licensing,
#   redistribution, logins, or URLs changing. Instead, this script supports a repeatable
#   local install from a user-provided archive.
set -euo pipefail

if command -v hbmk2 >/dev/null 2>&1; then
  echo "hbmk2 already present: $(command -v hbmk2)"
  exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFIX="${ROOT}/xharbour/toolchain"
BIN="${PREFIX}/bin"

XHB_ARCHIVE="${XHB_ARCHIVE:-}"
if [[ -n "${XHB_ARCHIVE}" ]]; then
  if [[ ! -f "${XHB_ARCHIVE}" ]]; then
    echo "XHB_ARCHIVE points to a missing file: ${XHB_ARCHIVE}" >&2
    exit 2
  fi
  mkdir -p "${PREFIX}"
  echo "Installing xHarbour toolchain into ${PREFIX}"
  # Support common tarball formats; avoid assuming a specific vendor layout.
  tar -xf "${XHB_ARCHIVE}" -C "${PREFIX}"
fi

if [[ -x "${BIN}/hbmk2" ]]; then
  cat <<EOF
xHarbour toolchain unpacked. For this shell session, run:

  export PATH="${BIN}:\$PATH"

Then compile benchmarks:

  ./xharbour/build.sh
EOF
  exit 0
fi

cat <<'EOF'
ERROR: `hbmk2` still not on PATH.

To run the full benchmark (including xHarbour phases), you must install a toolchain
that provides `hbmk2` and ensure it is on PATH.

Options:
  - Install xHarbour 1.2.3 via your normal method (system-wide), OR
  - Provide a local xHarbour archive and unpack it into the repo:

      XHB_ARCHIVE=/path/to/xharbour.tar.gz ./xharbour/scripts/install-toolchain.sh

    Then:
      export PATH="$PWD/xharbour/toolchain/bin:$PATH"

After installation:
  ./xharbour/build.sh
EOF
exit 1

