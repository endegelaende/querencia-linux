#!/usr/bin/env bash
# Querencia Linux -- AMD GPU (RX 6600 / RDNA 2)
# The amdgpu kernel driver is built into the kernel.
# We only need userspace: Mesa (OpenGL/Vulkan) + VA-API (hardware video).
set -xeuo pipefail

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
