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

[install-all] done.

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
