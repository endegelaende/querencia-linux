# =============================================================================
# Querencia Linux -- ujust Recipes
# "Where Linux Feels at Home"
# =============================================================================
# Usage: ujust <recipe>
# List:  ujust --list
# =============================================================================

# Default recipe: show help
default:
    @just --list --unsorted

# =============================================================================
# System Updates
# =============================================================================

# Full system update (bootc + Flatpak)
update:
    @echo "System update started..."
    @echo ""
    @echo "-- bootc image update --"
    sudo bootc upgrade
    @echo ""
    @echo "-- Flatpak updates --"
    flatpak update -y
    @echo ""
    @echo "Update complete. Reboot recommended if the image changed."

# Update only the bootc base image
update-system:
    @echo "Updating bootc image..."
    sudo bootc upgrade

# Update only Flatpak apps
update-flatpak:
    @echo "Updating Flatpak apps..."
    flatpak update -y

# Show bootc system status
status:
    @echo "bootc status:"
    @echo ""
    sudo bootc status

# Roll back to the previous image
rollback:
    @echo "Rolling back to previous image..."
    sudo bootc rollback
    @echo "Rollback staged. Please reboot."

# =============================================================================
# Flatpak
# =============================================================================

# Set up Flathub (if not already configured)
setup-flatpak:
    @echo "Setting up Flatpak and Flathub..."
    flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    @echo "Flathub is ready."
    @echo ""
    @echo "Install recommended apps with: ujust install-essentials"

# Install recommended Flatpak apps
install-essentials:
    @echo "Installing recommended Flatpak apps..."
    flatpak install -y flathub \
        org.mozilla.Thunderbird \
        org.libreoffice.LibreOffice \
        org.gnome.Calculator \
        org.gnome.Evince \
        com.github.tchx84.Flatseal \
        io.github.celluloid_player.Celluloid \
        org.gnome.SimpleScan
    @echo "Essential apps installed."
    @echo ""
    @echo "Warehouse (Flatpak Store) is pre-installed — find it in your application menu."

# Open the Flatpak Store (Warehouse)
open-store:
    @echo "Opening Warehouse (Flatpak Store)..."
    flatpak run io.github.flattool.Warehouse &

# Remove unused Flatpak runtimes
clean-flatpak:
    @echo "Removing unused Flatpak runtimes..."
    flatpak uninstall --unused -y
    @echo "Done."

# =============================================================================
# Distrobox
# =============================================================================

# Create an AlmaLinux distrobox
distrobox-alma:
    @echo "Creating AlmaLinux 10 distrobox..."
    distrobox create --name alma --image docker.io/library/almalinux:10 --yes
    @echo "Done. Enter with: distrobox enter alma"

# Create a Fedora distrobox
distrobox-fedora:
    @echo "Creating Fedora distrobox..."
    distrobox create --name fedora --image registry.fedoraproject.org/fedora-toolbox:latest --yes
    @echo "Done. Enter with: distrobox enter fedora"

# Create an Ubuntu distrobox
distrobox-ubuntu:
    @echo "Creating Ubuntu distrobox..."
    distrobox create --name ubuntu --image docker.io/library/ubuntu:latest --yes
    @echo "Done. Enter with: distrobox enter ubuntu"

# List all distroboxes
distrobox-list:
    @echo "Distroboxes:"
    distrobox list

# Upgrade all distroboxes
distrobox-upgrade:
    @echo "Upgrading all distroboxes..."
    distrobox upgrade --all
    @echo "Done."

# =============================================================================
# Third-Party Apps (Distrobox)
# =============================================================================

