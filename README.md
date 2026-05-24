# pi5-camera-ubuntu

Unofficial builds of the Raspberry Pi camera stack (`libpisp`, `libcamera`,
`rpicam-apps`) for **Ubuntu 24.04 (arm64) on Raspberry Pi 5**.

## What this is

A small collection of build scripts and `.deb` packages that bring the
Raspberry Pi userspace camera stack to Ubuntu 24.04 on the Pi 5, where the
upstream `libcamera` shipped by Ubuntu does not yet include the Pi-specific
ISP (PiSP) support required by sensors such as the IMX219 and IMX708.

Two phases are planned:

1. **Phase 1** — locally-built `.deb`s via `meson install --destdir` +
   `dpkg-deb`, distributed as GitHub Release artifacts.
2. **Phase 2** — a proper Launchpad PPA (`debian/` packaging).

## Disclaimer

These are **unofficial** builds. They are not provided, endorsed, or
supported by Raspberry Pi Ltd., Canonical, or the libcamera project.
Use at your own risk. All upstream source code retains its original
license; only the build scripts and packaging in this repository are
covered by the LICENSE file here.

## Tested on

- Ubuntu 24.04 LTS (arm64)
- Raspberry Pi 5
- Kernel 6.8 (stock Ubuntu kernel)

## Install

### Option A — Launchpad PPA (recommended)

```bash
sudo add-apt-repository -y ppa:manajev/pi5-camera
sudo apt update
sudo apt install -y rpicam-apps-rpi    # pulls libcamera-rpi + libpisp-rpi too
```

Installs to `/usr/...` (system standard). `apt upgrade` brings in new versions
automatically.

### Option B — GitHub Release one-liner

```bash
curl -fsSL https://github.com/legalaspro/pi5-camera-ubuntu/releases/latest/download/install-all.sh | bash
```

Installs to `/usr/local/...` (the Phase 1 from-source convention). No PPA
needed. Useful for off-grid setups or anywhere `add-apt-repository` is
inconvenient.

### If you also have ROS 2 (Jazzy/Humble/…)

ROS prepends its own lib dir to `LD_LIBRARY_PATH` on `source setup.bash`,
which would shadow our `libpisp.so.1`. Add ONE line to `~/.bashrc` **after**
the `source /opt/ros/<distro>/setup.bash` line:

```bash
# Option A (PPA install at /usr/...):
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH}

# Option B (GitHub-Release install at /usr/local/...):
export LD_LIBRARY_PATH=/usr/local/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH}
```

Pick the line matching how you installed. Then open a new shell and run
`cam -l` — both cameras should list via the PiSP pipeline handler.

If you don't use ROS, you don't need this line at all (for the PPA install).

## Build from source

See the [`scripts/`](scripts/) directory:

- `build-libpisp.sh`     — builds and packages `libpisp`
- `build-libcamera.sh`   — builds and packages Raspberry Pi's `libcamera` fork
- `build-rpicam-apps.sh` — builds and packages `rpicam-apps`
- `build-all.sh`         — runs all three in order

Artifacts are produced under [`packaging/dist/`](packaging/) as `.deb` files
by [`packaging/make-debs.sh`](packaging/make-debs.sh).

## Credits

This repository only packages upstream work. All credit for the camera
stack itself goes to:

- [raspberrypi/libpisp](https://github.com/raspberrypi/libpisp)
- [raspberrypi/libcamera](https://github.com/raspberrypi/libcamera)
- [raspberrypi/rpicam-apps](https://github.com/raspberrypi/rpicam-apps)
