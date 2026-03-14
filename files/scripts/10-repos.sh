#!/usr/bin/env bash
# Querencia Linux -- Repository Setup
# EPEL + CRB + Rocky Devel (build deps) + winonaoctober MATE COPR + RPM Fusion
set -xeuo pipefail

# EPEL + CRB (same approach as atomic-desktop 10-base.sh)
dnf install -y 'dnf-command(config-manager)' epel-release
dnf config-manager --set-enabled crb

# Upgrade EPEL to the EPEL-shipped version (guard against empty output
# which would cause an unintended full system upgrade)
_epel_pkg=$(dnf repoquery --installed --qf '%{name}' --whatprovides epel-release)
if [ -n "$_epel_pkg" ]; then
    dnf upgrade -y "$_epel_pkg"
else
    echo "WARNING: epel-release not found by repoquery, skipping EPEL upgrade" >&2
fi

# Rocky Devel repo (build deps that CentOS Stream / AlmaLinux don't ship)
# and winonaoctober MATE COPR -- both are in our system files
# (copied by build.sh before this script runs)
dnf config-manager --set-enabled rocky-devel

# RPM Fusion Free + Nonfree (for multimedia codecs)
dnf install -y \
    https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm
