#!/usr/bin/env bash
# Querencia Linux -- Build-time Verification Tests
# =============================================================================
# Runs after all installation and configuration scripts (10-*.sh through 88-*.sh).
# Validates that the image was built correctly before signing and cleanup.
#
# Checks:
#   - Required packages are installed
#   - Unwanted packages are NOT installed
#   - Systemd service presets are configured
#   - Critical files and directories exist
#   - GPU-variant-specific configuration is correct
#
# If any check fails, the script exits 1 and the build is aborted.
# =============================================================================
set -xeuo pipefail

echo "=== Querencia Linux Build-time Tests ==="
echo ""

FAILURES=0

check_pass() { echo "  PASS: $1"; }
check_fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Determine GPU variant (same logic as 30-gpu.sh, 80-branding.sh, 85-gpu-tuning.sh)
VARIANT="${VARIANT:-}"

# =============================================================================
# Package Presence — these MUST be installed
# =============================================================================
echo "=== Package Presence ==="

# MATE Desktop core
for pkg in mate-desktop caja marco mate-panel mate-session-manager; do
    rpm -q "$pkg" &>/dev/null && check_pass "$pkg installed" || check_fail "$pkg NOT installed"
done

# Display manager
# Note: The COPR RPM is named 'lightdm-gtk' (not 'lightdm-gtk-greeter').
# It provides the lightdm-gtk-greeter binary but the package name differs.
for pkg in lightdm lightdm-gtk; do
    rpm -q "$pkg" &>/dev/null && check_pass "$pkg installed" || check_fail "$pkg NOT installed"
done

# Browser (only GUI app in base image)
rpm -q firefox &>/dev/null && check_pass "firefox installed" || check_fail "firefox NOT installed"

# Flatpak
rpm -q flatpak &>/dev/null && check_pass "flatpak installed" || check_fail "flatpak NOT installed"

# Container tools
for pkg in podman distrobox; do
    rpm -q "$pkg" &>/dev/null && check_pass "$pkg installed" || check_fail "$pkg NOT installed"
done

# Audio (PipeWire)
for pkg in pipewire wireplumber; do
    rpm -q "$pkg" &>/dev/null && check_pass "$pkg installed" || check_fail "$pkg NOT installed"
done

# Network
rpm -q NetworkManager &>/dev/null && check_pass "NetworkManager installed" || check_fail "NetworkManager NOT installed"
rpm -q samba-client &>/dev/null && check_pass "samba-client installed" || check_fail "samba-client NOT installed"

# Printing
rpm -q cups &>/dev/null && check_pass "cups installed" || check_fail "cups NOT installed"

# Boot splash
rpm -q plymouth &>/dev/null && check_pass "plymouth installed" || check_fail "plymouth NOT installed"

# Atomic/immutable core
rpm -q bootc &>/dev/null && check_pass "bootc installed" || check_fail "bootc NOT installed"

# Hardware support for udev rules (Apple SuperDrive)
rpm -q sg3_utils &>/dev/null && check_pass "sg3_utils installed" || check_fail "sg3_utils NOT installed"

# usb_modeswitch (Realtek USB Ethernet docks) — optional, may not exist in EL10 repos
rpm -q usb_modeswitch &>/dev/null && check_pass "usb_modeswitch installed" || check_pass "usb_modeswitch not available (optional on EL10)"

echo ""

# =============================================================================
# Package Absence — these must NOT be installed
# =============================================================================
echo "=== Package Absence ==="

# dnfdragora is useless on immutable systems (no dnf install from desktop)
# and confuses users by offering a GUI package manager that can't work
rpm -q dnfdragora &>/dev/null && check_fail "dnfdragora is installed (should be absent)" || check_pass "dnfdragora not installed"

echo ""

# =============================================================================
# ZRAM — essential for desktop responsiveness
# =============================================================================
echo "=== ZRAM Configuration ==="

rpm -q zram-generator &>/dev/null && check_pass "zram-generator installed" || check_fail "zram-generator NOT installed"

ZRAM_CONF="/usr/lib/systemd/zram-generator.conf.d/querencia.conf"
if [ -f "$ZRAM_CONF" ]; then
    check_pass "$ZRAM_CONF exists"
    if grep -q "zram-size = ram / 2" "$ZRAM_CONF"; then
        check_pass "ZRAM size set to 50% of RAM"
    else
        check_fail "ZRAM size NOT set to 50% of RAM"
    fi
    if grep -q "compression-algorithm = zstd" "$ZRAM_CONF"; then
        check_pass "ZRAM compression set to zstd"
    else
        check_fail "ZRAM compression NOT set to zstd"
    fi
