#!/usr/bin/env bash
# Querencia Linux -- Branding
# Keep ID=almalinux so bootc tools can identify the base.
set -xeuo pipefail

# Determine GPU label from VARIANT env var (set by Containerfile ARG)
case "${VARIANT:-}" in
    ""|amd)
        GPU_LABEL="AMD"
        ;;
    nvidia)
        GPU_LABEL="NVIDIA"
        ;;
    *)
        echo "ERROR: Unknown VARIANT '${VARIANT}' — expected '', 'amd', or 'nvidia'"
        exit 1
        ;;
esac

rm -f /etc/os-release /usr/lib/os-release
printf '%s\n' \
    'NAME="Querencia Linux"' \
    'VERSION="10"' \
    'ID=almalinux' \
    'ID_LIKE="almalinux centos rhel fedora"' \
    'VERSION_ID="10"' \
    'PLATFORM_ID="platform:el10"' \
    "PRETTY_NAME=\"Querencia Linux 10 (${GPU_LABEL}) -- Where Linux Feels at Home\"" \
    'ANSI_COLOR="0;34"' \
    'CPE_NAME="cpe:/o:almalinux:almalinux:10"' \
    'HOME_URL="https://github.com/endegelaende/querencia-linux"' \
    'BUG_REPORT_URL="https://github.com/endegelaende/querencia-linux/issues"' \
    'LOGO=almalinux' \
    > /usr/lib/os-release
# Note: VARIANT_ID is set by 91-image-info.sh (template) — do not set it here.
ln -sf ../usr/lib/os-release /etc/os-release

# /etc/issue -- text console login prompt
printf '%s\n' \
    '' \
    "  Querencia Linux 10 (MATE / ${GPU_LABEL})" \
    '  Where Linux Feels at Home' \
    '' \
    > /etc/issue

# ---- Image metadata (machine-readable) ----
mkdir -p /usr/share/querencia
cat > /usr/share/querencia/image-info.json <<EOF
{
  "image-name": "querencia-linux${VARIANT:+-$VARIANT}",
  "image-vendor": "endegelaende",
  "image-ref": "ghcr.io/endegelaende/querencia-linux${VARIANT:+-$VARIANT}",
  "image-tag": "latest",
  "base-image": "quay.io/almalinuxorg/almalinux-bootc:10",
  "desktop": "mate",
  "gpu-variant": "${GPU_LABEL}",
  "build-date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
