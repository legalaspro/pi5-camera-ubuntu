# pi5-camera-ubuntu

Unofficial builds of the Raspberry Pi camera stack (`libpisp`, `libcamera`,
`rpicam-apps`) for **Ubuntu 24.04 (arm64) on Raspberry Pi 5**.

## What this is

A small collection of build scripts and `.deb` packages that bring the
Raspberry Pi userspace camera stack to Ubuntu 24.04 on the Pi 5, where the
upstream `libcamera` shipped by Ubuntu does not yet include the Pi-specific
ISP (PiSP) support required by sensors such as the IMX219 and IMX708.

Two phases are planned:

1. **Phase 1** — locally-built `.deb`s via `checkinstall`, distributed as
   GitHub Release artifacts.
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

## Install (one-liner)

Download the latest release tarball and run the bundled installer:

```bash
curl -fsSL https://github.com/<user>/pi5-camera-ubuntu/releases/latest/download/install-all.sh | bash
```

(Replace `<user>` with the actual GitHub user/org once published.)

## Build from source

See the [`scripts/`](scripts/) directory:

- `build-libpisp.sh`     — builds and packages `libpisp`
- `build-libcamera.sh`   — builds and packages Raspberry Pi's `libcamera` fork
- `build-rpicam-apps.sh` — builds and packages `rpicam-apps`
- `build-all.sh`         — runs all three in order

Artifacts are produced under [`checkinstall/`](checkinstall/) as `.deb` files.

## Credits

This repository only packages upstream work. All credit for the camera
stack itself goes to:

- [raspberrypi/libpisp](https://github.com/raspberrypi/libpisp)
- [raspberrypi/libcamera](https://github.com/raspberrypi/libcamera)
- [raspberrypi/rpicam-apps](https://github.com/raspberrypi/rpicam-apps)
