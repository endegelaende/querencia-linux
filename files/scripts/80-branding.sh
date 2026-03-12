#!/usr/bin/env bash
# Querencia Linux -- Branding
# Keep ID=almalinux so bootc tools can identify the base.
set -xeuo pipefail

rm -f /etc/os-release /usr/lib/os-release
printf '%s\n' \
    'NAME="Querencia Linux"' \
    'VERSION="10"' \
    'ID=almalinux' \
    'ID_LIKE="almalinux centos rhel fedora"' \
    'VERSION_ID="10"' \
    'PLATFORM_ID="platform:el10"' \
    'PRETTY_NAME="Querencia Linux 10 -- Where Linux Feels at Home"' \
    'ANSI_COLOR="0;34"' \
    'CPE_NAME="cpe:/o:almalinux:almalinux:10"' \
    'HOME_URL="https://github.com/endegelaende/querencia-linux"' \
    'BUG_REPORT_URL="https://github.com/endegelaende/querencia-linux/issues"' \
    'VARIANT="MATE Desktop"' \
    'VARIANT_ID=mate' \
    > /usr/lib/os-release
ln -sf ../usr/lib/os-release /etc/os-release

# /etc/issue -- text console login prompt
printf '%s\n' \
    '' \
    '  Querencia Linux 10 (MATE)' \
    '  Where Linux Feels at Home' \
    '' \
    > /etc/issue
