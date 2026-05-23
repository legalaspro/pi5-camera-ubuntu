#!/usr/bin/env bash
# Local install/uninstall test loop for the .debs produced by make-debs.sh.
# Skips the GitHub-release fetch in install-all.sh — useful during development.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${HERE}/dist"

PKGS=(libpisp-rpi-local libcamera-rpi-local rpicam-apps-rpi-local)

shopt -s nullglob
files=()
for pkg in "${PKGS[@]}"; do
  matches=( "${DIST_DIR}/${pkg}"_*.deb )
  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "ERROR: no ${pkg}_*.deb under ${DIST_DIR}" >&2
    echo "       Run packaging/make-debs.sh first." >&2
    exit 1
  fi
  files+=( "${matches[0]}" )
done
shopt -u nullglob

echo "[local-install] installing:"
printf '  %s\n' "${files[@]}"

# Stage in a world-readable /tmp dir so apt's '_apt' sandbox user can read the
# files. Without this, apt falls back to root with a noisy 'unsandboxed'
# notice because $HOME is mode 750 and unreadable to '_apt'.
stage=$(mktemp -d -t pi5cam-install.XXXXXX)
trap 'rm -rf "${stage}"' EXIT
cp "${files[@]}" "${stage}/"
chmod a+rx "${stage}"
mapfile -t staged < <(printf '%s\n' "${stage}"/*.deb)

# apt resolves Ubuntu deps automatically; dpkg -i would need `apt -f install` after.
sudo apt install -y "${staged[@]}"

echo
echo "[local-install] done. Quick check:"
dpkg -l | grep rpi-local || true

cat <<'EOF'

Add the following to ~/.bashrc AFTER any `source /opt/ros/.../setup.bash`
line, so /usr/local wins over ROS's vendored libcamera/libpisp:

  # Pi 5 IMX219 / libcamera built from source — must beat ROS Jazzy's vendored libs.
  export LD_LIBRARY_PATH=/usr/local/lib/aarch64-linux-gnu:/usr/local/lib:${LD_LIBRARY_PATH}
  export PKG_CONFIG_PATH=/usr/local/lib/aarch64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}

  # Optional explicit libcamera paths; useful for debugging/mixed environments.
  export LIBCAMERA_IPA_MODULE_PATH=/usr/local/lib/aarch64-linux-gnu/libcamera/ipa
  export LIBCAMERA_IPA_PROXY_PATH=/usr/local/libexec/libcamera

Then open a new shell and test:

  cam -l   # expect both cameras listed via the PiSP pipeline handler
EOF

