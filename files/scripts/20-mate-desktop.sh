#!/usr/bin/env bash
# Querencia Linux -- MATE Desktop Environment
# From skip77/MateDesktop-EL10 COPR (provides MATE + Xorg + LightDM for EL10)
set -xeuo pipefail

# Install the full MATE desktop group (includes Xorg, LightDM, Compiz)
dnf groupinstall -y "MATE-Desktop"

# Additional MATE packages (may not all be in the group)
dnf install -y mate-applets || true
dnf install -y mate-media || true
dnf install -y mate-power-manager || true
dnf install -y mate-screensaver || true
dnf install -y mate-system-monitor || true
dnf install -y mate-terminal || true
dnf install -y mate-utils || true
dnf install -y pluma || true
dnf install -y caja-extensions || true
dnf install -y engrampa || true
dnf install -y eom || true
dnf install -y atril || true

# Fonts
dnf install -y \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-sans-mono-fonts \
    google-noto-emoji-fonts \
    liberation-fonts \
    dejavu-sans-fonts

# Locale support (UTF-8 -- required for ostree/bootc)
dnf install -y \
    glibc-langpack-en \
    glibc-langpack-de

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Enable LightDM and graphical target
systemctl enable lightdm
systemctl set-default graphical.target
