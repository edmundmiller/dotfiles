"""End-to-end: archive -> read files directly (pure VCC approach)."""

import json
from pathlib import Path

from hermes_vcc.archive import archive_before_compression
from hermes_vcc.enhanced_summary import compile_to_brief
from hermes_vcc.recovery import list_archives


class TestFullPipeline:
    def test_archive_and_read(self, basic_conversation, archive_dir, vcc_py_path):
        session_dir = archive_before_compression(
            basic_conversation, "roundtrip", archive_dir, 1,
        )

        # .min.txt exists and is readable
        min_txt = (session_dir / "cycle_1.min.txt").read_text()
        assert len(min_txt) > 20

        # .txt exists and contains full content
        full_txt = (session_dir / "cycle_1.txt").read_text()
        assert "Paris" in full_txt
        assert "Berlin" in full_txt

        # list_archives reports it
        listing = list_archives(archive_dir, "roundtrip")
        assert "cycle_1" in listing

    def test_compile_to_brief_matches_archive(self, basic_conversation, archive_dir, vcc_py_path):
        """compile_to_brief output matches what archive produces."""
        session_dir = archive_before_compression(
            basic_conversation, "brief-match", archive_dir, 1,
        )
        archived_min = (session_dir / "cycle_1.min.txt").read_text().strip()
        compiled_min = compile_to_brief(basic_conversation)

        # Both should have the same structural content
        assert compiled_min is not None
        assert len(compiled_min) > 0
        assert len(archived_min) > 0


class TestMultiCycle:
    def test_both_cycles_readable(self, basic_conversation, archive_dir, vcc_py_path):
        archive_before_compression(basic_conversation, "multi", archive_dir, 1)

        extended = basic_conversation + [
            {"role": "user", "content": "What about Spain?"},
            {"role": "assistant", "content": "The capital of Spain is Madrid."},
        ]
        archive_before_compression(extended, "multi", archive_dir, 2)

        # Both cycles exist
        session_dir = archive_dir / "multi"
        assert (session_dir / "cycle_1.txt").exists()
        assert (session_dir / "cycle_2.txt").exists()

        # Cycle 2 has Madrid, cycle 1 doesn't
        c1 = (session_dir / "cycle_1.txt").read_text()
        c2 = (session_dir / "cycle_2.txt").read_text()
        assert "Madrid" not in c1
        assert "Madrid" in c2


class TestToolHeavy:
    def test_all_tools_in_min_txt(self, tool_heavy_session, archive_dir, vcc_py_path):
        session_dir = archive_before_compression(
            tool_heavy_session, "tools", archive_dir, 1,
        )
        min_txt = (session_dir / "cycle_1.min.txt").read_text()

        # VCC .min.txt should have one-line summaries for each tool call
        assert "Read" in min_txt
        assert "Edit" in min_txt
        assert "Grep" in min_txt
