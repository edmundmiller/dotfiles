"""Configuration for hermes-vcc.

Reads ``compression.vcc`` from Hermes config.yaml.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

_DEFAULT_HERMES_CONFIG = Path.home() / ".hermes" / "config.yaml"


@dataclass
class VCCConfig:
    """VCC configuration with safe defaults."""

    enabled: bool = True
    archive_dir: Path = field(
        default_factory=lambda: Path.home() / ".hermes" / "vcc_archives"
    )
    retain_archives: int = 10

    def __post_init__(self) -> None:
        if isinstance(self.archive_dir, str):
            self.archive_dir = Path(self.archive_dir)
        self.archive_dir = self.archive_dir.expanduser()


def load_config(config_path: Path | None = None) -> VCCConfig:
    """Load VCC config from Hermes config.yaml.

    Falls back to defaults if anything is missing.
    """
    path = config_path or _DEFAULT_HERMES_CONFIG

    if not path.is_file():
        return VCCConfig()

    try:
        import yaml
    except ImportError:
        return VCCConfig()

    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception:
        return VCCConfig()

    if not isinstance(data, dict):
        return VCCConfig()

    vcc_section = data.get("compression", {}).get("vcc", {})
    if not isinstance(vcc_section, dict):
        return VCCConfig()

    kwargs: dict[str, Any] = {}
    if "enabled" in vcc_section:
        kwargs["enabled"] = bool(vcc_section["enabled"])
    if "archive_dir" in vcc_section:
        kwargs["archive_dir"] = Path(str(vcc_section["archive_dir"]))
    if "retain_archives" in vcc_section:
        try:
            kwargs["retain_archives"] = int(vcc_section["retain_archives"])
        except (TypeError, ValueError):
            pass

    return VCCConfig(**kwargs)
