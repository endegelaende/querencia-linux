#!/usr/bin/env bash
# =============================================================================
# setup-copr-fork.sh — Automate COPR fork setup for Querencia Linux
# =============================================================================
#
# This script reads packages.json and sets up a complete COPR fork of
# skip77/MateDesktop-EL10 under the winonaoctober account.
#
# Prerequisites:
#   - copr-cli installed and configured (~/.config/copr with valid API token)
#   - jq installed (JSON processing)
#   - curl installed (COPR API + SRPM downloads)
#
# Usage:
#   ./setup-copr-fork.sh [OPTIONS]
#
# Options:
#   --skip-builds     Only add/update packages, don't trigger builds
#   --phase N         Only process build phase N (1-6)
#   --package NAME    Only process a single package by name
#   --srpm-only       Only process SRPM/upload packages
#   --scm-only        Only process SCM packages
#   --dry-run         Show what would be done without executing
#   --help            Show this help message
#
# The script is idempotent — safe to run multiple times. SCM packages are
# updated in place via add-package-scm; upload packages check for existing
# successful builds before re-submitting.
#
# See copr-fork/README.md and CLAUDE.md for full context.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
COPR_PROJECT="winonaoctober/MateDesktop-EL10"
COPR_OWNER="winonaoctober"
COPR_NAME="MateDesktop-EL10"
SKIP77_OWNER="skip77"
SKIP77_PROJECT="MateDesktop-EL10"
COPR_API_BASE="https://copr.fedorainfracloud.org/api_3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_JSON="$SCRIPT_DIR/packages.json"
SRPM_DIR="$SCRIPT_DIR/srpms"
LOG_FILE="$SCRIPT_DIR/setup-copr-fork.log"

# Counters for the summary
TOTAL_PROCESSED=0
SCM_ADDED=0
SCM_FAILED=0
SRPM_DOWNLOADED=0
SRPM_UPLOADED=0
SRPM_SKIPPED=0
SRPM_FAILED=0
BUILDS_TRIGGERED=0
BUILDS_SUCCEEDED=0
BUILDS_FAILED=0

# ---------------------------------------------------------------------------
# CLI argument defaults
# ---------------------------------------------------------------------------
SKIP_BUILDS=false
TARGET_PHASE=""
TARGET_PACKAGE=""
SRPM_ONLY=false
SCM_ONLY=false
DRY_RUN=false

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
show_help() {
    sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-builds)
            SKIP_BUILDS=true
            shift
            ;;
        --phase)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --phase requires a value (1-6)"
                exit 1
            fi
            TARGET_PHASE="$2"
            shift 2
            ;;
        --package)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --package requires a package name"
                exit 1
            fi
            TARGET_PACKAGE="$2"
            shift 2
            ;;
        --srpm-only)
            SRPM_ONLY=true
            shift
            ;;
        --scm-only)
            SCM_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage information."
            exit 1
            ;;
    esac
done

# Sanity check: --srpm-only and --scm-only are mutually exclusive
if [[ "$SRPM_ONLY" == true && "$SCM_ONLY" == true ]]; then
    echo "ERROR: --srpm-only and --scm-only are mutually exclusive"
    exit 1
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

