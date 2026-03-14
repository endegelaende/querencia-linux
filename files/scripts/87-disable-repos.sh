#!/usr/bin/env bash
# =============================================================================
# Querencia Linux -- Disable Third-Party Repositories
# =============================================================================
# On an atomic/immutable system the root filesystem is read-only at runtime,
# so package repos serve no purpose after the image is built. Leaving them
# enabled is a unnecessary attack surface (repo metadata fetches, GPG key
# trust, potential for accidental layering attempts).
#
# This script runs AFTER all package installation is complete (last dnf usage
# is in 72-plymouth.sh) and BEFORE the template scripts (90-signing.sh,
# 91-image-info.sh) and cleanup.sh which do not install packages.
#
# Repos disabled here:
#   - EPEL                          (epel*.repo)
#   - RPM Fusion Free + Nonfree     (rpmfusion-*.repo)
#   - Rocky Devel                   (rocky-devel.repo)
#   - winonaoctober MATE COPR       (winonaoctober-*.repo / _copr:*.repo)
#   - AlmaLinux NVIDIA / CUDA       (nvidia*.repo, cuda*.repo — NVIDIA variant only)
#
# AlmaLinux base repos (almalinux-*.repo) are kept enabled so that:
#   - bootc can check for base image updates
#   - dnf repoquery still works for debugging on a live system
#   - Future bootc operations that need repo access still function
# =============================================================================
set -xeuo pipefail

echo "=== Disabling third-party repositories ==="

disabled_count=0

for repo_file in /etc/yum.repos.d/*.repo; do
    # Guard against empty glob (no .repo files at all)
    [ -f "$repo_file" ] || continue

    filename=$(basename "$repo_file")

    case "$filename" in
        # ── Keep AlmaLinux base repos enabled ──
        almalinux-*.repo)
            echo "  KEEP: $filename (base repo)"
            ;;

        # ── Disable everything else ──
        *)
            if grep -qE '^enabled\s*=\s*1' "$repo_file" 2>/dev/null; then
                echo "  DISABLE: $filename"
                sed -i 's/^enabled\s*=\s*1/enabled=0/' "$repo_file"
                disabled_count=$((disabled_count + 1))
            else
                echo "  SKIP: $filename (already disabled or no enabled= line)"
            fi
            ;;
    esac
done

echo "=== Disabled $disabled_count third-party repo file(s) ==="

# ── Verify: list remaining enabled repos ──
echo "--- Repos still enabled after cleanup ---"
dnf repolist --enabled 2>/dev/null || true
echo "--- End repo list ---"