# Install Omnissa Horizon Client (VDI) in a Distrobox container
install-horizon:
    #!/usr/bin/env bash
    set -euo pipefail
    CONTAINER="horizon"
    RPM_URL="https://download3.omnissa.com/software/CART26FQ4_LIN64_RPMPKG_2512.1/Omnissa-Horizon-Client-2512-8.17.1-22261155021.x64.rpm"
    RPM_FILE="/tmp/omnissa-horizon-client.x86_64.rpm"
    echo "=== Omnissa Horizon Client Installer ==="
    echo ""
    # Create AlmaLinux 10 distrobox if it doesn't exist
    if ! podman container exists "${CONTAINER}" 2>/dev/null; then
        echo "Creating distrobox '${CONTAINER}'..."
        distrobox create --name "${CONTAINER}" --image docker.io/library/almalinux:10 --yes
    else
        echo "Distrobox '${CONTAINER}' already exists."
    fi
    echo ""
    echo "Installing GTK/X11 dependencies..."
    distrobox enter "${CONTAINER}" -- bash -c "sudo dnf install -y gtk3 libXtst libusbx alsa-lib pulseaudio-libs mesa-libGL mesa-libEGL libxkbfile"
    echo ""
    echo "Downloading Horizon Client RPM..."
    distrobox enter "${CONTAINER}" -- bash -c "curl -fSL -o ${RPM_FILE} '${RPM_URL}'"
    echo ""
    echo "Installing Horizon Client..."
    distrobox enter "${CONTAINER}" -- bash -c "sudo dnf install -y ${RPM_FILE} && rm -f ${RPM_FILE}"
    echo ""
    echo "Exporting Horizon Client to host desktop..."
    distrobox enter "${CONTAINER}" -- bash -c "distrobox-export --app horizon-client 2>/dev/null || true"
    echo ""
    echo "Done! Omnissa Horizon Client should appear in your application menu."
    echo "If not, log out and back in."
    echo ""
    echo "To uninstall: ujust remove-horizon"

# Remove Omnissa Horizon Client and its Distrobox
remove-horizon:
    #!/usr/bin/env bash
    set -euo pipefail
    CONTAINER="horizon"
    echo "Removing Horizon Client desktop integration..."
    distrobox enter "${CONTAINER}" -- bash -c "distrobox-export --app horizon-client --delete 2>/dev/null || true"
    echo "Removing distrobox '${CONTAINER}'..."
    distrobox rm --force "${CONTAINER}" 2>/dev/null || true
    echo "Done. Omnissa Horizon Client has been removed."

# =============================================================================
# GPU (auto-detects AMD or NVIDIA)
# =============================================================================

# Show GPU info (auto-detects AMD or NVIDIA)
gpu-info:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== GPU Information ==="
    echo ""
    echo "-- GPU hardware --"
    lspci -k 2>/dev/null | grep -A3 -i 'vga\|3d controller' || echo "(lspci not available)"
    echo ""
    if lsmod | grep -q nvidia 2>/dev/null; then
        echo "-- NVIDIA Driver --"
        nvidia-smi 2>/dev/null || echo "(nvidia-smi not available)"
        echo ""
        echo "-- Loaded modules --"
        lsmod | grep -i nvidia || true
        echo ""
        echo "-- Kernel args --"
        grep -oE '(modprobe\.blacklist=nouveau|nvidia-drm\.modeset=[0-9]+|rd\.driver\.blacklist=nouveau)' /proc/cmdline 2>/dev/null || echo "(none)"
        echo ""
        echo "-- nouveau status --"
        if lsmod | grep -q nouveau 2>/dev/null; then
            echo "WARNING: nouveau is loaded (should be blacklisted)"
        else
            echo "nouveau is not loaded (correct)"
        fi
    elif lsmod | grep -q amdgpu 2>/dev/null; then
        echo "-- AMD Kernel driver --"
        lsmod | grep -i amdgpu
        echo ""
        echo "-- Mesa / OpenGL --"
        glxinfo 2>/dev/null | grep -i "opengl renderer\|opengl version" || echo "(glxinfo not available -- install mesa-demos)"
        echo ""
        echo "-- VA-API (hardware video) --"
        vainfo 2>/dev/null || echo "(vainfo not available)"
    else
        echo "-- Kernel driver --"
        echo "No AMD (amdgpu) or NVIDIA driver detected."
        echo "Loaded GPU-related modules:"
        lsmod | grep -iE 'gpu|drm|video|vga|radeon|nouveau|i915|xe' 2>/dev/null || echo "(none)"
    fi
    echo ""
    echo "-- Vulkan --"
    vulkaninfo --summary 2>/dev/null || echo "(vulkaninfo not available)"

