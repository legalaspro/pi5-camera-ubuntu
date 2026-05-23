#!/usr/bin/env bash
# Build rpicam-apps from a pinned upstream commit. Stops before `meson install`.
set -euo pipefail

REPO_URL="https://github.com/raspberrypi/rpicam-apps.git"
PINNED_SHA="ea1bbcbea049d4e914c6dff5897c714cb791dc6f"
SRC_DIR="${HOME}/src"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--src-dir DIR]

Options:
  --src-dir DIR   Directory to clone the source tree into (default: \$HOME/src)
  -h, --help      Show this help

Clones raspberrypi/rpicam-apps at ${PINNED_SHA}, runs meson setup + compile
with libav/drm/egl enabled and qt/opencv/tflite/hailo disabled, and stops
before \`meson install\`.
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

REPO_DIR="${SRC_DIR}/rpicam-apps"
BUILD_DIR="${REPO_DIR}/build"

echo "[rpicam-apps] src dir : ${SRC_DIR}"
echo "[rpicam-apps] repo dir: ${REPO_DIR}"
echo "[rpicam-apps] pinned  : ${PINNED_SHA}"

mkdir -p "${SRC_DIR}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "[rpicam-apps] cloning ${REPO_URL}"
  git clone "${REPO_URL}" "${REPO_DIR}"
else
  echo "[rpicam-apps] repo already present, fetching"
  git -C "${REPO_DIR}" fetch --tags origin
fi

echo "[rpicam-apps] checking out ${PINNED_SHA}"
git -C "${REPO_DIR}" checkout --detach "${PINNED_SHA}"

echo "[rpicam-apps] meson setup"
# enable_libav requires libavdevice-dev (which Ubuntu's libavcodec-dev does not
# pull in); leave it disabled — rpicam-vid still records raw H.264 / MJPEG /
# YUV, and the user can remux with ffmpeg if MP4 containers are needed.
# enable_egl needs a GL desktop; headless robotics use doesn't benefit.
meson setup "${BUILD_DIR}" "${REPO_DIR}" \
  --prefix=/usr/local \
  --buildtype=release \
  -Denable_libav=disabled \
  -Denable_drm=enabled \
  -Denable_egl=disabled \
  -Denable_qt=disabled \
  -Denable_opencv=disabled \
  -Denable_tflite=disabled \
  -Denable_hailo=disabled \
  --reconfigure

# Same memory-aware parallelism trick as build-libcamera.sh: avoid OOM on 4 GB Pi.
# Override with BUILD_JOBS=N ./build-rpicam-apps.sh.
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

echo "[rpicam-apps] meson compile -j${JOBS}  (BUILD_JOBS=${BUILD_JOBS:-auto})"
meson compile -C "${BUILD_DIR}" -j"${JOBS}"

echo "[rpicam-apps] verifying build artifacts"
expected=(
  "${BUILD_DIR}/apps/rpicam-hello"
  "${BUILD_DIR}/apps/rpicam-still"
  "${BUILD_DIR}/apps/rpicam-vid"
)
missing=0
for bin in "${expected[@]}"; do
  if [[ ! -x "${bin}" ]]; then
    echo "[rpicam-apps] ERROR: missing executable ${bin}" >&2
    missing=1
  fi
done
if [[ ${missing} -ne 0 ]]; then
  exit 1
fi

echo "[rpicam-apps] built:"
printf '  %s\n' "${expected[@]}"

echo "[rpicam-apps] OK — stopped before \`meson install\`"
