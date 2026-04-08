"""Tests for hermes_vcc.hooks — VCC archive hook installation."""

from unittest.mock import MagicMock

from hermes_vcc.config import VCCConfig
from hermes_vcc.hooks import install, _install_archive


def _make_config(tmp_path):
    return VCCConfig(enabled=True, archive_dir=tmp_path / "vcc_archives", retain_archives=10)


def _make_agent(has_compress=True):
    agent = MagicMock()
    agent.session_id = "test-123"
    if has_compress:
        agent._compress_context = MagicMock(return_value=([], "sys"))
        agent._compress_context._vcc_wrapped = False
    else:
        del agent._compress_context
    return agent


class TestInstallArchive:
    def test_installs(self, tmp_path, vcc_py_path):
        config = _make_config(tmp_path)
        agent = _make_agent()
        original = agent._compress_context
        assert _install_archive(agent, config) is True
        assert agent._compress_context._vcc_wrapped is True
        agent._compress_context([{"role": "user", "content": "hi"}], "sys")
        original.assert_called_once()

    def test_no_method(self, tmp_path):
        config = _make_config(tmp_path)
        agent = _make_agent(has_compress=False)
        assert _install_archive(agent, config) is False

    def test_idempotent(self, tmp_path, vcc_py_path):
        config = _make_config(tmp_path)
        agent = _make_agent()
        _install_archive(agent, config)
        wrapper = agent._compress_context
        _install_archive(agent, config)
        assert agent._compress_context is wrapper


class TestInstall:
    def test_archive_hook(self, tmp_path, vcc_py_path):
        config = _make_config(tmp_path)
        agent = _make_agent()
        results = install(agent, config)
        assert results["archive"] is True

    def test_disabled(self, tmp_path):
        config = _make_config(tmp_path)
        config.enabled = False
        agent = _make_agent()
        results = install(agent, config)
        assert results == {"archive": False}
