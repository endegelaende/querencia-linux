#!/usr/bin/env bash
# rebuild-failed.sh — Rebuild all failed COPR packages in correct dependency order.
#
# This script queries the COPR monitor for failed packages, then triggers
# rebuilds in the correct phase order (respecting dependency chains).
# It handles both SCM packages (via build-package) and SRPM uploads
# (via build --srpm re-upload).
#
# Usage:
#   ./rebuild-failed.sh                    # Rebuild all failed packages (all phases)
#   ./rebuild-failed.sh --phase 3          # Rebuild only failed packages in phase 3
#   ./rebuild-failed.sh --package caja     # Rebuild a single package (regardless of status)
#   ./rebuild-failed.sh --dry-run          # Show what would be rebuilt without triggering
#   ./rebuild-failed.sh --list             # Just list failed packages and exit
#   ./rebuild-failed.sh --wait             # Wait for each phase to complete before next
#   ./rebuild-failed.sh --chroot x86_64    # Only check/rebuild for specific chroot
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
COPR_PROJECT="winonaoctober/MateDesktop-EL10"
COPR_OWNER="winonaoctober"
COPR_NAME="MateDesktop-EL10"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_JSON="$SCRIPT_DIR/packages.json"
SRPMS_DIR="$SCRIPT_DIR/srpms"

# COPR monitor URL (used to scrape current build status)
MONITOR_URL="https://copr.fedorainfracloud.org/coprs/$COPR_OWNER/$COPR_NAME/monitor/"

# Phase order for rebuilds (from packages.json build_order_hints)
# Phase 1: Base libraries with no in-repo deps
# Phase 2: C++ bindings, X server, MATE foundation
# Phase 3: X drivers, MATE core components, LightDM
# Phase 4: MATE desktop components, panels, apps
# Phase 5: Extensions, plugins, extra apps
# Phase 6: Compiz stack, extra apps, everything else

# Delay between triggering builds (seconds) — be nice to COPR
BUILD_DELAY=3

# Delay between phase completion checks (seconds)
POLL_INTERVAL=60

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
FILTER_PHASE=""
FILTER_PACKAGE=""
DRY_RUN=false
LIST_ONLY=false
WAIT_PHASES=false
FILTER_CHROOT=""

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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --wait)
            WAIT_PHASES=true
            shift
            ;;
        --chroot)
            FILTER_CHROOT="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'HELP'
Usage: rebuild-failed.sh [OPTIONS]

Rebuild all failed COPR packages in correct dependency order.

Options:
  --phase N       Only rebuild failed packages in build phase N (1-6)
  --package NAME  Force rebuild a single package (regardless of status)
  --dry-run       Show what would be rebuilt without triggering builds
  --list          Just list failed packages grouped by phase and exit
  --wait          Wait for each phase to complete before starting next
  --chroot ARCH   Only check failures for specific chroot (x86_64 or aarch64)
  -h, --help      Show this help message

Examples:
  ./rebuild-failed.sh                    # Rebuild all failed, all phases
  ./rebuild-failed.sh --phase 3          # Only phase 3 failures
  ./rebuild-failed.sh --dry-run          # Preview without building
  ./rebuild-failed.sh --list             # Just show what's failed
  ./rebuild-failed.sh --wait             # Sequential phase rebuilds
  ./rebuild-failed.sh --package compiz   # Force rebuild one package

The script respects build_order_hints from packages.json to rebuild
in the correct dependency order. Within each phase, all packages are
triggered with --nowait for parallelism.

SCM packages are rebuilt via 'copr-cli build-package'.
SRPM packages are rebuilt via 'copr-cli build --srpm' (requires srpms/ dir).
HELP
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
for cmd in copr-cli jq curl; do
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
# Helper functions
# ---------------------------------------------------------------------------

