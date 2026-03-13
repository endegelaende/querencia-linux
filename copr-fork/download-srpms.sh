#!/usr/bin/env bash
# download-srpms.sh — Download SRPMs from skip77's COPR build results
#
# The COPR API returns SRPM URLs under /srpm-builds/ which get cleaned up.
# The actual SRPMs are still available in the per-chroot build result dirs:
#   /results/skip77/MateDesktop-EL10/rhel+epel-10-x86_64/<buildid>-<name>/
#
# This script finds the build ID via the API, then downloads the .src.rpm
# from the build result directory.
#
set -euo pipefail

COPR_API="https://copr.fedorainfracloud.org/api_3"
DOWNLOAD_BASE="https://download.copr.fedorainfracloud.org/results/skip77/MateDesktop-EL10/rhel+epel-10-x86_64"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRPM_DIR="$SCRIPT_DIR/srpms"
PACKAGES_JSON="$SCRIPT_DIR/packages.json"

mkdir -p "$SRPM_DIR"

# Validate tools
for cmd in jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' is required but not found." >&2
        exit 1
    fi
done

if [[ ! -f "$PACKAGES_JSON" ]]; then
    echo "ERROR: packages.json not found at $PACKAGES_JSON" >&2
    exit 1
fi

# Get all upload package names
upload_pkgs=$(jq -r '.packages[] | select(.source_type == "upload") | .name' "$PACKAGES_JSON")
total=$(echo "$upload_pkgs" | wc -l)
count=0
ok=0
fail=0

echo "=== Downloading SRPMs from skip77/MateDesktop-EL10 ==="
echo "    Packages to download: $total"
echo ""

for name in $upload_pkgs; do
    count=$((count + 1))
    echo "[$count/$total] $name"

    # Get build ID from API
    response=$(curl -s --max-time 15 \
        "${COPR_API}/package?ownername=skip77&projectname=MateDesktop-EL10&packagename=${name}&with_latest_succeeded_build=true" \
        2>/dev/null)

    if [[ -z "$response" ]]; then
        echo "  ERROR: Empty API response"
        fail=$((fail + 1))
        continue
    fi

    build_id=$(echo "$response" | jq -r '.builds.latest_succeeded.id // empty')

    if [[ -z "$build_id" ]]; then
        echo "  ERROR: No successful build found"
        fail=$((fail + 1))
        continue
    fi

    # Pad build ID to 8 digits (COPR uses zero-padded IDs in directory names)
    padded_id=$(printf "%08d" "$build_id")

    # Build result directory URL
    dir_url="${DOWNLOAD_BASE}/${padded_id}-${name}/"
    echo "  Build ID: $build_id -> $dir_url"

    # Fetch the directory listing and find the .src.rpm filename
    dir_listing=$(curl -s --max-time 15 "$dir_url" 2>/dev/null)

    if [[ -z "$dir_listing" ]]; then
        echo "  ERROR: Could not fetch build directory listing"
        fail=$((fail + 1))
        continue
    fi

    # Extract .src.rpm filename from HTML directory listing
    srpm_file=$(echo "$dir_listing" | grep -oP '[a-zA-Z0-9._+-]+\.src\.rpm' | head -1 || true)

    if [[ -z "$srpm_file" ]]; then
        echo "  ERROR: No .src.rpm found in build directory"
        fail=$((fail + 1))
        continue
    fi

    srpm_url="${dir_url}${srpm_file}"
    local_file="$SRPM_DIR/$srpm_file"

    if [[ -f "$local_file" ]]; then
        echo "  SKIP: Already downloaded $srpm_file"
        ok=$((ok + 1))
        continue
    fi

    echo "  Downloading: $srpm_file"
    if curl -fSL --max-time 120 -o "$local_file" "$srpm_url" 2>/dev/null; then
        size=$(du -h "$local_file" | cut -f1)
        echo "  OK: $srpm_file ($size)"
        ok=$((ok + 1))
    else
        echo "  FAILED: Could not download $srpm_url"
        rm -f "$local_file"
        fail=$((fail + 1))
    fi
done

echo ""
echo "=== Download Summary ==="
echo "  Success: $ok/$total"
if [[ $fail -gt 0 ]]; then
    echo "  Failed:  $fail/$total"
fi
echo ""
echo "SRPMs saved to: $SRPM_DIR"
if [[ -d "$SRPM_DIR" ]] && ls "$SRPM_DIR"/*.src.rpm &>/dev/null 2>&1; then
    echo ""
    ls -lhS "$SRPM_DIR"/*.src.rpm
fi
