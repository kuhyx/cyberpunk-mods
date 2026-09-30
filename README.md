# cyberpunk-mods

Personal Cyberpunk 2077 (2.31, Steam + Proton) mods and the pinned framework
stack they run on.

| Mod | What it does |
|---|---|
| `auto_continue` | The first main menu of a game process loads the newest save ("Continue"). Returning to the menu later is left alone. |
| `no_auto_track` | Quest tracking only changes when you choose. Automatic switches (next quest after completion, new quest/gig/fixer, main-quest re-track) are reverted; a tracked quest advancing to its next objective stays tracked. |
| `fast_travel_map` | The fast-travel map behaves like the regular map: same filter, tracked-quest panel, no "select destination" box, right-click sets/removes a waypoint. Esc/B closes; hold to fast travel is unchanged. |
| `radio_in_combat` | With your car radio or pocket radio playing, combat neither fades it nor starts combat music. With no radio on, vanilla combat music. |
| `auto_disassemble` | Weapons, clothing, junk and weapon/clothing mods are disassembled on pickup (outside menus, so buying/crafting/stash transfers are safe), once after each load, and via the inventory's "Disassemble Junk" button. Never: iconics, equipped, wardrobe-outfit or favourited items, quest items, grenades, consumables, cyberware (incl. its mods and quickhacks), or the stash. |
| `no_load_prompt` | TweakXL override of the initial loading screens; with auto_continue's fast-travel loading-screen request it removes the "Press [Space] to continue" after the first load. |
| `skip_intro` | Built at install time from your own game files: the startup logo/intro videos cut to one frame (`archive/pc/mod/kuhy_skip_intro.archive`). |
| `kuhy_common` | Shared `KuhyLog` (Codeware `ModLog`, or a no-op if RED4ext did not load). |
| Auto Drive Enhanced | Third-party ([Nexus 23157](https://www.nexusmods.com/cyberpunk2077/mods/23157)); installed from `~/Downloads` if present. |

Launch flags (`--launcher-skip -skipStartScreen`) and the Proton DLL override
that loads CET and RED4ext are set by `scripts/set_launch_options.py`, which
merges into existing Steam launch options (e.g. `gamemoderun`) and refuses to
run while Steam is open.

## Commands

```bash
scripts/check.sh                  # offline compile gate (redscript under wine, headless)
./install.sh                      # check, then deploy frameworks + mods (+ Auto Drive Enhanced)
python3 scripts/set_launch_options.py   # Steam must be closed
scripts/check_logs.sh             # after a launch: framework/mod load errors + mod log lines
./uninstall.sh                    # remove everything in the manifest, restore vanilla scripts
```

State lives in `~/data/cyberpunk-mods/` (download cache, pristine script
bundle, wine prefix, install manifest). Framework versions and hashes are
pinned in `frameworks.lock`.

## In-game self-test

`scripts/ingame_selftest.sh` launches the game through Steam with a temporary
CET test mod (`tests/ingame/kuhy_selftest`), lets auto_continue load the newest
save, runs every mod's checks in the live game, then exits and prints
PASS/FAIL (and `check_logs.sh`). It loads the newest save and drives the live
display: back up saves first. Last full run (2026-09-30): every check passes
except the fast-travel right-click/Esc input steps, which are unverified: the
injected keys never reached the game (CET's first-run key-binding wizard
captures the keyboard, a fullscreen lock screen captured the mouse). The
fast-travel view itself was verified by screenshot. After a real try,
`check_logs.sh` shows `Kuhy.FastTravelMap` lines for every back event.

## Setup notes

- CET needs the VC++ 2022 runtime in the Proton prefix; `install.sh` runs
  `scripts/ensure_vcruntime.sh` (the game's own redist is 14.28, CET crashes
  with "Error: 998").
- CET shows a one-time "bind a key for the overlay" prompt on first launch;
  answer it in game. Pre-setting the key in bindings.json hung the game.

## Safety properties

- `scripts/check.sh` compiles twice: with the frameworks, and mods-only (what
  the game compiles when RED4ext fails to load). Both must pass, so a missing
  launch option cannot break every script mod at once.
- Nothing deployed overwrites a vanilla file; `uninstall.sh` deletes the
  manifest's files and restores the pristine script bundle.
