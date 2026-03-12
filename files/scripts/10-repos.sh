#!/usr/bin/env bash
# Querencia Linux -- Repository Setup
# EPEL + CRB + Rocky Devel (build deps) + skip77 MATE COPR + RPM Fusion
set -xeuo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")"

# EPEL + CRB (same approach as atomic-desktop 10-base.sh)
dnf install -y 'dnf-command(config-manager)' epel-release
dnf config-manager --set-enabled crb

# Upgrade EPEL to the EPEL-shipped version
dnf upgrade -y $(dnf repoquery --installed --qf '%{name}' --whatprovides epel-release)

# Rocky Devel repo (build deps that CentOS Stream / AlmaLinux don't ship)
# and skip77 MATE COPR -- both are in our system files
# (copied by build.sh before this script runs)

# RPM Fusion Free + Nonfree (for multimedia codecs)
dnf install -y \
    https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm
