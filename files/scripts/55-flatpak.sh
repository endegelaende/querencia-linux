#!/usr/bin/env bash
# Querencia Linux -- Flatpak + Flathub
set -xeuo pipefail

dnf install -y flatpak

flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
