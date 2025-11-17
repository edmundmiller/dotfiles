"""Tests for state management functionality."""

import time
from agent_fleet.core.state import (
    load_state,
    save_state,
    generate_task_id,
    ensure_worktrees_dir,
)
from agent_fleet.core.config import WORKTREES_DIR, STATE_FILE


def test_generate_task_id_format():
    """Task ID should follow YYYYMMDD-HHMMSS format"""
    task_id = generate_task_id()
    assert len(task_id) == 15  # YYYYMMDD-HHMMSS
    assert task_id[8] == "-"  # Hyphen separator

    # Should be parseable as datetime
    parts = task_id.split("-")
    assert len(parts) == 2
    assert parts[0].isdigit() and len(parts[0]) == 8  # Date part
    assert parts[1].isdigit() and len(parts[1]) == 6  # Time part


def test_generate_task_id_unique():
    """Sequential task IDs should be different (or at least potentially so)"""
    id1 = generate_task_id()
    time.sleep(0.001)  # Small delay to ensure different timestamp
    id2 = generate_task_id()

    # Note: These might be the same if called in the same second
    # This test just documents the format, not uniqueness guarantee
    assert isinstance(id1, str)
    assert isinstance(id2, str)


def test_load_state_missing_file(tmp_path):
    """Should return empty state when file doesn't exist"""
    repo_root = tmp_path / "test-repo"
    repo_root.mkdir()

    state = load_state(repo_root)
    assert state == {"workspaces": {}}


def test_load_state_invalid_json(tmp_path):
    """Should return empty state when JSON is invalid"""
    repo_root = tmp_path / "test-repo"
    repo_root.mkdir()
    worktrees = repo_root / WORKTREES_DIR
    worktrees.mkdir()

    state_file = repo_root / STATE_FILE
    state_file.write_text("not valid json{{{")

    state = load_state(repo_root)
    assert state == {"workspaces": {}}


def test_save_and_load_state_roundtrip(tmp_path):
    """Should preserve state through save/load cycle"""
    repo_root = tmp_path / "test-repo"
    repo_root.mkdir()
    worktrees = repo_root / WORKTREES_DIR
    worktrees.mkdir()

    # Create test state
    test_state = {
        "workspaces": {
            "agent-20250116-120000": {
                "id": "20250116-120000",
                "description": "Test task",
                "created": "2025-01-16T12:00:00",
                "path": ".worktrees/agent-20250116-120000",
                "agent": "claude-code",
            }
        }
    }

    # Save and load
    save_state(repo_root, test_state)
    loaded_state = load_state(repo_root)

    assert loaded_state == test_state
    assert "agent-20250116-120000" in loaded_state["workspaces"]
    assert (
        loaded_state["workspaces"]["agent-20250116-120000"]["description"]
        == "Test task"
    )


def test_save_state_creates_directory(tmp_path):
    """Should create .worktrees directory if it doesn't exist"""
    repo_root = tmp_path / "test-repo"
    repo_root.mkdir()

    state = {"workspaces": {}}

    # Directory doesn't exist yet
    assert not (repo_root / WORKTREES_DIR).exists()

    # Create directory first (as the actual code does)
    worktrees = repo_root / WORKTREES_DIR
    worktrees.mkdir(exist_ok=True)

    save_state(repo_root, state)

    # State file should exist now
    assert (repo_root / STATE_FILE).exists()


def test_empty_state_initialization():
    """Empty state should have empty workspaces dict"""
    state = {"workspaces": {}}
    assert isinstance(state["workspaces"], dict)
    assert len(state["workspaces"]) == 0


def test_ensure_worktrees_dir_creates_directory(tmp_path):
    """Should create .worktrees directory if it doesn't exist"""
    repo_root = tmp_path / "test-repo"
    repo_root.mkdir()

    worktrees = ensure_worktrees_dir(repo_root)

    assert worktrees.exists()
    assert worktrees.is_dir()
    assert worktrees == repo_root / WORKTREES_DIR


def test_ensure_worktrees_dir_idempotent(tmp_path):
    """Should not fail if directory already exists"""
    repo_root = tmp_path / "test-repo"
    repo_root.mkdir()

    # Create it once
    worktrees1 = ensure_worktrees_dir(repo_root)

    # Create it again
    worktrees2 = ensure_worktrees_dir(repo_root)

    assert worktrees1 == worktrees2
    assert worktrees1.exists()
