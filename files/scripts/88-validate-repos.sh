#!/usr/bin/env bash
# Querencia Linux -- Validate repos are disabled (security gate)
# =============================================================================
# Runs after 87-disable-repos.sh has disabled all third-party repos.
# This script is a pure VALIDATION GATE — it does not disable anything itself.
# If any third-party repo is still enabled, the build fails hard.
#
# Why a separate validation step?
#   87-disable-repos.sh does the work (sed on repo files).
#   88-validate-repos.sh verifies the result (dnf repolist).
#   Separation ensures that a bug in the disable script (missed glob,
#   new repo format, etc.) is caught before the image ships.
#
# AlmaLinux base repos allowed to remain enabled:
#   baseos, appstream, crb, extras (and their -debug/-source variants)
#
# Third-party repos that MUST have been disabled by 87-disable-repos.sh:
#   - EPEL (epel, epel-cisco-openh264, epel-next, etc.)
#   - RPM Fusion (rpmfusion-free-*, rpmfusion-nonfree-*)
#   - Rocky Devel (rocky-devel)
#   - winonaoctober MATE COPR (copr:copr.fedorainfracloud.org:winonaoctober:*)
#   - AlmaLinux NVIDIA repos (nvidia-driver, cuda — NVIDIA variant only)
# =============================================================================
set -xeuo pipefail

echo "=== Validating repository configuration ==="

# Get list of enabled repos via dnf (skip the header line)
ENABLED_REPOS=$(dnf repolist --enabled 2>/dev/null | tail -n +2 | awk '{print $1}' || true)

FAILED=0
for repo in $ENABLED_REPOS; do
    case "$repo" in
        # AlmaLinux base repos — these are expected and safe
        baseos|appstream|crb|extras)
            echo "  OK: $repo (AlmaLinux base)"
            ;;
        # Debug and source repos — harmless, sometimes enabled by default
        baseos-debug*|appstream-debug*|crb-debug*|extras-debug*)
            echo "  OK: $repo (AlmaLinux debug)"
            ;;
        baseos-source*|appstream-source*|crb-source*|extras-source*)
            echo "  OK: $repo (AlmaLinux source)"
            ;;
        # Anything else is a third-party repo that should have been disabled
        *)
            echo "  ERROR: Third-party repo '$repo' is still enabled!"
            FAILED=1
            ;;
    esac
done

if [[ $FAILED -eq 1 ]]; then
    echo ""
    echo "FATAL: Third-party repos left enabled after 87-disable-repos.sh."
    echo "In an atomic/immutable image, all third-party repos should be disabled."
    echo "Users cannot run 'dnf install' anyway (read-only root filesystem)."
    echo ""
    echo "Fix: Update 87-disable-repos.sh to handle the repo(s) listed above."
    echo "     The disable script may have missed a new repo file or glob pattern."
    echo ""
    echo "Currently enabled repos:"
    dnf repolist --enabled 2>/dev/null || true
    exit 1
fi

echo "=== All repos validated — only AlmaLinux base repos enabled ==="
