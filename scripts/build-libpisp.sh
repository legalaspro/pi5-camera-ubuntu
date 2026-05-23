#!/usr/bin/env bash
# Build libpisp from a pinned upstream commit. Stops before `meson install`.
set -euo pipefail

REPO_URL="https://github.com/raspberrypi/libpisp.git"
PINNED_SHA="07e61ad07596b4c5729289e9016ec19fea7f0d19"
SRC_DIR="${HOME}/src"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--src-dir DIR]

Options:
  --src-dir DIR   Directory to clone the source tree into (default: \$HOME/src)
  -h, --help      Show this help

Clones raspberrypi/libpisp at ${PINNED_SHA}, runs meson setup + compile,
and stops before \`meson install\`.
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

REPO_DIR="${SRC_DIR}/libpisp"
BUILD_DIR="${REPO_DIR}/build"

echo "[libpisp] src dir : ${SRC_DIR}"
echo "[libpisp] repo dir: ${REPO_DIR}"
echo "[libpisp] pinned  : ${PINNED_SHA}"

mkdir -p "${SRC_DIR}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "[libpisp] cloning ${REPO_URL}"
  git clone "${REPO_URL}" "${REPO_DIR}"
else
  echo "[libpisp] repo already present, fetching"
  git -C "${REPO_DIR}" fetch --tags origin
fi

echo "[libpisp] checking out ${PINNED_SHA}"
git -C "${REPO_DIR}" checkout --detach "${PINNED_SHA}"

echo "[libpisp] meson setup"
meson setup "${BUILD_DIR}" "${REPO_DIR}" \
  --prefix=/usr/local \
  -Dgstreamer=disabled \
  --reconfigure

echo "[libpisp] meson compile"
meson compile -C "${BUILD_DIR}"

echo "[libpisp] verifying build artifact"
shopt -s nullglob
artifacts=( "${BUILD_DIR}/src/"libpisp.so* )
shopt -u nullglob
if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "[libpisp] ERROR: no libpisp.so* found under ${BUILD_DIR}/src/" >&2
  exit 1
fi
echo "[libpisp] built:"
printf '  %s\n' "${artifacts[@]}"

echo "[libpisp] OK — stopped before \`meson install\`"
