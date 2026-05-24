#!/usr/bin/env bash
# Build a Debian source package for libpisp suitable for `dput`-uploading to
# the Launchpad PPA. Pinned to the same upstream commit as build-libpisp.sh.
#
# Outputs (in $WORK_PARENT, default /tmp/pi5-camera-src):
#   libpisp-rpi_1.5.0-1~noble1.dsc
#   libpisp-rpi_1.5.0.orig.tar.xz
#   libpisp-rpi_1.5.0-1~noble1.debian.tar.xz
#   libpisp-rpi_1.5.0-1~noble1_source.changes
#   libpisp-rpi_1.5.0-1~noble1_source.buildinfo
#
# After this script:
#   cd $WORK_PARENT
#   debsign libpisp-rpi_*_source.changes
#   dput ppa:manajev/pi5-camera libpisp-rpi_*_source.changes
set -euo pipefail

REPO_URL="https://github.com/raspberrypi/libpisp.git"
PINNED_SHA="07e61ad07596b4c5729289e9016ec19fea7f0d19"
UPSTREAM_VERSION="1.5.0"
PKG_NAME="libpisp-rpi"
WORK_PARENT="${WORK_PARENT:-/tmp/pi5-camera-src}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEBIAN_SRC="${REPO_ROOT}/debian/libpisp"
WORK_DIR="${WORK_PARENT}/${PKG_NAME}-${UPSTREAM_VERSION}"
ORIG_TARBALL="${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}.orig.tar.xz"

echo "[source-package-libpisp] repo root      : ${REPO_ROOT}"
echo "[source-package-libpisp] debian/ source : ${DEBIAN_SRC}"
echo "[source-package-libpisp] work dir       : ${WORK_DIR}"

if [[ ! -d "${DEBIAN_SRC}" ]]; then
  echo "ERROR: ${DEBIAN_SRC} not found. Did you check out the right branch?" >&2
  exit 1
fi

for tool in git debuild xz; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERROR: required tool '${tool}' not found. Install devscripts + xz-utils." >&2
    exit 1
  fi
done

# 1. Clean + recreate the work parent
rm -rf "${WORK_DIR}" "${ORIG_TARBALL}"
mkdir -p "${WORK_PARENT}"

# 2. Clone upstream at the pinned commit (shallow is fine, then unshallow for git archive)
echo "[source-package-libpisp] cloning upstream ${PINNED_SHA:0:12}"
git clone --quiet "${REPO_URL}" "${WORK_DIR}"
git -C "${WORK_DIR}" checkout --quiet --detach "${PINNED_SHA}"

# 3. Build the orig tarball from the clean upstream tree.
#    --prefix sets the top-level directory inside the tarball; debian's source
#    format 3.0 (quilt) expects <pkgname>-<version>/.
echo "[source-package-libpisp] creating ${ORIG_TARBALL}"
git -C "${WORK_DIR}" archive \
  --format=tar \
  --prefix="${PKG_NAME}-${UPSTREAM_VERSION}/" \
  HEAD \
  | xz -T0 -c > "${ORIG_TARBALL}"

# 4. Drop our debian/ packaging into the work dir.
#    debuild reads ./debian/* relative to the cwd.
echo "[source-package-libpisp] copying debian/ packaging"
rm -rf "${WORK_DIR}/debian"
cp -a "${DEBIAN_SRC}" "${WORK_DIR}/debian"
chmod +x "${WORK_DIR}/debian/rules"

# 5. Build the source package.
#    -S  = source only (no .deb here; Launchpad's builders make the .deb)
#    -d  = skip the local build-dep check. We are NOT compiling here — we are
#          just bundling source + debian/ into a tarball + manifest. Launchpad
#          installs Build-Depends inside its own chroot before compiling.
#          Without -d, debuild refuses to run unless every Build-Dep is also
#          installed on your local Pi, which defeats the point of letting
#          Launchpad build for you.
#    -uc -us = don't sign here (we sign with debsign in the next step)
echo "[source-package-libpisp] debuild -S -d -uc -us"
(
  cd "${WORK_DIR}"
  debuild -S -d -uc -us
)

echo
echo "[source-package-libpisp] source artifacts:"
ls -1 "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}"-*.dsc \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}".orig.tar.xz \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*.debian.tar.xz \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*_source.changes \
      "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*_source.buildinfo 2>/dev/null

# 6. OPTIONAL local smoke test: install Build-Depends, run a binary build,
#    and produce a .deb you can dpkg -i to verify the recipe actually works
#    before burning a Launchpad round-trip. Enable with SMOKE_TEST=1.
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
  echo "[smoke-test] debuild -b -uc -us  (local binary build)"
  echo "==================================================================="
  (
    cd "${WORK_DIR}"
    debuild -b -uc -us
  )

  echo
  echo "[smoke-test] binary artifacts:"
  ls -1 "${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-"*_arm64.deb \
        "${WORK_PARENT}/${PKG_NAME}-dbgsym_${UPSTREAM_VERSION}-"*_arm64.ddeb 2>/dev/null
  echo
  echo "[smoke-test] try it:"
  echo "  sudo dpkg -i ${WORK_PARENT}/${PKG_NAME}_${UPSTREAM_VERSION}-*_arm64.deb"
  echo "  ls /usr/lib/aarch64-linux-gnu/ | grep pisp"
  echo "  sudo dpkg -r ${PKG_NAME}"
fi

echo
echo "[source-package-libpisp] next — sign + upload to Launchpad:"
echo "  cd ${WORK_PARENT}"
echo "  debsign ${PKG_NAME}_*_source.changes"
echo "  dput ppa:manajev/pi5-camera ${PKG_NAME}_*_source.changes"
