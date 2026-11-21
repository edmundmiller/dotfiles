#!/usr/bin/env python3
"""Read the approved NUC analog headset metadata and controls, never PCM audio."""

import json
from pathlib import Path
import re
import socket
import subprocess
import sys


def inspect_headset(root=Path("/"), amixer="amixer"):
    pci = root / "sys/devices/pci0000:00/0000:00:1f.3"
    if ((pci / "vendor").read_text().strip() != "0x8086"
            or (pci / "device").read_text().strip() != "0x02c8"
            or (pci / "driver").resolve(strict=True).name != "snd_hda_intel"):
        raise ValueError("Unexpected analog audio controller")
    cards = [card for card in (root / "sys/class/sound").glob("card[0-9]*")
        if card.resolve(strict=True).parent == pci / "sound"]
    if len(cards) != 1:
        raise ValueError("Expected exactly one card on the approved controller")
    card = cards[0].name.removeprefix("card")
    proc = root / f"proc/asound/card{card}"
    if (proc / "codec#0").read_text().splitlines()[0] != "Codec: Realtek ALC256":
        raise ValueError("Unexpected analog codec")
    endpoints = {}
    for direction in ("c", "p"):
        pcm = root / f"sys/class/sound/pcmC{card}D0{direction}"
        if pcm.resolve(strict=True).parent != pci / "sound" / f"card{card}":
            raise ValueError("Analog endpoint is outside the approved controller")
        endpoints[direction] = {"name": pcm.name, "dev": (pcm / "dev").read_text().strip(),
            "status": (proc / f"pcm0{direction}/sub0/status").read_text().strip()}

    def read_controls(*arguments):
        return subprocess.run([amixer, "--card", card, *arguments],
            capture_output=True, text=True, check=True, timeout=5).stdout.strip()

    controls = {}
    for line in read_controls("controls").splitlines():
        match = re.fullmatch(
            r"numid=(\d+),iface=(?:MIXER|CARD),name='([^']+)'(?:,index=(\d+))?", line)
        if match and re.match(
                r"^(?:Master|PCM|Headphone|Headset Mic|Internal Mic|Capture|Input Source|Auto-Mute Mode)(?: |$)",
                match[2]):
            controls[match[1]] = {"name": match[2], "index": int(match[3] or 0),
                "readback": read_controls("cget", f"numid={match[1]}")}
    return {"controller": "0000:00:1f.3", "codec": "Realtek ALC256",
        "card_index": int(card), "endpoints": endpoints, "controls": controls,
        "control_reads_only": True, "pcm_opened": False, "settings_changed": False,
        "acoustic_signal_verified": False}


if __name__ == "__main__":
    try:
        if socket.gethostname() != "nuc":
            raise ValueError("Run only on the NUC host")
        print(json.dumps(inspect_headset(), sort_keys=True))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Headset inspection failed: {error}", file=sys.stderr)
        sys.exit(1)
