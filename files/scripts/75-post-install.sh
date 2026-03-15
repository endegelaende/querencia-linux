#!/usr/bin/env bash
# Querencia Linux -- Post-Install Configuration
# Sets up system-wide defaults that become active on first boot.
set -xeuo pipefail

# ---- Querencia Welcome App (permissions) ------------------------------------
# Files are copied from system_files/ by build.sh but may lose +x in transit.
chmod +x /usr/bin/querencia-welcome 2>/dev/null || true
chmod +x /usr/bin/querencia-welcome-launcher 2>/dev/null || true
chmod +x /usr/lib/querencia/welcome/querencia-welcome.py 2>/dev/null || true

# ---- XDG User Directories (English defaults) --------------------------------
mkdir -p /etc/xdg
cat > /etc/xdg/user-dirs.defaults <<'EOF'
DESKTOP=Desktop
DOWNLOAD=Downloads
TEMPLATES=Templates
PUBLICSHARE=Public
DOCUMENTS=Documents
MUSIC=Music
PICTURES=Pictures
VIDEOS=Videos
EOF

# Flatpak overrides are applied per-user in the first-boot script below,
# because /var/lib/flatpak/ gets wiped during the container build cleanup.

# ---- Systemd Presets ---------------------------------------------------------
mkdir -p /usr/lib/systemd/system-preset
cat > /usr/lib/systemd/system-preset/50-querencia-linux.preset <<'EOF'
enable lightdm.service
enable NetworkManager.service
enable bluetooth.service
enable fstrim.timer
enable cups.socket
enable firewalld.service
EOF

# Mask rpm-ostree-countme (exists on bootc systems but fails without rpm-ostree)
systemctl mask rpm-ostree-countme.service rpm-ostree-countme.timer

# ---- ujust Shortcut ----------------------------------------------------------
JUSTFILE_SRC="/usr/share/justfiles/custom.just"
JUSTFILE_LINK="/usr/bin/ujust"

if [ -f "${JUSTFILE_SRC}" ]; then
    cat > "${JUSTFILE_LINK}" <<'UJUST'
#!/usr/bin/env bash
exec just --justfile /usr/share/justfiles/custom.just "$@"
UJUST
    chmod +x "${JUSTFILE_LINK}"
fi

# ---- First-Boot Service (per user) ------------------------------------------
mkdir -p /usr/lib/systemd/user
cat > /usr/lib/systemd/user/querencia-first-boot-setup.service <<'EOF'
[Unit]
Description=Querencia Linux -- First-boot setup for new user
ConditionPathExists=!%h/.config/querencia-setup-done
After=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/querencia-first-boot
ExecStartPost=/usr/bin/touch %h/.config/querencia-setup-done

[Install]
WantedBy=default.target
EOF

mkdir -p /usr/libexec
cat > /usr/libexec/querencia-first-boot <<'FIRSTBOOT'
#!/usr/bin/env bash
set -euo pipefail

# Create XDG user directories
if command -v xdg-user-dirs-update &>/dev/null; then
    xdg-user-dirs-update
fi

# Set up default Caja bookmarks (sidebar shortcuts)
BOOKMARKS_FILE="${HOME}/.config/gtk-3.0/bookmarks"
if [ ! -f "${BOOKMARKS_FILE}" ]; then
    mkdir -p "${HOME}/.config/gtk-3.0"
    cat > "${BOOKMARKS_FILE}" <<BOOKMARKS
file://${HOME}/Documents Documents
file://${HOME}/Downloads Downloads
file://${HOME}/Pictures Pictures
file://${HOME}/Music Music
file://${HOME}/Videos Videos
BOOKMARKS
fi

# Apply Flatpak overrides (GPU access + BlueMenta theming)
if command -v flatpak &>/dev/null; then
    flatpak override --user \
        --device=dri \
        --filesystem=xdg-config/gtk-3.0:ro \
        --filesystem=xdg-config/gtk-4.0:ro \
        --filesystem=/usr/share/themes:ro \
        --filesystem=/usr/share/icons:ro \
        --env=GTK_THEME=BlueMenta \
        --env=XCURSOR_THEME=Adwaita \
        --env=XCURSOR_SIZE=24 \
        2>/dev/null || true
