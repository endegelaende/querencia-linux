#!/usr/bin/env bash
# Querencia Linux -- Distrobox + Podman (mutable container environments)
set -xeuo pipefail

dnf install -y \
    distrobox \
    podman