log_info()    { log "ℹ️  $*"; }
log_ok()      { log "✅ $*"; }
log_warn()    { log "⚠️  $*"; }
log_error()   { log "❌ $*"; }
log_skip()    { log "⏭️  $*"; }
log_build()   { log "🔨 $*"; }
log_phase()   { log "📦 $*"; }
log_header()  {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "$*"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ---------------------------------------------------------------------------
# Dry-run wrapper — prints the command instead of executing it when --dry-run
# ---------------------------------------------------------------------------
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] $*"
        return 0
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Step 1: Validate prerequisites
# ---------------------------------------------------------------------------
validate_prerequisites() {
    log_header "Step 1: Validating prerequisites"

    local missing=()

    for cmd in copr-cli jq curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        else
            log_ok "$cmd found: $(command -v "$cmd")"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        log_error "Install them with: sudo dnf install copr-cli jq curl"
        exit 1
    fi

    # Check copr-cli configuration
    local copr_config="$HOME/.config/copr"
    if [[ ! -f "$copr_config" ]]; then
        log_error "COPR API config not found at $copr_config"
        log_error "Run 'copr-cli' or visit https://copr.fedorainfracloud.org/api/ to set up your token."
        exit 1
    fi
    log_ok "COPR config found: $copr_config"

    # Check packages.json exists
    if [[ ! -f "$PACKAGES_JSON" ]]; then
        log_error "packages.json not found at $PACKAGES_JSON"
        exit 1
    fi

    local pkg_count
    pkg_count=$(jq '.packages | length' "$PACKAGES_JSON")
    log_ok "packages.json loaded: $pkg_count packages"

    # Create SRPM download directory
    mkdir -p "$SRPM_DIR"
    log_ok "SRPM directory: $SRPM_DIR"

    log_info "All prerequisites satisfied"
}

# ---------------------------------------------------------------------------
# Step 2: Create the COPR project (idempotent)
# ---------------------------------------------------------------------------
create_copr_project() {
    log_header "Step 2: Creating COPR project $COPR_PROJECT"

    # Check if the project already exists via the API
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "${COPR_API_BASE}/project?ownername=${COPR_OWNER}&projectname=${COPR_NAME}")

    if [[ "$http_code" == "200" ]]; then
        log_ok "Project $COPR_PROJECT already exists — skipping creation"
        # Still modify it to ensure settings are current
        log_info "Updating project settings to ensure consistency..."
        run_cmd copr-cli modify \
            --chroot rhel+epel-10-x86_64 \
            --chroot rhel+epel-10-aarch64 \
            --description "MATE Desktop for AlmaLinux/EL10 — fork of skip77/MateDesktop-EL10 for Querencia Linux" \
            --instructions "See https://github.com/endegelaende/querencia-linux for usage" \
            --repo 'https://download.rockylinux.org/pub/rocky/$releasever/devel/$basearch/os/' \
            --repo 'https://dl.fedoraproject.org/pub/epel/${releasever}z/Everything/$basearch/' \
            --unlisted-on-hp on \
            "$COPR_PROJECT" || log_warn "Failed to update project settings (non-fatal)"
        return 0
    fi

    log_info "Project does not exist — creating $COPR_PROJECT"
    if run_cmd copr-cli create \
        --chroot rhel+epel-10-x86_64 \
        --chroot rhel+epel-10-aarch64 \
        --description "MATE Desktop for AlmaLinux/EL10 — fork of skip77/MateDesktop-EL10 for Querencia Linux" \
        --instructions "See https://github.com/endegelaende/querencia-linux for usage" \
        --repo 'https://download.rockylinux.org/pub/rocky/$releasever/devel/$basearch/os/' \
        --repo 'https://dl.fedoraproject.org/pub/epel/${releasever}z/Everything/$basearch/' \
        --unlisted-on-hp on \
        "$COPR_PROJECT"; then
        log_ok "Project $COPR_PROJECT created successfully"
    else
        log_error "Failed to create project $COPR_PROJECT"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Step 3: Add SCM packages
# ---------------------------------------------------------------------------
add_scm_package() {
    local name="$1"
    local clone_url="$2"
    local branch="$3"
    local method="$4"

    log_info "Adding SCM package: $name (branch=$branch, method=$method)"
    log_info "  clone_url: $clone_url"

    if run_cmd copr-cli add-package-scm "$COPR_PROJECT" \
        --name "$name" \
        --clone-url "$clone_url" \
        --commit "$branch" \
        --subdir "" \
        --method "$method" \
        --type git; then
        log_ok "SCM package added/updated: $name"
        SCM_ADDED=$((SCM_ADDED + 1))
        return 0
    else
        log_error "Failed to add SCM package: $name"
        SCM_FAILED=$((SCM_FAILED + 1))
        return 1
    fi
}

