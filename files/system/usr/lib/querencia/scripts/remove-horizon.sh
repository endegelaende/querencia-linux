#!/usr/bin/env bash
# =============================================================================
# Omnissa Horizon Client Uninstaller for Querencia Linux
# Removes Horizon Client, its Distrobox, and all desktop integration.
# Called by: ujust remove-horizon
#
# See OMNISSA.md for full problem analysis and architecture documentation.
# =============================================================================
set -euo pipefail

CONTAINER="horizon"
LOCAL_APPS="${HOME}/.local/share/applications"
LOCAL_BIN="${HOME}/.local/bin"

echo "=== Omnissa Horizon Client Uninstaller ==="
echo ""

# --- Remove desktop integration from inside the container --------------------
if podman container exists "${CONTAINER}" 2>/dev/null; then
    echo "Removing Horizon Client export from container..."
    distrobox enter "${CONTAINER}" -- bash -c \
        "distrobox-export --app horizon-client --delete 2>/dev/null || true; rm -f ~/.local/bin/xdg-open" \
        2>/dev/null || true
else
    echo "Distrobox '${CONTAINER}' does not exist — skipping container cleanup."
    # The xdg-open wrapper lives in the shared home directory; clean it up
    # even if the container is already gone.
    rm -f "${LOCAL_BIN}/xdg-open"
fi

# --- Remove host-side files --------------------------------------------------
echo "Removing desktop entries and handlers..."
rm -f "${LOCAL_APPS}/horizon-horizon-client.desktop"
rm -f "${LOCAL_APPS}/horizon-horizon-client-next.desktop"
rm -f "${LOCAL_APPS}/horizon-vmware-view-handler.desktop"
rm -f "${LOCAL_APPS}/vmware-view-handler.desktop"
rm -f "${LOCAL_BIN}/horizon-vmware-view-handler"
rm -f "${LOCAL_BIN}/horizon-launcher"
update-desktop-database "${LOCAL_APPS}" 2>/dev/null || true

# --- Remove vmware-view:// from mimeapps.list --------------------------------
MIMEAPPS="${HOME}/.config/mimeapps.list"
if [ -f "${MIMEAPPS}" ]; then
    if grep -q "vmware-view" "${MIMEAPPS}" 2>/dev/null; then
        sed -i '/x-scheme-handler\/vmware-view/d' "${MIMEAPPS}"
        echo "Removed vmware-view:// from mimeapps.list."
    fi
fi

# --- Remove the Distrobox container -----------------------------------------
if podman container exists "${CONTAINER}" 2>/dev/null; then
    echo "Removing distrobox '${CONTAINER}'..."
    distrobox rm --force "${CONTAINER}" 2>/dev/null || true
else
    echo "No container to remove."
fi

echo ""
echo "Done. Omnissa Horizon Client has been removed."
