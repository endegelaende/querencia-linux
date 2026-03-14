#!/usr/bin/env bash
# =============================================================================
# migrate-to-forks-curl.sh — Migrate upload packages to SCM forks via COPR API
# =============================================================================
#
# Pure curl-based version of migrate-to-forks.sh — works on Windows (Git Bash)
# and any system with bash + curl + jq. No copr-cli or Linux VM required.
#
# Migrates these packages from upload (SRPM) to SCM (GitHub fork):
#   - system-config-printer  → endegelaende/rpms-system-config-printer  (f43-el10)
#   - qadwaitadecorations    → endegelaende/rpms-qadwaitadecorations    (f43-el10)
#
# Prerequisites:
#   - bash, curl, jq
#   - COPR API credentials as environment variables (see below)
#
# Get your API token at: https://copr.fedorainfracloud.org/api/
# (Account: winonaoctober, Expiry: 08.09.2026)
#
# Usage:
#   # Set credentials first:
#   export COPR_LOGIN="your-login-token"
#   export COPR_TOKEN="your-api-token"
#
#   # Dry run (read-only — shows current state, no changes):
#   ./migrate-to-forks-curl.sh --dry-run
#
#   # Execute migration:
#   ./migrate-to-forks-curl.sh
#
#   # Migrate only one package:
#   ./migrate-to-forks-curl.sh --package system-config-printer
#   ./migrate-to-forks-curl.sh --package qadwaitadecorations
#
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
COPR_API="https://copr.fedorainfracloud.org/api_3"
COPR_OWNER="winonaoctober"
COPR_PROJECT="MateDesktop-EL10"

# Package definitions: name → clone_url, branch
declare -A CLONE_URLS=(
    ["system-config-printer"]="https://github.com/endegelaende/rpms-system-config-printer.git"
    ["qadwaitadecorations"]="https://github.com/endegelaende/rpms-qadwaitadecorations.git"
)

declare -A BRANCHES=(
    ["system-config-printer"]="f43-el10"
    ["qadwaitadecorations"]="f43-el10"
)

# Packages to migrate (order doesn't matter — no deps between them)
ALL_PACKAGES=("system-config-printer" "qadwaitadecorations")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
DRY_RUN=false
ONLY_PACKAGE=""
ERRORS=0

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BOLD}${CYAN}==> $*${NC}"; }
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${NC} $*"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --package)
            ONLY_PACKAGE="$2"
            shift 2
            ;;
        --help|-h)
            head -35 "$0" | tail -30
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            log_info "Usage: $0 [--dry-run] [--package NAME]"
            exit 1
            ;;
    esac
done

# Filter packages if --package was given
if [[ -n "$ONLY_PACKAGE" ]]; then
    if [[ -z "${CLONE_URLS[$ONLY_PACKAGE]+x}" ]]; then
        log_error "Unknown package: $ONLY_PACKAGE"
        log_info "Valid packages: ${ALL_PACKAGES[*]}"
        exit 1
    fi
    PACKAGES=("$ONLY_PACKAGE")
else
    PACKAGES=("${ALL_PACKAGES[@]}")
fi

# ---------------------------------------------------------------------------
# COPR API helpers
# ---------------------------------------------------------------------------

# GET request (no auth needed for read-only)
copr_get() {
    local url="$1"
    curl -s -f "$url" 2>/dev/null
}

# POST request (needs auth)
copr_post() {
    local url="$1"
    shift
    curl -s -f -X POST \
        -u "${COPR_LOGIN}:${COPR_TOKEN}" \
        "$url" \
        "$@"
}

