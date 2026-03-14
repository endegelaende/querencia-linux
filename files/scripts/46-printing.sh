#!/usr/bin/env bash
# Querencia Linux -- Printing & Scanning Support (CUPS + SANE)
set -xeuo pipefail

# CUPS print server, filters, and PolicyKit helper for unprivileged management
dnf install -y \
    cups \
    cups-filters \
    cups-pk-helper \
    system-config-printer \
    avahi \
    nss-mdns

# Enable mDNS name resolution (.local hostnames) in nsswitch.conf.
# mdns4_minimal: only IPv4, only .local domain -- minimal and safe.
# [NOTFOUND=return]: don't fall through to DNS for .local queries (avoids delays).
# This enables: ping printer.local, ssh pi.local, etc.
if [ -f /etc/nsswitch.conf ]; then
    if ! grep -q 'mdns4_minimal' /etc/nsswitch.conf; then
        sed -i 's/^hosts:\s*files/hosts:      files mdns4_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
        echo "nsswitch.conf: added mdns4_minimal to hosts line"
    else
        echo "nsswitch.conf: mdns4_minimal already configured"
    fi
fi

# Extra printer drivers and PPD database (optional, not in all repos)
dnf install -y gutenprint-cups || true
dnf install -y foomatic-db || true
dnf install -y foomatic-db-ppds || true

# Scanner support (SANE backends for USB/network scanners)
# Hardware drivers must be in the base image -- scanner apps come via Flatpak
dnf install -y sane-backends || true
dnf install -y sane-backends-drivers-scanners || true

# Socket-activated: CUPS only starts when a print job arrives or the UI connects
# Note: cups.socket is enabled via systemd preset in 75-post-install.sh
# mDNS/DNS-SD for automatic network printer discovery
systemctl enable avahi-daemon.service
