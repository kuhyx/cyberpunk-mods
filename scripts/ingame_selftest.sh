#!/bin/bash

# ============================================================================
# End-to-end in-game test. Installs the kuhy_selftest CET mod, launches the
# game through Steam (the real launch path: launch options, Proton, auto-
# continue), injects the right-click / Esc the fast-travel test asks for,
# screenshots the run, then removes the test mod and prints the results.
#
# It drives the LIVE display and loads the newest save; back up saves first
# (install flow: ~/data/cyberpunk-mods/backups/). Exit 0 only if every check
# passed and scripts/check_logs.sh is clean.
# Requires: steam, xdotool, ImageMagick (import).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly REPO_ROOT
readonly GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
readonly MOD_DIR="$GAME_DIR/bin/x64/plugins/cyber_engine_tweaks/mods/kuhy_selftest"
readonly TIMEOUT_S="${SELFTEST_TIMEOUT_S:-900}"
OUT="${CP2077_MODS_DATA:-$HOME/data/cyberpunk-mods}/selftest/$(date +%Y%m%d-%H%M%S)"
readonly OUT
export DISPLAY="${DISPLAY:-:0}"

cleanup() {
    rm -rf "$MOD_DIR"
}
trap cleanup EXIT

game_pid() {
    pgrep -f 'Cyberpunk2077\.exe' | head -1 || true
}

shot() {
    import -display "$DISPLAY" -window root "$OUT/$(date +%H%M%S)-$1.png" 2>/dev/null || true
}

# Send one xdotool input action to whatever has focus (the game, which
# launched fullscreen). No windowactivate: changing focus made a fullscreen
# lock screen re-raise itself over the game and swallow the input.
send() {
    sleep 0.5
    "$@"
}

phase() {
    cat "$MOD_DIR/state.txt" 2>/dev/null || echo none
}

main() {
    mkdir -p "$OUT" "$MOD_DIR"
    cp "$REPO_ROOT"/tests/ingame/kuhy_selftest/*.lua "$MOD_DIR/"
    if [[ -n "$(game_pid)" ]]; then
        echo "Error: the game is already running" >&2
        exit 1
    fi
    if ! pgrep -x steam >/dev/null; then
        setsid steam -silent >/dev/null 2>&1 < /dev/null &
        sleep 20
    fi
    local started; started="$(date +%s)"
    steam steam://rungameid/1091500 >/dev/null 2>&1 &

    local last="" now elapsed shots=0 changed=0
    while true; do
        now="$(phase)"
        elapsed=$(( $(date +%s) - started ))
        if [[ "$now" != "$last" ]]; then
            changed="$elapsed"
            echo "[$elapsed s] phase: $now"
            shot "$now"
            last="$now"
            case "$now" in
                ft_ready_for_rmb)
                    sleep 2; shot map-before-rmb
                    # SELFTEST_FT_ESC_ONLY=1 skips the click, isolating the Esc check
                    # from anything a mouse event wakes up (a lock screen did).
                    if [[ "${SELFTEST_FT_ESC_ONLY:-0}" != 1 ]]; then
                        send xdotool mousemove 1920 1080 click 3
                    fi
                    : >"$MOD_DIR/rmb_done"
                    sleep 2; shot map-after-rmb ;;
                need_continue)
                    sleep 3; shot continue-prompt
                    send xdotool key space ;;
                ft_ready_for_esc)
                    send xdotool key Escape
                    : >"$MOD_DIR/esc_done"
                    sleep 2; shot after-esc ;;
            esac
        fi
        # A screenshot every 10 s until the save is live shows the boot path.
        if [[ "$now" == "boot" || "$now" == "none" ]] && (( elapsed / 10 > shots )); then
            shots=$(( elapsed / 10 )); shot "boot-${elapsed}s"
        fi
        if [[ "$now" != "none" && "$now" != "boot" && "$now" != "done" ]] && (( elapsed - changed > 150 )); then
            echo "phase $now stalled for 150 s (game frozen?)"
            shot stalled
            break
        fi
        if [[ "$now" == "none" ]] && (( elapsed > 240 )); then
            echo "CET self-test never started after 240 s (hung before the main menu)"
            shot hung
            break
        fi
        if [[ "$now" == "done" ]] || (( elapsed > TIMEOUT_S )); then
            break
        fi
        if (( elapsed > 60 )) && [[ -z "$(game_pid)" ]]; then
            echo "game exited during phase $now"
            break
        fi
        sleep 1
    done

    local waited=0
    while [[ -n "$(game_pid)" ]] && (( waited < 60 )); do sleep 2; waited=$((waited + 2)); done
    if [[ -n "$(game_pid)" ]]; then
        echo "game still running after test; terminating it"
        kill "$(game_pid)" || true
    fi

    cp "$MOD_DIR/results.txt" "$OUT/" 2>/dev/null || true
    cleanup
    echo "--- results ($OUT)"
    cat "$OUT/results.txt" 2>/dev/null || echo "(no results file)"
    local status=0
    grep -q '^DONE fails=0$' "$OUT/results.txt" 2>/dev/null || status=1
    "$REPO_ROOT/scripts/check_logs.sh" || status=1
    exit "$status"
}

main "$@"
