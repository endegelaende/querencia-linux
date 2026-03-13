#!/usr/bin/env bash
# Querencia Linux -- Micromamba (fast user-space package manager)
# Installed system-wide to /usr/bin.
# Each user can create their own environments in ~/micromamba.
# No root privileges required -- perfect for immutable systems.
set -xeuo pipefail

curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest \
    | tar -xvj -C /usr/bin --strip-components=1 bin/micromamba

chmod +x /usr/bin/micromamba

# Shell integration is provided via /etc/profile.d/micromamba.sh
# (copied from system files by build.sh)
