#!/usr/bin/env bash
# Querencia Linux -- Flatpak + Flathub
# Installs Flatpak and configures Flathub remote.
# Warehouse (Flatpak Store GUI) is installed per-user at first boot.
set -xeuo pipefail

dnf install -y flatpak

flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# Update appstream metadata so Warehouse has catalog data on first launch
flatpak update --appstream 2>/dev/null || true
