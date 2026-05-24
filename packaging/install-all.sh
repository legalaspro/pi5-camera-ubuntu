#!/usr/bin/env bash
# One-shot installer: pulls the latest .debs from the GitHub release and
# installs them into /usr/local via dpkg.
set -euo pipefail

REPO="legalaspro/pi5-camera-ubuntu"
PKGS=(libpisp-rpi libcamera-rpi rpicam-apps-rpi)

arch=$(dpkg --print-architecture)
if [[ "${arch}" != "arm64" ]]; then
  echo "ERROR: this installer only supports arm64 (got ${arch})" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    echo "WARNING: tested only on Ubuntu 24.04 Noble (detected ${ID:-?} ${VERSION_ID:-?})" >&2
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI 'gh' required (sudo apt install gh)" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

echo "[install-all] downloading latest .debs from ${REPO}"
gh release download --repo "${REPO}" --pattern '*.deb' --dir "${tmp}"

shopt -s nullglob
for pkg in "${PKGS[@]}"; do
  matches=( "${tmp}/${pkg}"_*.deb )
  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "ERROR: no .deb for ${pkg} found in latest release" >&2
    exit 1
  fi
  echo "[install-all] dpkg -i ${matches[0]}"
  sudo dpkg -i "${matches[0]}" || true
done
shopt -u nullglob

echo "[install-all] resolving dependencies with apt -f install"
sudo apt-get -f install -y

cat <<'EOF'

[install-all] done — .debs installed under /usr/local/.
(For the PPA-installed variant under /usr/, see the README PPA section.)

/usr/local/lib/aarch64-linux-gnu/ is NOT on Ubuntu's default ld.so search
path, so add this one line to ~/.bashrc — and if you use ROS, place it
AFTER `source /opt/ros/<distro>/setup.bash` so it beats ROS's vendored libs:

  export LD_LIBRARY_PATH=/usr/local/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH}

Open a new shell and test:
  cam -l   # expect both cameras listed via the PiSP pipeline handler
EOF
