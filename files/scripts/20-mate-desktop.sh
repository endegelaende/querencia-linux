#!/usr/bin/env bash
# Querencia Linux -- MATE Desktop Environment
# From winonaoctober/MateDesktop-EL10 COPR (provides MATE + Xorg + LightDM for EL10)
#
# NOTE: We install packages explicitly instead of using dnf groupinstall because
# our winonaoctober COPR fork does not ship a comps.xml group definition.
# The package list below covers the full MATE Desktop environment, filtered
# to exclude bloat apps (they belong in Flatpak on an immutable system).
set -xeuo pipefail

# ---- Xorg / Display Server ---------------------------------------------------
dnf install -y \
    xorg-x11-server-Xorg \
    xorg-x11-xauth \
    xorg-x11-xinit \
    xorg-x11-drv-libinput \
    xorg-x11-drv-evdev \
    xorg-x11-drv-wacom \
    xmodmap \
    xrdb \
    glx-utils

# ---- MATE Desktop Core -------------------------------------------------------
dnf install -y \
    mate-desktop \
    mate-desktop-libs \
    mate-desktop-configs \
    mate-session-manager \
    mate-settings-daemon \
    mate-panel \
    mate-panel-libs \
    marco \
    caja \
    mate-menus \
    mate-menus-libs \
    mate-menus-preferences-category-menu \
    mate-control-center \
    mate-control-center-filesystem \
    mate-notification-daemon \
    mate-polkit \
    mate-icon-theme \
    mate-themes \
    mate-backgrounds \
    mate-common \
    libmatekbd \
    libmatemixer \
    libmateweather \
    libmateweather-data

# ---- MATE Applications (core tools we keep) ----------------------------------
dnf install -y \
    mate-terminal \
    mate-calc \
    mate-screenshot \
    mate-utils \
    mate-utils-common \
    mate-dictionary \
    mate-disk-image-mounter \
    mate-disk-usage-analyzer \
    mate-search-tool \
    mate-system-log \
    mate-system-monitor \
    mate-media \
    mate-power-manager \
    mate-screensaver \
    engrampa \
    eom \
    atril \
    atril-caja \
    atril-thumbnailer

# Optional MATE apps (may not be built yet in COPR — install individually)
dnf install -y pluma || true
dnf install -y mozo || true
dnf install -y mate-applets || true
dnf install -y mate-sensors-applet || true
dnf install -y mate-user-admin || true

# ---- Caja Extensions (optional — not all may be built yet) -------------------
dnf install -y caja-actions || true
dnf install -y caja-image-converter || true
dnf install -y caja-open-terminal || true
dnf install -y caja-sendto || true
dnf install -y caja-wallpaper || true
dnf install -y caja-xattr-tags || true

# ---- LightDM + Greeters ------------------------------------------------------
dnf install -y \
    lightdm \
    lightdm-gtk \
    lightdm-gtk-greeter

# ---- Desktop Integration -----------------------------------------------------
dnf install -y \
    gnome-themes-extra \
    gtk2-engines \
    gvfs-fuse \
    gvfs-gphoto2 \
    gvfs-mtp \
    gvfs-smb \
    libsecret \
    usermode-gtk \
    xdg-user-dirs-gtk \
    lm_sensors

# ---- Packages we explicitly do NOT install (Flatpak / not needed) -------------
# thunderbird, filezilla, brasero, celluloid, simple-scan, xreader, xed
# gnome-software, gparted, dconf-editor, gucharmap, seahorse, yelp
# xscreensaver-*, blivet-gui, system-config-language, lightdm-settings
# dnfdragora, libyui-*, mate-user-guide, mate-menu, mintmenu
# abrt-desktop, initial-setup-gui

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

# Note: No need to mkdir /var/lib/lightdm-data etc. here — cleanup.sh wipes
# /var entirely. The tmpfiles.d config above + greeter-setup-script in
# lightdm.conf handle runtime directory creation on every boot.

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
