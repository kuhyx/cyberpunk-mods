#!/bin/bash

# ============================================================================
# After a launch: did every framework and mod load? Reads the RED4ext, CET
# and redscript logs in the game directory and exits non-zero on any error.
# Also prints the mods' own ModLog lines (auto-continue, auto-track reverts,
# combat-music switches) so behaviour can be traced after a play session.
# ============================================================================

set -euo pipefail

GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
FAILED=0

# Print a log's error lines; mark failure if there are any.
scan() {
    local label="$1" file="$2" pattern="$3"
    if [[ ! -f "$file" ]]; then
        echo "MISSING $label log: $file (framework never loaded?)"
        FAILED=1
        return
    fi
    local hits
    hits="$(grep -aiE "$pattern" "$file" | tail -20 || true)"
    if [[ -n "$hits" ]]; then
        echo "ERRORS in $label ($file):"
        echo "$hits"
        FAILED=1
    else
        echo "ok      $label ($(stat -c %y "$file" | cut -d. -f1))"
    fi
}

main() {
    local red4ext_log
    red4ext_log="$(find "$GAME_DIR/red4ext/logs" -maxdepth 1 -name 'red4ext*.log' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2- || true)"
    scan RED4ext "${red4ext_log:-$GAME_DIR/red4ext/logs/red4ext.log}" '\[(error|critical)\]'
    scan CET "$GAME_DIR/bin/x64/plugins/cyber_engine_tweaks/cyber_engine_tweaks.log" '\[(error|critical)\]'
    scan redscript "$GAME_DIR/r6/logs/redscript_rCURRENT.log" '^\s*\[?ERROR|compilation failed'

    echo "--- mod log lines"
    grep -rahE 'Kuhy\.' "$GAME_DIR/r6/logs" "$GAME_DIR/red4ext/logs" 2>/dev/null | tail -30 || true
    exit "$FAILED"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --game-dir) GAME_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

main
