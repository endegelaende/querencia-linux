#!/usr/bin/env bash
# Querencia Linux -- PipeWire Audio
set -xeuo pipefail

dnf install -y \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    pipewire-utils \
    wireplumber \
    pavucontrol

# PipeWire is a user service (started per user session)
systemctl --global enable pipewire.socket || true
systemctl --global enable pipewire-pulse.socket || true
systemctl --global enable wireplumber.service || true