fi

# Add Flathub remote for user and install Warehouse (Flatpak store)
if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists --user flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    flatpak install --user --noninteractive flathub \
        io.github.flattool.Warehouse 2>/dev/null || true
fi

# Create micromamba 'base' environment (user-space package manager)
if command -v micromamba &>/dev/null; then
    export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
    eval "$(micromamba shell hook --shell bash)"
    if [ ! -d "${MAMBA_ROOT_PREFIX}/envs/base" ]; then
        micromamba create -n base -c conda-forge -y 2>/dev/null || true
    fi
fi

mkdir -p "${HOME}/.config"

# Launch the Welcome Center (GUI first-boot experience)
# Falls back to a simple notification if the welcome app is missing.
if [ -x /usr/bin/querencia-welcome ]; then
    /usr/bin/querencia-welcome &
    disown 2>/dev/null || true
elif command -v notify-send &>/dev/null; then
    notify-send \
        --icon=dialog-information \
        "Querencia Linux" \
"Welcome! Your system is ready.
Browse apps: Warehouse (Flatpak Store) in your menu
Install packages: micromamba install <pkg>
Run 'ujust --list' for more commands." \
        2>/dev/null || true
fi
FIRSTBOOT
chmod +x /usr/libexec/querencia-first-boot

systemctl --global enable querencia-first-boot-setup.service 2>/dev/null || true

# ---- Flatpak Desktop Entry Sync (persistent, per user) ----------------------
# MATE's menu does not reliably scan ~/.local/share/flatpak/exports/share/applications/
# even when XDG_DATA_DIRS includes that path. This systemd user path unit watches
# the Flatpak export directory and triggers a service that symlinks new .desktop
# files into ~/.local/share/applications/ + refreshes the desktop database.
# This ensures apps installed via Warehouse or "flatpak install --user" appear
# in the MATE menu immediately — not just at first boot.

cat > /usr/lib/systemd/user/querencia-flatpak-desktop-sync.path <<'EOF'
[Unit]
Description=Watch Flatpak user app exports for desktop entry changes

[Path]
PathChanged=%h/.local/share/flatpak/exports/share/applications
Unit=querencia-flatpak-desktop-sync.service

[Install]
WantedBy=default.target
EOF

cat > /usr/lib/systemd/user/querencia-flatpak-desktop-sync.service <<'EOF'
[Unit]
Description=Sync Flatpak desktop entries to local applications dir

[Service]
Type=oneshot
# Small delay so Flatpak finishes writing all files before we sync
ExecStartPre=/usr/bin/sleep 2
ExecStart=/usr/libexec/querencia-flatpak-desktop-sync
EOF

cat > /usr/libexec/querencia-flatpak-desktop-sync <<'SYNC'
#!/usr/bin/env bash
set -euo pipefail

FLATPAK_EXPORT="${HOME}/.local/share/flatpak/exports/share/applications"
LOCAL_APPS="${HOME}/.local/share/applications"

[ -d "${FLATPAK_EXPORT}" ] || exit 0
mkdir -p "${LOCAL_APPS}"

