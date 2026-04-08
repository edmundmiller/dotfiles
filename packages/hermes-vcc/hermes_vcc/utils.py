"""Shared utilities for hermes-vcc."""

from __future__ import annotations

import importlib.util
import logging
import sys
import types
from pathlib import Path

logger = logging.getLogger(__name__)

_PACKAGE_DIR = Path(__file__).resolve().parent
_PROJECT_ROOT = _PACKAGE_DIR.parent


def estimate_tokens(text: str) -> int:
    """Rough token estimate using byte-pair heuristic (len // 4).

    Good enough for budgeting and manifest metadata; not a substitute
    for a real tokenizer.
    """
    return len(text) // 4


def ensure_dir(path: Path) -> Path:
    """Create directory (and parents) if it does not exist.

    Returns the path for chaining convenience.
    """
    path.mkdir(parents=True, exist_ok=True)
    return path


def vendor_vcc_path() -> Path:
    """Return the absolute path to vendor/VCC.py shipped with this package."""
    return _PROJECT_ROOT / "vendor" / "VCC.py"


def import_vcc() -> types.ModuleType:
    """Dynamically import the vendored VCC.py module.

    Uses importlib.util so the module does not need to live on sys.path.
    The module is cached in sys.modules after the first successful import.

    Returns:
        The loaded VCC module.

    Raises:
        FileNotFoundError: If vendor/VCC.py is missing.
        ImportError: If the module fails to load.
    """
    module_name = "hermes_vcc._vendor_vcc"

    # Return cached module if already loaded.
    if module_name in sys.modules:
        return sys.modules[module_name]

    vcc_path = vendor_vcc_path()
    if not vcc_path.exists():
        raise FileNotFoundError(f"Vendored VCC.py not found at {vcc_path}")

    spec = importlib.util.spec_from_file_location(module_name, str(vcc_path))
    if spec is None or spec.loader is None:
        raise ImportError(f"Could not create module spec for {vcc_path}")

    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module

    try:
        spec.loader.exec_module(module)
    except Exception:
        # Remove partially-loaded module from cache on failure.
        sys.modules.pop(module_name, None)
        raise

    return module
