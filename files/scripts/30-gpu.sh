#!/usr/bin/env bash
# =============================================================================
# Querencia Linux -- GPU Driver Installation
# =============================================================================
# Selects GPU driver stack based on the VARIANT build-arg (Dockerfile ARG).
#
#   VARIANT=""        → AMD (default) — Mesa + RADV + VA-API + linux-firmware
#   VARIANT="nvidia"  → NVIDIA — AlmaLinux native nvidia-open-kmod + Mesa fallback
#
# The VARIANT ARG is defined in the Dockerfile and is available as an
# environment variable during the RUN stage (Docker/Podman export all ARGs
# that are declared before the RUN instruction).
# =============================================================================
set -xeuo pipefail

# Default to AMD when VARIANT is unset or empty
VARIANT="${VARIANT:-}"

case "${VARIANT}" in

# =============================================================================
# NVIDIA — AlmaLinux official NVIDIA support
# https://wiki.almalinux.org/documentation/nvidia.html
#
# AlmaLinux provides pre-compiled, Secure-Boot-signed kernel modules via
# almalinux-release-nvidia-driver. This meta-package enables the NVIDIA
# repo as well as CRB, EPEL, and the CUDA repo.
#
# We use nvidia-open-kmod (open-source kernel modules, supported on
# Turing+ / GTX 1650+) plus the proprietary userspace driver.
# =============================================================================
nvidia)
    echo "=== GPU: Installing NVIDIA drivers (AlmaLinux native) ==="

    # Step 1: Enable AlmaLinux NVIDIA repository (+ CRB + EPEL + CUDA)
    dnf install -y almalinux-release-nvidia-driver

    # Step 2: Pre-compiled open kernel modules + userspace driver
    # nvidia-open-kmod  — open-source kernel module (Secure Boot signed by AlmaLinux)
    # nvidia-driver     — proprietary userspace (libGL, Xorg driver, settings)
    dnf install -y \
        nvidia-open-kmod \
        nvidia-driver

    # Step 3: CUDA utilities (nvidia-smi, etc.) — optional
    dnf install -y nvidia-driver-cuda || true

    # Step 4: Hybrid GPU switching (Intel/AMD iGPU + discrete NVIDIA)
    # switcheroo-control exposes a D-Bus interface that lets desktop environments
    # offer "Launch using Discrete GPU" context menu entries.
    dnf install -y switcheroo-control
    systemctl enable switcheroo-control.service

    # Step 5: Basic Mesa for software fallback / Wayland compatibility / Flatpak apps
    # Even with NVIDIA as the primary GPU, Mesa provides software rasterizers
    # and the Vulkan loader that many applications expect to find.
    dnf install -y \
        mesa-dri-drivers \
        mesa-libGL \
        mesa-libEGL \
        vulkan-loader

    echo "=== GPU: NVIDIA installation complete ==="
    ;;

# =============================================================================
# AMD (default) — Mesa userspace + VA-API hardware video + linux-firmware
#
# The amdgpu kernel driver is built into the kernel — no kmod needed.
# We only install userspace components:
#   - Mesa (OpenGL / Vulkan via RADV)
#   - VA-API (hardware video decode/encode)
#   - linux-firmware (GPU microcode for GCN 1.2+ / RDNA / RDNA 2+)
#   - Xorg DDX drivers (xorg-x11-drv-amdgpu for modern, -ati for legacy)
# =============================================================================
""|amd)
    echo "=== GPU: Installing AMD drivers (Mesa + VA-API) ==="

    dnf install -y \
        mesa-dri-drivers \
        mesa-vulkan-drivers \
        mesa-libGL \
        mesa-libEGL \
        mesa-libgbm \
        vulkan-loader \
        vulkan-tools \
        libva \
        linux-firmware \
        xorg-x11-drv-amdgpu \
        xorg-x11-drv-ati

    # Optional VA-API / VDPAU packages (names may vary across EL versions)
    dnf install -y mesa-va-drivers || true
    dnf install -y mesa-vdpau-drivers || true
    dnf install -y libva-utils || true

    echo "=== GPU: AMD installation complete ==="
    ;;

# =============================================================================
# Unknown variant — fail loud so the build doesn't silently skip GPU setup
# =============================================================================
*)
    echo "ERROR: Unknown VARIANT '${VARIANT}'. Expected '' (AMD default), 'amd', or 'nvidia'." >&2
    exit 1
    ;;

esac
