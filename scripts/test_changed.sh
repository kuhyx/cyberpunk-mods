#!/bin/bash

# ============================================================================
# Test the files changed vs HEAD (staged, unstaged, untracked). The repo has no
# unit-test framework: the testable surface offline is Lua syntax (CET mods and
# the in-game self-test) and the redscript compile gate. Quiet: failures plus
# a one-line summary. Falls back to every Lua file when nothing maps. The
# redscript gate (needs wine + the pristine game bundle) runs only when .reds
# or frameworks.lock changed and the bundle is present.
# ============================================================================

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
readonly BUNDLE="${CP2077_MODS_DATA:-$HOME/data/cyberpunk-mods}/vanilla/final.redscripts"

changed=()
while IFS= read -r f; do
    [[ -n "$f" && -e "$f" ]] && changed+=("$f")
done < <({ git diff --name-only HEAD 2>/dev/null || true; git ls-files --others --exclude-standard; } | sort -u)

if [[ ${#changed[@]} -eq 0 ]]; then echo "no changes vs HEAD: nothing to test"; exit 0; fi

lua_files=()
reds=0
for f in "${changed[@]}"; do
    case "$f" in
        *.lua) lua_files+=("$f") ;;
        *.reds | frameworks.lock) reds=1 ;;
    esac
done
if [[ ${#lua_files[@]} -eq 0 && $reds -eq 0 ]]; then
    echo "no mapped tests: checking every Lua file"
    mapfile -t lua_files < <(git ls-files '*.lua')
fi

rc=0
for f in "${lua_files[@]}"; do
    luac -p "$f" || rc=1
done
note=""
if [[ $reds -eq 1 ]]; then
    if [[ -f "$BUNDLE" ]]; then
        scripts/check.sh 2>&1 | grep -E '^(FAIL|PASS|Error)' || true
        [[ ${PIPESTATUS[0]} -eq 0 ]] || rc=1
    else
        note=" (redscript gate skipped: no vanilla bundle)"
    fi
fi
echo "checked ${#lua_files[@]} lua file(s), redscript=$reds: $([[ $rc -eq 0 ]] && echo pass || echo FAIL)$note"
exit "$rc"
