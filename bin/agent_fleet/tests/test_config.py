"""Tests for configuration constants and validation."""

from agent_fleet.core.config import WORKSPACE_PREFIX, WORKTREES_DIR, STATE_FILE


def test_workspace_prefix_constant():
    """Workspace prefix should be 'agent-'"""
    assert WORKSPACE_PREFIX == "agent-"


def test_workspace_name_format():
    """Workspace names should follow agent-<taskid> format"""
    task_id = "20250116-120000"
    workspace_name = f"{WORKSPACE_PREFIX}{task_id}"

    assert workspace_name == "agent-20250116-120000"
    assert workspace_name.startswith(WORKSPACE_PREFIX)


def test_state_file_location():
    """State file should be in .worktrees/.agent-fleet.json"""
    assert STATE_FILE == ".worktrees/.agent-fleet.json"


def test_worktrees_dir_constant():
    """Worktrees directory should be .worktrees"""
    assert WORKTREES_DIR == ".worktrees"


def test_state_structure_spec():
    """State file should have workspaces dict with specific fields"""
    # This documents the expected state structure
    state = {
        "workspaces": {
            "agent-20250116-120000": {
                "id": "20250116-120000",
                "description": "Task description",
                "created": "2025-01-16T12:00:00",
                "path": ".worktrees/agent-20250116-120000",
                "agent": "claude-code",
            }
        }
    }

    # Verify structure
    assert "workspaces" in state
    assert isinstance(state["workspaces"], dict)

    workspace = state["workspaces"]["agent-20250116-120000"]
    assert "id" in workspace
    assert "description" in workspace
    assert "created" in workspace
    assert "path" in workspace
    assert "agent" in workspace