# Live GPU monitoring (auto-detects AMD or NVIDIA)
gpu-monitor:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo "NVIDIA GPU Monitor (Ctrl+C to exit):"
        echo ""
        watch -n 1 'nvidia-smi'
    elif [ -d /sys/class/drm/card0/device ] && lsmod | grep -q amdgpu 2>/dev/null; then
        echo "AMD GPU Monitor (Ctrl+C to exit):"
        echo ""
        watch -n 1 'echo "-- GPU Busy --" && cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null && echo "%" && echo "" && echo "-- Temperature --" && cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | awk "{printf \"%.1f C\n\", \$1/1000}" && echo "" && echo "-- VRAM --" && echo "Used: $(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | awk "{printf \"%.0f MB\", \$1/1048576}") / Total: $(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | awk "{printf \"%.0f MB\", \$1/1048576}")" && echo "" && echo "-- Clock --" && cat /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null | grep "\*" && echo "" && echo "-- Power --" && cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | awk "{printf \"%.1f W\n\", \$1/1000000}"'
    else
        echo "No supported GPU monitoring available."
        echo "Try: lspci -k | grep -A3 VGA"
    fi

# Show GPU sensor readings (auto-detects AMD or NVIDIA)
gpu-sensors:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo "NVIDIA GPU Sensors:"
        echo ""
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,power.limit,fan.speed,clocks.gr,clocks.mem --format=csv,noheader,nounits 2>/dev/null | \
        while IFS=, read -r name temp gpu_util mem_util mem_used mem_total power power_limit fan clk_gr clk_mem; do
            echo "  GPU:         $(echo "$name" | xargs)"
            echo "  Temperature: $(echo "$temp" | xargs) °C"
            echo "  GPU Util:    $(echo "$gpu_util" | xargs) %"
            echo "  Mem Util:    $(echo "$mem_util" | xargs) %"
            echo "  VRAM:        $(echo "$mem_used" | xargs) / $(echo "$mem_total" | xargs) MiB"
            echo "  Power:       $(echo "$power" | xargs) / $(echo "$power_limit" | xargs) W"
            echo "  Fan:         $(echo "$fan" | xargs) %"
            echo "  Clocks:      $(echo "$clk_gr" | xargs) MHz (GPU), $(echo "$clk_mem" | xargs) MHz (Mem)"
        done || nvidia-smi
    elif lsmod | grep -q amdgpu 2>/dev/null; then
        echo "AMD GPU Sensors:"
        echo ""
        echo "-- Temperature --"
        cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | awk '{printf "  GPU: %.1f °C\n", $1/1000}' || echo "  Not available"
        echo ""
        echo "-- VRAM Usage --"
        echo "  Used:  $(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | awk '{printf "%.0f MB", $1/1048576}')"
        echo "  Total: $(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | awk '{printf "%.0f MB", $1/1048576}')"
        echo ""
        echo "-- Utilization --"
        echo "  GPU Busy: $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)%"
        echo ""
        echo "-- Power --"
        cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | awk '{printf "  Draw: %.1f W\n", $1/1000000}' || echo "  Not available"
    else
        echo "No supported GPU detected for sensor readings."
        echo "Try: lspci -k | grep -A3 VGA"
    fi

# Set GPU power profile to performance (AMD only — NVIDIA uses nvidia-smi)
gpu-performance:
    #!/usr/bin/env bash
    set -euo pipefail
    if lsmod | grep -q amdgpu 2>/dev/null; then
        echo "AMD GPU power profile -> Performance"
        echo "high" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
        echo "Performance mode active."
    elif command -v nvidia-smi &>/dev/null; then
        echo "NVIDIA GPU -> Prefer Maximum Performance"
        sudo nvidia-smi -pm 1 2>/dev/null || true
        sudo nvidia-smi --power-limit=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs) 2>/dev/null || true
        echo "Set persistence mode ON and power limit to maximum."
        echo "For per-app control, use: switcherooctl launch <command>"
    else
        echo "No supported GPU found for power profile control."
    fi

# Set GPU power profile to power saving (AMD only — NVIDIA uses nvidia-smi)
gpu-powersave:
    #!/usr/bin/env bash
    set -euo pipefail
    if lsmod | grep -q amdgpu 2>/dev/null; then
        echo "AMD GPU power profile -> Power Save"
        echo "low" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
        echo "Power save mode active."
    elif command -v nvidia-smi &>/dev/null; then
        echo "NVIDIA GPU -> Power Saving"
        sudo nvidia-smi -pm 1 2>/dev/null || true
        sudo nvidia-smi -pl $(nvidia-smi --query-gpu=power.min_limit --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs) 2>/dev/null || true
        echo "Set power limit to minimum."
        echo "Note: Clock speeds will reduce under load. Reset with: ujust gpu-auto"
    else
        echo "No supported GPU found for power profile control."
    fi

