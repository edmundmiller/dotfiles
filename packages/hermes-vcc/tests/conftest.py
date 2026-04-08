"""Shared test fixtures for hermes-vcc."""

import json
from pathlib import Path

import pytest

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def fixtures_dir():
    return FIXTURES_DIR


@pytest.fixture
def basic_conversation():
    return json.loads((FIXTURES_DIR / "basic_conversation.json").read_text())


@pytest.fixture
def tool_heavy_session():
    return json.loads((FIXTURES_DIR / "tool_heavy_session.json").read_text())


@pytest.fixture
def thinking_session():
    return json.loads((FIXTURES_DIR / "thinking_session.json").read_text())


@pytest.fixture
def compressed_session():
    return json.loads((FIXTURES_DIR / "compressed_session.json").read_text())


@pytest.fixture
def multi_tool_message():
    return json.loads((FIXTURES_DIR / "multi_tool_message.json").read_text())


@pytest.fixture
def archive_dir(tmp_path):
    """Temporary directory for VCC archive output."""
    d = tmp_path / "vcc_archives"
    d.mkdir()
    return d


@pytest.fixture
def vcc_py_path():
    """Path to the vendored VCC.py."""
    p = Path(__file__).parent.parent / "vendor" / "VCC.py"
    assert p.exists(), f"Vendored VCC.py not found at {p}"
    return p
