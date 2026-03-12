#!/usr/bin/env bash
# Querencia Linux -- Enable systemd services
set -xeuo pipefail

systemctl enable fstrim.timer
