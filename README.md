# Querencia Linux

> "Where Linux Feels at Home"

An atomic, immutable desktop image built on [AlmaLinux 10](https://almalinux.org/) with the [MATE Desktop Environment](https://mate-desktop.org/) — OCI container-based updates, automatic rollback, and enterprise-grade stability.

Built using the official [AlmaLinux Atomic Respin Template](https://github.com/AlmaLinux/atomic-respin-template).

![AlmaLinux](https://img.shields.io/badge/AlmaLinux-10-blue?logo=almalinux)
![MATE](https://img.shields.io/badge/Desktop-MATE-green?logo=mate)
![AMD](https://img.shields.io/badge/GPU-AMD%20RX%206600-red?logo=amd)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## Contents

- [What is this?](#what-is-this)
- [Architecture](#architecture)
- [Build](#build)
- [Installation](#installation)
- [Updates and Rollback](#updates-and-rollback)
- [ujust Commands](#ujust-commands)
- [AMD GPU Support](#amd-gpu-support)
- [Flatpak and Apps](#flatpak-and-apps)
- [Distrobox](#distrobox)
- [Micromamba](#micromamba)
- [Multimedia Codecs](#multimedia-codecs)
- [Customization](#customization)
- [Project Structure](#project-structure)
- [FAQ](#faq)

---

## What is this?

This project builds a **bootable OCI container image** that functions as a complete Linux desktop operating system. It combines:

| Component | Description |
|---|---|
| **AlmaLinux 10** | Enterprise Linux, RHEL-compatible, with long-term stability |
| **MATE Desktop** | Classic, fast, resource-friendly desktop environment (via [skip77 COPR](https://copr.fedorainfracloud.org/coprs/skip77/MateDesktop-EL10/)) |
| **bootc** | Atomic image-based updates with rollback |
| **AMD GPU (Mesa/amdgpu)** | Open-source drivers for RX 6600 (RDNA 2), Vulkan, VA-API |
| **Multimedia Codecs** | Full codec support via RPM Fusion (H.264, H.265, AAC, VP9, AV1) |
| **Micromamba** | Fast user-space package manager (conda-forge) |
| **Flatpak** | Sandboxed apps from Flathub |
| **Distrobox** | Mutable containers for development |

### Why?

- **Immutable** — The root filesystem is read-only. No more broken updates.
- **Rollback** — Return to the previous working image at any time.
- **Reproducible** — The image is built from numbered scripts. Always the same result.
- **Automatic updates** — GitHub Actions builds a new image weekly.
- **Enterprise-stable** — AlmaLinux 10 as the base. No rolling-release surprises.
- **AMD GPU out of the box** — Mesa + Vulkan (RADV) + VA-API hardware video decoding.
- **AlmaLinux Atomic ecosystem** — Built on the official respin template with `bootc container lint`, Cosign signing support, and the `atomic-ci` pipeline.

---

## Architecture

```
+-----------------------------------------------------+
|                   Your Desktop                       |
|  +---------+  +----------+  +--------------------+  |
|  | Flatpak |  | Distrobox|  |  Native MATE Apps   |  |
|  |  Apps   |  | Containers|  |  (built into image) |  |
|  +---------+  +----------+  +--------------------+  |
+-----------------------------------------------------+
|  MATE Desktop + LightDM + PipeWire                   |
+-----------------------------------------------------+
|  Mesa (OpenGL / Vulkan RADV) + VA-API + amdgpu       |
+-----------------------------------------------------+
|  AlmaLinux 10 bootc (immutable, atomic)              |
+-----------------------------------------------------+
|  Linux Kernel + Firmware (RDNA 2)                    |
+-----------------------------------------------------+
```

### Image Layers

```
quay.io/almalinuxorg/almalinux-bootc:10     ← Bare bootc base (no desktop)
    ↓
ghcr.io/endegelaende/querencia-linux:latest  ← This image (MATE + everything)
```

### Update Flow

```
GitHub Push/Schedule → GitHub Actions → Build Image → Push to GHCR
                                                          |
Your PC: bootc upgrade ←----------------------------------|
              |
         Reboot → New image active (old image kept for rollback)
```

---

## Build

### Prerequisites

- Podman (with `--cap-add=all` and `--device /dev/fuse` support)
- ~10 GB disk space for the build

### Local Build with Podman

```bash
# Using the Makefile (recommended)
make image

# Or manually
sudo podman build \
    --security-opt=label=disable \
    --cap-add=all \
    --device /dev/fuse \
    --build-arg IMAGE_NAME=localhost/querencia-linux \
    --build-arg IMAGE_REGISTRY=localhost \
    -t localhost/querencia-linux \
    -f Dockerfile .
```

### Build an ISO (for fresh install)

```bash
make iso
# Output: ./output/bootiso/install.iso
```

### Build a QCOW2 (for VM testing)

```bash
make qcow2
# Output: ./output/qcow2/disk.qcow2

# Test in QEMU
make run-qemu-qcow
```

### Automatic Build via GitHub Actions

The CI pipeline runs automatically on:
- Push to `main` branch
- Weekly (Monday 04:00 UTC) to pick up base image updates
- Manual trigger via GitHub UI (`workflow_dispatch`)

The pipeline uses the [AlmaLinux atomic-ci](https://github.com/AlmaLinux/atomic-ci) reusable workflows and includes:
- Image build with layer caching
- `bootc container lint` verification
- Container smoke test (`bootc -V`, `os-release` check)
- Image promotion (tagging as `latest`)
- Automatic GitHub Release creation

---

## Installation

### Option A: Rebase from an existing bootc/Atomic system

```bash
sudo bootc switch ghcr.io/endegelaende/querencia-linux:latest
sudo reboot
```

### Option B: Fresh install with the ISO

1. Build the ISO (`make iso`) or download from GitHub Actions artifacts
2. Write to a USB drive (Ventoy, Rufus, or `dd`)
3. Boot from USB
4. Follow the Anaconda installer (choose language, disk, create your user)

### Option C: Test in a VM

```bash
# Build QCOW2 image
make qcow2

# Run in QEMU (KVM accelerated)
make run-qemu-qcow

# Or install from ISO
make run-qemu-iso
```

---

## Updates and Rollback

### Updating the System

```bash
# Update everything (recommended)
ujust update

# Or manually:
sudo bootc upgrade          # Base image
flatpak update -y           # Flatpak apps
```

### Rollback

```bash
# Roll back to the previous image
ujust rollback
# Or: sudo bootc rollback
sudo reboot
```

### How Updates Work

1. `bootc upgrade` downloads the new image in the background
2. The new image is staged alongside the current one
3. On reboot, the new image becomes active
4. The old image is kept — you can always roll back
5. No partial updates, no broken states — the entire image is atomic

---

## ujust Commands

`ujust` is a convenience wrapper around [just](https://github.com/casey/just). Run `ujust --list` for all available commands.

### System

| Command | Description |
|---|---|
| `ujust update` | Full update (bootc + Flatpak) |
| `ujust status` | Show bootc image status |
| `ujust rollback` | Roll back to previous image |
| `ujust info` | Show system info (fastfetch) |
| `ujust disk` | Show disk usage |
| `ujust memory` | Show memory usage |
| `ujust services` | Show running services |
| `ujust logs` | Show current boot logs |
| `ujust trim` | Run SSD TRIM |
| `ujust clean` | Clean up caches and logs |
| `ujust maintenance` | Full maintenance (update + clean) |

### AMD GPU

| Command | Description |
|---|---|
| `ujust gpu-info` | Show GPU driver, Vulkan, VA-API info |
| `ujust gpu-monitor` | Live GPU monitoring (temp, clock, VRAM) |
| `ujust gpu-sensors` | One-shot sensor readings |
| `ujust gpu-performance` | Set GPU to performance mode |
| `ujust gpu-powersave` | Set GPU to power saving mode |
| `ujust gpu-auto` | Set GPU to automatic mode |
| `ujust gpu-test` | Run Vulkan test (vkcube) |

### Flatpak

| Command | Description |
|---|---|
| `ujust setup-flatpak` | Set up Flathub |
| `ujust install-essentials` | Install recommended apps |
| `ujust clean-flatpak` | Remove unused runtimes |

### Distrobox

| Command | Description |
|---|---|
| `ujust distrobox-alma` | Create AlmaLinux container |
| `ujust distrobox-fedora` | Create Fedora container |
| `ujust distrobox-ubuntu` | Create Ubuntu container |
| `ujust distrobox-list` | List all containers |
| `ujust distrobox-upgrade` | Upgrade all containers |

### Micromamba

| Command | Description |
|---|---|
| `ujust mamba-setup` | Initialize micromamba |
| `ujust mamba-install-tools` | Install CLI tools (ripgrep, bat, eza, fzf, etc.) |
| `ujust mamba-python [version]` | Create Python dev environment |
| `ujust mamba-node [version]` | Create Node.js dev environment |
| `ujust mamba-create [name]` | Create empty environment |
| `ujust mamba-list` | List environments |
| `ujust mamba-backup [name]` | Export environment to YAML |
| `ujust mamba-restore [file]` | Restore from YAML |

### MATE Desktop

| Command | Description |
|---|---|
| `ujust mate-reset-panel` | Reset panel to defaults |
| `ujust mate-dark` | Switch to dark theme |
| `ujust mate-light` | Switch to light theme |

### Multimedia

| Command | Description |
|---|---|
| `ujust codec-check` | Check installed codecs |
| `ujust codec-test` | Play a test video |

---

## AMD GPU Support

### What is Included

The image ships with full open-source AMD GPU support:

| Component | Package | Purpose |
|---|---|---|
| Kernel driver | `amdgpu` (built-in) | GPU hardware access |
| OpenGL | `mesa-dri-drivers` | 3D rendering |
| Vulkan | `mesa-vulkan-drivers` (RADV) | Modern graphics API |
| VA-API | `mesa-va-drivers` | Hardware video decoding |
| Firmware | `linux-firmware` | GPU microcode (RDNA 2) |

### Kernel Optimizations

- `amdgpu` module loaded early at boot (`/etc/modules-load.d/amdgpu.conf`)
- Full Power-Play feature mask enabled (`ppfeaturemask=0xffffffff`) for overclocking and fan control

### Checking GPU Status

```bash
# Quick overview
ujust gpu-info

# Live monitoring
ujust gpu-monitor

# Vulkan test
ujust gpu-test
```

### Gaming

Install Steam via Flatpak for Proton/DXVK gaming:

```bash
flatpak install flathub com.valvesoftware.Steam
```

Vulkan (RADV) and 32-bit libraries are included in the Steam Flatpak.

---

## Flatpak and Apps

### Set Up Flathub (automatic on first login)

Flathub is configured system-wide during the image build and per-user on first login. You can also run:

```bash
ujust setup-flatpak
```

### Install Recommended Apps

```bash
ujust install-essentials
```

This installs: Firefox, Thunderbird, LibreOffice, Calculator, Evince, Flatseal, Celluloid.

### Install Additional Apps

```bash
flatpak install flathub com.spotify.Client
flatpak install flathub com.discordapp.Discord
flatpak install flathub com.valvesoftware.Steam
flatpak install flathub org.gimp.GIMP
```

---

## Distrobox

[Distrobox](https://github.com/89luca89/distrobox) gives you mutable containers that integrate with your desktop. Perfect for development tools that need `dnf install` or `apt install`.

```bash
# Create an AlmaLinux development container
ujust distrobox-alma
distrobox enter alma

# Inside the container: full dnf access
dnf install -y gcc make python3-devel

# Export a GUI app to your host desktop
distrobox-export --app code
```

Available presets: `ujust distrobox-alma`, `ujust distrobox-fedora`, `ujust distrobox-ubuntu`.

---

## Micromamba

[Micromamba](https://mamba.readthedocs.io/) is a fast, standalone package manager for conda-forge. Installed system-wide at `/usr/local/bin/micromamba`, but environments are per-user in `~/micromamba`.

### Getting Started

```bash
# Initialize (first time)
ujust mamba-setup
source ~/.bashrc

# Install useful CLI tools
ujust mamba-install-tools
micromamba activate tools
```

### Development Environments

```bash
# Python 3.12
ujust mamba-python 3.12
micromamba activate python3.12

# Node.js 22
ujust mamba-node 22
micromamba activate node22

# Custom environment
ujust mamba-create myproject
micromamba activate myproject
micromamba install -c conda-forge numpy pandas jupyter
```

### Backup and Restore

```bash
# Export
ujust mamba-backup tools

# Restore (on a new machine or after reinstall)
ujust mamba-restore ~/.config/micromamba-backups/tools.yml
```

---

## Multimedia Codecs

Full multimedia support is included via RPM Fusion:

| Format | Support |
|---|---|
| H.264 (AVC) | ✅ GStreamer + FFmpeg |
| H.265 (HEVC) | ✅ GStreamer + FFmpeg |
| AAC | ✅ GStreamer + FFmpeg |
| VP9 | ✅ GStreamer + FFmpeg |
| AV1 | ✅ GStreamer + FFmpeg |
| MP3 | ✅ GStreamer + FFmpeg |

### Verify Codec Support

```bash
ujust codec-check
```

### Test Playback

```bash
ujust codec-test
```

---

## Customization

### Adding Packages to the Image

Edit or add a numbered script in `files/scripts/`. The build system runs scripts matching `*-*.sh` in human-numeric order:

```bash
# files/scripts/46-my-packages.sh
#!/usr/bin/env bash
set -xeuo pipefail

dnf install -y my-package another-package
```

### Adding System Configuration Files

Place files under `files/system/` mirroring the root filesystem structure. They are copied to `/` at the start of the build:

```
files/system/etc/my-config.conf  →  /etc/my-config.conf
files/system/usr/share/foo/bar   →  /usr/share/foo/bar
```

### Changing MATE Settings

Edit `files/system/etc/dconf/db/local.d/01-mate-defaults.conf` and rebuild. Users can always override settings individually — the dconf file only sets system-wide defaults.

### Adding ujust Recipes

Edit `files/system/usr/share/justfiles/custom.just` to add new commands.

---

## Project Structure

```
querencia-linux/
├── .github/
│   ├── actions/config/action.yml   ← CI environment (registry, image name)
│   └── workflows/build.yml         ← GitHub Actions pipeline (atomic-ci)
├── files/
│   ├── scripts/
│   │   ├── build.sh                ← Build orchestrator (copies files, runs scripts)
│   │   ├── cleanup.sh              ← Image layer cleanup (dnf clean, /var, /usr/local)
│   │   ├── 10-repos.sh             ← EPEL, CRB, Rocky Devel, skip77 COPR, RPM Fusion
│   │   ├── 20-mate-desktop.sh      ← MATE Desktop + LightDM + Xorg + Fonts + Locale
│   │   ├── 25-audio.sh             ← PipeWire + WirePlumber
│   │   ├── 30-amd-gpu.sh           ← Mesa, Vulkan (RADV), VA-API, Firmware
│   │   ├── 35-multimedia.sh        ← GStreamer + FFmpeg codecs (RPM Fusion)
│   │   ├── 40-network.sh           ← NetworkManager, Bluetooth
│   │   ├── 45-system-tools.sh      ← Firefox, htop, git, fastfetch, just
│   │   ├── 50-micromamba.sh         ← Micromamba binary to /usr/local/bin
│   │   ├── 55-flatpak.sh           ← Flatpak + Flathub remote
│   │   ├── 60-distrobox.sh         ← Distrobox + Podman
│   │   ├── 70-services.sh          ← systemd service enablement
│   │   ├── 75-post-install.sh      ← ujust, first-boot, sysctl, polkit, MOTD
│   │   ├── 80-branding.sh          ← os-release, /etc/issue
│   │   ├── 85-amd-tuning.sh        ← amdgpu module + ppfeaturemask
│   │   ├── 90-signing.sh           ← Cosign key setup (from template)
│   │   └── 91-image-info.sh        ← VARIANT_ID in os-release (from template)
│   └── system/                      ← Files overlaid onto / during build
│       ├── etc/
│       │   ├── dconf/               ← MATE default settings
│       │   ├── lightdm/             ← LightDM + Slick Greeter config
│       │   ├── profile.d/           ← Micromamba shell integration
│       │   └── yum.repos.d/         ← Rocky Devel + skip77 MATE COPR repos
│       └── usr/share/justfiles/     ← ujust recipes (custom.just)
├── Dockerfile                       ← Multi-stage build (AlmaLinux bootc:10 base)
├── Makefile                         ← Local build, ISO, QCOW2, QEMU targets
├── atomic-desktop.pub               ← AlmaLinux Atomic Desktop verification key
├── iso.toml                         ← bootc-image-builder ISO configuration
├── LICENSE                          ← MIT
└── README.md                        ← This file
```

### How the Build Works

1. **Stage 1 (`scratch`)**: System files, scripts, and keys are copied into a throwaway context layer
2. **Stage 2 (`almalinux-bootc:10`)**: The actual image build:
   - `build.sh` copies `files/system/` to `/` (config overlay)
   - Numbered scripts (`10-*.sh` through `91-*.sh`) run in order
   - `cleanup.sh` minimizes the final image
3. **Linting**: `bootc container lint` verifies the image is bootable
4. Build scripts and context files are **not** included in the final image (multi-stage build)

---

## FAQ

### Can I still use dnf?

No — the root filesystem is read-only. Use:
- **Flatpak** for GUI apps
- **Distrobox** for CLI tools and development
- **Micromamba** for language-specific packages (Python, Node.js, etc.)
- **Add packages to the image** by editing `files/scripts/` and rebuilding

### Is my AMD RX 6600 supported?

Yes. The RDNA 2 architecture is fully supported by the open-source `amdgpu` kernel driver and Mesa userspace. Vulkan, OpenGL, and VA-API hardware video decoding all work out of the box.

### How large is the image?

The OCI image is approximately 3–4 GB compressed. The installed system uses about 8–10 GB.

### What happens if an update is broken?

Roll back:

```bash
sudo bootc rollback
sudo reboot
```

The previous working image is always kept. You can also select it from the GRUB boot menu.

### Can I use Wayland instead of X11?

Not with MATE. MATE requires Xorg, which is provided by the skip77 COPR. The LightDM display manager starts an Xorg session by default.

### Why MATE and not GNOME/KDE?

MATE is lightweight, classic, and fast. AlmaLinux already provides official [GNOME](https://github.com/AlmaLinux/atomic-desktop) and [KDE](https://github.com/AlmaLinux/atomic-desktop) atomic images. This project fills the MATE gap.

### Why AlmaLinux and not CentOS Stream?

AlmaLinux 10 is binary-compatible with RHEL 10 and provides:
- The official [Atomic Respin Template](https://github.com/AlmaLinux/atomic-respin-template) we build on
- Professional CI infrastructure (`atomic-ci`) with Cosign signing
- A dedicated Atomic SIG (Special Interest Group) maintaining the base images
- Long-term support and a community-governed project

Both AlmaLinux 10 and CentOS Stream 10 use the same packages — the skip77 MATE COPR works on both (it targets `rhel+epel-10`).

### How does this differ from Universal Blue / Bluefin?

| | Querencia Linux | Universal Blue |
|---|---|---|
| Base | AlmaLinux 10 (RHEL-compatible) | Fedora (rolling) |
| Desktop | MATE | GNOME (Bluefin) / KDE (Aurora) |
| Updates | Weekly rebuild | Daily rebuild |
| Philosophy | Enterprise-stable, minimal | Bleeding-edge, feature-rich |
| GPU Focus | AMD (open-source Mesa) | NVIDIA + AMD |
| Template | AlmaLinux atomic-respin-template | Custom build system |

### How do I contribute?

1. Fork this repository
2. Create a feature branch
3. Edit the relevant script in `files/scripts/` or config in `files/system/`
4. Test locally with `make image`
5. Submit a pull request

---

## License

[MIT](LICENSE)