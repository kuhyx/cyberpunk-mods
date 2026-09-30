#!/bin/bash

# ============================================================================
# Remove everything install.sh deployed (files listed in the manifest) and
# restore the pristine script bundle that redscript recompiles in place.
# None of the deployed files overwrote a vanilla file, so deleting them is a
# complete undo.
# ============================================================================

set -euo pipefail

readonly DATA="${CP2077_MODS_DATA:-$HOME/data/cyberpunk-mods}"
readonly MANIFEST="$DATA/installed.manifest"
readonly VANILLA_BUNDLE="$DATA/vanilla/final.redscripts"
GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"

main() {
    if [[ ! -f "$MANIFEST" ]]; then
        echo "Nothing to do: no manifest at $MANIFEST"
        exit 0
    fi
    local rel removed=0
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        if [[ -f "$GAME_DIR/$rel" ]]; then
            rm -f "$GAME_DIR/$rel"
            removed=$((removed + 1))
        fi
    done <"$MANIFEST"
    cp "$VANILLA_BUNDLE" "$GAME_DIR/r6/cache/final.redscripts"
    rm -f "$GAME_DIR/r6/cache/final.redscripts.bk" "$GAME_DIR/r6/cache/final.redscripts.modded"
    find "$GAME_DIR/r6/scripts" "$GAME_DIR/red4ext" "$GAME_DIR/bin/x64/plugins" \
        -depth -type d -empty -delete 2>/dev/null || true
    mv "$MANIFEST" "$MANIFEST.uninstalled"
    echo "removed $removed files; vanilla script bundle restored"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --game-dir) GAME_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

main
