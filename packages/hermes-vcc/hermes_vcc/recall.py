"""vcc_recall: search conversation history across compaction boundaries."""

from __future__ import annotations

import json
import re
from pathlib import Path


def recall_search(
    query: str,
    session_id: str,
    archive_dir: Path,
    max_results: int = 20,
) -> list[dict]:
    """Search archived JSONL files for query matches.

    Returns a list of dicts with keys: cycle, line, role, preview, score.
    """
    session_path = archive_dir / session_id
    try:
        files = sorted(f for f in session_path.iterdir() if f.name.endswith(".jsonl"))
    except (FileNotFoundError, NotADirectoryError):
        return []

    words = query.strip().split()
    try:
        patterns = [re.compile(query, re.IGNORECASE)]
    except re.error:
        patterns = [
            re.compile(re.escape(w), re.IGNORECASE) for w in words
        ]

    matches: list[dict] = []
    for file in files:
        m = re.match(r"cycle_(\d+)\.jsonl", file.name)
        cycle = int(m.group(1)) if m else 0
        lines = file.read_text(encoding="utf-8").splitlines()
        for line_idx, raw_line in enumerate(lines):
            if not raw_line.strip():
                continue
            try:
                record = json.loads(raw_line)
            except json.JSONDecodeError:
                continue
            role = record.get("type") or record.get("role") or "unknown"
            text = _extract_text(record)
            if not text:
                continue
            match_count = sum(1 for p in patterns if p.search(text))
            if match_count == 0:
                continue
            matches.append(
                {
                    "cycle": cycle,
                    "line": line_idx + 1,
                    "role": role,
                    "preview": text[:200],
                    "score": match_count / len(patterns),
                }
            )

    matches.sort(key=lambda x: (-x["score"], -x["cycle"]))
    return matches[:max_results]


def _extract_text(record: dict) -> str:
    content = record.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(
            c.get("text", "") for c in content if c.get("type") == "text"
        )
    # nested message wrapper
    msg = record.get("message")
    if isinstance(msg, dict):
        return _extract_text(msg)
    return ""