# Get the list of failed packages from COPR API
get_failed_packages() {
    echo "Querying COPR for package build statuses..." >&2

    # Use the COPR API to get package list with latest build status
    local api_url="https://copr.fedorainfracloud.org/api_3/package/list?ownername=$COPR_OWNER&projectname=$COPR_NAME&with_latest_build=true&limit=200"

    local response
    response=$(curl -s "$api_url") || {
        echo "Error: Failed to query COPR API" >&2
        return 1
    }

    # Extract package names where latest build has failed status
    # The API returns builds per chroot; we check if any chroot has failed
    if [[ -n "$FILTER_CHROOT" ]]; then
        # Match chroot substring (e.g. "x86_64" matches "rhel+epel-10-x86_64")
        # Uses builds.latest_per_chroots which is keyed by full chroot name
        echo "$response" | jq -r --arg chroot "$FILTER_CHROOT" '
            .items[]
            | select(
                .builds.latest_per_chroots
                and (
                    .builds.latest_per_chroots
                    | to_entries[]
                    | select(.key | contains($chroot))
                    | .value.state == "failed"
                )
            )
            | .name
        ' 2>/dev/null | sort -u
    else
        echo "$response" | jq -r '
            .items[]
            | select(
                .builds.latest
                and (.builds.latest.state == "failed")
            )
            | .name
        ' 2>/dev/null | sort -u
    fi
}

# Alternative: scrape the monitor page for failed packages
get_failed_packages_from_monitor() {
    echo "Scraping COPR monitor for failed packages..." >&2

    local html
    html=$(curl -sL "$MONITOR_URL") || {
        echo "Error: Failed to fetch COPR monitor page" >&2
        return 1
    }

    # Extract package names that have "failed" status
    # The monitor page has rows like: <td>packagename</td> ... <td>failed</td>
    echo "$html" | grep -oP '(?<=<td[^>]*>\s*<a[^>]*>)\s*\w[\w.-]*\w\s*(?=</a>)' | while read -r pkg; do
        pkg=$(echo "$pkg" | xargs)  # trim whitespace
        # Check if this package has a "failed" cell nearby
        if echo "$html" | grep -A5 ">$pkg<" | grep -q "failed"; then
            echo "$pkg"
        fi
    done | sort -u
}

# Get source type of a package from packages.json
get_source_type() {
    local name="$1"
    jq -r --arg name "$name" '.packages[] | select(.name == $name) | .source_type' "$PACKAGES_JSON"
}

# Get the phase for a package from build_order_hints
get_package_phase() {
    local name="$1"
    jq -r --arg name "$name" '
        .build_order_hints[]
        | select(.packages | index($name))
        | .phase
    ' "$PACKAGES_JSON"
}

# Get all packages in a specific phase from build_order_hints
get_phase_packages() {
    local phase="$1"
    jq -r --argjson phase "$phase" \
        '.build_order_hints[] | select(.phase == $phase) | .packages[]' "$PACKAGES_JSON"
}

# Get phase description
get_phase_description() {
    local phase="$1"
    jq -r --argjson phase "$phase" \
        '.build_order_hints[] | select(.phase == $phase) | .description' "$PACKAGES_JSON"
}

# Rebuild a single SCM package
rebuild_scm_package() {
    local name="$1"
    if $DRY_RUN; then
        echo "  [DRY-RUN] copr-cli build-package $COPR_PROJECT --name $name --nowait"
        return 0
    fi
    copr-cli build-package "$COPR_PROJECT" --name "$name" --nowait 2>&1
}

