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

# Archive format backends (needed by engrampa for full format support)
dnf install -y p7zip p7zip-plugins || true
dnf install -y unrar || true
dnf install -y bzip2 || true
dnf install -y xz || true

# Thumbnail support (Caja file manager previews)
dnf install -y ffmpegthumbnailer || true
dnf install -y evince-thumbnailer || true
dnf install -y gdk-pixbuf2 || true

# MATE PolicyKit agent (graphical password prompts for admin actions)
# May already be pulled in by MATE-Desktop group, install explicitly to be sure
dnf install -y mate-polkit || true
