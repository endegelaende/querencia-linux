#!/bin/bash
# migrate-to-forks.sh — Convert upload packages to SCM forks in COPR
#
# ============================================================================
# STATUS: COMPLETED (2026-03-13)
#
# Both packages have been successfully migrated:
#   - system-config-printer  Build #10224099  1.5.18-16.querencia1  ✅ succeeded
#   - qadwaitadecorations    Build #10224095  0.1.7-2.querencia1    ✅ succeeded
#
# Method: make_srpm (not rpkg — rpkg cannot resolve lookaside for GitHub forks)
# Each fork repo contains .copr/Makefile that downloads sources from Fedora
# lookaside (src.fedoraproject.org) and runs rpmbuild -bs.
#
# This script is kept for reference. Re-running it is safe (idempotent) but
# will delete and recreate the package entries, triggering fresh builds.
# ============================================================================
#
# This script migrates system-config-printer and qadwaitadecorations
# from upload (SRPM) packages to SCM packages pointing at our GitHub forks.
#
# Prerequisites:
#   - copr-cli installed and configured with winonaoctober API token
#   - GitHub forks already created and pushed:
#     - github.com/endegelaende/rpms-system-config-printer (branch: f43-el10)
#     - github.com/endegelaende/rpms-qadwaitadecorations (branch: f43-el10)
#   - Each fork must contain .copr/Makefile for make_srpm method
#
# Usage:
#   ./migrate-to-forks.sh [--dry-run]
#
# Run on the Linux Build-VM where copr-cli is configured.

set -euo pipefail

COPR_PROJECT="winonaoctober/MateDesktop-EL10"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE — no changes will be made ==="
    echo
fi

run_cmd() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        echo "[exec] $*"
        "$@"
    fi
}

echo "=============================================="
echo "COPR Fork Migration: Upload → SCM"
echo "Project: ${COPR_PROJECT}"
echo "=============================================="
echo

# -----------------------------------------------
# Step 1: Delete existing upload package entries
# -----------------------------------------------
# We must delete the old package entries before recreating them as SCM.
# COPR does not allow changing source_type in-place.

echo "--- Step 1: Delete old upload package entries ---"
echo

for pkg in system-config-printer qadwaitadecorations; do
    echo "Deleting package: ${pkg}"
    run_cmd copr-cli delete-package "${COPR_PROJECT}" --name "${pkg}"
    echo
done

# Small delay to let COPR process the deletions
if ! $DRY_RUN; then
    echo "Waiting 10s for COPR to process deletions..."
    sleep 10
fi

# -----------------------------------------------
# Step 2: Create SCM package entries pointing to our forks
# -----------------------------------------------

echo "--- Step 2: Create SCM package entries ---"
echo

# system-config-printer
echo "Creating SCM package: system-config-printer"
run_cmd copr-cli add-package-scm "${COPR_PROJECT}" \
    --name system-config-printer \
    --clone-url https://github.com/endegelaende/rpms-system-config-printer.git \
    --commit f43-el10 \
    --method make_srpm
echo

# qadwaitadecorations
echo "Creating SCM package: qadwaitadecorations"
run_cmd copr-cli add-package-scm "${COPR_PROJECT}" \
    --name qadwaitadecorations \
    --clone-url https://github.com/endegelaende/rpms-qadwaitadecorations.git \
    --commit f43-el10 \
    --method make_srpm
echo

# -----------------------------------------------
# Step 3: Trigger initial builds
# -----------------------------------------------

echo "--- Step 3: Trigger initial builds ---"
echo

for pkg in system-config-printer qadwaitadecorations; do
    echo "Building package: ${pkg}"
    run_cmd copr-cli build-package "${COPR_PROJECT}" --name "${pkg}"
    echo
done

# -----------------------------------------------
# Summary
# -----------------------------------------------

echo "=============================================="
echo "Migration complete!"
echo
echo "Next steps:"
echo "  1. Monitor builds at:"
echo "     https://copr.fedorainfracloud.org/coprs/${COPR_PROJECT}/monitor/"
echo
echo "  2. If builds succeed, update packages.json:"
echo "     - system-config-printer: source_type upload → scm"
echo "     - qadwaitadecorations: source_type upload → scm"
echo "     - statistics: upload_srpm 13 → 11, scm_fedora 111 → 113"
echo
echo "  3. If builds fail, check the build logs and fix specs in the forks."
echo "     Common issues:"
echo "     - Missing BuildRequires (qt5-qtbase-devel etc.)"
echo "     - rpkg source fetching (verify .gitattributes / sources file)"
echo "=============================================="
