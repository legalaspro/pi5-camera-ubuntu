#!/usr/bin/env bash
# Build Raspberry Pi's libcamera fork from a pinned upstream commit.
# Stops before `meson install`.
set -euo pipefail

REPO_URL="https://github.com/raspberrypi/libcamera.git"
PINNED_SHA="26bfadc66e8d7f727a993fe58174217b8a96f7f9"   # tag v0.7.1+rpt20260429
SRC_DIR="${HOME}/src"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--src-dir DIR]

Options:
  --src-dir DIR   Directory to clone the source tree into (default: \$HOME/src)
  -h, --help      Show this help

Clones raspberrypi/libcamera at ${PINNED_SHA}, runs meson setup + compile
with rpi/vc4 + rpi/pisp pipelines/IPAs enabled, and stops before
\`meson install\`.
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

REPO_DIR="${SRC_DIR}/libcamera"
BUILD_DIR="${REPO_DIR}/build"

echo "[libcamera] src dir : ${SRC_DIR}"
echo "[libcamera] repo dir: ${REPO_DIR}"
echo "[libcamera] pinned  : ${PINNED_SHA}"

mkdir -p "${SRC_DIR}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "[libcamera] cloning ${REPO_URL}"
  git clone "${REPO_URL}" "${REPO_DIR}"
else
  echo "[libcamera] repo already present, fetching"
  git -C "${REPO_DIR}" fetch --tags origin
fi

echo "[libcamera] checking out ${PINNED_SHA}"
git -C "${REPO_DIR}" checkout --detach "${PINNED_SHA}"

echo "[libcamera] meson setup"
meson setup "${BUILD_DIR}" "${REPO_DIR}" \
  --prefix=/usr/local \
  --buildtype=release \
  -Dpipelines=rpi/vc4,rpi/pisp \
  -Dipas=rpi/vc4,rpi/pisp \
  -Dv4l2=true \
  -Dgstreamer=enabled \
  -Dcam=enabled \
  -Dpycamera=enabled \
  -Dtest=false \
  -Dlc-compliance=disabled \
  -Dqcam=disabled \
  -Ddocumentation=disabled \
  --reconfigure

# Pick a safe parallelism for the compile.
# libcamera has heavy C++ TUs that peak around ~1.5 GB each, so on a 4 GB Pi
# the meson default of -j$(nproc) reliably OOMs and the build fails with
# mysterious "g++ killed" errors. Override with BUILD_JOBS=N ./build-libcamera.sh.
choose_jobs() {
  if [[ -n "${BUILD_JOBS:-}" ]]; then echo "${BUILD_JOBS}"; return; fi
  local mem_kb mem_gb cores j
  mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  mem_gb=$(( mem_kb / 1024 / 1024 ))
  cores=$(nproc)
  if   (( mem_gb < 3 ));  then j=1
  elif (( mem_gb < 6 ));  then j=2
  elif (( mem_gb < 12 )); then j=3
  else j=$(( cores > 1 ? cores - 1 : 1 ))
  fi
  (( j > cores )) && j=${cores}
  echo "${j}"
}
JOBS=$(choose_jobs)

echo "[libcamera] meson compile -j${JOBS}  (BUILD_JOBS=${BUILD_JOBS:-auto}, $(nproc) cores, $(awk '/MemTotal/{printf "%.1f", $2/1024/1024}' /proc/meminfo) GB RAM)"
meson compile -C "${BUILD_DIR}" -j"${JOBS}"

echo "[libcamera] verifying build artifacts"
shopt -s nullglob
core=( "${BUILD_DIR}/src/libcamera/"libcamera.so* )
pisp_ipa=( "${BUILD_DIR}/src/ipa/rpi/pisp/"ipa_rpi_pisp.so* )
cam_cli="${BUILD_DIR}/src/apps/cam/cam"
shopt -u nullglob

missing=0
if [[ ${#core[@]} -eq 0 ]]; then
  echo "[libcamera] ERROR: missing libcamera.so* under ${BUILD_DIR}/src/libcamera/" >&2
  missing=1
fi
if [[ ${#pisp_ipa[@]} -eq 0 ]]; then
  echo "[libcamera] ERROR: missing ipa_rpi_pisp.so under ${BUILD_DIR}/src/ipa/rpi/pisp/" >&2
  missing=1
fi
if [[ ! -x "${cam_cli}" ]]; then
  echo "[libcamera] ERROR: missing cam CLI at ${cam_cli}" >&2
  missing=1
fi
if [[ ${missing} -ne 0 ]]; then
  exit 1
fi

echo "[libcamera] built:"
printf '  %s\n' "${core[@]}" "${pisp_ipa[@]}" "${cam_cli}"

echo "[libcamera] OK — stopped before \`meson install\`"