else
    check_fail "$ZRAM_CONF MISSING"
fi

echo ""

# =============================================================================
# Systemd Service Presets — verify expected services are enabled
# =============================================================================
echo "=== Systemd Service Presets ==="

# Check that the preset file exists and contains expected entries
PRESET_FILE="/usr/lib/systemd/system-preset/50-querencia-linux.preset"
if [ -f "$PRESET_FILE" ]; then
    check_pass "preset file exists: $PRESET_FILE"

    for service in lightdm.service NetworkManager.service bluetooth.service firewalld.service; do
        grep -q "enable ${service}" "$PRESET_FILE" && \
            check_pass "$service in preset file" || \
            check_fail "$service NOT in preset file"
    done

    # cups.socket (socket-activated, not cups.service)
    grep -q "enable cups.socket" "$PRESET_FILE" && \
        check_pass "cups.socket in preset file" || \
        check_fail "cups.socket NOT in preset file"

    # fstrim.timer (periodic SSD TRIM)
    grep -q "enable fstrim.timer" "$PRESET_FILE" && \
        check_pass "fstrim.timer in preset file" || \
        check_fail "fstrim.timer NOT in preset file"
else
    check_fail "preset file MISSING: $PRESET_FILE"
fi

# Verify services that are enabled directly by scripts (not via preset file)
# These use 'systemctl enable' in their respective install scripts.

# flatpak-init-repo.service (55-flatpak.sh)
FLATPAK_INIT="/usr/lib/systemd/system/flatpak-init-repo.service"
if [ -f "$FLATPAK_INIT" ]; then
    check_pass "flatpak-init-repo.service unit file exists"
else
    check_fail "flatpak-init-repo.service unit file MISSING"
fi

# querencia-auto-update.timer (75-post-install.sh)
if [ -f "/usr/lib/systemd/system/querencia-auto-update.timer" ]; then
    check_pass "querencia-auto-update.timer unit file exists"
else
    check_fail "querencia-auto-update.timer unit file MISSING"
fi

# querencia-first-boot-setup.service (75-post-install.sh, user service)
if [ -f "/usr/lib/systemd/user/querencia-first-boot-setup.service" ]; then
    check_pass "querencia-first-boot-setup.service user unit exists"
else
    check_fail "querencia-first-boot-setup.service user unit MISSING"
fi

echo ""

# =============================================================================
# Critical File Checks
# =============================================================================
echo "=== Critical Files ==="

# os-release must mention Querencia
if [ -f /etc/os-release ]; then
    if grep -q "Querencia" /etc/os-release; then
        check_pass "/etc/os-release contains 'Querencia'"
    else
        check_fail "/etc/os-release does NOT contain 'Querencia'"
        echo "         Content: $(head -3 /etc/os-release)"
    fi
else
    check_fail "/etc/os-release MISSING"
fi

# Flatpak Flathub remote config (static, survives /var wipe)
FLATHUB_REMOTE="/usr/lib/flatpak/remotes.d/flathub.flatpakrepo"
if [ -f "$FLATHUB_REMOTE" ]; then
    check_pass "$FLATHUB_REMOTE exists"
else
    check_fail "$FLATHUB_REMOTE MISSING"
fi

# Plymouth theme directory
PLYMOUTH_DIR="/usr/share/plymouth/themes/querencia"
if [ -d "$PLYMOUTH_DIR" ]; then
    check_pass "$PLYMOUTH_DIR/ directory exists"
    # Check for the theme descriptor
    if [ -f "${PLYMOUTH_DIR}/querencia.plymouth" ]; then
        check_pass "querencia.plymouth theme descriptor exists"
    else
        check_fail "querencia.plymouth theme descriptor MISSING"
    fi
else
    check_fail "$PLYMOUTH_DIR/ directory MISSING"
fi

# ujust justfile
JUSTFILE="/usr/share/justfiles/custom.just"
if [ -f "$JUSTFILE" ]; then
    check_pass "$JUSTFILE exists"
else
    check_fail "$JUSTFILE MISSING"
fi

# ujust wrapper script
if [ -x "/usr/bin/ujust" ]; then
    check_pass "/usr/bin/ujust exists and is executable"
else
    check_fail "/usr/bin/ujust MISSING or not executable"
fi

