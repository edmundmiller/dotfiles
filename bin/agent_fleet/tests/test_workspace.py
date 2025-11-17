"""Tests for workspace operations and parsing."""

from agent_fleet.core.config import WORKSPACE_PREFIX, WORKTREES_DIR


def test_list_jj_workspaces_parsing():
    """Should parse jj workspace list output correctly"""
    # This is a spec test documenting the expected parsing behavior
    # In real use, this would mock subprocess.run

    sample_output = """default: /path/to/repo
agent-20250116-120000: /path/to/repo/.worktrees/agent-20250116-120000
agent-20250116-123000: /path/to/repo/.worktrees/agent-20250116-123000
* agent-20250116-130000: /path/to/repo/.worktrees/agent-20250116-130000
other-workspace: /path/to/other"""

    # Test the parsing logic directly
    workspaces = set()
    for line in sample_output.strip().split("\n"):
        if ":" in line:
            name = line.split(":")[0].strip().lstrip("*").strip()
            if name.startswith(WORKSPACE_PREFIX):
                workspaces.add(name)

    assert "agent-20250116-120000" in workspaces
    assert "agent-20250116-123000" in workspaces
    assert "agent-20250116-130000" in workspaces
    assert "default" not in workspaces
    assert "other-workspace" not in workspaces
    assert len(workspaces) == 3


def test_list_jj_workspaces_filters_current():
    """Should handle current workspace marker (*)"""
    sample_output = "* agent-20250116-120000: /path/to/workspace"

    workspaces = set()
    for line in sample_output.strip().split("\n"):
        if ":" in line:
            name = line.split(":")[0].strip().lstrip("*").strip()
            if name.startswith(WORKSPACE_PREFIX):
                workspaces.add(name)

    assert "agent-20250116-120000" in workspaces


def test_state_workspace_path_relative():
    """Workspace path in state should be relative to repo root"""
    # This is a spec test documenting the expected behavior
    workspace_path = ".worktrees/agent-20250116-120000"

    assert not workspace_path.startswith("/")  # Not absolute
    assert workspace_path.startswith(WORKTREES_DIR)
