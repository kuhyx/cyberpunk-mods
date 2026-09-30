#!/bin/bash

# ============================================================================
# CET (and other mods built with MSVC 17.10+) crash in DllMain on an older
# msvcp140.dll: "Unable to load cyber_engine_tweaks.asi. Error: 998" -- an
# access violation in MSVCP140 during std::mutex::lock. Cyberpunk's own
# _CommonRedist installs 14.28 into the Proton prefix, so upgrade the prefix
# to the current VC++ 2015-2022 runtime whenever it is older than 14.40.
# Idempotent; a prefix reset by Steam is repaired on the next install.sh.
# Requires: protontricks (installed if missing).
# ============================================================================

set -euo pipefail

readonly APP_ID=1091500
readonly MIN_MINOR=40
readonly PREFIX="$HOME/.local/share/Steam/steamapps/compatdata/$APP_ID/pfx"
readonly DLL="$PREFIX/drive_c/windows/system32/msvcp140.dll"

runtime_version() {
    strings -el "$DLL" 2>/dev/null | grep -A1 -m1 '^FileVersion$' | tail -1 | cut -d' ' -f1
}

main() {
    if [[ ! -f "$DLL" ]]; then
        echo "skip vcruntime: no Proton prefix yet (launch the game once first)"
        return 0
    fi
    local version minor
    version="$(runtime_version)"
    minor="$(cut -d. -f2 <<<"$version")"
    if [[ "${minor:-0}" -ge "$MIN_MINOR" ]]; then
        echo "ok   vcruntime $version in the Proton prefix"
        return 0
    fi
    command -v protontricks >/dev/null || sudo pacman -S --needed --noconfirm protontricks
    echo "upgrading vcruntime $version -> vcrun2022 (CET needs >= 14.$MIN_MINOR)"
    WINEDEBUG=-all protontricks "$APP_ID" -q vcrun2022 >/dev/null
    version="$(runtime_version)"
    minor="$(cut -d. -f2 <<<"$version")"
    if [[ "${minor:-0}" -lt "$MIN_MINOR" ]]; then
        echo "Error: vcruntime still $version after vcrun2022" >&2
        exit 1
    fi
    echo "ok   vcruntime $version in the Proton prefix"
}

main "$@"
