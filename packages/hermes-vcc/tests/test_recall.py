"""Tests for hermes_vcc.recall."""

import json
import pytest
from pathlib import Path
from unittest.mock import patch

from hermes_vcc.recall import recall_expand, recall_search, _cycle_from_path


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


# ---------------------------------------------------------------------------
# _cycle_from_path
# ---------------------------------------------------------------------------

class TestCycleFromPath:
    def test_extracts_cycle_number(self) -> None:
        assert _cycle_from_path("qmd://vcc-sess/cycle_3.txt") == 3

    def test_extracts_from_min_txt(self) -> None:
        assert _cycle_from_path("qmd://vcc-sess/cycle_12.min.txt") == 12

    def test_returns_zero_when_no_match(self) -> None:
        assert _cycle_from_path("qmd://vcc-sess/other.txt") == 0

    def test_returns_zero_for_empty(self) -> None:
        assert _cycle_from_path("") == 0


# ---------------------------------------------------------------------------
# qmd integration in recall_search
# ---------------------------------------------------------------------------

class TestRecallWithQmd:
    def test_uses_qmd_when_available(self, tmp_path: Path) -> None:
        from hermes_vcc import qmd

        mock_results = [
            {"file": "qmd://vcc-s/cycle_1.txt", "snippet": "found it",
             "score": 0.9, "docid": "#abc", "title": "c1", "context": ""},
        ]

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "search", return_value=mock_results):
            results = recall_search("query", "s", tmp_path / "archives")

        assert len(results) == 1
        assert results[0]["score"] == 0.9
        assert results[0]["docid"] == "#abc"
        assert results[0]["cycle"] == 1
        assert results[0]["role"] == "archive"

    def test_falls_back_to_regex_when_qmd_returns_empty(self, tmp_path: Path) -> None:
        from hermes_vcc import qmd

        session_id = "fallback-test"
        archive_dir = tmp_path / "archives"
        _write_jsonl(
            archive_dir / session_id / "cycle_1.jsonl",
            [{"role": "user", "content": "find this needle"}],
        )

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "search", return_value=[]):
            results = recall_search("needle", session_id, archive_dir)

        assert len(results) == 1
        assert "needle" in results[0]["preview"]

    def test_falls_back_to_regex_when_qmd_unavailable(self, tmp_path: Path) -> None:
        from hermes_vcc import qmd

        session_id = "no-qmd"
        archive_dir = tmp_path / "archives"
        _write_jsonl(
            archive_dir / session_id / "cycle_1.jsonl",
            [{"role": "assistant", "content": "the answer is 42"}],
        )

        with patch.object(qmd, "is_available", return_value=False):
            results = recall_search("42", session_id, archive_dir)

        assert len(results) == 1
        assert "42" in results[0]["preview"]

    def test_truncates_preview_to_200(self, tmp_path: Path) -> None:
        from hermes_vcc import qmd

        long_snippet = "x" * 300
        mock_results = [
            {"file": "qmd://vcc-s/cycle_1.txt", "snippet": long_snippet,
             "score": 0.5, "docid": "#a", "title": "", "context": ""},
        ]

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "search", return_value=mock_results):
            results = recall_search("query", "s", tmp_path / "archives")

        assert len(results[0]["preview"]) == 200


# ---------------------------------------------------------------------------
# recall_expand
# ---------------------------------------------------------------------------

class TestRecallExpand:
    def test_returns_content_from_qmd(self) -> None:
        from hermes_vcc import qmd

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "get_document", return_value="full document text"):
            content = recall_expand("#abc123")

        assert content == "full document text"

    def test_returns_none_when_unavailable(self) -> None:
        from hermes_vcc import qmd

        with patch.object(qmd, "is_available", return_value=False):
            assert recall_expand("#abc123") is None

    def test_returns_none_when_doc_not_found(self) -> None:
        from hermes_vcc import qmd

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "get_document", return_value=None):
            assert recall_expand("#nonexistent") is None
