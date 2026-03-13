#!/usr/bin/env bash
# Querencia Linux -- Printing & Scanning Support (CUPS + SANE)
set -xeuo pipefail

# CUPS print server, filters, and PolicyKit helper for unprivileged management
dnf install -y \
    cups \
    cups-filters \
    cups-pk-helper \
    system-config-printer

# Extra printer drivers and PPD database (optional, not in all repos)
dnf install -y gutenprint-cups || true
dnf install -y foomatic-db || true
dnf install -y foomatic-db-ppds || true

# Scanner support (SANE backends for USB/network scanners)
# Hardware drivers must be in the base image -- scanner apps come via Flatpak
dnf install -y sane-backends || true
dnf install -y sane-backends-drivers-scanners || true

# Socket-activated: CUPS only starts when a print job arrives or the UI connects
systemctl enable cups.socket