# First-boot script
if [ -x "/usr/libexec/querencia-first-boot" ]; then
    check_pass "/usr/libexec/querencia-first-boot exists and is executable"
else
    check_fail "/usr/libexec/querencia-first-boot MISSING or not executable"
fi

# Auto-update script
if [ -x "/usr/libexec/querencia-auto-update" ]; then
    check_pass "/usr/libexec/querencia-auto-update exists and is executable"
else
    check_fail "/usr/libexec/querencia-auto-update MISSING or not executable"
fi

# Micromamba binary
if [ -x "/usr/bin/micromamba" ]; then
    check_pass "/usr/bin/micromamba exists and is executable"
else
    check_fail "/usr/bin/micromamba MISSING or not executable"
fi

# dconf profile (needed for MATE defaults to take effect)
if [ -f "/etc/dconf/profile/user" ]; then
    check_pass "/etc/dconf/profile/user exists"
else
    check_fail "/etc/dconf/profile/user MISSING"
fi

# MATE dconf defaults
if [ -f "/etc/dconf/db/local.d/01-mate-defaults.conf" ]; then
    check_pass "MATE dconf defaults exist"
else
    check_fail "MATE dconf defaults MISSING"
fi

# LightDM configuration
if [ -f "/etc/lightdm/lightdm.conf" ]; then
    check_pass "/etc/lightdm/lightdm.conf exists"
else
    check_fail "/etc/lightdm/lightdm.conf MISSING"
fi

# Polkit rules (wheel group Flatpak access)
if [ -f "/usr/lib/polkit-1/rules.d/50-querencia-linux.rules" ]; then
    check_pass "polkit rules exist"
else
    check_fail "polkit rules MISSING"
fi

# Sysctl tweaks (ZRAM swappiness, inotify, BBR)
if [ -f "/usr/lib/sysctl.d/99-querencia-linux-desktop.conf" ]; then
    check_pass "sysctl desktop tweaks exist"
else
    check_fail "sysctl desktop tweaks MISSING"
fi

# Welcome app
if [ -f "/usr/lib/querencia/welcome/querencia-welcome.py" ]; then
    check_pass "querencia-welcome.py exists"
else
    check_fail "querencia-welcome.py MISSING"
fi

if [ -x "/usr/bin/querencia-welcome" ]; then
    check_pass "/usr/bin/querencia-welcome exists and is executable"
else
    check_fail "/usr/bin/querencia-welcome MISSING or not executable"
fi

if [ -x "/usr/bin/querencia-welcome-launcher" ]; then
    check_pass "/usr/bin/querencia-welcome-launcher exists and is executable"
else
    check_fail "/usr/bin/querencia-welcome-launcher MISSING or not executable"
fi

if [ -f "/etc/xdg/autostart/querencia-welcome.desktop" ]; then
    check_pass "querencia-welcome autostart desktop entry exists"
else
    check_fail "querencia-welcome autostart desktop entry MISSING"
fi

if [ -f "/usr/share/applications/querencia-welcome.desktop" ]; then
    check_pass "querencia-welcome application menu entry exists"
else
    check_fail "querencia-welcome application menu entry MISSING"
fi

echo ""

# =============================================================================
# GPU-Variant Checks
# =============================================================================
echo "=== GPU-Variant Checks (VARIANT='${VARIANT:-<empty/AMD>}') ==="

case "${VARIANT}" in

