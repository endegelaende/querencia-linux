#!/usr/bin/env bash
# Querencia Linux -- MATE Desktop Environment
# From winonaoctober/MateDesktop-EL10 COPR (provides MATE + Xorg + LightDM for EL10)
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

# LightDM greeter: slick-greeter is primary, gtk-greeter as fallback
dnf install -y lightdm-gtk-greeter || true

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

# ---- LightDM runtime directories (needed on bootc/ostree where /var is empty) ----
# Create tmpfiles.d config so systemd-tmpfiles recreates them every boot.
# Use /usr/lib/tmpfiles.d/ (immutable, survives cleanup.sh which wipes /var and /etc changes).
# Use a unique filename to avoid being overwritten by the lightdm package's own lightdm.conf
# (which only creates /run/lightdm).
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/lightdm-querencia.conf <<'TMPFILES'
# Querencia Linux: LightDM directories needed at runtime (bootc/ostree clears /var)
d /var/lib/lightdm-data 0755 lightdm lightdm -
d /var/cache/lightdm 0755 lightdm lightdm -
d /var/log/lightdm 0750 root lightdm -
TMPFILES

# Also create them now for the build layer
mkdir -p /var/lib/lightdm-data
mkdir -p /var/cache/lightdm
mkdir -p /var/log/lightdm
chown lightdm:lightdm /var/lib/lightdm-data 2>/dev/null || true
chown lightdm:lightdm /var/cache/lightdm 2>/dev/null || true
chown root:lightdm /var/log/lightdm 2>/dev/null || true
chmod 0750 /var/log/lightdm 2>/dev/null || true

# Ensure MATE session file exists for LightDM
if [ ! -f /usr/share/xsessions/mate.desktop ]; then
    mkdir -p /usr/share/xsessions
    cat > /usr/share/xsessions/mate.desktop <<'XSESSION'
[Desktop Entry]
Name=MATE
Comment=This session logs you into MATE
Exec=mate-session
TryExec=mate-session
Type=Application
DesktopNames=MATE
XSESSION
fi

# Enable LightDM and graphical target
systemctl enable lightdm
systemctl set-default graphical.target
