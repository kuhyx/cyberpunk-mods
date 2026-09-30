#!/usr/bin/env python3
"""Cut a Bink 2 (KB2*) video down to its first frame.

Used to neutralise the startup logo videos: the game still "plays" them, but
each lasts one frame. Layout (little endian), as read by FFmpeg's bink demuxer:

    0   signature   b"KB2?"
    4   file size - 8
    8   frame count
    12  largest frame size
    16  frame count (again)
    20  width, 24 height, 28 fps num, 32 fps den, 36 flags
    40  audio track count
    44  4 extra bytes for revision >= "i"
        per-audio-track headers (12 bytes each)
        frame index: frame count + 1 uint32 offsets (bit 0 = keyframe)
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

HEADER = struct.Struct("<4s10I")


def index_offset(data: bytes) -> int:
    """Byte offset of the frame index table."""
    signature = data[:4]
    audio_tracks = HEADER.unpack_from(data)[10]
    offset = HEADER.size + (4 if signature[3:4] >= b"i" else 0)
    return offset + 12 * audio_tracks


def first_frame_only(data: bytes) -> bytes:
    """Return a valid Bink 2 file holding only the first frame of ``data``."""
    fields = list(HEADER.unpack_from(data))
    signature, frames, audio_tracks = fields[0], fields[2], fields[10]
    if not signature.startswith(b"KB2"):
        msg = f"not a Bink 2 file (signature {signature!r})"
        raise ValueError(msg)
    if audio_tracks:
        msg = "videos with embedded audio are not supported"
        raise ValueError(msg)
    table = index_offset(data)
    offsets = struct.unpack_from(f"<{frames + 1}I", data, table)
    start, end = offsets[0] & ~1, offsets[1] & ~1
    frame = data[start:end]

    prefix = bytearray(data[:table])
    new_start = table + 8  # two index entries follow the prefix
    fields[1] = new_start + len(frame) - 8
    fields[2] = fields[4] = 1
    fields[3] = len(frame)
    HEADER.pack_into(prefix, 0, *fields)
    index = struct.pack("<2I", new_start | 1, new_start + len(frame))
    return bytes(prefix) + index + frame


def main() -> int:
    """Truncate each input file to one frame, writing to the output dir."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--out", type=Path, required=True, help="output directory")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for path in args.inputs:
        result = first_frame_only(path.read_bytes())
        (args.out / path.name).write_bytes(result)
        print(f"{path.name}: {path.stat().st_size} -> {len(result)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
