#!/usr/bin/env bash
# Build .deb packages for libpisp / libcamera / rpicam-apps using
# `meson install --destdir=...` + `dpkg-deb -b`.
#
# Why not checkinstall? Its installwatch LD_PRELOAD library breaks on modern
# glibc (Ubuntu 24.04). The meson-destdir + dpkg-deb path is the standard
# modern way to package meson projects: no sudo, no LD_PRELOAD tricks, no
# system-wide install side effects.
#
# Each upstream source tree must already be built (see ../scripts/build-*.sh).
set -euo pipefail

SRC_DIR="${HOME}/src"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${HERE}/dist"
STAGING_ROOT="${HERE}/staging"
DESC_FILES=(
  "${HERE}/libpisp.desc"
  "${HERE}/libcamera-rpi.desc"
  "${HERE}/rpicam-apps.desc"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [--src-dir DIR]

Options:
  --src-dir DIR   Directory containing libpisp/, libcamera/, rpicam-apps/
                  source trees (default: \$HOME/src)
  -h, --help      Show this help

Builds .debs into ${DIST_DIR}/. No sudo required.
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

for tool in meson dpkg-deb; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERROR: required tool '${tool}' not found in PATH." >&2
    exit 1
  fi
done

mkdir -p "${DIST_DIR}" "${STAGING_ROOT}"
echo "[make-debs] src dir    : ${SRC_DIR}"
echo "[make-debs] dist dir   : ${DIST_DIR}"
echo "[make-debs] staging dir: ${STAGING_ROOT}"

# Translate a multi-line description into the Debian "long description" format:
# every line indented by one space; blank lines replaced with " .".
format_long_desc() {
  local desc="$1"
  while IFS= read -r line; do
    if [[ -z "${line}" ]]; then
      printf ' .\n'
    else
      printf ' %s\n' "${line}"
    fi
  done <<< "${desc}"
}

package_one() {
  local desc_file="$1"

  # Reset variables so a previous package's values cannot leak in.
  local PKGNAME="" PKGVERSION="" PKGRELEASE="" PKGARCH="" PKGLICENSE=""
  local PKGGROUP="" PKGSOURCE="" MAINTAINER="" REQUIRES=""
  local SRC_SUBDIR="" SUMMARY="" DESCRIPTION=""

  # shellcheck disable=SC1090
  source "${desc_file}"

  local repo_dir="${SRC_DIR}/${SRC_SUBDIR}"
  local build_dir="${repo_dir}/build"
  local staging="${STAGING_ROOT}/${PKGNAME}"
  local deb_version="${PKGVERSION}-${PKGRELEASE}"
  local deb_file="${DIST_DIR}/${PKGNAME}_${deb_version}_${PKGARCH}.deb"

  # checkinstall's MAINTAINER had escaped angle brackets to dodge its eval bug.
  # We don't have that problem here, but strip any leftover backslashes so the
  # control file is clean Debian-format.
  local clean_maintainer="${MAINTAINER//\\</<}"
  clean_maintainer="${clean_maintainer//\\>/>}"

  echo
  echo "==================================================================="
  echo "[make-debs] ${PKGNAME} ${deb_version} (${PKGARCH})"
  echo "[make-debs] source : ${repo_dir}"
  echo "==================================================================="

  if [[ ! -d "${build_dir}" ]]; then
    echo "[make-debs] ERROR: build dir ${build_dir} not found." >&2
    echo "[make-debs]        Run ../scripts/build-${SRC_SUBDIR}.sh first." >&2
    return 1
  fi

  # 1. Make sure the build is current. This is a no-op if nothing changed.
  echo "[make-debs] meson compile"
  meson compile -C "${build_dir}" >/dev/null

  # 2. Install into a per-package staging dir. Crucially: --destdir means the
  #    files land in ${staging}/usr/local/... instead of /usr/local/... so no
  #    root privileges are needed.
  echo "[make-debs] meson install --destdir=${staging}"
  rm -rf "${staging}"
  mkdir -p "${staging}"
  meson install -C "${build_dir}" --destdir "${staging}" --quiet

  # 3. Write DEBIAN/control so dpkg-deb can package the staging tree.
  mkdir -p "${staging}/DEBIAN"
  local installed_size_kb
  installed_size_kb=$(du -sk --exclude=DEBIAN "${staging}" | awk '{print $1}')

  {
    printf 'Package: %s\n' "${PKGNAME}"
    printf 'Version: %s\n' "${deb_version}"
    printf 'Architecture: %s\n' "${PKGARCH}"
    printf 'Maintainer: %s\n' "${clean_maintainer}"
    printf 'Section: %s\n' "${PKGGROUP}"
    printf 'Priority: optional\n'
    if [[ -n "${REQUIRES}" ]]; then
      printf 'Depends: %s\n' "${REQUIRES}"
    fi
    printf 'Installed-Size: %s\n' "${installed_size_kb}"
    printf 'Homepage: %s\n' "${PKGSOURCE}"
    printf 'Description: %s\n' "${SUMMARY}"
    format_long_desc "${DESCRIPTION}"
  } > "${staging}/DEBIAN/control"

  # 4. Build the .deb. xz compression matches what Ubuntu ships with.
  echo "[make-debs] dpkg-deb -b -> ${deb_file}"
  dpkg-deb --build --root-owner-group -Zxz "${staging}" "${deb_file}" >/dev/null

  # 5. Quick sanity-check: package info should round-trip.
  echo "[make-debs] dpkg-deb -I summary:"
  dpkg-deb -I "${deb_file}" | sed 's/^/  /'

  # Keep the staging tree around for inspection; nuke before next package only.
}

for desc in "${DESC_FILES[@]}"; do
  package_one "${desc}"
done

echo
echo "[make-debs] done — .debs in ${DIST_DIR}:"
ls -1 "${DIST_DIR}"/*.deb