process_scm_packages() {
    log_header "Step 3: Adding SCM packages"

    local scm_packages
    scm_packages=$(jq -c '.packages[] | select(.source_type == "scm")' "$PACKAGES_JSON")

    if [[ -z "$scm_packages" ]]; then
        log_warn "No SCM packages found in packages.json"
        return 0
    fi

    local count
    count=$(echo "$scm_packages" | wc -l)
    log_info "Found $count SCM packages to process"

    while IFS= read -r pkg; do
        local name clone_url branch method

        name=$(echo "$pkg" | jq -r '.name')
        clone_url=$(echo "$pkg" | jq -r '.clone_url')
        branch=$(echo "$pkg" | jq -r '.our_branch')
        method=$(echo "$pkg" | jq -r '.source_build_method // "rpkg"')

        # Filter: single package mode
        if [[ -n "$TARGET_PACKAGE" && "$name" != "$TARGET_PACKAGE" ]]; then
            continue
        fi

        TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))
        add_scm_package "$name" "$clone_url" "$branch" "$method" || true
    done <<< "$scm_packages"
}

# ---------------------------------------------------------------------------
# Step 4: Handle upload (SRPM) packages
# ---------------------------------------------------------------------------

# Fetch the SRPM download URL from skip77's COPR via the API
get_srpm_url() {
    local pkg_name="$1"

    local api_url="${COPR_API_BASE}/package?ownername=${SKIP77_OWNER}&projectname=${SKIP77_PROJECT}&packagename=${pkg_name}&with_latest_succeeded_build=true"
    local response
    response=$(curl -s "$api_url")

    if [[ -z "$response" ]]; then
        log_error "Empty response from COPR API for package $pkg_name"
        return 1
    fi

    # Check if the package exists
    local error
    error=$(echo "$response" | jq -r '.error // empty')
    if [[ -n "$error" ]]; then
        log_error "COPR API error for $pkg_name: $error"
        return 1
    fi

    # Extract the SRPM URL from builds.latest_succeeded.source_package.url
    local srpm_url
    srpm_url=$(echo "$response" | jq -r '.builds.latest_succeeded.source_package.url // empty')

    if [[ -z "$srpm_url" || "$srpm_url" == "null" ]]; then
        log_error "No SRPM URL found for $pkg_name in skip77's COPR"
        return 1
    fi

    echo "$srpm_url"
}

# Check if a package already has a successful build in our fork
package_has_successful_build() {
    local pkg_name="$1"

    local api_url="${COPR_API_BASE}/package?ownername=${COPR_OWNER}&projectname=${COPR_NAME}&packagename=${pkg_name}&with_latest_succeeded_build=true"
    local response
    response=$(curl -s "$api_url" 2>/dev/null)

    if [[ -z "$response" ]]; then
        return 1  # no response = no build
    fi

    local build_id
    build_id=$(echo "$response" | jq -r '.builds.latest_succeeded.id // empty')

    if [[ -n "$build_id" && "$build_id" != "null" ]]; then
        return 0  # has a successful build
    fi

    return 1  # no successful build
}

