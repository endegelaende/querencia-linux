#!/usr/bin/env bash
# Querencia Linux -- Micromamba (fast user-space package manager)
# Installed system-wide to /usr/bin.
# Each user can create their own environments in ~/micromamba.
# No root privileges required -- perfect for immutable systems.
#
# Pinned to a specific release from mamba-org/micromamba-releases
# with SHA256 verification for supply-chain security.
# To update: change VERSION, BUILD and SHA256 below, values from:
# https://github.com/mamba-org/micromamba-releases/releases
set -xeuo pipefail

VERSION="2.5.0"
BUILD="2"
SHA256="c04571cfb0750e5432d530a3068b8fcd232ebed3133358e056e59a90b9852b00"
RELEASE_TAG="${VERSION}-${BUILD}"
URL="https://github.com/mamba-org/micromamba-releases/releases/download/${RELEASE_TAG}/micromamba-linux-64"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading micromamba ${RELEASE_TAG}..."
curl -fsSL -o "${TMPDIR}/micromamba" "${URL}"

echo "Verifying SHA256 checksum..."
echo "${SHA256}  ${TMPDIR}/micromamba" | sha256sum -c -

install -m 0755 "${TMPDIR}/micromamba" /usr/bin/micromamba

echo "Installed micromamba $(micromamba --version) to /usr/bin/micromamba"

# Shell integration is provided via /etc/profile.d/micromamba.sh
# (copied from system files by build.sh)