# Set GPU power profile to automatic (AMD) / reset to defaults (NVIDIA)
gpu-auto:
    #!/usr/bin/env bash
    set -euo pipefail
    if lsmod | grep -q amdgpu 2>/dev/null; then
        echo "AMD GPU power profile -> Auto"
        echo "auto" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
        echo "Auto mode active."
    elif command -v nvidia-smi &>/dev/null; then
        echo "NVIDIA GPU -> Reset to defaults"
        sudo nvidia-smi -pm 0 2>/dev/null || true
        sudo nvidia-smi -rgc 2>/dev/null || true
        sudo nvidia-smi -rmc 2>/dev/null || true
        echo "Persistence mode OFF, clocks reset to default."
    else
        echo "No supported GPU found for power profile control."
    fi

# Run Vulkan test (vkcube)
gpu-test:
    @echo "Starting Vulkan test (vkcube)..."
    vkcube 2>/dev/null || echo "vkcube not found -- install vulkan-tools"

# =============================================================================
# MATE Desktop
# =============================================================================

# Reset MATE panel to defaults
mate-reset-panel:
    @echo "Resetting MATE panel..."
    dconf reset -f /org/mate/panel/
    mate-panel --replace &
    @echo "Panel reset."

# Switch to dark theme
mate-dark:
    @echo "Switching to dark theme..."
    dconf write /org/mate/desktop/interface/gtk-theme "'BlueMenta'"
    dconf write /org/mate/marco/general/theme "'BlueMenta'"
    @echo "Dark theme active."

# Switch to light theme
mate-light:
    @echo "Switching to light theme..."
    dconf write /org/mate/desktop/interface/gtk-theme "'Menta'"
    dconf write /org/mate/marco/general/theme "'Menta'"
    @echo "Light theme active."

# =============================================================================
# System Tools
# =============================================================================

# Show system info (fastfetch)
info:
    @fastfetch 2>/dev/null || echo "fastfetch not installed"

# Show disk usage
disk:
    @echo "Disk usage:"
    df -h / /boot /var/home 2>/dev/null | column -t

# Show memory usage
memory:
    @echo "Memory usage:"
    free -h

# Show running services
services:
    @echo "Active services:"
    systemctl list-units --type=service --state=running --no-pager

# Show logs from current boot session
logs:
    @echo "Current boot session logs (last 50 lines):"
    journalctl -b --no-pager | tail -50

# Run SSD TRIM
trim:
    @echo "Running SSD TRIM..."
    sudo fstrim -av
    @echo "TRIM complete."

# Clean up temporary files and caches
clean:
    @echo "Cleaning up system..."
    sudo journalctl --vacuum-time=7d
    flatpak uninstall --unused -y 2>/dev/null || true
    podman system prune -f 2>/dev/null || true
    @echo "Cleanup complete."

# Full maintenance: update + clean
maintenance: update clean
    @echo ""
    @echo "Maintenance complete."

# Show auto-update status and log
update-status:
    @echo "Auto-update timer status:"
    @echo ""
    systemctl status querencia-auto-update.timer --no-pager 2>/dev/null || echo "Timer not found."
    @echo ""
    @echo "-- Last update log (last 20 lines) --"
    @tail -20 /var/log/querencia-auto-update.log 2>/dev/null || echo "No log yet."

# Trigger auto-update manually (stages image for next reboot)
update-now:
    @echo "Running auto-update now..."
    sudo systemctl start querencia-auto-update.service
    @echo ""
    @echo "Check result:"
    @tail -10 /var/log/querencia-auto-update.log 2>/dev/null || echo "No log yet."

# Disable automatic updates
update-disable:
    @echo "Disabling automatic updates..."
    sudo systemctl disable --now querencia-auto-update.timer
    @echo "Auto-updates disabled. Re-enable with: ujust update-enable"

# Enable automatic updates
update-enable:
    @echo "Enabling automatic updates..."
    sudo systemctl enable --now querencia-auto-update.timer
    @echo "Auto-updates enabled (every 6 hours)."

