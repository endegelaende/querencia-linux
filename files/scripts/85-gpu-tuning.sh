#!/usr/bin/env bash
# Querencia Linux -- GPU Kernel Optimizations (AMD / NVIDIA)
# Configures kernel modules, modprobe options, and boot arguments
# based on the VARIANT environment variable set in the Dockerfile.
#
# VARIANT=""       or unset → AMD (default)
# VARIANT="nvidia"         → NVIDIA
#
# Uses /usr/lib/ paths (immutable, image-controlled) instead of /etc/
# so these configs are part of the OS image and not subject to /etc 3-way merge.
set -xeuo pipefail

# Default to AMD if VARIANT is empty or unset
VARIANT="${VARIANT:-}"

case "${VARIANT}" in

  nvidia)
    echo ":: Configuring NVIDIA GPU support"

    # ── Blacklist nouveau (open-source driver conflicts with proprietary NVIDIA) ──
    mkdir -p /usr/lib/modprobe.d
    cat > /usr/lib/modprobe.d/nvidia.conf <<'EOF'
# Querencia Linux: Blacklist nouveau to prevent conflicts with NVIDIA drivers
blacklist nouveau
options nouveau modeset=0

# Enable kernel modesetting for the NVIDIA DRM driver
# Required for Wayland, smooth VT switching, and proper suspend/resume
options nvidia-drm modeset=1
EOF

    # ── Load nvidia_drm early at boot ──
    mkdir -p /usr/lib/modules-load.d
    cat > /usr/lib/modules-load.d/nvidia.conf <<'EOF'
# Querencia Linux: Load NVIDIA DRM module early for KMS
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
EOF

    # ── bootc kernel command line arguments ──
    # bootc reads /usr/lib/bootc/kargs.d/*.toml and applies them to the BLS entry.
    # This ensures nouveau is blacklisted at the earliest possible stage (initramfs)
    # and nvidia-drm modesetting is enabled from the kernel command line.
    mkdir -p /usr/lib/bootc/kargs.d
    cat > /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

    echo ":: NVIDIA GPU configuration complete"
    ;;

  ""|amd)
    echo ":: Configuring AMD GPU support (default)"

    # ── Ensure amdgpu is loaded early at boot ──
    mkdir -p /usr/lib/modules-load.d
    echo "amdgpu" > /usr/lib/modules-load.d/amdgpu.conf

    # ── Power-Play Feature Mask: full GPU control (overclocking, fan curve) ──
    # 0xffffffff enables all power management features including:
    #   - GPU overclocking / undervolting
    #   - Fan curve control
    #   - Power limit adjustment
    # This is a power-user setting appropriate for a personal desktop image.
    mkdir -p /usr/lib/modprobe.d
    echo 'options amdgpu ppfeaturemask=0xffffffff' > /usr/lib/modprobe.d/amdgpu.conf

    echo ":: AMD GPU configuration complete"
    ;;

  *)
    echo "ERROR: Unknown VARIANT '${VARIANT}'. Expected '' (AMD default), 'amd', or 'nvidia'." >&2
    exit 1
    ;;

esac
