#!/usr/bin/env bash
# Querencia Linux -- Network & Bluetooth
set -xeuo pipefail

dnf install -y \
    NetworkManager \
    NetworkManager-wifi \
    NetworkManager-openvpn \
    network-manager-applet \
    bluez \
    blueman \
    firewalld

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable firewalld
