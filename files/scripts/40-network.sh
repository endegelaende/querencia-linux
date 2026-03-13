#!/usr/bin/env bash
# Querencia Linux -- Network & Bluetooth
set -xeuo pipefail

dnf install -y \
    NetworkManager \
    NetworkManager-wifi \
    NetworkManager-openvpn \
    NetworkManager-openvpn-gnome \
    network-manager-applet \
    bluez \
    blueman \
    firewalld

# WireGuard VPN (modern, fast VPN — kernel module is built-in since Linux 5.6)
dnf install -y wireguard-tools || true
dnf install -y NetworkManager-wireguard || true

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable firewalld
