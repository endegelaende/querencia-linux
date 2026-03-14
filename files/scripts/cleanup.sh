#!/usr/bin/env bash

set -xeuo pipefail

# Image cleanup
# Specifically called by build.sh

# Image-layer cleanup
shopt -s extglob

dnf clean all

rm -rf /.gitkeep /boot

# Remove /var contents but skip /var/cache/dnf which is a bind-mount
# during the build (--mount=type=cache,dst=/var/cache/dnf in Dockerfile).
# Attempting to rm a bind-mount target fails with "Device or resource busy".
# Strategy: delete everything in /var except the cache/dnf path, then clean up
# any empty directories left behind (except the mount point itself).
find /var -mindepth 1 -maxdepth 1 -not -name 'cache' -exec rm -rf {} +
find /var/cache -mindepth 1 -maxdepth 1 -not -name 'dnf' -exec rm -rf {} + 2>/dev/null || true

mkdir -p /boot /var

# Make /usr/local writeable
mv /usr/local /var/usrlocal
ln -s /var/usrlocal /usr/local
