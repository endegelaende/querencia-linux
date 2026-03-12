#!/usr/bin/env bash
# Querencia Linux -- AMD GPU Kernel Optimizations
set -xeuo pipefail

# Ensure amdgpu is loaded early at boot
echo "amdgpu" > /etc/modules-load.d/amdgpu.conf

# Power-Play Feature Mask: full GPU control (overclocking, fan curve)
echo 'options amdgpu ppfeaturemask=0xffffffff' > /etc/modprobe.d/amdgpu.conf
