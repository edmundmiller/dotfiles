"""jmux attention hook for Hermes.

Sets tmux session option ``@jmux-attention=1`` when a CLI turn finishes
successfully inside tmux, so jmux shows the orange attention marker.
"""

from __future__ import annotations

import logging
import os
import subprocess
from typing import Any

logger = logging.getLogger(__name__)


def _set_jmux_attention() -> None:
    """Best-effort: set attention on current tmux session."""
    try:
        subprocess.run(
            ["tmux", "set-option", "@jmux-attention", "1"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
        )
    except Exception as exc:  # pragma: no cover - defensive
        logger.debug("jmux attention hook failed: %s", exc)


def _on_session_end(
    session_id: str | None = None,
    completed: bool = False,
    interrupted: bool = False,
    platform: str | None = None,
    **_: Any,
) -> None:
    """Mark attention after a completed, non-interrupted CLI turn in tmux."""
    _ = session_id

    if not completed or interrupted:
        return

    if platform not in (None, "cli"):
        return

    if not os.environ.get("TMUX"):
        return

    _set_jmux_attention()


def register(ctx) -> None:
    """Register Hermes lifecycle hook."""
    ctx.register_hook("on_session_end", _on_session_end)
