"""vcc_recall: search conversation history across compaction boundaries.

Uses qmd hybrid search (BM25 + vector + reranking) when available,
falling back to regex matching over raw JSONL archives.
"""

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
    """Search archived conversation history.

    Tries qmd hybrid search first for ranked, semantic results.
    Falls back to regex scanning of JSONL archives if qmd is unavailable.

    Returns a list of dicts with keys: cycle, line, role, preview, score.
    """
    from hermes_vcc import qmd

    if qmd.is_available():
        results = _recall_via_qmd(query, session_id, max_results)
        if results:
            return results

    return _recall_via_regex(query, session_id, archive_dir, max_results)


def recall_expand(
    file_ref: str,
) -> str | None:
    """Retrieve full content for a qmd docid or file reference.

    Returns the full document text, or None if qmd is unavailable.
    """
    from hermes_vcc import qmd

    if not qmd.is_available():
        return None
    return qmd.get_document(file_ref)


def _recall_via_qmd(
    query: str,
    session_id: str,
    max_results: int,
) -> list[dict]:
    """Search via qmd hybrid search, normalizing results to recall format."""
    from hermes_vcc import qmd

    raw = qmd.search(query, session_id=session_id, max_results=max_results)
    if not raw:
        return []

    results = []
    for r in raw:
        file_path = r.get("file", "")
        cycle = _cycle_from_path(file_path)
        results.append({
            "cycle": cycle,
            "line": 0,
            "role": "archive",
            "preview": r.get("snippet", "")[:200],
            "score": r.get("score", 0),
            "docid": r.get("docid", ""),
            "file": file_path,
        })
    return results


def _cycle_from_path(file_path: str) -> int:
    """Extract cycle number from a qmd file path like qmd://vcc-sess/cycle_3.txt."""
    m = re.search(r"cycle_(\d+)", file_path)
    return int(m.group(1)) if m else 0


def _recall_via_regex(
    query: str,
    session_id: str,
    archive_dir: Path,
    max_results: int,
) -> list[dict]:
    """Fallback: regex search over raw JSONL archives."""
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
