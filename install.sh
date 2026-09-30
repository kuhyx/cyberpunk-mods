#!/bin/bash

# ============================================================================
# Install the pinned frameworks, this repo's mods and (if downloaded) Auto
# Drive Enhanced into the Cyberpunk 2077 game directory.
#
#   1. scripts/check.sh must pass (one redscript error disables every mod).
#   2. Framework zips + mods/* are copied into the game root; every file
#      written is recorded in the manifest so uninstall.sh can remove it.
#   3. Auto Drive Enhanced is taken from the newest matching archive in
#      ~/Downloads (Nexus-only: one manual "Manual download" click).
#
# Steam launch options are a separate step (scripts/set_launch_options.py)
# because Steam must be closed for that edit to stick.
# Requires: unzip, 7z, rsync.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
readonly REPO_ROOT
readonly DATA="${CP2077_MODS_DATA:-$HOME/data/cyberpunk-mods}"
readonly CACHE="${CP2077_MODS_CACHE:-$DATA/cache}"
readonly MANIFEST="$DATA/installed.manifest"
readonly ADE_GLOB='Auto Drive Enhanced*'
GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
DOWNLOADS="$HOME/Downloads"
TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    echo "Usage: $(basename "$0") [--game-dir DIR] [--downloads DIR]"
    exit 0
}

ensure_tools() {
    local missing=()
    command -v unzip >/dev/null || missing+=(unzip)
    command -v 7z >/dev/null || missing+=(7zip)
    command -v rsync >/dev/null || missing+=(rsync)
    command -v xvfb-run >/dev/null || missing+=(xorg-server-xvfb)
    command -v wine >/dev/null || missing+=(wine)
    if [[ ${#missing[@]} -gt 0 ]]; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
}

# Copy a staged tree into the game root and append its files to a manifest.
deploy_tree() {
    local src="$1" manifest="$2"
    find "$src" -type f -printf '%P\n' >>"$manifest"
    rsync -a "$src/" "$GAME_DIR/"
}

# Newest Auto Drive Enhanced archive, extracted; prints the dir holding the
# game-root layout (r6/, red4ext/, archive/ ...), or nothing if absent.
stage_auto_drive() {
    local archive root
    archive="$(find "$DOWNLOADS" -maxdepth 2 -type f -iname "$ADE_GLOB" \
        \( -iname '*.zip' -o -iname '*.7z' -o -iname '*.rar' \) -printf '%T@ %p\n' \
        | sort -rn | head -1 | cut -d' ' -f2-)"
    if [[ -z "$archive" ]]; then
        return 0
    fi
    7z x -y -o"$TEMP_DIR/ade" "$archive" >/dev/null
    root="$(find "$TEMP_DIR/ade" -maxdepth 3 -type d \( -name r6 -o -name red4ext -o -name archive \) \
        -printf '%h\n' | head -1)"
    echo "${root:-}"
}

main() {
    if [[ ! -f "$GAME_DIR/bin/x64/Cyberpunk2077.exe" ]]; then
        echo "Error: no Cyberpunk2077.exe under $GAME_DIR" >&2
        exit 1
    fi
    ensure_tools
    TEMP_DIR="$(mktemp -d "$DATA/install.XXXXXX")"

    local ade_root
    ade_root="$(stage_auto_drive)"
    if [[ -n "$ade_root" ]]; then
        EXTRA_REDS_DIR="$ade_root" "$REPO_ROOT/scripts/check.sh"
    else
        "$REPO_ROOT/scripts/check.sh"
    fi

    : >"$MANIFEST.new"
    local name url
    while IFS=$'\t' read -r name url _; do
        [[ "$name" == @* ]] && continue
        mkdir -p "$TEMP_DIR/fw/$name"
        unzip -q -o "$CACHE/$(basename "$url")" -d "$TEMP_DIR/fw/$name"
        deploy_tree "$TEMP_DIR/fw/$name" "$MANIFEST.new"
        echo "installed $name"
    done < <(grep -vE '^\s*(#|$)' "$REPO_ROOT/frameworks.lock")

    local mod
    for mod in "$REPO_ROOT"/mods/*/; do
        deploy_tree "$mod" "$MANIFEST.new"
        echo "installed $(basename "$mod")"
    done

    "$REPO_ROOT/scripts/build_skip_intro.sh" "$GAME_DIR" "$TEMP_DIR/skip_intro"
    deploy_tree "$TEMP_DIR/skip_intro" "$MANIFEST.new"
    echo "installed skip_intro"

    if [[ -n "$ade_root" ]]; then
        deploy_tree "$ade_root" "$MANIFEST.new"
        echo "installed Auto Drive Enhanced"
    else
        echo "SKIP Auto Drive Enhanced: no '$ADE_GLOB' archive in $DOWNLOADS"
        echo "     get it from https://www.nexusmods.com/cyberpunk2077/mods/23157?tab=files"
    fi

    sort -u "$MANIFEST.new" "$MANIFEST" 2>/dev/null >"$MANIFEST.tmp" || sort -u "$MANIFEST.new" >"$MANIFEST.tmp"
    mv "$MANIFEST.tmp" "$MANIFEST"
    rm -f "$MANIFEST.new"
    echo "done: $(wc -l <"$MANIFEST") files tracked in $MANIFEST"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --game-dir) GAME_DIR="$2"; shift 2 ;;
        --downloads) DOWNLOADS="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

main
