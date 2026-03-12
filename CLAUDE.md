# CLAUDE.md – Project Context for Querencia Linux

> **Querencia Linux** – "Where Linux Feels at Home"
> Atomic, immutable desktop image built on AlmaLinux 10 with MATE Desktop.
> Based on the official [AlmaLinux Atomic Respin Template](https://github.com/AlmaLinux/atomic-respin-template).

> **Repository:** https://github.com/endegelaende/querencia-linux
> **Image:** `ghcr.io/endegelaende/querencia-linux:latest`
> **Base:** `quay.io/almalinuxorg/almalinux-bootc:10` (bare bootc, no desktop)

## Quick Reference

```bash
# Local build (requires Podman with --cap-add=all + --device /dev/fuse)
make image

# Build ISO installer
make iso

# Build QCOW2 for VM testing
make qcow2

# Test in QEMU
make run-qemu-qcow
make run-qemu-iso
```

## What This Project Is

A **bootable OCI container image** that functions as a complete Linux desktop OS:

- **AlmaLinux 10** – Enterprise Linux, RHEL-compatible, long-term support
- **MATE Desktop** – Classic, lightweight (via [skip77/MateDesktop-EL10 COPR](https://copr.fedorainfracloud.org/coprs/skip77/MateDesktop-EL10/))
- **bootc** – Atomic image-based updates with rollback
- **AMD GPU** – Mesa + Vulkan (RADV) + VA-API for RX 6600 (RDNA 2)
- **Multimedia** – Full codec support via RPM Fusion (H.264, H.265, AAC, VP9, AV1)
- **Micromamba** – User-space package manager (conda-forge)
- **Flatpak** – Sandboxed apps from Flathub
- **Distrobox** – Mutable containers for development

The root filesystem is **read-only at runtime**. Software installation happens via Flatpak, Distrobox, Micromamba, or by editing the build scripts and rebuilding the image.

## History

**v1 (original):** Built on CentOS Stream 10 (`centos-bootc:stream10`) with a monolithic `Containerfile`. Custom CI/CD with manual Podman+ISO build steps.

**v2 (current):** Rebuilt from scratch on **AlmaLinux 10** using the official Atomic Respin Template. Modular numbered scripts, multi-stage Dockerfile, `bootc container lint`, Cosign signing support, AlmaLinux `atomic-ci` reusable workflows. The skip77 MATE COPR works identically on AlmaLinux 10 (it targets `rhel+epel-10`, which is the same for all EL10 distros).

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
quay.io/almalinuxorg/almalinux-bootc:10        ← Bare bootc base (no desktop)
    ↓
ghcr.io/endegelaende/querencia-linux:latest     ← This image (MATE + everything)
```

### Update Flow

```
GitHub Push/Schedule → GitHub Actions → Build Image → Push to GHCR
                                                          |
Your PC: bootc upgrade ←----------------------------------|
              |
         Reboot → New image active (old image kept for rollback)
```

## Project Structure

```
querencia-linux/
├── .github/
│   ├── actions/config/action.yml   ← CI environment variables (registry, image name)
│   └── workflows/build.yml         ← GitHub Actions pipeline (uses atomic-ci v11)
├── files/
│   ├── scripts/                    ← Numbered build scripts (run in order by build.sh)
│   │   ├── build.sh                ← Orchestrator: copies system files, runs *-*.sh scripts, cleanup
│   │   ├── cleanup.sh              ← Final cleanup: dnf clean, /var + /boot reset, /usr/local writable
│   │   ├── 10-repos.sh             ← EPEL, CRB, Rocky Devel, skip77 COPR, RPM Fusion
│   │   ├── 20-mate-desktop.sh      ← MATE Desktop + LightDM + Xorg + Fonts + Locale
│   │   ├── 25-audio.sh             ← PipeWire + WirePlumber (user services)
│   │   ├── 30-amd-gpu.sh           ← Mesa, Vulkan (RADV), VA-API, linux-firmware
│   │   ├── 35-multimedia.sh        ← GStreamer + FFmpeg codecs (RPM Fusion)
│   │   ├── 40-network.sh           ← NetworkManager, WiFi, OpenVPN, Bluetooth
│   │   ├── 45-system-tools.sh      ← Firefox, gnome-disk-utility, htop, git, fastfetch, just
│   │   ├── 50-micromamba.sh         ← Micromamba binary to /usr/local/bin
│   │   ├── 55-flatpak.sh           ← Flatpak + Flathub remote
│   │   ├── 60-distrobox.sh         ← Distrobox + Podman
│   │   ├── 70-services.sh          ← fstrim.timer
│   │   ├── 75-post-install.sh      ← ujust, first-boot service, sysctl, polkit, MOTD, dconf update
│   │   ├── 80-branding.sh          ← os-release (ID=almalinux), /etc/issue
│   │   ├── 85-amd-tuning.sh        ← amdgpu kernel module + ppfeaturemask=0xffffffff
│   │   ├── 90-signing.sh           ← Cosign key setup (DO NOT MODIFY -- from template)
│   │   └── 91-image-info.sh        ← VARIANT_ID in os-release (DO NOT MODIFY -- from template)
│   └── system/                      ← Files overlaid onto / at start of build
│       ├── etc/
│       │   ├── dconf/
│       │   │   ├── db/local.d/01-mate-defaults.conf  ← MATE desktop defaults (theme, fonts, terminal, etc.)
│       │   │   └── profile/user                       ← dconf profile (user-db:user, system-db:local)
│       │   ├── lightdm/
│       │   │   ├── lightdm.conf                       ← LightDM config (MATE session, slick-greeter)
│       │   │   └── slick-greeter.conf                 ← Login screen theme
│       │   ├── profile.d/
│       │   │   └── micromamba.sh                      ← Shell integration + aliases (mamba, conda)
│       │   └── yum.repos.d/
│       │       ├── rocky-devel.repo                   ← Rocky Linux 10 Devel (build deps)
│       │       └── skip77-MateDesktop-EL10.repo       ← skip77 MATE COPR for EL10
│       └── usr/share/justfiles/
│           └── custom.just                            ← ujust recipes (update, gpu, mamba, etc.)
├── Dockerfile                       ← Multi-stage build (scratch → almalinux-bootc:10)
├── Makefile                         ← Local build targets (image, iso, qcow2, run-qemu-*)
├── atomic-desktop.pub               ← AlmaLinux Atomic Desktop verification key
├── iso.toml                         ← bootc-image-builder ISO configuration
├── .gitattributes                   ← Force LF line endings (Linux project built on Windows)
├── .gitignore                       ← Build artifacts, secrets, editor files
├── LICENSE                          ← MIT
└── README.md                        ← User-facing documentation
```

## How the Build Works

The Dockerfile uses a **multi-stage build** pattern from the AlmaLinux Atomic Respin Template:

### Stage 1: Context (`FROM scratch AS ctx`)

Copies files into a throwaway layer that does NOT end up in the final image:
- `files/system/` → `/system_files/` (config overlay)
- `files/scripts/` → `/build_files/` (with `chmod 0755`)
- `*.pub` → `/keys/` (signing keys)

### Stage 2: Image Build (`FROM almalinux-bootc:10`)

Single `RUN` instruction that bind-mounts the context and runs `build.sh`:

```
RUN --mount=type=tmpfs,dst=/opt \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build_files/build.sh
```

The `build.sh` orchestrator:
1. `cp -avf /ctx/system_files/. /` — copies system config files onto root filesystem
2. Finds all `*-*.sh` scripts and runs them in human-numeric sort order (10, 20, 25, 30, ...)
3. Runs `cleanup.sh` at the end (always, regardless of script order)

### Stage 3: Linting

```
RUN bootc container lint
```

Verifies the final image is a valid bootable container.

### Key implications:
- Build scripts and context files are **never included** in the final image
- `tmpfs` mounts on `/opt` and `/tmp` keep temporary build artifacts out of the layer
- The `cleanup.sh` removes `/var` and `/boot` and recreates them empty (bootc manages these at runtime)
- `/usr/local` is moved to `/var/usrlocal` with a symlink (makes it writable on bootc systems)

## Build Scripts – Detailed Reference

### 10-repos.sh – Repository Setup

Repositories needed for the build:

| Repository | Purpose | Source |
|---|---|---|
| **EPEL** | Extra Packages for Enterprise Linux | `dnf install epel-release` |
| **CRB** | CodeReady Builder (build deps) | `dnf config-manager --set-enabled crb` |
| **Rocky Devel** | Build deps not in CentOS/Alma base repos | `files/system/etc/yum.repos.d/rocky-devel.repo` |
| **skip77 COPR** | MATE Desktop + Xorg + LightDM for EL10 | `files/system/etc/yum.repos.d/skip77-MateDesktop-EL10.repo` |
| **RPM Fusion Free** | Multimedia codecs (GStreamer, FFmpeg) | Installed from RPM URL |
| **RPM Fusion Nonfree** | Additional codecs | Installed from RPM URL |

The repo files for Rocky Devel and skip77 are placed by the `cp -avf system_files/. /` step in `build.sh` **before** the numbered scripts run.

### 20-mate-desktop.sh – MATE Desktop

- `dnf groupinstall "MATE-Desktop"` — full MATE from skip77 COPR (includes Xorg, LightDM, Compiz)
- Individual MATE packages installed with `|| true` fallback (may not all exist in COPR)
- Fonts: Noto Sans/Serif/Mono, Noto Emoji, Liberation, DejaVu
- Locale: `glibc-langpack-en` + `glibc-langpack-de` (critical for ostree/bootc UTF-8 path handling)
- `LANG=en_US.UTF-8` written to `/etc/locale.conf`
- LightDM enabled, graphical target set as default

**Why skip77 COPR?** CentOS Stream 10 / AlmaLinux 10 / RHEL 10 dropped Xorg and MATE from the base repos. The skip77 COPR rebuilds MATE + Xorg + LightDM for EL10. It builds for the `rhel+epel-10` chroot, which is binary-compatible across all EL10 distros.

### 25-audio.sh – PipeWire

- PipeWire + PulseAudio compatibility + ALSA integration + WirePlumber
- `pavucontrol` for GUI volume control
- PipeWire is a **user service** (started per user session, not system-wide)

### 30-amd-gpu.sh – AMD GPU Drivers

Userspace only — the `amdgpu` kernel driver is built into the AlmaLinux kernel:

| Package | Purpose |
|---|---|
| `mesa-dri-drivers` | OpenGL (RadeonSI) |
| `mesa-vulkan-drivers` | Vulkan (RADV) |
| `mesa-libGL`, `mesa-libEGL`, `mesa-libgbm` | GL/EGL/GBM libraries |
| `vulkan-loader`, `vulkan-tools` | Vulkan runtime + `vulkaninfo` |
| `libva` | VA-API library |
| `linux-firmware` | GPU firmware for RDNA 2 |
| `mesa-va-drivers` (optional) | VA-API hardware video decoding |
| `mesa-vdpau-drivers` (optional) | VDPAU video decoding |
| `libva-utils` (optional) | `vainfo` diagnostic tool |

### 35-multimedia.sh – Codecs

From RPM Fusion. Each optional package installed individually with `|| true` because package names vary across EL versions and DNF4 has no `--skip-unavailable`:

- GStreamer: base, good, bad-free, ugly, good-extras, bad-freeworld, OpenH264, libav
- FFmpeg: full version from RPM Fusion (not the restricted `-free` variant)
- Codec libraries: x264-libs, x265-libs
- Fallback: if full `ffmpeg` not available, tries `ffmpeg-free`

### 40-network.sh – Networking

- NetworkManager + WiFi + OpenVPN + network-manager-applet
- Bluetooth: bluez + blueman
- Both services enabled via systemctl

### 45-system-tools.sh – System Utilities

Firefox, gnome-disk-utility, gnome-keyring, xdg-utils, xdg-user-dirs, bash-completion, vim, htop, wget, curl, git. Optional: fastfetch, just.

### 50-micromamba.sh – Micromamba

Downloads latest micromamba binary to `/usr/local/bin/micromamba`. Shell integration is provided by `files/system/etc/profile.d/micromamba.sh` (copied by build.sh before this script runs). Aliases: `mamba` and `conda` → `micromamba`.

After `cleanup.sh`, `/usr/local` is moved to `/var/usrlocal` (writable on bootc), so the binary ends up at `/var/usrlocal/bin/micromamba` with a symlink from `/usr/local`.

### 55-flatpak.sh – Flatpak

Installs Flatpak and adds the Flathub remote system-wide. Per-user Flathub setup happens on first login via the first-boot service (see 75-post-install.sh).

### 60-distrobox.sh – Distrobox

Installs Distrobox + Podman. Users can create mutable containers for development.

### 70-services.sh – Systemd Services

Enables `fstrim.timer` for periodic SSD TRIM. Other services (LightDM, NetworkManager, Bluetooth) are enabled in their respective scripts (20, 40).

### 75-post-install.sh – Post-Install Configuration

This is the largest script. It sets up:

1. **XDG user directories** – English defaults (Desktop, Downloads, Documents, etc.)
2. **Flatpak overrides** – Global DRI device access + GTK theming for sandboxed apps
3. **Systemd presets** – Service enablement list for first boot
4. **ujust shortcut** – `/usr/local/bin/ujust` → `just --justfile /usr/share/justfiles/custom.just`
5. **First-boot user service** – Runs once per user on first login:
   - Creates XDG user directories
   - Adds Flathub remote for user
   - Shows desktop notification
   - Creates `~/.config/querencia-setup-done` marker
6. **MOTD** – Terminal welcome message + `/etc/issue.net`
7. **Polkit rules** – wheel group can manage Flatpak without password
8. **Sysctl tweaks** – `vm.swappiness=10`, inotify limits (524288 watches), BBR congestion control
9. **Bash aliases** – `ls --color=auto`, `ll`
10. **dconf update** – Applies MATE defaults from `01-mate-defaults.conf`

### 80-branding.sh – OS Branding

Writes custom `/usr/lib/os-release` with:
- `ID=almalinux` (kept for bootc/bootc-image-builder compatibility)
- `NAME="Querencia Linux"`
- `PRETTY_NAME="Querencia Linux 10 -- Where Linux Feels at Home"`
- `VARIANT="MATE Desktop"`, `VARIANT_ID=mate`

Note: `91-image-info.sh` later overwrites `VARIANT_ID` with the image name (`querencia-linux`) for AlmaLinux countme stats.

### 85-amd-tuning.sh – AMD GPU Kernel Tuning

- `/etc/modules-load.d/amdgpu.conf` – Loads `amdgpu` module early at boot
- `/etc/modprobe.d/amdgpu.conf` – `ppfeaturemask=0xffffffff` for full Power-Play (overclocking, fan curve control)

### 90-signing.sh – Cosign Signing (Template)

**DO NOT MODIFY.** From the AlmaLinux template. Sets up container signing policy if a `cosign.pub` key is present. Configures registry trust policy with `jq`.

### 91-image-info.sh – Image Info (Template)

**DO NOT MODIFY.** From the AlmaLinux template. Replaces `VARIANT_ID` in `/usr/lib/os-release` with the `IMAGE_NAME` build arg for AlmaLinux countme usage statistics.

### cleanup.sh – Image Cleanup (Template)

**DO NOT MODIFY.** Called last by `build.sh`. Performs:
- `dnf clean all`
- Removes `/var` and `/boot`, recreates them empty (bootc manages at runtime)
- Moves `/usr/local` to `/var/usrlocal` + symlink (makes it writable on immutable root)

### build.sh – Build Orchestrator (Template)

**DO NOT MODIFY.** Entry point called by the Dockerfile:
1. Copies `system_files/` to `/` (config overlay)
2. Finds all `*-*.sh` scripts via `find` with `sort --sort=human-numeric`
3. Runs each script in a `::group::` block (GitHub Actions log grouping)
4. Runs `cleanup.sh` at the end

## System Configuration Files

### files/system/etc/yum.repos.d/rocky-devel.repo

Rocky Linux 10 Devel repository. Provides build dependencies not available in AlmaLinux base repos. Priority 200 (low) so it doesn't override base packages.

### files/system/etc/yum.repos.d/skip77-MateDesktop-EL10.repo

skip77 COPR repository for MATE Desktop on EL10. Targets `rhel+epel-10-$basearch`. GPG-checked.

### files/system/etc/lightdm/lightdm.conf

- Default session: `mate`
- Greeter: `slick-greeter`
- Guest login disabled
- User switching allowed

### files/system/etc/lightdm/slick-greeter.conf

Login screen appearance: Noto Sans font, Adwaita cursor, dark background, clock format `%H:%M • %A, %d. %B %Y`.

### files/system/etc/dconf/db/local.d/01-mate-defaults.conf

System-wide MATE desktop defaults (users can override individually):

- **Theme:** BlueMenta (GTK + Marco)
- **Fonts:** Noto Sans 10, Noto Sans Mono 10
- **Terminal:** Dracula-inspired color scheme, unlimited scrollback
- **Window Manager:** Compositing enabled, 4 workspaces, center new windows
- **Keyboard:** German layout (`de`)
- **Power:** No sleep on AC, display off after 15min
- **File Manager (Caja):** List view, small zoom, show delete option
- **Screensaver:** Blank mode, lock after 10min idle

### files/system/etc/dconf/profile/user

```
user-db:user
system-db:local
```

Standard dconf profile: user settings override system defaults.

### files/system/etc/profile.d/micromamba.sh

Bash shell integration for micromamba:
- Sets `MAMBA_ROOT_PREFIX=~/micromamba`
- Evaluates micromamba shell hook
- Aliases: `mamba` and `conda` → `micromamba`

### files/system/usr/share/justfiles/custom.just

Comprehensive ujust recipes. Categories:

| Category | Recipes |
|---|---|
| **System** | `update`, `update-system`, `update-flatpak`, `status`, `rollback`, `info`, `disk`, `memory`, `services`, `logs`, `trim`, `clean`, `maintenance` |
| **Flatpak** | `setup-flatpak`, `install-essentials`, `clean-flatpak` |
| **Distrobox** | `distrobox-alma`, `distrobox-fedora`, `distrobox-ubuntu`, `distrobox-list`, `distrobox-upgrade` |
| **AMD GPU** | `gpu-info`, `gpu-monitor`, `gpu-sensors`, `gpu-performance`, `gpu-powersave`, `gpu-auto`, `gpu-test` |
| **MATE** | `mate-reset-panel`, `mate-dark`, `mate-light` |
| **Micromamba** | `mamba-setup`, `mamba-install-tools`, `mamba-create`, `mamba-install`, `mamba-list`, `mamba-packages`, `mamba-update`, `mamba-backup`, `mamba-restore`, `mamba-backups`, `mamba-clean`, `mamba-python`, `mamba-node` |
| **Multimedia** | `codec-check`, `codec-test` |

## CI/CD Pipeline

### GitHub Actions (`.github/workflows/build.yml`)

Uses [AlmaLinux/atomic-ci](https://github.com/AlmaLinux/atomic-ci) v11 reusable workflows.

**Triggers:**
- Push to `main` (excluding README changes)
- Pull requests
- Weekly schedule: Monday 04:00 UTC
- Manual `workflow_dispatch`

**Jobs:**
1. **set-env** – Sets registry, image name, platform variables
2. **build-image** – Builds OCI image via `atomic-ci/build-image.yml`
3. **test-image** – Smoke test: runs container, checks `bootc -V` and `/etc/os-release`
4. **promote-image** – Tags as `latest`, version tags (only on `main`)
5. **create-release** – Creates GitHub Release (only on `main`)

**Guard:** `if: github.repository != 'AlmaLinux/atomic-respin-template'` prevents the template repo itself from building.

### Configuration (`.github/actions/config/action.yml`)

| Variable | Value | Notes |
|---|---|---|
| `REGISTRY` | `ghcr.io` | GitHub Container Registry |
| `REGISTRY_USER` | `${{ github.actor }}` | Auto from GitHub |
| `IMAGE_PATH` | `${{ github.repository_owner }}` | = `endegelaende` |
| `IMAGE_NAME` | `querencia-linux` | **Hardcoded** (repo can be renamed without breaking) |
| `PLATFORMS` | `amd64` | x86_64 only |
| `IS_SIGNED` | depends on `SIGNING_SECRET` | `true` if secret exists |

### Image References

| Reference | Purpose |
|---|---|
| `ghcr.io/endegelaende/querencia-linux:latest` | Latest stable image |
| `ghcr.io/endegelaende/querencia-linux:10` | Major version tag |
| `ghcr.io/endegelaende/querencia-linux:<version>` | Specific version |

## Key Design Decisions

### Why AlmaLinux 10 (not CentOS Stream 10)?

- Official Atomic Respin Template with professional CI infrastructure
- `atomic-ci` reusable workflows with Cosign signing, SBOM generation
- Dedicated Atomic SIG maintaining the base images
- `quay.io/almalinuxorg/almalinux-bootc:10` is a proper bare bootc image (no desktop)
- AlmaLinux is community-governed with long-term support guarantees
- Binary-compatible with RHEL 10 and CentOS Stream 10

### Why MATE Desktop?

- AlmaLinux already provides official GNOME and KDE atomic images
- MATE fills the gap for a lightweight, classic desktop
- MATE works well with X11 (no Wayland requirement)
- The skip77 COPR provides a complete, well-maintained MATE build for EL10

### Why skip77 COPR?

RHEL 10 / AlmaLinux 10 / CentOS Stream 10 removed Xorg from the base repos. MATE requires Xorg. The skip77 COPR:
- Provides the complete `MATE-Desktop` group (MATE + Xorg + LightDM + Compiz)
- Builds for `rhel+epel-10` chroot (works on all EL10 distros)
- Is the only maintained source of MATE packages for EL10
- Includes quality-of-life apps (Celluloid, DNFDragora, X-Apps)

### Why Rocky Devel repo?

Some build dependencies required by the skip77 COPR packages are only available in the Rocky Linux "devel" repository (similar to Fedora's "buildroot" packages). These are not in AlmaLinux or CentOS Stream base repos. The repo is set to priority 200 so it never overrides base packages.

### Why individual `|| true` for optional packages?

DNF4 (used in EL10) has no `--skip-unavailable` flag. If any package in a `dnf install` list doesn't exist, the entire command fails. Individual installs with `|| true` allow optional packages to be missing without breaking the build. This is particularly important for:
- MATE packages that may not all be in the COPR group
- VA-API/VDPAU packages with varying names across EL versions
- Extended GStreamer/FFmpeg codec packages from RPM Fusion

### Why multi-stage build?

The `FROM scratch AS ctx` pattern ensures:
- Build scripts are NOT included in the final image (saves space, reduces attack surface)
- System config files are only used during build (overlay), not shipped as separate layers
- GPG/signing keys are available during build but not persisted

### Why `/usr/local` → `/var/usrlocal` symlink?

On bootc/ostree systems, `/usr` is read-only at runtime. The `cleanup.sh` moves `/usr/local` to `/var/usrlocal` (which IS writable) and creates a symlink. This allows:
- Micromamba binary at `/usr/local/bin/micromamba` to be accessible
- `ujust` shortcut at `/usr/local/bin/ujust` to be accessible
- Users to install additional binaries to `/usr/local/bin` at runtime if needed

## Target Hardware

- **CPU:** x86_64
- **GPU:** AMD RX 6600 (RDNA 2) — but any AMD GPU supported by `amdgpu` + Mesa will work
- **Boot:** UEFI
- **Storage:** SSD recommended (fstrim.timer enabled)

## Language

The system locale is `en_US.UTF-8`. German locale data (`glibc-langpack-de`) is included. The MATE keyboard layout defaults to German (`de`). The ujust recipes and system messages are in English.

## Customization Guide

### Adding packages to the image

Create a new numbered script in `files/scripts/`:

```bash
# files/scripts/46-my-packages.sh
#!/usr/bin/env bash
set -xeuo pipefail

dnf install -y my-package another-package
```

The number determines execution order. Use a number between existing scripts.

### Adding system configuration files

Place files under `files/system/` mirroring the root filesystem:

```
files/system/etc/my-config.conf  →  /etc/my-config.conf
files/system/usr/share/foo/bar   →  /usr/share/foo/bar
```

These are copied to `/` at the start of the build (before numbered scripts run).

### Adding ujust recipes

Edit `files/system/usr/share/justfiles/custom.just`.

### Changing MATE defaults

Edit `files/system/etc/dconf/db/local.d/01-mate-defaults.conf`. Users can always override settings individually — this only sets system-wide defaults. The `dconf update` command is run by `75-post-install.sh`.

### Changing LightDM/greeter settings

Edit `files/system/etc/lightdm/lightdm.conf` or `slick-greeter.conf`.

## Files That Should NOT Be Modified

These come from the AlmaLinux Atomic Respin Template and should be kept in sync with upstream:

- `files/scripts/build.sh` – Build orchestrator
- `files/scripts/cleanup.sh` – Image layer cleanup
- `files/scripts/90-signing.sh` – Cosign key setup
- `files/scripts/91-image-info.sh` – VARIANT_ID for countme stats
- `atomic-desktop.pub` – AlmaLinux Atomic Desktop verification key

## Line Endings

This is a Linux project developed on Windows. `.gitattributes` enforces LF line endings for all text files. Shell scripts MUST use LF — CRLF will break them on Linux. Git is configured with `core.autocrlf=input` to normalize on commit.