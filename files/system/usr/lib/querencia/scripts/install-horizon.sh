#!/usr/bin/env bash
# =============================================================================
# Omnissa Horizon Client Installer for Querencia Linux
# Installs Horizon Client in a Distrobox with SAML/Workspace ONE support.
#
# Called by: ujust install-horizon
# Location:  /usr/lib/querencia/scripts/install-horizon.sh
#
# See OMNISSA.md for full problem analysis and architecture documentation.
# =============================================================================
set -euo pipefail

CONTAINER="horizon"
RPM_URL="https://download3.omnissa.com/software/CART26FQ4_LIN64_RPMPKG_2512.1/Omnissa-Horizon-Client-2512-8.17.1-22261155021.x64.rpm"
RPM_FILE="/tmp/omnissa-horizon-client.x86_64.rpm"
LOCAL_APPS="${HOME}/.local/share/applications"
LOCAL_BIN="${HOME}/.local/bin"

echo "=== Omnissa Horizon Client Installer ==="
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
echo ""
echo "Installing dependencies..."
distrobox enter "${CONTAINER}" -- bash -c \
    "sudo dnf install -y gtk3 libXtst libusbx alsa-lib pulseaudio-libs \
     mesa-libGL mesa-libEGL libxkbfile xdg-utils firefox dnf-plugins-core cpio"

