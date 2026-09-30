#!/bin/bash

# ============================================================================
# Every framework in frameworks.lock pinned to its repo's newest STABLE
# GitHub release (the dependency-freshness rule for this custom manifest).
# Exit 1 when a pin is behind, 3 when the answer cannot be determined.
# Requires: curl, jq. GITHUB_TOKEN is used when set (CI rate limits).
# ============================================================================

set -euo pipefail

LOCK="$(cd "$(dirname "$0")/.." && pwd)/frameworks.lock"
readonly LOCK

latest_tag() {
    local repo="$1" auth=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    # /releases/latest skips drafts and pre-releases by definition.
    curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -er '.tag_name'
}

main() {
    local name url repo tag latest behind=0
    while IFS=$'\t' read -r name url _; do
        [[ "$url" =~ github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/ ]] || continue
        repo="${BASH_REMATCH[1]}"
        tag="${BASH_REMATCH[2]}"
        if ! latest="$(latest_tag "$repo")"; then
            echo "UNKNOWN $name: could not query $repo" >&2
            exit 3
        fi
        if [[ "$tag" == "$latest" ]]; then
            echo "ok      $name $tag"
        else
            echo "BEHIND  $name $tag -> $latest"
            behind=1
        fi
    done < <(grep -vE '^\s*(#|$)' "$LOCK")
    exit "$behind"
}

main "$@"
