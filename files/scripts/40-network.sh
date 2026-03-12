#!/usr/bin/env bash
# Querencia Linux -- Network & Bluetooth
set -xeuo pipefail

dnf install -y \
    NetworkManager \
    NetworkManager-wifi \
    NetworkManager-openvpn \
    network-manager-applet \
    bluez \
    blueman

systemctl enable NetworkManager
systemctl enable bluetooth
