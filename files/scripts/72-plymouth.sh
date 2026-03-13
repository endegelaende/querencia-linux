#!/usr/bin/env bash
# Querencia Linux -- Plymouth Boot Splash
# Installs Plymouth and creates a custom theme with the Querencia logo.
set -xeuo pipefail

# Install Plymouth and basic themes (provides the spinner plugin)
dnf install -y plymouth plymouth-system-theme plymouth-plugin-two-step || true

# ---- Create Querencia Plymouth Theme -----------------------------------------
THEME_DIR="/usr/share/plymouth/themes/querencia"
mkdir -p "${THEME_DIR}"

# Convert SVG logo to PNG at build time (rsvg-convert comes from librsvg2-tools)
dnf install -y librsvg2-tools || true

LOGO_SVG="/tmp/querencia-logo.svg"
CONTEXT_PATH="$(realpath "$(dirname "$0")/..")"

# The logo SVG is in the build context under assets/
if [ -f "${CONTEXT_PATH}/../assets/querencia-logo.svg" ]; then
    cp "${CONTEXT_PATH}/../assets/querencia-logo.svg" "${LOGO_SVG}"
elif [ -f "/assets/querencia-logo.svg" ]; then
    cp "/assets/querencia-logo.svg" "${LOGO_SVG}"
fi

if [ -f "${LOGO_SVG}" ] && command -v rsvg-convert &>/dev/null; then
    # Main logo: 460px wide (suitable for center screen)
    rsvg-convert -w 460 -h 86 "${LOGO_SVG}" -o "${THEME_DIR}/logo.png"
    # Watermark (smaller, for bottom of screen)
    rsvg-convert -w 230 -h 43 "${LOGO_SVG}" -o "${THEME_DIR}/watermark.png"
else
    echo "WARNING: Could not convert logo SVG to PNG (rsvg-convert missing or no SVG found)"
    echo "Plymouth theme will work but without logo"
fi

# ---- Theme descriptor --------------------------------------------------------
cat > "${THEME_DIR}/querencia.plymouth" <<'PLYMOUTH'
[Plymouth Theme]
Name=Querencia Linux
Description=Querencia Linux boot splash — "Where Linux Feels at Home"
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/querencia
HorizontalAlignment=.5
VerticalAlignment=.5
Transition=none
TransitionDuration=0.0
BackgroundStartColor=0x1a1a1a
BackgroundEndColor=0x1a1a1a
PLYMOUTH

# ---- Spinner animation frames (simple throbber) -----------------------------
# We generate a simple spinner using ImageMagick if available,
# otherwise fall back to Plymouth's built-in spinner assets.
if command -v convert &>/dev/null; then
    # Create 36 frames of a spinning arc (10° per frame)
    for i in $(seq 0 35); do
        angle=$((i * 10))
        convert -size 48x48 xc:transparent \
            -stroke '#C75230' -strokewidth 3 -fill none \
            -draw "arc 4,4 44,44 ${angle},$((angle + 90))" \
            "${THEME_DIR}/throbber-$(printf '%04d' $i).png" 2>/dev/null || break
    done
fi

# If we couldn't generate spinner frames, symlink from the built-in spinner theme
if [ ! -f "${THEME_DIR}/throbber-0000.png" ]; then
    SPINNER_SRC="/usr/share/plymouth/themes/spinner"
    if [ -d "${SPINNER_SRC}" ]; then
        for f in "${SPINNER_SRC}"/throbber-*.png; do
            [ -f "$f" ] && ln -sf "$f" "${THEME_DIR}/$(basename "$f")"
        done
        # Also grab animation and lock images if present
        for f in "${SPINNER_SRC}"/animation-*.png "${SPINNER_SRC}"/lock.png; do
            [ -f "$f" ] && ln -sf "$f" "${THEME_DIR}/$(basename "$f")"
        done
    fi
fi

# ---- Set as default theme ----------------------------------------------------
plymouth-set-default-theme querencia 2>/dev/null || true

# Update initramfs to include the Plymouth theme
# On bootc systems this ensures the theme is in the boot image
if command -v dracut &>/dev/null; then
    # Find the current kernel version
    KVER=$(ls /lib/modules/ | sort -V | tail -1)
    if [ -n "${KVER}" ]; then
        dracut --force --kver "${KVER}" 2>/dev/null || true
    fi
fi

echo "Plymouth theme 'querencia' installed and set as default."