process_upload_package() {
    local name="$1"
    local srpm_filename="$2"

    log_info "Processing upload package: $name ($srpm_filename)"

    # Check for existing successful build (idempotency)
    if package_has_successful_build "$name"; then
        log_skip "Package $name already has a successful build in $COPR_PROJECT — skipping"
        SRPM_SKIPPED=$((SRPM_SKIPPED + 1))
        return 0
    fi

    # Check if we already downloaded the SRPM
    local local_srpm="$SRPM_DIR/$srpm_filename"
    if [[ -f "$local_srpm" ]]; then
        log_info "SRPM already downloaded: $local_srpm"
    else
        # Fetch the SRPM URL from skip77's COPR API
        log_info "Fetching SRPM URL from skip77's COPR for $name..."
        local srpm_url
        if ! srpm_url=$(get_srpm_url "$name"); then
            log_error "Could not determine SRPM URL for $name"
            SRPM_FAILED=$((SRPM_FAILED + 1))
            return 1
        fi

        log_info "Downloading SRPM: $srpm_url"
        # Extract the actual filename from the URL (may differ from packages.json)
        local actual_filename
        actual_filename=$(basename "$srpm_url")
        local_srpm="$SRPM_DIR/$actual_filename"

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would download: $srpm_url -> $local_srpm"
            SRPM_DOWNLOADED=$((SRPM_DOWNLOADED + 1))
        else
            if curl -fSL -o "$local_srpm" "$srpm_url"; then
                log_ok "Downloaded: $actual_filename ($(du -h "$local_srpm" | cut -f1))"
                SRPM_DOWNLOADED=$((SRPM_DOWNLOADED + 1))
            else
                log_error "Failed to download SRPM for $name from $srpm_url"
                rm -f "$local_srpm"  # clean up partial download
                SRPM_FAILED=$((SRPM_FAILED + 1))
                return 1
            fi
        fi
    fi

    # Upload the SRPM to our COPR
    log_info "Uploading SRPM to $COPR_PROJECT: $local_srpm"
    if run_cmd copr-cli build "$COPR_PROJECT" "$local_srpm" --nowait; then
        log_ok "SRPM upload submitted: $name"
        SRPM_UPLOADED=$((SRPM_UPLOADED + 1))
        return 0
    else
        log_error "Failed to upload SRPM for $name"
        SRPM_FAILED=$((SRPM_FAILED + 1))
        return 1
    fi
}

process_upload_packages() {
    log_header "Step 4: Processing upload (SRPM) packages"

    local upload_packages
    upload_packages=$(jq -c '.packages[] | select(.source_type == "upload")' "$PACKAGES_JSON")

    if [[ -z "$upload_packages" ]]; then
        log_warn "No upload packages found in packages.json"
        return 0
    fi

    local count
    count=$(echo "$upload_packages" | wc -l)
    log_info "Found $count upload packages to process"

    while IFS= read -r pkg; do
        local name srpm_filename

        name=$(echo "$pkg" | jq -r '.name')
        srpm_filename=$(echo "$pkg" | jq -r '.srpm_filename // empty')

        # Filter: single package mode
        if [[ -n "$TARGET_PACKAGE" && "$name" != "$TARGET_PACKAGE" ]]; then
            continue
        fi

        if [[ -z "$srpm_filename" ]]; then
            log_warn "No srpm_filename for $name — skipping"
            continue
        fi

        TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))
        process_upload_package "$name" "$srpm_filename" || true
    done <<< "$upload_packages"
}

# ---------------------------------------------------------------------------
# Step 5: Build triggering (phased)
# ---------------------------------------------------------------------------

# Get the list of packages for a given build phase from build_order_hints
get_phase_packages() {
    local phase="$1"
    jq -r ".build_order_hints[] | select(.phase == $phase) | .packages[]" "$PACKAGES_JSON"
}

# Get the source_type for a package by name
get_package_source_type() {
    local name="$1"
    jq -r ".packages[] | select(.name == \"$name\") | .source_type" "$PACKAGES_JSON"
}

