#!/usr/bin/env python3
"""Build agent-icons.otf from SVGs mapped to PUA codepoints."""

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib import SVGPath

UNITS_PER_EM = 1000
ASCENT = 800
DESCENT = 200

# PUA codepoint assignments
CODEPOINTS = {
    "claude": 0xF5000,
    "amp": 0xF5001,
    "opencode": 0xF5002,
    "anthropic": 0xF5003,
}

PS_NAME = "AgentIcons"
FAMILY_NAME = "Agent Icons"


def svg_to_recording(svg_file: Path):
    """Import SVG and return a RecordingPen scaled to the em square."""
    tree = ET.parse(svg_file)
    root = tree.getroot()

    vb = root.get("viewBox", "").split()
    if len(vb) == 4:
        vb_x, vb_y, vb_w, vb_h = map(float, vb)
    else:
        vb_w = float(root.get("width", "24"))
        vb_h = float(root.get("height", "24"))
        vb_x, vb_y = 0, 0

    # Scale to fit em square with 5% padding
    padding = UNITS_PER_EM * 0.05
    avail = UNITS_PER_EM - 2 * padding
    scale = min(avail / vb_w, avail / vb_h)

    # Center in em square, flip Y (SVG Y-down → font Y-up)
    scaled_w = vb_w * scale
    scaled_h = vb_h * scale
    x_off = (UNITS_PER_EM - scaled_w) / 2 - vb_x * scale
    y_off = ASCENT - (UNITS_PER_EM - scaled_h) / 2 + vb_y * scale

    rec = RecordingPen()
    svg_path = SVGPath(svg_file)
    svg_path.draw(TransformPen(rec, (scale, 0, 0, -scale, x_off, y_off)))
    return rec


def main():
    svg_dir = Path(__file__).parent / "svgs"
    out_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("agent-icons.otf")

    glyph_names = [".notdef"]
    glyph_map = {}
    recordings = {}

    for name, codepoint in CODEPOINTS.items():
        svg_file = svg_dir / f"{name}.svg"
        if not svg_file.exists():
            print(f"warning: {svg_file} not found, skipping", file=sys.stderr)
            continue
        glyph_name = f"agent_{name}"
        glyph_names.append(glyph_name)
        glyph_map[codepoint] = glyph_name
        recordings[glyph_name] = svg_to_recording(svg_file)

    # Build CFF charstrings from recordings
    charstrings = {}
    for glyph_name, rec in recordings.items():
        pen = T2CharStringPen(UNITS_PER_EM, None)
        rec.replay(pen)
        charstrings[glyph_name] = pen.getCharString()

    # .notdef gets an empty charstring
    pen = T2CharStringPen(UNITS_PER_EM, None)
    pen.endPath()
    charstrings[".notdef"] = pen.getCharString()

    fb = FontBuilder(UNITS_PER_EM, isTTF=False)
    fb.setupGlyphOrder(glyph_names)
    fb.setupCharacterMap(glyph_map)

    # setupCFF signature: (psName, fontInfo, charStringsDict, privateDict)
    fb.setupCFF(
        PS_NAME,
        {"FullName": FAMILY_NAME},
        charstrings,
        {},
    )

    metrics = {name: (UNITS_PER_EM, 0) for name in glyph_names}
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT)
    fb.setupNameTable({
        "familyName": FAMILY_NAME,
        "styleName": "Regular",
    })
    fb.setupOS2(
        sTypoAscender=ASCENT,
        sTypoDescender=-DESCENT,
        sTypoLineGap=0,
    )
    fb.setupPost()

    fb.font.save(str(out_file))
    print(f"Built {out_file} with {len(glyph_map)} glyphs")

    # Write codepoints map for consumers
    cp_file = out_file.with_suffix(".json")
    cp_file.write_text(
        json.dumps(
            {name: f"U+{cp:05X}" for name, cp in CODEPOINTS.items()},
            indent=2,
        )
        + "\n"
    )
    print(f"Wrote {cp_file}")


if __name__ == "__main__":
    main()