# Add symlinks for new Flatpak .desktop files
for desktop_file in "${FLATPAK_EXPORT}"/*.desktop; do
    [ -f "${desktop_file}" ] || continue
    base="$(basename "${desktop_file}")"
    if [ ! -e "${LOCAL_APPS}/${base}" ] || [ -L "${LOCAL_APPS}/${base}" ]; then
        ln -sf "${desktop_file}" "${LOCAL_APPS}/${base}"
    fi
done

# Remove stale symlinks (Flatpak app was uninstalled)
for link in "${LOCAL_APPS}"/*.desktop; do
    [ -L "${link}" ] || continue
    if [ ! -e "${link}" ]; then
        rm -f "${link}"
    fi
done

# Refresh desktop database so MATE menu picks up changes
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "${LOCAL_APPS}" 2>/dev/null || true
fi
SYNC
chmod +x /usr/libexec/querencia-flatpak-desktop-sync

systemctl --global enable querencia-flatpak-desktop-sync.path 2>/dev/null || true

# ---- Auto-Update Timer -------------------------------------------------------
mkdir -p /usr/lib/systemd/system
cat > /usr/lib/systemd/system/querencia-auto-update.timer <<'EOF'
[Unit]
Description=Querencia Linux -- Automatic image update check

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h
Persistent=true
RandomizedDelaySec=30min

[Install]
WantedBy=timers.target
EOF

cat > /usr/lib/systemd/system/querencia-auto-update.service <<'EOF'
[Unit]
Description=Querencia Linux -- Automatic image update
After=network-online.target
Wants=network-online.target
ConditionACPower=true

[Service]
Type=oneshot
ExecStart=/usr/libexec/querencia-auto-update
Nice=19
IOSchedulingClass=idle
EOF

cat > /usr/libexec/querencia-auto-update <<'AUTOUPDATE'
#!/usr/bin/env bash
# Querencia Linux -- Automatic background update
# Checks for new bootc images and stages them for next reboot.
# Also updates Flatpak apps system-wide.
# Notifies logged-in desktop users when an update is staged.
set -euo pipefail

LOGFILE="/var/log/querencia-auto-update.log"
exec >> "${LOGFILE}" 2>&1
echo "=== $(date -Iseconds) ==="

# Skip updates on metered connections (mobile data, tethering, etc.)
# NetworkManager reports "yes" for metered connections.
# Users can toggle this in Settings → Network → a connection → "Metered Connection".
if command -v nmcli &>/dev/null; then
    if nmcli -t -f GENERAL.METERED dev show 2>/dev/null | grep -qi ":yes"; then
        echo "Metered connection detected — skipping update to save data."
        echo "To force an update: sudo systemctl start querencia-auto-update.service"
        echo "Or disable metered mode in Network settings."
        echo "=== Done (skipped) ==="
        exit 0
    fi
fi

IMAGE_UPDATED=false

# Stage new bootc image (applied on next reboot)
# Strategy: capture the booted image digest before upgrade, then compare
# against the staged digest afterwards. Uses `bootc status --json` (stable API)
# instead of fragile output text matching.
echo "Checking for bootc image updates..."

# Capture current booted image digest (before upgrade)
BOOTED_DIGEST=""
if command -v jq &>/dev/null; then
    BOOTED_DIGEST=$(bootc status --json 2>/dev/null \
        | jq -r '.status.booted.image.imageDigest // empty' 2>/dev/null) || true
fi
echo "Booted image digest: ${BOOTED_DIGEST:-unknown}"

# Run the upgrade (stdout/stderr already go to LOGFILE via exec >>)
bootc upgrade 2>&1 || true

# Check if a new image was staged (after upgrade)
if command -v jq &>/dev/null; then
    STAGED_DIGEST=$(bootc status --json 2>/dev/null \
        | jq -r '.status.staged.image.imageDigest // empty' 2>/dev/null) || true
    if [ -n "${STAGED_DIGEST}" ] && [ "${STAGED_DIGEST}" != "${BOOTED_DIGEST}" ]; then
        echo "New image staged (digest: ${STAGED_DIGEST}). Will apply on next reboot."
        IMAGE_UPDATED=true
    elif [ -n "${STAGED_DIGEST}" ]; then
        echo "System is up to date (staged image matches booted)."
    else
        echo "No staged deployment found — system is up to date."
    fi
else
    # Fallback if jq is somehow missing: treat any upgrade run as potentially staged
    echo "Warning: jq not found — cannot verify staged image digest."
    echo "Assuming upgrade completed successfully."
fi

# Update Flatpak apps (system-wide and per-user)
if command -v flatpak &>/dev/null; then
    echo "Updating system Flatpak apps..."
    flatpak update -y --noninteractive 2>/dev/null || true
    echo "Updating user Flatpak apps..."
    while IFS= read -r user_name; do
        [ -z "${user_name}" ] && continue
        sudo -u "${user_name}" flatpak update --user -y --noninteractive 2>/dev/null || true
    done < <(loginctl list-users --no-legend 2>/dev/null | awk '{print $2}')
    flatpak uninstall --unused -y --noninteractive 2>/dev/null || true
    echo "Flatpak update complete."
fi

# Notify logged-in desktop users about staged image update
if [ "${IMAGE_UPDATED}" = true ]; then
    echo "Notifying desktop users..."
    while IFS= read -r _line; do
        user_id=$(echo "$_line" | awk '{print $1}')
        user_name=$(echo "$_line" | awk '{print $2}')
        [ -z "${user_name}" ] && continue

        # Use loginctl show-user to get session list (stable API, not column-based)
        DISPLAY_VAL=""
        SESSION_ID=$(loginctl show-user "${user_name}" -p Sessions --value 2>/dev/null | awk '{print $1}')
        if [ -n "${SESSION_ID}" ]; then
            DISPLAY_VAL=$(loginctl show-session "${SESSION_ID}" -p Display --value 2>/dev/null || echo ":0")
        fi
        DISPLAY_VAL="${DISPLAY_VAL:-:0}"
        sudo -u "${user_name}" \
            DISPLAY="${DISPLAY_VAL}" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${user_id}/bus" \
            notify-send \
                --icon=software-update-available \
                "System Update Available" \
"A new Querencia Linux image has been staged.
Reboot to apply the update.

Run 'ujust rollback' after reboot to undo." \
                2>/dev/null || true
    done < <(loginctl list-users --no-legend 2>/dev/null)
fi

echo "=== Done ==="
AUTOUPDATE
chmod +x /usr/libexec/querencia-auto-update

systemctl enable querencia-auto-update.timer
systemctl enable dconf-update.service

# ---- MOTD --------------------------------------------------------------------
cat > /etc/motd <<'MOTD'

  Querencia Linux
  "Where Linux Feels at Home"
  -----------------------------------------------
  AlmaLinux 10 | MATE Desktop | Atomic / Immutable

  ujust --list       Show available commands
  ujust update       Update system + Flatpaks
  ujust status       Show bootc image status
  ujust rollback     Roll back to previous image
  ujust info         Show system info

  ujust device-info  Collect & share diagnostics (support URL)
  ujust bios         Reboot into BIOS/UEFI setup
  ujust logs-errors  Show errors from current boot
  ujust benchmark    Run 60-second system stress test

  Auto-updates run every 6 hours (reboot to apply)
  Updates are skipped on metered connections.

  Browse & install apps:
    Warehouse (Flatpak Store) — in your application menu
    micromamba install ripgrep bat fd-find

MOTD
cp /etc/motd /etc/issue.net

# ---- Polkit Rules (wheel group can manage Flatpak) ---------------------------
mkdir -p /usr/lib/polkit-1/rules.d
cat > /usr/lib/polkit-1/rules.d/50-querencia-linux.rules <<'POLKIT'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.Flatpak.appstream-update" ||
         action.id == "org.freedesktop.Flatpak.runtime-install" ||
         action.id == "org.freedesktop.Flatpak.app-install" ||
         action.id == "org.freedesktop.Flatpak.modify-repo") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT

# ---- Sysctl Tweaks (desktop-optimized) --------------------------------------
mkdir -p /usr/lib/sysctl.d
cat > /usr/lib/sysctl.d/99-querencia-linux-desktop.conf <<'SYSCTL'
# ZRAM-optimized swappiness: higher value is better with compressed RAM swap.
# With ZRAM there is no disk penalty, so the kernel should swap early to ZRAM
# rather than evicting file caches. 180 is the recommended value for ZRAM
# (kernel 5.8+ supports 0-200 range; Fedora/ChromeOS use 180).
vm.swappiness = 180
# Increase inotify watches (needed for IDEs, file managers, etc.)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
# Network performance
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
SYSCTL

# ---- Bash Aliases (like atomic-workstation) ----------------------------------
cat > /etc/profile.d/bash_aliases.sh <<'EOF'
alias ls='ls --color=auto'
alias ll='ls -la'
EOF

# ---- dconf update (apply MATE defaults) --------------------------------------
dconf update || true
