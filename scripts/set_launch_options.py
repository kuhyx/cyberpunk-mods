#!/usr/bin/env python3
"""Set Cyberpunk 2077's Steam launch options in every localconfig.vdf.

Steam rewrites localconfig.vdf from memory on exit, so this refuses to run
while Steam is up. The original file is backed up next to itself first.

Launch options:
  WINEDLLOVERRIDES  lets Proton load CET (version.dll) and RED4ext (winmm.dll)
  --launcher-skip   bypasses REDlauncher
  -skipStartScreen  bypasses the "press any key" breaching screen
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path

import vdf

APP_ID = "1091500"
DLL_OVERRIDE = 'WINEDLLOVERRIDES="winmm,version=n,b"'
GAME_FLAGS = ("--launcher-skip", "-skipStartScreen")
STEAM_USERDATA = Path.home() / ".local/share/Steam/userdata"


def merge_options(current: str) -> str:
    """Add the DLL override and game flags, keeping whatever is already there.

    ``gamemoderun %command% --launcher-skip`` becomes
    ``WINEDLLOVERRIDES="winmm,version=n,b" gamemoderun %command% --launcher-skip -skipStartScreen``.
    """
    before, sep, after = current.partition("%command%")
    if not sep:
        # Without %command% Steam appends the whole string as game arguments.
        before, after = "", current
    if "WINEDLLOVERRIDES" not in before:
        before = f"{DLL_OVERRIDE} {before}"
    flags = after.split()
    flags += [flag for flag in GAME_FLAGS if flag not in flags]
    return " ".join([*before.split(), "%command%", *flags])


def steam_running() -> bool:
    """Return True while any process named exactly ``steam`` exists."""
    return (
        subprocess.run(
            ["pgrep", "-x", "steam"], capture_output=True, check=False
        ).returncode
        == 0
    )


def app_section(config: dict, app_id: str) -> dict:
    """Return (creating if needed) the per-app dict under Software/Valve/Steam/apps."""
    store = config.setdefault("UserLocalConfigStore", {})
    node = (
        store.setdefault("Software", {}).setdefault("Valve", {}).setdefault("Steam", {})
    )
    apps = node.setdefault("apps", {})
    return apps.setdefault(app_id, {})


APP_PATH = ("userlocalconfigstore", "software", "valve", "steam", "apps", APP_ID)


def vdf_escape(value: str) -> str:
    """Escape a string for a quoted VDF value."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def set_app_option(text: str, key: str, value: str) -> str:
    """Set ``key`` inside the apps/<APP_ID> block, touching only that line.

    Steam's own formatting (tab runs, key order, duplicate keys) is kept
    byte-for-byte: a vdf load/dump round trip rewrites ~14k lines.
    """
    lines = text.splitlines(keepends=True)
    stack: list[str] = []
    pending = ""
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "{":
            stack.append(pending.lower())
            continue
        if stripped == "}":
            if tuple(stack) == APP_PATH:
                indent = line[: len(line) - len(line.lstrip())] + "\t"
                lines.insert(i, f'{indent}"{key}"\t\t"{vdf_escape(value)}"\n')
                return "".join(lines)
            stack.pop()
            continue
        tokens = stripped.split('"')
        if len(tokens) >= 2:
            pending = tokens[1]
        if tuple(stack) == APP_PATH and pending == key and len(tokens) >= 4:
            prefix = line[: line.index('"', line.index(f'"{key}"') + len(key) + 2)]
            lines[i] = f'{prefix}"{vdf_escape(value)}"\n'
            return "".join(lines)
    msg = f"apps/{APP_ID} block not found"
    raise ValueError(msg)


def patch_file(path: Path) -> bool:
    """Merge the launch options into one localconfig.vdf; return True if changed."""
    text = path.read_text(encoding="utf-8", errors="surrogateescape")
    current = app_section(vdf.loads(text), APP_ID).get("LaunchOptions", "")
    options = merge_options(current)
    if current == options:
        return False
    patched = set_app_option(text, "LaunchOptions", options)
    if app_section(vdf.loads(patched), APP_ID).get("LaunchOptions") != options:
        msg = f"{path}: patched file does not read back the new launch options"
        raise ValueError(msg)
    backup = path.with_name(f"{path.name}.bak-{time.strftime('%Y%m%d-%H%M%S')}")
    shutil.copy2(path, backup)
    path.write_text(patched, encoding="utf-8", errors="surrogateescape")
    return True


def main() -> int:
    """Patch every Steam user's localconfig.vdf; exit 2 if Steam is running."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check", action="store_true", help="only report current value"
    )
    args = parser.parse_args()

    configs = sorted(
        p
        for p in STEAM_USERDATA.glob("*/config/localconfig.vdf")
        if p.parts[-3].isdigit()
    )
    if not configs:
        print(f"Error: no localconfig.vdf under {STEAM_USERDATA}", file=sys.stderr)
        return 1
    for path in configs:
        config = vdf.loads(path.read_text(encoding="utf-8", errors="surrogateescape"))
        current = app_section(config, APP_ID).get("LaunchOptions", "")
        print(f"{path}: LaunchOptions={current!r} -> {merge_options(current)!r}")
    if args.check:
        return 0
    if steam_running():
        print(
            "Error: Steam is running; quit Steam first (it rewrites localconfig.vdf on exit)",
            file=sys.stderr,
        )
        return 2
    for path in configs:
        changed = patch_file(path)
        print(f"{'set' if changed else 'already set'}: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
