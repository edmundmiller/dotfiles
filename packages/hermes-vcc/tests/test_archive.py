"""Tests for hermes_vcc.archive — pre-compression archival system."""

import json
from pathlib import Path

import pytest

from hermes_vcc.archive import (
    archive_before_compression,
    get_archive_manifest,
    prune_archives,
)


class TestArchiveCreatesFiles:
    """archive_before_compression produces .jsonl, .txt, .min.txt."""

    def test_archive_creates_files(self, basic_conversation, archive_dir, vcc_py_path):
        session_id = "test-session"
        session_dir = archive_before_compression(
            messages=basic_conversation,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=1,
        )

        assert (session_dir / "cycle_1.jsonl").exists()
        assert (session_dir / "cycle_1.txt").exists()
        assert (session_dir / "cycle_1.min.txt").exists()


class TestArchiveManifest:
    """manifest.json has correct structure."""

    def test_archive_manifest(self, basic_conversation, archive_dir, vcc_py_path):
        session_id = "manifest-test"
        session_dir = archive_before_compression(
            messages=basic_conversation,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=1,
        )

        manifest = get_archive_manifest(session_dir)
        assert manifest["session_id"] == session_id
        assert "last_updated" in manifest
        assert "cycles" in manifest
        assert isinstance(manifest["cycles"], list)
        assert len(manifest["cycles"]) == 1

        cycle = manifest["cycles"][0]
        assert cycle["id"] == 1
        assert "timestamp" in cycle
        assert cycle["message_count"] == len(basic_conversation)
        assert "tokens_estimate" in cycle
        assert isinstance(cycle["tokens_estimate"], int)


class TestArchiveContentComplete:
    """All messages appear in the .txt output."""

    def test_archive_content_complete(self, basic_conversation, archive_dir, vcc_py_path):
        session_dir = archive_before_compression(
            messages=basic_conversation,
            session_id="content-test",
            archive_dir=archive_dir,
            compression_cycle=1,
        )

        txt_content = (session_dir / "cycle_1.txt").read_text(encoding="utf-8")
        # Every message's content should appear in the full transcript
        for msg in basic_conversation:
            content = msg.get("content") or ""
            if content:
                # Check that at least some substring of each message appears
                # VCC may truncate, but short messages should appear fully
                assert content[:50] in txt_content, (
                    f"Message content not found in transcript: {content[:80]}"
                )


class TestArchiveMultipleCycles:
    """Archiving twice creates two cycles in manifest."""

    def test_archive_multiple_cycles(self, basic_conversation, archive_dir, vcc_py_path):
        session_id = "multi-cycle"
        archive_before_compression(
            messages=basic_conversation,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=1,
        )
        session_dir = archive_before_compression(
            messages=basic_conversation,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=2,
        )

        manifest = get_archive_manifest(session_dir)
        assert len(manifest["cycles"]) == 2
        assert manifest["cycles"][0]["id"] == 1
        assert manifest["cycles"][1]["id"] == 2

        # Both JSONL files should exist
        assert (session_dir / "cycle_1.jsonl").exists()
        assert (session_dir / "cycle_2.jsonl").exists()


class TestArchivePrune:
    """prune_archives removes oldest cycles beyond the retain limit."""

    def test_archive_prune(self, basic_conversation, archive_dir, vcc_py_path):
        session_id = "prune-test"
        session_dir = None

        # Create 12 cycles
        for i in range(1, 13):
            session_dir = archive_before_compression(
                messages=basic_conversation,
                session_id=session_id,
                archive_dir=archive_dir,
                compression_cycle=i,
            )

        manifest_before = get_archive_manifest(session_dir)
        assert len(manifest_before["cycles"]) == 12

        # Prune to 10
        prune_archives(session_dir, retain=10)

        manifest_after = get_archive_manifest(session_dir)
        assert len(manifest_after["cycles"]) == 10

        # Oldest 2 (cycle 1, 2) should be gone
        remaining_ids = [c["id"] for c in manifest_after["cycles"]]
        assert 1 not in remaining_ids
        assert 2 not in remaining_ids
        assert 3 in remaining_ids
        assert 12 in remaining_ids

        # Files for pruned cycles should be deleted
        assert not (session_dir / "cycle_1.jsonl").exists()
        assert not (session_dir / "cycle_2.jsonl").exists()
        # Files for kept cycles should still exist
        assert (session_dir / "cycle_3.jsonl").exists()
        assert (session_dir / "cycle_12.jsonl").exists()


class TestArchiveEmptyMessages:
    """Handles empty message list gracefully."""

    def test_archive_empty_messages(self, archive_dir, vcc_py_path):
        session_dir = archive_before_compression(
            messages=[],
            session_id="empty-test",
            archive_dir=archive_dir,
            compression_cycle=1,
        )

        # Should still return a valid session_dir
        assert session_dir.is_dir()
        # JSONL should exist (empty records)
        assert (session_dir / "cycle_1.jsonl").exists()


class TestArchiveReturnsSessionDir:
    """Always returns session_dir Path even on failure."""

    def test_archive_returns_session_dir(self, basic_conversation, archive_dir, vcc_py_path):
        session_dir = archive_before_compression(
            messages=basic_conversation,
            session_id="return-test",
            archive_dir=archive_dir,
            compression_cycle=1,
        )
        assert isinstance(session_dir, Path)
        assert session_dir.is_dir()
        assert session_dir.name == "return-test"


class TestGetArchiveManifest:
    """get_archive_manifest helper returns correct data."""

    def test_get_archive_manifest(self, basic_conversation, archive_dir, vcc_py_path):
        session_dir = archive_before_compression(
            messages=basic_conversation,
            session_id="get-manifest",
            archive_dir=archive_dir,
            compression_cycle=1,
        )

        manifest = get_archive_manifest(session_dir)
        assert isinstance(manifest, dict)
        assert manifest["session_id"] == "get-manifest"
        assert len(manifest["cycles"]) == 1

    def test_get_archive_manifest_missing(self, tmp_path):
        """Returns empty dict when manifest does not exist."""
        empty_dir = tmp_path / "nonexistent"
        empty_dir.mkdir()
        manifest = get_archive_manifest(empty_dir)
        assert manifest == {}
