#!/usr/bin/env bash
# Querencia Linux -- ZRAM Swap (compressed RAM-based swap)
# Uses systemd-zram-generator for automatic ZRAM device at boot.
# Perfect for immutable systems: no swap partition/file needed.
set -xeuo pipefail

# Install zram-generator (creates /dev/zram0 swap automatically at boot)
# Hard dependency: ZRAM is essential for desktop responsiveness and is a test-checklist item.
# Package is called "zram-generator" on EL10 (not "systemd-zram-generator" like on Fedora).
dnf install -y zram-generator

# Configure ZRAM: 50% of RAM, zstd compression (best ratio/speed for desktop)
mkdir -p /usr/lib/systemd/zram-generator.conf.d
cat > /usr/lib/systemd/zram-generator.conf.d/querencia.conf <<'ZRAM'
# Querencia Linux ZRAM configuration
# Creates a compressed swap device in RAM at every boot.
# Helps prevent OOM with Firefox, Flatpak apps, etc.

[zram0]
# Use 50% of total RAM (e.g. 8 GB RAM → 4 GB ZRAM swap)
zram-size = ram / 2

# zstd: best compression ratio with fast decompression
compression-algorithm = zstd

# Swap priority (higher than any disk-based swap)
swap-priority = 100

# Filesystem type: swap
fs-type = swap
ZRAM