# Trigger a build for an SCM package and capture the build ID
trigger_scm_build() {
    local name="$1"

    log_build "Triggering build: $name"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would trigger: copr-cli build-package $COPR_PROJECT --name $name --nowait"
        BUILDS_TRIGGERED=$((BUILDS_TRIGGERED + 1))
        echo "dry-run-0"
        return 0
    fi

    local output
    if output=$(copr-cli build-package "$COPR_PROJECT" --name "$name" --nowait 2>&1); then
        # copr-cli build-package --nowait prints "Created builds: <id>"
        local build_id
        build_id=$(echo "$output" | grep -oP 'Created builds: \K[0-9]+' || echo "")

        if [[ -z "$build_id" ]]; then
            # Try alternate output format: just a number on a line
            build_id=$(echo "$output" | grep -oP '^\d+$' | head -1 || echo "")
        fi

        if [[ -n "$build_id" ]]; then
            log_ok "Build triggered for $name — build ID: $build_id"
            BUILDS_TRIGGERED=$((BUILDS_TRIGGERED + 1))
            echo "$build_id"
            return 0
        else
            log_warn "Build triggered for $name but could not parse build ID from output:"
            log_warn "  $output"
            BUILDS_TRIGGERED=$((BUILDS_TRIGGERED + 1))
            echo "unknown"
            return 0
        fi
    else
        log_error "Failed to trigger build for $name"
        log_error "  $output"
        BUILDS_FAILED=$((BUILDS_FAILED + 1))
        return 1
    fi
}

