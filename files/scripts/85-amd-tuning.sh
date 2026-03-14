#!/usr/bin/env bash
# Querencia Linux -- AMD GPU Kernel Optimizations
# Use /usr/lib/ paths (immutable, image-controlled) instead of /etc/
# so these configs are part of the OS image and not subject to /etc 3-way merge.
set -xeuo pipefail

# Ensure amdgpu is loaded early at boot
mkdir -p /usr/lib/modules-load.d
echo "amdgpu" > /usr/lib/modules-load.d/amdgpu.conf

# Power-Play Feature Mask: full GPU control (overclocking, fan curve)
mkdir -p /usr/lib/modprobe.d
echo 'options amdgpu ppfeaturemask=0xffffffff' > /usr/lib/modprobe.d/amdgpu.conf