# Rebuild a single SRPM package
rebuild_srpm_package() {
    local name="$1"

    # Find the SRPM file
    local srpm_file=""
    if [[ -d "$SRPMS_DIR" ]]; then
        srpm_file=$(find "$SRPMS_DIR" -name "${name}-*.src.rpm" -type f 2>/dev/null | head -1)
    fi

    if [[ -z "$srpm_file" ]]; then
        # Try to get the SRPM filename from packages.json
        local expected_srpm
        expected_srpm=$(jq -r --arg name "$name" \
            '.packages[] | select(.name == $name) | .srpm_filename // empty' "$PACKAGES_JSON")
        if [[ -n "$expected_srpm" && -f "$SRPMS_DIR/$expected_srpm" ]]; then
            srpm_file="$SRPMS_DIR/$expected_srpm"
        fi
    fi

    if [[ -z "$srpm_file" ]]; then
        echo "  WARNING: No SRPM found for '$name' in $SRPMS_DIR" >&2
        echo "  -> Download it first: ./download-srpms.sh" >&2
        echo "  -> Or rebuild manually via COPR web UI" >&2
        return 1
    fi

    if $DRY_RUN; then
        echo "  [DRY-RUN] copr-cli build $COPR_PROJECT $srpm_file --nowait"
        return 0
    fi
    copr-cli build "$COPR_PROJECT" "$srpm_file" --nowait 2>&1
}

# Wait for all running builds in the project to finish
wait_for_builds() {
    echo ""
    echo "  Waiting for builds to complete..."

    while true; do
        local api_url="https://copr.fedorainfracloud.org/api_3/build/list?ownername=$COPR_OWNER&projectname=$COPR_NAME&limit=50&status=running"
        local pending_url="https://copr.fedorainfracloud.org/api_3/build/list?ownername=$COPR_OWNER&projectname=$COPR_NAME&limit=50&status=pending"
        local starting_url="https://copr.fedorainfracloud.org/api_3/build/list?ownername=$COPR_OWNER&projectname=$COPR_NAME&limit=50&status=starting"
        local importing_url="https://copr.fedorainfracloud.org/api_3/build/list?ownername=$COPR_OWNER&projectname=$COPR_NAME&limit=50&status=importing"
        local waiting_url="https://copr.fedorainfracloud.org/api_3/build/list?ownername=$COPR_OWNER&projectname=$COPR_NAME&limit=50&status=waiting"

        local running pending starting importing waiting
        running=$(curl -s "$api_url" | jq '.items | length' 2>/dev/null || echo "0")
        pending=$(curl -s "$pending_url" | jq '.items | length' 2>/dev/null || echo "0")
        starting=$(curl -s "$starting_url" | jq '.items | length' 2>/dev/null || echo "0")
        importing=$(curl -s "$importing_url" | jq '.items | length' 2>/dev/null || echo "0")
        waiting=$(curl -s "$waiting_url" | jq '.items | length' 2>/dev/null || echo "0")

        local total_active=$((running + pending + starting + importing + waiting))

        if [[ $total_active -eq 0 ]]; then
            echo "  All builds completed."
            break
        fi

        echo "  Still active: ${running} running, ${pending} pending, ${starting} starting, ${importing} importing, ${waiting} waiting — checking again in ${POLL_INTERVAL}s..."
        sleep "$POLL_INTERVAL"
    done
}

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

echo "========================================================"
echo "  COPR Failed Package Rebuilder"
echo "  Project: $COPR_PROJECT"
echo "========================================================"
echo ""

# --- Single package mode ---
if [[ -n "$FILTER_PACKAGE" ]]; then
    source_type=$(get_source_type "$FILTER_PACKAGE")
    phase=$(get_package_phase "$FILTER_PACKAGE")

    if [[ -z "$source_type" ]]; then
        echo "Error: Package '$FILTER_PACKAGE' not found in packages.json." >&2
        exit 1
    fi

    echo "Rebuilding single package: $FILTER_PACKAGE"
    echo "  Source type: $source_type"
    echo "  Build phase: ${phase:-unknown}"
    echo ""

    if [[ "$source_type" == "scm" ]]; then
        rebuild_scm_package "$FILTER_PACKAGE"
    elif [[ "$source_type" == "upload" ]]; then
        rebuild_srpm_package "$FILTER_PACKAGE"
    else
        echo "Error: Unknown source_type '$source_type' for $FILTER_PACKAGE" >&2
        exit 1
    fi

    echo ""
    echo "Monitor at: https://copr.fedorainfracloud.org/coprs/$COPR_PROJECT/builds/"
    exit 0
