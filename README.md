# cyberpunk-mods

Personal Cyberpunk 2077 (2.31, Steam + Proton) mods and the pinned framework
stack they run on.

| Mod | What it does |
|---|---|
| `auto_continue` | The first main menu of a game process loads the newest save ("Continue"). Returning to the menu later is left alone. |
| `no_auto_track` | Quest tracking only changes when you choose. Automatic switches (next quest after completion, new quest/gig/fixer, main-quest re-track) are reverted; a tracked quest advancing to its next objective stays tracked. |
| `fast_travel_map` | The fast-travel map behaves like the regular map: same filter, tracked-quest panel, no "select destination" box, right-click sets/removes a waypoint. Esc/B closes; hold to fast travel is unchanged. |
| `radio_in_combat` | With your car radio or pocket radio playing, combat neither fades it nor starts combat music. With no radio on, vanilla combat music. |
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

## Known gaps

- The CD PROJEKT / partner logo videos before the menu still play: they are
  chosen by native code, not scripts. `-skipStartScreen` removes the
  breaching screen.