# GET with auth (some endpoints need it)
copr_get_auth() {
    local url="$1"
    curl -s -f \
        -u "${COPR_LOGIN}:${COPR_TOKEN}" \
        "$url"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
preflight() {
    log_step "Preflight checks"
    echo

    # Check tools
    local missing=()
    for tool in curl jq; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing tools: ${missing[*]}"
        exit 1
    fi
    log_ok "Tools available: curl, jq"

    # Check credentials (not needed for dry-run read-only, but warn)
    if [[ -z "${COPR_LOGIN:-}" ]] || [[ -z "${COPR_TOKEN:-}" ]]; then
        if $DRY_RUN; then
            log_warn "COPR_LOGIN / COPR_TOKEN not set — dry-run will only show read-only info"
        else
            log_error "COPR_LOGIN and COPR_TOKEN must be set as environment variables"
            log_info ""
            log_info "Get your token at: https://copr.fedorainfracloud.org/api/"
            log_info ""
            log_info "Then run:"
            log_info "  export COPR_LOGIN=\"your-login-from-api-page\""
            log_info "  export COPR_TOKEN=\"your-token-from-api-page\""
            log_info ""
            exit 1
        fi
    else
        # Verify credentials work
        local response
        if response=$(curl -s -o /dev/null -w "%{http_code}" \
            -u "${COPR_LOGIN}:${COPR_TOKEN}" \
            "${COPR_API}/project?ownername=${COPR_OWNER}&projectname=${COPR_PROJECT}"); then
            if [[ "$response" == "200" ]]; then
                log_ok "COPR API credentials valid"
            else
                log_error "COPR API returned HTTP $response — check credentials"
                exit 1
            fi
        else
            log_error "Failed to reach COPR API"
            exit 1
        fi
    fi

    # Check GitHub repos are accessible
    for pkg in "${PACKAGES[@]}"; do
        local url="${CLONE_URLS[$pkg]}"
        local branch="${BRANCHES[$pkg]}"
        if git ls-remote --heads "$url" "$branch" 2>/dev/null | grep -q "$branch"; then
            log_ok "GitHub fork OK: $pkg ($branch)"
        else
            log_error "GitHub fork missing or branch not found: $url ($branch)"
            ERRORS=$((ERRORS + 1))
        fi
    done

    if [[ $ERRORS -gt 0 ]]; then
        log_error "Preflight failed with $ERRORS error(s)"
        exit 1
    fi

    echo
}

# ---------------------------------------------------------------------------
# Show current COPR state for a package
# ---------------------------------------------------------------------------
show_package_state() {
    local pkg="$1"
    log_info "Querying current COPR state for: $pkg"

    local response
    if response=$(copr_get "${COPR_API}/package?ownername=${COPR_OWNER}&projectname=${COPR_PROJECT}&packagename=${pkg}&with_latest_build=true" 2>/dev/null); then
        local source_type name
        source_type=$(echo "$response" | jq -r '.source_type // "unknown"')
        name=$(echo "$response" | jq -r '.name // "unknown"')

        echo "  Name:        $name"
        echo "  Source type:  $source_type"

        if [[ "$source_type" == "scm" ]]; then
            local clone_url committish method
            clone_url=$(echo "$response" | jq -r '.source_dict.clone_url // "n/a"')
            committish=$(echo "$response" | jq -r '.source_dict.committish // "n/a"')
            method=$(echo "$response" | jq -r '.source_dict.source_build_method // "n/a"')
            echo "  Clone URL:   $clone_url"
            echo "  Branch:      $committish"
            echo "  Method:      $method"
        fi

        # Latest build info
        local build_state build_version build_id
        build_state=$(echo "$response" | jq -r '.builds.latest.state // "none"')
        build_version=$(echo "$response" | jq -r '.builds.latest.source_package.version // "n/a"')
        build_id=$(echo "$response" | jq -r '.builds.latest.id // "n/a"')
        echo "  Latest build: #${build_id} — ${build_version} (${build_state})"
    else
        log_warn "Package $pkg not found in COPR (may have been deleted already)"
        echo "  Status: not found"
    fi
    echo
}

# ---------------------------------------------------------------------------
# Step 1: Delete old upload package entry
# ---------------------------------------------------------------------------
delete_package() {
    local pkg="$1"

    # Check if package exists first
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "${COPR_API}/package?ownername=${COPR_OWNER}&projectname=${COPR_PROJECT}&packagename=${pkg}")

    if [[ "$http_code" == "404" ]]; then
        log_ok "$pkg — not found in COPR (already deleted or never existed)"
        return 0
    fi

    if $DRY_RUN; then
        log_dry "Would delete package: $pkg"
        return 0
    fi

    log_info "Deleting package: $pkg"

    local response
    response=$(copr_post "${COPR_API}/package/delete" \
        -H "Content-Type: application/json" \
        -d "{
            \"ownername\": \"${COPR_OWNER}\",
            \"projectname\": \"${COPR_PROJECT}\",
            \"package_name\": \"${pkg}\"
        }" 2>&1) || true

    # The delete endpoint returns empty on success or an error object
    if [[ -z "$response" ]] || echo "$response" | jq -e '.output == "ok"' &>/dev/null; then
        log_ok "Deleted: $pkg"
    else
        # Check if it's already gone
        local check_code
        check_code=$(curl -s -o /dev/null -w "%{http_code}" \
            "${COPR_API}/package?ownername=${COPR_OWNER}&projectname=${COPR_PROJECT}&packagename=${pkg}")
        if [[ "$check_code" == "404" ]]; then
            log_ok "Deleted: $pkg (confirmed gone)"
        else
            log_error "Failed to delete $pkg — API response: $response"
            ERRORS=$((ERRORS + 1))
            return 1
        fi
    fi
}

