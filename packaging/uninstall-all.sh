#!/usr/bin/env bash
# Symmetric uninstaller for install-all.sh.
# Removes the three pi5-camera-ubuntu .debs in reverse install order.
# Does NOT touch ~/.bashrc — env-var lines are printed at the end so you can
# remove them yourself if you want a fully clean state.
set -euo pipefail

# Reverse install order: dependents first.
PKGS=(rpicam-apps-rpi-local libcamera-rpi-local libpisp-rpi-local)

installed=()
for pkg in "${PKGS[@]}"; do
  if dpkg -s "${pkg}" >/dev/null 2>&1; then
    installed+=("${pkg}")
  else
    echo "[uninstall-all] ${pkg} not installed (skipping)"
  fi
done

if [[ ${#installed[@]} -eq 0 ]]; then
  echo "[uninstall-all] nothing to remove."
  exit 0
fi

echo "[uninstall-all] removing: ${installed[*]}"
sudo dpkg -r "${installed[@]}"

# Optional: drop any deps that were pulled in only for these packages.
echo "[uninstall-all] apt-get autoremove (orphaned deps)"
sudo apt-get autoremove -y

cat <<'EOF'

[uninstall-all] done.

If you added the camera env vars to ~/.bashrc during install, you may want
to remove these lines (look just AFTER your `source /opt/ros/.../setup.bash`):

  export LD_LIBRARY_PATH=/usr/local/lib/aarch64-linux-gnu:/usr/local/lib:${LD_LIBRARY_PATH}
  export PKG_CONFIG_PATH=/usr/local/lib/aarch64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}
  export LIBCAMERA_IPA_MODULE_PATH=/usr/local/lib/aarch64-linux-gnu/libcamera/ipa
  export LIBCAMERA_IPA_PROXY_PATH=/usr/local/libexec/libcamera

Verify removal:
  dpkg -l | grep -E 'libpisp|libcamera|rpicam' && echo '(any rpi-local lines above are still installed)'
  cam -l   # should now be 'command not found' if /usr/local/bin/cam is gone
EOF
