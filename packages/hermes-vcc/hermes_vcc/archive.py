"""Pre-compression archive system for Hermes conversations.

Before each compression cycle, the full conversation is archived as JSONL and
compiled via VCC.  This gives a lossless record of every message that existed
before the compressor threw information away.

The archive MUST NEVER raise exceptions that propagate to the caller.  All
failures are logged as warnings and silently swallowed so the compression
pipeline is never broken by archival bookkeeping.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from hermes_vcc.utils import ensure_dir, estimate_tokens, import_vcc

logger = logging.getLogger(__name__)

_MANIFEST_NAME = "manifest.json"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _read_manifest(session_dir: Path) -> dict[str, Any]:
    """Load manifest.json from *session_dir*, returning empty dict on failure."""
    manifest_path = session_dir / _MANIFEST_NAME
    if not manifest_path.exists():
        return {}
    try:
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("Failed to read manifest at %s: %s", manifest_path, exc)
        return {}


def _write_manifest(session_dir: Path, manifest: dict[str, Any]) -> None:
    """Atomically-ish write *manifest* to manifest.json."""
    manifest_path = session_dir / _MANIFEST_NAME
    try:
        tmp = manifest_path.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        tmp.replace(manifest_path)
    except OSError as exc:
        logger.warning("Failed to write manifest at %s: %s", manifest_path, exc)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def archive_before_compression(
    messages: list[dict],
    session_id: str,
    archive_dir: Path,
    compression_cycle: int,
) -> Path:
    """Archive the current conversation state before compression.

    Steps:
        1. Convert *messages* to VCC JSONL records via the adapter.
        2. Write ``cycle_{compression_cycle}.jsonl`` into a per-session directory.
        3. Run VCC ``compile_pass`` to produce ``.txt`` / ``.min.txt`` views.
        4. Append cycle metadata to ``manifest.json``.

    Args:
        messages: Hermes OpenAI-format message list (the full conversation).
        session_id: Unique session identifier used as subdirectory name.
        archive_dir: Root directory for all session archives.
        compression_cycle: Monotonically increasing cycle counter.

    Returns:
        Path to the session subdirectory (always returned, even on partial
        failure, so the caller can reference it).
    """
    session_dir = ensure_dir(archive_dir / session_id)

    try:
        # --- 1. Convert to VCC records ---
        from hermes_vcc.adapter import convert_conversation, records_to_jsonl

        records = convert_conversation(messages)
        jsonl_text = records_to_jsonl(records)

        # --- 2. Write JSONL ---
        jsonl_path = session_dir / f"cycle_{compression_cycle}.jsonl"
        jsonl_path.write_text(jsonl_text, encoding="utf-8")

        # --- 3. Run VCC compile ---
        try:
            vcc = import_vcc()
            vcc.compile_pass(
                str(jsonl_path),
                str(session_dir),
                truncate=128,
                truncate_user=256,
                quiet=True,
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "VCC compile_pass failed for cycle %d of session %s: %s",
                compression_cycle,
                session_id,
                exc,
            )

        # --- 4. Update manifest ---
        token_est = estimate_tokens(jsonl_text)
        manifest = _read_manifest(session_dir)
        cycles: list[dict[str, Any]] = manifest.get("cycles", [])
        cycles.append({
            "id": compression_cycle,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "message_count": len(messages),
            "tokens_estimate": token_est,
        })
        manifest["cycles"] = cycles
        manifest["session_id"] = session_id
        manifest["last_updated"] = datetime.now(timezone.utc).isoformat()
        _write_manifest(session_dir, manifest)

        # --- 5. Register with qmd for hybrid recall ---
        try:
            from hermes_vcc import qmd

            if qmd.is_available():
                qmd.ensure_collection(session_dir, session_id)
        except Exception as exc:  # noqa: BLE001
            logger.debug("qmd collection registration skipped: %s", exc)

    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "archive_before_compression failed for session %s cycle %d: %s",
            session_id,
            compression_cycle,
            exc,
        )

    return session_dir


def prune_archives(session_dir: Path, retain: int = 10) -> None:
    """Remove oldest archive cycles beyond *retain* count.

    Deletes both the ``.jsonl`` source and VCC-produced ``.txt`` / ``.min.txt``
    files for pruned cycles, then updates ``manifest.json``.

    Args:
        session_dir: Per-session archive directory containing manifest.json.
        retain: Maximum number of cycles to keep (most recent wins).
    """
    try:
        manifest = _read_manifest(session_dir)
        cycles: list[dict[str, Any]] = manifest.get("cycles", [])

        if len(cycles) <= retain:
            return

        # Sort by id ascending so we can identify the oldest.
        cycles.sort(key=lambda c: c.get("id", 0))
        to_remove = cycles[: len(cycles) - retain]
        to_keep = cycles[len(cycles) - retain :]

        for cycle in to_remove:
            cycle_id = cycle.get("id", "unknown")
            prefix = f"cycle_{cycle_id}"
            # Remove all files matching cycle_<id>.* (jsonl, txt, min.txt)
            for path in session_dir.glob(f"{prefix}.*"):
                try:
                    path.unlink()
                    logger.debug("Pruned archive file %s", path)
                except OSError as exc:
                    logger.warning("Failed to delete %s: %s", path, exc)

        manifest["cycles"] = to_keep
        manifest["last_updated"] = datetime.now(timezone.utc).isoformat()
        _write_manifest(session_dir, manifest)

        logger.info(
            "Pruned %d archive cycles from %s, retained %d",
            len(to_remove),
            session_dir,
            len(to_keep),
        )

    except Exception as exc:  # noqa: BLE001
        logger.warning("prune_archives failed for %s: %s", session_dir, exc)


def get_archive_manifest(session_dir: Path) -> dict[str, Any]:
    """Read and return the archive manifest for a session.

    Args:
        session_dir: Per-session archive directory.

    Returns:
        Parsed manifest dict, or empty dict if the manifest does not exist
        or cannot be read.
    """
    return _read_manifest(session_dir)