# =============================================================================
# Firewall
# =============================================================================

# Show firewall status
firewall-status:
    @echo "Firewall status:"
    @echo ""
    sudo firewall-cmd --state 2>/dev/null || echo "firewalld not running."
    @echo ""
    @echo "-- Active zone --"
    sudo firewall-cmd --get-active-zones 2>/dev/null || true
    @echo ""
    @echo "-- Allowed services --"
    sudo firewall-cmd --list-all 2>/dev/null || true

# Allow a service through the firewall (e.g. ssh, http, https)
firewall-allow service:
    @echo "Allowing {{service}} through firewall..."
    sudo firewall-cmd --permanent --add-service={{service}}
    sudo firewall-cmd --reload
    @echo "{{service}} is now allowed."

# Block a service in the firewall
firewall-block service:
    @echo "Blocking {{service}} in firewall..."
    sudo firewall-cmd --permanent --remove-service={{service}}
    sudo firewall-cmd --reload
    @echo "{{service}} is now blocked."

# =============================================================================
# Printing
# =============================================================================

# Open printer settings
printer-setup:
    @echo "Opening printer settings..."
    system-config-printer &

# Show CUPS status
printer-status:
    @echo "CUPS printing status:"
    @echo ""
    systemctl status cups.socket --no-pager 2>/dev/null || echo "CUPS not available."
    @echo ""
    @echo "-- Configured printers --"
    lpstat -p 2>/dev/null || echo "No printers configured."

# =============================================================================
# Micromamba (user-space package manager)
# =============================================================================
# The 'base' environment is auto-created on first login and always active.
# Install packages directly:  micromamba install ripgrep bat fd-find
# Or use ujust:               ujust mamba-install ripgrep bat fd-find

# Show micromamba status and base environment info
mamba-setup:
    @echo "Micromamba status:"
    @echo ""
    @if [ -d "${HOME}/micromamba/envs/base" ]; then \
        echo "  ✅ base environment is ready (auto-created on first login)"; \
        echo "  📦 Installed packages:"; \
        micromamba list -n base --no-banner 2>/dev/null | tail -n +4 || true; \
    else \
        echo "  ⚠️  base environment not found — creating it now..."; \
        micromamba create -n base -c conda-forge -y; \
        echo "  ✅ base environment created."; \
        echo "  Restart your terminal or run: source ~/.bashrc"; \
    fi
    @echo ""
    @echo "Install packages:  micromamba install <package>"
    @echo "Search packages:   micromamba search <package>"
    @echo "Create new env:    ujust mamba-create myenv"

# Install recommended CLI tools into base environment
mamba-install-tools:
    @echo "Installing CLI tools into base environment..."
    micromamba install -n base -c conda-forge -y \
        ripgrep \
        fd-find \
        bat \
        eza \
        zoxide \
        fzf \
        delta \
        starship \
        jq \
        yq \
        tldr \
        bottom
    @echo ""
    @echo "CLI tools installed into base (already active)."
    @echo "Try: rg, fd, bat, eza, fzf, jq, tldr"

# Create a new empty environment
mamba-create name:
    @echo "Creating environment '{{name}}'..."
    micromamba create -n {{name}} -c conda-forge -y
    @echo "Environment '{{name}}' created. Activate: micromamba activate {{name}}"

# Install package(s) into base environment
mamba-install +packages:
    @echo "Installing into base: {{packages}}"
    micromamba install -n base -c conda-forge -y {{packages}}

# List all environments
mamba-list:
    @echo "Micromamba environments:"
    @echo ""
    micromamba env list

# List packages in base environment
mamba-packages:
    @echo "Packages in base:"
    micromamba list -n base

# Update all packages in base environment
mamba-update:
    @echo "Updating base environment..."
    micromamba update -n base --all -y
    @echo "Base environment updated."

# Export environment to YAML (backup)
mamba-backup name="tools":
    @echo "Exporting environment '{{name}}'..."
    @mkdir -p "${HOME}/.config/micromamba-backups"
    micromamba env export -n {{name}} > "${HOME}/.config/micromamba-backups/{{name}}.yml"
    @echo "Saved to: ~/.config/micromamba-backups/{{name}}.yml"

# Restore environment from YAML file
mamba-restore file:
    @echo "Restoring environment from {{file}}..."
    micromamba create -f {{file}} -y
    @echo "Environment restored."