nvidia)
    echo "  Checking NVIDIA-specific configuration..."

    # NVIDIA modprobe config (nouveau blacklist + nvidia-drm modeset)
    if [ -f "/usr/lib/modprobe.d/nvidia.conf" ]; then
        check_pass "/usr/lib/modprobe.d/nvidia.conf exists"
        if grep -q "blacklist nouveau" /usr/lib/modprobe.d/nvidia.conf; then
            check_pass "nouveau blacklisted in nvidia.conf"
        else
            check_fail "nouveau NOT blacklisted in nvidia.conf"
        fi
        if grep -q "nvidia-drm modeset=1" /usr/lib/modprobe.d/nvidia.conf; then
            check_pass "nvidia-drm modeset=1 set in nvidia.conf"
        else
            check_fail "nvidia-drm modeset=1 NOT set in nvidia.conf"
        fi
    else
        check_fail "/usr/lib/modprobe.d/nvidia.conf MISSING"
    fi

    # NVIDIA modules-load.d config
    if [ -f "/usr/lib/modules-load.d/nvidia.conf" ]; then
        check_pass "/usr/lib/modules-load.d/nvidia.conf exists"
        for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
            if grep -q "^${mod}$" /usr/lib/modules-load.d/nvidia.conf; then
                check_pass "module $mod in modules-load.d/nvidia.conf"
            else
                check_fail "module $mod NOT in modules-load.d/nvidia.conf"
            fi
        done
    else
        check_fail "/usr/lib/modules-load.d/nvidia.conf MISSING"
    fi

    # bootc kernel args (nouveau blacklist at initramfs level)
    if [ -f "/usr/lib/bootc/kargs.d/00-nvidia.toml" ]; then
        check_pass "/usr/lib/bootc/kargs.d/00-nvidia.toml exists"
        if grep -q "modprobe.blacklist=nouveau" /usr/lib/bootc/kargs.d/00-nvidia.toml; then
            check_pass "nouveau blacklisted in bootc kargs"
        else
            check_fail "nouveau NOT blacklisted in bootc kargs"
        fi
    else
        check_fail "/usr/lib/bootc/kargs.d/00-nvidia.toml MISSING"
    fi

    # NVIDIA packages
    for pkg in nvidia-open-kmod nvidia-driver; do
        rpm -q "$pkg" &>/dev/null && check_pass "$pkg installed" || check_fail "$pkg NOT installed"
    done

    # AMD config should NOT exist in NVIDIA variant
    if [ -f "/usr/lib/modprobe.d/amdgpu.conf" ]; then
        check_fail "/usr/lib/modprobe.d/amdgpu.conf exists in NVIDIA variant (unexpected)"
    else
        check_pass "no amdgpu.conf in NVIDIA variant (correct)"
    fi

    # os-release should mention NVIDIA
    if grep -q "NVIDIA" /etc/os-release; then
        check_pass "os-release contains NVIDIA label"
    else
        check_fail "os-release does NOT contain NVIDIA label"
    fi
    ;;

""|amd)
    echo "  Checking AMD-specific configuration..."

    # AMD modprobe config (ppfeaturemask for power management)
    if [ -f "/usr/lib/modprobe.d/amdgpu.conf" ]; then
        check_pass "/usr/lib/modprobe.d/amdgpu.conf exists"
        if grep -q "ppfeaturemask=0xffffffff" /usr/lib/modprobe.d/amdgpu.conf; then
            check_pass "ppfeaturemask=0xffffffff set"
        else
            check_fail "ppfeaturemask=0xffffffff NOT set in amdgpu.conf"
        fi
    else
        check_fail "/usr/lib/modprobe.d/amdgpu.conf MISSING"
    fi

    # AMD modules-load.d config
    if [ -f "/usr/lib/modules-load.d/amdgpu.conf" ]; then
        check_pass "/usr/lib/modules-load.d/amdgpu.conf exists"
    else
        check_fail "/usr/lib/modules-load.d/amdgpu.conf MISSING"
    fi

    # NVIDIA config should NOT exist in AMD variant
    if [ -f "/usr/lib/modprobe.d/nvidia.conf" ]; then
        check_fail "/usr/lib/modprobe.d/nvidia.conf exists in AMD variant (unexpected)"
    else
        check_pass "no nvidia.conf in AMD variant (correct)"
    fi
    if [ -f "/usr/lib/bootc/kargs.d/00-nvidia.toml" ]; then
        check_fail "00-nvidia.toml exists in AMD variant (unexpected)"
    else
        check_pass "no 00-nvidia.toml in AMD variant (correct)"
    fi

    # Mesa packages (AMD userspace)
    for pkg in mesa-dri-drivers mesa-vulkan-drivers mesa-libGL; do
        rpm -q "$pkg" &>/dev/null && check_pass "$pkg installed" || check_fail "$pkg NOT installed"
    done

    # os-release should mention AMD
    if grep -q "AMD" /etc/os-release; then
        check_pass "os-release contains AMD label"
    else
        check_fail "os-release does NOT contain AMD label"
    fi
    ;;

*)
    check_fail "Unknown VARIANT '${VARIANT}' — cannot validate GPU configuration"
    ;;

esac

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "==========================================="
echo "  Tests complete: $FAILURES failure(s)"
echo "==========================================="
echo ""

if [[ $FAILURES -gt 0 ]]; then
    echo "FATAL: $FAILURES test(s) failed. Aborting build."
    echo "Review the FAIL lines above to identify what went wrong."
    exit 1
fi

echo "All tests passed. Image is ready for signing and cleanup."