# ---------------------------------------------------------------------------
# Step 2: Create SCM package entry
# ---------------------------------------------------------------------------
create_scm_package() {
    local pkg="$1"
    local clone_url="${CLONE_URLS[$pkg]}"
    local branch="${BRANCHES[$pkg]}"

    if $DRY_RUN; then
        log_dry "Would create SCM package: $pkg"
        log_dry "  Clone URL: $clone_url"
        log_dry "  Branch:    $branch"
        log_dry "  Method:    rpkg"
        return 0
    fi

    log_info "Creating SCM package: $pkg"
    log_info "  Clone URL: $clone_url"
    log_info "  Branch:    $branch"

    local response
    response=$(copr_post "${COPR_API}/package/add/${COPR_OWNER}/${COPR_PROJECT}/scm" \
        -H "Content-Type: application/json" \
        -d "{
            \"package_name\": \"${pkg}\",
            \"clone_url\": \"${clone_url}\",
            \"committish\": \"${branch}\",
            \"source_build_method\": \"rpkg\",
            \"spec\": \"\",
            \"scm_type\": \"git\"
        }" 2>&1)

    if echo "$response" | jq -e '.id' &>/dev/null; then
        local pkg_id
        pkg_id=$(echo "$response" | jq -r '.id')
        log_ok "Created SCM package: $pkg (id: $pkg_id)"
    else
        log_error "Failed to create SCM package: $pkg"
        log_error "Response: $response"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Step 3: Trigger build
# ---------------------------------------------------------------------------
trigger_build() {
    local pkg="$1"

    if $DRY_RUN; then
        log_dry "Would trigger build for: $pkg"
        return 0
    fi

    log_info "Triggering build for: $pkg"

    local response
    response=$(copr_post "${COPR_API}/package/build" \
        -H "Content-Type: application/json" \
        -d "{
            \"ownername\": \"${COPR_OWNER}\",
            \"projectname\": \"${COPR_PROJECT}\",
            \"package_name\": \"${pkg}\"
        }" 2>&1)

    if echo "$response" | jq -e '.builds' &>/dev/null; then
        local build_ids
        build_ids=$(echo "$response" | jq -r '.builds[].id' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
        log_ok "Build triggered: $pkg (build IDs: $build_ids)"
    elif echo "$response" | jq -e '.id' &>/dev/null; then
        local build_id
        build_id=$(echo "$response" | jq -r '.id')
        log_ok "Build triggered: $pkg (build ID: $build_id)"
    else
        log_error "Failed to trigger build for: $pkg"
        log_error "Response: $response"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Poll build status
# ---------------------------------------------------------------------------
poll_builds() {
    if $DRY_RUN; then
        return 0
    fi

    log_step "Checking build status (initial poll)"
    echo

    # Wait a moment for builds to register
    log_info "Waiting 15s for COPR to register builds..."
    sleep 15

    for pkg in "${PACKAGES[@]}"; do
        local response
        if response=$(copr_get "${COPR_API}/package?ownername=${COPR_OWNER}&projectname=${COPR_PROJECT}&packagename=${pkg}&with_latest_build=true" 2>/dev/null); then
            local state build_id
            state=$(echo "$response" | jq -r '.builds.latest.state // "unknown"')
            build_id=$(echo "$response" | jq -r '.builds.latest.id // "n/a"')

            case "$state" in
                succeeded)
                    log_ok "$pkg: build #$build_id — $state"
                    ;;
                running|pending|starting|importing|waiting)
                    log_info "$pkg: build #$build_id — $state (still in progress)"
                    ;;
                failed|forked)
                    log_error "$pkg: build #$build_id — $state"
                    log_info "  Check logs: https://copr.fedorainfracloud.org/coprs/build/$build_id/"
                    ;;
                *)
                    log_warn "$pkg: build #$build_id — $state"
                    ;;
            esac
        else
            log_warn "$pkg: could not query build status"
        fi
    done

    echo
}

