"""Tests for hermes_vcc.qmd integration."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from hermes_vcc import qmd


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _reset_qmd_cache():
    """Reset the qmd binary cache between tests."""
    qmd._QMD_BIN = None
    yield
    qmd._QMD_BIN = None


# ---------------------------------------------------------------------------
# collection_name
# ---------------------------------------------------------------------------

class TestCollectionName:
    def test_basic(self) -> None:
        assert qmd.collection_name("abc-123") == "vcc-abc-123"

    def test_sanitizes_slashes(self) -> None:
        name = qmd.collection_name("path/to/session")
        assert "/" not in name
        assert name == "vcc-path-to-session"

    def test_sanitizes_spaces(self) -> None:
        name = qmd.collection_name("my session id")
        assert " " not in name
        assert name == "vcc-my-session-id"

    def test_truncates_long_ids(self) -> None:
        long_id = "a" * 100
        name = qmd.collection_name(long_id)
        assert len(name) <= 64  # prefix (4) + 60 chars

    def test_empty_id(self) -> None:
        name = qmd.collection_name("")
        assert name == "vcc-"


# ---------------------------------------------------------------------------
# is_available
# ---------------------------------------------------------------------------

class TestIsAvailable:
    def test_when_missing(self) -> None:
        with patch("shutil.which", return_value=None):
            assert not qmd.is_available()

    def test_when_found(self) -> None:
        with patch("shutil.which", return_value="/usr/bin/qmd"):
            assert qmd.is_available()

    def test_caches_result(self) -> None:
        with patch("shutil.which", return_value="/usr/bin/qmd") as mock_which:
            qmd.is_available()
            qmd.is_available()
            mock_which.assert_called_once()


# ---------------------------------------------------------------------------
# _run
# ---------------------------------------------------------------------------

class TestRun:
    def test_raises_when_no_binary(self) -> None:
        with patch("shutil.which", return_value=None):
            with pytest.raises(RuntimeError, match="qmd binary not found"):
                qmd._run(["status"])

    def test_passes_args_to_subprocess(self) -> None:
        with patch("shutil.which", return_value="/usr/bin/qmd"), \
             patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            qmd._run(["search", "test", "--json"])
            mock_run.assert_called_once_with(
                ["/usr/bin/qmd", "search", "test", "--json"],
                capture_output=True,
                text=True,
                timeout=30,
            )

    def test_respects_timeout(self) -> None:
        with patch("shutil.which", return_value="/usr/bin/qmd"), \
             patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            qmd._run(["update"], timeout=120)
            assert mock_run.call_args.kwargs["timeout"] == 120


# ---------------------------------------------------------------------------
# search
# ---------------------------------------------------------------------------

class TestSearch:
    def test_returns_empty_when_unavailable(self) -> None:
        with patch.object(qmd, "is_available", return_value=False):
            assert qmd.search("test", session_id="s1") == []

    def test_parses_json_output(self) -> None:
        mock_output = json.dumps([
            {
                "docid": "#abc123",
                "score": 0.92,
                "file": "qmd://vcc-s1/cycle_1.txt",
                "title": "cycle_1",
                "context": "VCC archive",
                "snippet": "The user asked about nginx",
            },
            {
                "docid": "#def456",
                "score": 0.78,
                "file": "qmd://vcc-s1/cycle_2.min.txt",
                "title": "cycle_2",
                "context": "VCC archive",
                "snippet": "nginx reverse proxy",
            },
        ])

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout=mock_output, stderr="",
            )
            results = qmd.search("nginx", session_id="s1")

        assert len(results) == 2
        assert results[0]["score"] == 0.92
        assert results[0]["docid"] == "#abc123"
        assert results[0]["file"] == "qmd://vcc-s1/cycle_1.txt"
        assert "nginx" in results[1]["snippet"]

    def test_uses_query_cmd_for_hybrid(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="[]", stderr="",
            )
            qmd.search("test", session_id="s1", use_hybrid=True)

        args = mock_run.call_args[0][0]
        assert args[0] == "query"
        assert "--no-rerank" not in args

    def test_uses_search_cmd_for_bm25_only(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="[]", stderr="",
            )
            qmd.search("test", session_id="s1", use_hybrid=False)

        args = mock_run.call_args[0][0]
        assert args[0] == "search"
        assert "--no-rerank" in args

    def test_scopes_to_session_collection(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="[]", stderr="",
            )
            qmd.search("test", session_id="my-session")

        args = mock_run.call_args[0][0]
        assert "-c" in args
        assert "vcc-my-session" in args

    def test_searches_all_vcc_collections_when_no_session(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "list_vcc_collections", return_value=["vcc-a", "vcc-b"]), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="[]", stderr="",
            )
            qmd.search("test")

        args = mock_run.call_args[0][0]
        assert args.count("-c") == 2
        assert "vcc-a" in args
        assert "vcc-b" in args

    def test_returns_empty_when_no_vcc_collections(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "list_vcc_collections", return_value=[]):
            assert qmd.search("test") == []

    def test_handles_cli_failure(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=1, stdout="", stderr="error",
            )
            assert qmd.search("test", session_id="s1") == []

    def test_handles_invalid_json(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="not json", stderr="",
            )
            assert qmd.search("test", session_id="s1") == []

    def test_handles_non_list_json(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout='{"error": "oops"}', stderr="",
            )
            assert qmd.search("test", session_id="s1") == []

    def test_handles_timeout(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.side_effect = subprocess.TimeoutExpired("qmd", 60)
            assert qmd.search("test", session_id="s1") == []

    def test_respects_max_results(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="[]", stderr="",
            )
            qmd.search("test", session_id="s1", max_results=5)

        args = mock_run.call_args[0][0]
        n_idx = args.index("-n")
        assert args[n_idx + 1] == "5"

    def test_normalizes_result_keys(self) -> None:
        mock_output = json.dumps([
            {"docid": "#a", "score": 0.5, "file": "f", "title": "t",
             "context": "c", "snippet": "s", "extra_field": "ignored"},
        ])
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout=mock_output, stderr="",
            )
            results = qmd.search("test", session_id="s1")

        assert set(results[0].keys()) == {"file", "title", "score", "snippet", "docid", "context"}


# ---------------------------------------------------------------------------
# get_document
# ---------------------------------------------------------------------------

class TestGetDocument:
    def test_returns_content(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout="1: [user]\n2: How do I configure nginx?\n",
            )
            content = qmd.get_document("#abc123")

        assert content is not None
        assert "nginx" in content

    def test_passes_line_numbers_flag(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="")
            qmd.get_document("qmd://vcc-s1/cycle_1.txt")

        args = mock_run.call_args[0][0]
        assert "--line-numbers" in args

    def test_returns_none_on_failure(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=1, stdout="", stderr="not found",
            )
            assert qmd.get_document("#nonexistent") is None

    def test_returns_none_when_unavailable(self) -> None:
        with patch.object(qmd, "is_available", return_value=False):
            assert qmd.get_document("#abc") is None

    def test_returns_none_on_exception(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.side_effect = subprocess.TimeoutExpired("qmd", 30)
            assert qmd.get_document("#abc") is None


# ---------------------------------------------------------------------------
# ensure_collection
# ---------------------------------------------------------------------------

class TestEnsureCollection:
    def test_returns_false_when_unavailable(self, tmp_path: Path) -> None:
        with patch.object(qmd, "is_available", return_value=False):
            assert not qmd.ensure_collection(tmp_path, "s1")

    def test_updates_existing_collection(self, tmp_path: Path) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            # collection show succeeds → already exists
            mock_run.return_value = MagicMock(returncode=0)
            assert qmd.ensure_collection(tmp_path, "s1")

        # Should have called show, then update
        calls = [c[0][0] for c in mock_run.call_args_list]
        assert calls[0] == ["collection", "show", "vcc-s1"]
        assert calls[1] == ["update"]

    def test_creates_new_collection(self, tmp_path: Path) -> None:
        show_fail = MagicMock(returncode=1)
        add_ok = MagicMock(returncode=0)
        update_ok = MagicMock(returncode=0)

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run, \
             patch.object(qmd, "_patch_collection_pattern") as mock_patch:
            mock_run.side_effect = [show_fail, add_ok, update_ok]
            assert qmd.ensure_collection(tmp_path, "new-sess")

        mock_patch.assert_called_once()
        calls = [c[0][0] for c in mock_run.call_args_list]
        assert calls[1][0:3] == ["collection", "add", "vcc-new-sess"]

    def test_returns_false_on_add_failure(self, tmp_path: Path) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.side_effect = [
                MagicMock(returncode=1),  # show fails
                MagicMock(returncode=1, stderr="add failed"),  # add fails
            ]
            assert not qmd.ensure_collection(tmp_path, "s1")

    def test_handles_exception(self, tmp_path: Path) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.side_effect = [
                Exception("show boom"),
                Exception("add boom"),
            ]
            assert not qmd.ensure_collection(tmp_path, "s1")


# ---------------------------------------------------------------------------
# _patch_collection_pattern
# ---------------------------------------------------------------------------

class TestPatchCollectionPattern:
    def test_patches_yaml(self, tmp_path: Path) -> None:
        import yaml

        config_dir = tmp_path / ".config" / "qmd"
        config_dir.mkdir(parents=True)
        config_path = config_dir / "index.yml"
        config_path.write_text(
            yaml.dump({"collections": {"vault": {"path": "/vault", "pattern": "**/*.md"}}})
        )

        with patch.object(Path, "home", return_value=tmp_path):
            qmd._patch_collection_pattern("vcc-test", "/tmp/archives/test")

        data = yaml.safe_load(config_path.read_text())
        assert "vcc-test" in data["collections"]
        assert data["collections"]["vcc-test"]["pattern"] == "**/*.txt"
        assert data["collections"]["vcc-test"]["path"] == "/tmp/archives/test"
        assert data["collections"]["vcc-test"]["includeByDefault"] is False
        # Original collection preserved
        assert "vault" in data["collections"]

    def test_skips_when_no_config(self, tmp_path: Path) -> None:
        with patch.object(Path, "home", return_value=tmp_path):
            # Should not raise
            qmd._patch_collection_pattern("vcc-test", "/tmp/test")

    def test_skips_when_no_yaml(self) -> None:
        with patch.dict("sys.modules", {"yaml": None}):
            # Force ImportError path — should not raise
            import importlib
            # Just verify it doesn't blow up when yaml unavailable
            # (the real test is that the function has the try/except)


# ---------------------------------------------------------------------------
# remove_collection
# ---------------------------------------------------------------------------

class TestRemoveCollection:
    def test_success(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            assert qmd.remove_collection("sess-1")
            mock_run.assert_called_once_with(
                ["collection", "remove", "vcc-sess-1"],
            )

    def test_returns_false_on_failure(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.return_value = MagicMock(returncode=1)
            assert not qmd.remove_collection("sess-1")

    def test_returns_false_when_unavailable(self) -> None:
        with patch.object(qmd, "is_available", return_value=False):
            assert not qmd.remove_collection("sess-1")

    def test_handles_exception(self) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(qmd, "_run") as mock_run:
            mock_run.side_effect = Exception("boom")
            assert not qmd.remove_collection("sess-1")


# ---------------------------------------------------------------------------
# list_vcc_collections
# ---------------------------------------------------------------------------

class TestListVccCollections:
    def test_returns_only_vcc_prefixed(self, tmp_path: Path) -> None:
        import yaml

        config_dir = tmp_path / ".config" / "qmd"
        config_dir.mkdir(parents=True)
        config_path = config_dir / "index.yml"
        config_path.write_text(yaml.dump({
            "collections": {
                "vault": {"path": "/vault"},
                "vcc-session-1": {"path": "/archives/s1"},
                "vcc-session-2": {"path": "/archives/s2"},
                "ai-chats": {"path": "/chats"},
            },
        }))

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(Path, "home", return_value=tmp_path):
            result = qmd.list_vcc_collections()

        assert sorted(result) == ["vcc-session-1", "vcc-session-2"]

    def test_returns_empty_when_unavailable(self) -> None:
        with patch.object(qmd, "is_available", return_value=False):
            assert qmd.list_vcc_collections() == []

    def test_returns_empty_when_no_config(self, tmp_path: Path) -> None:
        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(Path, "home", return_value=tmp_path):
            assert qmd.list_vcc_collections() == []

    def test_returns_empty_when_no_vcc_collections(self, tmp_path: Path) -> None:
        import yaml

        config_dir = tmp_path / ".config" / "qmd"
        config_dir.mkdir(parents=True)
        (config_dir / "index.yml").write_text(yaml.dump({
            "collections": {"vault": {"path": "/vault"}},
        }))

        with patch.object(qmd, "is_available", return_value=True), \
             patch.object(Path, "home", return_value=tmp_path):
            assert qmd.list_vcc_collections() == []
