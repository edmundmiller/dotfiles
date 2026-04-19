"""Tests for hermes_vcc.qmd integration."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from hermes_vcc import qmd


def test_collection_name_basic() -> None:
    assert qmd.collection_name("abc-123") == "vcc-abc-123"


def test_collection_name_sanitizes() -> None:
    name = qmd.collection_name("path/with spaces/session")
    assert "/" not in name
    assert " " not in name
    assert name.startswith("vcc-")


def test_collection_name_truncates() -> None:
    long_id = "a" * 100
    name = qmd.collection_name(long_id)
    assert len(name) <= 64  # prefix + 60 chars


def test_is_available_when_missing() -> None:
    with patch("shutil.which", return_value=None):
        qmd._QMD_BIN = None  # reset cache
        assert not qmd.is_available()
        qmd._QMD_BIN = None  # reset for other tests


def test_is_available_when_found() -> None:
    with patch("shutil.which", return_value="/usr/bin/qmd"):
        qmd._QMD_BIN = None
        assert qmd.is_available()
        qmd._QMD_BIN = None


def test_search_returns_empty_when_unavailable() -> None:
    with patch.object(qmd, "is_available", return_value=False):
        results = qmd.search("test query", session_id="sess-1")
        assert results == []


def test_search_parses_json_output() -> None:
    mock_output = json.dumps([
        {
            "docid": "#abc123",
            "score": 0.92,
            "file": "qmd://vcc-sess-1/cycle_1.txt",
            "title": "cycle_1",
            "context": "VCC archive",
            "snippet": "The user asked about nginx configuration",
        },
        {
            "docid": "#def456",
            "score": 0.78,
            "file": "qmd://vcc-sess-1/cycle_2.min.txt",
            "title": "cycle_2",
            "context": "VCC archive",
            "snippet": "nginx reverse proxy setup",
        },
    ])

    with patch.object(qmd, "is_available", return_value=True), \
         patch.object(qmd, "list_vcc_collections", return_value=["vcc-sess-1"]), \
         patch.object(qmd, "_run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0, stdout=mock_output, stderr="")
        results = qmd.search("nginx", session_id="sess-1")

    assert len(results) == 2
    assert results[0]["score"] == 0.92
    assert results[0]["docid"] == "#abc123"
    assert "nginx" in results[1]["snippet"]


def test_search_handles_cli_failure() -> None:
    with patch.object(qmd, "is_available", return_value=True), \
         patch.object(qmd, "list_vcc_collections", return_value=["vcc-sess-1"]), \
         patch.object(qmd, "_run") as mock_run:
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="error")
        results = qmd.search("test", session_id="sess-1")

    assert results == []


def test_get_document_returns_content() -> None:
    with patch.object(qmd, "is_available", return_value=True), \
         patch.object(qmd, "_run") as mock_run:
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="1: [user]\n2: How do I configure nginx?\n",
        )
        content = qmd.get_document("#abc123")

    assert content is not None
    assert "nginx" in content


def test_get_document_returns_none_on_failure() -> None:
    with patch.object(qmd, "is_available", return_value=True), \
         patch.object(qmd, "_run") as mock_run:
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="not found")
        content = qmd.get_document("#nonexistent")

    assert content is None


def test_remove_collection() -> None:
    with patch.object(qmd, "is_available", return_value=True), \
         patch.object(qmd, "_run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0)
        assert qmd.remove_collection("sess-1")
        mock_run.assert_called_once_with(["collection", "remove", "vcc-sess-1"])
