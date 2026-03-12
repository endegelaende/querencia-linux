#!/usr/bin/env bash
# Querencia Linux -- System Tools & Utilities
set -xeuo pipefail

dnf install -y \
    firefox \
    gnome-disk-utility \
    gnome-keyring \
    xdg-utils \
    xdg-user-dirs \
    xdg-user-dirs-gtk \
    bash-completion \
    vim-enhanced \
    htop \
    wget \
    curl \
    git \
    almalinux-backgrounds

# Xorg drivers for VM support (QXL/SPICE, VESA fallback)
dnf install -y xorg-x11-drv-qxl || true
dnf install -y xorg-x11-drv-vesa || true
dnf install -y xorg-x11-drv-fbdev || true
dnf install -y spice-vdagent || true

# Optional tools (may not be in all repos)
dnf install -y fastfetch || true
dnf install -y just || true
