"""Tests for hermes_vcc.recall."""

import json
import pytest
from pathlib import Path

from hermes_vcc.recall import recall_search


def _write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        for r in records:
            fh.write(json.dumps(r) + "\n")


def test_recall_basic(tmp_path: Path) -> None:
    session_id = "test-session-1"
    archive_dir = tmp_path / "archives"
    cycle_file = archive_dir / session_id / "cycle_1.jsonl"
    _write_jsonl(
        cycle_file,
        [
            {"role": "user", "content": "Hello, what is the capital of France?"},
            {"role": "assistant", "content": "The capital of France is Paris."},
            {"role": "user", "content": "What about Germany?"},
        ],
    )

    results = recall_search("France", session_id, archive_dir)
    assert len(results) == 2
    assert all("France" in r["preview"] for r in results)
    assert results[0]["cycle"] == 1


def test_recall_no_match(tmp_path: Path) -> None:
    session_id = "test-session-2"
    archive_dir = tmp_path / "archives"
    cycle_file = archive_dir / session_id / "cycle_1.jsonl"
    _write_jsonl(cycle_file, [{"role": "user", "content": "Hello world"}])

    results = recall_search("xyz_no_match", session_id, archive_dir)
    assert results == []


def test_recall_missing_session(tmp_path: Path) -> None:
    results = recall_search("anything", "nonexistent", tmp_path)
    assert results == []


def test_recall_score_and_order(tmp_path: Path) -> None:
    session_id = "test-session-3"
    archive_dir = tmp_path / "archives"
    _write_jsonl(
        archive_dir / session_id / "cycle_1.jsonl",
        [{"role": "user", "content": "foo"}],
    )
    _write_jsonl(
        archive_dir / session_id / "cycle_2.jsonl",
        [{"role": "assistant", "content": "foo bar"}],
    )

    # Two-keyword search: "foo bar" — second record matches both
    results = recall_search("foo bar", session_id, archive_dir)
    assert results[0]["score"] == 1.0
    assert "foo bar" in results[0]["preview"]


def test_recall_list_content(tmp_path: Path) -> None:
    session_id = "test-session-4"
    archive_dir = tmp_path / "archives"
    _write_jsonl(
        archive_dir / session_id / "cycle_1.jsonl",
        [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Searching for needle in haystack"},
                    {"type": "image", "url": "http://example.com/img.png"},
                ],
            }
        ],
    )

    results = recall_search("needle", session_id, archive_dir)
    assert len(results) == 1
    assert "needle" in results[0]["preview"]