# Show all backups
mamba-backups:
    @echo "Available backups:"
    @ls -la "${HOME}/.config/micromamba-backups/" 2>/dev/null || echo "  No backups found. Create one with: ujust mamba-backup"

# Clean micromamba cache
mamba-clean:
    @echo "Cleaning micromamba cache..."
    micromamba clean --all -y
    @echo "Cache cleaned."

# Create a Python development environment
mamba-python version="3.12":
    @echo "Creating Python {{version}} environment..."
    micromamba create -n python{{version}} -c conda-forge -y \
        python={{version}} \
        pip \
        ipython \
        black \
        ruff \
        mypy
    @echo "Python {{version}} environment created."
    @echo "  Activate: micromamba activate python{{version}}"

# Create a Node.js development environment
mamba-node version="22":
    @echo "Creating Node.js {{version}} environment..."
    micromamba create -n node{{version}} -c conda-forge -y \
        nodejs={{version}} \
        yarn
    @echo "Node.js {{version}} environment created."
    @echo "  Activate: micromamba activate node{{version}}"

# =============================================================================
# Multimedia
# =============================================================================

# Check codec status (which formats are supported)
codec-check:
    @echo "Multimedia codec status:"
    @echo ""
    @echo "-- GStreamer Plugins --"
    @gst-inspect-1.0 --version 2>/dev/null && echo "" || echo "  GStreamer not found"
    @echo "  Base:      $(rpm -q gstreamer1-plugins-base 2>/dev/null || echo 'not installed')"
    @echo "  Good:      $(rpm -q gstreamer1-plugins-good 2>/dev/null || echo 'not installed')"
    @echo "  Bad-Free:  $(rpm -q gstreamer1-plugins-bad-free 2>/dev/null || echo 'not installed')"
    @echo "  Ugly:      $(rpm -q gstreamer1-plugins-ugly 2>/dev/null || echo 'not installed')"
    @echo "  OpenH264:  $(rpm -q gstreamer1-plugin-openh264 2>/dev/null || echo 'not installed')"
    @echo "  Libav:     $(rpm -q gstreamer1-libav 2>/dev/null || echo 'not installed')"
    @echo ""
    @echo "-- FFmpeg --"
    @ffmpeg -version 2>/dev/null | head -1 || echo "  FFmpeg not found"
    @echo ""
    @echo "-- Supported formats --"
    @echo "  H.264:  $(ffmpeg -decoders 2>/dev/null | grep -c h264 || echo '?') decoders"
    @echo "  H.265:  $(ffmpeg -decoders 2>/dev/null | grep -c hevc || echo '?') decoders"
    @echo "  VP9:    $(ffmpeg -decoders 2>/dev/null | grep -c vp9 || echo '?') decoders"
    @echo "  AV1:    $(ffmpeg -decoders 2>/dev/null | grep -c av1 || echo '?') decoders"
    @echo "  AAC:    $(ffmpeg -decoders 2>/dev/null | grep -c aac || echo '?') decoders"
    @echo "  MP3:    $(ffmpeg -decoders 2>/dev/null | grep -c mp3 || echo '?') decoders"
    @echo ""
    @echo "-- VA-API Hardware Decoding --"
    @vainfo 2>/dev/null | grep -E "VAProfile|Driver" || echo "  VA-API not available"

# Play a test video (Big Buck Bunny)
codec-test:
    @echo "Downloading test video (Big Buck Bunny)..."
    @curl -fsSL -o /tmp/bbb_trailer.mp4 \
        "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4" \
        2>/dev/null \
    && echo "Starting playback..." \
    && celluloid /tmp/bbb_trailer.mp4 2>/dev/null \
        || mpv /tmp/bbb_trailer.mp4 2>/dev/null \
        || xdg-open /tmp/bbb_trailer.mp4 2>/dev/null \
        || echo "No video player found. Install one: flatpak install flathub io.github.celluloid_player.Celluloid"

# =============================================================================
# Diagnostics & Troubleshooting (inspired by Bluefin)
# =============================================================================

