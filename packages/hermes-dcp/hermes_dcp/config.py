"""Configuration loader for hermes-dcp."""

from __future__ import annotations

import importlib
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class DCPConfig:
    enabled: bool = True
    threshold: float = 0.50
    protect_first_n: int = 3
    protect_last_n: int = 12
    keep_recent_turns: int = 3
    max_tool_chars: int = 1200
    dedupe: bool = True
    purge_errors: bool = True
    error_turns: int = 4
    distill_max_chars: int = 280

    def normalize(self) -> "DCPConfig":
        self.threshold = min(max(float(self.threshold), 0.05), 0.95)
        self.protect_first_n = max(1, int(self.protect_first_n))
        self.protect_last_n = max(1, int(self.protect_last_n))
        self.keep_recent_turns = max(0, int(self.keep_recent_turns))
        self.max_tool_chars = max(120, int(self.max_tool_chars))
        self.error_turns = max(0, int(self.error_turns))
        self.distill_max_chars = max(80, int(self.distill_max_chars))
        return self


def _hermes_home(override: str | Path | None = None) -> Path:
    if override is not None:
        return Path(override).expanduser()
    env = (os.environ.get("HERMES_HOME") or "").strip()
    if env:
        return Path(env).expanduser()
    return Path.home() / ".hermes"


def _as_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _load_yaml(path: Path) -> dict[str, Any]:
    try:
        yaml = importlib.import_module("yaml")
    except Exception:
        return {}

    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception:
        return {}

    return _as_dict(loaded)


def load_config(*, hermes_home: str | Path | None = None) -> DCPConfig:
    cfg = DCPConfig()
    config_path = _hermes_home(hermes_home) / "config.yaml"

    if not config_path.exists():
        return cfg.normalize()

    data = _load_yaml(config_path)
    if not data:
        return cfg.normalize()

    context = _as_dict(data.get("context"))
    dcp = _as_dict(context.get("dcp"))
    compression = _as_dict(data.get("compression"))

    merged: dict[str, Any] = {
        "threshold": compression.get("threshold", cfg.threshold),
        "protect_last_n": compression.get("protect_last_n", cfg.protect_last_n),
    }
    merged.update(dcp)

    for key, value in merged.items():
        if hasattr(cfg, key):
            setattr(cfg, key, value)

    return cfg.normalize()
