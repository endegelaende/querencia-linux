#!/usr/bin/env bash
# Querencia Linux -- System Tools & Utilities
set -xeuo pipefail

dnf install -y \
    firefox \
    gnome-disk-utility \
    gnome-keyring \
    xdg-utils \
    xdg-user-dirs \
    bash-completion \
    vim-enhanced \
    nano \
    htop \
    wget \
    curl \
    git \
    jq \
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

# Thumbnail support (Caja file manager previews)
dnf install -y ffmpegthumbnailer || true

# SELinux troubleshooter (graphical notifications for SELinux denials)
# Essential on atomic systems where users can't easily debug AVC denials
dnf install -y setroubleshoot-server || true
dnf install -y setroubleshoot-plugins || true

# Night mode / blue light filter (needs direct X11 gamma access, can't run in Flatpak sandbox)
dnf install -y redshift || true
dnf install -y redshift-gtk || true
