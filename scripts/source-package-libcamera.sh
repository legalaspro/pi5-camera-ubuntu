#!/usr/bin/env bash
# Build a Debian source package for libcamera (Raspberry Pi fork) suitable for
# `dput`-uploading to the Launchpad PPA. Pinned to the same upstream commit
# used by scripts/build-libcamera.sh.
#
# Outputs (in $WORK_PARENT, default /tmp/pi5-camera-src):
#   libcamera-rpi_0.7.1-1~noble1.dsc
#   libcamera-rpi_0.7.1.orig.tar.xz
#   libcamera-rpi_0.7.1-1~noble1.debian.tar.xz
#   libcamera-rpi_0.7.1-1~noble1_source.changes
#   libcamera-rpi_0.7.1-1~noble1_source.buildinfo
#
# After this script:
#   cd $WORK_PARENT
#   debsign libcamera-rpi_*_source.changes
#   dput ppa:manajev/pi5-camera libcamera-rpi_*_source.changes
#
# Optional smoke test:
#   SMOKE_TEST=1 bash scripts/source-package-libcamera.sh
set -euo pipefail

REPO_URL="https://github.com/raspberrypi/libcamera.git"
PINNED_SHA="26bfadc66e8d7f727a993fe58174217b8a96f7f9"
UPSTREAM_VERSION="0.7.1"
PKG_NAME="libcamera-rpi"
WORK_PARENT="${WORK_PARENT:-/tmp/pi5-camera-src}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEBIAN_SRC="${REPO_ROOT}/debian/libcamera"
WORK_DIR="${WORK_PARENT}/${PKG_NAME}-${UPSTREAM_VERSION}"
ORIG_TARBALL="${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}.orig.tar.xz"

echo "[source-package-libcamera] repo root      : ${REPO_ROOT}"
echo "[source-package-libcamera] debian/ source : ${DEBIAN_SRC}"
echo "[source-package-libcamera] work dir       : ${WORK_DIR}"

if [[ ! -d "${DEBIAN_SRC}" ]]; then
  echo "ERROR: ${DEBIAN_SRC} not found." >&2
  exit 1
fi

for tool in git debuild xz; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERROR: required tool '${tool}' not found." >&2
    exit 1
  fi
done

# 1. Clean + recreate
rm -rf "${WORK_DIR}" "${ORIG_TARBALL}"
mkdir -p "${WORK_PARENT}"

# 2. Clone upstream at the pinned commit
echo "[source-package-libcamera] cloning upstream ${PINNED_SHA:0:12}"
git clone --quiet "${REPO_URL}" "${WORK_DIR}"
git -C "${WORK_DIR}" checkout --quiet --detach "${PINNED_SHA}"

# 3. Build the orig tarball
echo "[source-package-libcamera] creating ${ORIG_TARBALL}"
git -C "${WORK_DIR}" archive \
  --format=tar \
  --prefix="${PKG_NAME}-${UPSTREAM_VERSION}/" \
  HEAD \
  | xz -T0 -c > "${ORIG_TARBALL}"

# 4. Drop our debian/ packaging into the work dir
echo "[source-package-libcamera] copying debian/ packaging"
rm -rf "${WORK_DIR}/debian"
cp -a "${DEBIAN_SRC}" "${WORK_DIR}/debian"
chmod +x "${WORK_DIR}/debian/rules"

# 5. Build the source package (see source-package-libpisp.sh for -d rationale)
echo "[source-package-libcamera] debuild -S -d -uc -us"
(
  cd "${WORK_DIR}"
  debuild -S -d -uc -us
)

echo
echo "[source-package-libcamera] source artifacts:"
ls -1 "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}"-*.dsc \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}".orig.tar.xz \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*.debian.tar.xz \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*_source.changes \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*_source.buildinfo 2>/dev/null

# 6. Optional smoke test
if [[ "${SMOKE_TEST:-0}" == "1" ]]; then
  echo
  echo "==================================================================="
  echo "[smoke-test] installing Build-Depends with mk-build-deps"
  echo "==================================================================="
  (
    cd "${WORK_PARENT}"
    sudo mk-build-deps --install --remove --root-cmd sudo --tool 'apt-get -y --no-install-recommends' \
      "${PKG_NAME}_${UPSTREAM_VERSION}"-*.dsc
  )

  echo
  echo "==================================================================="
  echo "[smoke-test] debuild -b -uc -us  (local binary build, ~15 min on Pi 5)"
  echo "==================================================================="
  (
    cd "${WORK_DIR}"
    debuild -b -uc -us
  )

  echo
  echo "[smoke-test] binary artifacts:"
  ls -1 "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*_arm64.deb \
        "${WORK_PARENT}/${PKG_NAME}-dbgsym_${UPSTREAM_VERSION}-"*_arm64.ddeb 2>/dev/null
fi

echo
echo "[source-package-libcamera] next — sign + upload to Launchpad:"
echo "  cd ${WORK_PARENT}"
echo "  debsign ${PKG_NAME}_*_source.changes"
echo "  dput ppa:manajev/pi5-camera ${PKG_NAME}_*_source.changes"
