#!/usr/bin/env bash
# Build libpisp, libcamera, and rpicam-apps in dependency order.
# Each sub-script stops before `meson install`; nothing is installed here.
set -euo pipefail

SRC_DIR="${HOME}/src"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--src-dir DIR]

Options:
  --src-dir DIR   Directory to clone the source trees into (default: \$HOME/src)
  -h, --help      Show this help

Runs build-libpisp.sh, build-libcamera.sh, build-rpicam-apps.sh in order.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-dir) SRC_DIR="$2"; shift 2 ;;
    --src-dir=*) SRC_DIR="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[build-all] src dir: ${SRC_DIR}"
echo "[build-all] scripts: ${SCRIPT_DIR}"

for step in build-libpisp.sh build-libcamera.sh build-rpicam-apps.sh; do
  echo
  echo "==================================================================="
  echo "[build-all] >>> ${step}"
  echo "==================================================================="
  bash "${SCRIPT_DIR}/${step}" --src-dir "${SRC_DIR}"
done

echo
echo "[build-all] all three components built — none installed"
