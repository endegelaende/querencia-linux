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
    firewalld \
    firewall-config \
    samba-client \
    cifs-utils

# WireGuard VPN (modern, fast VPN — kernel module is built-in since Linux 5.6)
dnf install -y wireguard-tools || true

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable firewalld

# Allow Samba client traffic (NetBIOS browsing) so Caja "Network" shows SMB shares
firewall-offline-cmd --add-service=samba-client
