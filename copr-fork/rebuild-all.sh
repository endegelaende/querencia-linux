#!/usr/bin/env bash
# rebuild-all.sh — Trigger rebuilds of all SCM packages in the COPR fork.
#
# This script reads packages.json and triggers copr-cli build-package for each
# package with source_type == "scm". Packages must already be added to the
# project (e.g. via setup-copr-fork.sh).
#
# Usage:
#   ./rebuild-all.sh                  # Rebuild all SCM packages
#   ./rebuild-all.sh --phase 3        # Rebuild only packages in build phase 3
#   ./rebuild-all.sh --package caja   # Rebuild a single package
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
COPR_PROJECT="winonaoctober/MateDesktop-EL10"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_JSON="$SCRIPT_DIR/packages.json"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
FILTER_PHASE=""
FILTER_PACKAGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)
            FILTER_PHASE="$2"
            shift 2
            ;;
        --package)
            FILTER_PACKAGE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--phase N] [--package NAME]"
            echo ""
            echo "Options:"
            echo "  --phase N       Only rebuild packages in build phase N (1-6)"
            echo "  --package NAME  Rebuild a single package by name"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
for cmd in copr-cli jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not found in PATH." >&2
        exit 1
    fi
done

if [[ ! -f "$PACKAGES_JSON" ]]; then
    echo "Error: packages.json not found at $PACKAGES_JSON" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Build the package list
# ---------------------------------------------------------------------------
if [[ -n "$FILTER_PACKAGE" ]]; then
    # Single package mode — verify it exists and is SCM
    source_type=$(jq -r --arg name "$FILTER_PACKAGE" \
        '.packages[] | select(.name == $name) | .source_type' "$PACKAGES_JSON")
    if [[ -z "$source_type" ]]; then
        echo "Error: Package '$FILTER_PACKAGE' not found in packages.json." >&2
        exit 1
    fi
    if [[ "$source_type" != "scm" ]]; then
        echo "Error: Package '$FILTER_PACKAGE' has source_type '$source_type', not 'scm'." >&2
        exit 1
    fi
    PACKAGE_NAMES="$FILTER_PACKAGE"
elif [[ -n "$FILTER_PHASE" ]]; then
    # Phase filter — get package names from build_order_hints, then intersect with SCM packages
    phase_packages=$(jq -r --argjson phase "$FILTER_PHASE" \
        '.build_order_hints[] | select(.phase == $phase) | .packages[]' "$PACKAGES_JSON")
    if [[ -z "$phase_packages" ]]; then
        echo "Error: No packages found for phase $FILTER_PHASE." >&2
        exit 1
    fi
    # Filter to only SCM packages present in the phase
    PACKAGE_NAMES=""
    while IFS= read -r pkg; do
        st=$(jq -r --arg name "$pkg" \
            '.packages[] | select(.name == $name) | .source_type' "$PACKAGES_JSON")
        if [[ "$st" == "scm" ]]; then
            PACKAGE_NAMES+="$pkg"$'\n'
        fi
    done <<< "$phase_packages"
    PACKAGE_NAMES=$(echo "$PACKAGE_NAMES" | sed '/^$/d')
else
    # All SCM packages
    PACKAGE_NAMES=$(jq -r '.packages[] | select(.source_type == "scm") | .name' "$PACKAGES_JSON")
fi

if [[ -z "$PACKAGE_NAMES" ]]; then
    echo "No SCM packages matched the given filters."
    exit 0
fi

# ---------------------------------------------------------------------------
# Trigger rebuilds
# ---------------------------------------------------------------------------
total=$(echo "$PACKAGE_NAMES" | wc -l)
count=0
failed=0

echo "=== Rebuilding SCM packages in $COPR_PROJECT ==="
[[ -n "$FILTER_PHASE" ]] && echo "    Phase filter: $FILTER_PHASE"
[[ -n "$FILTER_PACKAGE" ]] && echo "    Package filter: $FILTER_PACKAGE"
echo "    Packages to rebuild: $total"
echo ""

while IFS= read -r name; do
    count=$((count + 1))
    echo "Triggering rebuild for $name... ($count/$total)"
    if ! copr-cli build-package "$COPR_PROJECT" --name "$name" --nowait 2>&1; then
        echo "  WARNING: Failed to trigger rebuild for $name" >&2
        failed=$((failed + 1))
    fi
done <<< "$PACKAGE_NAMES"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Rebuild Summary ==="
echo "  Triggered: $((count - failed))/$total"
if [[ $failed -gt 0 ]]; then
    echo "  Failed:    $failed/$total"
fi
echo ""
echo "Monitor builds at: https://copr.fedorainfracloud.org/coprs/$COPR_PROJECT/builds/"
