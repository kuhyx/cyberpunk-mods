#!/bin/bash

# ============================================================================
# Build archive/pc/mod/kuhy_skip_intro.archive from the installed game: the
# startup logo/intro videos, each cut to its first frame, packed under their
# original depot paths so the game loads them instead of the originals.
# Built locally from the player's own files -- no CDPR asset in the repo.
#
# Usage: build_skip_intro.sh <game-dir> <output-root>
#   writes <output-root>/archive/pc/mod/kuhy_skip_intro.archive
# Requires: WolvenKit CLI (installed by ~/src/wiki-kb/tools), python3.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
readonly WOLVENKIT="${WOLVENKIT_CLI:-$HOME/.local/opt/wolvenkit-cli/WolvenKit.CLI}"
readonly ARCHIVE_NAME="kuhy_skip_intro"
# Depot paths of the videos played before the main menu.
readonly VIDEOS=(
    'base\movies\fullscreen\logo_splashscreen\cp_logo_intro_en.bk2'
    'base\movies\fullscreen\common\cyberpunk2077_game_intro.bk2'
    'base\movies\fullscreen\common\cyberpunk2077_game_intro_rtx.bk2'
    'base\movies\fullscreen\common\cyberpunk2077_game_intro_message_en.bk2'
    'base\movies\fullscreen\common\intro_after_splash_screens.bk2'
)
TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

main() {
    local game_dir="$1" out_root="$2"
    if [[ ! -x "$WOLVENKIT" ]]; then
        echo "Error: WolvenKit CLI not found at $WOLVENKIT (run ~/src/wiki-kb/tools/install_gamefiles_tools.sh)" >&2
        exit 1
    fi
    TEMP_DIR="$(mktemp -d "${CP2077_MODS_DATA:-$HOME/data/cyberpunk-mods}/skipintro.XXXXXX")"

    # Escape the depot paths into one anchored alternation for WolvenKit.
    local regex="" video
    for video in "${VIDEOS[@]}"; do
        regex+="${regex:+|}$(printf '%s' "$video" | sed 's/[\\.]/\\&/g')"
    done
    "$WOLVENKIT" extract "$game_dir/archive/pc/content/basegame_1_engine.archive" \
        -o "$TEMP_DIR/src" -r "^($regex)\$" -v Minimal >/dev/null

    local rel dir
    for video in "${VIDEOS[@]}"; do
        rel="${video//\\//}"
        dir="$TEMP_DIR/$ARCHIVE_NAME/$(dirname "$rel")"
        mkdir -p "$dir"
        python3 "$SCRIPT_DIR/bink_truncate.py" "$TEMP_DIR/src/$rel" --out "$dir"
    done

    mkdir -p "$out_root/archive/pc/mod"
    "$WOLVENKIT" pack "$TEMP_DIR/$ARCHIVE_NAME" -o "$out_root/archive/pc/mod" -v Minimal >/dev/null
    local archive="$out_root/archive/pc/mod/$ARCHIVE_NAME.archive"
    if [[ ! -s "$archive" ]]; then
        echo "Error: pack produced no $archive" >&2
        exit 1
    fi
    # Gate: the packed archive must list exactly the replaced videos.
    local listed
    listed="$("$WOLVENKIT" archive "$archive" -l 2>/dev/null | grep -c '\.bk2' || true)"
    if [[ "$listed" -ne ${#VIDEOS[@]} ]]; then
        echo "Error: $archive lists $listed videos, expected ${#VIDEOS[@]}" >&2
        exit 1
    fi
    echo "built $archive ($listed videos, $(stat -c %s "$archive") bytes)"
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $(basename "$0") <game-dir> <output-root>" >&2
    exit 1
fi
main "$@"
