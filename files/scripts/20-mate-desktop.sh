#!/usr/bin/env bash
# Querencia Linux -- MATE Desktop Environment
# From winonaoctober/MateDesktop-EL10 COPR (provides MATE + Xorg + LightDM for EL10)
set -xeuo pipefail

# Install the full MATE desktop group (includes Xorg, LightDM, Compiz)
dnf groupinstall -y "MATE-Desktop"

# ---- Remove dnfdragora + libyui chain (useless on immutable/atomic system) ----
# dnfdragora is a graphical DNF frontend — on a bootc image the rootfs is read-only,
# so dnf install does nothing. It also pulls in libyui, python-manatools, etc.
# Remove it and its entire dependency chain if they got pulled in by the group.
dnf remove -y --noautoremove dnfdragora dnfdragora-updater python3-dnfdragora python3-manatools \
    libyui libyui-mga libyui-gtk libyui-mga-gtk libyui-mga-ncurses \
    2>/dev/null || true

# ---- Remove bloat apps pulled in by the MATE-Desktop group -------------------
# On an atomic/immutable system, GUI apps belong in Flatpak, not the base image.
# Only Firefox stays (needs system integration). MATE core tools (atril, pluma,
# engrampa, eom, mate-calc, mate-terminal, mate-screenshot, mozo) are kept.
dnf remove -y --noautoremove \
    thunderbird \
    filezilla libfilezilla \
    brasero brasero-libs \
    celluloid \
    simple-scan \
    xreader xreader-libs xreader-data \
    gnome-software gnome-software-fedora-langpacks \
    gnome-abrt abrt abrt-addon-ccpp abrt-addon-kerneloops abrt-addon-pstoreoops \
        abrt-addon-vmcore abrt-addon-xorg abrt-dbus abrt-desktop abrt-gui \
        abrt-gui-libs abrt-libs python3-abrt python3-abrt-addon \
    blivet-gui blivet-gui-runtime \
    gparted \
    dconf-editor \
    gucharmap gucharmap-libs \
    seahorse \
    xscreensaver-base xscreensaver-extras xscreensaver-extras-gss \
        xscreensaver-gl-base xscreensaver-gl-extras xscreensaver-gl-extras-gss \
    yelp yelp-libs yelp-tools yelp-xsl \
    xed \
    system-config-language \
    lightdm-settings \
    mate-user-guide \
    mate-menu \
    2>/dev/null || true

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
# Include common languages so the Anaconda installer language choice works
dnf install -y \
    glibc-langpack-en \
    glibc-langpack-de \
    glibc-langpack-fr \
    glibc-langpack-es \
    glibc-langpack-it \
    glibc-langpack-pt \
    glibc-langpack-nl \
    glibc-langpack-pl \
    glibc-langpack-ru \
    glibc-langpack-ja \
    glibc-langpack-zh \
    glibc-langpack-ko

# Neutral default locale for the image build.
# The Anaconda installer overwrites /etc/locale.conf and /etc/vconsole.conf
# with the user's language and keyboard choice — do NOT hardcode de_DE or
# any specific keyboard layout here.
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ---- LightDM runtime directories (needed on bootc/ostree where /var is empty) ----
# Create tmpfiles.d config so systemd-tmpfiles recreates them every boot.
# Use /usr/lib/tmpfiles.d/ (immutable, survives cleanup.sh which wipes /var and /etc changes).
# Use a unique filename to avoid being overwritten by the lightdm package's own lightdm.conf
# (which only creates /run/lightdm).
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/lightdm-querencia.conf <<'TMPFILES'
# Querencia Linux: LightDM directories needed at runtime (bootc/ostree clears /var)
d /var/lib/lightdm 0750 lightdm lightdm -
d /var/lib/lightdm-data 0755 lightdm lightdm -
d /var/cache/lightdm 0755 lightdm lightdm -
d /var/log/lightdm 0750 root lightdm -
TMPFILES

# Remove slick-greeter override (crashes with GPU passthrough and some VMs).
# The 90-slick-greeter.conf from the slick-greeter package overrides our
# lightdm.conf setting of greeter-session=lightdm-gtk-greeter.
rm -f /usr/share/lightdm/lightdm.conf.d/90-slick-greeter.conf

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
