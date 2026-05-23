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

# Chain steps via meson's uninstalled pkg-config files so each component can
# find its dependencies in the previous build dir without `meson install`.
prepend_uninstalled() {
  local d="${SRC_DIR}/$1/build/meson-uninstalled"
  if [[ -d "${d}" ]]; then
    export PKG_CONFIG_PATH="${d}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    echo "[build-all] PKG_CONFIG_PATH += ${d}"
  fi
}

declare -A NEXT_DEPS=(
  [build-libpisp.sh]=libpisp
  [build-libcamera.sh]=libcamera
)

for step in build-libpisp.sh build-libcamera.sh build-rpicam-apps.sh; do
  echo
  echo "==================================================================="
  echo "[build-all] >>> ${step}"
  echo "==================================================================="
  bash "${SCRIPT_DIR}/${step}" --src-dir "${SRC_DIR}"
  if [[ -n "${NEXT_DEPS[${step}]:-}" ]]; then
    prepend_uninstalled "${NEXT_DEPS[${step}]}"
  fi
done

echo
echo "[build-all] all three components built — none installed"
