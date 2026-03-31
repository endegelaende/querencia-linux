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

# Hardware support for udev rules (Apple SuperDrive + Realtek USB Ethernet docks)
dnf install -y sg3_utils || true
dnf install -y usb_modeswitch || true

# iOS device support (iPhone/iPad mounting and file access)
dnf install -y ifuse || true
dnf install -y libimobiledevice || true
dnf install -y usbmuxd || true

# External monitor brightness/settings via DDC/CI protocol
dnf install -y ddcutil || true

# Power management (laptop power analysis and tuning)
dnf install -y powertop || true

# Fingerprint authentication (many laptops have fingerprint readers)
dnf install -y fprintd fprintd-pam || true
if rpm -q fprintd >/dev/null 2>&1; then
    authselect enable-feature with-fingerprint 2>/dev/null || true
fi
