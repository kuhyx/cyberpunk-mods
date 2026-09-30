#!/bin/bash

# ============================================================================
# Offline compile gate: compile every framework .reds plus every mod in
# mods/ against the pristine 2.31 script bundle with the pinned redscript
# compiler (run headless under wine). One redscript error disables ALL
# script mods in game, so install.sh refuses to deploy unless this passes.
# Optional: also compiles third-party .reds found under $EXTRA_REDS_DIR
# (install.sh points it at the extracted Auto Drive Enhanced).
# Requires: wine, xvfb-run, unzip; heavy work runs via capped.sh.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly REPO_ROOT
readonly DATA="${CP2077_MODS_DATA:-$HOME/data/cyberpunk-mods}"
readonly CACHE="${CP2077_MODS_CACHE:-$DATA/cache}"
readonly VANILLA_BUNDLE="$DATA/vanilla/final.redscripts"
readonly VANILLA_SHA="2119046f3f3466206d8a16a4803b0ef0f3c90926ab689f9abbd5b8e42e28ee86"
readonly CAPPED="$HOME/.claude/scripts/capped.sh"
STAGE=""

cleanup() {
    if [[ -n "$STAGE" && -d "$STAGE" ]]; then
        rm -rf "$STAGE"
    fi
}
trap cleanup EXIT

# Unix path -> wine Z: path.
winpath() {
    local p="$1"
    printf 'Z:%s' "${p//\//\\}"
}

stage_sources() {
    local zip
    mkdir -p "$STAGE/src/frameworks" "$STAGE/src/mods"
    for zip in "$CACHE"/*.zip; do
        unzip -q -o "$zip" '*.reds' -d "$STAGE/src/frameworks/$(basename "$zip" .zip)" 2>/dev/null || true
    done
    cp -r "$REPO_ROOT/mods/." "$STAGE/src/mods/"
    if [[ -n "${EXTRA_REDS_DIR:-}" ]]; then
        cp -r "$EXTRA_REDS_DIR" "$STAGE/src/extra"
    fi
}

compile_pass() {
    local label="$1" src="$2" log="$STAGE/compile.log" status=0
    rm -f "$STAGE/out.redscripts"
    WINEPREFIX="$DATA/wineprefix" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" \
        "$CAPPED" env -u DISPLAY -u WAYLAND_DISPLAY timeout 900 xvfb-run -a \
        wine "$CACHE/redscript-cli.exe" compile \
        -s "$(winpath "$src")" \
        -b "$(winpath "$VANILLA_BUNDLE")" \
        -o "$(winpath "$STAGE/out.redscripts")" >"$log" 2>&1 || status=$?

    # Keep only compiler errors (wine/mesa/X chatter and warnings are noise).
    grep -A4 -E '^ERROR ' "$log" || true
    # The CLI exits 0 even on a failed build; its ERROR lines are the verdict.
    if [[ "$status" -ne 0 || ! -s "$STAGE/out.redscripts" ]] || grep -qE '^ERROR ' "$log"; then
        echo "FAIL: redscript compile, $label (exit $status)" >&2
        exit 1
    fi
    echo "ok   compile, $label"
}

main() {
    if [[ "$(sha256sum "$VANILLA_BUNDLE" | cut -d' ' -f1)" != "$VANILLA_SHA" ]]; then
        echo "Error: $VANILLA_BUNDLE is missing or not the pristine 2.31 bundle" >&2
        exit 1
    fi
    "$REPO_ROOT/scripts/fetch_frameworks.sh" >/dev/null
    STAGE="$(mktemp -d "$DATA/check.XXXXXX")"
    stage_sources

    # Pass 1: the real install (frameworks + mods). Pass 2: mods alone, as
    # the game compiles them when RED4ext fails to load (e.g. launch options
    # not applied yet) -- that must not break every script mod either.
    compile_pass "with frameworks" "$STAGE/src"
    compile_pass "mods only" "$STAGE/src/mods"
    echo "PASS: all mods compile against the 2.31 bundle"
}

main "$@"
