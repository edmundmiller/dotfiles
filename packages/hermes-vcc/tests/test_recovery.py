"""Tests for hermes_vcc.recovery — archive listing helpers."""

from hermes_vcc.archive import archive_before_compression
from hermes_vcc.recovery import list_archives


class TestListArchives:
    def test_no_dir(self, tmp_path):
        result = list_archives(tmp_path / "nonexistent")
        assert "No archive directory" in result

    def test_empty_dir(self, tmp_path):
        d = tmp_path / "archives"
        d.mkdir()
        result = list_archives(d)
        assert "No sessions" in result

    def test_with_archives(self, basic_conversation, archive_dir, vcc_py_path):
        archive_before_compression(basic_conversation, "sess1", archive_dir, 1)
        archive_before_compression(basic_conversation, "sess1", archive_dir, 2)
        result = list_archives(archive_dir, "sess1")
        assert "cycle_1" in result
        assert "cycle_2" in result

    def test_latest_session(self, basic_conversation, archive_dir, vcc_py_path):
        archive_before_compression(basic_conversation, "sess1", archive_dir, 1)
        result = list_archives(archive_dir)  # no session_id — picks latest
        assert "cycle_1" in result