# Collect system diagnostics and upload to a pastebin (shareable URL for support)
device-info:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Collecting system diagnostics..."
    echo ""
    TMPFILE=$(mktemp /tmp/querencia-diag-XXXXXX.txt)
    {
        echo "=== Querencia Linux — Device Info ==="
        echo "Generated: $(date -Iseconds)"
        echo ""
        echo "=== OS Release ==="
        cat /etc/os-release 2>/dev/null || echo "not available"
        echo ""
        echo "=== Kernel ==="
        uname -a
        echo ""
        echo "=== bootc Status ==="
        sudo bootc status 2>/dev/null || echo "bootc not available"
        echo ""
        echo "=== Hardware ==="
        echo "-- CPU --"
        lscpu 2>/dev/null | grep -E "Model name|Architecture|CPU\(s\)|Thread|Core" || echo "lscpu not available"
        echo ""
        echo "-- Memory --"
        free -h
        echo ""
        echo "-- GPU --"
        lspci -k 2>/dev/null | grep -A3 -i vga || echo "lspci not available"
        echo ""
        echo "-- Disk --"
        df -h / /boot /var/home 2>/dev/null || df -h /
        echo ""
        echo "-- Block Devices --"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null || echo "lsblk not available"
        echo ""
        echo "=== SWAP ==="
        swapon --show 2>/dev/null || echo "no swap"
        echo ""
        echo "=== Network ==="
        nmcli -t -f NAME,TYPE,DEVICE,STATE con show 2>/dev/null || echo "nmcli not available"
        echo ""
        echo "=== Installed RPMs ==="
        rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort || echo "rpm not available"
        echo ""
        echo "=== Flatpaks ==="
        flatpak list --columns=name,application,version,branch 2>/dev/null || echo "no flatpaks"
        echo ""
        echo "=== Distroboxes ==="
        distrobox list 2>/dev/null || echo "no distroboxes"
        echo ""
        echo "=== systemd Failed Units ==="
        systemctl --failed --no-pager 2>/dev/null || true
        echo ""
        echo "=== SELinux ==="
        getenforce 2>/dev/null || echo "SELinux status unknown"
        echo ""
        echo "=== Recent Errors (last 25 lines, this boot) ==="
        journalctl -b 0 -p err --no-pager -n 25 2>/dev/null || echo "no errors"
    } > "${TMPFILE}" 2>&1
    echo "Diagnostics collected ($(wc -l < "${TMPFILE}") lines)."
    echo ""
    echo "This will upload your system diagnostics to ix.io (a public pastebin)."
    echo "The data includes: OS version, hardware info, RPM list, network, logs."
    echo ""
    read -p "Upload to ix.io? [y/N] " _upload
    if [[ "${_upload}" != [yY] ]]; then
        echo ""
        echo "Upload skipped. Diagnostics saved locally:"
        echo "  ${TMPFILE}"
        echo ""
        echo "You can share it manually:  curl -F 'f:1=<${TMPFILE}' ix.io"
        exit 0
    fi
    echo ""
    echo "Uploading to ix.io..."
    URL=$(curl -sF 'f:1=<'"${TMPFILE}" ix.io 2>/dev/null) || true
    if [ -n "${URL}" ]; then
        echo ""
        echo "Share this URL for support:"
        echo "  ${URL}"
        echo ""
        echo "(URL copied to clipboard if xclip is available)"
        echo "${URL}" | xclip -selection clipboard 2>/dev/null || true
    else
        echo "Upload failed. Diagnostics saved locally:"
        echo "  ${TMPFILE}"
        echo ""
        echo "You can share it manually:  curl -F 'f:1=<${TMPFILE}' ix.io"
    fi

# Reboot into BIOS/UEFI firmware setup
bios:
    @echo "Rebooting into BIOS/UEFI setup..."
    @echo "The system will reboot NOW and enter firmware setup."
    @echo ""
    @read -p "Press Enter to continue or Ctrl+C to cancel... " _confirm
    systemctl reboot --firmware-setup

# Show BIOS/UEFI information
bios-info:
    @echo "BIOS/UEFI Information:"
    @echo ""
    @echo "  Manufacturer: $(cat /sys/class/dmi/id/board_vendor 2>/dev/null || echo 'unknown')"
    @echo "  Product:      $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'unknown')"
    @echo "  BIOS Version: $(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo 'unknown')"
    @echo "  BIOS Date:    $(cat /sys/class/dmi/id/bios_date 2>/dev/null || echo 'unknown')"

