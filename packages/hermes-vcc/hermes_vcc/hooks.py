"""Install VCC into a running Hermes agent.

One hook: archive the full conversation as VCC views (.txt, .min.txt)
before each compression cycle. The LLM summary is left untouched —
VCC is a projection tool for trace analysis and recovery, not a
replacement for semantic compression summaries.

Per the VCC paper (Zhang & Agrawala, 2026): VCC performs *projection*
(selecting and annotating existing content with exact coordinates),
not *abstraction* (generating new content). The LLM summary provides
the semantic abstraction (Goal, Progress, Decisions, Next Steps) that
the agent needs to continue working. VCC provides the lossless archive
the agent can consult when it needs specific details.
"""

from __future__ import annotations

import functools
import logging
from typing import Any

from hermes_vcc.config import VCCConfig, load_config

logger = logging.getLogger(__name__)

_CYCLE_ATTR = "_vcc_compression_cycle"


def install(agent: Any, config: VCCConfig | None = None) -> dict[str, bool]:
    """Install VCC archive hook on a Hermes agent.

    Archives the full conversation as VCC views before each compression.
    Does NOT replace the LLM summary — VCC is for recovery, not compression.

    Args:
        agent: A Hermes AIAgent instance.
        config: Optional config. Loaded from config.yaml if None.

    Returns:
        {"archive": bool} indicating success.
    """
    if config is None:
        try:
            config = load_config()
        except Exception:
            config = VCCConfig()

    if not config.enabled:
        return {"archive": False}

    result = _install_archive(agent, config)
    logger.info("VCC archive hook: %s", result)
    return {"archive": result}


def _install_archive(agent: Any, config: VCCConfig) -> bool:
    """Patch _compress_context to archive before compression."""
    try:
        original = getattr(agent, "_compress_context", None)
        if original is None:
            return False
        if getattr(original, "_vcc_wrapped", False):
            return True  # already installed

        from hermes_vcc.archive import archive_before_compression, prune_archives
        from hermes_vcc.utils import ensure_dir

        archive_dir = ensure_dir(config.archive_dir)

        @functools.wraps(original)
        def wrapper(messages, system_message, *args, **kwargs):
            session_id = getattr(agent, "session_id", None) or "unknown"
            cycle = getattr(agent, _CYCLE_ATTR, 0) + 1
            setattr(agent, _CYCLE_ATTR, cycle)

            try:
                session_dir = archive_before_compression(
                    messages, session_id, archive_dir, cycle,
                )
                if config.retain_archives > 0:
                    prune_archives(session_dir, retain=config.retain_archives)
            except Exception as exc:
                logger.warning("VCC archive failed (non-fatal): %s", exc)

            return original(messages, system_message, *args, **kwargs)

        wrapper._vcc_wrapped = True  # type: ignore[attr-defined]
        agent._compress_context = wrapper
        return True

    except Exception as exc:
        logger.warning("VCC archive hook failed: %s", exc)
        return False