# =============================================================================
# 3) Firefox langpacks
# =============================================================================
# The AlmaLinux container image strips /usr/lib64/firefox/browser/extensions/
# even though the langpack .xpi files are part of the firefox RPM. We extract
# the langpacks matching the current system locale so the container Firefox
# appears in the user's language.
echo ""
LANG_SHORT="${LANG%%_*}"  # e.g. "de" from "de_DE.utf8"
if [ -n "${LANG_SHORT}" ] && [ "${LANG_SHORT}" != "en" ]; then
    echo "Installing Firefox langpack for '${LANG_SHORT}'..."
    distrobox enter "${CONTAINER}" -- bash -c "
        XPI=/usr/lib64/firefox/browser/extensions/langpack-${LANG_SHORT}@firefox.mozilla.org.xpi
        if [ ! -f \"\${XPI}\" ]; then
            tmpdir=\$(mktemp -d) && cd /
            sudo dnf download firefox --destdir=\"\${tmpdir}\" 2>/dev/null
            sudo rpm2cpio \"\${tmpdir}\"/firefox-*.rpm \
                | sudo cpio -idm \"./usr/lib64/firefox/browser/extensions/langpack-${LANG_SHORT}@firefox.mozilla.org.xpi\" 2>/dev/null
            sudo rm -rf \"\${tmpdir}\"
        else
            echo 'Langpack already installed.'
        fi"
else
    echo "System language is English — skipping Firefox langpack."
fi

# =============================================================================
# 4) Local xdg-open wrapper inside the container
# =============================================================================
# Distrobox creates an xdg-open wrapper in ~/.local/bin/ that forwards all URLs
# to the host browser (Firefox). This breaks the vmware-view:// SAML callback
# because Firefox would receive the URL back instead of handing it to the
# Horizon Client.
#
# Fix: The wrapper now detects vmware-view:// URLs and routes them to the real
# /usr/bin/xdg-open (inside the container), which finds the registered
# x-scheme-handler and invokes the Horizon SAML handler. All other URLs
# continue to go to Firefox as before.
echo ""
echo "Configuring xdg-open wrapper for SAML handoff..."
distrobox enter "${CONTAINER}" -- bash -c \
    'mkdir -p ~/.local/bin && cat > ~/.local/bin/xdg-open <<'"'"'XDGEOF'"'"'
#!/usr/bin/env bash
# xdg-open wrapper for Distrobox "horizon" container.
# Routes vmware-view:// SAML callbacks to the real system xdg-open so they
# reach the registered scheme handler (horizon-client). Everything else goes
# to Firefox (distrobox host browser integration).
#
# Without this, vmware-view:// URLs loop back into Firefox because
# ~/.local/bin appears before /usr/bin in PATH.

URL="${1:-}"

if [[ "${URL}" == vmware-view://* ]]; then
    exec /usr/bin/xdg-open "${URL}"
fi

exec /usr/bin/firefox "$@"
XDGEOF
chmod +x ~/.local/bin/xdg-open'

# =============================================================================
# 5) Download and install Horizon Client
# =============================================================================
echo ""
echo "Downloading Horizon Client RPM..."
distrobox enter "${CONTAINER}" -- bash -c \
    "curl -fSL -o ${RPM_FILE} '${RPM_URL}'"

echo ""
echo "Installing Horizon Client..."
distrobox enter "${CONTAINER}" -- bash -c \
    "sudo dnf install -y ${RPM_FILE} && rm -f ${RPM_FILE}"

# =============================================================================
# 6) Export desktop entry to host
# =============================================================================
echo ""
echo "Exporting Horizon Client to host desktop..."
distrobox enter "${CONTAINER}" -- bash -c \
    "distrobox-export --app horizon-client 2>/dev/null || true"

# =============================================================================
# 7) SAML/Workspace ONE handler on host
# =============================================================================
# After SAML authentication the Horizon server redirects Firefox to
# vmware-view://...?SAMLart=<token>. Firefox delegates to xdg-open, which
# finds horizon-vmware-view-handler.desktop and invokes this script.
#
# Key points:
#   - The script detects whether it is running inside the Distrobox container
#     (/run/.containerenv exists) or on the bare host.
#   - Inside the container: call horizon-client directly.
#   - On the host: use distrobox-enter to reach horizon-client.
#   - horizon-client MUST be started with nohup + background + redirected
#     streams. Without this it receives SIGPIPE/SIGHUP when the calling
#     process chain (xdg-open → handler) exits, and dies immediately
#     (producing a 0-byte log file).
echo ""
echo "Setting up SAML authentication handler..."
mkdir -p "${LOCAL_BIN}"
mkdir -p "${LOCAL_APPS}"

cat > "${LOCAL_BIN}/horizon-vmware-view-handler" <<'HANDLER'
#!/usr/bin/env bash
CONTAINER="horizon"
URL="${1:-}"

if [ -z "${URL}" ]; then
    exit 0
fi

if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
    # We are inside the Distrobox container (Firefox was started via
    # distrobox-enter, so the whole process tree is in the container
    # namespace). Call horizon-client directly.
    #
    # nohup + background + stream redirection prevents horizon-client from
    # being killed by SIGPIPE/SIGHUP when the parent process chain exits.
    nohup horizon-client "${URL}" </dev/null >/dev/null 2>&1 &
else
    # We are on the host — enter the container to reach horizon-client.
    exec /usr/bin/distrobox-enter -n "${CONTAINER}" -- horizon-client "${URL}"
fi
HANDLER
chmod +x "${LOCAL_BIN}/horizon-vmware-view-handler"

# =============================================================================
# 8) Desktop entry — main launcher with PATH override for SAML
# =============================================================================
# Override the distrobox-exported .desktop file so Horizon starts with the local
# xdg-open wrapper (PATH prepend) for reliable SAML browser handoff.
DESKTOP_FILE="${LOCAL_APPS}/horizon-horizon-client.desktop"
if [ -f "${DESKTOP_FILE}" ]; then
    cat > "${DESKTOP_FILE}" <<DESKTOP
[Desktop Entry]
Encoding=UTF-8
Type=Application
Icon=/run/host/home/${USER}/.local/share/icons/horizon-client.png
Exec=/usr/bin/distrobox-enter -n ${CONTAINER} -- bash -lc 'export PATH="\$HOME/.local/bin:\$PATH"; exec horizon-client %u'
Terminal=false
Categories=Application;Network;
Name=Omnissa Horizon Client
Comment=Omnissa Horizon VDI Client
MimeType=x-scheme-handler/vmware-view;
StartupWMClass=horizon-client
DESKTOP
fi

# =============================================================================
# 9) Desktop entry — vmware-view:// URL handler
# =============================================================================
cat > "${LOCAL_APPS}/horizon-vmware-view-handler.desktop" <<URLHANDLER
[Desktop Entry]
Type=Application
Name=Horizon SAML Handler
NoDisplay=true
Exec=${LOCAL_BIN}/horizon-vmware-view-handler %u
MimeType=x-scheme-handler/vmware-view;
URLHANDLER

# Register as default handler for vmware-view:// URLs
xdg-mime default horizon-vmware-view-handler.desktop x-scheme-handler/vmware-view 2>/dev/null || true
update-desktop-database "${LOCAL_APPS}" 2>/dev/null || true

# =============================================================================
# Done
# =============================================================================
echo ""
echo "Done! Omnissa Horizon Client installed with SAML/Workspace ONE support."
echo ""
echo "  Start:     Click 'Omnissa Horizon Client' in your application menu"
echo "  Uninstall: ujust remove-horizon"
echo ""