fi

# --- Get failed packages ---
echo "Step 1: Detecting failed packages..."
echo ""

FAILED_PACKAGES=$(get_failed_packages)

if [[ -z "$FAILED_PACKAGES" ]]; then
    echo "No failed packages found! Trying monitor page fallback..."
    FAILED_PACKAGES=$(get_failed_packages_from_monitor)
fi

if [[ -z "$FAILED_PACKAGES" ]]; then
    echo ""
    echo "No failed packages detected. Everything looks good!"
    echo "Monitor: https://copr.fedorainfracloud.org/coprs/$COPR_PROJECT/monitor/"
    exit 0
fi

FAILED_COUNT=$(echo "$FAILED_PACKAGES" | wc -l)
echo "Found $FAILED_COUNT failed packages."
echo ""

# --- Organize by phase ---
echo "Step 2: Organizing by build phase..."
echo ""

# Build associative-like structure: phase -> packages
declare -A PHASE_FAILED
for phase_num in 1 2 3 4 5 6; do
    PHASE_FAILED[$phase_num]=""
done

# Also track packages not in any phase
UNPHASED_FAILED=""

while IFS= read -r pkg; do
    phase=$(get_package_phase "$pkg")
    if [[ -n "$phase" ]]; then
        if [[ -n "${PHASE_FAILED[$phase]}" ]]; then
            PHASE_FAILED[$phase]+=$'\n'"$pkg"
        else
            PHASE_FAILED[$phase]="$pkg"
        fi
    else
        if [[ -n "$UNPHASED_FAILED" ]]; then
            UNPHASED_FAILED+=$'\n'"$pkg"
        else
            UNPHASED_FAILED="$pkg"
        fi
    fi
done <<< "$FAILED_PACKAGES"

# --- Display summary ---
echo "Failed packages by build phase:"
echo "────────────────────────────────────────────────────────"

for phase_num in 1 2 3 4 5 6; do
    if [[ -n "${PHASE_FAILED[$phase_num]}" ]]; then
        desc=$(get_phase_description "$phase_num")
        pkg_count=$(echo "${PHASE_FAILED[$phase_num]}" | wc -l)
        echo ""
        echo "  Phase $phase_num — $desc ($pkg_count packages):"
        while IFS= read -r pkg; do
            src=$(get_source_type "$pkg")
            echo "    • $pkg [$src]"
        done <<< "${PHASE_FAILED[$phase_num]}"
    fi
done

if [[ -n "$UNPHASED_FAILED" ]]; then
    echo ""
    echo "  No phase assigned:"
    while IFS= read -r pkg; do
        src=$(get_source_type "$pkg")
        echo "    • $pkg [${src:-unknown}]"
    done <<< "$UNPHASED_FAILED"
fi

echo ""
echo "────────────────────────────────────────────────────────"
echo ""

# --- List-only mode ---
if $LIST_ONLY; then
    echo "Total failed: $FAILED_COUNT"
    echo "(Use without --list to trigger rebuilds)"
    exit 0
fi

# --- Trigger rebuilds ---
if $DRY_RUN; then
    echo "Step 3: Rebuild plan (DRY RUN — no builds will be triggered):"
else
    echo "Step 3: Triggering rebuilds in phase order..."
fi
echo ""

total_triggered=0
total_failed_trigger=0
total_skipped=0

