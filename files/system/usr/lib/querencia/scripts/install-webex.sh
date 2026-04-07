#!/usr/bin/env bash
# =============================================================================
# Cisco Webex Installer for Querencia Linux
# Installs Webex in a Distrobox container with full audio/video support.
#
# Called by: ujust install-webex
# Location:  /usr/lib/querencia/scripts/install-webex.sh
# =============================================================================
set -euo pipefail

CONTAINER="webex"
RPM_URL="https://binaries.webex.com/WebexDesktop-CentOS-Official-Package/Webex.rpm"
RPM_FILE="/tmp/webex.x86_64.rpm"
LOCAL_APPS="${HOME}/.local/share/applications"
LOCAL_BIN="${HOME}/.local/bin"

echo "=== Cisco Webex Installer ==="
echo ""

# =============================================================================
# 1) Create Distrobox
# =============================================================================
if ! podman container exists "${CONTAINER}" 2>/dev/null; then
    echo "Creating distrobox '${CONTAINER}'..."
    distrobox create --name "${CONTAINER}" --image docker.io/library/almalinux:10 --yes
else
    echo "Distrobox '${CONTAINER}' already exists."
fi

# =============================================================================
# 2) Install dependencies inside the container
# =============================================================================
# Dependencies from the RPM spec plus extras for audio/video/screen sharing.
echo ""
echo "Installing dependencies..."
distrobox enter "${CONTAINER}" -- bash -c \
    "sudo dnf install -y \
     alsa-lib \
     at-spi2-core \
     atk \
     gtk3 \
     libXScrnSaver \
     libXcomposite \
     libXcursor \
     libXrandr \
     libglvnd-opengl \
     libnotify \
     libsecret \
     libwayland-client \
     libxkbcommon-x11 \
     lshw \
     mesa-libGL \
     mesa-libgbm \
     nss \
     pango \
     pcre2-utf16 \
     pulseaudio-libs \
     systemd-libs \
     upower \
     xcb-util-image \
     xcb-util-keysyms \
     xcb-util-renderutil \
     xcb-util-wm \
     pipewire-pulseaudio \
     xdg-utils"

# =============================================================================
# 3) Download and install Webex
# =============================================================================
echo ""
echo "Downloading Webex RPM..."
distrobox enter "${CONTAINER}" -- bash -c \
    "curl -fSL -o ${RPM_FILE} '${RPM_URL}'"

echo ""
echo "Installing Webex..."
# Use --nodeps because distrobox satisfies runtime deps from the host and
# the RPM's post-install scriptlet writes to /usr/share/applications and
# /etc/udev which we handle ourselves below.
distrobox enter "${CONTAINER}" -- bash -c \
    "sudo rpm -ivh --nodeps ${RPM_FILE} && rm -f ${RPM_FILE}"

# =============================================================================
# 4) Export desktop entry to host
# =============================================================================
echo ""
echo "Exporting Webex to host desktop..."
distrobox enter "${CONTAINER}" -- bash -c \
    "distrobox-export --app CiscoCollabHost 2>/dev/null || true"

# =============================================================================
# 5) Create/override desktop entry with proper Exec line
# =============================================================================
# The distrobox-export may create a .desktop file, but we need to ensure
# proper naming, icon path, and URL scheme handling.
echo ""
echo "Configuring desktop integration..."
mkdir -p "${LOCAL_APPS}"

DESKTOP_FILE="${LOCAL_APPS}/webex.desktop"
cat > "${DESKTOP_FILE}" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Cisco Webex
Comment=Webex — Meetings, Messaging, Calling
Icon=/run/host/opt/Webex/bin/sparklogosmall.png
Exec=/usr/bin/distrobox-enter -n ${CONTAINER} -- /opt/Webex/bin/CiscoCollabHost %U
Terminal=false
Categories=Network;InstantMessaging;VideoConference;
MimeType=x-scheme-handler/webexteams;x-scheme-handler/ciscospark;x-scheme-handler/webex;
StartupWMClass=CiscoCollabHost
DESKTOP

# =============================================================================
# 6) URL scheme handlers (webex://, webexteams://, ciscospark://)
# =============================================================================
# Webex uses three URL schemes for deep linking (meeting joins, chat links).
echo ""
echo "Setting up URL scheme handlers..."
mkdir -p "${LOCAL_BIN}"

cat > "${LOCAL_BIN}/webex-url-handler" <<'HANDLER'
#!/usr/bin/env bash
CONTAINER="webex"
URL="${1:-}"

if [ -z "${URL}" ]; then
    exit 0
fi

if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
    # Inside the Distrobox container — call Webex directly.
    nohup /opt/Webex/bin/CiscoCollabHost "${URL}" </dev/null >/dev/null 2>&1 &
else
    # On the host — enter the container to reach Webex.
    exec /usr/bin/distrobox-enter -n "${CONTAINER}" -- /opt/Webex/bin/CiscoCollabHost "${URL}"
fi
HANDLER
chmod +x "${LOCAL_BIN}/webex-url-handler"

cat > "${LOCAL_APPS}/webex-url-handler.desktop" <<URLHANDLER
[Desktop Entry]
Type=Application
Name=Webex URL Handler
NoDisplay=true
Exec=${LOCAL_BIN}/webex-url-handler %u
MimeType=x-scheme-handler/webexteams;x-scheme-handler/ciscospark;x-scheme-handler/webex;
URLHANDLER

# Register as default handler for all three URL schemes
xdg-mime default webex-url-handler.desktop x-scheme-handler/webex 2>/dev/null || true
xdg-mime default webex-url-handler.desktop x-scheme-handler/webexteams 2>/dev/null || true
xdg-mime default webex-url-handler.desktop x-scheme-handler/ciscospark 2>/dev/null || true
update-desktop-database "${LOCAL_APPS}" 2>/dev/null || true

# =============================================================================
# Done
# =============================================================================
echo ""
echo "Done! Cisco Webex installed."
echo ""
echo "  Start:     Click 'Cisco Webex' in your application menu"
echo "  Uninstall: ujust remove-webex"
echo ""
