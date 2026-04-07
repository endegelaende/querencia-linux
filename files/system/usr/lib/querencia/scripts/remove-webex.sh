#!/usr/bin/env bash
# =============================================================================
# Cisco Webex Uninstaller for Querencia Linux
# Removes Webex, its Distrobox, and all desktop integration.
# Called by: ujust remove-webex
#
# Location: /usr/lib/querencia/scripts/remove-webex.sh
# =============================================================================
set -euo pipefail

CONTAINER="webex"
LOCAL_APPS="${HOME}/.local/share/applications"
LOCAL_BIN="${HOME}/.local/bin"

echo "=== Cisco Webex Uninstaller ==="
echo ""

# --- Remove desktop integration from inside the container --------------------
if podman container exists "${CONTAINER}" 2>/dev/null; then
    echo "Removing Webex export from container..."
    distrobox enter "${CONTAINER}" -- bash -c \
        "distrobox-export --app CiscoCollabHost --delete 2>/dev/null || true" \
        2>/dev/null || true
else
    echo "Distrobox '${CONTAINER}' does not exist — skipping container cleanup."
fi

# --- Remove host-side files --------------------------------------------------
echo "Removing desktop entries and handlers..."
rm -f "${LOCAL_APPS}/webex.desktop"
rm -f "${LOCAL_APPS}/webex-url-handler.desktop"
rm -f "${LOCAL_APPS}/webex-CiscoCollabHost.desktop"
rm -f "${LOCAL_BIN}/webex-url-handler"
update-desktop-database "${LOCAL_APPS}" 2>/dev/null || true

# --- Remove URL schemes from mimeapps.list -----------------------------------
MIMEAPPS="${HOME}/.config/mimeapps.list"
if [ -f "${MIMEAPPS}" ]; then
    if grep -q "webex" "${MIMEAPPS}" 2>/dev/null; then
        sed -i '/x-scheme-handler\/webex=/d' "${MIMEAPPS}"
        sed -i '/x-scheme-handler\/webexteams=/d' "${MIMEAPPS}"
        sed -i '/x-scheme-handler\/ciscospark=/d' "${MIMEAPPS}"
        echo "Removed webex:// URL schemes from mimeapps.list."
    fi
fi

# --- Remove Webex user data ---------------------------------------------------
WEBEX_DATA="${HOME}/.local/share/Webex"
WEBEX_LAUNCHER="${HOME}/.local/share/WebexLauncher"
if [ -d "${WEBEX_DATA}" ]; then
    echo "Removing Webex user data..."
    rm -rf "${WEBEX_DATA}"
fi
if [ -d "${WEBEX_LAUNCHER}" ]; then
    rm -rf "${WEBEX_LAUNCHER}"
fi

# --- Remove the Distrobox container ------------------------------------------
if podman container exists "${CONTAINER}" 2>/dev/null; then
    echo "Removing distrobox '${CONTAINER}'..."
    distrobox rm --force "${CONTAINER}" 2>/dev/null || true
else
    echo "No container to remove."
fi

echo ""
echo "Done. Cisco Webex has been removed."
