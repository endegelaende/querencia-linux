#!/usr/bin/env bash
# Querencia Linux -- Post-Install Configuration
# Sets up system-wide defaults that become active on first boot.
set -xeuo pipefail

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

# ---- Flatpak Overrides -- GPU access and theming ----------------------------
mkdir -p /var/lib/flatpak/overrides
cat > /var/lib/flatpak/overrides/global <<'EOF'
[Context]
devices=dri;
filesystems=xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;/usr/share/themes:ro;/usr/share/icons:ro;

[Environment]
GTK_THEME=BlueMenta
XCURSOR_THEME=default
XCURSOR_SIZE=24
EOF

# ---- Systemd Presets ---------------------------------------------------------
mkdir -p /etc/systemd/system-preset
cat > /etc/systemd/system-preset/50-querencia-linux.preset <<'EOF'
enable lightdm.service
enable NetworkManager.service
enable bluetooth.service
enable fstrim.timer
enable cups.socket
enable firewalld.service
EOF

# ---- ujust Shortcut ----------------------------------------------------------
JUSTFILE_SRC="/usr/share/justfiles/custom.just"
JUSTFILE_LINK="/usr/local/bin/ujust"

if [ -f "${JUSTFILE_SRC}" ]; then
    mkdir -p /usr/local/bin
    cat > "${JUSTFILE_LINK}" <<'UJUST'
#!/usr/bin/env bash
exec just --justfile /usr/share/justfiles/custom.just "$@"
UJUST
    chmod +x "${JUSTFILE_LINK}"
fi

# ---- First-Boot Service (per user) ------------------------------------------
mkdir -p /etc/systemd/user
cat > /etc/systemd/user/querencia-first-boot-setup.service <<'EOF'
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

# Desktop notification
if command -v notify-send &>/dev/null; then
    notify-send \
        --icon=dialog-information \
        "Querencia Linux" \
        "Welcome. Your system is ready.\nBrowse apps: Warehouse (Flatpak Store) in your menu\nInstall packages: micromamba install <pkg>\nRun 'ujust --list' for more commands." \
        2>/dev/null || true
fi
FIRSTBOOT
chmod +x /usr/libexec/querencia-first-boot

systemctl --global enable querencia-first-boot-setup.service 2>/dev/null || true

# ---- Auto-Update Timer -------------------------------------------------------
cat > /etc/systemd/system/querencia-auto-update.timer <<'EOF'
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

cat > /etc/systemd/system/querencia-auto-update.service <<'EOF'
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

IMAGE_UPDATED=false

# Stage new bootc image (applied on next reboot)
# bootc upgrade: exit 0 = update staged, non-zero = already current or error
echo "Checking for bootc image updates..."
bootc upgrade 2>&1 || rc=$?
rc=${rc:-0}
if [ "${rc}" -eq 0 ]; then
    echo "New image staged. Will apply on next reboot."
    IMAGE_UPDATED=true
else
    echo "No update available (bootc exit code ${rc})."
fi

# Update Flatpak apps
if command -v flatpak &>/dev/null; then
    echo "Updating Flatpak apps..."
    flatpak update -y --noninteractive 2>/dev/null || true
    flatpak uninstall --unused -y --noninteractive 2>/dev/null || true
    echo "Flatpak update complete."
fi

# Notify logged-in desktop users about staged image update
if [ "${IMAGE_UPDATED}" = true ]; then
    echo "Notifying desktop users..."
    for user_id in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}'); do
        user_name=$(loginctl list-users --no-legend 2>/dev/null | awk -v id="$user_id" '$1==id {print $2}')
        if [ -n "${user_name}" ]; then
            sudo -u "${user_name}" \
                DISPLAY=:0 \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${user_id}/bus" \
                notify-send \
                    --icon=software-update-available \
                    "System Update Available" \
                    "A new Querencia Linux image has been staged.\nReboot to apply the update.\n\nRun 'ujust rollback' after reboot to undo." \
                    2>/dev/null || true
        fi
    done
fi

echo "=== Done ==="
AUTOUPDATE
chmod +x /usr/libexec/querencia-auto-update

systemctl enable querencia-auto-update.timer

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

  Auto-updates run every 6 hours (reboot to apply)

  Browse & install apps:
    Warehouse (Flatpak Store) — in your application menu
    micromamba install ripgrep bat fd-find

MOTD
cp /etc/motd /etc/issue.net

# ---- Polkit Rules (wheel group can manage Flatpak) ---------------------------
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-querencia-linux.rules <<'POLKIT'
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
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-querencia-linux-desktop.conf <<'SYSCTL'
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
