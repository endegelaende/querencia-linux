#!/usr/bin/env bash
# Querencia Linux -- System Tools & Utilities
set -xeuo pipefail

dnf install -y \
    firefox \
    gnome-disk-utility \
    gnome-keyring \
    xdg-utils \
    xdg-user-dirs \
    xdg-user-dirs-gtk \
    bash-completion \
    vim-enhanced \
    htop \
    wget \
    curl \
    git

# Optional tools (may not be in all repos)
dnf install -y fastfetch || true
dnf install -y just || true