# Show all system logs from the current boot
logs-this-boot:
    @echo "Logs from current boot session:"
    @echo "(Use arrow keys to scroll, q to quit)"
    @echo ""
    journalctl -b 0

# Show all system logs from the previous boot
logs-last-boot:
    @echo "Logs from previous boot session:"
    @echo "(Use arrow keys to scroll, q to quit)"
    @echo ""
    journalctl -b -1

# Show only errors from the current boot
logs-errors:
    @echo "Errors from current boot session:"
    @echo ""
    journalctl -b 0 -p err --no-pager

# Show only errors from the previous boot
logs-errors-last:
    @echo "Errors from previous boot session:"
    @echo ""
    journalctl -b -1 -p err --no-pager

# Run a 60-second system benchmark (CPU + Memory)
benchmark:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v stress-ng &>/dev/null; then
        echo "stress-ng not found. Installing via micromamba..."
        if command -v micromamba &>/dev/null; then
            micromamba install -n base -c conda-forge -y stress-ng 2>/dev/null || true
        fi
        if ! command -v stress-ng &>/dev/null; then
            echo "Could not install stress-ng. Install it manually:"
            echo "  micromamba install -n base -c conda-forge stress-ng"
            echo "  -- or --"
            echo "  distrobox enter alma -- sudo dnf install stress-ng"
            exit 1
        fi
    fi
    CPUS=$(nproc)
    echo "=== Querencia Linux — System Benchmark ==="
    echo "CPUs: ${CPUS} | Duration: 60 seconds"
    echo "Press Ctrl+C to cancel"
    echo ""
    echo "Starting benchmark..."
    echo ""
    stress-ng --cpu "${CPUS}" --vm 1 --vm-bytes 75% --timeout 60s --metrics-brief
    echo ""
    echo "Benchmark complete."

# Check idle power consumption (requires powerstat or turbostat)
check-idle-power:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v powerstat &>/dev/null; then
        echo "Measuring idle power draw (30 seconds, 10 samples)..."
        echo "Keep the system idle during measurement."
        echo ""
        sudo powerstat -d 0 -n 10 -s 3
    elif command -v turbostat &>/dev/null; then
        echo "Measuring with turbostat (10 seconds)..."
        echo ""
        sudo turbostat --quiet --show PkgWatt,CorWatt,GFXWatt --interval 2 --num_iterations 5
    else
        echo "No power measurement tool found."
        echo "Reading from RAPL (if available)..."
        echo ""
        if [ -d /sys/class/powercap/intel-rapl:0 ]; then
            E1=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)
            sleep 5
            E2=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)
            WATTS=$(echo "scale=2; ($E2 - $E1) / 5000000" | bc)
            echo "Estimated package power: ${WATTS} W (5-second average)"
        else
            echo "RAPL not available. Try installing powerstat:"
            echo "  micromamba install -n base -c conda-forge powerstat"
        fi
    fi

# Show files that differ between system defaults (/usr/etc) and local overrides (/etc)
check-local-overrides:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking for local overrides (/etc vs /usr/etc)..."
    echo ""
    if [ ! -d /usr/etc ]; then
        echo "No /usr/etc found — this system may not use the /usr/etc pattern."
        echo ""
        echo "Showing non-default files in /etc owned by no package:"
        rpm -Va --nofiles --nodigest 2>/dev/null | head -30 || echo "  (rpm verification not available)"
        exit 0
    fi
    FOUND=0
    while IFS= read -r -d '' usretc_file; do
        etc_file="/etc${usretc_file#/usr/etc}"
        if [ -f "${etc_file}" ]; then
            if ! diff -q "${usretc_file}" "${etc_file}" &>/dev/null; then
                if [ "${FOUND}" -eq 0 ]; then
                    echo "Modified files (local overrides):"
                    echo ""
                fi
                FOUND=$((FOUND + 1))
                echo "  ${etc_file}"
                echo "    (differs from ${usretc_file})"
            fi
        fi
    done < <(find /usr/etc -type f -print0 2>/dev/null)
    if [ "${FOUND}" -eq 0 ]; then
        echo "No local overrides found. System is using all defaults."
    else
        echo ""
        echo "${FOUND} file(s) with local overrides."
        echo ""
        echo "To inspect a specific file:"
        echo "  diff /usr/etc/<path> /etc/<path>"
    fi
