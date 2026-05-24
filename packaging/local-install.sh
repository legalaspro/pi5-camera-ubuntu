#!/usr/bin/env bash
# Local install/uninstall test loop for the .debs produced by make-debs.sh.
# Skips the GitHub-release fetch in install-all.sh — useful during development.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${HERE}/dist"

PKGS=(libpisp-rpi libcamera-rpi rpicam-apps-rpi)

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
dpkg -l | grep -E '^ii  (libpisp-rpi|libcamera-rpi|rpicam-apps-rpi) ' || true

cat <<'EOF'

/usr/local/lib/aarch64-linux-gnu/ is NOT on Ubuntu's default ld.so search
path, so add this one line to ~/.bashrc — and if you use ROS, place it
AFTER `source /opt/ros/<distro>/setup.bash` so it beats ROS's vendored libs:

  export LD_LIBRARY_PATH=/usr/local/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH}

Open a new shell and test:
  cam -l   # expect both cameras listed via the PiSP pipeline handler
EOF

