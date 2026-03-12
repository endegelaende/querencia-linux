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

# Add Flathub remote for user
if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists --user flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi

mkdir -p "${HOME}/.config"

# Desktop notification
if command -v notify-send &>/dev/null; then
    notify-send \
        --icon=dialog-information \
        "Querencia Linux" \
        "Welcome. Your system is ready.\nRun 'ujust --list' in a terminal for available commands." \
        2>/dev/null || true
fi
FIRSTBOOT
chmod +x /usr/libexec/querencia-first-boot

systemctl --global enable querencia-first-boot-setup.service 2>/dev/null || true

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
# Reduce swappiness (desktops benefit from keeping more in RAM)
vm.swappiness = 10
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
