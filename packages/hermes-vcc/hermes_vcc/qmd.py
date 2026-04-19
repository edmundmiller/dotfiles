"""qmd integration for hermes-vcc recall.

Wraps the qmd CLI to manage VCC archive collections and run hybrid search
(BM25 + vector + reranking) over archived conversation transcripts.

qmd is optional — all functions degrade gracefully if the binary is absent.
"""

from __future__ import annotations

import json
import logging
import shutil
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)

_COLLECTION_PREFIX = "vcc-"
_QMD_BIN: str | None = None


def _qmd_bin() -> str | None:
    """Find qmd binary, caching the result."""
    global _QMD_BIN  # noqa: PLW0603
    if _QMD_BIN is None:
        _QMD_BIN = shutil.which("qmd") or ""
    return _QMD_BIN or None


def is_available() -> bool:
    """Return True if qmd is installed and reachable."""
    return _qmd_bin() is not None


def _run(args: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
    """Run a qmd CLI command, returning the completed process."""
    binary = _qmd_bin()
    if binary is None:
        raise RuntimeError("qmd binary not found")
    return subprocess.run(
        [binary, *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def collection_name(session_id: str) -> str:
    """Derive a qmd collection name from a session ID."""
    safe = session_id.replace("/", "-").replace(" ", "-")[:60]
    return f"{_COLLECTION_PREFIX}{safe}"


def ensure_collection(session_dir: Path, session_id: str) -> bool:
    """Register or update a qmd collection for a VCC session archive.

    Points qmd at the session directory with a ``**/*.txt`` glob so it
    indexes both ``.txt`` (full views) and ``.min.txt`` (brief views).

    Returns True if the collection was successfully created/updated.
    """
    if not is_available():
        return False

    name = collection_name(session_id)
    abs_dir = str(session_dir.resolve())

    try:
        # Check if collection already exists
        result = _run(["collection", "show", name])
        if result.returncode == 0:
            # Already exists — just update index
            _run(["update"], timeout=60)
            return True
    except Exception:
        pass

    try:
        # Create new collection via CLI — qmd add takes: name path [pattern]
        result = _run(["collection", "add", name, abs_dir])
        if result.returncode != 0:
            logger.warning("qmd collection add failed: %s", result.stderr)
            return False

        # The CLI defaults to **/*.md — we need to fix the pattern via config.
        # For now, update the config file directly.
        _patch_collection_pattern(name, abs_dir)

        # Re-index with the correct pattern
        _run(["update"], timeout=60)
        return True

    except Exception as exc:
        logger.warning("qmd ensure_collection failed: %s", exc)
        return False


def _patch_collection_pattern(name: str, path: str) -> None:
    """Patch the qmd index.yml to set pattern to **/*.txt for a collection."""
    try:
        import yaml
    except ImportError:
        logger.debug("pyyaml not available, skipping qmd config patch")
        return

    config_path = Path.home() / ".config" / "qmd" / "index.yml"
    if not config_path.exists():
        return

    try:
        data = yaml.safe_load(config_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return

        collections = data.setdefault("collections", {})
        collections[name] = {
            "path": path,
            "pattern": "**/*.txt",
            "context": {
                "": "VCC conversation archive — lossless agent session transcripts and brief views",
            },
            "includeByDefault": False,
        }

        config_path.write_text(
            yaml.dump(data, default_flow_style=False, sort_keys=False),
            encoding="utf-8",
        )
    except Exception as exc:
        logger.warning("Failed to patch qmd config: %s", exc)


def remove_collection(session_id: str) -> bool:
    """Remove a qmd collection for a pruned session."""
    if not is_available():
        return False

    name = collection_name(session_id)
    try:
        result = _run(["collection", "remove", name])
        return result.returncode == 0
    except Exception as exc:
        logger.warning("qmd remove_collection failed: %s", exc)
        return False


def search(
    query: str,
    session_id: str | None = None,
    max_results: int = 20,
    use_hybrid: bool = True,
) -> list[dict]:
    """Search VCC archives via qmd.

    Args:
        query: Search query (natural language or keywords).
        session_id: Limit to a specific session's collection.
            If None, searches all VCC collections.
        max_results: Maximum number of results.
        use_hybrid: Use ``qmd query`` (hybrid) vs ``qmd search`` (BM25 only).

    Returns:
        List of result dicts with keys: file, title, score, snippet, docid.
    """
    if not is_available():
        return []

    cmd = "query" if use_hybrid else "search"
    args = [cmd, query, "--json", "-n", str(max_results)]

    if session_id:
        args.extend(["-c", collection_name(session_id)])
    else:
        # Search all VCC collections — collect their names
        vcc_collections = list_vcc_collections()
        if not vcc_collections:
            return []
        for name in vcc_collections:
            args.extend(["-c", name])

    if not use_hybrid:
        args.append("--no-rerank")

    try:
        result = _run(args, timeout=60)
        if result.returncode != 0:
            logger.warning("qmd %s failed: %s", cmd, result.stderr)
            return []

        raw = json.loads(result.stdout)
        if not isinstance(raw, list):
            return []

        return [
            {
                "file": r.get("file", ""),
                "title": r.get("title", ""),
                "score": r.get("score", 0),
                "snippet": r.get("snippet", ""),
                "docid": r.get("docid", ""),
                "context": r.get("context", ""),
            }
            for r in raw[:max_results]
        ]

    except json.JSONDecodeError:
        logger.warning("qmd returned invalid JSON")
        return []
    except Exception as exc:
        logger.warning("qmd search failed: %s", exc)
        return []


def list_vcc_collections() -> list[str]:
    """Return names of all VCC-managed qmd collections."""
    if not is_available():
        return []

    try:
        import yaml
    except ImportError:
        return []

    config_path = Path.home() / ".config" / "qmd" / "index.yml"
    if not config_path.exists():
        return []

    try:
        data = yaml.safe_load(config_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return []
        collections = data.get("collections", {})
        return [
            name for name in collections
            if name.startswith(_COLLECTION_PREFIX)
        ]
    except Exception:
        return []


def get_document(file_ref: str) -> str | None:
    """Retrieve full document content by qmd file reference or docid.

    Args:
        file_ref: A ``qmd://collection/path`` URI or ``#docid`` reference.

    Returns:
        Document text, or None on failure.
    """
    if not is_available():
        return None

    try:
        result = _run(["get", file_ref, "--line-numbers"])
        if result.returncode != 0:
            return None
        return result.stdout
    except Exception as exc:
        logger.warning("qmd get failed: %s", exc)
        return None
