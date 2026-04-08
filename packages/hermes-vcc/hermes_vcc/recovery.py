"""Thin helpers for listing and locating VCC archives.

The agent recovers details by reading archive files directly (.min.txt,
.txt) or running VCC.py --grep.  This module just helps find archives.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def list_archives(archive_dir: Path, session_id: str | None = None) -> str:
    """List available VCC archive cycles.

    Args:
        archive_dir: Root archive directory.
        session_id: Specific session, or None for the latest.

    Returns:
        Human-readable listing of archive cycles and file paths.
    """
    if not archive_dir.is_dir():
        return f"No archive directory at {archive_dir}"

    # Resolve session dir
    if session_id:
        session_dir = archive_dir / session_id
    else:
        subdirs = [p for p in archive_dir.iterdir() if p.is_dir()]
        if not subdirs:
            return "No sessions archived yet."
        session_dir = max(subdirs, key=lambda p: p.stat().st_mtime)

    if not session_dir.is_dir():
        return f"Session {session_id} not found."

    # Read manifest
    manifest_path = session_dir / "manifest.json"
    lines = [f"Archives in {session_dir.name}:"]

    if manifest_path.exists():
        try:
            data = json.loads(manifest_path.read_text(encoding="utf-8"))
            for c in data.get("cycles", []):
                cid = c.get("id", "?")
                ts = c.get("timestamp", "?")
                msgs = c.get("message_count", "?")
                lines.append(f"  cycle_{cid}: {msgs} messages @ {ts}")
                min_path = session_dir / f"cycle_{cid}.min.txt"
                txt_path = session_dir / f"cycle_{cid}.txt"
                if min_path.exists():
                    lines.append(f"    brief: {min_path}")
                if txt_path.exists():
                    lines.append(f"    full:  {txt_path}")
            return "\n".join(lines)
        except Exception:
            pass

    # Fallback: scan files
    import re
    for p in sorted(session_dir.glob("cycle_*.min.txt")):
        m = re.match(r"cycle_(\d+)", p.stem)
        if m:
            lines.append(f"  cycle_{m.group(1)}: {p}")
    return "\n".join(lines) if len(lines) > 1 else "No archive cycles found."