for phase_num in 1 2 3 4 5 6; do
    phase_packages="${PHASE_FAILED[$phase_num]}"

    # Apply phase filter
    if [[ -n "$FILTER_PHASE" && "$phase_num" != "$FILTER_PHASE" ]]; then
        continue
    fi

    if [[ -z "$phase_packages" ]]; then
        continue
    fi

    desc=$(get_phase_description "$phase_num")
    pkg_count=$(echo "$phase_packages" | wc -l)

    echo "━━━ Phase $phase_num: $desc ($pkg_count packages) ━━━"
    echo ""

    while IFS= read -r pkg; do
        source_type=$(get_source_type "$pkg")

        echo "  [$phase_num] Rebuilding: $pkg ($source_type)"

        if [[ "$source_type" == "scm" ]]; then
            if rebuild_scm_package "$pkg"; then
                total_triggered=$((total_triggered + 1))
            else
                echo "  ⚠ Failed to trigger rebuild for $pkg" >&2
                total_failed_trigger=$((total_failed_trigger + 1))
            fi
        elif [[ "$source_type" == "upload" ]]; then
            if rebuild_srpm_package "$pkg"; then
                total_triggered=$((total_triggered + 1))
            else
                echo "  ⚠ Skipped $pkg (SRPM not available)" >&2
                total_skipped=$((total_skipped + 1))
            fi
        else
            echo "  ⚠ Unknown source type '$source_type' for $pkg — skipping" >&2
            total_skipped=$((total_skipped + 1))
        fi

        # Small delay between triggers to avoid hammering COPR
        if ! $DRY_RUN; then
            sleep "$BUILD_DELAY"
        fi

    done <<< "$phase_packages"

    echo ""

    # Wait for phase to complete before starting next phase
    if $WAIT_PHASES && ! $DRY_RUN; then
        wait_for_builds
        echo ""
    fi
done

# Handle unphased packages (after all phases)
if [[ -n "$UNPHASED_FAILED" && -z "$FILTER_PHASE" ]]; then
    echo "━━━ Unphased packages ━━━"
    echo ""

    while IFS= read -r pkg; do
        source_type=$(get_source_type "$pkg")

        echo "  [?] Rebuilding: $pkg ($source_type)"

        if [[ "$source_type" == "scm" ]]; then
            if rebuild_scm_package "$pkg"; then
                total_triggered=$((total_triggered + 1))
            else
                echo "  ⚠ Failed to trigger rebuild for $pkg" >&2
                total_failed_trigger=$((total_failed_trigger + 1))
            fi
        elif [[ "$source_type" == "upload" ]]; then
            if rebuild_srpm_package "$pkg"; then
                total_triggered=$((total_triggered + 1))
            else
                echo "  ⚠ Skipped $pkg (SRPM not available)" >&2
                total_skipped=$((total_skipped + 1))
            fi
        else
            echo "  ⚠ Unknown source type — skipping $pkg" >&2
            total_skipped=$((total_skipped + 1))
        fi

        if ! $DRY_RUN; then
            sleep "$BUILD_DELAY"
        fi
    done <<< "$UNPHASED_FAILED"

    echo ""
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================================"
echo "  Rebuild Summary"
echo "========================================================"
echo ""
echo "  Failed packages found:   $FAILED_COUNT"
echo "  Rebuilds triggered:      $total_triggered"
if [[ $total_failed_trigger -gt 0 ]]; then
    echo "  Failed to trigger:       $total_failed_trigger"
fi
if [[ $total_skipped -gt 0 ]]; then
    echo "  Skipped (no SRPM/other): $total_skipped"
fi
if $DRY_RUN; then
    echo ""
    echo "  *** DRY RUN — no builds were actually triggered ***"
    echo "  Run without --dry-run to trigger builds."
fi
echo ""
echo "  Monitor builds:  https://copr.fedorainfracloud.org/coprs/$COPR_PROJECT/monitor/"
echo "  Build list:      https://copr.fedorainfracloud.org/coprs/$COPR_PROJECT/builds/"
echo ""

if $WAIT_PHASES && ! $DRY_RUN; then
    echo "All phases completed. Re-run this script to check for remaining failures."
elif ! $DRY_RUN; then
    echo "Builds triggered with --nowait. Use --wait flag for sequential phase execution."
    echo "Re-run this script after builds complete to check for remaining failures."
fi