# ===========================================================================
# Main
# ===========================================================================
main() {
    echo
    echo "============================================================"
    echo "  COPR Migration: Upload → SCM (curl-based)"
    echo "  Project: ${COPR_OWNER}/${COPR_PROJECT}"
    if $DRY_RUN; then
        echo "  Mode: DRY RUN (no changes)"
    else
        echo "  Mode: LIVE"
    fi
    echo "  Packages: ${PACKAGES[*]}"
    echo "============================================================"
    echo

    # Preflight
    preflight

    # Show current state
    log_step "Current COPR state"
    echo
    for pkg in "${PACKAGES[@]}"; do
        show_package_state "$pkg"
    done

    if $DRY_RUN; then
        log_step "Dry run: planned actions"
        echo
        for pkg in "${PACKAGES[@]}"; do
            log_dry "1. Delete upload package: $pkg"
            log_dry "2. Create SCM package: $pkg"
            log_dry "     Clone URL: ${CLONE_URLS[$pkg]}"
            log_dry "     Branch:    ${BRANCHES[$pkg]}"
            log_dry "     Method:    rpkg"
            log_dry "3. Trigger initial build: $pkg"
            echo
        done
        echo "============================================================"
        echo "  Dry run complete. No changes were made."
        echo "  Re-run without --dry-run to execute."
        echo "============================================================"
        echo
        return 0
    fi

    # Step 1: Delete old packages
    log_step "Step 1/3: Delete old upload package entries"
    echo
    for pkg in "${PACKAGES[@]}"; do
        delete_package "$pkg"
    done
    echo

    if [[ $ERRORS -gt 0 ]]; then
        log_error "Aborting: $ERRORS error(s) during deletion"
        exit 1
    fi

    # Wait for COPR to process deletions
    log_info "Waiting 10s for COPR to process deletions..."
    sleep 10

    # Step 2: Create SCM packages
    log_step "Step 2/3: Create SCM package entries"
    echo
    for pkg in "${PACKAGES[@]}"; do
        create_scm_package "$pkg"
    done
    echo

    if [[ $ERRORS -gt 0 ]]; then
        log_error "Aborting: $ERRORS error(s) during package creation"
        exit 1
    fi

    # Step 3: Trigger builds
    log_step "Step 3/3: Trigger initial builds"
    echo
    for pkg in "${PACKAGES[@]}"; do
        trigger_build "$pkg"
    done
    echo

    # Poll initial status
    poll_builds

    # Summary
    echo "============================================================"
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "  ${GREEN}Migration complete! ${#PACKAGES[@]} package(s) migrated.${NC}"
    else
        echo -e "  ${RED}Migration finished with $ERRORS error(s).${NC}"
    fi
    echo
    echo "  Monitor builds:"
    echo "    https://copr.fedorainfracloud.org/coprs/${COPR_OWNER}/${COPR_PROJECT}/monitor/"
    echo
    echo "  Individual build pages:"
    for pkg in "${PACKAGES[@]}"; do
        echo "    https://copr.fedorainfracloud.org/coprs/${COPR_OWNER}/${COPR_PROJECT}/package/${pkg}/"
    done
    echo
    echo "  After builds succeed, verify in the image build:"
    echo "    - system-config-printer GUI present (/usr/bin/system-config-printer)"
    echo "    - qadwaitadecorations Qt5 subpackage built"
    echo
    echo "  To re-check build status later:"
    echo "    curl -s '${COPR_API}/package?ownername=${COPR_OWNER}&projectname=${COPR_PROJECT}&packagename=PKGNAME&with_latest_build=true' | jq '.builds.latest.state'"
    echo "============================================================"
    echo

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi
}

main
