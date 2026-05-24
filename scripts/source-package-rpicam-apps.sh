#!/usr/bin/env bash
# Build a Debian source package for rpicam-apps suitable for `dput`-uploading
# to the Launchpad PPA. Pinned to the same upstream commit used by
# scripts/build-rpicam-apps.sh.
#
# Outputs (in $WORK_PARENT, default /tmp/pi5-camera-src):
#   rpicam-apps-rpi_1.12.0-1~noble1.dsc
#   rpicam-apps-rpi_1.12.0.orig.tar.xz
#   rpicam-apps-rpi_1.12.0-1~noble1.debian.tar.xz
#   rpicam-apps-rpi_1.12.0-1~noble1_source.changes
#   rpicam-apps-rpi_1.12.0-1~noble1_source.buildinfo
#
# After this script:
#   cd $WORK_PARENT
#   debsign rpicam-apps-rpi_*_source.changes
#   dput ppa:manajev/pi5-camera rpicam-apps-rpi_*_source.changes
#
# Optional smoke test:
#   SMOKE_TEST=1 bash scripts/source-package-rpicam-apps.sh
set -euo pipefail

REPO_URL="https://github.com/raspberrypi/rpicam-apps.git"
PINNED_SHA="ea1bbcbea049d4e914c6dff5897c714cb791dc6f"
UPSTREAM_VERSION="1.12.0"
PKG_NAME="rpicam-apps-rpi"
WORK_PARENT="${WORK_PARENT:-/tmp/pi5-camera-src}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEBIAN_SRC="${REPO_ROOT}/debian/rpicam-apps"
WORK_DIR="${WORK_PARENT}/${PKG_NAME}-${UPSTREAM_VERSION}"
ORIG_TARBALL="${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}.orig.tar.xz"

echo "[source-package-rpicam-apps] repo root      : ${REPO_ROOT}"
echo "[source-package-rpicam-apps] debian/ source : ${DEBIAN_SRC}"
echo "[source-package-rpicam-apps] work dir       : ${WORK_DIR}"

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
echo "[source-package-rpicam-apps] cloning upstream ${PINNED_SHA:0:12}"
git clone --quiet "${REPO_URL}" "${WORK_DIR}"
git -C "${WORK_DIR}" checkout --quiet --detach "${PINNED_SHA}"

# 3. Build the orig tarball
echo "[source-package-rpicam-apps] creating ${ORIG_TARBALL}"
git -C "${WORK_DIR}" archive \
  --format=tar \
  --prefix="${PKG_NAME}-${UPSTREAM_VERSION}/" \
  HEAD \
  | xz -T0 -c > "${ORIG_TARBALL}"

# 4. Drop our debian/ packaging into the work dir
echo "[source-package-rpicam-apps] copying debian/ packaging"
rm -rf "${WORK_DIR}/debian"
cp -a "${DEBIAN_SRC}" "${WORK_DIR}/debian"
chmod +x "${WORK_DIR}/debian/rules"

# 5. Build the source package (see source-package-libpisp.sh for -d rationale)
echo "[source-package-rpicam-apps] debuild -S -d -uc -us"
(
  cd "${WORK_DIR}"
  debuild -S -d -uc -us
)

echo
echo "[source-package-rpicam-apps] source artifacts:"
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
  echo "[smoke-test] debuild -b -uc -us  (local binary build, ~5 min on Pi 5)"
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
echo "[source-package-rpicam-apps] next — sign + upload to Launchpad:"
echo "  cd ${WORK_PARENT}"
echo "  debsign ${PKG_NAME}_*_source.changes"
echo "  dput ppa:manajev/pi5-camera ${PKG_NAME}_*_source.changes"