# Wait for a set of build IDs to complete
wait_for_builds() {
    local build_ids=("$@")

    if [[ ${#build_ids[@]} -eq 0 ]]; then
        return 0
    fi

    # Filter out dry-run and unknown placeholders
    local real_ids=()
    for bid in "${build_ids[@]}"; do
        if [[ "$bid" =~ ^[0-9]+$ ]]; then
            real_ids+=("$bid")
        fi
    done

    if [[ ${#real_ids[@]} -eq 0 ]]; then
        log_info "No real build IDs to wait for"
        return 0
    fi

    log_info "Waiting for ${#real_ids[@]} build(s) to complete..."
    log_info "Build IDs: ${real_ids[*]}"

    local all_ok=true
    for bid in "${real_ids[@]}"; do
        log_info "  Watching build $bid..."
        if copr-cli watch-build "$bid" 2>&1; then
            log_ok "  Build $bid succeeded"
            BUILDS_SUCCEEDED=$((BUILDS_SUCCEEDED + 1))
        else
            log_error "  Build $bid failed"
            BUILDS_FAILED=$((BUILDS_FAILED + 1))
            all_ok=false
        fi
    done

    if [[ "$all_ok" == true ]]; then
        return 0
    else
        return 1
    fi
}

# Process a single build phase
process_build_phase() {
    local phase="$1"
    local description
    description=$(jq -r ".build_order_hints[] | select(.phase == $phase) | .description" "$PACKAGES_JSON")

    log_phase "Phase $phase: $description"

    local packages
    packages=$(get_phase_packages "$phase")

    if [[ -z "$packages" ]]; then
        log_warn "No packages in phase $phase"
        return 0
    fi

    local phase_build_ids=()
    local phase_count=0

    while IFS= read -r name; do
        # Skip if targeting a specific package
        if [[ -n "$TARGET_PACKAGE" && "$name" != "$TARGET_PACKAGE" ]]; then
            continue
        fi

        local source_type
        source_type=$(get_package_source_type "$name")

        # Apply source type filters
        if [[ "$SCM_ONLY" == true && "$source_type" != "scm" ]]; then
            continue
        fi
        if [[ "$SRPM_ONLY" == true && "$source_type" != "upload" ]]; then
            continue
        fi

        # Only trigger builds for SCM packages — upload packages were already
        # submitted as builds during the SRPM upload step
        if [[ "$source_type" == "scm" ]]; then
            local build_id
            if build_id=$(trigger_scm_build "$name"); then
                phase_build_ids+=("$build_id")
                phase_count=$((phase_count + 1))
            fi
        else
            log_skip "Skipping build trigger for upload package $name (submitted during SRPM upload)"
        fi
    done <<< "$packages"

    # Wait for all builds in this phase to complete before moving on
    if [[ $phase_count -gt 0 && ${#phase_build_ids[@]} -gt 0 ]]; then
        log_info "Phase $phase: $phase_count build(s) triggered — waiting for completion"
        wait_for_builds "${phase_build_ids[@]}" || \
            log_warn "Phase $phase: Some builds failed — continuing to next phase"
    else
        log_info "Phase $phase: No builds to wait for"
    fi
}

trigger_phased_builds() {
    log_header "Step 5: Triggering phased builds"

    if [[ "$SKIP_BUILDS" == true ]]; then
        log_skip "Build triggering skipped (--skip-builds)"
        return 0
    fi

    # Determine which phases to process
    local phases
    if [[ -n "$TARGET_PHASE" ]]; then
        # Validate phase number
        if ! jq -e ".build_order_hints[] | select(.phase == $TARGET_PHASE)" "$PACKAGES_JSON" &>/dev/null; then
            log_error "Invalid phase: $TARGET_PHASE (valid phases: 1-6)"
            return 1
        fi
        phases=("$TARGET_PHASE")
        log_info "Processing single phase: $TARGET_PHASE"
    else
        # Process all phases in order
        phases=($(jq -r '.build_order_hints[].phase' "$PACKAGES_JSON" | sort -n))
        log_info "Processing all ${#phases[@]} phases: ${phases[*]}"
    fi

    for phase in "${phases[@]}"; do
        process_build_phase "$phase"
        echo ""  # visual separator between phases
    done
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    log_header "Summary"

    echo ""
    log_info "Total packages processed:   $TOTAL_PROCESSED"
    echo ""
    log_info "SCM packages added/updated: $SCM_ADDED"
    if [[ $SCM_FAILED -gt 0 ]]; then
        log_error "SCM packages failed:        $SCM_FAILED"
    fi
    echo ""
    log_info "SRPMs downloaded:           $SRPM_DOWNLOADED"
    log_info "SRPMs uploaded:             $SRPM_UPLOADED"
    log_info "SRPMs skipped (existing):   $SRPM_SKIPPED"
    if [[ $SRPM_FAILED -gt 0 ]]; then
        log_error "SRPMs failed:               $SRPM_FAILED"
    fi
    echo ""

    if [[ "$SKIP_BUILDS" == false ]]; then
        log_info "Builds triggered:           $BUILDS_TRIGGERED"
        log_info "Builds succeeded:           $BUILDS_SUCCEEDED"
        if [[ $BUILDS_FAILED -gt 0 ]]; then
            log_error "Builds failed:              $BUILDS_FAILED"
        fi
    else
        log_info "Builds: skipped (--skip-builds)"
    fi

    echo ""
    local total_failures=$((SCM_FAILED + SRPM_FAILED + BUILDS_FAILED))
    if [[ $total_failures -eq 0 ]]; then
        log_ok "All operations completed successfully!"
    else
        log_warn "Completed with $total_failures failure(s) — check the log: $LOG_FILE"
    fi

    echo ""
    log_info "Project URL: https://copr.fedorainfracloud.org/coprs/$COPR_PROJECT/"
    log_info "Full log:    $LOG_FILE"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    # Initialize log file
    echo "" >> "$LOG_FILE"
    log_header "COPR Fork Setup — $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Project:   $COPR_PROJECT"
    log_info "JSON:      $PACKAGES_JSON"
    log_info "Options:   skip_builds=$SKIP_BUILDS phase=$TARGET_PHASE package=$TARGET_PACKAGE srpm_only=$SRPM_ONLY scm_only=$SCM_ONLY dry_run=$DRY_RUN"

    # Step 1: Validate
    validate_prerequisites

    # Step 2: Create/update COPR project
    create_copr_project

    # Step 3: Add SCM packages (unless --srpm-only)
    if [[ "$SRPM_ONLY" == false ]]; then
        process_scm_packages
    else
        log_skip "SCM packages skipped (--srpm-only)"
    fi

    # Step 4: Process upload (SRPM) packages (unless --scm-only)
    if [[ "$SCM_ONLY" == false ]]; then
        process_upload_packages
    else
        log_skip "Upload packages skipped (--scm-only)"
    fi

    # Step 5: Trigger phased builds
    trigger_phased_builds

    # Summary
    print_summary
}

main
