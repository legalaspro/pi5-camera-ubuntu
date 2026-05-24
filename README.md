# pi5-camera-ubuntu

Unofficial builds of the Raspberry Pi camera stack — `libpisp`, `libcamera`
(Raspberry Pi fork), and `rpicam-apps` — for **Ubuntu 24.04 (arm64) on
Raspberry Pi 5**, where the `libcamera` shipped by Ubuntu (0.2.0) is too old
for the Pi 5's PiSP hardware ISP needed by IMX219, IMX708, and friends.

> **Disclaimer:** unofficial builds. Not provided, endorsed, or supported by
> Raspberry Pi Ltd., Canonical, or the libcamera project.

## Tested on

- Ubuntu 24.04 LTS (Noble), arm64
- Raspberry Pi 5
- Kernel 6.8 (stock Ubuntu kernel)

## Install

### Recommended — Launchpad PPA

```bash
sudo add-apt-repository -y ppa:manajev/pi5-camera
sudo apt update
sudo apt install -y rpicam-apps-rpi    # pulls libcamera-rpi + libpisp-rpi too
```

Installs under `/usr/`. `apt upgrade` keeps you on the latest.

### Alternative — GitHub Release one-liner

```bash
curl -fsSL https://github.com/legalaspro/pi5-camera-ubuntu/releases/latest/download/install-all.sh | bash
```

Installs under `/usr/local/`. Useful when `add-apt-repository` is inconvenient
(off-grid, locked-down networks, etc.).

### If you also have ROS 2 (Jazzy / Humble / …)

ROS prepends its own lib dir to `LD_LIBRARY_PATH` on `source setup.bash`,
which would shadow our `libpisp.so.1`. Add ONE line to `~/.bashrc` **after**
the `source /opt/ros/<distro>/setup.bash` line — pick the path matching how
you installed:

```bash
# PPA install (under /usr/):
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH}

# GitHub-Release install (under /usr/local/):
export LD_LIBRARY_PATH=/usr/local/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH}
```

If you don't use ROS and installed from the PPA, no env-var setup is needed.

After installing, run `cam -l` to confirm libcamera is functional. Capture
and pipeline tests depend on which sensor(s) you have attached — see the
[Raspberry Pi camera docs](https://www.raspberrypi.com/documentation/computers/camera_software.html)
for `rpicam-*` usage.

## Packages

| Package | What it is |
|---|---|
| `libpisp-rpi` | Pi 5 PiSP ISP userspace driver (BSD-2-Clause) |
| `libcamera-rpi` | Raspberry Pi `libcamera` fork with `rpi/pisp` pipeline + IPAs + IMX219/IMX708 tuning + Python bindings + GStreamer plugin (LGPL-2.1+) |
| `rpicam-apps-rpi` | `rpicam-hello / still / vid / raw / jpeg` CLI tools (BSD-2-Clause) |

All install to standard system paths (`/usr/...` from PPA, `/usr/local/...`
from GitHub Release). Removable cleanly with `sudo apt remove`.

## Build from source

See [`scripts/`](scripts/):

- `build-libpisp.sh` / `build-libcamera.sh` / `build-rpicam-apps.sh` — clone
  upstream at a pinned SHA and run `meson setup + compile`. Memory-aware `-j`
  picker so libcamera doesn't OOM on a 4 GB Pi.
- `build-all.sh` — all three in dependency order.

Then package into `.deb`s:

- `packaging/make-debs.sh` — `meson install --destdir=staging/<pkg>` +
  `dpkg-deb -b` → `packaging/dist/*.deb`. Output of the GitHub Release path.
- `scripts/source-package-<pkg>.sh` — build a Debian *source* package for
  uploading to Launchpad (PPA path). Optional `SMOKE_TEST=1` runs a full
  local binary build through `debuild -b` first.

## Credits

This repository only packages upstream work. All credit goes to:

- [raspberrypi/libpisp](https://github.com/raspberrypi/libpisp)
- [raspberrypi/libcamera](https://github.com/raspberrypi/libcamera)
- [raspberrypi/rpicam-apps](https://github.com/raspberrypi/rpicam-apps)
