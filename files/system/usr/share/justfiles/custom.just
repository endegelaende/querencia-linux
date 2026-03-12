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
    flatpak install -y flathub org.mozilla.firefox
    flatpak install -y flathub org.mozilla.Thunderbird
    flatpak install -y flathub org.libreoffice.LibreOffice
    flatpak install -y flathub org.gnome.Calculator
    flatpak install -y flathub org.gnome.Evince
    flatpak install -y flathub com.github.tchx84.Flatseal
    flatpak install -y flathub io.github.celluloid_player.Celluloid
    @echo "Essential apps installed."

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
    distrobox create --name alma --image quay.io/almalinux/almalinux:10 --yes
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
# AMD GPU (RX 6600 / RDNA 2)
# =============================================================================

# Show AMD GPU info (driver, Vulkan, VA-API)
gpu-info:
    @echo "AMD GPU Information:"
    @echo ""
    @echo "-- Kernel driver --"
    lsmod | grep -i amdgpu
    @echo ""
    @echo "-- GPU hardware --"
    lspci -k | grep -A3 -i vga
    @echo ""
    @echo "-- Mesa / OpenGL --"
    glxinfo | grep -i "opengl renderer\|opengl version" 2>/dev/null || echo "(glxinfo not available -- install mesa-demos)"
    @echo ""
    @echo "-- Vulkan --"
    vulkaninfo --summary 2>/dev/null || echo "(vulkaninfo not available)"
    @echo ""
    @echo "-- VA-API (hardware video) --"
    vainfo 2>/dev/null || echo "(vainfo not available)"

# Live AMD GPU monitoring (temperature, clock, utilization, VRAM)
gpu-monitor:
    @echo "AMD GPU Monitor (Ctrl+C to exit):"
    @echo ""
    watch -n 1 'echo "-- GPU Busy --" && cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null && echo "%" && echo "" && echo "-- Temperature --" && cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | awk "{printf \"%.1f C\n\", \$1/1000}" && echo "" && echo "-- VRAM --" && echo "Used: $(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | awk "{printf \"%.0f MB\", \$1/1048576}") / Total: $(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | awk "{printf \"%.0f MB\", \$1/1048576}")" && echo "" && echo "-- Clock --" && cat /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null | grep "\*" && echo "" && echo "-- Power --" && cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | awk "{printf \"%.1f W\n\", \$1/1000000}"'

# Show AMD GPU sensor readings (one-shot)
gpu-sensors:
    @echo "AMD GPU Sensors:"
    @echo ""
    @echo "-- Temperature --"
    @cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | awk '{printf "GPU: %.1f C\n", $$1/1000}' || echo "Not available"
    @echo ""
    @echo "-- VRAM Usage --"
    @echo "Used:  $$(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | awk '{printf "%.0f MB", $$1/1048576}')"
    @echo "Total: $$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | awk '{printf "%.0f MB", $$1/1048576}')"
    @echo ""
    @echo "-- Utilization --"
    @echo "GPU Busy: $$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)%"
    @echo ""
    @echo "-- Power --"
    @cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | awk '{printf "Draw: %.1f W\n", $$1/1000000}' || echo "Not available"

# Set GPU power profile to performance
gpu-performance:
    @echo "GPU power profile -> Performance"
    echo "high" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
    @echo "Performance mode active."

# Set GPU power profile to power saving
gpu-powersave:
    @echo "GPU power profile -> Power Save"
    echo "low" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
    @echo "Power save mode active."

# Set GPU power profile to automatic
gpu-auto:
    @echo "GPU power profile -> Auto"
    echo "auto" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
    @echo "Auto mode active."

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

# =============================================================================
# Micromamba (user-space package manager)
# =============================================================================

# Initialize micromamba (first time setup)
mamba-setup:
    @echo "Setting up micromamba..."
    @if [ ! -d "${HOME}/micromamba" ]; then \
        micromamba shell init --shell bash --root-prefix "${HOME}/micromamba"; \
        echo "Micromamba initialized."; \
        echo "  Restart your terminal or run: source ~/.bashrc"; \
    else \
        echo "Micromamba is already set up (${HOME}/micromamba)"; \
    fi

# Create a 'tools' environment with useful CLI tools
mamba-install-tools:
    @echo "Creating 'tools' environment with CLI tools..."
    micromamba create -n tools -c conda-forge -y \
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
    @echo "'tools' environment created."
    @echo "  Activate with: micromamba activate tools"
    @echo "  Make permanent: echo 'micromamba activate tools' >> ~/.bashrc"

# Create a new empty environment
mamba-create name:
    @echo "Creating environment '{{name}}'..."
    micromamba create -n {{name}} -c conda-forge -y
    @echo "Environment '{{name}}' created. Activate: micromamba activate {{name}}"

# Install package(s) in the active environment
mamba-install +packages:
    @echo "Installing: {{packages}}"
    micromamba install -c conda-forge -y {{packages}}

# List all environments
mamba-list:
    @echo "Micromamba environments:"
    @echo ""
    micromamba env list

# List packages in the active environment
mamba-packages:
    @echo "Installed packages:"
    micromamba list

# Update all packages in the active environment
mamba-update:
    @echo "Updating active environment..."
    micromamba update --all -y
    @echo "Environment updated."

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
