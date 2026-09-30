#!/bin/bash

# ============================================================================
# Download every archive pinned in frameworks.lock into the cache and verify
# its sha256. --update-hashes rewrites the lock with the downloaded hashes
# (only after a deliberate version bump).
# Requires: curl, sha256sum.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly REPO_ROOT
readonly LOCK="$REPO_ROOT/frameworks.lock"
readonly CACHE="${CP2077_MODS_CACHE:-$HOME/data/cyberpunk-mods/cache}"
UPDATE_HASHES=0

usage() {
    echo "Usage: $(basename "$0") [--update-hashes]"
    exit 0
}

# Print "<name> <url> <sha>" for every non-comment lock line.
lock_entries() {
    grep -vE '^\s*(#|$)' "$LOCK"
}

fetch_one() {
    local name="$1" url="$2" want="$3"
    local dest
    dest="$CACHE/$(basename "$url")"
    if [[ ! -s "$dest" ]]; then
        curl -fsSL --retry 3 -o "$dest.part" "$url"
        mv "$dest.part" "$dest"
    fi
    local got
    got="$(sha256sum "$dest" | cut -d' ' -f1)"
    if [[ "$UPDATE_HASHES" -eq 1 ]]; then
        sed -i "s|^\(${name}\t[^\t]*\t\).*|\1${got}|" "$LOCK"
    elif [[ "$want" != "$got" ]]; then
        echo "Error: sha256 mismatch for $name ($dest): want $want got $got" >&2
        exit 1
    fi
    echo "ok  $name"
}

main() {
    mkdir -p "$CACHE"
    local name url sha
    while IFS=$'\t' read -r name url sha; do
        fetch_one "$name" "$url" "$sha"
    done < <(lock_entries)
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --update-hashes) UPDATE_HASHES=1; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

main
